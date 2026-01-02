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
