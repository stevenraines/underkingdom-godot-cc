extends Node

## MapManager - Manages multiple maps, handles transitions, caching
##
## Keeps track of loaded maps and provides methods for generating
## and transitioning between maps.

var loaded_maps: Dictionary = {}  # map_id -> GameMap
var current_map: GameMap = null
var current_dungeon_floor: int = 0  # Track which dungeon floor player is on (0 = overworld)
var current_dungeon_type: String = ""  # Track current dungeon type (e.g., "burial_barrow")

func _ready() -> void:
	print("MapManager initialized")

## Get or generate a map by ID
func get_or_generate_map(map_id: String, world_seed: int) -> GameMap:
	# Check cache first
	if map_id in loaded_maps:
		var cached_map = loaded_maps[map_id]
		print("Loading cached map: %s (internal map_id=%s, tiles=%d)" % [map_id, cached_map.map_id, cached_map.tiles.size()])
		return cached_map

	# Generate new map
	var map = _generate_map(map_id, world_seed)
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
	# Map IDs follow format: dungeon_id_floor_N (e.g., burial_barrow_floor_1)
	var is_dungeon = "_floor_" in map_id or current_map.metadata.has("floor_number")
	if is_dungeon:
		_load_features_and_hazards(current_map)

	EventBus.map_changed.emit(map_id)
	print("Transitioned to map: ", map_id)


## Load features and hazards from map metadata into managers
func _load_features_and_hazards(map: GameMap) -> void:
	print("[MapManager] Loading features/hazards for: %s" % map.map_id)
	print("[MapManager] Map metadata keys: %s" % str(map.metadata.keys()))
	print("[MapManager] pending_features: %d" % map.metadata.get("pending_features", []).size())
	print("[MapManager] pending_hazards: %d" % map.metadata.get("pending_hazards", []).size())

	# Load dungeon hints from dungeon definition
	var dungeon_id: String = map.metadata.get("dungeon_id", "")
	if not dungeon_id.is_empty():
		var hints: Array = _load_dungeon_hints(dungeon_id)
		FeatureManager.set_dungeon_hints(hints)

	FeatureManager.load_features_from_map(map)
	HazardManager.load_hazards_from_map(map)
	print("[MapManager] After loading - active_features: %d, active_hazards: %d" % [FeatureManager.active_features.size(), HazardManager.active_hazards.size()])


## Load hints from a dungeon definition file
func _load_dungeon_hints(dungeon_id: String) -> Array:
	var file_path = "res://data/dungeons/%s.json" % dungeon_id
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[MapManager] Failed to load dungeon definition: %s" % file_path)
		return []

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_warning("[MapManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return []

	var data: Dictionary = json.data
	return data.get("hints", [])

## Generate a map based on its ID
func _generate_map(map_id: String, world_seed: int) -> GameMap:
	if map_id == "overworld":
		# For overworld, create empty map shell - chunks generated on demand
		print("[MapManager] Creating chunk-based overworld map")
		var map = GameMap.new("overworld", 10000, 10000, world_seed)  # Virtually infinite bounds
		map.chunk_based = true

		# Note: Terrain generation happens in ChunkManager on demand
		# Use SpecialFeaturePlacer to find suitable biome-based locations for special features

		# Clear any previously placed towns from TownManager
		TownManager.clear_placed_towns()

		# Place all towns based on town definitions
		var town_definitions = TownManager.town_definitions
		var towns = SpecialFeaturePlacer.place_all_towns(world_seed, town_definitions)

		# Get primary town position (first town, usually starter_town)
		var primary_town_pos = towns[0].position if towns.size() > 0 else Vector2i(400, 400)

		# Place all dungeon entrances based on dungeon definitions
		var dungeon_entrances = SpecialFeaturePlacer.place_all_dungeon_entrances(world_seed, primary_town_pos)

		# Get first wilderness dungeon for player spawn calculation
		var first_wilderness_entrance = Vector2i(primary_town_pos.x + 15, primary_town_pos.y)
		for entrance in dungeon_entrances:
			var dungeon_def = DungeonManager.get_dungeon(entrance.dungeon_type)
			if dungeon_def.get("placement", "wilderness") == "wilderness":
				first_wilderness_entrance = entrance.position
				break

		# Place player spawn just outside primary town (10 tiles away, opposite from first dungeon)
		var player_spawn = SpecialFeaturePlacer.place_player_spawn(primary_town_pos, first_wilderness_entrance, world_seed)

		# Store special positions in map metadata
		# ChunkManager will check these and place actual tiles when chunks load
		map.set_meta("town_center", primary_town_pos)  # Legacy compatibility
		map.set_meta("player_spawn", player_spawn)
		map.set_meta("dungeon_entrances", dungeon_entrances)

		# Store all towns in metadata for multi-town support
		map.metadata["towns"] = towns

		# Initialize empty NPC spawns array (will be populated when town chunks generate)
		map.metadata["npc_spawns"] = []

		print("[MapManager] Special features placed: %d towns, %d dungeons, spawn=%v" % [towns.size(), dungeon_entrances.size(), player_spawn])
		for town in towns:
			print("[MapManager]   - %s at %v" % [town.name, town.position])

		return map

	elif "_floor_" in map_id:
		# Generic dungeon floor handling: dungeon_type_floor_N
		# Extract dungeon type and floor number
		var floor_idx = map_id.find("_floor_")
		var dungeon_type = map_id.substr(0, floor_idx)
		var floor_str = map_id.substr(floor_idx + 7)  # Skip "_floor_"
		var floor_number = int(floor_str)

		print("[MapManager] Generating %s floor %d" % [dungeon_type, floor_number])

		# Use DungeonManager to generate the floor with the correct generator
		return DungeonManager.generate_floor(dungeon_type, floor_number, world_seed)
	else:
		push_error("Unknown map ID: " + map_id)
		# Return empty map as fallback
		return GameMap.new(map_id, 50, 50, world_seed)

## Enter a dungeon from its entrance
## dungeon_type: e.g., "burial_barrow", "sewers", "natural_cave"
func enter_dungeon(dungeon_type: String) -> void:
	current_dungeon_type = dungeon_type
	current_dungeon_floor = 1
	var map_id = "%s_floor_%d" % [dungeon_type, current_dungeon_floor]
	transition_to_map(map_id)

## Descend to next dungeon floor
func descend_dungeon() -> void:
	current_dungeon_floor += 1
	var map_id = "%s_floor_%d" % [current_dungeon_type, current_dungeon_floor]
	transition_to_map(map_id)

## Ascend to previous dungeon floor or overworld
func ascend_dungeon() -> void:
	current_dungeon_floor -= 1

	if current_dungeon_floor >= 1:
		var map_id = "%s_floor_%d" % [current_dungeon_type, current_dungeon_floor]
		transition_to_map(map_id)
	else:
		# Return to overworld (floor 0 or below means overworld)
		current_dungeon_floor = 0  # Reset to 0 when on overworld
		current_dungeon_type = ""  # Clear dungeon type
		transition_to_map("overworld")

## Get dungeon entrance info at a position, or null if no entrance there
func get_dungeon_entrance_at(pos: Vector2i) -> Variant:
	if not current_map:
		return null
	var entrances = current_map.get_meta("dungeon_entrances", [])
	for entrance in entrances:
		if entrance.position == pos:
			return entrance
	return null

## Clear map cache (useful for testing regeneration)
func clear_cache() -> void:
	loaded_maps.clear()
	print("Map cache cleared")
