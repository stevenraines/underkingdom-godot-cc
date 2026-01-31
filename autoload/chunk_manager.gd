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
var load_radius: int = 1  # Load chunks within 1 chunk distance (3x3 grid = 96x96 tiles covers 80x40 viewport)
var unload_radius: int = 2  # Unload chunks beyond 2 chunk distance (same as load radius - unload immediately when leaving area)
var max_cache_size: int = 100  # Maximum cached chunks (prevents memory growth)

var world_seed: int = 0  # Set when map is loaded
var is_chunk_mode: bool = false  # True for overworld, false for dungeons

# Circuit breaker: prevent infinite chunk operations in a single turn
var _chunk_ops_this_turn: int = 0
var _last_turn_number: int = -1
const MAX_CHUNK_OPS_PER_TURN: int = 50  # Emergency brake
var _updating_chunks: bool = false  # Prevent recursive calls

# Chunk operation freezing (prevents chunk loading during entity processing)
var _chunk_ops_frozen: bool = false
var _queued_loads: Dictionary = {}  # Vector2i -> true (Dictionary for auto-deduplication)
var _queued_unloads: Dictionary = {}  # Vector2i -> true

# Async loading configuration
const MAX_CHUNKS_PER_FRAME: int = 3  # Maximum chunks to load per frame
var _pending_loads: Array[Vector2i] = []  # Priority queue for async loading
var _current_player_chunk: Vector2i = Vector2i.ZERO  # For priority calculation
var _chunks_in_progress: Dictionary = {}  # Vector2i -> true (prevents duplicate queuing)

func _ready() -> void:
	print("ChunkManager initialized")
	EventBus.map_changed.connect(_on_map_changed)

	# Load max cache size from BiomeManager config
	var chunk_settings = BiomeManager.get_chunk_settings()
	if chunk_settings.has("cache_max_size"):
		max_cache_size = chunk_settings["cache_max_size"]
		print("[ChunkManager] Max cache size set to %d chunks" % max_cache_size)

	# Enable process for async chunk loading
	set_process(true)

func _process(_delta: float) -> void:
	_process_async_loads()

## Process pending chunk loads - called each frame
func _process_async_loads() -> void:
	if _pending_loads.is_empty():
		return

	# Skip if operations are frozen (during entity processing)
	if _chunk_ops_frozen:
		return

	# Skip if not in chunk mode
	if not is_chunk_mode:
		return

	var chunks_loaded_this_frame = 0

	while not _pending_loads.is_empty() and chunks_loaded_this_frame < MAX_CHUNKS_PER_FRAME:
		var chunk_coords = _pending_loads.pop_front()
		_chunks_in_progress.erase(chunk_coords)

		# Skip if already loaded (may have been loaded synchronously)
		if chunk_coords in active_chunks:
			continue

		# Load the chunk
		var chunk = load_chunk(chunk_coords)
		if chunk:
			chunks_loaded_this_frame += 1

	if chunks_loaded_this_frame > 0:
		print("[ChunkManager] Async loaded %d chunks, %d remaining" % [
			chunks_loaded_this_frame,
			_pending_loads.size()
		])

## Queue a chunk for async loading (closer chunks have higher priority)
func _queue_chunk_for_loading(chunk_coords: Vector2i) -> void:
	# Skip if already active, queued, or in progress
	if chunk_coords in active_chunks:
		return
	if chunk_coords in _chunks_in_progress:
		return

	_pending_loads.append(chunk_coords)
	_chunks_in_progress[chunk_coords] = true

	# Sort queue by distance to current player chunk (closer = earlier)
	_pending_loads.sort_custom(_compare_chunk_priority)

## Compare chunks by distance to player (closer = higher priority = earlier in array)
func _compare_chunk_priority(a: Vector2i, b: Vector2i) -> bool:
	var dist_a = max(abs(a.x - _current_player_chunk.x), abs(a.y - _current_player_chunk.y))
	var dist_b = max(abs(b.x - _current_player_chunk.x), abs(b.y - _current_player_chunk.y))
	return dist_a < dist_b

## Check if there are pending chunk loads
func is_async_loading() -> bool:
	return not _pending_loads.is_empty()

## Get count of pending chunks
func get_pending_chunk_count() -> int:
	return _pending_loads.size()

## Clear pending async loads (called on map change)
func _clear_async_queue() -> void:
	_pending_loads.clear()
	_chunks_in_progress.clear()

## Enable chunk mode for a map
func enable_chunk_mode(map_id: String, seed: int) -> void:
	if map_id == "overworld":
		is_chunk_mode = true
		world_seed = seed
		print("[ChunkManager] Chunk mode enabled for overworld")
	else:
		is_chunk_mode = false
		print("[ChunkManager] Chunk mode disabled for %s" % map_id)

## Freeze chunk loading/unloading (during entity processing)
func freeze_chunk_operations() -> void:
	_chunk_ops_frozen = true
	_queued_loads.clear()
	_queued_unloads.clear()
	print("[ChunkManager] Chunk operations FROZEN")

## Unfreeze and apply queued operations
func unfreeze_and_apply_queued_operations() -> void:
	_chunk_ops_frozen = false

	var load_count = _queued_loads.size()
	var unload_count = _queued_unloads.size()
	print("[ChunkManager] Unfreezing and applying %d loads, %d unloads" % [load_count, unload_count])

	# Unload first (frees memory)
	for coords in _queued_unloads:
		if coords in active_chunks:
			unload_chunk(coords)
	_queued_unloads.clear()

	# Load requested chunks
	for coords in _queued_loads:
		if coords not in active_chunks:
			load_chunk(coords)
	_queued_loads.clear()

	print("[ChunkManager] Chunk operations UNFROZEN")

## Check if operations are frozen (for external checks)
func is_frozen() -> bool:
	return _chunk_ops_frozen

## Emergency unfreeze without applying queued operations (for player death, etc.)
func emergency_unfreeze() -> void:
	_chunk_ops_frozen = false
	_queued_loads.clear()
	_queued_unloads.clear()
	print("[ChunkManager] EMERGENCY UNFREEZE - queued operations discarded")

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

	# Check cache - but DON'T automatically re-add to active_chunks
	# Only update_active_chunks() should control what's active
	if chunk_coords in chunk_cache:
		_touch_chunk_lru(chunk_coords)
		return chunk_cache[chunk_coords]

	# Generate new chunk
	return load_chunk(chunk_coords)

## Load/generate a chunk
func load_chunk(chunk_coords: Vector2i) -> WorldChunk:
	# If frozen, queue the load and return cached chunk or null
	if _chunk_ops_frozen:
		_queued_loads[chunk_coords] = true  # Queue for later (auto-deduplicates)
		print("[ChunkManager] Chunk load QUEUED: %v" % chunk_coords)

		# Return cached chunk if available
		if chunk_coords in chunk_cache:
			return chunk_cache[chunk_coords]

		# Return null - caller must handle gracefully
		return null

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

	var load_start = Time.get_ticks_usec()

	# Generate chunk
	var gen_start = Time.get_ticks_usec()
	var chunk = WorldChunk.new(chunk_coords, world_seed)
	chunk.generate(world_seed)
	var gen_time = Time.get_ticks_usec() - gen_start

	active_chunks[chunk_coords] = chunk
	chunk_cache[chunk_coords] = chunk
	visited_chunks[chunk_coords] = true  # Mark as visited for minimap

	# Update LRU tracking
	_touch_chunk_lru(chunk_coords)

	# Evict old chunks if cache is full (LRU policy)
	var evict_start = Time.get_ticks_usec()
	_evict_old_chunks_if_needed()
	var evict_time = Time.get_ticks_usec() - evict_start

	# Check for dungeon entrance discoveries in this chunk
	var discovery_start = Time.get_ticks_usec()
	_check_for_dungeon_discoveries(chunk_coords)
	var discovery_time = Time.get_ticks_usec() - discovery_start

	# Emit chunk loaded event
	var event_start = Time.get_ticks_usec()
	EventBus.chunk_loaded.emit(chunk_coords)
	var event_time = Time.get_ticks_usec() - event_start

	var total_time = Time.get_ticks_usec() - load_start

	# Log timing if load took >5ms
	if total_time > 5000:
		print("[ChunkManager] load_chunk %v: gen=%.2fms, evict=%.2fms, discovery=%.2fms, event=%.2fms, total=%.2fms" % [
			chunk_coords,
			gen_time / 1000.0,
			evict_time / 1000.0,
			discovery_time / 1000.0,
			event_time / 1000.0,
			total_time / 1000.0
		])

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
	# Skip eviction if we're within limits
	if chunk_cache.size() <= max_cache_size:
		return

	# DIAGNOSTIC: Check data structure consistency
	var chunks_in_cache_not_active = 0
	for chunk_coord in chunk_cache:
		if chunk_coord not in active_chunks:
			chunks_in_cache_not_active += 1

	# DIAGNOSTIC: Check first 10 chunks in access order to see if any are inactive
	var first_10_status: Array = []
	for i in range(min(10, chunk_access_order.size())):
		var chunk = chunk_access_order[i]
		var is_active = chunk in active_chunks
		first_10_status.append("%v:%s" % [chunk, "A" if is_active else "I"])

	# CRITICAL: Prevent infinite loop if all chunks are active
	# Track progress - if we check every chunk once without evicting, stop
	var evicted_count = 0
	var moved_count = 0
	var checks_since_eviction = 0  # How many chunks checked without evicting
	var original_size = chunk_access_order.size()

	while chunk_cache.size() > max_cache_size and chunk_access_order.size() > 0:
		# Safety: if we've checked every chunk without evicting, give up
		if checks_since_eviction >= original_size:
			break

		# Evict least recently used (first in list)
		var oldest_chunk = chunk_access_order[0]
		checks_since_eviction += 1

		# Don't evict if it's currently active
		if oldest_chunk in active_chunks:
			# Move active chunk to end (it's being used, shouldn't be evicted)
			chunk_access_order.remove_at(0)
			chunk_access_index.erase(oldest_chunk)
			chunk_access_order.append(oldest_chunk)
			chunk_access_index[oldest_chunk] = chunk_access_order.size() - 1
			moved_count += 1
			continue

		# Found an inactive chunk to evict
		chunk_cache.erase(oldest_chunk)
		chunk_access_order.remove_at(0)
		chunk_access_index.erase(oldest_chunk)
		_rebuild_access_index()
		evicted_count += 1

		# Reset counter after successful eviction (we made progress)
		checks_since_eviction = 0
		original_size = chunk_access_order.size()  # Update since size changed

	# Warn if we couldn't evict enough chunks
	if chunk_cache.size() > max_cache_size:
		push_warning("[ChunkManager] Could not evict enough chunks - moved %d active, evicted %d, checks=%d. Active: %d, Cache: %d (max: %d), Inactive: %d. First 10 in order: %s" % [
			moved_count, evicted_count, checks_since_eviction, active_chunks.size(), chunk_cache.size(), max_cache_size, chunks_in_cache_not_active, first_10_status
		])

## Rebuild the access index after array modifications
func _rebuild_access_index() -> void:
	chunk_access_index.clear()
	for i in range(chunk_access_order.size()):
		chunk_access_index[chunk_access_order[i]] = i

## Unload a chunk from active memory
func unload_chunk(chunk_coords: Vector2i) -> void:
	# If frozen, queue the unload
	if _chunk_ops_frozen:
		_queued_unloads[chunk_coords] = true  # Queue for later (auto-deduplicates)
		print("[ChunkManager] Chunk unload QUEUED: %v" % chunk_coords)
		return

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
## Uses hybrid sync/async loading: player's chunk loads immediately, rest queued
func update_active_chunks(player_pos: Vector2i) -> void:
	if not is_chunk_mode:
		return

	# Prevent recursive calls (reentrancy guard)
	if _updating_chunks:
		push_warning("[ChunkManager] Recursive call to update_active_chunks detected, ignoring")
		return

	_updating_chunks = true
	var start_time = Time.get_ticks_usec()

	var player_chunk = world_to_chunk(player_pos)
	_current_player_chunk = player_chunk  # Store for priority sorting

	# Get island bounds
	var island_settings = BiomeManager.get_island_settings()
	var max_chunk_x = island_settings.get("width_chunks", 50)
	var max_chunk_y = island_settings.get("height_chunks", 50)

	# STEP 1: Unload distant chunks FIRST (synchronous - fast operation)
	var chunks_to_unload: Array[Vector2i] = []
	for coords in active_chunks:
		# Chebyshev distance (max of x/y differences) for square loading area
		var distance = max(abs(coords.x - player_chunk.x), abs(coords.y - player_chunk.y))
		if distance > unload_radius:
			chunks_to_unload.append(coords)

	var unload_start = Time.get_ticks_usec()
	for coords in chunks_to_unload:
		unload_chunk(coords)
	var unload_time = Time.get_ticks_usec() - unload_start

	# STEP 2: Calculate which chunks should be loaded
	var chunks_to_load: Array[Vector2i] = []
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var chunk_coords = player_chunk + Vector2i(dx, dy)
			# Skip chunks outside island bounds
			if chunk_coords.x >= 0 and chunk_coords.x < max_chunk_x and chunk_coords.y >= 0 and chunk_coords.y < max_chunk_y:
				if chunk_coords not in active_chunks:
					chunks_to_load.append(chunk_coords)

	# STEP 3: Load player's CURRENT chunk IMMEDIATELY (synchronous)
	# This ensures the player always has valid ground beneath them
	var sync_loaded = 0
	var load_start = Time.get_ticks_usec()

	if player_chunk not in active_chunks:
		# Check bounds
		if player_chunk.x >= 0 and player_chunk.x < max_chunk_x and player_chunk.y >= 0 and player_chunk.y < max_chunk_y:
			var chunk = load_chunk(player_chunk)
			if chunk:
				sync_loaded += 1
		# Remove from chunks_to_load since we just loaded it
		var idx = chunks_to_load.find(player_chunk)
		if idx >= 0:
			chunks_to_load.remove_at(idx)

	var sync_load_time = Time.get_ticks_usec() - load_start

	# STEP 4: Queue remaining chunks for async loading
	var queued_count = 0
	for coords in chunks_to_load:
		_queue_chunk_for_loading(coords)
		queued_count += 1

	var total_time = Time.get_ticks_usec() - start_time

	# Log performance
	if sync_loaded > 0 or chunks_to_unload.size() > 0 or queued_count > 0 or total_time > 5000:
		print("[ChunkManager] update_active_chunks: sync_loaded=%d (%.2fms), unloaded=%d (%.2fms), queued=%d, total=%.2fms" % [
			sync_loaded, sync_load_time / 1000.0,
			chunks_to_unload.size(), unload_time / 1000.0,
			queued_count,
			total_time / 1000.0
		])

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

	# If frozen and chunk not available, return null (caller handles gracefully)
	# This prevents LOF checks from seeing through walls when chunks are frozen
	if _chunk_ops_frozen:
		return null

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
	_clear_async_queue()  # Clear pending async loads
	print("[ChunkManager] All chunks cleared")

## Handle map changes
func _on_map_changed(map_id: String) -> void:
	# Clear async queue to prevent stale loads
	_clear_async_queue()

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
