extends Node

## EntityManager - Manages all entities in the game
##
## Keeps track of all entities (enemies, NPCs, items), handles spawning,
## and coordinates entity updates during turns.

# All active entities (excluding player)
var entities: Array[Entity] = []

# Enemy definitions cache
var enemy_definitions: Dictionary = {}

# Base path for enemy data
const ENEMY_DATA_BASE_PATH: String = "res://data/enemies"

# Player reference (set by game scene)
var player: Player = null

func _ready() -> void:
	print("EntityManager initialized")
	_load_enemy_definitions()

## Load all enemy definitions by recursively scanning folders
func _load_enemy_definitions() -> void:
	_load_enemies_from_folder(ENEMY_DATA_BASE_PATH)
	print("EntityManager: Loaded %d enemy definitions" % enemy_definitions.size())

## Recursively load enemies from a folder and all subfolders
func _load_enemies_from_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("EntityManager: Could not open directory: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = path + "/" + file_name
		
		if dir.current_is_dir():
			# Skip hidden folders and navigate into subfolders
			if not file_name.begins_with("."):
				_load_enemies_from_folder(full_path)
		elif file_name.ends_with(".json"):
			# Load JSON file as enemy data
			_load_enemy_from_file(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

## Load a single enemy from a JSON file
func _load_enemy_from_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if not file:
		push_error("EntityManager: Failed to load enemy file: " + file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("EntityManager: Failed to parse enemy JSON: %s at line %d" % [file_path, json.get_error_line()])
		return
	
	var data = json.data
	
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
		push_warning("EntityManager: Invalid enemy file format in %s" % file_path)

## Check if an enemy ID exists
func has_enemy_definition(enemy_id: String) -> bool:
	return enemy_id in enemy_definitions

## Get enemy definition data by ID
func get_enemy_definition(enemy_id: String) -> Dictionary:
	return enemy_definitions.get(enemy_id, {})

## Get all enemy IDs
func get_all_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_definitions:
		result.append(enemy_id)
	return result

## Get all enemy IDs with a specific behavior type
func get_enemies_by_behavior(behavior: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_definitions:
		if enemy_definitions[enemy_id].get("behavior", "") == behavior:
			result.append(enemy_id)
	return result

## Spawn an enemy at a position
func spawn_enemy(enemy_id: String, pos: Vector2i) -> Enemy:
	if not enemy_id in enemy_definitions:
		push_error("Unknown enemy ID: " + enemy_id)
		return null

	var enemy = Enemy.create(enemy_definitions[enemy_id])
	enemy.position = pos

	entities.append(enemy)

	# Add to current map's entity list
	if MapManager.current_map:
		MapManager.current_map.entities.append(enemy)

	print("Spawned %s at %s" % [enemy.name, pos])
	return enemy

## Remove an entity (when it dies or is removed)
func remove_entity(entity: Entity) -> void:
	entities.erase(entity)

	if MapManager.current_map:
		MapManager.current_map.entities.erase(entity)

## Get all entities at a position
func get_entities_at(pos: Vector2i) -> Array[Entity]:
	var result: Array[Entity] = []

	for entity in entities:
		if entity.position == pos and entity.is_alive:
			result.append(entity)

	return result

## Get ground items at a position
func get_ground_items_at(pos: Vector2i) -> Array[GroundItem]:
	var result: Array[GroundItem] = []

	for entity in entities:
		if entity.position == pos and entity is GroundItem:
			result.append(entity as GroundItem)

	return result

## Spawn a ground item at a position
func spawn_ground_item(item: Item, pos: Vector2i, despawn_turns: int = -1) -> GroundItem:
	var ground_item = GroundItem.create(item, pos, despawn_turns)
	entities.append(ground_item)

	if MapManager.current_map:
		MapManager.current_map.entities.append(ground_item)

	return ground_item

## Spawn an NPC from spawn data
func spawn_npc(spawn_data: Dictionary):
	var NPCClass = load("res://entities/npc.gd")
	var npc = NPCClass.new(
		spawn_data.get("npc_id", "npc"),
		spawn_data.get("position", Vector2i.ZERO),
		"@",
		Color("#FFAA00"),
		true
	)

	npc.entity_type = "npc"
	npc.npc_type = spawn_data.get("npc_type", "generic")
	npc.shop_type = spawn_data.get("shop_type", "general")
	npc.name = spawn_data.get("name", "NPC")
	npc.gold = spawn_data.get("gold", 0)
	npc.restock_interval = spawn_data.get("restock_interval", 500)
	npc.last_restock_turn = 0

	# Set dialogue for shop NPCs
	if npc.npc_type == "shop":
		if npc.shop_type == "blacksmith":
			npc.dialogue = {
				"greeting": "Well met! Looking for quality arms and armor?",
				"buy": "Fine craftsmanship, all of it. Made with my own hands!",
				"sell": "Got some metal to sell? I'll pay fair prices.",
				"farewell": "May your blade stay sharp, traveler!"
			}
		else:
			npc.dialogue = {
				"greeting": "Welcome to my shop, traveler! I have supplies for your journey.",
				"buy": "Take a look at my wares. Fair prices, I assure you!",
				"sell": "Let me see what you have. I'll pay a fair price.",
				"farewell": "Safe travels, friend! Watch out for those barrows..."
			}
		npc.load_shop_inventory()

	entities.append(npc)

	if MapManager.current_map:
		MapManager.current_map.entities.append(npc)

	return npc

## Get entity blocking movement at position (returns first blocking entity)
func get_blocking_entity_at(pos: Vector2i) -> Entity:
	for entity in entities:
		if entity.position == pos and entity.blocks_movement and entity.is_alive:
			return entity

	return null

## Process all entity turns (called after player turn)
func process_entity_turns() -> void:
	for entity in entities:
		if entity.is_alive:
			if entity is Enemy:
				(entity as Enemy).take_turn()
			elif entity.has_method("process_turn"):
				# NPC or other entity with turn processing
				entity.process_turn()

## Clear all entities (for map transitions)
func clear_entities() -> void:
	entities.clear()

## Get entities on current map
func get_current_map_entities() -> Array[Entity]:
	return entities.filter(func(e): return e.is_alive)
