# Refactor 01: Extend JsonHelper

**Risk Level**: Zero
**Estimated Changes**: 1 file modified, then 10+ files updated

---

## Goal

Extend `autoload/json_helper.gd` to eliminate duplicate code patterns found in 10+ manager files:
1. Recursive directory scanning for JSON files
2. Vector2i parsing from various formats
3. Color parsing from strings

---

## Current State

### JsonHelper (26 lines)
Currently only has `load_json_file()`:
```gdscript
static func load_json_file(path: String) -> Variant:
    # ... basic JSON loading
```

### Duplicate Pattern in 10+ Managers
Each manager duplicates this ~25-line pattern:
```gdscript
func _load_*_from_folder(path: String) -> void:
    var dir = DirAccess.open(path)
    if not dir:
        push_warning("...")
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()

    while file_name != "":
        var full_path = path + "/" + file_name

        if dir.current_is_dir():
            if not file_name.begins_with("."):
                _load_*_from_folder(full_path)  # Recursive
        elif file_name.ends_with(".json"):
            _load_*_from_file(full_path)

        file_name = dir.get_next()

    dir.list_dir_end()
```

### Duplicate Vector Parsing (3 files)
```gdscript
func _parse_vector2i(value) -> Vector2i:
    if value is Vector2i:
        return value
    if value is String:
        # Parse "(x, y)" format
    if value is Dictionary:
        return Vector2i(value.get("x", 0), value.get("y", 0))
    return Vector2i.ZERO
```

---

## Implementation

### Step 1: Update autoload/json_helper.gd

Replace the entire file with:

```gdscript
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
```

---

### Step 2: Update EntityManager

In `autoload/entity_manager.gd`, replace:

**Remove** the `_load_enemies_from_folder()` method (lines 39-61) and update `_load_enemy_definitions()`:

```gdscript
## Load all enemy definitions by recursively scanning folders
func _load_enemy_definitions() -> void:
	var files = JsonHelper.load_all_from_directory(ENEMY_DATA_BASE_PATH)
	for file_entry in files:
		_process_enemy_data(file_entry.path, file_entry.data)
	#print("EntityManager: Loaded %d enemy definitions" % enemy_definitions.size())


## Process loaded enemy data (handles both single and multi-enemy formats)
func _process_enemy_data(file_path: String, data) -> void:
	# Handle single enemy file (new format with "id" field)
	if data is Dictionary and "id" in data:
		var enemy_id = data.get("id", "")
		if enemy_id != "":
			enemy_definitions[enemy_id] = data
			print("Loaded enemy definition: ", enemy_id)
		else:
			push_warning("EntityManager: Enemy without ID in %s" % file_path)
	# Handle old multi-enemy format for backwards compatibility
	elif data is Dictionary and "enemies" in data:
		for enemy_data in data["enemies"]:
			var enemy_id = enemy_data.get("id", "")
			if enemy_id != "":
				enemy_definitions[enemy_id] = enemy_data
				print("Loaded enemy definition: ", enemy_id)
			else:
				push_warning("EntityManager: Enemy without ID in %s" % file_path)
	else:
		push_warning("EntityManager: Invalid enemy format in %s" % file_path)
```

**Remove** `_load_enemy_from_file()` method (lines 64-100+) - functionality absorbed into `_process_enemy_data()`.

**Replace** `_parse_vector2i()` usage with `JsonHelper.parse_vector2i()`.

---

### Step 3: Update Other Managers

Apply similar changes to these files:

| File | Method to Remove | Replacement |
|------|-----------------|-------------|
| `feature_manager.gd` | `_load_feature_definitions_recursive()` | Use `JsonHelper.load_all_from_directory()` |
| `hazard_manager.gd` | `_load_hazard_definitions_recursive()` | Use `JsonHelper.load_all_from_directory()` |
| `item_manager.gd` | `_load_items_from_folder()` | Use `JsonHelper.load_all_from_directory()` |
| `recipe_manager.gd` | `_load_recipes_from_folder()` | Use `JsonHelper.load_all_from_directory()` |
| `spell_manager.gd` | `_load_spells_from_folder()` | Use `JsonHelper.load_all_from_directory()` |
| `variant_manager.gd` | `_load_templates_from_folder()`, `_load_variants_from_folder()` | Use `JsonHelper.load_all_from_directory()` |
| `creature_type_manager.gd` | `_load_creature_types_from_folder()` | Use `JsonHelper.load_all_from_directory()` |
| `tile_type_manager.gd` | `_load_tile_types_from_folder()` | Use `JsonHelper.load_all_from_directory()` |
| `biome_manager.gd` | `_load_biomes_from_folder()` | Use `JsonHelper.load_all_from_directory()` |

For files using `_parse_vector2i()`:
| File | Replace With |
|------|--------------|
| `entity_manager.gd` | `JsonHelper.parse_vector2i()` |
| `feature_manager.gd` | `JsonHelper.parse_vector2i()` |
| `hazard_manager.gd` | `JsonHelper.parse_vector2i()` |

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Create new world - enemies spawn correctly
- [ ] Enter dungeon - features appear correctly
- [ ] Check hazards spawn in appropriate locations
- [ ] Items can be found/picked up
- [ ] Spells work correctly
- [ ] Crafting recipes load and work
- [ ] Biomes render correctly on overworld
- [ ] Save game and load - all data preserved
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- autoload/json_helper.gd
git checkout HEAD -- autoload/entity_manager.gd
# ... etc for other modified files
```

Or revert entire commit:
```bash
git revert HEAD
```
