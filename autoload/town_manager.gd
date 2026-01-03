extends Node
## TownManager autoload singleton - do not use class_name to avoid conflict

## TownManager - Manages town definitions and placement
##
## Loads town definitions from JSON and handles placing multiple towns
## across the island based on biome preferences.

const DATA_PATH = "res://data/towns"
const BUILDINGS_PATH = "res://data/buildings"

var town_definitions: Dictionary = {}  # id -> town definition
var building_definitions: Dictionary = {}  # id -> building definition
var placed_towns: Array = []  # Array of placed town data

func _ready() -> void:
	_load_building_definitions()
	_load_town_definitions()
	print("[TownManager] Loaded %d town definitions, %d building definitions" % [town_definitions.size(), building_definitions.size()])

## Load all building definitions from JSON files
func _load_building_definitions() -> void:
	_load_definitions_from_path(BUILDINGS_PATH, building_definitions)

## Load all town definitions from JSON files
func _load_town_definitions() -> void:
	_load_definitions_from_path(DATA_PATH, town_definitions)

## Generic loader for JSON definition files
func _load_definitions_from_path(path: String, target_dict: Dictionary) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("[TownManager] Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_definition_file(path + "/" + file_name, target_dict)
		elif dir.current_is_dir() and not file_name.begins_with("."):
			# Recursively load subdirectories
			_load_definitions_from_path(path + "/" + file_name, target_dict)
		file_name = dir.get_next()
	dir.list_dir_end()

## Load a single definition file
func _load_definition_file(file_path: String, target_dict: Dictionary) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[TownManager] Could not open file: %s" % file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_warning("[TownManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	var id = data.get("id", "")
	if id.is_empty():
		push_warning("[TownManager] Definition missing 'id' in %s" % file_path)
		return

	target_dict[id] = data
	#print("[TownManager] Loaded definition: %s" % id)

## Get a town definition by ID
func get_town(town_id: String) -> Dictionary:
	return town_definitions.get(town_id, {})

## Get a building definition by ID
func get_building(building_id: String) -> Dictionary:
	return building_definitions.get(building_id, {})

## Get all town IDs
func get_all_town_types() -> Array:
	return town_definitions.keys()

## Get all building IDs
func get_all_building_types() -> Array:
	return building_definitions.keys()

## Clear placed towns (for new game)
func clear_placed_towns() -> void:
	placed_towns.clear()

## Add a placed town record
func add_placed_town(town_data: Dictionary) -> void:
	placed_towns.append(town_data)

## Get all placed towns
func get_placed_towns() -> Array:
	return placed_towns

## Check if a position is within any town
func is_in_any_town(position: Vector2i) -> bool:
	for town in placed_towns:
		var town_pos = town.get("position", Vector2i(-1, -1))
		var town_size = town.get("size", Vector2i(15, 15))
		var half_size = town_size / 2
		var town_rect = Rect2i(town_pos - half_size, town_size)
		if town_rect.has_point(position):
			return true
	return false

## Get the town at a position (or null if not in a town)
func get_town_at(position: Vector2i) -> Variant:
	for town in placed_towns:
		var town_pos = town.get("position", Vector2i(-1, -1))
		var town_size = town.get("size", Vector2i(15, 15))
		var half_size = town_size / 2
		var town_rect = Rect2i(town_pos - half_size, town_size)
		if town_rect.has_point(position):
			return town
	return null

## Serialize placed towns for saving
func save_placed_towns() -> Array:
	var save_data: Array = []
	for town in placed_towns:
		var town_save = town.duplicate()
		# Convert Vector2i to array for JSON
		if town_save.has("position"):
			var pos = town_save["position"]
			town_save["position"] = [pos.x, pos.y]
		if town_save.has("size"):
			var size = town_save["size"]
			town_save["size"] = [size.x, size.y]
		save_data.append(town_save)
	return save_data

## Load placed towns from save data
func load_placed_towns(save_data: Array) -> void:
	placed_towns.clear()
	for town_save in save_data:
		var town = town_save.duplicate()
		# Convert arrays back to Vector2i
		if town.has("position") and town["position"] is Array:
			var pos = town["position"]
			town["position"] = Vector2i(pos[0], pos[1])
		if town.has("size") and town["size"] is Array:
			var size = town["size"]
			town["size"] = Vector2i(size[0], size[1])
		placed_towns.append(town)
	print("[TownManager] Loaded %d placed towns from save" % placed_towns.size())
