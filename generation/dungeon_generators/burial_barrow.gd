class_name BurialBarrowGenerator
## BurialBarrowGenerator - Backward compatibility wrapper for burial barrow dungeons
##
## Delegates to the new data-driven RectangularRoomsGenerator using burial_barrow.json
## Maintains the existing API: generate_floor(world_seed, floor_number) -> GameMap
##
## DEPRECATED: New code should use DungeonManager.generate_floor("burial_barrow", floor_number, world_seed)

const DUNGEON_FILE_PATH = "res://data/dungeons/burial_barrow.json"
const GENERATOR_PATH = "res://generation/dungeon_generators/rectangular_rooms_generator.gd"


## Generate a burial barrow dungeon floor (backward compatible API)
## @param world_seed: World seed for deterministic generation
## @param floor_number: Current floor number (1-based)
## @returns: Generated GameMap instance
static func generate_floor(world_seed: int, floor_number: int):
	# Load dungeon definition directly (can't access autoloads from static function)
	var dungeon_def: Dictionary = _load_dungeon_definition()

	# Load and create the rectangular rooms generator at runtime
	var generator_script = load(GENERATOR_PATH)
	if generator_script == null:
		push_error("Failed to load generator script: " + GENERATOR_PATH)
		return null

	var generator = generator_script.new()

	# Generate the floor
	var map = generator.generate_floor(dungeon_def, floor_number, world_seed)
	print("Burial barrow floor %d generated (backward compatibility wrapper)" % floor_number)
	return map


## Load burial barrow dungeon definition from JSON
static func _load_dungeon_definition() -> Dictionary:
	var file = FileAccess.open(DUNGEON_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open burial barrow definition: " + DUNGEON_FILE_PATH)
		return _get_fallback_definition()

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("JSON parse error in burial_barrow.json: " + json.get_error_message())
		return _get_fallback_definition()

	return json.data


## Fallback definition if JSON loading fails
static func _get_fallback_definition() -> Dictionary:
	return {
		"id": "burial_barrow",
		"name": "Burial Barrow",
		"generator_type": "rectangular_rooms",
		"map_size": {"width": 50, "height": 50},
		"generation_params": {
			"room_count_range": [5, 8],
			"room_size_range": [3, 8],
			"corridor_width": 1,
			"connectivity": 0.7
		},
		"tiles": {
			"wall": "stone_wall",
			"floor": "stone_floor"
		},
		"enemy_pools": [],
		"difficulty_curve": {
			"enemy_level_multiplier": 1.0,
			"enemy_count_base": 3,
			"enemy_count_per_floor": 0.5
		}
	}
