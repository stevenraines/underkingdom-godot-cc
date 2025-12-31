class_name JsonHelper
extends Node

## JsonHelper - Small utility with static helpers to load JSON files
## Use from anywhere as `JsonHelper.load_json_file(path)`

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
