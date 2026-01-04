extends Node

## TurnManager - Controls turn-based game flow and day/night cycle
##
## Manages the turn counter, day/night cycle, and ensures the game
## only advances when the player takes an action.
## Uses CalendarManager for calendar-based time tracking.

const HarvestSystem = preload("res://systems/harvest_system.gd")

# Turn tracking
var current_turn: int = 0
var time_of_day: String = "dawn"
var is_player_turn: bool = true

# Cached time periods from CalendarManager
var _time_periods: Dictionary = {}

func _ready() -> void:
	# Load time periods from CalendarManager (will be available after CalendarManager._ready())
	call_deferred("_load_time_periods")
	print("TurnManager initialized")

## Load time period data from CalendarManager
func _load_time_periods() -> void:
	_time_periods = CalendarManager.get_time_periods()

## Get turns per day from CalendarManager
func get_turns_per_day() -> int:
	return CalendarManager.get_turns_per_day()

## Advance the turn counter and update time of day
func advance_turn() -> void:
	current_turn += 1
	_update_time_of_day()

	# Process player survival systems
	_process_player_survival()

	# Process enemy turns
	EntityManager.process_entity_turns()

	# Process renewable resource respawns
	HarvestSystem.process_renewable_resources()

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
	var turns_per_day = get_turns_per_day()
	var turn_in_day = current_turn % turns_per_day

	# Use time periods from calendar data
	for period_name in _time_periods:
		var period = _time_periods[period_name]
		var start = period.get("start", 0)
		var end = period.get("end", 100)

		# Handle wrap-around for night (85-100 and 0)
		if start < end:
			if turn_in_day >= start and turn_in_day < end:
				return period_name
		else:
			# Night wraps from end of day to start
			if turn_in_day >= start or turn_in_day < end:
				return period_name

	return "day"  # Fallback

## Update time of day and emit signal if changed
func _update_time_of_day() -> void:
	var new_time = get_time_of_day()
	if new_time != time_of_day:
		# Check if we're transitioning to a new day (night -> dawn)
		if time_of_day == "night" and new_time == "dawn":
			CalendarManager.advance_day(GameManager.world_seed)
			print("[TurnManager] %s" % CalendarManager.get_full_date_string())
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

## Get current day from CalendarManager (for backwards compatibility)
var current_day: int:
	get:
		return CalendarManager.current_day
