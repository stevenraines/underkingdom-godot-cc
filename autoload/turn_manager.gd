extends Node

## TurnManager - Controls turn-based game flow and day/night cycle
##
## Manages the turn counter, day/night cycle, and ensures the game
## only advances when the player takes an action.

# Turn tracking
var current_turn: int = 0
var time_of_day: String = "dawn"
var is_player_turn: bool = true

# Day/night cycle constants (1 full day = 100 turns)
const DAWN_START = 0
const DAWN_END = 15
const DAY_START = 15
const DAY_END = 70
const DUSK_START = 70
const DUSK_END = 85
const NIGHT_START = 85
const NIGHT_END = 100
const TURNS_PER_DAY = 100

func _ready() -> void:
	print("TurnManager initialized")

## Advance the turn counter and update time of day
func advance_turn() -> void:
	current_turn += 1
	_update_time_of_day()
	EventBus.turn_advanced.emit(current_turn)

	# Reset player turn flag
	is_player_turn = true

## Get current time of day period based on turn number
func get_time_of_day() -> String:
	var turn_in_day = current_turn % TURNS_PER_DAY

	if turn_in_day >= DAWN_START and turn_in_day < DAWN_END:
		return "dawn"
	elif turn_in_day >= DAY_START and turn_in_day < DAY_END:
		return "day"
	elif turn_in_day >= DUSK_START and turn_in_day < DUSK_END:
		return "dusk"
	else:  # NIGHT_START to NIGHT_END (850-1000) and wraps to 0
		return "night"

## Update time of day and emit signal if changed
func _update_time_of_day() -> void:
	var new_time = get_time_of_day()
	if new_time != time_of_day:
		time_of_day = new_time
		EventBus.time_of_day_changed.emit(time_of_day)
		print("Time of day changed to: ", time_of_day)

## Block until player takes action (for future enemy AI turns)
func wait_for_player() -> void:
	is_player_turn = false
	await EventBus.turn_advanced
