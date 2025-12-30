extends Node

## TurnManager - Controls turn-based game flow and day/night cycle
##
## Manages the turn counter, day/night cycle, and ensures the game
## only advances when the player takes an action.

# Turn tracking
var current_turn: int = 0
var current_day: int = 1  # Day counter, starts at day 1
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

	# Process player survival systems
	_process_player_survival()

	# Process enemy turns
	EntityManager.process_entity_turns()

	EventBus.turn_advanced.emit(current_turn)

	# Reset player turn flag
	is_player_turn = true

## Process player survival systems each turn
func _process_player_survival() -> void:
	if EntityManager.player and EntityManager.player.survival:
		var effects = EntityManager.player.process_survival_turn(current_turn)
		
		# Regenerate some stamina each turn (slower rate while active)
		EntityManager.player.regenerate_stamina()
		
		# Emit warnings if any
		for warning in effects.get("warnings", []):
			EventBus.survival_warning.emit(warning, _get_warning_severity(warning))

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
		# Check if we're transitioning to a new day (night -> dawn)
		if time_of_day == "night" and new_time == "dawn":
			current_day += 1
			print("Day %d has begun" % current_day)
		time_of_day = new_time
		EventBus.time_of_day_changed.emit(time_of_day)
		print("Time of day changed to: ", time_of_day)

## Block until player takes action (for future enemy AI turns)
func wait_for_player() -> void:
	is_player_turn = false
	await EventBus.turn_advanced

## Get severity level for a warning message
func _get_warning_severity(warning: String) -> String:
	if "dying" in warning or "death" in warning or "starving to" in warning:
		return "critical"
	elif "starving" in warning or "dehydrated" in warning or "freezing" in warning or "overheating" in warning or "exhausted" in warning:
		return "severe"
	elif "very" in warning or "severely" in warning:
		return "warning"
	else:
		return "minor"
