extends Node
## SaveManager - Handles game state serialization and persistence
##
## Manages three save slots, save/load operations, and state serialization.
## Save files are stored as JSON in user:// directory.

# Preload ItemFactory for template-based item deserialization
const ItemFactoryClass = preload("res://items/item_factory.gd")

const SAVE_DIR = "user://saves/"
const SAVE_FILE_PATTERN = "save_slot_%d.json"
const MAX_SLOTS = 3
const SAVE_VERSION = "1.0.0"

# Pending save data for deferred loading
var pending_save_data: Dictionary = {}

# Flag to prevent map change handlers from respawning enemies during load
var is_deserializing: bool = false

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

	# Store save data for deferred loading after game scene is ready
	pending_save_data = json.data

	print("SaveManager: Save data loaded from slot %d, waiting for game scene" % slot)
	return true

## Apply pending save data (called by game scene after initialization)
func apply_pending_save() -> void:
	if pending_save_data.is_empty():
		return

	print("SaveManager: Applying pending save data...")
	_deserialize_game_state(pending_save_data)

	EventBus.emit_signal("game_loaded", 0)
	EventBus.emit_signal("message_logged", "Game loaded successfully.")
	print("SaveManager: Game loaded successfully")

	# Clear pending data
	pending_save_data = {}

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

	# Get world name from world data
	if save_data.has("world"):
		info.world_name = save_data.world.get("world_name", "Unknown World")

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
		"entities": _serialize_entities(),
		"harvest": _serialize_harvest()
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
		"world_name": GameManager.world_name,
		"current_turn": TurnManager.current_turn,
		"time_of_day": TurnManager.get_time_of_day(),
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
			"STR": player.attributes["STR"],
			"DEX": player.attributes["DEX"],
			"CON": player.attributes["CON"],
			"INT": player.attributes["INT"],
			"WIS": player.attributes["WIS"],
			"CHA": player.attributes["CHA"]
		},
		"health": {
			"current": player.current_health,
			"max": player.max_health
		},
		"survival": _serialize_survival(player.survival),
		"inventory": _serialize_inventory(player.inventory),
		"equipment": _serialize_equipment(player.inventory.equipment),
		"gold": player.gold,
		"experience": player.experience,
		"experience_to_next_level": player.experience_to_next_level,
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
		"base_max_stamina": survival.base_max_stamina,
		"fatigue": survival.fatigue
	}

## Serialize inventory
func _serialize_inventory(inventory: Inventory) -> Array:
	if not inventory:
		return []

	var items = []
	for item in inventory.items:
		if item is Item:
			# Use Item's serialize method for proper template/variant handling
			items.append(item.serialize())
		else:
			# Legacy fallback for non-Item objects
			var count_val = item.count if "count" in item else 1
			var durability_val = item.get("durability") if typeof(item) == TYPE_DICTIONARY else null
			items.append({
				"id": item.id,
				"stack_size": count_val,
				"durability": durability_val
			})
	return items

## Serialize equipment
func _serialize_equipment(equipment: Dictionary) -> Dictionary:
	var equipped = {}
	for slot in equipment.keys():
		var item = equipment[slot]
		if item:
			# Use Item's serialize method for proper template/variant handling
			if item is Item:
				equipped[slot] = item.serialize()
			else:
				equipped[slot] = {"id": item.id, "stack_size": 1}
	return equipped

## Serialize maps (save current map tiles to preserve harvested resources)
func _serialize_maps() -> Dictionary:
	var maps_data = {}

	# Save tiles for the current map (where player has been)
	if MapManager.current_map:
		var map = MapManager.current_map

		# For chunk-based maps (overworld), save chunks instead of all tiles
		if map.chunk_based:
			maps_data[map.map_id] = {
				"width": map.width,
				"height": map.height,
				"chunk_based": true,
				"chunks": ChunkManager.save_chunks()
			}
		else:
			# For non-chunked maps (dungeons), save all tiles
			var tiles_data = []

			# Save all tiles
			for y in range(map.height):
				for x in range(map.width):
					var tile = map.get_tile(Vector2i(x, y))
					tiles_data.append({
						"tile_type": tile.tile_type,
						"walkable": tile.walkable,
						"transparent": tile.transparent,
						"ascii_char": tile.ascii_char,
						"harvestable_resource_id": tile.harvestable_resource_id,
						"is_open": tile.is_open,
						"is_locked": tile.is_locked,
						"lock_id": tile.lock_id,
						"lock_level": tile.lock_level
					})

			maps_data[map.map_id] = {
				"width": map.width,
				"height": map.height,
				"chunk_based": false,
				"tiles": tiles_data
			}

	return maps_data

## Serialize harvest system state (renewable resources and harvest progress)
func _serialize_harvest() -> Dictionary:
	return {
		"renewable_resources": HarvestSystem.serialize_renewable_resources(),
		"harvest_progress": HarvestSystem.serialize_harvest_progress()
	}

## Serialize entities (NPCs, enemies, persistent state)
func _serialize_entities() -> Dictionary:
	var npcs = []
	var enemies = []

	# Serialize all NPCs and Enemies for state persistence
	for entity in EntityManager.entities:
		if entity is NPC:
			npcs.append(_serialize_npc(entity))
		elif entity is Enemy:
			enemies.append(_serialize_enemy(entity))

	return {
		"npcs": npcs,
		"enemies": enemies,
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

## Serialize a single Enemy
func _serialize_enemy(enemy: Enemy) -> Dictionary:
	return {
		"enemy_id": enemy.entity_id,
		"position": {"x": enemy.position.x, "y": enemy.position.y},
		"current_health": enemy.current_health,
		"max_health": enemy.max_health,
		"is_aggressive": enemy.is_aggressive,
		"is_alerted": enemy.is_alerted,
		"target_position": {"x": enemy.target_position.x, "y": enemy.target_position.y},
		"last_known_player_pos": {"x": enemy.last_known_player_pos.x, "y": enemy.last_known_player_pos.y}
	}

# ===== DESERIALIZATION =====

## Deserialize game state from save data
func _deserialize_game_state(save_data: Dictionary):
	print("SaveManager: Deserializing game state...")

	# Set flag to prevent map_changed handler from respawning enemies
	is_deserializing = true

	# Clear map cache to ensure maps regenerate with correct seed
	MapManager.loaded_maps.clear()

	_deserialize_world(save_data.world)
	_deserialize_player(save_data.player)

	# Reload current map (this triggers map_changed signal, but we skip enemy spawn)
	var map_id = save_data.world.get("current_map_id", "overworld")
	MapManager.current_dungeon_floor = save_data.world.get("current_dungeon_floor", 0)
	MapManager.transition_to_map(map_id)

	# Restore map tiles (to preserve harvested resources)
	_deserialize_maps(save_data.maps, map_id)

	# Now restore entities AFTER the map is ready (so they're added to the correct map)
	_deserialize_entities(save_data.entities)

	# Restore harvest system state
	if save_data.has("harvest"):
		_deserialize_harvest(save_data.harvest)

	# Clear flag
	is_deserializing = false

	print("SaveManager: Deserialization complete")

## Deserialize world state
func _deserialize_world(world_data: Dictionary):
	GameManager.world_seed = world_data.seed
	GameManager.world_name = world_data.get("world_name", "Unknown World")
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
	player.experience = player_data.experience
	player.experience_to_next_level = player_data.experience_to_next_level

	# Restore known recipes (clear and append to maintain Array[String] type)
	player.known_recipes.clear()
	for recipe_id in player_data.known_recipes:
		player.known_recipes.append(recipe_id)

	print("SaveManager: Player deserialized")

## Deserialize survival state
func _deserialize_survival(survival: SurvivalSystem, survival_data: Dictionary):
	if not survival or survival_data.is_empty():
		return

	survival.hunger = survival_data.hunger
	survival.thirst = survival_data.thirst
	survival.temperature = survival_data.temperature
	survival.stamina = survival_data.stamina
	survival.base_max_stamina = survival_data.base_max_stamina
	survival.fatigue = survival_data.fatigue

## Deserialize inventory
func _deserialize_inventory(inventory: Inventory, items_data: Array):
	if not inventory:
		return

	inventory.items.clear()
	for item_data in items_data:
		var item: Item = null

		# Check if this is a templated item (has template_id and variants)
		if item_data.has("template_id") and item_data.has("variants"):
			item = ItemFactoryClass.create_item(
				item_data.template_id,
				item_data.variants,
				item_data.get("stack_size", 1)
			)
		else:
			# Legacy format or non-templated item
			var item_id = item_data.get("id", item_data.get("item_id", ""))
			var count = item_data.get("stack_size", item_data.get("count", 1))
			item = ItemManager.create_item(item_id, count)

		if item:
			# Restore durability if it was saved
			if item_data.has("durability") and item_data.durability != null:
				item.durability = item_data.durability
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
		var item_data = equipment_data[slot]
		var item: Item = null

		# Handle new format (dictionary with possible template_id)
		if item_data is Dictionary:
			if item_data.has("template_id") and item_data.has("variants"):
				item = ItemFactoryClass.create_item(
					item_data.template_id,
					item_data.variants,
					1
				)
			else:
				var item_id = item_data.get("id", "")
				item = ItemManager.create_item(item_id, 1)

			# Restore durability if saved
			if item and item_data.has("durability") and item_data.durability != null:
				item.durability = item_data.durability
		else:
			# Legacy format: just item_id string
			item = ItemManager.create_item(item_data, 1)

		if item:
			inventory.equipment[slot] = item

## Deserialize maps (restore tiles to preserve harvested resources)
func _deserialize_maps(maps_data: Dictionary, current_map_id: String) -> void:
	if not maps_data.has(current_map_id):
		return  # No saved data for this map

	var map_data = maps_data[current_map_id]
	var map = MapManager.current_map

	if not map:
		return

	# For chunk-based maps, load chunks from save
	if map_data.get("chunk_based", false):
		var chunks_data = map_data.get("chunks", [])
		ChunkManager.load_chunks(chunks_data)
		print("SaveManager: Loaded %d chunks for %s" % [chunks_data.size(), current_map_id])
		return

	# For non-chunked maps (dungeons), restore tiles
	var tiles_data = map_data.tiles
	var idx = 0
	for y in range(map.height):
		for x in range(map.width):
			if idx >= tiles_data.size():
				break

			var tile_data = tiles_data[idx]
			var tile = map.get_tile(Vector2i(x, y))

			# Update tile properties from saved data
			tile.tile_type = tile_data.tile_type
			tile.walkable = tile_data.walkable
			tile.transparent = tile_data.transparent
			tile.ascii_char = tile_data.ascii_char
			tile.harvestable_resource_id = tile_data.harvestable_resource_id
			tile.is_open = tile_data.get("is_open", false)  # Default to false for backwards compatibility
			# Lock properties (default to unlocked for backwards compatibility)
			tile.is_locked = tile_data.get("is_locked", false)
			tile.lock_id = tile_data.get("lock_id", "")
			tile.lock_level = tile_data.get("lock_level", 1)

			idx += 1

	print("SaveManager: Map tiles restored for ", current_map_id)

## Deserialize entities (NPCs and Enemies)
func _deserialize_entities(entities_data: Dictionary):
	# Clear current NPCs and Enemies (they'll be respawned from save)
	var entities_to_remove = []
	for entity in EntityManager.entities:
		if entity is NPC or entity is Enemy:
			entities_to_remove.append(entity)

	for entity in entities_to_remove:
		EntityManager.entities.erase(entity)
		if MapManager.current_map:
			MapManager.current_map.entities.erase(entity)

	# Restore NPC states from save
	for npc_data in entities_data.npcs:
		# Convert position dictionary to Vector2i
		var spawn_data = npc_data.duplicate()
		var pos_dict = npc_data.position
		spawn_data.position = Vector2i(pos_dict.x, pos_dict.y)

		var npc = EntityManager.spawn_npc(spawn_data)

		# Restore saved state
		npc.gold = npc_data.gold
		npc.last_restock_turn = npc_data.last_restock_turn

		# Restore trade inventory
		npc.trade_inventory.clear()
		for item_data in npc_data.inventory:
			npc.trade_inventory.append(item_data.duplicate())

	# Restore Enemy states from save
	if entities_data.has("enemies"):
		for enemy_data in entities_data.enemies:
			# Spawn enemy at saved position
			var pos = Vector2i(enemy_data.position.x, enemy_data.position.y)
			var enemy = EntityManager.spawn_enemy(enemy_data.enemy_id, pos)

			if enemy:
				# Restore saved state
				enemy.current_health = enemy_data.current_health
				enemy.max_health = enemy_data.max_health
				enemy.is_aggressive = enemy_data.is_aggressive
				enemy.is_alerted = enemy_data.is_alerted
				enemy.target_position = Vector2i(enemy_data.target_position.x, enemy_data.target_position.y)
				enemy.last_known_player_pos = Vector2i(enemy_data.last_known_player_pos.x, enemy_data.last_known_player_pos.y)

	print("SaveManager: Entities deserialized")

## Deserialize harvest system state
func _deserialize_harvest(harvest_data: Dictionary):
	# Restore renewable resources
	if harvest_data.has("renewable_resources"):
		HarvestSystem.deserialize_renewable_resources(harvest_data.renewable_resources)

	# Restore harvest progress
	if harvest_data.has("harvest_progress"):
		HarvestSystem.deserialize_harvest_progress(harvest_data.harvest_progress)

	print("SaveManager: Harvest state deserialized")

# ===== HELPER CLASSES =====

## Information about a save slot
class SaveSlotInfo:
	var slot_number: int = 0
	var exists: bool = false
	var save_name: String = "Empty Slot"
	var world_name: String = ""
	var timestamp: String = ""
	var playtime_turns: int = 0
