extends Node

## GameManager - High-level game state and coordination
##
## Manages world seed, game state transitions, and coordinates
## between major systems like TurnManager and MapManager.

const _HarvestSystem = preload("res://systems/harvest_system.gd")

# Game state
var world_seed: int = 0
var world_name: String = ""  # Player-provided name for the world
var game_state: String = "menu"  # "menu", "playing", "paused"
var current_map_id: String = ""
var is_loading_save: bool = false  # Flag to prevent start_new_game when loading
var last_overworld_position: Vector2i = Vector2i.ZERO  # Player's position when entering dungeon

# Fast travel - visited locations tracking
# Format: location_id -> {type, name, position, visited_turn}
var visited_locations: Dictionary = {}

# Player settings
var auto_open_doors: bool = true  # Automatically open doors when walking into them

func _ready() -> void:
	# Load harvestable resources
	_HarvestSystem.load_resources()
	print("GameManager initialized")

## Start a new game with world name (used as seed)
## If world_name_input is empty, generates a random seed and default name
func start_new_game(world_name_input: String = "") -> void:
	if world_name_input.is_empty():
		randomize()
		world_seed = randi()
		world_name = "World %d" % (world_seed % 10000)
	else:
		world_name = world_name_input
		# Use abs() to ensure positive seed value (hash() can return negative)
		world_seed = abs(world_name_input.hash())
		# If hash is 0 (unlikely), use a default value
		if world_seed == 0:
			world_seed = 12345

	game_state = "playing"
	TurnManager.current_turn = 0
	TurnManager.time_of_day = "dawn"

	# Clear map cache to ensure new world generation with new seed
	MapManager.loaded_maps.clear()

	# Clear chunk cache to ensure fresh chunk generation with new colors
	ChunkManager.clear_chunks()

	# Reset last overworld position
	last_overworld_position = Vector2i.ZERO

	# Clear visited locations for new game
	clear_visited_locations()

	print("New game started - World: '%s', Seed: %d" % [world_name, world_seed])

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

## Mark all placed towns as visited (called after map generation)
## Uses map metadata which is available immediately, rather than TownManager.placed_towns
## which is populated lazily during chunk loading
func mark_all_towns_visited() -> void:
	if not MapManager.current_map:
		print("GameManager: No current map, cannot mark towns as visited")
		return

	# Get towns from map metadata (available immediately after map creation)
	var towns = MapManager.current_map.metadata.get("towns", [])
	for town in towns:
		var town_id = town.get("town_id", town.get("id", "unknown_town"))
		var town_name = town.get("name", "Unknown Town")
		var town_pos = town.get("position", Vector2i.ZERO)
		# Handle position that might be Vector2i or Dictionary
		if town_pos is Dictionary:
			town_pos = Vector2i(int(town_pos.get("x", 0)), int(town_pos.get("y", 0)))
		mark_location_visited(town_id, "town", town_name, town_pos)
	print("GameManager: Marked %d towns as visited" % towns.size())
