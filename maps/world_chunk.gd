class_name WorldChunk

## WorldChunk - Represents a 32x32 section of the world
##
## Chunks are the fundamental unit of map streaming - only active chunks are kept in memory.
## Each chunk generates deterministically from a seed based on its coordinates.

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
	#print("[WorldChunk] Generating chunk %v with seed %d" % [chunk_coords, seed])

	var rng = SeededRandom.new(seed)

	# Check if this chunk contains special features
	var map = MapManager.current_map
	var dungeon_entrance_pos = map.get_meta("dungeon_entrance", Vector2i(-1, -1)) if map else Vector2i(-1, -1)
	var town_center_pos = map.get_meta("town_center", Vector2i(-1, -1)) if map else Vector2i(-1, -1)

	if town_center_pos != Vector2i(-1, -1):
		print("[WorldChunk] Chunk %v: Town center found at %v" % [chunk_coords, town_center_pos])

	# Generate all tiles in chunk using biome system
	for local_y in range(CHUNK_SIZE):
		for local_x in range(CHUNK_SIZE):
			var world_pos = chunk_to_world_position(Vector2i(local_x, local_y))

			# Get biome at world position
			var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

			# Create base tile from biome
			var tile = GameTile.create(biome.base_tile)

			# Override floor character and color for visual variety
			if biome.base_tile == "floor":
				tile.ascii_char = biome.grass_char
				# Set color based on whether it's a grass character or floor
				if biome.grass_char == ".":
					tile.color = biome.color_floor
				else:
					tile.color = biome.color_grass

			# Check for special features at this position
			if world_pos == dungeon_entrance_pos:
				# Place dungeon entrance
				tile = GameTile.create("stairs_down")
				print("[WorldChunk] Placed dungeon entrance at %v" % world_pos)
			elif town_center_pos != Vector2i(-1, -1):
				# Check if within town area (20x20 around center)
				var dist_to_town = (world_pos - town_center_pos).length()
				if dist_to_town <= 10:
					# This tile is within town boundary
					# Town generation will be handled by TownGenerator when chunk loads
					# For now, just ensure it's walkable floor
					if tile.tile_type != "floor":
						tile = GameTile.create("floor")
						tile.ascii_char = biome.grass_char
						# Set color for town floor tiles
						if biome.grass_char == ".":
							tile.color = biome.color_floor
						else:
							tile.color = biome.color_grass

			tiles[Vector2i(local_x, local_y)] = tile

			# Try to spawn resources on floor tiles (skip in town area)
			var dist_to_town = (world_pos - town_center_pos).length() if town_center_pos != Vector2i(-1, -1) else 999
			if tile.walkable and tile.tile_type == "floor" and dist_to_town > 10:
				# Try to spawn tree
				# Use biome data we already fetched (avoids expensive blending call)
				# This eliminates 3500 extra noise samples per chunk

				if rng.randf() < biome.tree_density:
					var resource_instance = ResourceSpawner.ResourceInstance.new("tree", world_pos, chunk_coords)
					resources.append(resource_instance)

					# Mark tile as non-walkable
					tile.walkable = false
					tile.transparent = false
					tile.ascii_char = "T"
					tile.harvestable_resource_id = "tree"
					tile.color = Color.WHITE  # Reset color - tree uses default renderer color
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
					tile.color = Color.WHITE  # Reset color - rock uses default renderer color

	# Generate town structures if this chunk contains the town center
	if town_center_pos != Vector2i(-1, -1):
		var town_chunk = Vector2i(
			floori(float(town_center_pos.x) / CHUNK_SIZE),
			floori(float(town_center_pos.y) / CHUNK_SIZE)
		)
		print("[WorldChunk] Chunk %v checking town: town_chunk=%v, match=%s" % [chunk_coords, town_chunk, chunk_coords == town_chunk])
		if chunk_coords == town_chunk:
			print("[WorldChunk] *** GENERATING TOWN STRUCTURES in chunk %v ***" % [chunk_coords])
			_generate_town_structures(town_center_pos, world_seed)

	is_loaded = true
	is_dirty = true
	#print("[WorldChunk] Generated chunk %v with %d resources" % [chunk_coords, resources.size()])

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
	print("[WorldChunk] Unloaded chunk %v" % [chunk_coords])

## Serialize chunk for saving
func to_dict() -> Dictionary:
	var tiles_data = []
	for local_pos in tiles:
		var tile = tiles[local_pos]
		# Only save modified tiles (non-default)
		if tile.tile_type != "floor" or tile.harvestable_resource_id != "":
			tiles_data.append({
				"pos": [local_pos.x, local_pos.y],
				"type": tile.tile_type,
				"walkable": tile.walkable,
				"transparent": tile.transparent,
				"char": tile.ascii_char,
				"resource_id": tile.harvestable_resource_id
			})

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
		chunk.tiles[local_pos] = tile

	# Restore resources
	var resources_data = data.get("resources", [])
	for resource_data in resources_data:
		chunk.resources.append(ResourceSpawner.ResourceInstance.from_dict(resource_data))

	return chunk

## Generate town structures within this chunk
func _generate_town_structures(town_center: Vector2i, world_seed: int) -> void:
	var rng = SeededRandom.new(world_seed + 999)

	# Town is 15x15 centered on town_center
	var town_size = Vector2i(15, 15)
	var town_start = town_center - town_size / 2

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

	print("[WorldChunk] Generated town structures in chunk %v" % [chunk_coords])
