extends Node

## GameManager - High-level game state and coordination
##
## Manages world seed, game state transitions, and coordinates
## between major systems like TurnManager and MapManager.

const _HarvestSystem = preload("res://systems/harvest_system.gd")

# Game state
var world_seed: int = 0
var game_state: String = "menu"  # "menu", "playing", "paused"
var current_map_id: String = ""

func _ready() -> void:
	# Load harvestable resources
	_HarvestSystem.load_resources()
	print("GameManager initialized")

## Start a new game with optional seed
## If seed is -1, generates a random seed
func start_new_game(seed: int = -1) -> void:
	if seed == -1:
		randomize()
		world_seed = randi()
	else:
		world_seed = seed

	game_state = "playing"
	TurnManager.current_turn = 0
	TurnManager.time_of_day = "dawn"

	print("New game started with seed: ", world_seed)

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
