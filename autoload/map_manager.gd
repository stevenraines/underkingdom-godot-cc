extends Node

## MapManager - Manages multiple maps, handles transitions, caching
##
## Keeps track of loaded maps and provides methods for generating
## and transitioning between maps.

var loaded_maps: Dictionary = {}  # map_id -> GameMap
var current_map: GameMap = null
var current_dungeon_floor: int = 0  # Track which dungeon floor player is on (0 = overworld)

func _ready() -> void:
	print("MapManager initialized")

## Get or generate a map by ID
func get_or_generate_map(map_id: String, seed: int) -> GameMap:
	# Check cache first
	if map_id in loaded_maps:
		print("Loading cached map: ", map_id)
		return loaded_maps[map_id]

	# Generate new map
	var map = _generate_map(map_id, seed)
	loaded_maps[map_id] = map
	return map

## Transition to a different map
func transition_to_map(map_id: String) -> void:
	current_map = get_or_generate_map(map_id, GameManager.world_seed)
	GameManager.set_current_map(map_id)

	# Enable chunk mode for overworld
	if map_id == "overworld":
		current_map.chunk_based = true
		ChunkManager.enable_chunk_mode(map_id, GameManager.world_seed)
	else:
		current_map.chunk_based = false
		ChunkManager.enable_chunk_mode(map_id, GameManager.world_seed)

	EventBus.map_changed.emit(map_id)
	print("Transitioned to map: ", map_id)

## Generate a map based on its ID
func _generate_map(map_id: String, seed: int) -> GameMap:
	if map_id == "overworld":
		# For overworld, create empty map shell - chunks generated on demand
		print("[MapManager] Creating chunk-based overworld map")
		var map = GameMap.new("overworld", 10000, 10000, seed)  # Virtually infinite bounds
		map.chunk_based = true

		# Note: Terrain generation happens in ChunkManager on demand
		# Use SpecialFeaturePlacer to find suitable biome-based locations for special features

		# Place dungeon entrance in suitable biome (rocky hills, mountains, barren rock)
		var entrance_pos = SpecialFeaturePlacer.place_dungeon_entrance(seed)

		# Place town in suitable biome (grassland, woodland) not too close to dungeon
		var town_pos = SpecialFeaturePlacer.place_town(seed, entrance_pos)

		# Store special positions in map metadata
		# ChunkManager will check these and place actual tiles when chunks load
		map.set_meta("dungeon_entrance", entrance_pos)
		map.set_meta("town_center", town_pos)

		print("[MapManager] Special features placed: dungeon=%v, town=%v" % [entrance_pos, town_pos])

		return map

	elif map_id.begins_with("dungeon_barrow_floor_"):
		# Extract floor number from map_id
		var floor_str = map_id.replace("dungeon_barrow_floor_", "")
		var floor_number = int(floor_str)
		return BurialBarrowGenerator.generate_floor(seed, floor_number)
	else:
		push_error("Unknown map ID: " + map_id)
		# Return empty map as fallback
		return GameMap.new(map_id, 50, 50, seed)

## Descend to next dungeon floor
func descend_dungeon() -> void:
	current_dungeon_floor += 1
	var map_id = "dungeon_barrow_floor_%d" % current_dungeon_floor
	transition_to_map(map_id)

## Ascend to previous dungeon floor or overworld
func ascend_dungeon() -> void:
	current_dungeon_floor -= 1

	if current_dungeon_floor >= 1:
		var map_id = "dungeon_barrow_floor_%d" % current_dungeon_floor
		transition_to_map(map_id)
	else:
		# Return to overworld (floor 0 or below means overworld)
		current_dungeon_floor = 0  # Reset to 0 when on overworld
		transition_to_map("overworld")

## Clear map cache (useful for testing regeneration)
func clear_cache() -> void:
	loaded_maps.clear()
	print("Map cache cleared")
