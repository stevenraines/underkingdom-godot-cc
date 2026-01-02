extends Node
## Manages dungeon definitions and provides dungeon data to generators
##
## DungeonManager is an autoload singleton that loads dungeon definitions
## from JSON files and provides access to dungeon parameters for procedural
## generation. All dungeon types are data-driven and defined in data/dungeons/

const DUNGEON_DATA_PATH = "res://data/dungeons"
const _GeneratorFactory = preload("res://generation/dungeon_generator_factory.gd")

## Dictionary mapping dungeon IDs to their full definitions
## Format: { "dungeon_id": { ...dungeon_data... } }
var dungeon_definitions: Dictionary = {}

## Whether dungeons have been loaded
var loaded: bool = false


func _ready() -> void:
	load_dungeon_definitions()


## Load all dungeon definitions from JSON files in DUNGEON_DATA_PATH
func load_dungeon_definitions() -> void:
	if loaded:
		return

	var dir = DirAccess.open(DUNGEON_DATA_PATH)
	if not dir:
		push_error("Failed to open dungeon data directory: " + DUNGEON_DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = DUNGEON_DATA_PATH + "/" + file_name
			_load_dungeon_file(file_path)
		file_name = dir.get_next()

	dir.list_dir_end()
	loaded = true
	print("[DungeonManager] Loaded %d dungeon types" % dungeon_definitions.size())


## Load a single dungeon definition JSON file
func _load_dungeon_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open dungeon file: " + file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data = json.data
	if not data.has("id"):
		push_error("Dungeon definition missing 'id' field: " + file_path)
		return

	dungeon_definitions[data["id"]] = data
	print("[DungeonManager] Loaded dungeon type: %s" % data["id"])


## Get dungeon definition by ID
## Returns the full dungeon definition dictionary, or fallback if not found
func get_dungeon(dungeon_id: String) -> Dictionary:
	if not dungeon_definitions.has(dungeon_id):
		push_warning("Unknown dungeon type: " + dungeon_id)
		return _get_fallback_definition()

	return dungeon_definitions[dungeon_id]


## Get all available dungeon type IDs
func get_all_dungeon_types() -> Array[String]:
	var types: Array[String] = []
	for id in dungeon_definitions:
		types.append(id)
	return types


## Get a random dungeon type using seeded RNG
## Useful for procedural dungeon placement in overworld
func get_random_dungeon_type(rng: SeededRandom) -> String:
	var types = get_all_dungeon_types()
	if types.size() == 0:
		return "burial_barrow"  # Fallback
	return types[rng.randi_range(0, types.size() - 1)]


## Get dungeon floor count (random within the defined range)
## Uses the dungeon's floor_count.min and floor_count.max
func get_floor_count(dungeon_id: String, rng: SeededRandom) -> int:
	var def = get_dungeon(dungeon_id)
	var floor_count = def.get("floor_count", {"min": 10, "max": 20})
	return rng.randi_range(floor_count.min, floor_count.max)


## Get map size for a dungeon type
## Returns Vector2i(width, height)
func get_map_size(dungeon_id: String) -> Vector2i:
	var def = get_dungeon(dungeon_id)
	var size = def.get("map_size", {"width": 50, "height": 50})
	return Vector2i(size.width, size.height)


## Get generator type string for a dungeon
## Returns the algorithm to use (e.g., "rectangular_rooms", "cellular_automata")
func get_generator_type(dungeon_id: String) -> String:
	var def = get_dungeon(dungeon_id)
	return def.get("generator_type", "rectangular_rooms")


## Generate a dungeon floor using the appropriate generator
## This is the primary API for creating dungeon maps
## @param dungeon_id: Dungeon type identifier (e.g., "burial_barrow", "natural_cave")
## @param floor_number: Floor number (1-based)
## @param world_seed: World seed for deterministic generation
## @returns: Generated GameMap instance
func generate_floor(dungeon_id: String, floor_number: int, world_seed: int) -> GameMap:
	var dungeon_def: Dictionary = get_dungeon(dungeon_id)
	var generator_type: String = dungeon_def.get("generator_type", "rectangular_rooms")
	# Use duck typing to avoid class_name resolution issues at parse time
	var generator = _GeneratorFactory.create(generator_type)
	var map: GameMap = generator.generate_floor(dungeon_def, floor_number, world_seed)

	# Process pending features and hazards stored by generator
	_process_pending_features(map)
	_process_pending_hazards(map)

	return map


## Process pending features stored in map metadata by generator
## Transfers feature data to FeatureManager for runtime handling
func _process_pending_features(map: GameMap) -> void:
	if not map.metadata.has("pending_features"):
		return

	var pending: Array = map.metadata.pending_features
	if pending.is_empty():
		return

	# Initialize features array in metadata
	if not map.metadata.has("features"):
		map.metadata["features"] = []

	# Process each pending feature
	for feature_data in pending:
		var pos: Vector2i = feature_data.position
		var feature_id: String = feature_data.feature_id
		var config: Dictionary = feature_data.config

		# Create feature instance
		var feature_instance: Dictionary = {
			"feature_id": feature_id,
			"position": pos,
			"config": config,
			"interacted": false,
			"state": {}
		}

		# Add loot if applicable
		if config.get("contains_loot", false):
			feature_instance.state["has_loot"] = true

		# Add summon enemy if applicable
		if config.has("summons_enemy"):
			feature_instance.state["summons_enemy"] = config.summons_enemy

		map.metadata.features.append(feature_instance)

	# Clear pending features
	map.metadata.erase("pending_features")
	print("[DungeonManager] Processed %d features" % map.metadata.features.size())


## Process pending hazards stored in map metadata by generator
## Transfers hazard data to HazardManager for runtime handling
func _process_pending_hazards(map: GameMap) -> void:
	if not map.metadata.has("pending_hazards"):
		return

	var pending: Array = map.metadata.pending_hazards
	if pending.is_empty():
		return

	# Initialize hazards array in metadata
	if not map.metadata.has("hazards"):
		map.metadata["hazards"] = []

	# Process each pending hazard
	for hazard_data in pending:
		var pos: Vector2i = hazard_data.position
		var hazard_id: String = hazard_data.hazard_id
		var config: Dictionary = hazard_data.config

		# Create hazard instance
		var hazard_instance: Dictionary = {
			"hazard_id": hazard_id,
			"position": pos,
			"config": config,
			"triggered": false,
			"detected": false,
			"disarmed": false,
			"damage": config.get("damage", 10)
		}

		map.metadata.hazards.append(hazard_instance)

	# Clear pending hazards
	map.metadata.erase("pending_hazards")
	print("[DungeonManager] Processed %d hazards" % map.metadata.hazards.size())


## Fallback definition used when a dungeon type is not found
## Provides safe defaults to prevent crashes
func _get_fallback_definition() -> Dictionary:
	return {
		"id": "unknown",
		"name": "Unknown Dungeon",
		"description": "Fallback dungeon definition",
		"generator_type": "rectangular_rooms",
		"map_size": {"width": 50, "height": 50},
		"floor_count": {"min": 5, "max": 10},
		"generation_params": {
			"room_count_range": [5, 8],
			"room_size_range": [3, 8],
			"corridor_width": 1,
			"connectivity": 0.7
		},
		"tiles": {
			"wall": "stone_wall",
			"floor": "stone_floor",
			"door": "wooden_door"
		},
		"lighting": {
			"base_visibility": 0.5,
			"torch_radius": 5
		},
		"enemy_pools": [],
		"loot_tables": [],
		"room_features": [],
		"hazards": [],
		"difficulty_curve": {
			"enemy_level_multiplier": 1.0,
			"enemy_count_base": 3,
			"enemy_count_per_floor": 0.5,
			"loot_quality_multiplier": 1.0
		}
	}
