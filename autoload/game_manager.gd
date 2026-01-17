extends Node

## GameManager - High-level game state and coordination
##
## Manages world seed, game state transitions, and coordinates
## between major systems like TurnManager and MapManager.

const _HarvestSystem = preload("res://systems/harvest_system.gd")
const _FarmingSystem = preload("res://systems/farming_system.gd")
const _FogOfWarSystem = preload("res://systems/fog_of_war_system.gd")

# Game state
var world_seed: int = 0
var world_name: String = ""  # Player-provided name for the world (legacy, kept for save compatibility)
var character_name: String = ""  # Character name displayed in UI
var game_state: String = "menu"  # "menu", "playing", "paused"
var current_map_id: String = ""
var is_loading_save: bool = false  # Flag to prevent start_new_game when loading
var last_overworld_position: Vector2i = Vector2i.ZERO  # Player's position when entering dungeon

# Fast travel - visited locations tracking
# Format: location_id -> {type, name, position, visited_turn}
var visited_locations: Dictionary = {}

# Player settings
var auto_open_doors: bool = true  # Automatically open doors when walking into them

# Debug flags
var debug_god_mode: bool = false  # Player takes no damage
var debug_map_revealed: bool = false  # All tiles visible (FOV bypassed)

func _ready() -> void:
	# Load harvestable resources
	_HarvestSystem.load_resources()
	# Load crop definitions for farming
	_FarmingSystem.load_crops()
	print("GameManager initialized")

## Start a new game with character name (used as seed)
## If character_name_input is empty, generates a random seed and default name
func start_new_game(character_name_input: String = "") -> void:
	if character_name_input.is_empty():
		randomize()
		world_seed = randi()
		character_name = "Adventurer"
		world_name = character_name  # Keep world_name in sync for save compatibility
	else:
		character_name = character_name_input
		world_name = character_name_input  # Keep world_name in sync for save compatibility
		# Use abs() to ensure positive seed value (hash() can return negative)
		world_seed = abs(character_name_input.hash())
		# If hash is 0 (unlikely), use a default value
		if world_seed == 0:
			world_seed = 12345

	game_state = "playing"
	TurnManager.current_turn = 0
	TurnManager.time_of_day = "dawn"

	# Initialize calendar with world seed
	CalendarManager.initialize_with_seed(world_seed)

	# Initialize weather with world seed
	WeatherManager.initialize_with_seed(world_seed)

	# Clear map cache to ensure new world generation with new seed
	MapManager.loaded_maps.clear()

	# Clear chunk cache to ensure fresh chunk generation with new colors
	ChunkManager.clear_chunks()

	# Clear farming system data (crops and tilled soil)
	_FarmingSystem.clear()

	# Clear harvest system data (renewable resources)
	_HarvestSystem.clear()

	# Clear fog of war data (explored tiles)
	_FogOfWarSystem.clear_all()

	# Reset last overworld position
	last_overworld_position = Vector2i.ZERO

	# Clear visited locations for new game
	clear_visited_locations()

	print("New game started - Character: '%s', Seed: %d" % [character_name, world_seed])

## Update the current map being played
func set_current_map(map_id: String) -> void:
	current_map_id = map_id
	print("Current map set to: ", map_id)

## Pause the game
func pause_game() -> void:
	if game_state == "playing":
		game_state = "paused"

## Resume the game
func resume_game() -> void:
	if game_state == "paused":
		game_state = "playing"

# ===== FAST TRAVEL - VISITED LOCATIONS =====

## Mark a location as visited/discovered
func mark_location_visited(location_id: String, location_type: String, location_name: String, position: Vector2i) -> void:
	if not visited_locations.has(location_id):
		visited_locations[location_id] = {
			"type": location_type,  # "town" or "dungeon"
			"name": location_name,
			"position": {"x": position.x, "y": position.y},
			"visited_turn": TurnManager.current_turn
		}
		EventBus.location_discovered.emit(location_id, location_name)
		print("GameManager: Discovered location '%s' at %v" % [location_name, position])

## Check if a location has been visited
func is_location_visited(location_id: String) -> bool:
	return visited_locations.has(location_id)

## Get all visited locations
func get_visited_locations() -> Dictionary:
	return visited_locations

## Get visited locations filtered by type
func get_visited_locations_by_type(location_type: String) -> Array:
	var result: Array = []
	for location_id in visited_locations:
		var location = visited_locations[location_id]
		if location.type == location_type:
			result.append({"id": location_id, "data": location})
	return result

## Clear visited locations (for new game)
func clear_visited_locations() -> void:
	visited_locations.clear()

## Mark towns and dungeons as visited based on their known_at_start config
## Called after map generation to populate fast travel locations
func mark_known_locations_visited() -> void:
	if not MapManager.current_map:
		print("GameManager: No current map, cannot mark locations as visited")
		return

	var towns_marked = 0
	var dungeons_marked = 0

	# Get towns from map metadata and check known_at_start flag
	var towns = MapManager.current_map.metadata.get("towns", [])
	for town in towns:
		var town_id = town.get("town_id", town.get("id", "unknown_town"))

		# Check if town definition has known_at_start = true
		var town_def = TownManager.get_town(town_id)
		if not town_def.get("known_at_start", false):
			continue

		var town_name = town.get("name", "Unknown Town")
		var town_pos = town.get("position", Vector2i.ZERO)
		# Handle position that might be Vector2i or Dictionary
		if town_pos is Dictionary:
			town_pos = Vector2i(int(town_pos.get("x", 0)), int(town_pos.get("y", 0)))
		mark_location_visited(town_id, "town", town_name, town_pos)
		towns_marked += 1

	# Get dungeons from map metadata and check known_at_start flag
	var entrances = MapManager.current_map.get_meta("dungeon_entrances", [])
	for entrance in entrances:
		var dungeon_type = entrance.get("dungeon_type", "")

		# Check if dungeon definition has known_at_start = true
		var dungeon_def = DungeonManager.get_dungeon(dungeon_type)
		if not dungeon_def.get("known_at_start", false):
			continue

		var dungeon_name = entrance.get("name", dungeon_type.capitalize())
		var entrance_pos = entrance.get("position", Vector2i.ZERO)
		# Handle position that might be Vector2i or Dictionary
		if entrance_pos is Dictionary:
			entrance_pos = Vector2i(int(entrance_pos.get("x", 0)), int(entrance_pos.get("y", 0)))
		mark_location_visited(dungeon_type, "dungeon", dungeon_name, entrance_pos)
		dungeons_marked += 1

	print("GameManager: Marked %d towns and %d dungeons as known at start" % [towns_marked, dungeons_marked])

## Legacy function - now calls mark_known_locations_visited
func mark_all_towns_visited() -> void:
	mark_known_locations_visited()
