extends Node

## WeatherManager - Data-driven weather system
##
## Manages weather generation, transitions, and effects based on season and biome.
## Weather changes at dawn each day and affects temperature, visibility, and survival.

const WEATHER_PATH = "res://data/weather"
const SEASONS_PATH = "res://data/weather/seasons"

# Weather definitions loaded from JSON
var weather_definitions: Dictionary = {}

# Seasonal weather configs loaded from JSON
var seasonal_configs: Dictionary = {}

# Current weather state
var current_weather_id: String = "clear"
var weather_duration_remaining: int = 1  # Days remaining
var special_event_active: String = ""
var special_event_duration: int = 0
var special_event_temp_modifier: float = 0.0

# Cache for performance
var _cached_weather: Dictionary = {}


func _ready() -> void:
	_load_weather_definitions()
	_load_seasonal_configs()
	print("[WeatherManager] Initialized with %d weather types, %d seasons" % [weather_definitions.size(), seasonal_configs.size()])


## Load all weather type definitions from JSON files
func _load_weather_definitions() -> void:
	var dir = DirAccess.open(WEATHER_PATH)
	if not dir:
		push_error("[WeatherManager] Failed to open weather directory: %s" % WEATHER_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		# Skip directories (like seasons/) and non-JSON files
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_weather_file(WEATHER_PATH + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Load a single weather definition file
func _load_weather_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[WeatherManager] Failed to load weather file: %s" % path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_warning("[WeatherManager] Failed to parse weather JSON: %s - %s" % [path, json.get_error_message()])
		return

	var data = json.data
	var weather_id = data.get("id", "")
	if weather_id != "":
		weather_definitions[weather_id] = data


## Load seasonal weather configuration files
func _load_seasonal_configs() -> void:
	var dir = DirAccess.open(SEASONS_PATH)
	if not dir:
		push_warning("[WeatherManager] Failed to open seasons directory: %s" % SEASONS_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_season_file(SEASONS_PATH + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Load a single seasonal config file
func _load_season_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[WeatherManager] Failed to load season file: %s" % path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_warning("[WeatherManager] Failed to parse season JSON: %s - %s" % [path, json.get_error_message()])
		return

	var data = json.data
	var season_name = data.get("season", "")
	if season_name != "":
		seasonal_configs[season_name] = data


## Initialize weather with world seed
func initialize_with_seed(world_seed: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + 7000  # Offset for weather

	# Start with partly cloudy as a neutral starting weather
	current_weather_id = "partly_cloudy"
	weather_duration_remaining = 1

	print("[WeatherManager] Weather initialized: %s" % current_weather_id)


## Generate new weather for the day
## Called at dawn by CalendarManager/TurnManager
func generate_daily_weather(world_seed: int, day_number: int, season: String, biome_id: String = "") -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + day_number * 100

	# Check if we should continue current weather
	weather_duration_remaining -= 1
	if weather_duration_remaining > 0:
		# Weather persists
		return

	# Check for special events first
	if _check_special_events(rng, season):
		return

	# Get base seasonal weights
	var weights = _get_seasonal_weights(season)

	# Apply biome modifiers if provided
	if biome_id != "":
		weights = _apply_biome_modifiers(weights, biome_id)

	# Get current temperature for rain-to-snow conversion
	var current_temp = _get_approximate_temp(season)
	weights = _apply_rain_to_snow_conversion(weights, current_temp, season, biome_id)

	# Pick new weather
	var old_weather = current_weather_id
	current_weather_id = _weighted_random_choice(rng, weights)

	# Set duration
	var weather_def = get_weather_definition(current_weather_id)
	var min_days = weather_def.get("min_duration_days", 1)
	var max_days = weather_def.get("max_duration_days", 1)
	weather_duration_remaining = rng.randi_range(min_days, max_days)

	# Emit signal if weather changed
	if old_weather != current_weather_id:
		var message = weather_def.get("messages", {}).get("start", "The weather changes.")
		EventBus.weather_changed.emit(old_weather, current_weather_id, message)
		print("[WeatherManager] Weather changed: %s -> %s (duration: %d days)" % [old_weather, current_weather_id, weather_duration_remaining])

	_cached_weather = weather_def


## Check for special weather events
func _check_special_events(rng: RandomNumberGenerator, season: String) -> bool:
	# Handle ongoing special event
	if special_event_active != "":
		special_event_duration -= 1
		if special_event_duration <= 0:
			EventBus.special_weather_event.emit(special_event_active, false)
			special_event_active = ""
			special_event_temp_modifier = 0.0
		return special_event_active != ""

	# Check for new special events
	var season_config = seasonal_configs.get(season.to_lower(), {})
	var special_events = season_config.get("special_events", {})

	for event_id in special_events:
		var event_data = special_events[event_id]
		var chance = event_data.get("chance", 0.0)

		if rng.randf() < chance:
			special_event_active = event_id
			special_event_duration = event_data.get("duration_days", 1)
			special_event_temp_modifier = event_data.get("temp_modifier", 0.0)

			var message = event_data.get("message", "A special weather event occurs.")
			EventBus.special_weather_event.emit(event_id, true)
			print("[WeatherManager] Special event started: %s (%d days)" % [event_id, special_event_duration])
			return true

	return false


## Get seasonal weather weights
func _get_seasonal_weights(season: String) -> Dictionary:
	var season_config = seasonal_configs.get(season.to_lower(), {})
	return season_config.get("base_weather_weights", {"clear": 50, "partly_cloudy": 30, "cloudy": 20})


## Apply biome modifiers to weather weights
func _apply_biome_modifiers(weights: Dictionary, biome_id: String) -> Dictionary:
	var biome = BiomeManager.get_biome(biome_id)
	if biome.is_empty():
		return weights

	var modifiers = biome.get("weather_modifiers", {})
	var modified_weights = weights.duplicate()

	# Apply bonuses
	for modifier_key in modifiers:
		if modifier_key.ends_with("_chance_bonus"):
			var weather_type = modifier_key.replace("_chance_bonus", "")
			var bonus = modifiers[modifier_key]
			if weather_type in modified_weights:
				modified_weights[weather_type] *= (1.0 + bonus)
			elif weather_type == "rain":
				# Apply rain bonus to all rain types
				for rain_type in ["light_rain", "rain", "heavy_rain"]:
					if rain_type in modified_weights:
						modified_weights[rain_type] *= (1.0 + bonus)
			elif weather_type == "snow":
				# Apply snow bonus to all snow types
				for snow_type in ["light_snow", "snow", "blizzard"]:
					if snow_type in modified_weights:
						modified_weights[snow_type] *= (1.0 + bonus)

	# Apply penalties
	for modifier_key in modifiers:
		if modifier_key.ends_with("_chance_penalty"):
			var weather_type = modifier_key.replace("_chance_penalty", "")
			var penalty = modifiers[modifier_key]
			if weather_type in modified_weights:
				modified_weights[weather_type] *= (1.0 - penalty)

	return modified_weights


## Get approximate temperature for rain-to-snow conversion check
func _get_approximate_temp(season: String) -> float:
	# Get season base temp from CalendarManager
	if CalendarManager:
		return CalendarManager.get_season_base_temp()
	# Fallback estimates
	match season.to_lower():
		"spring": return 55.0
		"summer": return 75.0
		"autumn": return 50.0
		"winter": return 35.0
		_: return 60.0


## Convert rain to snow based on temperature
func _apply_rain_to_snow_conversion(weights: Dictionary, temp: float, season: String, biome_id: String) -> Dictionary:
	# Get threshold from biome or season
	var threshold = 34.0  # Default freezing threshold

	if biome_id != "":
		var biome = BiomeManager.get_biome(biome_id)
		var modifiers = biome.get("weather_modifiers", {})
		threshold = modifiers.get("rain_to_snow_threshold", threshold)
	else:
		var season_config = seasonal_configs.get(season.to_lower(), {})
		threshold = season_config.get("rain_to_snow_temp_threshold", threshold)

	# If temperature is below threshold, convert rain to snow
	if temp < threshold:
		var modified = weights.duplicate()

		# Convert light_rain to light_snow
		if "light_rain" in modified:
			var rain_weight = modified["light_rain"]
			modified.erase("light_rain")
			modified["light_snow"] = modified.get("light_snow", 0) + rain_weight

		# Convert rain to snow
		if "rain" in modified:
			var rain_weight = modified["rain"]
			modified.erase("rain")
			modified["snow"] = modified.get("snow", 0) + rain_weight

		# Convert heavy_rain/thunderstorm to blizzard
		if "heavy_rain" in modified:
			var rain_weight = modified["heavy_rain"]
			modified.erase("heavy_rain")
			modified["blizzard"] = modified.get("blizzard", 0) + rain_weight * 0.5
			modified["snow"] = modified.get("snow", 0) + rain_weight * 0.5

		if "thunderstorm" in modified:
			var storm_weight = modified["thunderstorm"]
			modified.erase("thunderstorm")
			modified["blizzard"] = modified.get("blizzard", 0) + storm_weight

		return modified

	return weights


## Weighted random selection from weights dictionary
func _weighted_random_choice(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total_weight = 0.0
	for weather_id in weights:
		total_weight += weights[weather_id]

	if total_weight <= 0:
		return "clear"

	var roll = rng.randf() * total_weight
	var cumulative = 0.0

	for weather_id in weights:
		cumulative += weights[weather_id]
		if roll <= cumulative:
			return weather_id

	# Fallback
	return weights.keys()[0] if weights.size() > 0 else "clear"


## Get weather definition by ID
func get_weather_definition(weather_id: String) -> Dictionary:
	return weather_definitions.get(weather_id, {})


## Get current weather definition
func get_current_weather() -> Dictionary:
	if _cached_weather.is_empty():
		_cached_weather = get_weather_definition(current_weather_id)
	return _cached_weather


## Get current weather name
func get_current_weather_name() -> String:
	return get_current_weather().get("name", "Unknown")


## Get current weather ASCII character
func get_current_weather_char() -> String:
	return get_current_weather().get("ascii_char", "?")


## Get current weather color
func get_current_weather_color() -> Color:
	var color_str = get_current_weather().get("color", "#FFFFFF")
	return Color.html(color_str)


## Get temperature modifier from current weather (°F)
func get_weather_temp_modifier() -> float:
	var base_modifier = get_current_weather().get("temp_modifier", 0.0)
	# Add special event modifier
	return base_modifier + special_event_temp_modifier


## Get visibility modifier from current weather (tiles)
func get_visibility_modifier() -> int:
	return get_current_weather().get("visibility_modifier", 0)


## Get stamina drain modifier from current weather
func get_stamina_drain_modifier() -> float:
	return get_current_weather().get("stamina_drain_modifier", 1.0)


## Get thirst drain modifier from current weather
func get_thirst_drain_modifier() -> float:
	return get_current_weather().get("thirst_drain_modifier", 1.0)


## Get movement cost modifier from current weather
func get_movement_cost_modifier() -> float:
	return get_current_weather().get("movement_cost_modifier", 1.0)


## Check if current weather prevents outdoor fires
func does_weather_prevent_fire() -> bool:
	return get_current_weather().get("fire_prevention", false)


## Check if current weather requires shelter
func does_weather_require_shelter() -> bool:
	return get_current_weather().get("shelter_required", false)


## Get exposure damage interval (turns between damage ticks, 0 = no damage)
func get_exposure_damage_interval() -> int:
	return get_current_weather().get("exposure_damage_interval", 0)


## Check if player is in dungeon (no weather effects)
func is_in_dungeon() -> bool:
	if MapManager and MapManager.current_map:
		var map_id = MapManager.current_map.map_id
		return map_id != "overworld" and not map_id.begins_with("town_")
	return false


## Check if weather effects should apply to player
func should_apply_weather_effects() -> bool:
	# No weather effects in dungeons
	if is_in_dungeon():
		return false
	return true


## Get weather message for current conditions
func get_weather_message() -> String:
	var messages = get_current_weather().get("messages", {})
	return messages.get("ongoing", "")


## Serialize weather state for saving
func serialize() -> Dictionary:
	return {
		"current_weather_id": current_weather_id,
		"weather_duration_remaining": weather_duration_remaining,
		"special_event_active": special_event_active,
		"special_event_duration": special_event_duration,
		"special_event_temp_modifier": special_event_temp_modifier
	}


## Deserialize weather state from save
func deserialize(data: Dictionary) -> void:
	current_weather_id = data.get("current_weather_id", "clear")
	weather_duration_remaining = data.get("weather_duration_remaining", 1)
	special_event_active = data.get("special_event_active", "")
	special_event_duration = data.get("special_event_duration", 0)
	special_event_temp_modifier = data.get("special_event_temp_modifier", 0.0)
	_cached_weather = get_weather_definition(current_weather_id)
