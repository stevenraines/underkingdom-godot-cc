extends Node
## SaveManager - Handles game state serialization and persistence
##
## Manages three save slots, save/load operations, and state serialization.
## Save files are stored as JSON in user:// directory.

const SAVE_DIR = "user://saves/"
const SAVE_FILE_PATTERN = "save_slot_%d.json"
const MAX_SLOTS = 3
const SAVE_VERSION = "1.0.0"

func _ready():
	_ensure_save_directory()
	print("SaveManager initialized")

## Ensure save directory exists
func _ensure_save_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
		print("SaveManager: Created saves directory")

## Save game to specified slot
func save_game(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		EventBus.emit_signal("save_failed", "Invalid slot number: %d" % slot)
		return false

	var save_data = _serialize_game_state()
	save_data.metadata.slot_number = slot
	save_data.metadata.timestamp = Time.get_datetime_string_from_system()

	var file_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if not file:
		var error_msg = "Could not open file for writing: %s" % file_path
		EventBus.emit_signal("save_failed", error_msg)
		push_error("SaveManager: " + error_msg)
		return false

	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

	EventBus.emit_signal("game_saved", slot)
	EventBus.emit_signal("message_logged", "Game saved to slot %d." % slot)
	print("SaveManager: Game saved to slot %d" % slot)
	return true

## Load game from specified slot
func load_game(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		EventBus.emit_signal("load_failed", "Invalid slot number: %d" % slot)
		return false

	var file_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)

	if not FileAccess.file_exists(file_path):
		EventBus.emit_signal("load_failed", "Save file does not exist")
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		var error_msg = "Could not open file for reading: %s" % file_path
		EventBus.emit_signal("load_failed", error_msg)
		push_error("SaveManager: " + error_msg)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		EventBus.emit_signal("load_failed", "Failed to parse save file")
		push_error("SaveManager: Failed to parse JSON in slot %d" % slot)
		return false

	var save_data = json.data
	_deserialize_game_state(save_data)

	EventBus.emit_signal("game_loaded", slot)
	EventBus.emit_signal("message_logged", "Game loaded from slot %d." % slot)
	print("SaveManager: Game loaded from slot %d" % slot)
	return true

## Get information about a save slot
func get_save_slot_info(slot: int) -> SaveSlotInfo:
	var info = SaveSlotInfo.new()
	info.slot_number = slot

	var file_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)
	info.exists = FileAccess.file_exists(file_path)

	if not info.exists:
		return info

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return info

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return info

	var save_data = json.data
	if not save_data.has("metadata"):
		return info

	var metadata = save_data.metadata
	info.save_name = metadata.get("save_name", "Unnamed Save")
	info.timestamp = metadata.get("timestamp", "")
	info.playtime_turns = metadata.get("playtime_turns", 0)

	return info

## Delete a save slot
func delete_save(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		return false

	var file_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("SaveManager: Deleted save slot %d" % slot)
		return true
	return false

# ===== SERIALIZATION =====

## Serialize entire game state to dictionary
func _serialize_game_state() -> Dictionary:
	return {
		"metadata": _serialize_metadata(),
		"world": _serialize_world(),
		"player": _serialize_player(),
		"maps": _serialize_maps(),
		"entities": _serialize_entities()
	}

## Serialize save metadata
func _serialize_metadata() -> Dictionary:
	return {
		"save_name": "Adventure Save",  # Could make this user-editable
		"timestamp": "",  # Set during save
		"slot_number": 0,  # Set during save
		"playtime_turns": TurnManager.current_turn,
		"version": SAVE_VERSION
	}

## Serialize world state
func _serialize_world() -> Dictionary:
	return {
		"seed": GameManager.world_seed,
		"current_turn": TurnManager.current_turn,
		"time_of_day": TurnManager.get_turn_of_day(),
		"current_map_id": MapManager.current_map.map_id if MapManager.current_map else "overworld",
		"current_dungeon_floor": MapManager.current_dungeon_floor
	}

## Serialize player state
func _serialize_player() -> Dictionary:
	var player = EntityManager.player
	if not player:
		push_error("SaveManager: No player to serialize")
		return {}

	return {
		"position": {"x": player.position.x, "y": player.position.y},
		"attributes": {
			"STR": player.attributes.STR,
			"DEX": player.attributes.DEX,
			"CON": player.attributes.CON,
			"INT": player.attributes.INT,
			"WIS": player.attributes.WIS,
			"CHA": player.attributes.CHA
		},
		"health": {
			"current": player.current_health,
			"max": player.max_health
		},
		"survival": _serialize_survival(player.survival),
		"inventory": _serialize_inventory(player.inventory),
		"equipment": _serialize_equipment(player.inventory.equipment),
		"gold": player.gold,
		"xp": player.xp,
		"known_recipes": player.known_recipes.duplicate()
	}

## Serialize survival stats
func _serialize_survival(survival: SurvivalSystem) -> Dictionary:
	if not survival:
		return {}

	return {
		"hunger": survival.hunger,
		"thirst": survival.thirst,
		"temperature": survival.temperature,
		"stamina": survival.stamina,
		"max_stamina": survival.max_stamina,
		"fatigue": survival.fatigue
	}

## Serialize inventory
func _serialize_inventory(inventory: Inventory) -> Array:
	if not inventory:
		return []

	var items = []
	for item in inventory.items:
		# Support both Item instances and legacy/data objects
		var count_val = item.stack_size if item is Item else item.count
		var durability_val = null
		if item is Item:
			if item.durability != null and item.durability > -1:
				durability_val = item.durability
		else:
			# If it's a data/dict-like object, try to read durability if present
			durability_val = item.get("durability") if typeof(item) == TYPE_DICTIONARY else null

		items.append({
			"item_id": item.id,
			"count": count_val,
			"durability": durability_val
		})
	return items

## Serialize equipment
func _serialize_equipment(equipment: Dictionary) -> Dictionary:
	var equipped = {}
	for slot in equipment.keys():
		if equipment[slot]:
			equipped[slot] = equipment[slot].id
	return equipped

## Serialize maps (only explored data, maps regenerate from seed)
func _serialize_maps() -> Dictionary:
	return {
		"explored_tiles": {}  # Future: FOV exploration tracking
	}

## Serialize entities (NPCs, persistent state)
func _serialize_entities() -> Dictionary:
	var npcs = []

	# Serialize all NPCs for state persistence
	for entity in EntityManager.entities:
		if entity.has("npc_type"):  # Is an NPC
			npcs.append(_serialize_npc(entity))

	return {
		"npcs": npcs,
		"dead_enemies": {}  # Future: track dead enemies with loot
	}

## Serialize a single NPC
func _serialize_npc(npc) -> Dictionary:
	return {
		"npc_id": npc.entity_id,
		"npc_type": npc.npc_type,
		"position": {"x": npc.position.x, "y": npc.position.y},
		"name": npc.name,
		"gold": npc.gold,
		"last_restock_turn": npc.last_restock_turn,
		"inventory": _serialize_npc_inventory(npc.trade_inventory)
	}

## Serialize NPC trade inventory
func _serialize_npc_inventory(trade_inventory: Array) -> Array:
	var inventory = []
	for item_data in trade_inventory:
		inventory.append({
			"item_id": item_data.item_id,
			"count": item_data.count,
			"base_price": item_data.base_price
		})
	return inventory

# ===== DESERIALIZATION =====

## Deserialize game state from save data
func _deserialize_game_state(save_data: Dictionary):
	print("SaveManager: Deserializing game state...")

	_deserialize_world(save_data.world)
	_deserialize_player(save_data.player)
	_deserialize_entities(save_data.entities)

	# Reload current map
	var map_id = save_data.world.get("current_map_id", "overworld")
	MapManager.current_dungeon_floor = save_data.world.get("current_dungeon_floor", 0)
	MapManager.transition_to_map(map_id)

	print("SaveManager: Deserialization complete")

## Deserialize world state
func _deserialize_world(world_data: Dictionary):
	GameManager.world_seed = world_data.seed
	TurnManager.current_turn = world_data.current_turn

## Deserialize player state
func _deserialize_player(player_data: Dictionary):
	var player = EntityManager.player
	if not player:
		push_error("SaveManager: No player to deserialize into")
		return

	# Position
	player.position = Vector2i(player_data.position.x, player_data.position.y)

	# Attributes
	for attr in player_data.attributes.keys():
		player.attributes[attr] = player_data.attributes[attr]

	# Recalculate derived stats after attributes are set
	player._calculate_derived_stats()

	# Health
	player.current_health = player_data.health.current
	player.max_health = player_data.health.max

	# Survival
	_deserialize_survival(player.survival, player_data.survival)

	# Inventory
	_deserialize_inventory(player.inventory, player_data.inventory)

	# Equipment
	_deserialize_equipment(player.inventory, player_data.equipment)

	# Misc
	player.gold = player_data.gold
	player.xp = player_data.xp
	player.known_recipes = player_data.known_recipes.duplicate()

	print("SaveManager: Player deserialized")

## Deserialize survival state
func _deserialize_survival(survival: SurvivalSystem, survival_data: Dictionary):
	if not survival or survival_data.is_empty():
		return

	survival.hunger = survival_data.hunger
	survival.thirst = survival_data.thirst
	survival.temperature = survival_data.temperature
	survival.stamina = survival_data.stamina
	survival.max_stamina = survival_data.max_stamina
	survival.fatigue = survival_data.fatigue

## Deserialize inventory
func _deserialize_inventory(inventory: Inventory, items_data: Array):
	if not inventory:
		return

	inventory.items.clear()
	for item_data in items_data:
		var item = ItemManager.create_item(item_data.item_id, item_data.count)
		if item and item_data.durability != null and item.has("durability"):
			item.durability = item_data.durability
		if item:
			inventory.items.append(item)

## Deserialize equipment
func _deserialize_equipment(inventory: Inventory, equipment_data: Dictionary):
	if not inventory:
		return

	# Clear current equipment
	for slot in inventory.equipment.keys():
		inventory.equipment[slot] = null

	# Load equipped items
	for slot in equipment_data.keys():
		var item_id = equipment_data[slot]
		var item = ItemManager.create_item(item_id, 1)
		if item:
			inventory.equipment[slot] = item

## Deserialize entities (primarily NPCs)
func _deserialize_entities(entities_data: Dictionary):
	# Clear current NPCs (they'll be respawned)
	var npcs_to_remove = []
	for entity in EntityManager.entities:
		if entity.has("npc_type"):
			npcs_to_remove.append(entity)

	for npc in npcs_to_remove:
		EntityManager.entities.erase(npc)
		if MapManager.current_map:
			MapManager.current_map.entities.erase(npc)

	# Restore NPC states from save
	for npc_data in entities_data.npcs:
		var npc = EntityManager.spawn_npc(npc_data)

		# Restore saved state
		npc.gold = npc_data.gold
		npc.last_restock_turn = npc_data.last_restock_turn

		# Restore trade inventory
		npc.trade_inventory.clear()
		for item_data in npc_data.inventory:
			npc.trade_inventory.append(item_data.duplicate())

	print("SaveManager: Entities deserialized")

# ===== HELPER CLASSES =====

## Information about a save slot
class SaveSlotInfo:
	var slot_number: int = 0
	var exists: bool = false
	var save_name: String = "Empty Slot"
	var timestamp: String = ""
	var playtime_turns: int = 0
