class_name WorldChunk

## WorldChunk - Represents a 32x32 section of the world
##
## Chunks are the fundamental unit of map streaming - only active chunks are kept in memory.
## Each chunk generates deterministically from a seed based on its coordinates.

# Preload required scripts for town generation
const TownGeneratorScript = preload("res://generation/town_generator.gd")

const CHUNK_SIZE: int = 32  # 32x32 tiles per chunk

var chunk_coords: Vector2i  # Chunk grid position (e.g., 0,0 or 2,1)
var tiles: Dictionary  # Vector2i (local 0-31) -> GameTile
var resources: Array  # Array of ResourceSpawner.ResourceInstance
var seed: int  # Deterministic generation seed
var is_loaded: bool  # Currently in memory and rendered
var is_dirty: bool  # Needs re-rendering

func _init(coords: Vector2i, world_seed: int) -> void:
	chunk_coords = coords
	tiles = {}
	resources = []
	is_loaded = false
	is_dirty = false

	# Generate unique but deterministic seed for this chunk
	# Using Cantor pairing function: (a + b) * (a + b + 1) / 2 + b
	var a = coords.x + 1000  # Offset to ensure positive
	var b = coords.y + 1000
	var pairing = (a + b) * (a + b + 1) / 2 + b
	seed = hash(world_seed + pairing)

## Generate chunk content (terrain + resources)
func generate(world_seed: int) -> void:
	##print("[WorldChunk] Generating chunk %v with seed %d" % [chunk_coords, seed])

	var rng = SeededRandom.new(seed)

	# Check if this chunk contains special features
	var map = MapManager.current_map
	var dungeon_entrances: Array = map.get_meta("dungeon_entrances", []) if map else []

	# Support both new multi-town system and legacy single town
	var towns_data: Array = map.metadata.get("towns", []) if map else []
	var town_center_pos = map.get_meta("town_center", Vector2i(-1, -1)) if map else Vector2i(-1, -1)

	# If no towns array but legacy town_center exists, create a placeholder
	if towns_data.is_empty() and town_center_pos != Vector2i(-1, -1):
		towns_data = [{
			"town_id": "starter_town",
			"position": town_center_pos,
			"size": Vector2i(15, 15)
		}]

	# Build a dictionary of entrance positions for quick lookup
	var entrance_lookup: Dictionary = {}
	for entrance in dungeon_entrances:
		entrance_lookup[entrance.position] = entrance

	# Build a dictionary of road positions for quick lookup (to avoid spawning resources on roads)
	var road_positions: Dictionary = {}
	var road_paths_data: Array = map.metadata.get("road_paths", []) if map else []
	for road_path in road_paths_data:
		var points: Array = road_path.get("points", [])
		for point_data in points:
			var pos_value = point_data.get("pos")
			var world_pos: Vector2i
			if pos_value is Vector2i:
				world_pos = pos_value
			elif pos_value is Array:
				world_pos = Vector2i(pos_value[0], pos_value[1])
			else:
				continue
			road_positions[world_pos] = true

	# Generate all tiles in chunk using biome system
	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var world_pos = chunk_to_world_position(Vector2i(local_x, local_y))

			# Get biome at world position
			var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

			# Create base tile from biome
			var tile = GameTile.create(biome.base_tile)

			# Override character and color for visual variety based on biome
			if biome.base_tile == "floor":
				tile.ascii_char = biome.grass_char
				# Set color based on whether it's a grass character or floor
				if biome.grass_char == ".":
					tile.color = biome.color_floor
				else:
					tile.color = biome.color_grass
			elif biome.base_tile == "water":
				# Water tiles keep their blue color from tile definition (#3366FF)
				# Don't override - swamp/marsh water should still be blue, not green
				pass

			# Check for dungeon entrances at this position
			if world_pos in entrance_lookup:
				var entrance = entrance_lookup[world_pos]
				# Create a dungeon entrance tile with custom appearance
				tile = GameTile.create("dungeon_entrance")
				tile.ascii_char = entrance.entrance_char
				tile.color = Color.html(entrance.entrance_color)
				tile.set_meta("dungeon_type", entrance.dungeon_type)
				tile.set_meta("dungeon_name", entrance.name)
				#print("[WorldChunk] Placed %s entrance at %v" % [entrance.dungeon_type, world_pos])
			else:
				# Check if within any town area
				var in_town = _is_in_any_town(world_pos, towns_data)
				if in_town:
					# This tile is within town boundary
					# Town structures will be generated after base terrain
					# For now, just ensure it's walkable floor
					if tile.tile_type != "floor":
						tile = GameTile.create("floor")
						tile.ascii_char = biome.grass_char
						if biome.grass_char == ".":
							tile.color = biome.color_floor
						else:
							tile.color = biome.color_grass

			tiles[Vector2i(local_x, local_y)] = tile

			# Try to spawn resources on floor tiles (skip in town areas and on road paths)
			var min_dist_to_town = _get_min_distance_to_towns(world_pos, towns_data)
			var is_on_road = world_pos in road_positions
			if tile.walkable and tile.tile_type == "floor" and min_dist_to_town > 10 and not is_on_road:
				# Try to spawn tree
				if rng.randf() < biome.tree_density:
					var resource_instance = ResourceSpawner.ResourceInstance.new("tree", world_pos, chunk_coords)
					resources.append(resource_instance)

					# Mark tile as non-walkable
					tile.walkable = false
					tile.transparent = false
					tile.ascii_char = "T"
					tile.harvestable_resource_id = "tree"
					tile.color = Color.WHITE
					continue  # Don't spawn rock in same spot

				# Try to spawn rock
				if rng.randf() < biome.rock_density:
					var resource_instance = ResourceSpawner.ResourceInstance.new("rock", world_pos, chunk_coords)
					resources.append(resource_instance)

					# Mark tile as non-walkable
					tile.walkable = false
					tile.transparent = false
					tile.ascii_char = "◆"
					tile.harvestable_resource_id = "rock"
					tile.color = Color.WHITE
					continue  # Don't spawn flora in same spot

				# Try to spawn herb (now spawned as features for auto-pickup)
				var herb_density = biome.get("herb_density", 0.0)
				if herb_density > 0 and rng.randf() < herb_density:
					var biome_id = biome.get("id", "woodland")
					FeatureManager.spawn_overworld_feature("wild_herb_feature", world_pos, biome_id, map)
					continue  # Don't spawn other flora in same spot

				# Try to spawn flower (now spawned as features for auto-pickup)
				var flower_density = biome.get("flower_density", 0.0)
				if flower_density > 0 and rng.randf() < flower_density:
					var biome_id = biome.get("id", "woodland")
					FeatureManager.spawn_overworld_feature("wild_flower_feature", world_pos, biome_id, map)
					continue  # Don't spawn other flora in same spot

				# Try to spawn mushroom (now spawned as features for auto-pickup)
				var mushroom_density = biome.get("mushroom_density", 0.0)
				if mushroom_density > 0 and rng.randf() < mushroom_density:
					var biome_id = biome.get("id", "woodland")
					FeatureManager.spawn_overworld_feature("wild_mushroom_feature", world_pos, biome_id, map)

	# Generate town structures for any towns whose center is in this chunk
	_generate_towns_in_chunk(towns_data, world_seed)

	# Place inter-town road tiles that fall within this chunk
	var road_paths: Array = map.metadata.get("road_paths", []) if map else []
	_place_road_tiles_in_chunk(road_paths, world_seed)

	# Spawn overworld enemies using data-driven biome and town distance filtering
	_spawn_overworld_enemies(towns_data, rng)

	is_loaded = true
	is_dirty = true


## Check if a position is within any town's bounds
func _is_in_any_town(world_pos: Vector2i, towns_data: Array) -> bool:
	for town in towns_data:
		var town_pos = _get_town_position(town)
		var town_size = _get_town_size(town)
		var half_size = town_size / 2
		var town_rect = Rect2i(town_pos - half_size, town_size)
		if town_rect.has_point(world_pos):
			return true
	return false


## Get minimum distance to any town center
func _get_min_distance_to_towns(world_pos: Vector2i, towns_data: Array) -> float:
	var min_dist = 999.0
	for town in towns_data:
		var town_pos = _get_town_position(town)
		var dist = (world_pos - town_pos).length()
		if dist < min_dist:
			min_dist = dist
	return min_dist


## Extract town position from town data (handles both Vector2i and array formats)
func _get_town_position(town: Dictionary) -> Vector2i:
	var pos = town.get("position", Vector2i(-1, -1))
	if pos is Array:
		return Vector2i(pos[0], pos[1])
	return pos


## Extract town size from town data (handles both Vector2i and array formats)
func _get_town_size(town: Dictionary) -> Vector2i:
	var size = town.get("size", Vector2i(15, 15))
	if size is Array:
		return Vector2i(size[0], size[1])
	return size


## Generate town structures for towns that overlap with this chunk
func _generate_towns_in_chunk(towns_data: Array, world_seed: int) -> void:
	# Get TownManager singleton through Engine
	var town_manager = Engine.get_singleton("TownManager") if Engine.has_singleton("TownManager") else null
	if not town_manager:
		# Fallback: try to get from tree (autoload)
		town_manager = _get_autoload("TownManager")

	# Get this chunk's world bounds
	var chunk_bounds = get_world_bounds()
	var chunk_rect = Rect2i(chunk_bounds.min, Vector2i(CHUNK_SIZE, CHUNK_SIZE))

	for town in towns_data:
		var town_pos = _get_town_position(town)
		var town_size = _get_town_size(town)

		# Calculate town bounding rect (with extra padding for building offsets)
		# Buildings can have offsets up to half the town size, so use town_size as padding
		var town_rect = Rect2i(town_pos - town_size, town_size * 2)

		# Check if town bounds overlap with this chunk
		if not chunk_rect.intersects(town_rect):
			continue

		var town_id = town.get("town_id", "starter_town")

		# Determine if this is the "primary" chunk for this town (contains the center)
		var town_chunk = Vector2i(
			floori(float(town_pos.x) / CHUNK_SIZE),
			floori(float(town_pos.y) / CHUNK_SIZE)
		)
		var is_primary_chunk = (chunk_coords == town_chunk)

		#print("[WorldChunk] Generating %s structures in chunk %v (primary=%s)" % [town_id, chunk_coords, is_primary_chunk])

		# Get definitions from TownManager (or use defaults)
		var town_def: Dictionary = {}
		var building_defs: Dictionary = {}
		if town_manager:
			town_def = town_manager.get_town(town_id)
			building_defs = town_manager.building_definitions
		else:
			# Fallback to default definitions
			town_def = _get_default_town_def()
			building_defs = _get_default_building_defs()

		# Convert tiles dict from local to world coords for TownGenerator
		var world_tiles: Dictionary = {}
		for local_pos in tiles:
			var world_pos_tile = chunk_to_world_position(local_pos)
			world_tiles[world_pos_tile] = tiles[local_pos]

		# Generate using data-driven TownGenerator
		var result = TownGeneratorScript.generate_town(town_id, town_pos, world_seed, world_tiles, town_def, building_defs)

		# Copy generated tiles back to chunk local coordinates
		for world_pos_tile in world_tiles:
			var local_pos = world_to_chunk_position(world_pos_tile)
			if local_pos.x >= 0 and local_pos.x < CHUNK_SIZE and local_pos.y >= 0 and local_pos.y < CHUNK_SIZE:
				tiles[local_pos] = world_tiles[world_pos_tile]

		# Only spawn NPCs, crops, and register town from the primary chunk to avoid duplicates
		if is_primary_chunk:
			if result.has("npc_spawns") and result.npc_spawns.size() > 0:
				_spawn_town_npcs(result.npc_spawns, town_id)

			# Spawn crops if the town has crop fields
			if result.has("crop_spawns") and result.crop_spawns.size() > 0:
				_spawn_town_crops(result.crop_spawns, town_id)

			# Register town with TownManager
			if town_manager:
				town_manager.add_placed_town(result)


## Helper to get autoload node
func _get_autoload(autoload_name: String) -> Node:
	# Access autoload through the scene tree root
	var root = Engine.get_main_loop()
	if root and root is SceneTree:
		return root.root.get_node_or_null("/root/" + autoload_name)
	return null


## Default town definition for fallback
func _get_default_town_def() -> Dictionary:
	return {
		"id": "starter_town",
		"name": "Settlement",
		"size": [15, 15],
		"is_safe_zone": true,
		"buildings": [
			{"building_id": "shop", "position_offset": [0, 0], "npc_id": "shop_keeper"},
			{"building_id": "well", "position_offset": [4, 4]}
		],
		"decorations": {"perimeter_trees": true, "max_trees": 12}
	}


## Default building definitions for fallback
func _get_default_building_defs() -> Dictionary:
	return {
		"shop": {
			"id": "shop",
			"size": [5, 5],
			"template_type": "building",
			"door_position": "south",
			"npc_offset": [2, 2]
		},
		"well": {
			"id": "well",
			"size": [1, 1],
			"template_type": "feature",
			"tile_type": "water"
		}
	}


## Place inter-town road tiles that fall within this chunk
func _place_road_tiles_in_chunk(road_paths: Array, _world_seed: int) -> void:
	if road_paths.is_empty():
		return

	# Get towns data for boundary checking
	var map = MapManager.current_map
	var towns_data: Array = map.metadata.get("towns", []) if map else []

	# Get building footprints to avoid placing roads inside buildings
	var building_positions: Dictionary = _get_all_building_positions()

	var bounds = get_world_bounds()
	var chunk_rect = Rect2i(bounds.min, Vector2i(CHUNK_SIZE, CHUNK_SIZE))

	for road_path in road_paths:
		var points: Array = road_path.get("points", [])

		for point_data in points:
			var world_pos: Vector2i
			var pos_value = point_data.get("pos")
			if pos_value is Vector2i:
				world_pos = pos_value
			elif pos_value is Array:
				world_pos = Vector2i(pos_value[0], pos_value[1])
			else:
				continue

			# Check if this point is within this chunk
			if not chunk_rect.has_point(world_pos):
				continue

			var local_pos = world_to_chunk_position(world_pos)
			var road_type = point_data.get("type", "road_dirt")

			# Get existing tile at this position
			if local_pos not in tiles:
				continue

			var existing_tile = tiles[local_pos]

			# Don't replace special structures (but do allow replacing trees/rocks for roads)
			if existing_tile.tile_type in ["wall", "door", "dungeon_entrance", "stairs_down", "stairs_up"]:
				continue

			# Don't replace interior floor tiles (inside buildings)
			if existing_tile.is_interior:
				continue

			# Don't place roads inside building footprints (handles cross-chunk buildings)
			if world_pos in building_positions:
				continue

			# Don't place roads inside town boundaries at all
			if _is_in_any_town(world_pos, towns_data):
				continue

			# Don't replace wells
			if existing_tile.tile_type == "well":
				continue

			# Handle natural water - use bridges
			if existing_tile.tile_type == "water":
				var bridge_type = "bridge_stone" if road_type == "road_cobblestone" else "bridge_wood"
				tiles[local_pos] = GameTile.create(bridge_type)
				continue

			# Replace floor/grass tiles and resources (trees/rocks) with road
			if existing_tile.tile_type in ["floor", "tree", "rock"]:
				tiles[local_pos] = GameTile.create(road_type)


## Get all building positions from towns that overlap with this chunk
## Returns a Dictionary of world positions that are inside any building footprint
## For custom layouts, only includes non-space tiles to allow roads in irregular building shapes
func _get_all_building_positions() -> Dictionary:
	var positions: Dictionary = {}
	var map = MapManager.current_map
	if not map:
		return positions

	var towns_data: Array = map.metadata.get("towns", []) if map else []

	# Get TownManager for building definitions
	var town_manager = _get_autoload("TownManager")
	if not town_manager:
		return positions

	for town in towns_data:
		var town_id = town.get("town_id", "starter_town")
		var town_pos = _get_town_position(town)
		var town_def = town_manager.get_town(town_id)
		if town_def.is_empty():
			continue

		var buildings = town_def.get("buildings", [])
		for building_entry in buildings:
			var building_id = building_entry.get("building_id", "")
			var building_def = town_manager.building_definitions.get(building_id, {})
			if building_def.is_empty():
				continue

			# Get building position
			var offset_array = building_entry.get("position_offset", [0, 0])
			var offset = Vector2i(offset_array[0], offset_array[1])
			var building_pos = town_pos + offset

			# Get building size and handle rotation
			var size_array = building_def.get("size", [5, 5])
			var size = Vector2i(size_array[0], size_array[1])
			var door_facing = building_entry.get("door_facing", "south")
			var rotated_size = size if door_facing in ["south", "north"] else Vector2i(size.y, size.x)
			var half_size = rotated_size / 2
			var start = building_pos - half_size

			# Check if this is a custom layout building
			var template_type = building_def.get("template_type", "building")
			var layout = building_def.get("layout", null)

			if template_type == "custom" and layout != null:
				# For custom layouts, only add non-space positions
				var rotated_layout = _rotate_layout(layout, door_facing)
				for y in range(min(rotated_layout.size(), rotated_size.y)):
					var row = rotated_layout[y]
					for x in range(min(row.length(), rotated_size.x)):
						var tile_char = row[x]
						if tile_char != " ":
							var world_pos = start + Vector2i(x, y)
							positions[world_pos] = true
			else:
				# Standard buildings use full rectangular footprint
				for x in range(rotated_size.x):
					for y in range(rotated_size.y):
						var world_pos = start + Vector2i(x, y)
						positions[world_pos] = true

	return positions

## Rotate a layout array based on door facing direction (for building position calculation)
## Mirrors the rotation logic from TownGenerator
static func _rotate_layout(layout: Array, door_facing: String) -> Array:
	if door_facing == "south":
		return layout  # No rotation needed

	var height = layout.size()
	if height == 0:
		return layout
	var width = layout[0].length()

	var rotated: Array = []

	match door_facing:
		"north":
			# 180 degree rotation
			for y in range(height - 1, -1, -1):
				var new_row = ""
				var row = layout[y]
				for x in range(width - 1, -1, -1):
					new_row += row[x] if x < row.length() else " "
				rotated.append(new_row)
		"east":
			# 90 degrees clockwise
			for x in range(width):
				var new_row = ""
				for y in range(height - 1, -1, -1):
					var row = layout[y]
					new_row += row[x] if x < row.length() else " "
				rotated.append(new_row)
		"west":
			# 90 degrees counter-clockwise
			for x in range(width - 1, -1, -1):
				var new_row = ""
				for y in range(height):
					var row = layout[y]
					new_row += row[x] if x < row.length() else " "
				rotated.append(new_row)

	return rotated


## Spawn overworld enemies using data-driven biome and town distance filtering
func _spawn_overworld_enemies(towns_data: Array, rng: SeededRandom) -> void:
	var entity_manager = _get_autoload("EntityManager")
	if not entity_manager:
		return

	# Get current map for storing enemy spawns
	var map = MapManager.current_map
	if not map:
		return

	# Collect floor tile positions in this chunk
	var floor_positions: Array[Vector2i] = []
	for local_pos in tiles:
		var tile = tiles[local_pos]
		if tile.walkable and tile.tile_type == "floor":
			var world_pos = chunk_to_world_position(local_pos)
			floor_positions.append(world_pos)

	if floor_positions.is_empty():
		return

	# Calculate spawn count based on chunk size
	# 20% chance of no enemies, 30% chance of 1, 30% chance of 2, 20% chance of 3
	var spawn_roll = rng.randf()
	var spawn_count: int = 0
	if spawn_roll > 0.2:
		spawn_count = 1
		if spawn_roll > 0.5:
			spawn_count = 2
			if spawn_roll > 0.8:
				spawn_count = 4
				if spawn_roll > 0.95:
					spawn_count = 8
	var spawned: int = 0

	# Shuffle positions for random placement
	var shuffled_positions: Array[Vector2i] = floor_positions.duplicate()
	for i in range(shuffled_positions.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = shuffled_positions[i]
		shuffled_positions[i] = shuffled_positions[j]
		shuffled_positions[j] = temp

	for spawn_pos in shuffled_positions:
		if spawned >= spawn_count:
			break

		# Get minimum distance to any town
		var min_town_dist = _get_min_distance_to_towns(spawn_pos, towns_data)

		# Skip positions too close to towns (safe zone)
		if min_town_dist < 15:
			continue

		# Get biome at this position
		var biome = BiomeGenerator.get_biome_at(spawn_pos.x, spawn_pos.y, seed)
		var biome_id = biome.get("id", "grassland")

		# Get weighted enemies for this biome
		var weighted_enemies = entity_manager.get_weighted_enemies_for_biome(biome_id)
		if weighted_enemies.is_empty():
			continue

		# Filter by min_distance_from_town
		var valid_enemies: Array = []
		for enemy_data in weighted_enemies:
			var min_dist_required = enemy_data.get("min_distance_from_town", 0)
			if min_town_dist >= min_dist_required:
				valid_enemies.append(enemy_data)

		if valid_enemies.is_empty():
			continue

		# Pick weighted random enemy
		var chosen_enemy_id = _pick_weighted_enemy(valid_enemies, rng)
		if chosen_enemy_id.is_empty():
			continue

		# Store spawn data in map metadata
		if not map.metadata.has("enemy_spawns"):
			map.metadata["enemy_spawns"] = []
		map.metadata.enemy_spawns.append({
			"enemy_id": chosen_enemy_id,
			"position": spawn_pos,
			"level": 1,  # Overworld enemies are level 1
			"chunk": chunk_coords
		})

		spawned += 1

	if spawned > 0:
		#print("[WorldChunk] Spawned %d enemies in chunk %v" % [spawned, chunk_coords])
		pass


## Pick a weighted random enemy from a list of {enemy_id, weight} entries
func _pick_weighted_enemy(weighted_enemies: Array, rng: SeededRandom) -> String:
	if weighted_enemies.is_empty():
		return ""

	var total_weight: float = 0.0
	for entry in weighted_enemies:
		total_weight += entry.get("weight", 1.0)

	if total_weight <= 0:
		return ""

	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0

	for entry in weighted_enemies:
		cumulative += entry.get("weight", 1.0)
		if roll <= cumulative:
			return entry.get("enemy_id", "")

	return weighted_enemies[weighted_enemies.size() - 1].get("enemy_id", "")


## Spawn NPCs directly via EntityManager
func _spawn_town_npcs(npc_spawns: Array, town_id: String) -> void:
	var entity_manager = _get_autoload("EntityManager")
	if not entity_manager:
		push_warning("[WorldChunk] EntityManager not available for NPC spawning")
		return

	# Get MapManager to store NPC spawn data for respawning after map transitions
	var map_manager = _get_autoload("MapManager")

	for spawn in npc_spawns:
		spawn["town_id"] = town_id
		entity_manager.spawn_npc(spawn)

		# Store spawn data in map metadata so NPCs can be respawned after dungeon return
		if map_manager and map_manager.current_map:
			var metadata_spawns = map_manager.current_map.metadata.get("npc_spawns", [])
			metadata_spawns.append(spawn)
			map_manager.current_map.metadata["npc_spawns"] = metadata_spawns

	#print("[WorldChunk] Spawned %d NPCs for %s" % [npc_spawns.size(), town_id])

## Spawn crops for farm fields
func _spawn_town_crops(crop_spawns: Array, town_id: String) -> void:
	var entity_manager = _get_autoload("EntityManager")
	if not entity_manager:
		push_warning("[WorldChunk] EntityManager not available for crop spawning")
		return

	# Load FarmingSystem to get crop definitions
	var crop_count = 0
	for spawn in crop_spawns:
		var crop_id = spawn.get("crop_id", "")
		var pos = spawn.get("position", Vector2i.ZERO)
		var mature = spawn.get("mature", false)

		if crop_id.is_empty():
			continue

		# Get crop definition from FarmingSystem
		var crop_data = FarmingSystem.get_crop_definition(crop_id)
		if crop_data.is_empty():
			push_warning("[WorldChunk] Unknown crop type: %s" % crop_id)
			continue

		# Create the crop entity
		var CropEntityClass = preload("res://entities/crop_entity.gd")
		var crop = CropEntityClass.create(crop_id, pos, crop_data)

		# If mature, advance to final growth stage
		if mature:
			var stages = crop_data.get("growth_stages", [])
			if stages.size() > 0:
				crop.current_stage = stages.size() - 1
				crop.turns_in_stage = 0
				crop._update_visual()

		# Register with FarmingSystem
		var map_id = "overworld"  # Farm is on overworld
		var key = "%s:%d,%d" % [map_id, pos.x, pos.y]
		FarmingSystem._active_crops[key] = crop

		# Add to EntityManager
		entity_manager.entities.append(crop)
		crop_count += 1

	#print("[WorldChunk] Spawned %d crops for %s" % [crop_count, town_id])

## Get tile at local coordinates (0-31)
func get_tile(local_pos: Vector2i) -> GameTile:
	if local_pos in tiles:
		return tiles[local_pos]

	# Return default floor if not found
	return GameTile.create("floor")

## Set tile at local coordinates
func set_tile(local_pos: Vector2i, tile: GameTile) -> void:
	tiles[local_pos] = tile
	is_dirty = true

## Convert local chunk coordinates to world coordinates
func chunk_to_world_position(local_pos: Vector2i) -> Vector2i:
	return chunk_coords * CHUNK_SIZE + local_pos

## Convert world coordinates to local chunk coordinates
func world_to_chunk_position(world_pos: Vector2i) -> Vector2i:
	return world_pos - (chunk_coords * CHUNK_SIZE)

## Get world bounds of this chunk
func get_world_bounds() -> Dictionary:
	var min_pos = chunk_coords * CHUNK_SIZE
	var max_pos = min_pos + Vector2i(CHUNK_SIZE - 1, CHUNK_SIZE - 1)
	return {
		"min": min_pos,
		"max": max_pos
	}

## Unload chunk from memory (for performance)
func unload() -> void:
	# Keep chunk data for potential re-loading, just mark as unloaded
	is_loaded = false
	#print("[WorldChunk] Unloaded chunk %v" % [chunk_coords])

## Serialize chunk for saving
func to_dict() -> Dictionary:
	var tiles_data = []
	for local_pos in tiles:
		var tile = tiles[local_pos]
		# Save non-default tiles: non-floor types, tiles with resources/locks, or interior tiles
		if tile.tile_type != "floor" or tile.harvestable_resource_id != "" or tile.is_locked or tile.is_interior:
			var tile_dict = {
				"pos": [local_pos.x, local_pos.y],
				"type": tile.tile_type,
				"walkable": tile.walkable,
				"transparent": tile.transparent,
				"char": tile.ascii_char,
				"resource_id": tile.harvestable_resource_id
			}
			# Only save lock properties if they're non-default
			if tile.is_locked or tile.lock_id != "" or tile.lock_level != 1:
				tile_dict["is_locked"] = tile.is_locked
				tile_dict["lock_id"] = tile.lock_id
				tile_dict["lock_level"] = tile.lock_level
			# Save door state
			if tile.tile_type == "door":
				tile_dict["is_open"] = tile.is_open
			# Save interior flag for building visibility
			if tile.is_interior:
				tile_dict["is_interior"] = true
			tiles_data.append(tile_dict)

	var resources_data = []
	for resource in resources:
		if resource is ResourceSpawner.ResourceInstance:
			resources_data.append(resource.to_dict())

	return {
		"chunk_coords": [chunk_coords.x, chunk_coords.y],
		"seed": seed,
		"tiles": tiles_data,
		"resources": resources_data
	}

## Deserialize chunk from save data
static func from_dict(data: Dictionary, world_seed: int) -> WorldChunk:
	var coords_array = data.get("chunk_coords", [0, 0])
	var coords = Vector2i(coords_array[0], coords_array[1])
	var chunk = WorldChunk.new(coords, world_seed)
	chunk.seed = data.get("seed", chunk.seed)

	# Restore tiles
	var tiles_data = data.get("tiles", [])
	for tile_data in tiles_data:
		var pos_array = tile_data.get("pos", [0, 0])
		var local_pos = Vector2i(pos_array[0], pos_array[1])
		var tile = GameTile.new()
		tile.tile_type = tile_data.get("type", "floor")
		tile.walkable = tile_data.get("walkable", true)
		tile.transparent = tile_data.get("transparent", true)
		tile.ascii_char = tile_data.get("char", ".")
		tile.harvestable_resource_id = tile_data.get("resource_id", "")
		# Restore lock properties
		tile.is_locked = tile_data.get("is_locked", false)
		tile.lock_id = tile_data.get("lock_id", "")
		tile.lock_level = tile_data.get("lock_level", 1)
		# Restore door state
		if tile.tile_type == "door":
			tile.is_open = tile_data.get("is_open", false)
		# Restore interior flag for building visibility
		tile.is_interior = tile_data.get("is_interior", false)
		chunk.tiles[local_pos] = tile

	# Restore resources
	var resources_data = data.get("resources", [])
	for resource_data in resources_data:
		chunk.resources.append(ResourceSpawner.ResourceInstance.from_dict(resource_data))

	return chunk

## Generate town structures within this chunk
func _generate_town_structures(town_center: Vector2i, world_seed: int) -> void:
	var _rng = SeededRandom.new(world_seed + 999)

	# Town is 15x15 centered on town_center
	var town_size = Vector2i(15, 15)
	var _town_start = town_center - town_size / 2

	# Shop building (5x5)
	var shop_size = Vector2i(5, 5)
	var shop_start = town_center - shop_size / 2

	# Place shop walls and floor
	for x in range(shop_size.x):
		for y in range(shop_size.y):
			var world_pos = shop_start + Vector2i(x, y)
			var local_pos = world_to_chunk_position(world_pos)

			# Check if position is in this chunk
			if local_pos.x < 0 or local_pos.x >= CHUNK_SIZE or local_pos.y < 0 or local_pos.y >= CHUNK_SIZE:
				continue

			var is_wall = (x == 0 or x == shop_size.x - 1 or y == 0 or y == shop_size.y - 1)
			var is_door = (x == shop_size.x / 2 and y == shop_size.y - 1)

			var tile: GameTile
			if is_door:
				tile = GameTile.create("door")
			elif is_wall:
				tile = GameTile.create("wall")
			else:
				tile = GameTile.create("floor")
				tile.color = Color.WHITE  # Indoor floor uses default color

			tiles[local_pos] = tile

	# Place well (water source) near shop
	var well_pos = town_center + Vector2i(4, 4)
	var well_local = world_to_chunk_position(well_pos)
	if well_local.x >= 0 and well_local.x < CHUNK_SIZE and well_local.y >= 0 and well_local.y < CHUNK_SIZE:
		var well_tile = GameTile.create("water")
		tiles[well_local] = well_tile

	#print("[WorldChunk] Generated town structures in chunk %v" % [chunk_coords])
