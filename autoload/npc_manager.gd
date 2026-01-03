extends Node
## NPCManager autoload singleton - do not use class_name to avoid conflict

## NPCManager - Manages NPC definitions and spawning
##
## Loads NPC definitions from JSON and handles spawning NPCs
## based on town placement data.

const DATA_PATH = "res://data/npcs"
const NPCClass = preload("res://entities/npc.gd")

var npc_definitions: Dictionary = {}  # id -> npc definition
var active_npcs: Array = []  # Currently spawned NPCs

func _ready() -> void:
	_load_npc_definitions()
	print("[NPCManager] Loaded %d NPC definitions" % npc_definitions.size())

## Load all NPC definitions from JSON files
func _load_npc_definitions() -> void:
	var dir = DirAccess.open(DATA_PATH)
	if not dir:
		push_warning("[NPCManager] Could not open directory: %s" % DATA_PATH)
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

## Load a single NPC definition file
func _load_definition_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[NPCManager] Could not open file: %s" % file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_warning("[NPCManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	var id = data.get("id", "")
	if id.is_empty():
		push_warning("[NPCManager] NPC definition missing 'id' in %s" % file_path)
		return

	npc_definitions[id] = data
	#print("[NPCManager] Loaded NPC definition: %s" % id)

## Get an NPC definition by ID
func get_npc_definition(npc_id: String) -> Dictionary:
	return npc_definitions.get(npc_id, {})

## Get all NPC IDs
func get_all_npc_types() -> Array:
	return npc_definitions.keys()

## Create an NPC instance from a definition
func create_npc(npc_id: String, position: Vector2i) -> Variant:
	var definition = get_npc_definition(npc_id)
	if definition.is_empty():
		push_warning("[NPCManager] Unknown NPC type: %s" % npc_id)
		return null

	var npc = NPCClass.new(
		npc_id,
		position,
		definition.get("ascii_char", "@"),
		Color.html(definition.get("ascii_color", "#FFAA00")),
		true  # blocks movement
	)

	# Set properties from definition
	npc.name = definition.get("name", npc_id)
	npc.npc_type = definition.get("npc_type", "generic")
	npc.faction = definition.get("faction", "neutral")
	npc.gold = definition.get("gold", 0)
	npc.restock_interval = definition.get("restock_interval", 500)
	npc.dialogue = definition.get("dialogue", {}).duplicate()

	# Load trade inventory from definition
	var trade_inv = definition.get("trade_inventory", [])
	npc.trade_inventory = []
	for item_data in trade_inv:
		npc.trade_inventory.append(item_data.duplicate())

	active_npcs.append(npc)
	print("[NPCManager] Created NPC: %s (%s) at %v" % [npc.name, npc_id, position])
	return npc

## Clear all active NPCs
func clear_active_npcs() -> void:
	active_npcs.clear()

## Get all active NPCs
func get_active_npcs() -> Array:
	return active_npcs

## Remove an NPC from active list
func remove_npc(npc: Variant) -> void:
	var idx = active_npcs.find(npc)
	if idx >= 0:
		active_npcs.remove_at(idx)

## Serialize active NPCs for saving
func save_npcs() -> Array:
	var save_data: Array = []
	for npc in active_npcs:
		if npc.has_method("to_dict"):
			save_data.append(npc.to_dict())
	return save_data

## Load NPCs from save data
func load_npcs(save_data: Array) -> void:
	clear_active_npcs()
	for npc_data in save_data:
		var npc = NPCClass.new()
		if npc.has_method("from_dict"):
			npc.from_dict(npc_data)
			active_npcs.append(npc)
	print("[NPCManager] Loaded %d NPCs from save" % active_npcs.size())
