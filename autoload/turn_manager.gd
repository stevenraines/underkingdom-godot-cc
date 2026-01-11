extends Node

## TurnManager - Controls turn-based game flow and day/night cycle
##
## Manages the turn counter, day/night cycle, and ensures the game
## only advances when the player takes an action.
## Uses CalendarManager for calendar-based time tracking.

const HarvestSystem = preload("res://systems/harvest_system.gd")
const FarmingSystem = preload("res://systems/farming_system.gd")

# Turn tracking
var current_turn: int = 0
var time_of_day: String = "dawn"
var is_player_turn: bool = true

# Cached time periods from CalendarManager (array of {id, duration, temp_modifier, start, end})
var _time_periods: Array = []

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

	# Process active magical effect durations
	_process_effect_durations()

	# Process enemy turns
	EntityManager.process_entity_turns()

	# Process renewable resource respawns
	HarvestSystem.process_renewable_resources()

	# Process crop growth and tilled soil decay
	FarmingSystem.process_crop_growth()
	FarmingSystem.process_tilled_soil_decay()

	EventBus.turn_advanced.emit(current_turn)

	# Reset player turn flag
	is_player_turn = true

## Process player survival systems each turn
func _process_player_survival() -> void:
	if EntityManager.player and EntityManager.player.survival:
		var effects = EntityManager.player.process_survival_turn(current_turn)

		# Regenerate some stamina each turn (slower rate while active)
		EntityManager.player.regenerate_stamina()

		# Regenerate mana each turn (base rate, faster in shelter)
		EntityManager.player.regenerate_mana()

		# Emit warnings if any
		for warning in effects.get("warnings", []):
			EventBus.survival_warning.emit(warning, _get_warning_severity(warning))

## Get current time of day period based on turn number
func get_time_of_day() -> String:
	var turns_per_day = get_turns_per_day()
	var turn_in_day = current_turn % turns_per_day

	# Use time periods from calendar data (array with start/end computed from durations)
	for period in _time_periods:
		var start = period.get("start", 0)
		var end = period.get("end", 100)

		# Check if current turn falls within this period
		if turn_in_day >= start and turn_in_day < end:
			return period.get("id", "day")

	return "day"  # Fallback

## Update time of day and emit signal if changed
func _update_time_of_day() -> void:
	var new_time = get_time_of_day()
	if new_time != time_of_day:
		# Check if we're transitioning to a new day (night -> dawn)
		if time_of_day == "night" and new_time == "dawn":
			CalendarManager.advance_day(GameManager.world_seed)
			_generate_daily_weather()
			print("[TurnManager] %s" % CalendarManager.get_full_date_string())
		time_of_day = new_time
		EventBus.time_of_day_changed.emit(time_of_day)
		print("Time of day changed to: ", time_of_day)


## Generate weather for the new day
func _generate_daily_weather() -> void:
	if not WeatherManager:
		return

	# Get season name from CalendarManager
	var season = CalendarManager.get_season_name()

	# Get biome ID at player position (if available)
	var biome_id = ""
	if EntityManager.player and MapManager.current_map:
		var player_pos = EntityManager.player.position
		var biome = BiomeGenerator.get_biome_at(player_pos.x, player_pos.y, MapManager.current_map.seed)
		biome_id = biome.get("id", "")

	# Calculate day number for seed
	var day_number = CalendarManager.get_total_days_elapsed()

	# Generate weather
	WeatherManager.generate_daily_weather(GameManager.world_seed, day_number, season, biome_id)

## Block until player takes action (for future enemy AI turns)
func wait_for_player() -> void:
	is_player_turn = false
	await EventBus.turn_advanced

## Process active magical effect durations for player and all entities
func _process_effect_durations() -> void:
	# Process player effects
	if EntityManager.player and EntityManager.player.has_method("process_effect_durations"):
		EntityManager.player.process_effect_durations()

	# Process effects for all other entities
	for entity in EntityManager.entities:
		if entity != EntityManager.player and entity.has_method("process_effect_durations"):
			entity.process_effect_durations()


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
