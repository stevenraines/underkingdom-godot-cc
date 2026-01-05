extends Node
class_name FarmingSystem

## FarmingSystem - Handles crop planting, growth, and harvesting
##
## Manages:
## - Tilling soil (converting grass/dirt to tilled_soil)
## - Planting seeds
## - Crop growth over time
## - Harvesting mature crops
## - Tilled soil decay

const CropEntityClass = preload("res://entities/crop_entity.gd")

# Crop definitions loaded from JSON
static var _crop_definitions: Dictionary = {}

# Active crops on all maps - key is "map_id:x,y"
static var _active_crops: Dictionary = {}

# Tilled soil decay tracking - stores turn when soil was tilled
static var _tilled_soil: Dictionary = {}  # key is "map_id:x,y", value is {original_tile, tilled_turn}

# Configuration values (loaded from JSON)
static var _config: Dictionary = {}

# Paths
const CROP_DATA_PATH: String = "res://data/crops"
const CONFIG_PATH: String = "res://data/configuration/farming.json"

# Default values (used if config file not found)
const DEFAULT_TILLED_SOIL_DECAY_TURNS: int = 1000
const DEFAULT_TILL_STAMINA_COST: int = 8
const DEFAULT_PLANT_STAMINA_COST: int = 3

# Tillable tile types
const TILLABLE_TILES: Array[String] = ["grass", "dirt", "floor"]

## Get tilled soil decay turns from config
static func get_tilled_soil_decay_turns() -> int:
	return _config.get("tilled_soil_decay_turns", DEFAULT_TILLED_SOIL_DECAY_TURNS)

## Get till stamina cost from config
static func get_till_stamina_cost() -> int:
	return _config.get("till_stamina_cost", DEFAULT_TILL_STAMINA_COST)

## Get plant stamina cost from config
static func get_plant_stamina_cost() -> int:
	return _config.get("plant_stamina_cost", DEFAULT_PLANT_STAMINA_COST)

## Load configuration from JSON
static func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("[FarmingSystem] Config file not found, using defaults: %s" % CONFIG_PATH)
		return

	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		push_error("[FarmingSystem] Could not open config file: %s" % CONFIG_PATH)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("[FarmingSystem] JSON parse error in config: %s" % json.get_error_message())
		return

	_config = json.data

## Load crop definitions from JSON files
static func load_crops() -> void:
	_load_config()
	_crop_definitions.clear()
	_load_crops_from_folder(CROP_DATA_PATH)
	print("[FarmingSystem] Loaded %d crop definitions" % _crop_definitions.size())

## Recursively load crops from a folder
static func _load_crops_from_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("[FarmingSystem] Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name

		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_load_crops_from_folder(full_path)
		elif file_name.ends_with(".json"):
			_load_crop_from_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

## Load a single crop from a JSON file
static func _load_crop_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("[FarmingSystem] Crop file not found: %s" % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[FarmingSystem] Could not open file: %s" % path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("[FarmingSystem] JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return

	var data = json.data
	if data is Dictionary and "id" in data:
		var crop_id = data.get("id", "")
		if crop_id != "":
			_crop_definitions[crop_id] = data
		else:
			push_warning("[FarmingSystem] Crop without ID in %s" % path)
	else:
		push_warning("[FarmingSystem] Invalid crop format in %s" % path)

## Get crop definition by ID
static func get_crop_definition(crop_id: String) -> Dictionary:
	return _crop_definitions.get(crop_id, {})

## Get crop ID from seed item
static func get_crop_from_seed(seed_item: Item) -> String:
	# Check if the item data has a crop_id field
	var item_data = ItemManager.get_item_data(seed_item.id)
	return item_data.get("crop_id", "")

## Generate a unique key for position tracking
static func _get_position_key(map_id: String, pos: Vector2i) -> String:
	return "%s:%d,%d" % [map_id, pos.x, pos.y]

## Check if a tile can be tilled
static func can_till_tile(tile: GameTile) -> bool:
	return tile.tile_type in TILLABLE_TILES

## Check if player has a hoe equipped
static func has_hoe_equipped(player: Player) -> Dictionary:
	var equipped_items: Array[Item] = []
	if player.inventory.equipment.main_hand:
		equipped_items.append(player.inventory.equipment.main_hand)
	if player.inventory.equipment.off_hand:
		equipped_items.append(player.inventory.equipment.off_hand)

	for item in equipped_items:
		if item.tool_type == "hoe":
			return {"has_tool": true, "tool_name": item.name, "tool_item": item}

	return {"has_tool": false, "tool_name": "", "tool_item": null}

## Attempt to till soil at a position
static func till_soil(player: Player, target_pos: Vector2i) -> Dictionary:
	# Check for hoe
	var tool_check = has_hoe_equipped(player)
	if not tool_check.has_tool:
		return {"success": false, "message": "Need a hoe to till soil"}

	# Get tile at position
	var map = MapManager.current_map
	if not map:
		return {"success": false, "message": "No map loaded"}

	var tile = map.get_tile(target_pos)
	if not tile:
		return {"success": false, "message": "Invalid position"}

	# Check if tile can be tilled
	if not can_till_tile(tile):
		return {"success": false, "message": "Cannot till this ground"}

	# Check if already tilled
	if tile.tile_type == "tilled_soil":
		return {"success": false, "message": "Soil is already tilled"}

	# Check stamina
	if player.survival and not player.survival.consume_stamina(get_till_stamina_cost()):
		return {"success": false, "message": "Too tired to till"}

	# Store original tile type and color for decay
	var map_id = map.map_id
	var key = _get_position_key(map_id, target_pos)
	_tilled_soil[key] = {
		"original_tile": tile.tile_type,
		"original_color": tile.color.to_html(),  # Store color as hex string for serialization
		"tilled_turn": TurnManager.current_turn
	}

	# Transform tile to tilled soil
	var new_tile = GameTile.create("tilled_soil")
	new_tile.tilled_turn = TurnManager.current_turn
	map.set_tile(target_pos, new_tile)

	return {"success": true, "message": "You till the soil"}

## Get seeds from player inventory
static func get_plantable_seeds(player: Player) -> Array[Item]:
	var seeds: Array[Item] = []
	for item in player.inventory.items:
		var item_data = ItemManager.get_item_data(item.id)
		if item_data.get("type", "") == "seed":
			seeds.append(item)
	return seeds

## Check if a position has a crop
static func has_crop_at(map_id: String, pos: Vector2i) -> bool:
	var key = _get_position_key(map_id, pos)
	return key in _active_crops

## Get crop at position
static func get_crop_at(map_id: String, pos: Vector2i):
	var key = _get_position_key(map_id, pos)
	return _active_crops.get(key, null)

## Attempt to plant a seed at a position
static func plant_seed(player: Player, target_pos: Vector2i, seed_item: Item) -> Dictionary:
	# Get map
	var map = MapManager.current_map
	if not map:
		return {"success": false, "message": "No map loaded"}

	var map_id = map.map_id

	# Get tile at position
	var tile = map.get_tile(target_pos)
	if not tile:
		return {"success": false, "message": "Invalid position"}

	# Check if tile is tilled soil
	if tile.tile_type != "tilled_soil":
		return {"success": false, "message": "Must plant on tilled soil"}

	# Check if there's already a crop here
	if has_crop_at(map_id, target_pos):
		return {"success": false, "message": "There's already a crop here"}

	# Get crop ID from seed
	var crop_id = get_crop_from_seed(seed_item)
	if crop_id.is_empty():
		return {"success": false, "message": "This seed cannot be planted"}

	# Get crop definition
	var crop_data = get_crop_definition(crop_id)
	if crop_data.is_empty():
		return {"success": false, "message": "Unknown crop type"}

	# Check stamina
	if player.survival and not player.survival.consume_stamina(get_plant_stamina_cost()):
		return {"success": false, "message": "Too tired to plant"}

	# Consume seed from inventory
	player.inventory.remove_item_by_id(seed_item.id, 1)

	# Create crop entity
	var crop = CropEntityClass.create(crop_id, target_pos, crop_data)

	# Add to active crops
	var key = _get_position_key(map_id, target_pos)
	_active_crops[key] = crop

	# Add to EntityManager for rendering and map entities for persistence
	EntityManager.entities.append(crop)
	map.entities.append(crop)

	# Remove tilled soil decay tracking (now has a crop)
	if key in _tilled_soil:
		_tilled_soil.erase(key)

	var crop_name = crop_data.get("name", "crop")
	return {"success": true, "message": "You plant %s seeds" % crop_name}

## Process crop growth for all crops on current map (called each turn)
static func process_crop_growth() -> void:
	var map = MapManager.current_map
	if not map:
		return

	var map_id = map.map_id

	# Process crops on current map
	for key in _active_crops:
		if key.begins_with(map_id + ":"):
			var crop = _active_crops[key]
			var stage_changed = crop.advance_growth()
			if stage_changed:
				# Emit signal to update rendering when crop visual changes
				EventBus.entity_visual_changed.emit(crop.position)
				if crop.is_harvestable():
					# Emit message when crop becomes harvestable
					EventBus.message_logged.emit("Your %s has matured!" % crop.crop_data.get("name", "crop"))

## Process tilled soil decay (called each turn)
static func process_tilled_soil_decay() -> void:
	var map = MapManager.current_map
	if not map:
		return

	var map_id = map.map_id
	var current_turn = TurnManager.current_turn
	var to_remove: Array[String] = []

	for key in _tilled_soil:
		if not key.begins_with(map_id + ":"):
			continue

		var soil_data = _tilled_soil[key]
		var tilled_turn = soil_data.get("tilled_turn", 0)

		if current_turn - tilled_turn >= get_tilled_soil_decay_turns():
			# Parse position from key
			var parts = key.split(":")
			if parts.size() < 2:
				continue
			var pos_parts = parts[1].split(",")
			if pos_parts.size() < 2:
				continue
			var pos = Vector2i(int(pos_parts[0]), int(pos_parts[1]))

			# Revert to original tile with original color
			var original_tile = soil_data.get("original_tile", "grass")
			var new_tile = GameTile.create(original_tile)

			# Restore original color if stored
			var original_color_hex = soil_data.get("original_color", "")
			if original_color_hex != "":
				new_tile.color = Color.from_string(original_color_hex, Color.WHITE)

			map.set_tile(pos, new_tile)

			# Emit tile_changed signal to update rendering
			EventBus.tile_changed.emit(pos)

			to_remove.append(key)

	# Remove decayed entries
	for key in to_remove:
		_tilled_soil.erase(key)

## Harvest a crop at a position
static func harvest_crop(player: Player, target_pos: Vector2i) -> Dictionary:
	var map = MapManager.current_map
	if not map:
		return {"success": false, "message": "No map loaded"}

	var map_id = map.map_id
	var key = _get_position_key(map_id, target_pos)

	# Get crop at position
	var crop = _active_crops.get(key, null)
	if not crop:
		return {"success": false, "message": "No crop here to harvest"}

	# Check if harvestable
	if not crop.is_harvestable():
		return {"success": false, "message": "This crop isn't ready to harvest yet"}

	# Check stamina
	var stamina_cost = crop.get_harvest_stamina_cost()
	if player.survival and not player.survival.consume_stamina(stamina_cost):
		return {"success": false, "message": "Too tired to harvest"}

	# Generate yields and add directly to player inventory
	var yields = crop.get_harvest_yields()
	var yield_messages: Array[String] = []

	for yield_entry in yields:
		var item_id = yield_entry.get("item_id", "")
		var count = yield_entry.get("count", 1)

		var item = ItemManager.create_item(item_id, count)
		if item:
			# Try to add to player inventory
			if player.inventory and player.inventory.add_item(item):
				yield_messages.append("%d %s" % [count, item.name])
			else:
				# Inventory full - drop at harvest position as fallback
				var ground_item = GroundItem.new()
				ground_item.item = item
				ground_item.position = target_pos
				ground_item.ascii_char = item.ascii_char
				ground_item.color = item.get_color()
				EntityManager.entities.append(ground_item)
				map.entities.append(ground_item)
				yield_messages.append("%d %s (dropped)" % [count, item.name])

	# Remove crop from tracking
	_active_crops.erase(key)

	# Remove crop entity from EntityManager and map
	var em_idx = EntityManager.entities.find(crop)
	if em_idx >= 0:
		EntityManager.entities.remove_at(em_idx)
	var idx = map.entities.find(crop)
	if idx >= 0:
		map.entities.remove_at(idx)

	# Tilled soil remains - add back to decay tracking
	_tilled_soil[key] = {
		"original_tile": "grass",  # Default to grass after harvest
		"original_color": "",  # No preserved color for post-harvest
		"tilled_turn": TurnManager.current_turn
	}

	# Emit signal to re-render the position (crop removed, tilled soil visible again)
	EventBus.entity_visual_changed.emit(target_pos)

	var message = crop.get_harvest_message()
	if not yield_messages.is_empty():
		message += " (%s)" % ", ".join(yield_messages)

	return {"success": true, "message": message}

## Check if entity is trampling a crop
static func check_trample(entity: Entity, pos: Vector2i) -> void:
	var map = MapManager.current_map
	if not map:
		return

	var map_id = map.map_id
	var key = _get_position_key(map_id, pos)

	var crop = _active_crops.get(key, null)
	if not crop:
		return

	if crop.is_trample_vulnerable():
		# Destroy the crop
		_active_crops.erase(key)

		# Remove from EntityManager
		var em_idx = EntityManager.entities.find(crop)
		if em_idx >= 0:
			EntityManager.entities.remove_at(em_idx)

		# Remove from map entities
		var idx = map.entities.find(crop)
		if idx >= 0:
			map.entities.remove_at(idx)

		# Notify player if they trampled it
		if entity.entity_type == "player":
			EventBus.message_logged.emit("You trampled the seedling!")

## Get all crops on a map
static func get_crops_on_map(map_id: String) -> Array:
	var crops: Array = []
	for key in _active_crops:
		if key.begins_with(map_id + ":"):
			crops.append(_active_crops[key])
	return crops

## Serialize farming data for saving
static func serialize() -> Dictionary:
	var crops_data: Array[Dictionary] = []
	for key in _active_crops:
		var crop = _active_crops[key]
		var parts = key.split(":")
		var map_id = parts[0] if parts.size() > 0 else ""
		var data = crop.serialize()
		data["map_id"] = map_id
		crops_data.append(data)

	var tilled_data: Array[Dictionary] = []
	for key in _tilled_soil:
		var parts = key.split(":")
		if parts.size() < 2:
			continue
		var map_id = parts[0]
		var pos_parts = parts[1].split(",")
		if pos_parts.size() < 2:
			continue

		var soil_info = _tilled_soil[key]
		tilled_data.append({
			"map_id": map_id,
			"position": {"x": int(pos_parts[0]), "y": int(pos_parts[1])},
			"original_tile": soil_info.get("original_tile", "grass"),
			"original_color": soil_info.get("original_color", ""),
			"tilled_turn": soil_info.get("tilled_turn", 0)
		})

	return {
		"crops": crops_data,
		"tilled_soil": tilled_data
	}

## Deserialize farming data from save
static func deserialize(data: Dictionary) -> void:
	_active_crops.clear()
	_tilled_soil.clear()

	# Load crops
	var crops_data = data.get("crops", [])
	for crop_data in crops_data:
		var map_id = crop_data.get("map_id", "")
		var crop_id = crop_data.get("crop_id", "")
		var crop_def = get_crop_definition(crop_id)

		if crop_def.is_empty():
			continue

		var crop = CropEntityClass.deserialize(crop_data, crop_def)
		var key = _get_position_key(map_id, crop.position)
		_active_crops[key] = crop

		# Add to EntityManager for rendering
		EntityManager.entities.append(crop)

		# Add to current map if it's the right one
		if MapManager.current_map and MapManager.current_map.map_id == map_id:
			MapManager.current_map.entities.append(crop)

	# Load tilled soil
	var tilled_data = data.get("tilled_soil", [])
	for soil_data in tilled_data:
		var map_id = soil_data.get("map_id", "")
		var pos = Vector2i(
			soil_data.get("position", {}).get("x", 0),
			soil_data.get("position", {}).get("y", 0)
		)
		var key = _get_position_key(map_id, pos)
		_tilled_soil[key] = {
			"original_tile": soil_data.get("original_tile", "grass"),
			"original_color": soil_data.get("original_color", ""),
			"tilled_turn": soil_data.get("tilled_turn", 0)
		}

## Clear all farming data (for new game)
static func clear() -> void:
	_active_crops.clear()
	_tilled_soil.clear()

## Get tilled soil info for a position (for look mode)
## Returns Dictionary with info about the tilled soil, or empty dict if not tilled
static func get_tilled_soil_info(map_id: String, pos: Vector2i) -> Dictionary:
	var key = _get_position_key(map_id, pos)
	if key not in _tilled_soil:
		return {}

	var soil_data = _tilled_soil[key]
	var tilled_turn = soil_data.get("tilled_turn", 0)
	var turns_since_tilled = TurnManager.current_turn - tilled_turn
	var turns_until_decay = get_tilled_soil_decay_turns() - turns_since_tilled

	return {
		"tilled_turn": tilled_turn,
		"turns_since_tilled": turns_since_tilled,
		"turns_until_decay": max(0, turns_until_decay),
		"original_tile": soil_data.get("original_tile", "grass")
	}

## Check if a position has tilled soil (no crop)
static func is_tilled_soil(map_id: String, pos: Vector2i) -> bool:
	var key = _get_position_key(map_id, pos)
	return key in _tilled_soil

## Add crops to a map when it's loaded (called by MapManager)
static func add_crops_to_map(map) -> void:
	var map_id = map.map_id
	for key in _active_crops:
		if key.begins_with(map_id + ":"):
			var crop = _active_crops[key]
			# Add to EntityManager if not already there
			if not crop in EntityManager.entities:
				EntityManager.entities.append(crop)
			if not crop in map.entities:
				map.entities.append(crop)
