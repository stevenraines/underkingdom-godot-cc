extends Node
## SaveManager - Handles game state persistence and orchestrates serialization
##
## Manages three save slots, save/load operations, and coordinates domain-specific
## serializers. Save files are stored as JSON in user:// directory.
##
## Domain serialization is delegated to:
## - PlayerSerializer: player stats, race, class, survival, effects
## - InventorySerializer: inventory items, equipment
## - EntitySerializer: NPCs, enemies
## - MapSerializer: map tiles, chunks, harvest, farming

const PlayerSerializerClass = preload("res://autoload/serializers/player_serializer.gd")
const EntitySerializerClass = preload("res://autoload/serializers/entity_serializer.gd")
const MapSerializerClass = preload("res://autoload/serializers/map_serializer.gd")
const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")

const SAVE_DIR = "user://saves/"
const SAVE_FILE_PATTERN = "save_slot_%d.json"
const AUTOSAVE_FILE = "save_autosave.json"
const MAX_SLOTS = 3
const AUTOSAVE_INTERVAL = 25
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

	# Sync auto-save with this manual save
	_copy_save_to_autosave(slot)

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

	# Sync auto-save with loaded game
	_copy_save_to_autosave(slot)

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

## Save game to auto-save slot (checkpoint)
func save_autosave() -> bool:
	var save_data = _serialize_game_state()
	save_data.metadata.is_autosave = true
	save_data.metadata.slot_number = -1
	save_data.metadata.timestamp = Time.get_datetime_string_from_system()

	var file_path = SAVE_DIR + AUTOSAVE_FILE
	var file = FileAccess.open(file_path, FileAccess.WRITE)

	if not file:
		var error_msg = "Could not open auto-save file for writing: %s" % file_path
		push_error("SaveManager: " + error_msg)
		return false

	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

	EventBus.emit_signal("game_autosaved")
	print("SaveManager: Game auto-saved (checkpoint)")
	return true

## Load game from auto-save slot
func load_autosave() -> bool:
	var file_path = SAVE_DIR + AUTOSAVE_FILE

	if not FileAccess.file_exists(file_path):
		EventBus.emit_signal("load_failed", "Auto-save file does not exist")
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		var error_msg = "Could not open auto-save file for reading: %s" % file_path
		EventBus.emit_signal("load_failed", error_msg)
		push_error("SaveManager: " + error_msg)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		EventBus.emit_signal("load_failed", "Failed to parse auto-save file")
		push_error("SaveManager: Failed to parse auto-save JSON")
		return false

	# Store save data for deferred loading after game scene is ready
	pending_save_data = json.data

	print("SaveManager: Auto-save data loaded, waiting for game scene")
	return true

## Check if auto-save exists
func has_autosave() -> bool:
	var file_path = SAVE_DIR + AUTOSAVE_FILE
	return FileAccess.file_exists(file_path)

## Get auto-save metadata information
func get_autosave_info() -> Dictionary:
	var file_path = SAVE_DIR + AUTOSAVE_FILE

	if not FileAccess.file_exists(file_path):
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}

	var save_data = json.data
	if not save_data.has("metadata"):
		return {}

	var metadata = save_data.metadata
	var info = {
		"timestamp": metadata.get("timestamp", ""),
		"playtime_turns": metadata.get("playtime_turns", 0),
		"character_name": ""
	}

	# Get character name from world data
	if save_data.has("world"):
		info.character_name = save_data.world.get("character_name", "")
		info.world_name = save_data.world.get("world_name", "")

	return info

## Clear auto-save file
func clear_autosave() -> void:
	var file_path = SAVE_DIR + AUTOSAVE_FILE
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("SaveManager: Auto-save cleared")

## Copy a manual save to the auto-save slot
func _copy_save_to_autosave(slot: int) -> void:
	var source_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)
	var dest_path = SAVE_DIR + AUTOSAVE_FILE

	if not FileAccess.file_exists(source_path):
		return

	# Read the save file
	var file = FileAccess.open(source_path, FileAccess.READ)
	if not file:
		return

	var json_string = file.get_as_text()
	file.close()

	# Parse it to modify metadata
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return

	var save_data = json.data
	save_data.metadata.is_autosave = true
	save_data.metadata.slot_number = -1

	# Write to auto-save file
	var autosave_file = FileAccess.open(dest_path, FileAccess.WRITE)
	if not autosave_file:
		return

	autosave_file.store_string(JSON.stringify(save_data, "\t"))
	autosave_file.close()

	print("SaveManager: Auto-save synced with slot %d" % slot)

# ===== SERIALIZATION =====

## Serialize entire game state to dictionary
func _serialize_game_state() -> Dictionary:
	return {
		"metadata": _serialize_metadata(),
		"world": _serialize_world(),
		"player": PlayerSerializerClass.serialize(EntityManager.player),
		"maps": MapSerializerClass.serialize_maps(),
		"entities": EntitySerializerClass.serialize_all(EntityManager.entities),
		"harvest": MapSerializerClass.serialize_harvest(),
		"farming": MapSerializerClass.serialize_farming(),
		"structures": StructureManager.serialize(),
		"fog_of_war": FogOfWarSystemClass.serialize(),
		"identification": IdentificationManager.serialize()
	}

## Serialize save metadata
func _serialize_metadata() -> Dictionary:
	return {
		"save_name": "Adventure Save",  # Could make this user-editable
		"timestamp": "",  # Set during save
		"slot_number": 0,  # Set during save
		"is_autosave": false,  # Set to true for auto-saves
		"playtime_turns": TurnManager.current_turn,
		"version": SAVE_VERSION
	}

## Serialize world state
func _serialize_world() -> Dictionary:
	return {
		"seed": GameManager.world_seed,
		"world_name": GameManager.world_name,
		"character_name": GameManager.character_name,
		"current_turn": TurnManager.current_turn,
		"time_of_day": TurnManager.get_time_of_day(),
		"current_map_id": MapManager.current_map.map_id if MapManager.current_map else "overworld",
		"current_dungeon_type": MapManager.current_dungeon_type,
		"current_dungeon_floor": MapManager.current_dungeon_floor,
		"last_overworld_position": {"x": GameManager.last_overworld_position.x, "y": GameManager.last_overworld_position.y},
		"visited_locations": GameManager.visited_locations.duplicate(true),
		"calendar": CalendarManager.serialize(),
		"weather": WeatherManager.serialize()
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
	PlayerSerializerClass.deserialize(EntityManager.player, save_data.player)

	# Reload current map (this triggers map_changed signal, but we skip enemy spawn)
	var map_id = save_data.world.get("current_map_id", "overworld")
	MapManager.current_dungeon_type = save_data.world.get("current_dungeon_type", "")
	MapManager.current_dungeon_floor = save_data.world.get("current_dungeon_floor", 0)

	# Fallback: parse dungeon type from map_id for old saves
	if MapManager.current_dungeon_type == "" and "_floor_" in map_id:
		var floor_idx = map_id.find("_floor_")
		MapManager.current_dungeon_type = map_id.substr(0, floor_idx)

	MapManager.transition_to_map(map_id)

	# Restore map tiles (to preserve harvested resources)
	MapSerializerClass.deserialize_maps(save_data.maps, map_id)

	# Now restore entities AFTER the map is ready (so they're added to the correct map)
	EntitySerializerClass.deserialize_all(save_data.entities)

	# Restore harvest system state
	if save_data.has("harvest"):
		MapSerializerClass.deserialize_harvest(save_data.harvest)

	# Restore farming system state
	if save_data.has("farming"):
		MapSerializerClass.deserialize_farming(save_data.farming)

	# Restore structure placements (shelters, etc.)
	if save_data.has("structures"):
		StructureManager.deserialize(save_data.structures)

	# Restore fog of war (explored tiles)
	if save_data.has("fog_of_war"):
		FogOfWarSystemClass.deserialize(save_data.fog_of_war)

	# Restore identification state (wand/scroll/potion appearances and identified items)
	if save_data.has("identification"):
		IdentificationManager.deserialize(save_data.identification)

	# Clear flag
	is_deserializing = false

	print("SaveManager: Deserialization complete")

## Deserialize world state
func _deserialize_world(world_data: Dictionary):
	GameManager.world_seed = world_data.seed
	GameManager.world_name = world_data.get("world_name", "Unknown World")
	# For old saves without character_name, use world_name as fallback
	GameManager.character_name = world_data.get("character_name", GameManager.world_name)
	TurnManager.current_turn = world_data.current_turn

	# Restore time of day (affects lighting)
	if world_data.has("time_of_day"):
		TurnManager.time_of_day = world_data.time_of_day
	else:
		# Backwards compatibility: calculate from turn number
		TurnManager._update_time_of_day()

	# Restore last overworld position (for dungeon return)
	if world_data.has("last_overworld_position"):
		var pos_data = world_data.last_overworld_position
		GameManager.last_overworld_position = Vector2i(pos_data.x, pos_data.y)
	else:
		GameManager.last_overworld_position = Vector2i.ZERO

	# Restore visited locations for fast travel
	if world_data.has("visited_locations"):
		GameManager.visited_locations = world_data.visited_locations.duplicate(true)
	else:
		GameManager.visited_locations.clear()

	# Restore calendar state
	if world_data.has("calendar"):
		CalendarManager.deserialize(world_data.calendar)
	else:
		# Initialize calendar fresh if no saved state (backwards compatibility)
		CalendarManager.initialize_with_seed(GameManager.world_seed)

	# Restore weather state
	if world_data.has("weather"):
		WeatherManager.deserialize(world_data.weather)
	else:
		# Initialize weather fresh if no saved state (backwards compatibility)
		WeatherManager.initialize_with_seed(GameManager.world_seed)


# ===== HELPER CLASSES =====

## Information about a save slot
class SaveSlotInfo:
	var slot_number: int = 0
	var exists: bool = false
	var save_name: String = "Empty Slot"
	var world_name: String = ""
	var timestamp: String = ""
	var playtime_turns: int = 0
