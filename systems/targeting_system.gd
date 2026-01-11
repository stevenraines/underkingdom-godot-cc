class_name TargetingSystem
extends RefCounted

## TargetingSystem - Handles target selection for ranged combat and spells
##
## Provides target cycling and validation for ranged/thrown weapon attacks
## and spell targeting. Integrates with the UI to show targeting feedback.

# Preload system dependencies - required for cross-script class references
const RangedCombatSystemClass = preload("res://systems/ranged_combat_system.gd")
const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")

signal target_changed(target: Entity)
signal targeting_started()
signal targeting_cancelled()
signal targeting_confirmed(target: Entity)

# Current targeting state
var is_targeting: bool = false
var current_target: Entity = null
var valid_targets: Array[Entity] = []
var target_index: int = 0

# Attacker and weapon info for current targeting session
var attacker: Entity = null
var weapon: Item = null
var ammo: Item = null  # For ranged weapons that need ammo

# Spell targeting mode
var is_spell_targeting: bool = false
var targeting_spell = null  # The spell being targeted (Spell object)

## Start a targeting session for ranged attack
## Returns true if there are valid targets, false otherwise
func start_targeting(p_attacker: Entity, p_weapon: Item, p_ammo: Item = null) -> bool:
	attacker = p_attacker
	weapon = p_weapon
	ammo = p_ammo

	# Get all valid targets
	valid_targets = RangedCombatSystemClass.get_valid_targets(attacker, weapon)

	if valid_targets.is_empty():
		return false

	is_targeting = true
	target_index = 0
	current_target = valid_targets[0]

	targeting_started.emit()
	target_changed.emit(current_target)

	return true


## Start a targeting session for spell casting
## Returns true if there are valid targets, false otherwise
func start_spell_targeting(p_attacker: Entity, p_spell) -> bool:
	attacker = p_attacker
	targeting_spell = p_spell
	is_spell_targeting = true
	weapon = null
	ammo = null

	# Get all valid targets for this spell
	valid_targets = SpellCastingSystemClass.get_valid_spell_targets(attacker, p_spell)

	if valid_targets.is_empty():
		_end_targeting()
		return false

	is_targeting = true
	target_index = 0
	current_target = valid_targets[0]

	targeting_started.emit()
	target_changed.emit(current_target)

	return true


## Confirm the current target and cast spell
## Returns the spell cast result dictionary
func confirm_spell_target() -> Dictionary:
	if not is_targeting or not current_target or not is_spell_targeting:
		return {"success": false, "message": "No target selected"}

	var spell = targeting_spell
	var caster = attacker
	var target = current_target

	# End targeting before casting (so mana display updates correctly)
	_end_targeting()
	targeting_confirmed.emit(target)

	# Cast the spell
	var result = SpellCastingSystemClass.cast_spell(caster, spell, target)
	return result


## Cycle to the next target
func cycle_next() -> void:
	if not is_targeting or valid_targets.is_empty():
		return

	target_index = (target_index + 1) % valid_targets.size()
	current_target = valid_targets[target_index]
	target_changed.emit(current_target)


## Cycle to the previous target
func cycle_previous() -> void:
	if not is_targeting or valid_targets.is_empty():
		return

	target_index = (target_index - 1 + valid_targets.size()) % valid_targets.size()
	current_target = valid_targets[target_index]
	target_changed.emit(current_target)


## Confirm the current target and execute attack
## Returns the attack result dictionary
func confirm_target() -> Dictionary:
	if not is_targeting or not current_target:
		return {"error": "No target selected"}

	var result = RangedCombatSystemClass.attempt_ranged_attack(attacker, current_target, weapon, ammo)

	# End targeting
	var confirmed_target = current_target
	_end_targeting()
	targeting_confirmed.emit(confirmed_target)

	return result


## Cancel the targeting session
func cancel() -> void:
	_end_targeting()
	targeting_cancelled.emit()


## End the targeting session and reset state
func _end_targeting() -> void:
	is_targeting = false
	current_target = null
	valid_targets.clear()
	target_index = 0
	attacker = null
	weapon = null
	ammo = null
	is_spell_targeting = false
	targeting_spell = null


## Get the current target
func get_current_target() -> Entity:
	return current_target


## Get the count of valid targets
func get_target_count() -> int:
	return valid_targets.size()


## Get the current target index (1-based for display)
func get_target_index_display() -> int:
	return target_index + 1


## Get distance to current target
func get_target_distance() -> int:
	if not attacker or not current_target:
		return 0
	return RangedCombatSystemClass.get_tile_distance(attacker.position, current_target.position)


## Get calculated hit chance for current target
func get_hit_chance() -> int:
	if not attacker or not current_target or not weapon:
		return 0

	var str_stat = attacker.attributes.get("STR", 10)
	var effective_range = weapon.get_effective_range(str_stat)
	var distance = RangedCombatSystemClass.get_tile_distance(attacker.position, current_target.position)

	return RangedCombatSystemClass.calculate_ranged_accuracy(attacker, current_target, weapon, distance, effective_range)


## Check if targeting is active
func is_active() -> bool:
	return is_targeting


## Get targeting status text for UI
func get_status_text() -> String:
	if not is_targeting or not current_target:
		return ""

	var target_name = current_target.name
	var distance = get_target_distance()
	var index_text = "%d/%d" % [get_target_index_display(), get_target_count()]

	if is_spell_targeting and targeting_spell:
		var spell_name = targeting_spell.name
		return "CASTING: %s | Target: %s (%s) | Distance: %d" % [spell_name, target_name, index_text, distance]
	else:
		var hit_chance = get_hit_chance()
		return "Target: %s (%s) | Distance: %d | Hit: %d%%" % [target_name, index_text, distance, hit_chance]


## Get help text for targeting controls
func get_help_text() -> String:
	if is_spell_targeting:
		return "[Tab/←→] Cycle | [Enter/C] Cast | [Esc] Cancel"
	return "[Tab/←→] Cycle | [Enter/F] Fire | [Esc] Cancel"


## Get the spell range for current spell targeting session
func get_spell_range() -> int:
	if not is_spell_targeting or not targeting_spell:
		return 0
	return targeting_spell.get_range()


## Get the spell being targeted
func get_targeting_spell():
	return targeting_spell
