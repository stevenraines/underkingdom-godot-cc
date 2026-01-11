class_name SpellCastingSystem
extends RefCounted

## SpellCastingSystem - Handles spell casting mechanics
##
## Supports different targeting modes (self, ranged, tile), spell effects
## (damage, healing, buffs), mana consumption, and failure chances.
## Integrates with the targeting system for ranged spells.

# Preload dependencies
const RangedCombatSystemClass = preload("res://systems/ranged_combat_system.gd")

## Attempt to cast a spell on a target
## caster: The entity casting the spell
## spell: The Spell object being cast
## target: The target entity (null for self-targeting spells)
## Returns a dictionary with cast results
static func cast_spell(caster, spell, target = null) -> Dictionary:
	var result = {
		"success": false,
		"damage": 0,
		"healing": 0,
		"mana_cost": 0,
		"caster_name": caster.name if caster else "Unknown",
		"target_name": "",
		"spell_name": spell.name if spell else "Unknown",
		"message": "",
		"effects_applied": [],
		"target_died": false,
		"failed": false,
		"failure_type": ""  # "fizzle", "backfire", "wild_magic"
	}

	if not spell:
		result.message = "No spell selected."
		return result

	if not caster:
		result.message = "No caster."
		return result

	# Check if caster can cast this spell
	var can_cast_result = SpellManager.can_cast(caster, spell)
	if not can_cast_result.can_cast:
		result.message = can_cast_result.reason
		return result

	# Determine target based on targeting mode
	var targeting_mode = spell.get_targeting_mode()

	match targeting_mode:
		"self":
			target = caster
		"ranged", "touch":
			if not target:
				result.message = "No target selected."
				return result
			# Validate target is in range and LOS
			var validation = _validate_target(caster, spell, target)
			if not validation.valid:
				result.message = validation.reason
				return result

	result.target_name = target.name if target else ""

	# Calculate mana cost (with potential reduction from casting focus)
	var mana_cost = spell.get_mana_cost()

	# Apply mana cost modifier from casting focus (staves)
	if caster.has_method("get_casting_bonuses"):
		var casting_bonuses = caster.get_casting_bonuses()
		var mana_modifier = casting_bonuses.get("mana_cost_modifier", 0)
		# mana_modifier is a percentage (e.g., -10 = 10% reduction)
		if mana_modifier != 0:
			var multiplier = 1.0 + (mana_modifier / 100.0)
			mana_cost = int(mana_cost * multiplier)
			mana_cost = max(1, mana_cost)  # Minimum 1 mana cost

	result.mana_cost = mana_cost

	if caster.has_method("get") and caster.get("survival"):
		caster.survival.consume_mana(mana_cost)

	# Check for spell failure (based on level difference)
	var failure_result = _check_spell_failure(caster, spell)
	if failure_result.failed:
		result.failed = true
		result.failure_type = failure_result.type
		result.message = failure_result.message
		# Mana is still consumed on failure
		return result

	# Apply spell effects
	result = _apply_spell_effects(caster, spell, target, result)

	result.success = true

	# Emit spell cast signal
	EventBus.spell_cast.emit(caster, spell, [target] if target else [], result)

	return result


## Validate a target for a ranged/touch spell
static func _validate_target(caster, spell, target) -> Dictionary:
	var result = {"valid": true, "reason": ""}

	if not target:
		result.valid = false
		result.reason = "No target."
		return result

	# Check range
	var distance = RangedCombatSystemClass.get_distance(caster.position, target.position)
	var spell_range = spell.get_range()

	if spell_range > 0 and distance > spell_range:
		result.valid = false
		result.reason = "Target is out of range."
		return result

	# Check line of sight if required
	if spell.requires_los():
		if not RangedCombatSystemClass.has_line_of_sight(caster.position, target.position):
			result.valid = false
			result.reason = "No line of sight to target."
			return result

	return result


## Check for spell failure based on level difference
static func _check_spell_failure(caster, spell) -> Dictionary:
	var result = {"failed": false, "type": "", "message": ""}

	# Get caster level
	var caster_level = 1
	if caster.has_method("get") and caster.get("level"):
		caster_level = caster.level

	var spell_level = spell.level

	# Cantrips (level 0) never fail
	if spell_level == 0:
		return result

	# Calculate failure chance based on level difference
	# Casting at or below your level is safe
	# Casting above your level is risky
	var failure_chance = 0.0

	if spell_level > caster_level:
		# Trying to cast above your level - high failure
		failure_chance = 0.25 + (spell_level - caster_level) * 0.15
	elif spell_level == caster_level:
		failure_chance = 0.05  # 5% at equal level
	elif spell_level == caster_level - 1:
		failure_chance = 0.03  # 3% one level below
	elif spell_level == caster_level - 2:
		failure_chance = 0.02  # 2% two levels below
	else:
		failure_chance = 0.01  # 1% at much lower level

	# INT bonus reduces failure chance
	var caster_int = 10
	if caster.has_method("get_effective_attribute"):
		caster_int = caster.get_effective_attribute("INT")

	var int_bonus = max(0, (caster_int - spell.get_min_intelligence())) * 0.01
	failure_chance = max(0.0, failure_chance - int_bonus)

	# Apply casting focus bonus (staves)
	if caster.has_method("get_casting_bonuses"):
		var casting_bonuses = caster.get_casting_bonuses()
		var success_modifier = casting_bonuses.get("success_modifier", 0)
		# success_modifier is a percentage (e.g., 10 = 10% reduction)
		failure_chance = max(0.0, failure_chance - (success_modifier / 100.0))

	# Roll for failure
	if randf() < failure_chance:
		result.failed = true

		# Determine failure type
		var failure_roll = randf()
		if failure_roll < 0.7:
			result.type = "fizzle"
			result.message = "The spell fizzles and dissipates harmlessly."
		elif failure_roll < 0.95:
			result.type = "backfire"
			result.message = "The spell backfires!"
			# TODO: Apply backfire damage to caster
		else:
			result.type = "wild_magic"
			result.message = "Wild magic surges!"
			# TODO: Apply random wild magic effect

	return result


## Apply the spell's effects to the target
static func _apply_spell_effects(caster, spell, target, result: Dictionary) -> Dictionary:
	var effects = spell.effects

	# Check for saving throw first
	var save_succeeded = false
	var save_result = {}
	if spell.save.get("type", "") != "":
		var dc = calculate_save_dc(caster, spell)
		save_result = attempt_saving_throw(target, spell.save.type, dc)
		save_succeeded = save_result.success
		result["save_attempted"] = true
		result["save_succeeded"] = save_succeeded
		result["save_dc"] = dc

		# If save completely negates the spell, return early
		if save_succeeded and spell.save.get("on_success", "half") == "no_effect":
			result.message = "%s resists the %s!" % [target.name if target else "Target", spell.name]
			result.effects_applied.append("resisted")
			return result

	# Handle damage effects
	if spell.is_damage_spell():
		var damage_info = spell.get_damage()
		var base_damage = damage_info.get("base", 0)
		var damage_type = damage_info.get("type", "magical")
		var scaling = damage_info.get("scaling", 0)

		# Calculate scaled damage
		var caster_level = 1
		if caster.has_method("get") and caster.get("level"):
			caster_level = caster.level

		var damage = SpellManager.calculate_spell_damage(spell, caster)

		# Apply school damage bonus from casting focus (staves)
		if caster.has_method("get_casting_bonuses"):
			var casting_bonuses = caster.get_casting_bonuses()
			var school_bonuses = casting_bonuses.get("school_bonuses", {})
			var spell_school = spell.school if "school" in spell else ""
			if spell_school != "" and school_bonuses.has(spell_school):
				damage += school_bonuses[spell_school]

		# Apply half damage if save succeeded with "half_damage" or "half"
		var save_on_success = spell.save.get("on_success", "")
		if save_succeeded and save_on_success in ["half_damage", "half"]:
			damage = damage / 2

		result.damage = damage
		result.effects_applied.append("damage")

		# Apply damage to target
		if target and target.has_method("take_damage"):
			var source = caster.name if caster else "Magic"
			target.take_damage(damage, source, spell.name)

			if not target.is_alive:
				result.target_died = true

		result.message = "%s hits %s for %d %s damage!" % [
			spell.name,
			target.name if target else "the target",
			damage,
			damage_type
		]

		# Add partial resist message if save reduced damage
		if save_succeeded and save_on_success in ["half_damage", "half"]:
			result.message += " (%s partially resists!)" % (target.name if target else "Target")

		# Handle life drain effect (heal caster for percent of damage dealt)
		if effects.has("heal_percent"):
			var heal_percent = effects.heal_percent
			var heal_amount = int(damage * heal_percent)
			if heal_amount > 0 and caster and caster.has_method("heal"):
				caster.heal(heal_amount)
				result.healing = heal_amount
				result.effects_applied.append("life_drain")
				result.message += " You recover %d health!" % heal_amount

	# Handle healing effects
	if spell.is_heal_spell():
		var heal_info = spell.get_heal()
		var base_heal = heal_info.get("base", 0)

		# Calculate scaled healing
		var healing = SpellManager.calculate_spell_healing(spell, caster)
		result.healing = healing
		result.effects_applied.append("healing")

		# Apply healing to target
		if target and target.has_method("heal"):
			target.heal(healing)

		result.message = "%s restores %d health to %s." % [
			spell.name,
			healing,
			target.name if target else "the target"
		]

	# Handle buff effects
	if spell.is_buff_spell():
		var buff_info = spell.get_buff()
		result.effects_applied.append("buff")

		# Calculate duration
		var duration = SpellManager.calculate_spell_duration(spell, caster)

		# Build the effect dictionary for the new active effects system
		var effect = {
			"id": spell.id + "_buff",
			"type": "buff",
			"source_spell": spell.id,
			"remaining_duration": duration,
			"modifiers": {}
		}

		# Add stat modifiers from buff_info
		if buff_info.has("armor_bonus"):
			effect["armor_bonus"] = buff_info.armor_bonus
		if buff_info.has("str_bonus"):
			effect.modifiers["STR"] = buff_info.str_bonus
		if buff_info.has("dex_bonus"):
			effect.modifiers["DEX"] = buff_info.dex_bonus
		if buff_info.has("con_bonus"):
			effect.modifiers["CON"] = buff_info.con_bonus
		if buff_info.has("int_bonus"):
			effect.modifiers["INT"] = buff_info.int_bonus
		if buff_info.has("wis_bonus"):
			effect.modifiers["WIS"] = buff_info.wis_bonus
		if buff_info.has("cha_bonus"):
			effect.modifiers["CHA"] = buff_info.cha_bonus

		# Apply effect to target
		if target and target.has_method("add_magical_effect"):
			target.add_magical_effect(effect)
			result.message = "%s grants %s a magical buff for %d turns." % [
				spell.name,
				target.name if target else "the target",
				duration
			]
		else:
			result.message = "%s enhances %s!" % [
				spell.name,
				target.name if target else "the target"
			]

	# Handle debuff effects
	if spell.is_debuff_spell():
		var debuff_info = spell.get_debuff()
		result.effects_applied.append("debuff")

		# Calculate duration
		var duration = SpellManager.calculate_spell_duration(spell, caster)

		# Apply half duration if save succeeded with "half_duration"
		var save_on_success = spell.save.get("on_success", "")
		if save_succeeded and save_on_success == "half_duration":
			duration = duration / 2

		# Build the debuff effect dictionary
		var effect = {
			"id": spell.id + "_debuff",
			"type": "debuff",
			"source_spell": spell.id,
			"remaining_duration": duration,
			"modifiers": {}
		}

		# Add stat penalties from debuff_info (stored as negatives)
		if debuff_info.has("str_penalty"):
			effect.modifiers["STR"] = -debuff_info.str_penalty
		if debuff_info.has("dex_penalty"):
			effect.modifiers["DEX"] = -debuff_info.dex_penalty
		if debuff_info.has("con_penalty"):
			effect.modifiers["CON"] = -debuff_info.con_penalty
		if debuff_info.has("int_penalty"):
			effect.modifiers["INT"] = -debuff_info.int_penalty
		if debuff_info.has("wis_penalty"):
			effect.modifiers["WIS"] = -debuff_info.wis_penalty
		if debuff_info.has("cha_penalty"):
			effect.modifiers["CHA"] = -debuff_info.cha_penalty
		if debuff_info.has("armor_penalty"):
			effect["armor_bonus"] = -debuff_info.armor_penalty

		# Apply effect to target
		if target and target.has_method("add_magical_effect"):
			target.add_magical_effect(effect)
			var msg = "%s afflicts %s with a debuff for %d turns." % [
				spell.name,
				target.name if target else "the target",
				duration
			]
			# Add partial resist message if save reduced duration
			if save_succeeded and save_on_success == "half_duration":
				msg += " (%s partially resists!)" % (target.name if target else "Target")
			result.message = msg
		else:
			result.message = "%s weakens %s!" % [
				spell.name,
				target.name if target else "the target"
			]

	# Handle light effect (special case for Light cantrip)
	if effects.has("light"):
		var light_info = effects.light
		result.effects_applied.append("light")
		result.message = "A soft light begins to glow."
		# TODO: Integrate with lighting system

	# Use cast_message if no specific message was set
	if result.message == "" and spell.cast_message != "":
		result.message = spell.cast_message
	elif result.message == "":
		result.message = "You cast %s." % spell.name

	return result


## Calculate the saving throw DC for a spell
## DC = 10 + Spell Level + (Caster INT modifier)
static func calculate_save_dc(caster, spell) -> int:
	var caster_int = 10
	if caster and caster.has_method("get_effective_attribute"):
		caster_int = caster.get_effective_attribute("INT")

	# INT modifier is (INT - 10) / 2
	var int_mod = (caster_int - 10) / 2
	return 10 + spell.level + int_mod


## Attempt a saving throw against a spell
## Returns true if the save succeeds (target resists)
static func attempt_saving_throw(target, save_type: String, dc: int) -> Dictionary:
	var roll = randi_range(1, 20)
	var attribute_mod = 0

	if target and target.has_method("get_effective_attribute"):
		var attr_value = target.get_effective_attribute(save_type)
		attribute_mod = (attr_value - 10) / 2

	var total = roll + attribute_mod
	var success = total >= dc

	return {
		"success": success,
		"roll": roll,
		"modifier": attribute_mod,
		"total": total,
		"dc": dc
	}


## Get valid targets for a ranged spell
## Returns an array of entities that can be targeted
static func get_valid_spell_targets(caster, spell) -> Array[Entity]:
	var targets: Array[Entity] = []

	var targeting_mode = spell.get_targeting_mode()

	if targeting_mode == "self":
		return targets  # Self spells don't need target selection

	var spell_range = spell.get_range()
	var requires_los = spell.requires_los()

	# Get all entities within range
	for entity in EntityManager.entities:
		if entity == caster:
			continue

		if not entity.is_alive:
			continue

		# Check range
		var distance = RangedCombatSystemClass.get_distance(caster.position, entity.position)
		if spell_range > 0 and distance > spell_range:
			continue

		# Check line of sight
		if requires_los:
			if not RangedCombatSystemClass.has_line_of_sight(caster.position, entity.position):
				continue

		# For offensive spells, only target enemies
		if spell.is_damage_spell():
			if entity is Enemy:
				targets.append(entity)
		# For healing/buff spells, could target allies (just player for now)
		elif spell.is_heal_spell() or spell.is_buff_spell():
			# For now, only allow targeting self
			pass
		else:
			# Other spells can target any entity
			targets.append(entity)

	return targets


## Check if caster can currently cast any spells
static func can_cast_any_spell(caster) -> bool:
	if not caster:
		return false

	# Check if caster has a spellbook
	if caster.has_method("has_spellbook") and not caster.has_spellbook():
		return false

	# Check if caster knows any spells
	if caster.has_method("get_known_spells"):
		var known = caster.get_known_spells()
		return known.size() > 0

	return false
