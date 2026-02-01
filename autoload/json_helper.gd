class_name JsonHelper
extends Node

## JsonHelper - Utility class for JSON loading and parsing
##
## Provides static methods for:
## - Loading individual JSON files
## - Recursively loading all JSON files from a directory
## - Parsing common data types from JSON values

## Load a single JSON file and return its parsed contents
static func load_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("JsonHelper: File not found: %s" % path)
		return []

	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("JsonHelper: Could not open file: %s" % path)
		return []

	var text = f.get_as_text()
	f.close()

	var j = JSON.new()
	if j.parse(text) != OK:
		push_error("JsonHelper: Failed to parse JSON: %s" % path)
		return []

	return j.data


## Recursively load all JSON files from a directory
## Returns array of dictionaries: [{"path": "...", "data": {...}}, ...]
static func load_all_from_directory(base_path: String, recursive: bool = true) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_scan_directory(base_path, recursive, results)
	return results


## Internal recursive directory scanner
static func _scan_directory(path: String, recursive: bool, results: Array[Dictionary]) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("JsonHelper: Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name

		if dir.current_is_dir():
			# Skip hidden folders, recurse into others if enabled
			if recursive and not file_name.begins_with("."):
				_scan_directory(full_path, recursive, results)
		elif file_name.ends_with(".json"):
			# Load JSON file
			var data = load_json_file(full_path)
			if data != null and (data is Dictionary or data is Array):
				results.append({"path": full_path, "data": data})

		file_name = dir.get_next()

	dir.list_dir_end()


## Parse a value into Vector2i from various formats
## Supports: Vector2i, String "(x, y)", Dictionary {"x": n, "y": n}, Array [x, y]
static func parse_vector2i(value) -> Vector2i:
	if value == null:
		return Vector2i.ZERO

	if value is Vector2i:
		return value

	if value is Vector2:
		return Vector2i(int(value.x), int(value.y))

	if value is String:
		var cleaned = value.strip_edges().replace("(", "").replace(")", "")
		var parts = cleaned.split(",")
		if parts.size() != 2:
			push_warning("JsonHelper: Invalid Vector2i string format: %s" % value)
			return Vector2i.ZERO
		return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))

	if value is Dictionary:
		return Vector2i(
			int(value.get("x", 0)),
			int(value.get("y", 0))
		)

	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))

	push_warning("JsonHelper: Cannot parse Vector2i from type: %s" % typeof(value))
	return Vector2i.ZERO


## Parse a value into Color from various formats
## Supports: Color, String "#RRGGBB" or "#RRGGBBAA", Dictionary {"r":, "g":, "b":, "a":}
static func parse_color(value, default: Color = Color.WHITE) -> Color:
	if value == null:
		return default

	if value is Color:
		return value

	if value is String:
		if value.begins_with("#"):
			return Color.html(value)
		# Try named colors
		var named = Color.from_string(value, default)
		return named

	if value is Dictionary:
		return Color(
			value.get("r", 1.0),
			value.get("g", 1.0),
			value.get("b", 1.0),
			value.get("a", 1.0)
		)

	if value is Array and value.size() >= 3:
		return Color(
			value[0],
			value[1],
			value[2],
			value[3] if value.size() > 3 else 1.0
		)

	return default


## Parse a value into float, with optional default
static func parse_float(value, default: float = 0.0) -> float:
	if value == null:
		return default
	if value is float or value is int:
		return float(value)
	if value is String:
		if value.is_valid_float():
			return value.to_float()
	return default


## Parse a value into int, with optional default
static func parse_int(value, default: int = 0) -> int:
	if value == null:
		return default
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String:
		if value.is_valid_int():
			return value.to_int()
	return default
