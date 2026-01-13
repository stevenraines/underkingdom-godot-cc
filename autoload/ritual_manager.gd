extends Node

## RitualManager - Autoload for loading and managing ritual definitions
##
## Loads ritual JSON files from data/rituals/ and provides access to them.

const RITUAL_DATA_PATH = "res://data/rituals"

var rituals: Dictionary = {}  # id -> Ritual


func _ready() -> void:
	_load_rituals()
	print("RitualManager initialized with %d rituals" % rituals.size())


## Load all ritual definitions
func _load_rituals() -> void:
	_load_from_directory(RITUAL_DATA_PATH)


## Recursively load rituals from a directory
func _load_from_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name
		if dir.current_is_dir() and not file_name.begins_with("."):
			_load_from_directory(full_path)
		elif file_name.ends_with(".json"):
			_load_ritual_file(full_path)
		file_name = dir.get_next()

	dir.list_dir_end()


## Load a single ritual file
func _load_ritual_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("Failed to open ritual file: %s" % path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error == OK:
		var data = json.get_data()
		if data is Dictionary:
			var ritual = Ritual.from_dict(data)
			rituals[ritual.id] = ritual
	else:
		push_warning("Failed to parse ritual file: %s" % path)


## Get a ritual by ID
func get_ritual(ritual_id: String) -> Ritual:
	return rituals.get(ritual_id)


## Get all rituals
func get_all_rituals() -> Array:
	return rituals.values()


## Get all rituals of a specific school
func get_rituals_by_school(school: String) -> Array:
	var result: Array = []
	for ritual in rituals.values():
		if ritual.school == school:
			result.append(ritual)
	return result


## Check if a ritual exists
func ritual_exists(ritual_id: String) -> bool:
	return ritual_id in rituals
