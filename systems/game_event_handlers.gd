class_name GameEventHandlers
extends RefCounted

## GameEventHandlers - Manages EventBus signal subscriptions for game scene
##
## Centralizes event handling logic extracted from game.gd.
## Provides cleaner separation between event routing and game logic.

const ChunkManagerClass = preload("res://autoload/chunk_manager.gd")
const FOVSystemClass = preload("res://systems/fov_system.gd")
const Structure = preload("res://entities/structure.gd")
const CombatSystemClass = preload("res://systems/combat_system.gd")

# Game scene reference (set via setup())
var game = null

# State vars used exclusively by handlers (moved from game.gd)
var _processing_player_moved: bool = false
var _last_stamina_warning_turn: int = -999


## Initialize with game scene reference
func setup(game_scene) -> void:
	game = game_scene


## Connect all EventBus signals
func connect_signals() -> void:
	# Movement
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.entity_moved.connect(_on_entity_moved)
	EventBus.entity_visual_changed.connect(_on_entity_visual_changed)

	# Map and world
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.tile_changed.connect(_on_tile_changed)
	EventBus.chunk_loaded.connect(_on_chunk_loaded)

	# Turn and time
	EventBus.turn_advanced.connect(_on_turn_advanced)
	EventBus.time_of_day_changed.connect(_on_time_of_day_changed)

	# Combat
	EventBus.attack_performed.connect(_on_attack_performed)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.combat_message.connect(_on_combat_message)

	# Player progression
	EventBus.player_leveled_up.connect(_on_player_leveled_up)

	# Survival
	EventBus.survival_warning.connect(_on_survival_warning)
	EventBus.stamina_depleted.connect(_on_stamina_depleted)

	# Items
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_dropped.connect(_on_item_dropped)
	EventBus.item_used.connect(_on_item_used)
	EventBus.item_equipped.connect(_on_item_equipped)
	EventBus.item_unequipped.connect(_on_item_unequipped)
	EventBus.inventory_changed.connect(_on_inventory_changed)

	# Structures
	EventBus.structure_placed.connect(_on_structure_placed)

	# NPC / Shop
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.training_opened.connect(_on_training_opened)
	EventBus.npc_menu_opened.connect(_on_npc_menu_opened)

	# UI and feedback
	EventBus.message_logged.connect(_on_message_logged)
	EventBus.ritual_menu_requested.connect(_on_ritual_menu_requested)

	# Mode changes
	EventBus.harvesting_mode_changed.connect(_on_harvesting_mode_changed)
	EventBus.sprint_mode_changed.connect(_on_sprint_mode_changed)

	# Weather
	EventBus.weather_changed.connect(_on_weather_changed)

	# Debug
	EventBus.debug_toggle_perf_overlay.connect(_on_perf_overlay_toggle)

	# FeatureManager (not EventBus, but autoload signal)
	FeatureManager.feature_spawned_enemy.connect(_on_feature_spawned_enemy)


## Disconnect all signals (for cleanup)
func disconnect_signals() -> void:
	var connections = [
		[EventBus.player_moved, _on_player_moved],
		[EventBus.entity_moved, _on_entity_moved],
		[EventBus.entity_visual_changed, _on_entity_visual_changed],
		[EventBus.map_changed, _on_map_changed],
		[EventBus.tile_changed, _on_tile_changed],
		[EventBus.chunk_loaded, _on_chunk_loaded],
		[EventBus.turn_advanced, _on_turn_advanced],
		[EventBus.time_of_day_changed, _on_time_of_day_changed],
		[EventBus.attack_performed, _on_attack_performed],
		[EventBus.entity_died, _on_entity_died],
		[EventBus.player_died, _on_player_died],
		[EventBus.combat_message, _on_combat_message],
		[EventBus.player_leveled_up, _on_player_leveled_up],
		[EventBus.survival_warning, _on_survival_warning],
		[EventBus.stamina_depleted, _on_stamina_depleted],
		[EventBus.item_picked_up, _on_item_picked_up],
		[EventBus.item_dropped, _on_item_dropped],
		[EventBus.item_used, _on_item_used],
		[EventBus.item_equipped, _on_item_equipped],
		[EventBus.item_unequipped, _on_item_unequipped],
		[EventBus.inventory_changed, _on_inventory_changed],
		[EventBus.structure_placed, _on_structure_placed],
		[EventBus.shop_opened, _on_shop_opened],
		[EventBus.training_opened, _on_training_opened],
		[EventBus.npc_menu_opened, _on_npc_menu_opened],
		[EventBus.message_logged, _on_message_logged],
		[EventBus.ritual_menu_requested, _on_ritual_menu_requested],
		[EventBus.harvesting_mode_changed, _on_harvesting_mode_changed],
		[EventBus.sprint_mode_changed, _on_sprint_mode_changed],
		[EventBus.weather_changed, _on_weather_changed],
		[EventBus.debug_toggle_perf_overlay, _on_perf_overlay_toggle],
	]

	for conn in connections:
		if conn[0].is_connected(conn[1]):
			conn[0].disconnect(conn[1])

	if FeatureManager.feature_spawned_enemy.is_connected(_on_feature_spawned_enemy):
		FeatureManager.feature_spawned_enemy.disconnect(_on_feature_spawned_enemy)


# =============================================================================
# MOVEMENT HANDLERS
# =============================================================================

func _on_player_moved(old_pos: Vector2i, new_pos: Vector2i) -> void:
	# CRITICAL: Prevent recursive calls that cause infinite loops
	if _processing_player_moved:
		push_warning("[Game] Recursive _on_player_moved detected! old=%v new=%v" % [old_pos, new_pos])
		return

	_processing_player_moved = true

	# Update chunk loading for overworld
	if MapManager.current_map and MapManager.current_map.chunk_based:
		var chunk_update_start = Time.get_ticks_usec()
		ChunkManager.update_active_chunks(new_pos)
		var chunk_update_time = Time.get_ticks_usec() - chunk_update_start

		# Re-render map for chunk-based worlds (new chunks may have loaded)
		# Only re-render if player crossed chunk boundary
		var old_chunk = ChunkManagerClass.world_to_chunk(old_pos)
		var new_chunk = ChunkManagerClass.world_to_chunk(new_pos)
		if old_chunk != new_chunk:
			var render_start = Time.get_ticks_usec()
			game._full_render_needed = true  # New chunks loaded - need full render

			# Calculate visibility BEFORE rendering (features need visibility_data)
			var visibility_calc_start = Time.get_ticks_usec()
			game._update_visibility(false)  # Sets visibility_data but doesn't apply FOW
			var visibility_calc_time = Time.get_ticks_usec() - visibility_calc_start

			var map_render_start = Time.get_ticks_usec()
			game._render_map()
			var map_render_time = Time.get_ticks_usec() - map_render_start

			# NOTE: No need to call _render_ground_items() - _render_all_entities() handles it
			var entity_render_start = Time.get_ticks_usec()
			game._render_all_entities()
			var entity_render_time = Time.get_ticks_usec() - entity_render_start

			# Apply FOW to rendered entities
			var visibility_fow_start = Time.get_ticks_usec()
			game._update_visibility(true)  # Re-calculates and applies FOW
			var visibility_fow_time = Time.get_ticks_usec() - visibility_fow_start

			var total_render_time = Time.get_ticks_usec() - render_start
			print("[Game] Chunk crossing: chunk_update=%.2fms, vis_calc=%.2fms, map_render=%.2fms, entities=%.2fms, vis_fow=%.2fms, total=%.2fms" % [
				chunk_update_time / 1000.0,
				visibility_calc_time / 1000.0,
				map_render_time / 1000.0,
				entity_render_time / 1000.0,
				visibility_fow_time / 1000.0,
				total_render_time / 1000.0
			])

	# Clear old player position
	game.renderer.clear_entity(old_pos)

	# Re-render items/hazards/features at old position that were hidden under player
	# Render loot first, then hazards/features, then creatures (so creatures appear on top)
	game._render_ground_item_at(old_pos)
	game._render_feature_at(old_pos)
	game._render_hazard_at(old_pos)
	game._render_entity_at(old_pos)

	game.renderer.center_camera(new_pos)

	# In dungeons, wall visibility depends on player position
	# So we need to re-render the entire map when player moves
	var is_dungeon = MapManager.current_map and ("_floor_" in MapManager.current_map.map_id or MapManager.current_map.metadata.has("floor_number"))

	if is_dungeon:
		# Note: For dungeons, we still do full entity re-render every move
		# This is because dungeon entity counts are typically lower (20-30 vs 100+ in overworld)
		# and the incremental check overhead would negate the benefit
		# Calculate visibility BEFORE rendering (features/hazards need visibility_data for is_position_visible)
		game._update_visibility(false)  # Sets visibility_data but doesn't apply FOW yet
		# Re-render entire map with updated wall visibility
		game._full_render_needed = true  # _render_map() clears entity layer, need full re-render
		game._render_map()
		game._render_ground_items()  # Render loot first so creatures appear on top
		game._render_all_entities()  # Renders entities to entity layer
		# Apply FOW to rendered entities
		game._update_visibility(true)  # Re-calculates and applies FOW
	else:
		# Overworld: update visibility for incremental entity rendering
		# Entities are not fully re-rendered on every move, so FOW is applied to existing entities
		game._update_visibility()

	# CRITICAL: Render player AFTER everything else
	# Must be after visibility update so fog of war doesn't hide the player
	game.renderer.render_entity(new_pos, "@", Color.YELLOW)

	# Auto-pickup items at new position
	_auto_pickup_items()

	# If player stepped onto a structure, show a contextual message
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_at(new_pos, map_id)
	if structures.size() > 0:
		# Show only the first structure's message to avoid spamming
		var structure = structures[0]
		# Use "in" for shelters (player is inside), "near" for other structures
		var preposition = "in" if structure.has_component("shelter") else "near"
		var entry_msg = "You are %s %s." % [preposition, structure.name]
		if structure.has_component("fire"):
			var fire = structure.get_component("fire")
			var lit_text = "lit" if fire.is_lit else "unlit"
			entry_msg += " The fire is %s." % lit_text
		game._add_message(entry_msg, Color(0.9, 0.8, 0.6))

	# Check if standing on stairs and update message
	game._update_message()

	# Clear reentrancy guard
	_processing_player_moved = false


func _on_entity_moved(entity: Entity, old_pos: Vector2i, new_pos: Vector2i) -> void:
	game.renderer.clear_entity(old_pos)
	game.renderer.render_entity(new_pos, entity.ascii_char, entity.color)

	# NOTE: Don't mark enemy light cache dirty here - it causes too many rebuilds
	# Cache is invalidated once per turn via turn_advanced signal instead

	# Update target highlight if this entity is the current target
	if game.input_handler:
		var current_target = game.input_handler.get_current_target()
		if current_target and entity == current_target:
			game.update_target_highlight(current_target)


func _on_entity_visual_changed(pos: Vector2i) -> void:
	# CRITICAL: Clear tracking FIRST before clearing/re-rendering
	# This ensures incremental rendering knows this position needs updating
	if game._rendered_entities.has(pos):
		game._rendered_entities.erase(pos)

	# Clear existing entity rendering at position
	game.renderer.clear_entity(pos)

	# Force immediate entity layer flush to prevent ghost visuals
	# This is ONLY needed here for crop harvesting (not for general entity clearing)
	if game.renderer and game.renderer.has_method("_flush_entity_updates"):
		game.renderer._flush_entity_updates()


# =============================================================================
# MAP HANDLERS
# =============================================================================

func _on_map_changed(map_id: String) -> void:
	print("[Game] === Map change START: %s ===" % map_id)

	# Mark full render needed for new map
	game._full_render_needed = true

	# Skip entity handling during save load (SaveManager handles entities separately)
	if SaveManager.is_deserializing:
		print("[Game] Skipping entity handling during deserialization")
		# Still need to render the map
		if MapManager.current_map and MapManager.current_map.chunk_based and game.player:
			ChunkManager.update_active_chunks(game.player.position)
		game._render_map()
		if game.player:
			game.renderer.center_camera(game.player.position)
		print("[Game] === Map change COMPLETE (deserializing) ===")
		return

	# Invalidate FOV cache since map changed
	print("[Game] 1/8 Invalidating FOV cache")
	FOVSystemClass.invalidate_cache()

	# Mark enemy light cache as dirty (new map has different enemies)
	game._enemy_light_cache_dirty = true

	# Clear existing entities from EntityManager
	print("[Game] 2/8 Clearing entities")
	EntityManager.clear_entities()

	# Clear features and hazards when transitioning to overworld
	# This removes leftover dungeon features that could interfere with rendering
	# Overworld features will be spawned during chunk generation
	if MapManager.current_map and MapManager.current_map.chunk_based:
		print("[Game] 2/8 Clearing features/hazards for overworld transition")
		FeatureManager.clear_features()
		HazardManager.clear_hazards()

	# Setup fog of war for new map BEFORE chunk loading and rendering
	# This ensures renderer.current_map is set so is_position_visible() works for features/NPCs
	var fow_map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var fow_chunk_based = MapManager.current_map.chunk_based if MapManager.current_map else false
	print("[Game] 2.5/8 Setting renderer map info: map_id=%s, chunk_based=%s, map_set=%s" % [fow_map_id, fow_chunk_based, MapManager.current_map != null])
	game.renderer.set_map_info(fow_map_id, fow_chunk_based, MapManager.current_map)

	# Spawn or restore enemies for the new map
	print("[Game] 3/8 Spawning/restoring enemies")
	# Try to restore from saved state first (for visited maps)
	if not EntityManager.restore_entity_states_from_map(MapManager.current_map):
		# First visit - spawn from metadata
		game._spawn_map_enemies()

	# Load chunks at current player position before rendering
	# Player position has been set before map transition in input_handler
	if MapManager.current_map and MapManager.current_map.chunk_based and game.player:
		print("[Game] 4/8 Loading chunks at player position %v" % game.player.position)
		print("[Game] 4/8 Before chunk load: active_chunks=%d, cache=%d" % [ChunkManager.active_chunks.size(), ChunkManager.chunk_cache.size()])
		ChunkManager.update_active_chunks(game.player.position)
		print("[Game] 4/8 Chunks loaded, active count: %d" % ChunkManager.active_chunks.size())
		print("[Game] 4/8 After chunk load: features=%d, structures=%d, entities=%d" % [
			FeatureManager.active_features.size(),
			StructureManager.get_structures_on_map("overworld").size(),
			EntityManager.entities.size()
		])

	# Initialize light sources for new map (braziers, torches, etc.)
	# MUST happen before visibility calculation
	print("[Game] 5/8 Initializing light sources")
	game._initialize_light_sources_for_map()

	# Calculate visibility data BEFORE rendering (needed for features/hazards visibility checks)
	# But DON'T apply FOW yet - entity layer will be cleared and re-rendered
	print("[Game] 6/8 Calculating visibility data")
	game._update_visibility(false)  # Sets visibility_data but doesn't apply FOW

	# Render map (calls clear_all which clears entity layer)
	print("[Game] 7/8 Rendering map and entities")
	game._render_map()
	game._full_render_needed = true  # _render_map() calls clear_all(), must do full re-render
	game._render_all_entities()

	# Apply FOW to the rendered entities
	# This hides entities outside player's view
	print("[Game] 8/8 Applying fog of war to entities")
	game._update_visibility(true)  # Re-calculates and applies FOW to rendered entities

	# Re-render player at new position (ensure player renders on top)
	game.renderer.render_entity(game.player.position, "@", Color.YELLOW)
	game.renderer.center_camera(game.player.position)

	# Update message
	game._update_message()
	print("[Game] === Map change COMPLETE ===")


func _on_tile_changed(pos: Vector2i) -> void:
	if not MapManager.current_map:
		return

	# Re-render the changed tile (e.g., door opened/closed)
	var tile = MapManager.current_map.get_tile(pos)
	if tile:
		# Pass tile's color if it has one set (e.g., from biome data)
		if tile.color != Color.WHITE:
			game.renderer.render_tile(pos, tile.ascii_char, 0, tile.color)
		else:
			game.renderer.render_tile(pos, tile.ascii_char)

	# Invalidate FOV cache since tile transparency may have changed (doors, walls)
	FOVSystemClass.invalidate_cache()

	# Recalculate visibility when tiles change (doors open/close affects LOS)
	game._update_visibility()


func _on_chunk_loaded(chunk_coords: Vector2i) -> void:
	# Only trigger re-render if we're in chunk mode and have a player
	if not MapManager.current_map or not MapManager.current_map.chunk_based:
		return
	if not game.player:
		return

	# Check if this chunk is adjacent to or contains the player
	var player_chunk = ChunkManagerClass.world_to_chunk(game.player.position)
	var distance = max(abs(chunk_coords.x - player_chunk.x), abs(chunk_coords.y - player_chunk.y))

	# Only re-render for nearby chunks (within load radius)
	if distance <= ChunkManager.load_radius:
		game._full_render_needed = true
		# Calculate visibility data before rendering (features need visibility_data)
		game._update_visibility(false)
		game._render_map()
		game._render_all_entities()
		# Apply FOW to rendered entities
		game._update_visibility(true)
		# Re-render player on top
		game.renderer.render_entity(game.player.position, "@", Color.YELLOW)


# =============================================================================
# TURN AND TIME HANDLERS
# =============================================================================

func _on_turn_advanced(_turn_number: int) -> void:
	# Mark enemy light cache as dirty once per turn (enemies may have moved)
	# This is more efficient than marking it dirty on every enemy move
	game._enemy_light_cache_dirty = true

	game._update_hud()
	game._update_survival_display()


func _on_time_of_day_changed(new_time: String) -> void:
	# CRITICAL: Don't process time changes if player is dead
	# This prevents infinite loops in visibility calculations after death
	if not game.player or not game.player.is_alive:
		return

	# Refresh visibility using unified system (handles both LOS and lighting)
	# Time of day affects lighting calculations (day/night) and racial bonuses (darkvision)
	if MapManager.current_map:
		# Mark enemy light cache dirty since lighting conditions changed
		game._enemy_light_cache_dirty = true
		# Recalculate visibility with new lighting
		game._update_visibility()

	# Handle shop door locking on overworld
	if not MapManager.current_map or MapManager.current_map.map_id != "overworld":
		return

	var town_center = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	if town_center == Vector2i(-1, -1):
		return

	# Shop door position: shop is 5x5 centered on town_center, door at x=2, y=4 of shop
	# shop_start = town_center - Vector2i(2, 2)
	# door at shop_start + Vector2i(2, 4) = town_center + Vector2i(0, 2)
	var shop_door_pos = town_center + Vector2i(0, 2)

	if new_time == "night" or new_time == "midnight":
		_lock_shop_door_if_player_outside(shop_door_pos, town_center)
	elif new_time == "dawn":
		_unlock_shop_door(shop_door_pos)


## Lock shop door at night if player is outside
func _lock_shop_door_if_player_outside(door_pos: Vector2i, town_center: Vector2i) -> void:
	var tile = ChunkManager.get_tile(door_pos)
	if not tile or tile.tile_type != "door":
		return

	# Check if player is inside the shop (5x5 area centered on town_center)
	if game.player:
		var shop_start = town_center - Vector2i(2, 2)
		var shop_end = shop_start + Vector2i(4, 4)  # Inclusive bounds
		var player_inside = (game.player.position.x >= shop_start.x and game.player.position.x <= shop_end.x and
							 game.player.position.y >= shop_start.y and game.player.position.y <= shop_end.y)

		if player_inside:
			# Player is inside shop, don't lock them in
			return

	# Lock the door
	if not tile.is_locked:
		tile.is_locked = true
		tile.lock_id = "shop_door"
		tile.lock_level = 3  # Moderate difficulty
		# Close the door if open
		if tile.is_open:
			tile.close_door()
		EventBus.tile_changed.emit(door_pos)
		game._add_message("The shop door locks for the night.", Color.GRAY)


## Unlock shop door at dawn
func _unlock_shop_door(door_pos: Vector2i) -> void:
	var tile = ChunkManager.get_tile(door_pos)
	if not tile or tile.tile_type != "door":
		return

	if tile.is_locked and tile.lock_id == "shop_door":
		tile.is_locked = false
		EventBus.tile_changed.emit(door_pos)
		game._add_message("The shop door unlocks at dawn.", Color.GRAY)


# =============================================================================
# COMBAT HANDLERS
# =============================================================================

func _on_attack_performed(attacker: Entity, _defender: Entity, result: Dictionary) -> void:
	var is_player_attacker = (attacker == game.player)
	var message = CombatSystemClass.get_attack_message(result, is_player_attacker)

	# Determine message color
	var color: Color
	if result.hit:
		if result.defender_died:
			color = Color.RED
		elif is_player_attacker:
			color = Color(1.0, 0.6, 0.2)  # Orange - player dealing damage
		else:
			color = Color(1.0, 0.4, 0.4)  # Light red - taking damage
	else:
		color = Color(0.6, 0.6, 0.6)  # Gray for misses

	game._add_message(message, color)

	# Update HUD to show health changes
	# If player killed an enemy, award XP
	if result.defender_died and is_player_attacker and _defender and _defender is Enemy:
		var xp_gain = _defender.xp_value if "xp_value" in _defender else 0
		game.player.gain_experience(xp_gain)
		game._add_message("Gained %d XP." % xp_gain, Color(0.6, 0.9, 0.6))

	game._update_hud()


func _on_entity_died(entity: Entity) -> void:
	game.renderer.clear_entity(entity.position)

	# Check if it's the player
	if entity == game.player:
		EventBus.player_died.emit()
	else:
		var drop_messages: Array[String] = []
		var total_yields: Dictionary = {}

		if entity and entity is Enemy:
			# Process yields array (direct item drops defined on enemy)
			if entity.yields.size() > 0:
				for yield_data in entity.yields:
					var item_id = yield_data.get("item_id", "")
					var min_count = int(yield_data.get("min_count", 1))
					var max_count = int(yield_data.get("max_count", 1))
					var chance = float(yield_data.get("chance", 1.0))
					if randf() > chance:
						continue
					var range_size = max_count - min_count + 1
					var count = min_count + (randi() % max(1, range_size))
					if count > 0:
						if item_id in total_yields:
							total_yields[item_id] += count
						else:
							total_yields[item_id] = count

			# Process loot tables (creature type defaults + entity-specific, with CR scaling)
			var loot_drops = LootTableManager.generate_loot_for_entity(entity)
			for drop in loot_drops:
				var item_id = drop.get("item_id", "")
				var count = drop.get("count", 1)
				if item_id != "" and count > 0:
					if item_id in total_yields:
						total_yields[item_id] += count
					else:
						total_yields[item_id] = count

			# Create and spawn items as ground items
			for item_id in total_yields:
				var count = total_yields[item_id]
				var stacks = ItemManager.create_item_stacks(item_id, count)
				for it in stacks:
					EntityManager.spawn_ground_item(it, entity.position)
				var item_data = ItemManager.get_item_data(item_id)
				if item_data:
					drop_messages.append("%d %s" % [count, item_data.get("name", item_id)])

			if drop_messages.size() > 0:
				game._add_message("Dropped: %s" % ", ".join(drop_messages), Color(0.8, 0.8, 0.6))
				game._render_ground_item_at(entity.position)

		# Remove entity from managers
		EntityManager.remove_entity(entity)


func _on_player_died() -> void:
	print("[Game] !!! _on_player_died() called - Player has died !!!")
	game._add_message("", Color.WHITE)  # Blank line
	game._add_message("*** YOU HAVE DIED ***", Color.RED)

	print("[Game] Collecting player stats for death screen...")
	# Collect player stats for death screen
	var player_stats = {
		"turns": TurnManager.current_turn,
		"experience": game.player.experience if game.player else 0,
		"gold": game.player.gold if game.player else 0,
		"recipes_discovered": game.player.known_recipes.size() if game.player else 0,
		"structures_built": 0,  # TODO: Track this if needed
		"death_cause": game.player.death_cause if game.player else "",
		"death_method": game.player.death_method if game.player else "",
		"death_location": game.player.death_location if game.player else ""
	}

	print("[Game] Opening death screen...")
	# Show death screen with stats
	if game.death_screen:
		game.death_screen.open(player_stats)
		print("[Game] Death screen opened successfully")
	else:
		print("[Game] ERROR: death_screen is null!")

	print("[Game] _on_player_died() complete")


func _on_combat_message(message: String, color: Color) -> void:
	print("[DEBUG] _on_combat_message received: '%s'" % message)
	game._add_message(message, color)


# =============================================================================
# PLAYER PROGRESSION HANDLERS
# =============================================================================

func _on_player_leveled_up(new_level: int, skill_points_gained: int, gained_ability_point: bool) -> void:
	# Display congratulatory message with banner-style formatting
	game._add_message("", Color.WHITE)  # Blank line
	game._add_message("*** LEVEL UP! ***", Color(1.0, 0.85, 0.3))  # Gold
	game._add_message("You have reached Level %d!" % new_level, Color(0.7, 0.95, 0.7))  # Light green
	game._add_message("Gained %d skill point%s." % [skill_points_gained, "s" if skill_points_gained != 1 else ""], Color(0.7, 0.85, 0.95))  # Light blue

	if gained_ability_point:
		game._add_message("You may increase one ability score!", Color(0.95, 0.7, 0.85))  # Light pink

	game._add_message("Open Character Screen (P) to spend points.", Color.WHITE)
	game._add_message("", Color.WHITE)  # Blank line

	game._update_hud()


# =============================================================================
# SURVIVAL HANDLERS
# =============================================================================

func _on_survival_warning(message: String, severity: String) -> void:
	var color: Color
	match severity:
		"critical":
			color = Color.RED
		"severe":
			color = Color(1.0, 0.4, 0.2)  # Orange-red
		"warning":
			color = Color(1.0, 0.7, 0.2)  # Orange
		_:
			color = Color(0.8, 0.8, 0.5)  # Dim yellow

	game._add_message(message, color)


func _on_stamina_depleted() -> void:
	# Debounce: Only show message once per 3 turns to avoid spam
	var current_turn = TurnManager.current_turn if TurnManager else 0
	if current_turn - _last_stamina_warning_turn < 3:
		return

	_last_stamina_warning_turn = current_turn
	game._add_message("You are out of stamina!", Color(1.0, 0.5, 0.5))


# =============================================================================
# ITEM HANDLERS
# =============================================================================

func _on_item_picked_up(item) -> void:
	game._add_message("Picked up: %s" % item.name, Color(0.6, 0.9, 0.6))
	# Re-render to update ground items
	game._render_ground_items()


func _on_item_dropped(item, pos: Vector2i) -> void:
	game._add_message("Dropped: %s" % item.name, Color(0.7, 0.7, 0.7))
	# Re-render to show dropped item
	var render_color = item.get_color()
	# Lit light sources get a bright orange/yellow color
	if item.provides_light and item.is_lit:
		render_color = Color(1.0, 0.7, 0.2)
		# Update visibility since we dropped a light source
		game._update_visibility()
	game.renderer.render_entity(pos, item.ascii_char, render_color)
	game._update_hud()


func _on_item_used(_item, _result: Dictionary) -> void:
	game._update_hud()


func _on_item_equipped(item, _slot: String) -> void:
	# Auto-light torches and other burnable light sources when equipped
	if item.provides_light and item.burns_per_turn > 0 and not item.is_lit:
		item.is_lit = true
		game._add_message("You light the %s." % item.name, Color(1.0, 0.8, 0.4))
		# Update visibility since we now have a light source
		game._update_visibility()


func _on_item_unequipped(item, _slot: String) -> void:
	# When a lit torch is unequipped (but not dropped), it stays lit
	# The light source will be recalculated on next visibility update
	if item.provides_light and item.is_lit:
		game._update_visibility()


func _on_inventory_changed() -> void:
	if game.inventory_screen and game.inventory_screen.visible:
		game.inventory_screen.refresh()


func _on_message_logged(message: String) -> void:
	game._add_message(message, Color.WHITE)


# =============================================================================
# STRUCTURE HANDLERS
# =============================================================================

func _on_structure_placed(_structure: Structure) -> void:
	# Note: Message is already logged via result.message in _try_place_structure/_try_place_structure_at_cursor
	# Clear build mode state
	game.build_mode_active = false
	game.selected_structure_id = ""
	game.build_cursor_offset = Vector2i(1, 0)
	game.input_handler.set_ui_blocking(false)  # Re-enable player movement
	# Re-render map to clear cursor and show the new structure
	# Force full entity re-render since _render_map() clears the entity layer
	game._full_render_needed = true
	game._render_map()
	game._render_ground_items()
	game._render_all_entities()
	game.renderer.render_entity(game.player.position, "@", Color.YELLOW)


# =============================================================================
# NPC / SHOP HANDLERS
# =============================================================================

func _on_shop_opened(shop_npc: NPC, shop_player: Player) -> void:
	if game.shop_screen and shop_player:
		game.ui_coordinator.open("shop", [shop_player, shop_npc])


func _on_training_opened(trainer_npc: NPC, train_player: Player) -> void:
	if game.training_screen and train_player:
		game.ui_coordinator.open("training", [train_player, trainer_npc])


func _on_npc_menu_opened(menu_npc: NPC, menu_player: Player) -> void:
	if game.npc_menu_screen and menu_player:
		game.ui_coordinator.open("npc_menu", [menu_player, menu_npc])


# =============================================================================
# MODE CHANGE HANDLERS
# =============================================================================

func _on_harvesting_mode_changed(is_active: bool) -> void:
	game._update_toggles_display()
	if is_active:
		game._add_message("Entered harvesting mode - keep pressing direction to continue", Color(0.6, 0.9, 0.6))


func _on_sprint_mode_changed(_is_active: bool) -> void:
	game._update_toggles_display()


# =============================================================================
# WEATHER HANDLERS
# =============================================================================

func _on_weather_changed(_old_weather: String, _new_weather: String, message: String) -> void:
	if message != "":
		# Get weather color for the message
		var weather_color = WeatherManager.get_current_weather_color()
		game._add_message(message, weather_color)


# =============================================================================
# UI / FEEDBACK HANDLERS
# =============================================================================

func _on_ritual_menu_requested() -> void:
	if game.ritual_menu and game.player:
		game.ui_coordinator.open("ritual", [game.player])


func _on_perf_overlay_toggle() -> void:
	if game.perf_overlay:
		game.perf_overlay_enabled = not game.perf_overlay_enabled
		game.perf_overlay.visible = game.perf_overlay_enabled
		if game.perf_overlay_enabled:
			game._add_message("Performance overlay enabled", Color(0.5, 1.0, 0.5))
		else:
			game._add_message("Performance overlay disabled", Color(0.7, 0.7, 0.7))
	# Refresh rendering to show spawned entities/items and tile changes
	game._full_render_needed = true  # _render_map() clears entity layer
	game._render_map()
	game._render_ground_items()
	game._render_all_entities()
	game.renderer.render_entity(game.player.position, "@", Color.YELLOW)
	game._update_visibility()


# =============================================================================
# FEATURE / ENEMY SPAWN HANDLERS
# =============================================================================

func _on_feature_spawned_enemy(enemy_id: String, spawn_position: Vector2i) -> void:
	print("[Game] Feature spawned enemy: %s at %v" % [enemy_id, spawn_position])
	# Find a valid spawn position near the feature (not on the feature itself)
	var spawn_pos = _find_nearby_spawn_position(spawn_position)
	if spawn_pos != Vector2i(-1, -1):
		var enemy = EntityManager.spawn_enemy(enemy_id, spawn_pos)
		if enemy:
			game._add_message("A %s emerges!" % enemy.name, Color.ORANGE_RED)
			game._render_all_entities()
	else:
		push_warning("[Game] Could not find spawn position for feature enemy near %v" % spawn_position)


# =============================================================================
# HELPER METHODS (only used by handlers)
# =============================================================================

## Auto-pickup items at the player's position
func _auto_pickup_items() -> void:
	if not game.player or not GameManager.auto_pickup_enabled:
		return

	var ground_items = EntityManager.get_ground_items_at(game.player.position)
	for ground_item in ground_items:
		if game.player.pickup_item(ground_item):
			EntityManager.remove_entity(ground_item)
		else:
			# Pickup failed - provide feedback (only show once per position)
			if ground_item and ground_item.item:
				game._add_message("Cannot pick up %s (inventory full or too heavy)" % ground_item.item.name, Color(0.9, 0.6, 0.4))


## Find a valid spawn position near a given position
func _find_nearby_spawn_position(center: Vector2i) -> Vector2i:
	# Check adjacent tiles for valid spawn position
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	for dir in directions:
		var pos = center + dir
		if MapManager.current_map and MapManager.current_map.is_walkable(pos):
			# Make sure no blocking entity is already there (player is not in entities array)
			if not EntityManager.get_blocking_entity_at(pos) and game.player.position != pos:
				return pos
	return Vector2i(-1, -1)
