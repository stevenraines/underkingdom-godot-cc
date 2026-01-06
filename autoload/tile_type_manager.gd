extends Node
## TileTypeManager autoload singleton - do not use class_name to avoid conflict

## TileTypeManager - Manages tile type definitions
##
## Loads tile type definitions from JSON and provides access to tile properties
## like display_name, ascii_char, walkable, transparent, etc.

const DATA_PATH = "res://data/tiles"

var tile_definitions: Dictionary = {}  # id -> tile definition
var ascii_char_to_definition: Dictionary = {}  # ascii_char -> tile definition (for lookup by char)

func _ready() -> void:
	_load_tile_definitions()
	print("[TileTypeManager] Loaded %d tile type definitions" % tile_definitions.size())

## Load all tile type definitions from JSON files
func _load_tile_definitions() -> void:
	var dir = DirAccess.open(DATA_PATH)
	if not dir:
		push_warning("[TileTypeManager] Could not open directory: %s" % DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_definition_file(DATA_PATH + "/" + file_name)
		elif dir.current_is_dir() and not file_name.begins_with("."):
			# Recursively load subdirectories
			_load_definitions_from_subdirectory(DATA_PATH + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Recursively load from subdirectory
func _load_definitions_from_subdirectory(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_definition_file(path + "/" + file_name)
		elif dir.current_is_dir() and not file_name.begins_with("."):
			_load_definitions_from_subdirectory(path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Load a single tile type definition file
func _load_definition_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[TileTypeManager] Could not open file: %s" % file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_warning("[TileTypeManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	var id = data.get("id", "")
	if id.is_empty():
		push_warning("[TileTypeManager] Tile definition missing 'id' in %s" % file_path)
		return

	tile_definitions[id] = data

	# Also index by ascii_char for reverse lookup
	var ascii_char = data.get("ascii_char", "")
	if not ascii_char.is_empty():
		ascii_char_to_definition[ascii_char] = data

## Get a tile type definition by ID
func get_tile_definition(tile_id: String) -> Dictionary:
	return tile_definitions.get(tile_id, {})

## Get a tile type definition by ASCII character
func get_definition_by_ascii_char(ascii_char: String) -> Dictionary:
	return ascii_char_to_definition.get(ascii_char, {})

## Get all tile type IDs
func get_all_tile_types() -> Array:
	return tile_definitions.keys()

## Check if a tile type is defined
func has_tile_type(tile_id: String) -> bool:
	return tile_definitions.has(tile_id)

## Get the display name for a tile type
## For doors, can optionally specify the state (open, closed, locked)
func get_display_name(tile_id: String, door_state: String = "") -> String:
	var definition = get_tile_definition(tile_id)
	if definition.is_empty():
		# Fallback for unknown types
		if tile_id != "" and tile_id != "floor":
			return "a " + tile_id.replace("_", " ")
		return "an obstacle"

	# Handle door states
	if tile_id == "door" and not door_state.is_empty():
		match door_state:
			"open":
				return definition.get("display_name_open", definition.get("display_name", "a door"))
			"closed":
				return definition.get("display_name_closed", definition.get("display_name", "a door"))
			"locked":
				return definition.get("display_name_locked", definition.get("display_name", "a door"))

	return definition.get("display_name", "an obstacle")

## Get the display name for a tile based on its ASCII character
## Useful for special structures/features rendered on floor tiles
func get_display_name_by_ascii_char(ascii_char: String) -> String:
	var definition = get_definition_by_ascii_char(ascii_char)
	if definition.is_empty():
		return ""  # Return empty string so caller can fall back to other logic
	return definition.get("display_name", "")

## Get the ASCII character for a tile type
func get_ascii_char(tile_id: String) -> String:
	var definition = get_tile_definition(tile_id)
	return definition.get("ascii_char", ".")

## Get whether a tile type is walkable
func is_walkable(tile_id: String) -> bool:
	var definition = get_tile_definition(tile_id)
	return definition.get("walkable", true)

## Get whether a tile type is transparent (for FOV)
func is_transparent(tile_id: String) -> bool:
	var definition = get_tile_definition(tile_id)
	return definition.get("transparent", true)

## Get the harvestable resource ID for a tile type (if any)
func get_harvestable_resource_id(tile_id: String) -> String:
	var definition = get_tile_definition(tile_id)
	return definition.get("harvestable_resource_id", "")

## Get whether a tile is a fire source
func is_fire_source(tile_id: String) -> bool:
	var definition = get_tile_definition(tile_id)
	return definition.get("is_fire_source", false)

## Get whether a tile can have crops planted on it
func can_plant(tile_id: String) -> bool:
	var definition = get_tile_definition(tile_id)
	return definition.get("can_plant", false)
