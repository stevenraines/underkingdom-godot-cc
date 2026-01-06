extends Node

## ItemManager - Autoload singleton for item data management
##
## Loads item definitions from JSON files and creates item instances.
## Items are loaded from individual JSON files in the data/items folder
## and all subfolders recursively.

# Preload ItemFactory for template-based item creation
const ItemFactoryClass = preload("res://items/item_factory.gd")

# Item data cache (id -> data dictionary)
var _item_data: Dictionary = {}

# Base path for item data
const ITEM_DATA_BASE_PATH: String = "res://data/items"

func _ready() -> void:
	_load_all_items()
	print("ItemManager: Loaded %d item definitions" % _item_data.size())

## Load all item definitions by recursively scanning folders
func _load_all_items() -> void:
	_load_items_from_folder(ITEM_DATA_BASE_PATH)

## Recursively load items from a folder and all subfolders
func _load_items_from_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("ItemManager: Could not open directory: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + "/" + file_name
		
		if dir.current_is_dir():
			# Skip hidden folders and navigate into subfolders
			if not file_name.begins_with("."):
				_load_items_from_folder(full_path)
		elif file_name.ends_with(".json"):
			# Load JSON file as item data
			_load_item_from_file(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

## Load a single item from a JSON file
func _load_item_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("ItemManager: Item file not found: %s" % path)
		return
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("ItemManager: Could not open file: %s" % path)
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("ItemManager: JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return
	
	var data = json.data
	
	# Handle single item file (new format)
	if data is Dictionary and "id" in data:
		var item_id = data.get("id", "")
		if item_id != "":
			# Convert new format to expected format (compatibility layer)
			_normalize_item_data(data)
			_item_data[item_id] = data
			# Debug: log book loading
			if item_id.begins_with("recipe_book"):
				print("[ItemManager] Loaded book: %s from %s" % [item_id, path])
		else:
			push_warning("ItemManager: Item without ID in %s" % path)
	# Handle old multi-item format for backwards compatibility
	elif data is Dictionary and "items" in data:
		for item_data in data["items"]:
			var item_id = item_data.get("id", "")
			if item_id != "":
				_normalize_item_data(item_data)
				_item_data[item_id] = item_data
			else:
				push_warning("ItemManager: Item without ID in %s" % path)
	else:
		push_warning("ItemManager: Invalid item file format in %s" % path)

## Normalize item data - converts new format flags to old format for compatibility
func _normalize_item_data(data: Dictionary) -> void:
	# Convert 'category' to 'item_type' if present
	if "category" in data and "item_type" not in data:
		data["item_type"] = data["category"]
	
	# Process flags to maintain backwards compatibility
	var flags = data.get("flags", {})
	
	# If item has consumable flag, set item_type appropriately
	if flags.get("consumable", false) and data.get("item_type", "") != "consumable":
		# Item might be both tool and consumable - keep as-is if tool, else set consumable
		if not flags.get("tool", false):
			data["item_type"] = "consumable"
	
	# If item has tool flag set
	if flags.get("tool", false) and data.get("item_type", "") != "tool":
		if data.get("item_type", "") == "":
			data["item_type"] = "tool"

## Get raw item data by ID
## Supports both legacy items and template-based items (e.g., "iron_sword", "chainmail_chest_armor")
func get_item_data(item_id: String) -> Dictionary:
	# First check legacy items
	if item_id in _item_data:
		return _item_data[item_id]

	# Try parsing as template-based item
	var parsed = ItemFactoryClass.parse_item_id(item_id)
	if parsed.template_id != "":
		return ItemFactoryClass.get_composed_data(parsed.template_id, parsed.variants)

	return {}

## Check if an item ID exists
func has_item(item_id: String) -> bool:
	return item_id in _item_data

## Create a new item instance by ID
## Supports both legacy item IDs and template-based items
func create_item(item_id: String, count: int = 1) -> Item:
	# First, check if it's a legacy item
	if has_item(item_id):
		var data = _item_data[item_id]
		var item = Item.create_from_data(data)

		# Set stack size if stackable
		if item.max_stack > 1 and count > 1:
			item.stack_size = min(count, item.max_stack)

		return item

	# Try parsing as template-based item (e.g., "iron_knife", "steel_dwarven_sword")
	var parsed = ItemFactoryClass.parse_item_id(item_id)
	if parsed.template_id != "":
		return ItemFactoryClass.create_item(parsed.template_id, parsed.variants, count)

	push_error("ItemManager: Unknown item ID: %s" % item_id)
	return null

## Create multiple item stacks if needed
## Returns array of items to handle counts larger than max_stack
func create_item_stacks(item_id: String, total_count: int) -> Array[Item]:
	var items: Array[Item] = []
	
	if not has_item(item_id):
		push_error("ItemManager: Unknown item ID: %s" % item_id)
		return items
	
	var remaining = total_count
	var data = _item_data[item_id]
	var max_stack = data.get("max_stack", 1)
	
	while remaining > 0:
		var stack_count = min(remaining, max_stack)
		var item = create_item(item_id, stack_count)
		if item:
			items.append(item)
		remaining -= stack_count
	
	return items

## Get all item IDs of a specific type
func get_items_by_type(item_type: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in _item_data:
		if _item_data[item_id].get("item_type", "") == item_type:
			result.append(item_id)
	return result

## Get all item IDs
func get_all_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in _item_data:
		result.append(item_id)
	return result

## Get all item IDs by category (folder organization)
func get_items_by_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in _item_data:
		if _item_data[item_id].get("category", "") == category:
			result.append(item_id)
	return result

## Get all item IDs that have a specific flag set
func get_items_with_flag(flag_name: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in _item_data:
		var flags = _item_data[item_id].get("flags", {})
		if flags.get(flag_name, false):
			result.append(item_id)
	return result

## Check if an item has a specific flag
func item_has_flag(item_id: String, flag_name: String) -> bool:
	if not has_item(item_id):
		return false
	var flags = _item_data[item_id].get("flags", {})
	return flags.get(flag_name, false)

## Get all flags for an item
func get_item_flags(item_id: String) -> Dictionary:
	if not has_item(item_id):
		return {}
	return _item_data[item_id].get("flags", {})

## Debug: Print all loaded items
func debug_print_items() -> void:
	print("=== Loaded Items ===")
	for item_id in _item_data:
		var data = _item_data[item_id]
		print("  %s: %s (%s)" % [item_id, data.get("name", "?"), data.get("item_type", "?")])
	print("===================")
