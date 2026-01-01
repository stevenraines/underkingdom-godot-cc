extends Node

## ChunkManager - Manages chunk loading/unloading for infinite world streaming
##
## Only keeps chunks near the player in memory for performance.
## Chunks are generated deterministically from world seed.

const WorldChunk = preload("res://maps/world_chunk.gd")

var active_chunks: Dictionary = {}  # Vector2i (chunk_coords) -> WorldChunk
var chunk_cache: Dictionary = {}  # Long-term cache of generated chunks
var load_radius: int = 3  # Load chunks within 3 chunk distance of player
var unload_radius: int = 5  # Unload chunks beyond 5 chunk distance

var world_seed: int = 0  # Set when map is loaded
var is_chunk_mode: bool = false  # True for overworld, false for dungeons

func _ready() -> void:
	print("ChunkManager initialized")
	EventBus.map_changed.connect(_on_map_changed)

## Enable chunk mode for a map
func enable_chunk_mode(map_id: String, seed: int) -> void:
	if map_id == "overworld":
		is_chunk_mode = true
		world_seed = seed
		print("[ChunkManager] Chunk mode enabled for overworld")
	else:
		is_chunk_mode = false
		print("[ChunkManager] Chunk mode disabled for %s" % map_id)

## Convert world position to chunk coordinates
static func world_to_chunk(world_pos: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(world_pos.x) / WorldChunk.CHUNK_SIZE),
		floori(float(world_pos.y) / WorldChunk.CHUNK_SIZE)
	)

## Get or load a chunk at given chunk coordinates
func get_chunk(chunk_coords: Vector2i) -> WorldChunk:
	# Check active chunks first
	if chunk_coords in active_chunks:
		return active_chunks[chunk_coords]

	# Check cache
	if chunk_coords in chunk_cache:
		var chunk = chunk_cache[chunk_coords]
		chunk.is_loaded = true
		active_chunks[chunk_coords] = chunk
		return chunk

	# Generate new chunk
	return load_chunk(chunk_coords)

## Load/generate a chunk
func load_chunk(chunk_coords: Vector2i) -> WorldChunk:
	var chunk = WorldChunk.new(chunk_coords, world_seed)
	chunk.generate(world_seed)

	active_chunks[chunk_coords] = chunk
	chunk_cache[chunk_coords] = chunk

	EventBus.chunk_loaded.emit(chunk_coords)
	return chunk

## Unload a chunk from active memory
func unload_chunk(chunk_coords: Vector2i) -> void:
	if chunk_coords in active_chunks:
		var chunk = active_chunks[chunk_coords]
		chunk.unload()
		active_chunks.erase(chunk_coords)
		# Keep in cache for potential re-loading
		EventBus.chunk_unloaded.emit(chunk_coords)

## Update active chunks based on player position
func update_active_chunks(player_pos: Vector2i) -> void:
	if not is_chunk_mode:
		return

	var player_chunk = world_to_chunk(player_pos)

	# Calculate which chunks should be loaded
	var chunks_to_load: Array[Vector2i] = []
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var chunk_coords = player_chunk + Vector2i(dx, dy)
			chunks_to_load.append(chunk_coords)

	# Load new chunks
	for coords in chunks_to_load:
		if coords not in active_chunks:
			load_chunk(coords)

	# Unload distant chunks
	var chunks_to_unload: Array[Vector2i] = []
	for coords in active_chunks:
		var distance = (coords - player_chunk).length()
		if distance > unload_radius:
			chunks_to_unload.append(coords)

	for coords in chunks_to_unload:
		unload_chunk(coords)

## Get tile at world position (chunk-based access)
func get_tile(world_pos: Vector2i) -> GameTile:
	var chunk_coords = world_to_chunk(world_pos)
	var chunk = get_chunk(chunk_coords)

	if chunk:
		var local_pos = world_pos - (chunk_coords * WorldChunk.CHUNK_SIZE)
		# Clamp local position to valid range
		local_pos.x = clampi(local_pos.x, 0, WorldChunk.CHUNK_SIZE - 1)
		local_pos.y = clampi(local_pos.y, 0, WorldChunk.CHUNK_SIZE - 1)
		return chunk.get_tile(local_pos)

	# Fallback to default floor
	return GameTile.create("floor")

## Set tile at world position (chunk-based access)
func set_tile(world_pos: Vector2i, tile: GameTile) -> void:
	var chunk_coords = world_to_chunk(world_pos)
	var chunk = get_chunk(chunk_coords)

	if chunk:
		var local_pos = world_pos - (chunk_coords * WorldChunk.CHUNK_SIZE)
		local_pos.x = clampi(local_pos.x, 0, WorldChunk.CHUNK_SIZE - 1)
		local_pos.y = clampi(local_pos.y, 0, WorldChunk.CHUNK_SIZE - 1)
		chunk.set_tile(local_pos, tile)

## Get all active chunk coordinates
func get_active_chunk_coords() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coords in active_chunks:
		result.append(coords)
	return result

## Clear all chunks (on new game or map change)
func clear_chunks() -> void:
	active_chunks.clear()
	chunk_cache.clear()
	print("[ChunkManager] All chunks cleared")

## Handle map changes
func _on_map_changed(map_id: String) -> void:
	if map_id != "overworld":
		# Disable chunk mode for dungeons
		is_chunk_mode = false
		clear_chunks()

## Serialize chunks for saving
func save_chunks() -> Array:
	var chunks_data = []
	for coords in chunk_cache:
		var chunk = chunk_cache[coords]
		chunks_data.append(chunk.to_dict())
	return chunks_data

## Load chunks from save data
func load_chunks(chunks_data: Array) -> void:
	clear_chunks()

	for chunk_data in chunks_data:
		var chunk = WorldChunk.from_dict(chunk_data, world_seed)
		chunk_cache[chunk.chunk_coords] = chunk
		# Don't add to active_chunks yet - will load on demand

	print("[ChunkManager] Loaded %d chunks from save" % chunks_data.size())
