extends Node

## TurnManager - Controls turn-based game flow and day/night cycle
##
## Manages the turn counter, day/night cycle, and ensures the game
## only advances when the player takes an action.
## Uses CalendarManager for calendar-based time tracking.

const HarvestSystem = preload("res://systems/harvest_system.gd")
const FarmingSystem = preload("res://systems/farming_system.gd")
const RitualSystemClass = preload("res://systems/ritual_system.gd")

# Signals for turn state changes (used for performance optimization)
signal player_turn_started  # Emitted when player's turn begins (after enemy turns complete)
signal player_turn_ended  # Emitted when player's turn ends (before enemy turns start)

# Turn tracking
var current_turn: int = 0
var time_of_day: String = "dawn"
var is_player_turn: bool = true

# Auto-save tracking
var turns_since_autosave: int = 0

# Cached time periods from CalendarManager (array of {id, duration, temp_modifier, start, end})
var _time_periods: Array = []

# Message deduplication tracking
var _last_log_message: String = ""
var _log_repeat_count: int = 0

func _ready() -> void:
	# Load time periods from CalendarManager (will be available after CalendarManager._ready())
	call_deferred("_load_time_periods")

	# Connect to game_saved signal to reset auto-save counter
	EventBus.game_saved.connect(_on_game_saved)

	print("TurnManager initialized")

## Load time period data from CalendarManager
func _load_time_periods() -> void:
	_time_periods = CalendarManager.get_time_periods()

## Print message with deduplication - skips if same as last message
## DISABLED: Commenting out for cleaner debug output
func _log(_message: String) -> void:
	return  # Temporarily disabled for debugging
	#if message == _last_log_message:
	#	_log_repeat_count += 1
	#	# CRITICAL: If message repeats too many times, we may have an infinite loop
	#	if _log_repeat_count > 10:
	#		push_error("[TurnManager] INFINITE LOOP DETECTED: Message repeated %d times: %s" % [_log_repeat_count, message])
	#		# Emergency brake - force stop
	#		if ChunkManager:
	#			ChunkManager.emergency_unfreeze()
	#		return
	#	return
	#
	## If we had repeats, flush the count before printing new message
	#if _log_repeat_count > 0:
	#	print("  (repeated %d times)" % _log_repeat_count)
	#	_log_repeat_count = 0
	#
	#print(message)
	#_last_log_message = message

## Get turns per day from CalendarManager
func get_turns_per_day() -> int:
	return CalendarManager.get_turns_per_day()

## Advance the turn counter and update time of day
func advance_turn() -> void:
	_log("[TurnManager] === Starting turn %d ===" % (current_turn + 1))

	# ========================================================================
	# PHASE 1: PRE-TURN (Setup & Freeze World State)
	# ========================================================================

	# Player's turn is ending (they just took an action)
	player_turn_ended.emit()
	current_turn += 1
	_log("[TurnManager] Turn advanced to %d" % current_turn)

	# Update time/calendar before freezing
	_update_time_of_day()
	_log("[TurnManager] Time of day updated")

	# FREEZE chunk operations to prevent signal cascade during entity processing
	ChunkManager.freeze_chunk_operations()
	_log("[TurnManager] Chunk operations FROZEN")

	# Prepare entity snapshot for safe iteration
	EntityManager.prepare_turn_snapshot()
	_log("[TurnManager] Entity snapshot prepared")

	# Process player-only systems (survival, rituals)
	_process_player_survival()
	_log("[TurnManager] Player survival processed")

	_process_ritual_channeling()
	_log("[TurnManager] Ritual channeling processed")

	# Process PLAYER effects (player is not in entities array, must be done separately)
	if EntityManager.player:
		if EntityManager.player.has_method("process_dot_effects"):
			EntityManager.player.process_dot_effects()
		if EntityManager.player.has_method("process_effect_durations"):
			EntityManager.player.process_effect_durations()
	_log("[TurnManager] Player effects processed")

	# ========================================================================
	# PHASE 2: EXECUTION (Process All Entity Actions with Frozen Chunks)
	# ========================================================================

	# Process entity turns (DoTs + Effects + AI actions in single consolidated loop)
	_log("[TurnManager] Processing entity turns...")
	EntityManager.process_entity_turns()
	_log("[TurnManager] Entity turns complete")

	# EMERGENCY BRAKE: If player died, stop immediately
	if EntityManager.player and not EntityManager.player.is_alive:
		# Emergency unfreeze without applying operations (prevents signal cascade)
		ChunkManager.emergency_unfreeze()
		_log("[TurnManager] !!! PLAYER DIED - Stopping turn advancement !!!")
		return

	# ========================================================================
	# PHASE 3: POST-TURN (Cleanup & Apply Deferred Changes)
	# ========================================================================

	# UNFREEZE chunk operations and apply queued loads/unloads
	ChunkManager.unfreeze_and_apply_queued_operations()
	_log("[TurnManager] Chunk operations UNFROZEN and applied")

	# Process world systems (now safe to modify chunks)
	_log("[TurnManager] Processing renewable resources...")
	HarvestSystem.process_renewable_resources()
	_log("[TurnManager] Renewable resources complete")

	_log("[TurnManager] Processing feature respawns...")
	FeatureManager.process_feature_respawns()
	_log("[TurnManager] Feature respawns complete")

	_log("[TurnManager] Processing farming systems...")
	FarmingSystem.process_crop_growth()
	FarmingSystem.process_tilled_soil_decay()
	_log("[TurnManager] Farming systems complete")

	# Emit turn advanced signal
	_log("[TurnManager] Emitting turn_advanced signal")
	EventBus.turn_advanced.emit(current_turn)

	# Process auto-save if interval reached
	_process_autosave()

	# Reset player turn flag and emit signal
	is_player_turn = true
	player_turn_started.emit()
	_log("[TurnManager] === Turn %d complete ===" % current_turn)

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

## Process ritual channeling each turn (if active)
func _process_ritual_channeling() -> void:
	if RitualSystemClass.is_channeling():
		RitualSystemClass.process_channeling_turn()

## Process auto-save every N turns
func _process_autosave() -> void:
	turns_since_autosave += 1

	if turns_since_autosave >= SaveManager.AUTOSAVE_INTERVAL:
		if SaveManager.save_autosave():
			turns_since_autosave = 0

## Reset auto-save counter when manual save occurs
func _on_game_saved(_slot: int) -> void:
	turns_since_autosave = 0

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
			#print("[TurnManager] %s" % CalendarManager.get_full_date_string())
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
