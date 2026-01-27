extends Node

## ChunkManager - Manages chunk loading/unloading for infinite world streaming
##
## Only keeps chunks near the player in memory for performance.
## Chunks are generated deterministically from world seed.

const WorldChunk = preload("res://maps/world_chunk.gd")

var active_chunks: Dictionary = {}  # Vector2i (chunk_coords) -> WorldChunk
var chunk_cache: Dictionary = {}  # LRU cache of generated chunks
var chunk_access_order: Array[Vector2i] = []  # LRU tracking: most recent at end
var chunk_access_index: Dictionary = {}  # Vector2i -> index in chunk_access_order for O(1) lookup
var visited_chunks: Dictionary = {}  # Vector2i (chunk_coords) -> bool (for minimap)
var load_radius: int = 2  # Load chunks within 2 chunk distance (5x5 grid = 160x160 tiles covers 80x40 viewport)
var unload_radius: int = 4  # Unload chunks beyond 4 chunk distance
var max_cache_size: int = 100  # Maximum cached chunks (prevents memory growth)

var world_seed: int = 0  # Set when map is loaded
var is_chunk_mode: bool = false  # True for overworld, false for dungeons

# Circuit breaker: prevent infinite chunk operations in a single turn
var _chunk_ops_this_turn: int = 0
var _last_turn_number: int = -1
const MAX_CHUNK_OPS_PER_TURN: int = 50  # Emergency brake
var _updating_chunks: bool = false  # Prevent recursive calls

func _ready() -> void:
	print("ChunkManager initialized")
	EventBus.map_changed.connect(_on_map_changed)

	# Load max cache size from BiomeManager config
	var chunk_settings = BiomeManager.get_chunk_settings()
	if chunk_settings.has("cache_max_size"):
		max_cache_size = chunk_settings["cache_max_size"]
		print("[ChunkManager] Max cache size set to %d chunks" % max_cache_size)

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
		_touch_chunk_lru(chunk_coords)
		return active_chunks[chunk_coords]

	# Check cache
	if chunk_coords in chunk_cache:
		var chunk = chunk_cache[chunk_coords]
		chunk.is_loaded = true
		active_chunks[chunk_coords] = chunk
		_touch_chunk_lru(chunk_coords)
		return chunk

	# Generate new chunk
	return load_chunk(chunk_coords)

## Load/generate a chunk
func load_chunk(chunk_coords: Vector2i) -> WorldChunk:
	# Circuit breaker: Track turn and prevent infinite chunk operations
	var current_turn = TurnManager.current_turn if TurnManager else 0
	if current_turn != _last_turn_number:
		_last_turn_number = current_turn
		_chunk_ops_this_turn = 0

	_chunk_ops_this_turn += 1
	if _chunk_ops_this_turn > MAX_CHUNK_OPS_PER_TURN:
		push_error("[ChunkManager] CIRCUIT BREAKER: Too many chunk operations in turn %d (%d ops). Possible infinite loop!" % [current_turn, _chunk_ops_this_turn])
		return null

	# Check if chunk is within island bounds
	var island_settings = BiomeManager.get_island_settings()
	var max_chunk_x = island_settings.get("width_chunks", 50)
	var max_chunk_y = island_settings.get("height_chunks", 50)

	# Prevent generation outside island bounds (return ocean chunk)
	if chunk_coords.x < 0 or chunk_coords.x >= max_chunk_x or chunk_coords.y < 0 or chunk_coords.y >= max_chunk_y:
		print("[ChunkManager] Chunk %v is outside island bounds (%d×%d), skipping generation" % [chunk_coords, max_chunk_x, max_chunk_y])
		# Return null - caller should handle this gracefully
		return null

	var chunk = WorldChunk.new(chunk_coords, world_seed)
	chunk.generate(world_seed)

	active_chunks[chunk_coords] = chunk
	chunk_cache[chunk_coords] = chunk
	visited_chunks[chunk_coords] = true  # Mark as visited for minimap

	# Update LRU tracking
	_touch_chunk_lru(chunk_coords)

	# Evict old chunks if cache is full (LRU policy)
	_evict_old_chunks_if_needed()

	# Check for dungeon entrance discoveries in this chunk
	_check_for_dungeon_discoveries(chunk_coords)

	# Emit chunk loaded event
	EventBus.chunk_loaded.emit(chunk_coords)

	# Show feedback message for first few chunks (helps player understand world is generating)
	if visited_chunks.size() <= 5:
		EventBus.message_logged.emit("Exploring chunk %v..." % chunk_coords)

	return chunk

## Update LRU access tracking for a chunk (O(1) check, occasional O(n) rebuild)
func _touch_chunk_lru(chunk_coords: Vector2i) -> void:
	# Fast path: if already at end, nothing to do
	if chunk_access_index.has(chunk_coords):
		var current_idx = chunk_access_index[chunk_coords]
		if current_idx == chunk_access_order.size() - 1:
			return  # Already most recent, skip

	# Mark for lazy rebuild instead of immediate array modification
	# For now, just update the index - actual reorder happens during eviction
	if not chunk_access_index.has(chunk_coords):
		chunk_access_order.append(chunk_coords)
		chunk_access_index[chunk_coords] = chunk_access_order.size() - 1

## Evict least recently used chunks if cache exceeds max size
func _evict_old_chunks_if_needed() -> void:
	# CRITICAL: Prevent infinite loop if all chunks are active
	# Track how many chunks we've checked to avoid cycling forever
	var checks_remaining = chunk_access_order.size()

	while chunk_cache.size() > max_cache_size and chunk_access_order.size() > 0 and checks_remaining > 0:
		checks_remaining -= 1

		# Evict least recently used (first in list)
		var oldest_chunk = chunk_access_order[0]

		# Don't evict if it's currently active
		if oldest_chunk in active_chunks:
			chunk_access_order.remove_at(0)
			chunk_access_index.erase(oldest_chunk)
			chunk_access_order.append(oldest_chunk)  # Move to end
			chunk_access_index[oldest_chunk] = chunk_access_order.size() - 1
			continue

		# Evict from cache
		chunk_cache.erase(oldest_chunk)
		chunk_access_order.remove_at(0)
		chunk_access_index.erase(oldest_chunk)
		# Rebuild index after removal (indices shifted)
		_rebuild_access_index()
		# Reset counter when we successfully evict (we made progress)
		checks_remaining = chunk_access_order.size()

	# Warn if we couldn't evict enough chunks
	if chunk_cache.size() > max_cache_size:
		push_warning("[ChunkManager] Could not evict enough chunks - all %d chunks are active (cache: %d, max: %d)" % [active_chunks.size(), chunk_cache.size(), max_cache_size])

## Rebuild the access index after array modifications
func _rebuild_access_index() -> void:
	chunk_access_index.clear()
	for i in range(chunk_access_order.size()):
		chunk_access_index[chunk_access_order[i]] = i

## Unload a chunk from active memory
func unload_chunk(chunk_coords: Vector2i) -> void:
	# Circuit breaker: Track operations
	var current_turn = TurnManager.current_turn if TurnManager else 0
	if current_turn != _last_turn_number:
		_last_turn_number = current_turn
		_chunk_ops_this_turn = 0

	_chunk_ops_this_turn += 1
	if _chunk_ops_this_turn > MAX_CHUNK_OPS_PER_TURN:
		push_error("[ChunkManager] CIRCUIT BREAKER: Too many chunk operations in turn %d (%d ops). Possible infinite loop!" % [current_turn, _chunk_ops_this_turn])
		return

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

	# Prevent recursive calls (reentrancy guard)
	if _updating_chunks:
		push_warning("[ChunkManager] Recursive call to update_active_chunks detected, ignoring")
		return

	_updating_chunks = true

	var player_chunk = world_to_chunk(player_pos)

	# Get island bounds
	var island_settings = BiomeManager.get_island_settings()
	var max_chunk_x = island_settings.get("width_chunks", 50)
	var max_chunk_y = island_settings.get("height_chunks", 50)

	# Calculate which chunks should be loaded
	var chunks_to_load: Array[Vector2i] = []
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var chunk_coords = player_chunk + Vector2i(dx, dy)
			# Skip chunks outside island bounds
			if chunk_coords.x >= 0 and chunk_coords.x < max_chunk_x and chunk_coords.y >= 0 and chunk_coords.y < max_chunk_y:
				chunks_to_load.append(chunk_coords)

	# Load new chunks
	for coords in chunks_to_load:
		if coords not in active_chunks:
			var chunk = load_chunk(coords)
			# load_chunk returns null if outside bounds, skip it
			if not chunk:
				continue

	# Unload distant chunks (using Chebyshev distance for consistent square patterns)
	var chunks_to_unload: Array[Vector2i] = []
	for coords in active_chunks:
		# Chebyshev distance (max of x/y differences) for square loading area
		var distance = max(abs(coords.x - player_chunk.x), abs(coords.y - player_chunk.y))
		if distance > unload_radius:
			chunks_to_unload.append(coords)

	for coords in chunks_to_unload:
		unload_chunk(coords)

	# Clear reentrancy guard
	_updating_chunks = false

## Get tile at world position (chunk-based access)
## Optimized with fast path for already-active chunks (avoids LRU overhead)
func get_tile(world_pos: Vector2i) -> GameTile:
	var chunk_coords = world_to_chunk(world_pos)

	# Fast path: check active chunks first (avoids LRU overhead)
	var chunk: WorldChunk = null
	if chunk_coords in active_chunks:
		chunk = active_chunks[chunk_coords]
	else:
		chunk = get_chunk(chunk_coords)

	if chunk:
		var local_pos = world_pos - (chunk_coords * WorldChunk.CHUNK_SIZE)
		# Clamp local position to valid range
		local_pos.x = clampi(local_pos.x, 0, WorldChunk.CHUNK_SIZE - 1)
		local_pos.y = clampi(local_pos.y, 0, WorldChunk.CHUNK_SIZE - 1)
		return chunk.get_tile(local_pos)

	# Outside island bounds - return ocean tile
	return GameTile.create("water")

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
	visited_chunks.clear()
	chunk_access_order.clear()  # Clear LRU tracking
	chunk_access_index.clear()  # Clear LRU index
	print("[ChunkManager] All chunks cleared")

## Handle map changes
func _on_map_changed(map_id: String) -> void:
	if map_id != "overworld":
		# Disable chunk mode for dungeons
		is_chunk_mode = false
		clear_chunks()

## Check if any dungeon entrances are in this chunk and mark them as discovered
func _check_for_dungeon_discoveries(chunk_coords: Vector2i) -> void:
	if not MapManager.current_map:
		return

	var entrances = MapManager.current_map.get_meta("dungeon_entrances", [])
	for entrance in entrances:
		# Handle position that might be Vector2i, Dictionary, or Array
		var entrance_pos: Vector2i
		var pos_data = entrance.get("position", Vector2i.ZERO)
		if pos_data is Vector2i:
			entrance_pos = pos_data
		elif pos_data is Dictionary:
			entrance_pos = Vector2i(int(pos_data.get("x", 0)), int(pos_data.get("y", 0)))
		elif pos_data is Array and pos_data.size() >= 2:
			entrance_pos = Vector2i(int(pos_data[0]), int(pos_data[1]))
		else:
			entrance_pos = Vector2i.ZERO

		var entrance_chunk = world_to_chunk(entrance_pos)

		if entrance_chunk == chunk_coords:
			var dungeon_type = entrance.get("dungeon_type", "")
			var dungeon_name = entrance.get("name", dungeon_type.capitalize())

			if not GameManager.is_location_visited(dungeon_type):
				GameManager.mark_location_visited(
					dungeon_type,
					"dungeon",
					dungeon_name,
					entrance_pos
				)
				EventBus.message_logged.emit("Discovered: %s" % dungeon_name)

## Get all visited chunk coordinates (for minimap)
func get_visited_chunks() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coords in visited_chunks:
		result.append(coords)
	return result

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
		visited_chunks[chunk.chunk_coords] = true  # Mark as visited
		# Don't add to active_chunks yet - will load on demand

	print("[ChunkManager] Loaded %d chunks from save" % chunks_data.size())
