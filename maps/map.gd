class_name GameMap

## GameMap - Holds a single map's tiles and metadata
##
## Stores the tile grid, entities, and metadata for a map.
## Can be the overworld or a dungeon floor.

const GameTile = preload("res://maps/game_tile.gd")

var map_id: String  # "overworld" or "dungeon_barrow_floor_5"
var width: int
var height: int
var tiles: Dictionary = {}  # Vector2i -> GameTile (for non-chunked maps)
var seed: int  # Seed used to generate this map
var entities: Array = []  # Array of Entity objects
var chunk_based: bool = false  # True for overworld (uses ChunkManager), false for dungeons
var metadata: Dictionary = {}  # Additional map data (stairs positions, enemy spawns, etc.)

func _init(id: String = "", w: int = 100, h: int = 100, s: int = 0) -> void:
	map_id = id
	width = w
	height = h
	seed = s

## Get tile at position (handles both chunk-based and regular maps)
func get_tile(pos: Vector2i) -> GameTile:
	if chunk_based:
		# Use ChunkManager for overworld
		return ChunkManager.get_tile(pos)
	else:
		# Use dictionary for dungeons
		if pos in tiles:
			return tiles[pos]
		# Return wall if out of bounds
		return _create_tile("wall")

## Set tile at position (handles both chunk-based and regular maps)
func set_tile(pos: Vector2i, tile: GameTile) -> void:
	if chunk_based:
		# Use ChunkManager for overworld
		ChunkManager.set_tile(pos, tile)
	else:
		# Use dictionary for dungeons
		tiles[pos] = tile

## Check if position is walkable
func is_walkable(pos: Vector2i) -> bool:
	# Check bounds (skip for chunk-based infinite maps)
	if not chunk_based:
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			return false

	var tile = get_tile(pos)
	if not tile.walkable:
		return false

	# Check if any entity blocks movement at this position
	for entity in entities:
		if entity.position == pos and entity.blocks_movement:
			return false

	# Check if any structure blocks movement at this position
	var structures = StructureManager.get_structures_at(pos, map_id)
	for structure in structures:
		if structure.blocks_movement:
			return false

	# Check if any feature blocks movement at this position
	if FeatureManager.has_blocking_feature(pos):
		return false

	return true

## Check if position is transparent (for FOV)
func is_transparent(pos: Vector2i) -> bool:
	# Out of bounds is not transparent
	if not chunk_based:
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			return false
	else:
		# For chunk-based maps, only check tiles in loaded chunks
		# Don't trigger chunk loading from FOV calculations
		var chunk_coords = ChunkManager.world_to_chunk(pos)
		if chunk_coords not in ChunkManager.active_chunks:
			return false  # Unloaded chunks are considered opaque

	return get_tile(pos).transparent

## Fill entire map with a tile type
func fill(tile_type: String) -> void:
	for y in range(height):
		for x in range(width):
			set_tile(Vector2i(x, y), _create_tile(tile_type))

## Create a tile by type (helper function)
func _create_tile(type: String) -> GameTile:
	return GameTile.create(type)

## Calculate which walls are visible (adjacent to accessible floors)
## Returns a Set (Dictionary) of wall positions that should be rendered
func get_visible_walls(start_pos: Vector2i) -> Dictionary:
	var visible_walls: Dictionary = {}  # Set of Vector2i positions
	var visited_floors: Dictionary = {}  # Set of visited floor positions
	var to_visit: Array[Vector2i] = [start_pos]

	# Flood fill accessible floors
	while to_visit.size() > 0:
		var pos = to_visit.pop_back()

		# Skip if already visited or out of bounds
		if pos in visited_floors:
			continue
		if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
			continue

		var tile = get_tile(pos)

		# Only visit walkable tiles
		if not tile.walkable:
			continue

		visited_floors[pos] = true

		# Check all 8 neighbors (including diagonals for wall visibility)
		var neighbors = [
			Vector2i(pos.x - 1, pos.y - 1), Vector2i(pos.x, pos.y - 1), Vector2i(pos.x + 1, pos.y - 1),
			Vector2i(pos.x - 1, pos.y),                                 Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x - 1, pos.y + 1), Vector2i(pos.x, pos.y + 1), Vector2i(pos.x + 1, pos.y + 1)
		]

		for neighbor in neighbors:
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue

			var neighbor_tile = get_tile(neighbor)

			# If neighbor is a wall (non-walkable, non-transparent), mark it as visible
			if not neighbor_tile.walkable and not neighbor_tile.transparent:
				visible_walls[neighbor] = true
			# If neighbor is walkable and not visited, add to queue
			elif neighbor_tile.walkable and neighbor not in visited_floors:
				to_visit.append(neighbor)

	return visible_walls
