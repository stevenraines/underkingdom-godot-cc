class_name SurvivalSystem
extends RefCounted

## SurvivalSystem - Manages all survival mechanics
##
## Tracks hunger, thirst, temperature, stamina, and fatigue.
## Applies effects based on survival state thresholds.

# Current survival stats
var hunger: float = 100.0  # 0-100, starts full
var thirst: float = 100.0  # 0-100, starts full
var temperature: float = 68.0  # °F, comfortable default
var stamina: float = 100.0  # Current stamina
var base_max_stamina: float = 100.0  # Before fatigue reduction
var fatigue: float = 0.0  # 0-100, starts rested

# Drain rates (turns between 1 point drain)
const HUNGER_DRAIN_RATE: int = 20
const THIRST_DRAIN_RATE: int = 15
const FATIGUE_GAIN_RATE: int = 100  # Turns per 1 fatigue

# Stamina costs
const STAMINA_COST_MOVE: int = 1
const STAMINA_COST_ATTACK: int = 3
const STAMINA_COST_SPRINT: int = 5
const STAMINA_COST_HEAVY_ATTACK: int = 6

# Temperature thresholds (°F)
const TEMP_FREEZING: float = 32.0
const TEMP_COLD: float = 50.0
const TEMP_COOL: float = 59.0
const TEMP_WARM: float = 77.0
const TEMP_HOT: float = 86.0
const TEMP_HYPERTHERMIA: float = 104.0

# Base temperatures (°F)
const TEMP_WOODLAND_BASE: float = 64.0
const TEMP_DUNGEON_BASE: float = 54.0

# Time of day temperature modifiers (°F)
const TEMP_MOD_DAWN: float = -5.0
const TEMP_MOD_DAY: float = 0.0
const TEMP_MOD_DUSK: float = -4.0
const TEMP_MOD_NIGHT: float = -14.0

# Track turns for periodic effects
var _last_hunger_drain_turn: int = 0
var _last_thirst_drain_turn: int = 0
var _last_fatigue_turn: int = 0
var _last_health_drain_turn: int = 0

# Owner reference
var _owner: Entity = null

func _init(owner: Entity = null) -> void:
	_owner = owner
	if owner:
		# Calculate base max stamina from CON: 50 + CON × 10
		base_max_stamina = 50.0 + owner.attributes.get("CON", 10) * 10.0
		stamina = base_max_stamina

## Get effective max stamina (reduced by fatigue)
func get_max_stamina() -> float:
	# Fatigue reduces max stamina by fatigue%
	var fatigue_reduction = base_max_stamina * (fatigue / 100.0)
	return max(10.0, base_max_stamina - fatigue_reduction)

## Process survival effects for a turn
func process_turn(turn_number: int) -> Dictionary:
	var effects: Dictionary = {
		"hunger_drained": false,
		"thirst_drained": false,
		"fatigue_gained": false,
		"health_damage": 0,
		"stat_modifiers": {},
		"warnings": []
	}
	
	# Drain hunger
	if turn_number - _last_hunger_drain_turn >= HUNGER_DRAIN_RATE:
		hunger = max(0.0, hunger - 1.0)
		_last_hunger_drain_turn = turn_number
		effects.hunger_drained = true
		EventBus.survival_stat_changed.emit("hunger", hunger + 1.0, hunger)
	
	# Drain thirst (faster than hunger)
	if turn_number - _last_thirst_drain_turn >= THIRST_DRAIN_RATE:
		var thirst_drain = 1.0
		# Hot temperature accelerates thirst drain
		if temperature > TEMP_HOT:
			thirst_drain = 2.0
		thirst = max(0.0, thirst - thirst_drain)
		_last_thirst_drain_turn = turn_number
		effects.thirst_drained = true
		EventBus.survival_stat_changed.emit("thirst", thirst + thirst_drain, thirst)
	
	# Accumulate fatigue over time
	if turn_number - _last_fatigue_turn >= FATIGUE_GAIN_RATE:
		fatigue = min(100.0, fatigue + 1.0)
		_last_fatigue_turn = turn_number
		effects.fatigue_gained = true
		EventBus.survival_stat_changed.emit("fatigue", fatigue - 1.0, fatigue)
	
	# Calculate and apply survival effects
	var survival_effects = _calculate_survival_effects()
	effects.stat_modifiers = survival_effects.stat_modifiers
	
	# Health drain from critical states
	var health_drain_interval = survival_effects.health_drain_interval
	if health_drain_interval > 0:
		if turn_number - _last_health_drain_turn >= health_drain_interval:
			effects.health_damage = 1
			_last_health_drain_turn = turn_number
			if _owner:
				_owner.take_damage(1)
	
	# Generate warnings
	effects.warnings = _generate_warnings()
	
	return effects

## Calculate stat modifiers and effects from survival state
func _calculate_survival_effects() -> Dictionary:
	var result: Dictionary = {
		"stat_modifiers": {
			"STR": 0,
			"DEX": 0,
			"CON": 0,
			"INT": 0,
			"WIS": 0,
			"CHA": 0
		},
		"stamina_regen_modifier": 1.0,
		"max_stamina_modifier": 1.0,
		"perception_modifier": 0,
		"health_drain_interval": 0  # 0 = no drain
	}
	
	# Hunger effects
	if hunger <= 0:
		result.stat_modifiers["STR"] -= 3
		result.stat_modifiers["DEX"] -= 2
		result.health_drain_interval = _min_positive(result.health_drain_interval, 10)
	elif hunger <= 25:
		result.stat_modifiers["STR"] -= 2
		result.stamina_regen_modifier *= 0.25
		result.health_drain_interval = _min_positive(result.health_drain_interval, 50)
	elif hunger <= 50:
		result.stat_modifiers["STR"] -= 1
		result.stamina_regen_modifier *= 0.5
	elif hunger <= 75:
		result.stamina_regen_modifier *= 0.75
	
	# Thirst effects (more severe)
	if thirst <= 0:
		result.stat_modifiers["STR"] -= 2
		result.stat_modifiers["DEX"] -= 2
		result.stat_modifiers["WIS"] -= 3
		result.max_stamina_modifier *= 0.5
		result.health_drain_interval = _min_positive(result.health_drain_interval, 5)
	elif thirst <= 25:
		result.stat_modifiers["WIS"] -= 2
		result.max_stamina_modifier *= 0.6
		result.health_drain_interval = _min_positive(result.health_drain_interval, 25)
	elif thirst <= 50:
		result.stat_modifiers["WIS"] -= 1
		result.max_stamina_modifier *= 0.6
		result.perception_modifier -= 2
	elif thirst <= 75:
		result.max_stamina_modifier *= 0.8
	
	# Temperature effects
	if temperature < TEMP_FREEZING:
		result.stat_modifiers["DEX"] -= 3
		result.stamina_regen_modifier *= 0.25
		result.health_drain_interval = _min_positive(result.health_drain_interval, 10)
	elif temperature < TEMP_COLD:
		result.stat_modifiers["DEX"] -= 1
		result.stamina_regen_modifier *= 0.5
	elif temperature < TEMP_COOL:
		result.stamina_regen_modifier *= 0.75
	elif temperature > TEMP_HYPERTHERMIA:
		result.stat_modifiers["INT"] -= 2
		result.stat_modifiers["WIS"] -= 2
		result.health_drain_interval = _min_positive(result.health_drain_interval, 10)
	elif temperature > TEMP_HOT:
		result.stat_modifiers["INT"] -= 1
		# Thirst drain handled in process_turn
	
	return result

## Helper to get minimum positive value (for health drain intervals)
func _min_positive(a: int, b: int) -> int:
	if a <= 0:
		return b
	if b <= 0:
		return a
	return min(a, b)

## Generate warning messages based on survival state
func _generate_warnings() -> Array[String]:
	var warnings: Array[String] = []
	
	# Hunger warnings
	if hunger <= 0:
		warnings.append("You are starving to death!")
	elif hunger <= 25:
		warnings.append("You are starving!")
	elif hunger <= 50:
		warnings.append("You are very hungry.")
	
	# Thirst warnings
	if thirst <= 0:
		warnings.append("You are dying of thirst!")
	elif thirst <= 25:
		warnings.append("You are severely dehydrated!")
	elif thirst <= 50:
		warnings.append("You are very thirsty.")
	
	# Temperature warnings
	if temperature < TEMP_FREEZING:
		warnings.append("You are freezing!")
	elif temperature < TEMP_COLD:
		warnings.append("You are cold.")
	elif temperature > TEMP_HYPERTHERMIA:
		warnings.append("You are overheating!")
	elif temperature > TEMP_HOT:
		warnings.append("You are hot.")
	
	# Fatigue warnings
	if fatigue >= 90:
		warnings.append("You are exhausted!")
	elif fatigue >= 75:
		warnings.append("You are very tired.")
	elif fatigue >= 50:
		warnings.append("You are tired.")
	
	# Stamina warnings
	if stamina <= 0:
		warnings.append("You have no stamina!")
	elif stamina <= get_max_stamina() * 0.25:
		warnings.append("You are low on stamina.")
	
	return warnings

## Consume stamina for an action
## Returns true if action can proceed, false if not enough stamina
func consume_stamina(amount: int) -> bool:
	if stamina < amount:
		EventBus.stamina_depleted.emit()
		# Increase fatigue when trying to act without stamina
		fatigue = min(100.0, fatigue + 2.0)
		return false
	
	var old_stamina = stamina
	stamina = max(0.0, stamina - amount)
	EventBus.survival_stat_changed.emit("stamina", old_stamina, stamina)
	
	# If stamina hit 0, increase fatigue
	if stamina <= 0:
		fatigue = min(100.0, fatigue + 1.0)
		EventBus.stamina_depleted.emit()
	
	return true

## Regenerate stamina (called when not acting)
func regenerate_stamina(regen_modifier: float = 1.0) -> void:
	var max_stam = get_max_stamina()
	if stamina >= max_stam:
		return
	
	# Base regen: 1 per turn, modified by survival effects
	var regen_amount = 1.0 * regen_modifier
	var old_stamina = stamina
	stamina = min(max_stam, stamina + regen_amount)
	
	if stamina != old_stamina:
		EventBus.survival_stat_changed.emit("stamina", old_stamina, stamina)

## Update temperature based on environment
## Now uses CalendarManager for seasonal temperature variations
func update_temperature(map_id: String, time_of_day: String, player_pos: Vector2i) -> void:
	var old_temp = temperature

	# Determine base temperature
	var base_temp: float
	if map_id.begins_with("dungeon_"):
		# Dungeons have constant temperature, unaffected by seasons
		base_temp = TEMP_DUNGEON_BASE
	else:
		# Overworld uses seasonal temperature from CalendarManager
		base_temp = CalendarManager.get_ambient_temperature(time_of_day)

	# Check if player is inside a building (interior tile)
	var interior_bonus: float = 0.0
	if MapManager.current_map:
		var tile = MapManager.current_map.get_tile(player_pos)
		if tile and tile.is_interior:
			interior_bonus = CalendarManager.get_interior_temp_bonus()

	# Apply structure temperature bonuses (campfires, shelters)
	var structure_bonus = _calculate_structure_temperature_bonus(player_pos, map_id)

	temperature = base_temp + interior_bonus + structure_bonus

	if temperature != old_temp:
		EventBus.survival_stat_changed.emit("temperature", old_temp, temperature)

## Calculate temperature bonus from nearby structures
func _calculate_structure_temperature_bonus(player_pos: Vector2i, map_id: String) -> float:
	var bonus: float = 0.0
	var structures = StructureManager.get_structures_on_map(map_id)

	for structure in structures:
		# Check fire component
		if structure.has_component("fire"):
			var fire = structure.get_component("fire")
			if fire.affects_position(structure.position, player_pos):
				bonus += fire.get_temperature_bonus()

		# Check shelter component
		if structure.has_component("shelter"):
			var shelter = structure.get_component("shelter")
			if shelter.is_sheltered(structure.position, player_pos):
				bonus += shelter.temperature_bonus

	return bonus

## Get current hunger state as string
func get_hunger_state() -> String:
	if hunger <= 0:
		return "starving"
	elif hunger <= 25:
		return "famished"
	elif hunger <= 50:
		return "hungry"
	elif hunger <= 75:
		return "peckish"
	else:
		return "satisfied"

## Get current thirst state as string
func get_thirst_state() -> String:
	if thirst <= 0:
		return "dehydrated"
	elif thirst <= 25:
		return "parched"
	elif thirst <= 50:
		return "thirsty"
	elif thirst <= 75:
		return "dry"
	else:
		return "hydrated"

## Get current temperature state as string
func get_temperature_state() -> String:
	if temperature < TEMP_FREEZING:
		return "freezing"
	elif temperature < TEMP_COLD:
		return "cold"
	elif temperature < TEMP_COOL:
		return "cool"
	elif temperature <= TEMP_WARM:
		return "comfortable"
	elif temperature <= TEMP_HOT:
		return "warm"
	elif temperature <= TEMP_HYPERTHERMIA:
		return "hot"
	else:
		return "overheating"

## Get current fatigue state as string
func get_fatigue_state() -> String:
	if fatigue >= 90:
		return "exhausted"
	elif fatigue >= 75:
		return "very tired"
	elif fatigue >= 50:
		return "tired"
	elif fatigue >= 25:
		return "slightly tired"
	else:
		return "rested"

## Apply food to reduce hunger
func eat(nutrition: float) -> void:
	var old_hunger = hunger
	hunger = min(100.0, hunger + nutrition)
	EventBus.survival_stat_changed.emit("hunger", old_hunger, hunger)

## Apply water to reduce thirst
func drink(hydration: float) -> void:
	var old_thirst = thirst
	thirst = min(100.0, thirst + hydration)
	EventBus.survival_stat_changed.emit("thirst", old_thirst, thirst)

## Rest to reduce fatigue (future: sleeping system)
func rest(rest_amount: float) -> void:
	var old_fatigue = fatigue
	fatigue = max(0.0, fatigue - rest_amount)
	EventBus.survival_stat_changed.emit("fatigue", old_fatigue, fatigue)

## Get all current stat modifiers from survival effects
func get_stat_modifiers() -> Dictionary:
	return _calculate_survival_effects().stat_modifiers

## Get effective stat value with survival modifiers
func get_effective_stat(base_value: int, stat_name: String) -> int:
	var modifiers = get_stat_modifiers()
	return max(1, base_value + modifiers.get(stat_name, 0))
