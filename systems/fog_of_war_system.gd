class_name FogOfWarSystem

## FogOfWarSystem - Tracks explored tiles per map/chunk for fog of war
##
## Stores which tiles the player has previously seen.
## For chunk-based maps (overworld), stores per-chunk.
## For dungeon maps, stores globally for the map.
##
## Tile states:
## - Unexplored: Never seen (render very dark gray)
## - Explored: Previously seen but not currently visible (render dark gray)
## - Visible: Currently in FOV and illuminated (render normally)

# Storage for explored tiles
# For chunk-based maps: map_id -> chunk_coords -> Set of local positions
# For regular maps: map_id -> Set of world positions
static var explored_tiles: Dictionary = {}

# Current visibility state (recalculated each turn)
static var currently_visible: Dictionary = {}  # Vector2i -> bool

## Mark a tile as explored
static func mark_explored(map_id: String, world_pos: Vector2i, chunk_based: bool = false) -> void:
	if chunk_based:
		_mark_explored_chunk(map_id, world_pos)
	else:
		_mark_explored_global(map_id, world_pos)

## Mark multiple tiles as explored
static func mark_many_explored(map_id: String, positions: Array, chunk_based: bool = false) -> void:
	for pos in positions:
		mark_explored(map_id, pos, chunk_based)

## Check if a tile has been explored
static func is_explored(map_id: String, world_pos: Vector2i, chunk_based: bool = false) -> bool:
	if chunk_based:
		return _is_explored_chunk(map_id, world_pos)
	else:
		return _is_explored_global(map_id, world_pos)

## Set currently visible tiles (called after FOV calculation)
static func set_visible_tiles(visible_tiles: Array) -> void:
	currently_visible.clear()
	for pos in visible_tiles:
		currently_visible[pos] = true

## Check if a tile is currently visible
static func is_visible(world_pos: Vector2i) -> bool:
	return currently_visible.has(world_pos)

## Get tile visibility state
## Returns: "visible", "explored", or "unexplored"
static func get_tile_state(map_id: String, world_pos: Vector2i, chunk_based: bool = false) -> String:
	if is_visible(world_pos):
		return "visible"
	elif is_explored(map_id, world_pos, chunk_based):
		return "explored"
	else:
		return "unexplored"

## Clear explored data for a specific map
static func clear_map_data(map_id: String) -> void:
	if explored_tiles.has(map_id):
		explored_tiles.erase(map_id)

## Clear all fog of war data
static func clear_all() -> void:
	explored_tiles.clear()
	currently_visible.clear()

## Get all explored positions for a map (for serialization)
static func get_explored_data(map_id: String) -> Dictionary:
	if not explored_tiles.has(map_id):
		return {}
	return explored_tiles[map_id].duplicate(true)

## Set explored data for a map (for deserialization)
static func set_explored_data(map_id: String, data: Dictionary) -> void:
	explored_tiles[map_id] = data.duplicate(true)

## Get all explored data for saving
static func serialize() -> Dictionary:
	var result: Dictionary = {}
	for map_id in explored_tiles:
		var map_data = explored_tiles[map_id]
		if map_data is Dictionary:
			# Chunk-based map - serialize chunk data
			var serialized_chunks: Dictionary = {}
			for chunk_key in map_data:
				var positions = map_data[chunk_key]
				var pos_list: Array = []
				for pos in positions:
					pos_list.append([pos.x, pos.y])
				serialized_chunks[chunk_key] = pos_list
			result[map_id] = {"type": "chunk", "data": serialized_chunks}
		else:
			# Global map - serialize as array of positions
			var pos_list: Array = []
			for pos in map_data:
				pos_list.append([pos.x, pos.y])
			result[map_id] = {"type": "global", "data": pos_list}
	return result

## Restore explored data from save
static func deserialize(data: Dictionary) -> void:
	explored_tiles.clear()
	for map_id in data:
		var map_data = data[map_id]
		var data_type = map_data.get("type", "global")
		var raw_data = map_data.get("data", {})

		if data_type == "chunk":
			# Chunk-based map
			var chunk_dict: Dictionary = {}
			for chunk_key in raw_data:
				var positions: Dictionary = {}
				for pos_arr in raw_data[chunk_key]:
					var pos = Vector2i(pos_arr[0], pos_arr[1])
					positions[pos] = true
				chunk_dict[chunk_key] = positions
			explored_tiles[map_id] = chunk_dict
		else:
			# Global map
			var positions: Dictionary = {}
			for pos_arr in raw_data:
				var pos = Vector2i(pos_arr[0], pos_arr[1])
				positions[pos] = true
			explored_tiles[map_id] = positions

# Internal: Mark explored for chunk-based map
static func _mark_explored_chunk(map_id: String, world_pos: Vector2i) -> void:
	if not explored_tiles.has(map_id):
		explored_tiles[map_id] = {}

	# Get chunk coordinates
	var chunk_coords = _world_to_chunk(world_pos)
	var chunk_key = "%d,%d" % [chunk_coords.x, chunk_coords.y]

	if not explored_tiles[map_id].has(chunk_key):
		explored_tiles[map_id][chunk_key] = {}

	# Store local position within chunk
	var local_pos = _world_to_local(world_pos)
	explored_tiles[map_id][chunk_key][local_pos] = true

# Internal: Check explored for chunk-based map
static func _is_explored_chunk(map_id: String, world_pos: Vector2i) -> bool:
	if not explored_tiles.has(map_id):
		return false

	var chunk_coords = _world_to_chunk(world_pos)
	var chunk_key = "%d,%d" % [chunk_coords.x, chunk_coords.y]

	if not explored_tiles[map_id].has(chunk_key):
		return false

	var local_pos = _world_to_local(world_pos)
	return explored_tiles[map_id][chunk_key].has(local_pos)

# Internal: Mark explored for global map
static func _mark_explored_global(map_id: String, world_pos: Vector2i) -> void:
	if not explored_tiles.has(map_id):
		explored_tiles[map_id] = {}
	explored_tiles[map_id][world_pos] = true

# Internal: Check explored for global map
static func _is_explored_global(map_id: String, world_pos: Vector2i) -> bool:
	if not explored_tiles.has(map_id):
		return false
	return explored_tiles[map_id].has(world_pos)

# Chunk size constant (must match WorldChunk.CHUNK_SIZE)
const CHUNK_SIZE: int = 32

# Internal: Convert world position to chunk coordinates
static func _world_to_chunk(world_pos: Vector2i) -> Vector2i:
	var chunk_x = floori(float(world_pos.x) / CHUNK_SIZE)
	var chunk_y = floori(float(world_pos.y) / CHUNK_SIZE)
	return Vector2i(chunk_x, chunk_y)

# Internal: Convert world position to local chunk position
static func _world_to_local(world_pos: Vector2i) -> Vector2i:
	var local_x = world_pos.x % CHUNK_SIZE
	var local_y = world_pos.y % CHUNK_SIZE
	# Handle negative coordinates
	if local_x < 0:
		local_x += CHUNK_SIZE
	if local_y < 0:
		local_y += CHUNK_SIZE
	return Vector2i(local_x, local_y)
