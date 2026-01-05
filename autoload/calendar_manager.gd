extends Node

## CalendarManager - Data-driven calendar system
##
## Manages years, seasons, months, weeks, and days based on calendar.json.
## Provides temperature modifiers based on season and time of day.

const CALENDAR_PATH = "res://data/calendar.json"

# Calendar data loaded from JSON
var calendar_data: Dictionary = {}

# Current calendar state
var current_year: int = 1
var current_season_index: int = 0  # 0-3 (Spring, Summer, Autumn, Winter)
var current_month_index: int = 0   # 0-2 within season
var current_day: int = 1           # 1-28
var current_day_of_week: int = 0   # 0-6

# Daily temperature variation (set once per day from seed)
var daily_temp_variation: float = 0.0

# Cached values
var _days_per_week: int = 7
var _days_per_month: int = 28
var _months_per_season: int = 3
var _turns_per_day: int = 100  # Calculated from time_periods

# Time period data (array of {id, duration, temp_modifier, start, end})
var _time_periods: Array = []

func _ready() -> void:
	_load_calendar_data()
	print("[CalendarManager] Initialized")

## Load calendar configuration from JSON
func _load_calendar_data() -> void:
	var file = FileAccess.open(CALENDAR_PATH, FileAccess.READ)
	if not file:
		push_error("[CalendarManager] Failed to load calendar data from: %s" % CALENDAR_PATH)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("[CalendarManager] Failed to parse calendar JSON: %s" % json.get_error_message())
		return

	calendar_data = json.data

	# Cache commonly used values
	_days_per_week = calendar_data.get("days_per_week", 7)
	_days_per_month = calendar_data.get("days_per_month", 28)
	_months_per_season = calendar_data.get("months_per_season", 3)

	# Load time periods and calculate turns_per_day from sum of durations
	_load_time_periods()

## Load time periods from JSON and calculate turns_per_day from durations
func _load_time_periods() -> void:
	var periods_data = calendar_data.get("time_periods", [])
	_time_periods.clear()
	_turns_per_day = 0

	var current_turn = 0
	for period in periods_data:
		var duration = period.get("duration", 1)
		var period_entry = {
			"id": period.get("id", "unknown"),
			"duration": duration,
			"temp_modifier": period.get("temp_modifier", 0),
			"show_in_rest_menu": period.get("show_in_rest_menu", true),
			"start": current_turn,
			"end": current_turn + duration
		}
		_time_periods.append(period_entry)
		current_turn += duration

	_turns_per_day = current_turn
	print("[CalendarManager] Loaded %d time periods, turns_per_day = %d" % [_time_periods.size(), _turns_per_day])

## Initialize calendar with world seed
func initialize_with_seed(world_seed: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + 5000  # Offset for calendar

	# Generate starting year
	var min_year = calendar_data.get("starting_year_min", 101)
	var max_year = calendar_data.get("starting_year_max", 899)
	current_year = rng.randi_range(min_year, max_year)

	# Start at beginning of spring (day 1, month 1, season 0)
	current_season_index = 0
	current_month_index = 0
	current_day = 1
	current_day_of_week = 0

	# Set initial daily temperature variation
	_update_daily_temp_variation(world_seed)

	print("[CalendarManager] Calendar initialized: Year %d, %s" % [current_year, get_full_date_string()])

## Advance to the next day
func advance_day(world_seed: int) -> void:
	current_day += 1
	current_day_of_week = (current_day_of_week + 1) % _days_per_week

	# Check for month rollover
	if current_day > _days_per_month:
		current_day = 1
		current_month_index += 1

		# Check for season rollover
		if current_month_index >= _months_per_season:
			current_month_index = 0
			current_season_index += 1

			# Check for year rollover
			if current_season_index >= 4:
				current_season_index = 0
				current_year += 1
				print("[CalendarManager] New year: %d" % current_year)

	# Update daily temperature variation
	_update_daily_temp_variation(world_seed)

	EventBus.day_changed.emit(current_day)

## Update daily temperature variation based on seed and current day
func _update_daily_temp_variation(world_seed: int) -> void:
	var rng = RandomNumberGenerator.new()
	# Use seed + year + total day count for deterministic daily variation
	var total_days = get_total_days_elapsed()
	rng.seed = world_seed + current_year * 1000 + total_days

	var variation = calendar_data.get("daily_temp_variation", {"min": -3, "max": 3})
	daily_temp_variation = rng.randf_range(variation.min, variation.max)

## Get total days elapsed since start of year
func get_total_days_elapsed() -> int:
	var days = 0
	# Days from completed seasons
	days += current_season_index * _months_per_season * _days_per_month
	# Days from completed months in current season
	days += current_month_index * _days_per_month
	# Days in current month
	days += current_day
	return days

## Get turns per day
func get_turns_per_day() -> int:
	return _turns_per_day

## Get current season data
func get_current_season() -> Dictionary:
	var seasons = calendar_data.get("seasons", [])
	if current_season_index >= 0 and current_season_index < seasons.size():
		return seasons[current_season_index]
	return {}

## Get current month data
func get_current_month() -> Dictionary:
	var season = get_current_season()
	var months = season.get("months", [])
	if current_month_index >= 0 and current_month_index < months.size():
		return months[current_month_index]
	return {}

## Get current season name
func get_season_name() -> String:
	return get_current_season().get("name", "Unknown")

## Get current month name
func get_month_name() -> String:
	return get_current_month().get("name", "Unknown")

## Get current day name
func get_day_name() -> String:
	var day_names = calendar_data.get("day_names", ["Day"])
	if current_day_of_week >= 0 and current_day_of_week < day_names.size():
		return day_names[current_day_of_week]
	return "Day"

## Get day suffix (1st, 2nd, 3rd, etc.)
func get_day_suffix() -> String:
	var day_mod = current_day % 10
	var day_mod_100 = current_day % 100

	if day_mod_100 >= 11 and day_mod_100 <= 13:
		return "th"
	elif day_mod == 1:
		return "st"
	elif day_mod == 2:
		return "nd"
	elif day_mod == 3:
		return "rd"
	else:
		return "th"

## Get formatted date string: "15th of Bloom, Year 342 (Spring)"
func get_full_date_string() -> String:
	return "%d%s of %s, Year %d (%s)" % [
		current_day,
		get_day_suffix(),
		get_month_name(),
		current_year,
		get_season_name()
	]

## Get short date string: "Moonday, 15th Bloom"
func get_short_date_string() -> String:
	return "%s, %d%s %s" % [
		get_day_name(),
		current_day,
		get_day_suffix(),
		get_month_name()
	]

## Get base temperature for current season (°F)
func get_season_base_temp() -> float:
	return get_current_season().get("base_temp", 60.0)

## Get temperature modifier for current month (°F)
func get_month_temp_modifier() -> float:
	return get_current_month().get("temp_modifier", 0.0)

## Get temperature modifier for time of day (°F)
func get_time_of_day_temp_modifier(time_of_day: String) -> float:
	for period in _time_periods:
		if period.id == time_of_day:
			return period.temp_modifier
	return 0.0

## Get the ambient temperature for current conditions (°F)
## Combines season base + month modifier + time of day modifier + daily variation
func get_ambient_temperature(time_of_day: String) -> float:
	var temp = get_season_base_temp()
	temp += get_month_temp_modifier()
	temp += get_time_of_day_temp_modifier(time_of_day)
	temp += daily_temp_variation
	return temp

## Get time of day periods from data (returns array of period dictionaries)
func get_time_periods() -> Array:
	return _time_periods

## Get temperature bonus for being inside a building (°F)
func get_interior_temp_bonus() -> float:
	return calendar_data.get("interior_temp_bonus", 10.0)

## Serialize calendar state for saving
func serialize() -> Dictionary:
	return {
		"year": current_year,
		"season_index": current_season_index,
		"month_index": current_month_index,
		"day": current_day,
		"day_of_week": current_day_of_week,
		"daily_temp_variation": daily_temp_variation
	}

## Deserialize calendar state from save
func deserialize(data: Dictionary) -> void:
	current_year = data.get("year", 1)
	current_season_index = data.get("season_index", 0)
	current_month_index = data.get("month_index", 0)
	current_day = data.get("day", 1)
	current_day_of_week = data.get("day_of_week", 0)
	daily_temp_variation = data.get("daily_temp_variation", 0.0)
