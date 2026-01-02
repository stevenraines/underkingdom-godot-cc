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
		var cached_map = loaded_maps[map_id]
		print("Loading cached map: %s (internal map_id=%s, tiles=%d)" % [map_id, cached_map.map_id, cached_map.tiles.size()])
		return cached_map

	# Generate new map
	var map = _generate_map(map_id, seed)
	print("Generated new map: %s (internal map_id=%s, tiles=%d)" % [map_id, map.map_id, map.tiles.size()])
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

	# Load features and hazards into their managers for dungeon maps
	if map_id.begins_with("dungeon_"):
		_load_features_and_hazards(current_map)

	EventBus.map_changed.emit(map_id)
	print("Transitioned to map: ", map_id)


## Load features and hazards from map metadata into managers
func _load_features_and_hazards(map: GameMap) -> void:
	# Load features into FeatureManager
	FeatureManager.load_features_from_map(map)

	# Load hazards into HazardManager
	HazardManager.load_hazards_from_map(map)

## Generate a map based on its ID
func _generate_map(map_id: String, seed: int) -> GameMap:
	if map_id == "overworld":
		# For overworld, create empty map shell - chunks generated on demand
		print("[MapManager] Creating chunk-based overworld map")
		var map = GameMap.new("overworld", 10000, 10000, seed)  # Virtually infinite bounds
		map.chunk_based = true

		# Note: Terrain generation happens in ChunkManager on demand
		# Use SpecialFeaturePlacer to find suitable biome-based locations for special features

		# Place town first in suitable biome (grassland, woodland)
		var town_pos = SpecialFeaturePlacer.place_town(seed)

		# Place dungeon entrance 10-20 tiles from town in suitable biome
		var entrance_pos = SpecialFeaturePlacer.place_dungeon_entrance(seed, town_pos)

		# Place player spawn just outside town (10 tiles away, opposite from dungeon)
		var player_spawn = SpecialFeaturePlacer.place_player_spawn(town_pos, entrance_pos, seed)

		# Store special positions in map metadata
		# ChunkManager will check these and place actual tiles when chunks load
		map.set_meta("dungeon_entrance", entrance_pos)
		map.set_meta("town_center", town_pos)
		map.set_meta("player_spawn", player_spawn)

		# Store shop NPC spawn data in metadata
		var shop_npc_pos = town_pos  # Center of shop (5x5 building centered on town_pos)
		map.set_meta("npc_spawns", [{
			"npc_type": "shop",
			"npc_id": "shop_keeper",
			"position": shop_npc_pos,
			"name": "Olaf the Trader",
			"gold": 500,
			"restock_interval": 500
		}])

		print("[MapManager] Special features placed: town=%v, dungeon=%v, spawn=%v" % [town_pos, entrance_pos, player_spawn])

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
