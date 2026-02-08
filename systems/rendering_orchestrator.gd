class_name RenderingOrchestrator
extends RefCounted

## RenderingOrchestrator - Coordinates game rendering, visibility, and light sources
##
## Extracted from game.gd to reduce its size and improve organization.
## Manages: terrain rendering, entity rendering, ground items, features, hazards,
## visibility/FOV, fog of war, light source management, and dirty flag tracking.

const GroundItemClass = preload("res://entities/ground_item.gd")
const VisibilitySystemClass = preload("res://systems/visibility_system.gd")
const LightingSystemClass = preload("res://systems/lighting_system.gd")
const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")
const FOVSystemClass = preload("res://systems/fov_system.gd")
const ChunkManagerClass = preload("res://autoload/chunk_manager.gd")
const LogManagerClass = preload("res://autoload/log_manager.gd")

# External references (set via setup())
var renderer = null  # ASCIIRenderer
var player: Player = null
var input_handler = null  # InputHandler (for get_current_target)

# Dirty tracking / render state
var full_render_needed: bool = true
var rendered_entities: Dictionary = {}  # Vector2i -> Entity reference

# Light source caching
var enemy_light_cache: Array[Vector2i] = []
var enemy_light_cache_dirty: bool = true


## Initialize with game scene references
func setup(rend, p: Player, ih) -> void:
	renderer = rend
	player = p
	input_handler = ih


# =============================================================================
# MAP RENDERING
# =============================================================================

## Render the entire current map (terrain tiles)
func render_map() -> void:
	if not MapManager.current_map:
		return

	renderer.clear_all()

	# Chunk-based rendering for overworld
	if MapManager.current_map.chunk_based:
		var active_chunk_coords = ChunkManager.get_active_chunk_coords()
		for chunk_coords in active_chunk_coords:
			var chunk = ChunkManager.get_chunk(chunk_coords)
			if chunk and chunk.is_loaded:
				renderer.render_chunk(chunk)
		return

	# Check if this is a dungeon map
	var is_dungeon = MapManager.current_map.metadata.has("floor_number") or "_floor_" in MapManager.current_map.map_id

	# For dungeons, only render tiles that exist in the dictionary
	if is_dungeon:
		for pos in MapManager.current_map.tiles.keys():
			var tile = MapManager.current_map.tiles[pos]

			# Skip walls that aren't adjacent to any walkable tile
			if not tile.walkable and not tile.transparent:
				if not _is_wall_adjacent_to_walkable(pos):
					continue

			renderer.render_tile(pos, tile.ascii_char)
	else:
		# Traditional rendering for non-dungeon, non-chunk maps
		for y in range(MapManager.current_map.height):
			for x in range(MapManager.current_map.width):
				var pos = Vector2i(x, y)
				var tile = MapManager.current_map.get_tile(pos)
				renderer.render_tile(pos, tile.ascii_char)


## Check if a wall position is adjacent to any walkable tile
func _is_wall_adjacent_to_walkable(pos: Vector2i) -> bool:
	var neighbors = [
		Vector2i(pos.x - 1, pos.y - 1), Vector2i(pos.x, pos.y - 1), Vector2i(pos.x + 1, pos.y - 1),
		Vector2i(pos.x - 1, pos.y),                                 Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y + 1), Vector2i(pos.x, pos.y + 1), Vector2i(pos.x + 1, pos.y + 1)
	]

	for neighbor in neighbors:
		if neighbor in MapManager.current_map.tiles:
			var neighbor_tile = MapManager.current_map.tiles[neighbor]
			if neighbor_tile.walkable:
				return true

	return false


# =============================================================================
# SINGLE-POSITION RENDERING
# =============================================================================

## Render any non-blocking entity at a specific position (crops, etc.)
## Skips rendering if player is at the position (player renders on top)
func render_entity_at(pos: Vector2i) -> void:
	if player and player.position == pos:
		return

	for entity in EntityManager.entities:
		if entity.is_alive and entity.position == pos and not entity.blocks_movement:
			renderer.render_entity(pos, entity.ascii_char, entity.color)
			return  # Only render the first entity at this position


## Render a ground item or structure at a specific position if one exists
func render_ground_item_at(pos: Vector2i) -> void:
	# Check for structures first (they should be rendered above ground items)
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_at(pos, map_id)
	if structures.size() > 0:
		var structure = structures[0]
		var color = structure.color
		if color is String:
			color = Color.from_string(color, Color.WHITE)
		renderer.render_entity(pos, structure.ascii_char, color)
		return

	# If no structure, check for ground items
	var ground_items = EntityManager.get_ground_items_at(pos)
	if ground_items.size() > 0:
		var item = ground_items[0]
		renderer.render_entity(pos, item.ascii_char, item.color)


## Render a feature at a specific position if one exists
func render_feature_at(pos: Vector2i) -> void:
	if FeatureManager.active_features.has(pos):
		# Skip rendering on non-walkable tiles (walls)
		if MapManager.current_map:
			var tile = MapManager.current_map.get_tile(pos)
			if tile == null or not tile.walkable:
				return
		var feature: Dictionary = FeatureManager.active_features[pos]
		var definition: Dictionary = feature.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "?")
		var color = definition.get("color", Color.WHITE)
		if color is String:
			color = Color.from_string(color, Color.WHITE)
		renderer.render_entity(pos, ascii_char, color)


## Render a hazard at a specific position if one exists and is visible
func render_hazard_at(pos: Vector2i) -> void:
	if HazardManager.has_visible_hazard(pos):
		var hazard: Dictionary = HazardManager.active_hazards[pos]
		var definition: Dictionary = hazard.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "^")
		var color = definition.get("color", Color.RED)
		# Handle string colors (from serialized data)
		if color is String:
			color = Color.from_string(color, Color.RED)
		# Disarmed hazards appear grey
		if hazard.get("disarmed", false):
			color = Color(0.5, 0.5, 0.5)  # Grey
		renderer.render_entity(pos, ascii_char, color)


# =============================================================================
# ENTITY RENDERING (ALL)
# =============================================================================

## Render all entities on the current map
func render_all_entities() -> void:
	# Use incremental rendering if possible (much faster for large entity counts)
	if full_render_needed:
		_full_render_all_entities()
		full_render_needed = false
		return

	_incremental_render_entities()


## Full entity render - used on map transitions or when incremental tracking is lost
func _full_render_all_entities() -> void:
	rendered_entities.clear()

	# DIAGNOSTIC: Log entity/structure/feature counts for debugging
	var map_id_diag = MapManager.current_map.map_id if MapManager.current_map else "null"
	var is_daytime_diag = TurnManager.time_of_day if TurnManager else "unknown"
	var entity_count = EntityManager.entities.size()
	var structure_count = StructureManager.get_structures_on_map(map_id_diag).size()
	var feature_count = FeatureManager.active_features.size()
	LogManager.game("RENDER: map=%s time=%s entities=%d structures=%d features=%d" % [map_id_diag, is_daytime_diag, entity_count, structure_count, feature_count])

	# Get current target for highlighting
	var current_target = input_handler.get_current_target() if input_handler else null

	# Get player position to skip rendering entities at player's tile
	var player_pos = player.position if player else Vector2i(-1, -1)

	for entity in EntityManager.entities:
		# Ground items are rendered via render_ground_items(); skip them here
		if entity.get_script() == GroundItemClass:
			continue
		if entity.is_alive:
			# Skip entities at player's position - player renders on top
			if entity.position == player_pos:
				continue
			var render_color = entity.color
			# Highlight targeted enemy with a distinct color
			if entity == current_target:
				render_color = Color(1.0, 0.4, 0.4)  # Red tint for targeted enemy
			renderer.render_entity(entity.position, entity.ascii_char, render_color)
			rendered_entities[entity.position] = entity

	# Render structures (skip player position)
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_on_map(map_id)
	for structure in structures:
		if structure.position != player_pos:
			var struct_color = structure.color
			if struct_color is String:
				struct_color = Color.from_string(struct_color, Color.WHITE)
			renderer.render_entity(structure.position, structure.ascii_char, struct_color)
			rendered_entities[structure.position] = structure

	# Render dungeon features (skip player position) and add to tracking
	var is_overworld_map = MapManager.current_map and MapManager.current_map.chunk_based
	for pos in FeatureManager.active_features:
		if pos == player_pos:
			continue
		if MapManager.current_map:
			var tile = MapManager.current_map.get_tile(pos)
			# For dungeons: strictly check tile validity (walls shouldn't have features)
			# For overworld: be lenient - if tile is null, chunk may be loading, allow render
			if not is_overworld_map:
				if tile == null or not tile.walkable:
					continue
			elif tile != null and not tile.walkable:
				# Overworld: only skip if we CAN verify tile is non-walkable
				continue
		# Check if feature is visible
		if not renderer.is_position_visible(pos):
			continue

		# Features require direct line of sight (not just light leak visibility)
		# Check visibility_data for the in_los flag (only in dungeons/night)
		var vis_data = renderer.visibility_data if renderer else {}
		if not vis_data.is_empty() and vis_data.has(pos):
			# We have visibility data - check for direct LOS
			if not vis_data[pos].get("in_los", false):
				continue  # No direct LOS - skip rendering feature

		var feature: Dictionary = FeatureManager.active_features[pos]
		var definition: Dictionary = feature.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "?")
		var color = definition.get("color", Color.WHITE)
		# Handle color stored as string in JSON
		if color is String:
			color = Color.from_string(color, Color.WHITE)
		renderer.render_entity(pos, ascii_char, color)
		rendered_entities[pos] = feature

	# Render dungeon hazards (visible ones only, skip player position) and add to tracking
	for pos in HazardManager.active_hazards:
		if pos == player_pos:
			continue
		if not HazardManager.has_visible_hazard(pos):
			continue
		if not renderer.is_position_visible(pos):
			continue
		var hazard: Dictionary = HazardManager.active_hazards[pos]
		var definition: Dictionary = hazard.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "^")
		var color = definition.get("color", Color.RED)
		if color is String:
			color = Color.from_string(color, Color.RED)
		if hazard.get("disarmed", false):
			color = Color(0.5, 0.5, 0.5)
		renderer.render_entity(pos, ascii_char, color)
		rendered_entities[pos] = hazard


## Incremental entity render - only updates entities that changed
func _incremental_render_entities() -> void:
	var current_entities: Dictionary = {}

	# Get current target for highlighting
	var current_target = input_handler.get_current_target() if input_handler else null
	var player_pos = player.position if player else Vector2i(-1, -1)

	# Build current entity positions (skip ground items - rendered separately)
	for entity in EntityManager.entities:
		if entity.get_script() == GroundItemClass:
			continue
		if entity.is_alive and entity.position != player_pos:
			current_entities[entity.position] = entity

	# Add structures
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_on_map(map_id)
	for structure in structures:
		if structure.position != player_pos:
			current_entities[structure.position] = structure

	# Find and clear removed entities (but skip features/hazards - they'll be handled separately)
	for pos in rendered_entities:
		if not current_entities.has(pos):
			# Don't clear features or hazards here - they have their own rendering logic
			if not FeatureManager.active_features.has(pos) and not HazardManager.active_hazards.has(pos):
				renderer.clear_entity(pos)

	# Render new/moved entities
	for pos in current_entities:
		var entity = current_entities[pos]

		# Re-render if entity is new at this position or if it's the current target (color may change)
		if not rendered_entities.has(pos) or rendered_entities[pos] != entity or entity == current_target:
			var render_color = entity.color if "color" in entity else Color.WHITE
			var ascii_char = entity.ascii_char if "ascii_char" in entity else "?"

			# Highlight targeted enemy
			if entity == current_target:
				render_color = Color(1.0, 0.4, 0.4)

			renderer.render_entity(pos, ascii_char, render_color)

	# Before replacing rendered_entities, save old feature/hazard positions for cleanup
	var old_feature_positions: Array[Vector2i] = []
	var old_hazard_positions: Array[Vector2i] = []
	for pos in rendered_entities:
		if FeatureManager.active_features.has(pos):
			old_feature_positions.append(pos)
		elif HazardManager.active_hazards.has(pos):
			old_hazard_positions.append(pos)

	# Update rendered_entities with current entities
	rendered_entities = current_entities

	# Render features and hazards separately with visibility tracking
	var rendered_features: Array[Vector2i] = []
	var rendered_hazards: Array[Vector2i] = []

	# Render visible features
	for pos in FeatureManager.active_features:
		if pos == player_pos:
			continue
		if not renderer.is_position_visible(pos):
			continue

		# Features require direct line of sight (not just light leak visibility)
		# EXCEPT during daytime outdoors for exterior tiles (visibility_data is empty by design)
		var vis_data = renderer.visibility_data if renderer else {}
		var is_daytime_outdoors = MapManager.current_map and FOVSystemClass.is_daytime_outdoors(MapManager.current_map)
		var tile = MapManager.current_map.get_tile(pos) if MapManager.current_map else null
		var is_exterior = tile and not tile.is_interior

		if not is_daytime_outdoors or not is_exterior:
			# Night/interior: require LOS check
			if not vis_data.is_empty() and vis_data.has(pos):
				if not vis_data[pos].get("in_los", false):
					continue  # No direct LOS - skip rendering feature

		var feature: Dictionary = FeatureManager.active_features[pos]
		var definition: Dictionary = feature.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "?")
		var color = definition.get("color", Color.WHITE)
		if color is String:
			color = Color.from_string(color, Color.WHITE)
		renderer.render_entity(pos, ascii_char, color)
		rendered_entities[pos] = feature
		rendered_features.append(pos)

	# Render visible hazards
	for pos in HazardManager.active_hazards:
		if pos == player_pos:
			continue
		if not HazardManager.has_visible_hazard(pos):
			continue
		if renderer.is_position_visible(pos):
			var hazard: Dictionary = HazardManager.active_hazards[pos]
			var definition: Dictionary = hazard.get("definition", {})
			var ascii_char: String = definition.get("ascii_char", "^")
			var color = definition.get("color", Color.RED)
			if color is String:
				color = Color.from_string(color, Color.RED)
			if hazard.get("disarmed", false):
				color = Color(0.5, 0.5, 0.5)
			renderer.render_entity(pos, ascii_char, color)
			rendered_entities[pos] = hazard
			rendered_hazards.append(pos)

	# Clear features that were visible before but aren't now
	for pos in old_feature_positions:
		if not pos in rendered_features:
			renderer.clear_entity(pos)

	# Clear hazards that were visible before but aren't now
	for pos in old_hazard_positions:
		if not pos in rendered_hazards:
			renderer.clear_entity(pos)


# =============================================================================
# FEATURE AND HAZARD RENDERING (STANDALONE)
# =============================================================================

## Render dungeon features (chests, altars, etc.)
func render_features(skip_pos: Vector2i = Vector2i(-1, -1)) -> void:
	for pos in FeatureManager.active_features:
		if pos == skip_pos:
			continue
		if not renderer.is_position_visible(pos):
			continue
		var feature: Dictionary = FeatureManager.active_features[pos]
		var definition: Dictionary = feature.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "?")
		var color = definition.get("color", Color.WHITE)
		if color is String:
			color = Color.from_string(color, Color.WHITE)
		renderer.render_entity(pos, ascii_char, color)


## Render dungeon hazards (only visible/detected ones)
func render_hazards(skip_pos: Vector2i = Vector2i(-1, -1)) -> void:
	for pos in HazardManager.active_hazards:
		if pos == skip_pos:
			continue
		if not HazardManager.has_visible_hazard(pos):
			continue
		if not renderer.is_position_visible(pos):
			continue
		var hazard: Dictionary = HazardManager.active_hazards[pos]
		var definition: Dictionary = hazard.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "^")
		var color = definition.get("color", Color.RED)
		if color is String:
			color = Color.from_string(color, Color.RED)
		if hazard.get("disarmed", false):
			color = Color(0.5, 0.5, 0.5)
		renderer.render_entity(pos, ascii_char, color)


# =============================================================================
# GROUND ITEM RENDERING
# =============================================================================

## Render all ground items on the map (except under player)
func render_ground_items() -> void:
	# OPTIMIZATION: Only check visible tiles instead of all entities
	var visible_tiles = renderer.visible_tiles if renderer else []

	# If we don't have visible tiles info, fall back to scanning all (shouldn't happen)
	if visible_tiles.is_empty():
		for entity in EntityManager.entities:
			if entity is GroundItemClass:
				if player and entity.position == player.position:
					continue
				var render_color = entity.color
				if entity.item and entity.item.provides_light and entity.item.is_lit:
					render_color = Color(1.0, 0.7, 0.2)
				renderer.render_entity(entity.position, entity.ascii_char, render_color)
		return

	# Only check entities at visible positions (much faster)
	for pos in visible_tiles:
		var ground_items = EntityManager.get_ground_items_at(pos)
		if ground_items.size() > 0:
			var entity = ground_items[0]
			# Don't render items under the player - player renders on top
			if player and entity.position == player.position:
				continue
			# Lit light sources get a bright orange/yellow color
			var render_color = entity.color
			if entity.item and entity.item.provides_light and entity.item.is_lit:
				render_color = Color(1.0, 0.7, 0.2)  # Bright orange-yellow for lit torches
			renderer.render_entity(entity.position, entity.ascii_char, render_color)


# =============================================================================
# VISIBILITY AND FOG OF WAR
# =============================================================================

## Update visibility after player moves or light sources change
## If apply_fow is false, only calculates visibility data without applying fog of war to entities
## This is useful when you need visibility data for rendering, but will apply FOW later
func update_visibility(apply_fow: bool = true) -> void:
	# CRITICAL: Don't update visibility if player is dead
	# This prevents infinite loops during death processing
	if not player or not player.is_alive or not MapManager.current_map:
		return

	var total_start = Time.get_ticks_usec()

	# OPTIMIZATION: No longer re-scanning structures every move
	# Persistent lights are registered once on map load
	# Dynamic lights (enemies, ground items) are updated separately
	var dynamic_lights_start = Time.get_ticks_usec()
	_update_dynamic_light_sources()
	var dynamic_lights_time = Time.get_ticks_usec() - dynamic_lights_start

	# Get all light sources for visibility calculation
	var get_lights_start = Time.get_ticks_usec()
	var light_sources = LightingSystemClass.get_all_light_sources()
	var get_lights_time = Time.get_ticks_usec() - get_lights_start

	# Calculate visibility using UNIFIED system (LOS + lighting combined)
	var player_light_radius = (player.inventory.get_equipped_light_radius() if player.inventory else 0) + player.get_light_radius_bonus()
	var effective_perception = player.get_effective_perception_range() if player.has_method("get_effective_perception_range") else player.perception_range

	var calc_start = Time.get_ticks_usec()
	var visibility_result = VisibilitySystemClass.calculate_visibility(
		player.position,
		effective_perception,
		player_light_radius,
		MapManager.current_map,
		light_sources
	)
	var calc_time = Time.get_ticks_usec() - calc_start

	# Update fog of war
	var map_id = MapManager.current_map.map_id
	var chunk_based = MapManager.current_map.chunk_based

	var fow_start = Time.get_ticks_usec()
	FogOfWarSystemClass.set_visible_tiles(visibility_result.visible_tiles)
	FogOfWarSystemClass.mark_many_explored(map_id, visibility_result.visible_tiles, chunk_based)
	var fow_time = Time.get_ticks_usec() - fow_start

	# Set visibility data on renderer (needed for is_position_visible checks)
	var renderer_start = Time.get_ticks_usec()
	renderer.set_visibility_data(visibility_result.tile_data)

	# CRITICAL: Always update player_position in renderer for visibility checks (_is_entity_visible_at)
	# This must happen even when we're not applying FOW, because interior visibility checks use player_position
	renderer.player_position = player.position

	# Only apply FOW to entities if requested
	# When rendering fresh entities, call with apply_fow=false first, render, then call with apply_fow=true
	if apply_fow:
		renderer.update_fov(visibility_result.visible_tiles, player.position)
	var renderer_time = Time.get_ticks_usec() - renderer_start

	var total_time = Time.get_ticks_usec() - total_start

	# Log if visibility update took >10ms
	if total_time > 10000:
		print("[RenderOrch] update_visibility: dynamic_lights=%.2fms, get_lights=%.2fms, calc=%.2fms (tiles=%d), fow=%.2fms, renderer=%.2fms, total=%.2fms" % [
			dynamic_lights_time / 1000.0,
			get_lights_time / 1000.0,
			calc_time / 1000.0,
			visibility_result.visible_tiles.size(),
			fow_time / 1000.0,
			renderer_time / 1000.0,
			total_time / 1000.0
		])


# =============================================================================
# LIGHT SOURCES
# =============================================================================

## OPTIMIZATION: Initialize persistent light sources on map load
## Only called on map transitions, NOT on every player move
## Dynamic lights (enemies, ground items) are still scanned each update
func initialize_light_sources_for_map() -> void:
	# Clear registered sources when changing maps
	LightingSystemClass.clear_registered_sources()
	LightingSystemClass.clear_light_sources()

	if not MapManager.current_map:
		return

	var map_id = MapManager.current_map.map_id

	# Register persistent light sources from structures (campfires, etc.)
	var structures = StructureManager.get_structures_on_map(map_id)
	for structure in structures:
		if structure.has_component("fire"):
			var fire_comp = structure.get_component("fire")
			if fire_comp.is_lit:
				var source_id = "structure_%s_%d_%d" % [map_id, structure.position.x, structure.position.y]
				LightingSystemClass.register_source(structure.position, LightingSystemClass.LightType.CAMPFIRE, 20, source_id)

	# Register persistent light sources from dungeon features (braziers, glowing moss, etc.)
	for pos in FeatureManager.active_features:
		var feature = FeatureManager.active_features[pos]
		var definition = feature.get("definition", {})
		# Check if feature provides light
		if definition.get("provides_light", false):
			var light_type_str = definition.get("light_type", "torch")
			var light_type = _get_light_type_from_string(light_type_str)
			# Use custom light_radius from definition if specified, otherwise use default for type
			var radius = definition.get("light_radius", LightingSystemClass.LIGHT_RADII.get(light_type, 5))
			var source_id = "feature_%s_%d_%d" % [map_id, pos.x, pos.y]
			LightingSystemClass.register_source(pos, light_type, radius, source_id)

	# Register town lights (lampposts) on overworld
	if map_id == "overworld":
		_register_town_lights()

	# Dynamic light sources (enemies, ground items) are handled separately
	# They change position/state frequently so are scanned on-demand
	_update_dynamic_light_sources()


## Update dynamic light sources (enemies with torches, dropped items)
## Called only when needed (player moves, time changes to/from night)
func _update_dynamic_light_sources() -> void:
	# CRITICAL: Rebuild persistent lights from registry first
	# This ensures structures/features are always in the light_sources array
	LightingSystemClass.rebuild_light_sources_from_registry()

	# Only scan entities for light sources during night/dusk/midnight (performance optimization)
	# During day, enemies don't need torches and lit ground items are rare
	var is_dark = TurnManager.time_of_day == "night" or TurnManager.time_of_day == "dusk" or TurnManager.time_of_day == "midnight"
	if is_dark:
		# Rebuild enemy light cache only when dirty (enemies moved or map changed)
		if enemy_light_cache_dirty:
			_rebuild_enemy_light_cache()

		# Register light sources from cached enemy positions
		for enemy_pos in enemy_light_cache:
			LightingSystemClass.add_light_source(enemy_pos, LightingSystemClass.LightType.TORCH)

		# Register light sources from lit ground items (dropped torches, lanterns)
		# Only scan GroundItems, not all entities
		# CRITICAL: Duplicate array to prevent modification during iteration
		for entity in EntityManager.entities.duplicate():
			if entity is GroundItem:
				var item = entity.item
				if item and item.provides_light and item.is_lit:
					LightingSystemClass.add_light_source(entity.position, LightingSystemClass.LightType.TORCH, item.light_radius)


## Rebuild the enemy light source cache (only intelligent enemies carry torches)
## Called only when cache is dirty (enemy moved or map changed)
func _rebuild_enemy_light_cache() -> void:
	enemy_light_cache.clear()
	# CRITICAL: Duplicate array to prevent modification during iteration
	for entity in EntityManager.entities.duplicate():
		if entity is Enemy and entity.is_alive:
			# Only intelligent enemies (INT >= 5) carry torches
			var enemy_int = entity.attributes.get("INT", 1)
			if enemy_int >= 5:
				enemy_light_cache.append(entity.position)
	enemy_light_cache_dirty = false


## Register town lights (lampposts) at night
func _register_town_lights() -> void:
	# Get town center from map metadata
	var town_center = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	if town_center == Vector2i(-1, -1):
		return

	# Get town size (default 20x20)
	var town_size = MapManager.current_map.get_meta("town_size", Vector2i(20, 20))
	var half_size = town_size / 2

	# Place lamppost lights at corners and center of town
	var lamppost_positions = [
		town_center,  # Town center
		town_center + Vector2i(-half_size.x / 2, -half_size.y / 2),  # NW quadrant
		town_center + Vector2i(half_size.x / 2, -half_size.y / 2),   # NE quadrant
		town_center + Vector2i(-half_size.x / 2, half_size.y / 2),   # SW quadrant
		town_center + Vector2i(half_size.x / 2, half_size.y / 2),    # SE quadrant
	]

	for pos in lamppost_positions:
		LightingSystemClass.add_light_source(pos, LightingSystemClass.LightType.LANTERN)


## Convert light type string to LightType enum
func _get_light_type_from_string(type_str: String) -> int:
	match type_str.to_lower():
		"torch": return LightingSystemClass.LightType.TORCH
		"lantern": return LightingSystemClass.LightType.LANTERN
		"campfire": return LightingSystemClass.LightType.CAMPFIRE
		"brazier": return LightingSystemClass.LightType.BRAZIER
		"glowing_moss": return LightingSystemClass.LightType.GLOWING_MOSS
		"magical": return LightingSystemClass.LightType.MAGICAL
		"candle": return LightingSystemClass.LightType.CANDLE
		_: return LightingSystemClass.LightType.TORCH
