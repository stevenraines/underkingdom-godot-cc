extends Node

## StructureManager - Autoload singleton for structure management
##
## Loads structure definitions from JSON files and manages placed structures.
## Tracks structures per map to persist them across map regeneration.

# Preload Structure class
const Structure = preload("res://entities/structure.gd")

# Structure data cache (id -> data dictionary)
var structure_definitions: Dictionary = {}

# Placed structures per map (map_id -> Array[Structure])
var placed_structures: Dictionary = {}

# Base path for structure data
const STRUCTURE_DATA_PATH: String = "res://data/structures"

func _ready() -> void:
	_load_structure_definitions()
	print("StructureManager: Loaded %d structure definitions" % structure_definitions.size())

## Load all structure definitions from JSON files
func _load_structure_definitions() -> void:
	var dir = DirAccess.open(STRUCTURE_DATA_PATH)
	if not dir:
		push_warning("StructureManager: Could not open directory: %s" % STRUCTURE_DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var full_path = STRUCTURE_DATA_PATH + "/" + file_name
			_load_structure_from_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

## Load a single structure definition from a JSON file
func _load_structure_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("StructureManager: File not found: %s" % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("StructureManager: Could not open file: %s" % path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("StructureManager: JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return

	var data = json.data
	if data is Dictionary and "id" in data:
		var structure_id = data.get("id", "")
		if structure_id != "":
			structure_definitions[structure_id] = data
		else:
			push_warning("StructureManager: Structure without ID in %s" % path)
	else:
		push_warning("StructureManager: Invalid structure file format in %s" % path)

## Create a structure instance from definition
func create_structure(structure_id: String, pos: Vector2i):
	if not structure_definitions.has(structure_id):
		push_error("StructureManager: Unknown structure ID: %s" % structure_id)
		return null

	var data = structure_definitions[structure_id]
	return Structure.create_from_data(data, pos)

## Place a structure on a map (registers for persistence)
func place_structure(map_id: String, structure) -> void:
	if not placed_structures.has(map_id):
		placed_structures[map_id] = []

	placed_structures[map_id].append(structure)
	EventBus.structure_placed.emit(structure)

## Remove a structure from a map
func remove_structure(map_id: String, structure) -> void:
	if not placed_structures.has(map_id):
		return

	var structures = placed_structures[map_id]
	var index = structures.find(structure)
	if index >= 0:
		structures.remove_at(index)
		EventBus.structure_removed.emit(structure)

## Get all structures on a map
func get_structures_on_map(map_id: String) -> Array:
	if not placed_structures.has(map_id):
		return []

	# Return a copy to prevent external modification
	var result: Array = []
	for structure in placed_structures[map_id]:
		result.append(structure)
	return result

## Get structures at a specific position
func get_structures_at(pos: Vector2i, map_id: String) -> Array:
	var result: Array = []

	if not placed_structures.has(map_id):
		return result

	for structure in placed_structures[map_id]:
		if structure.position == pos:
			result.append(structure)

	return result

## Get structures within a radius of a position (Manhattan distance)
func get_structures_in_radius(center: Vector2i, radius: int, map_id: String) -> Array:
	var result: Array = []

	if not placed_structures.has(map_id):
		return result

	for structure in placed_structures[map_id]:
		var distance = abs(structure.position.x - center.x) + abs(structure.position.y - center.y)
		if distance <= radius:
			result.append(structure)

	return result

## Get fire sources within radius (convenience method for crafting)
func get_fire_sources_in_radius(center: Vector2i, radius: int, map_id: String) -> Array:
	var result: Array = []

	var nearby = get_structures_in_radius(center, radius, map_id)
	for structure in nearby:
		if structure.is_fire_source and structure.is_active:
			result.append(structure)

	return result

## Restore placed structures to a map after regeneration
## Called by MapManager after procedural generation
func restore_structures_to_map(map_id: String) -> void:
	# Structures are managed separately, no need to do anything here
	# The map's entity list is handled by the game scene during rendering
	pass

## Clear all structures (for new game)
func clear_all_structures() -> void:
	placed_structures.clear()

## Serialize all placed structures for save system
func serialize() -> Dictionary:
	var data = {
		"placed_structures": {}
	}

	for map_id in placed_structures:
		data.placed_structures[map_id] = []
		for structure in placed_structures[map_id]:
			data.placed_structures[map_id].append(structure.serialize())

	return data

## Deserialize placed structures from save data
func deserialize(data: Dictionary) -> void:
	placed_structures.clear()

	if not data.has("placed_structures"):
		return

	for map_id in data.placed_structures:
		placed_structures[map_id] = []
		for structure_data in data.placed_structures[map_id]:
			var structure = Structure.deserialize(structure_data, structure_definitions)
			if structure:
				placed_structures[map_id].append(structure)
