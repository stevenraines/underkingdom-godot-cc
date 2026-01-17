class_name SpellCastingSystem
extends RefCounted

## SpellCastingSystem - Handles spell casting mechanics
##
## Supports different targeting modes (self, ranged, tile), spell effects
## (damage, healing, buffs), mana consumption, and failure chances.
## Integrates with the targeting system for ranged spells.

# Preload dependencies
const RangedCombatSystemClass = preload("res://systems/ranged_combat_system.gd")
const ElementalSystemClass = preload("res://systems/elemental_system.gd")

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

		# Handle wild magic if that's the failure type
		if failure_result.type == "wild_magic":
			const WildMagicClass = preload("res://systems/wild_magic.gd")
			WildMagicClass.trigger_wild_magic(caster, spell)

		# Mana is still consumed on failure
		return result

	# Apply spell effects
	result = _apply_spell_effects(caster, spell, target, result)

	result.success = true

	# Handle concentration spells - caster must maintain concentration
	if spell.concentration and caster.has_method("start_concentration"):
		caster.start_concentration(spell.id)
		result["concentration_started"] = true

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

	# Apply racial spell success bonus (e.g., Gnome Arcane Affinity)
	if "spell_success_bonus" in caster:
		var racial_bonus = caster.spell_success_bonus / 100.0
		failure_chance = max(0.0, failure_chance - racial_bonus)

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
			result.message = "%s resists the %s! %s" % [target.name if target else "Target", spell.name, save_result.get("roll_info", "")]
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

		# Apply elemental damage calculation if target exists
		var elemental_result = {}
		if target:
			elemental_result = ElementalSystemClass.calculate_elemental_damage(damage, damage_type, target, caster)
			damage = elemental_result.get("final_damage", damage)

		result.damage = damage
		result.effects_applied.append("damage")

		# Apply damage to target
		if target and target.has_method("take_damage"):
			var source = caster.name if caster else "Magic"

			# Skip take_damage if elemental system already healed (necrotic vs undead)
			if not elemental_result.get("healed", false):
				target.take_damage(damage, source, spell.name)

			if not target.is_alive:
				result.target_died = true

		# Generate message based on elemental result
		if elemental_result.get("message", "") != "":
			result.message = elemental_result.message
		elif elemental_result.get("immune", false):
			result.message = "%s is immune to %s!" % [target.name if target else "Target", damage_type]
		elif elemental_result.get("healed", false):
			result.message = "%s absorbs the %s energy!" % [target.name if target else "Target", damage_type]
		else:
			result.message = "%s hits %s for %d %s damage!" % [
				spell.name,
				target.name if target else "the target",
				damage,
				damage_type
			]

			# Add elemental feedback
			if elemental_result.get("resisted", false):
				result.message += " (resisted)"
			elif elemental_result.get("vulnerable", false):
				result.message += " (vulnerable!)"

		# Add partial resist message if save reduced damage
		if save_succeeded and save_on_success in ["half_damage", "half"]:
			result.message += " (%s partially resists!)" % (target.name if target else "Target")

		# Emit elemental damage signal
		if target:
			EventBus.elemental_damage_applied.emit(target, damage_type, damage, elemental_result.get("resisted", false))

		# Check for environmental combos
		if target and "position" in target:
			ElementalSystemClass.apply_environmental_combo(target.position, damage_type, caster)

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
		if buff_info.has("light_radius_bonus"):
			effect["light_radius_bonus"] = buff_info.light_radius_bonus

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

	# Handle elemental resistance effects
	if effects.has("elemental_resistance"):
		var resist_info = effects.elemental_resistance
		var element = resist_info.get("element", "fire")
		var modifier = resist_info.get("modifier", -50)
		var duration = SpellManager.calculate_spell_duration(spell, caster)

		var effect = {
			"id": spell.id + "_resistance",
			"type": "elemental_resistance",
			"element": element,
			"modifier": modifier,
			"remaining_duration": duration,
			"source_spell": spell.id
		}

		if target and target.has_method("add_magical_effect"):
			target.add_magical_effect(effect)
			result.effects_applied.append("elemental_resistance")
			var resist_percent = abs(modifier)
			result.message = "%s gains %d%% resistance to %s for %d turns." % [
				target.name if target else "Target",
				resist_percent,
				element,
				duration
			]
			EventBus.resistance_changed.emit(target, element, target.get_elemental_resistance(element) if target.has_method("get_elemental_resistance") else modifier)

	# Handle elemental resistance all (resist elements spell)
	if effects.has("elemental_resistance_all"):
		var resist_info = effects.elemental_resistance_all
		var modifier = resist_info.get("modifier", -25)
		var duration = SpellManager.calculate_spell_duration(spell, caster)

		var elements = ["fire", "ice", "lightning", "poison", "necrotic", "holy"]
		for element in elements:
			var effect = {
				"id": spell.id + "_" + element + "_resistance",
				"type": "elemental_resistance",
				"element": element,
				"modifier": modifier,
				"remaining_duration": duration,
				"source_spell": spell.id
			}

			if target and target.has_method("add_magical_effect"):
				target.add_magical_effect(effect)

		result.effects_applied.append("elemental_resistance_all")
		var resist_percent = abs(modifier)
		result.message = "%s gains %d%% resistance to all elements for %d turns." % [
			target.name if target else "Target",
			resist_percent,
			duration
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

	# Handle DoT (Damage over Time) effects
	if effects.has("dot"):
		var dot_info = effects.dot
		var caster_level = caster.level if caster and "level" in caster else 1

		# Calculate scaled damage
		var base_damage = dot_info.get("damage_per_turn", 3)
		var damage_scaling = dot_info.get("damage_scaling", 0)
		var level_diff = max(0, caster_level - spell.level)
		var scaled_damage = base_damage + (damage_scaling * level_diff)

		# Calculate scaled duration
		var base_duration = dot_info.get("duration", 10)
		var duration_scaling = dot_info.get("duration_scaling", 0)
		var scaled_duration = base_duration + (duration_scaling * level_diff)

		# Apply save for duration reduction
		var dot_save_on_success = spell.save.get("on_success", "")
		if save_succeeded and dot_save_on_success == "half_duration":
			scaled_duration = scaled_duration / 2

		result.effects_applied.append("dot_" + dot_info.get("type", "unknown"))

		# Create DoT effect
		var effect = {
			"id": spell.id + "_dot",
			"name": spell.name,
			"type": "dot",
			"dot_type": dot_info.get("type", "poison"),
			"damage_per_turn": scaled_damage,
			"remaining_duration": scaled_duration,
			"source": caster
		}

		# Apply effect to target
		if target and target.has_method("add_magical_effect"):
			target.add_magical_effect(effect)
			var dot_type_name = dot_info.get("type", "poison").capitalize()
			var msg = "%s afflicts %s with %s for %d turns (%d damage/turn)." % [
				spell.name,
				target.name if target else "the target",
				dot_type_name,
				scaled_duration,
				scaled_damage
			]
			# Add partial resist message if save reduced duration
			if save_succeeded and dot_save_on_success == "half_duration":
				msg += " (%s partially resists!)" % (target.name if target else "Target")
			result.message = msg
		else:
			result.message = "Poison seeps into the target!"

	# Handle light effect (special case for Light cantrip)
	if effects.has("light"):
		var light_info = effects.light
		result.effects_applied.append("light")
		result.message = "A soft light begins to glow."
		# TODO: Integrate with lighting system

	# Handle summon effects
	if effects.has("summon"):
		var summon_data = effects.summon
		result = _apply_summon_effect(caster, spell, summon_data, result)

	# Handle terrain change effects
	if effects.has("terrain_change"):
		result = _apply_terrain_change(caster, spell, target, effects.terrain_change, result)

	# Handle mind effects (charm, fear, calm, enrage)
	if effects.has("mind_effect"):
		var mind_data = effects.mind_effect
		var effect_type = mind_data.get("type", "") if mind_data is Dictionary else str(mind_data)
		result = _apply_mind_effect(caster, spell, target, effect_type, result)

	# Handle remove curse effect
	if effects.has("remove_curse"):
		const CurseSystemClass = preload("res://systems/curse_system.gd")
		var curses_removed = CurseSystemClass.remove_all_curses(target)
		result.effects_applied.append("remove_curse")
		if curses_removed > 0:
			result.message = "The curses are lifted!"
		else:
			result.message = "No curses to remove."

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

	# Build roll info string
	var roll_info = _format_save_roll(roll, attribute_mod, save_type, total, dc)

	return {
		"success": success,
		"roll": roll,
		"modifier": attribute_mod,
		"total": total,
		"dc": dc,
		"roll_info": roll_info
	}


## Format saving throw roll breakdown for display (grey colored)
## Returns: "[X (Roll) +Y (SAVE) = total vs DC N]"
static func _format_save_roll(dice_roll: int, modifier: int, save_type: String, total: int, dc: int) -> String:
	var parts: Array[String] = ["%d (Roll)" % dice_roll]
	parts.append("%+d (%s)" % [modifier, save_type])
	parts.append("= %d vs DC %d" % [total, dc])
	return "[color=gray][%s][/color]" % " ".join(parts)


## Get valid targets for a ranged spell
## Returns an array of entities that can be targeted
static func get_valid_spell_targets(caster, spell) -> Array[Entity]:
	const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")

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

		# Check if target is currently visible (in FOV and illuminated)
		# This prevents targeting enemies behind walls or in unexplored areas
		if not FogOfWarSystemClass.is_visible(entity.position):
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


## Apply summon effect from a spell
## Creates a summoned creature near the caster
static func _apply_summon_effect(caster, spell, summon_data: Dictionary, result: Dictionary) -> Dictionary:
	const SummonedCreatureClass = preload("res://entities/summoned_creature.gd")

	var creature_id = summon_data.get("creature_id", "")
	if creature_id == "":
		result.message = "Invalid summon spell."
		return result

	# Get creature data
	var creature_data = EntityManager.get_enemy_data(creature_id)
	if creature_data.is_empty():
		result.message = "Unknown creature type."
		return result

	# Calculate duration
	var caster_level = caster.level if "level" in caster else 1
	var base_duration = summon_data.get("base_duration", 50)
	var duration_per_level = summon_data.get("duration_per_level", 10)
	var duration = base_duration + (caster_level * duration_per_level)

	# Create the summoned creature
	var summon = SummonedCreatureClass.create_summon(caster, creature_data, duration)
	summon.scale_for_caster_level(caster_level)

	# Find a valid spawn position near the caster
	var spawn_pos = _find_summon_spawn_position(caster.position)
	if spawn_pos == Vector2i(-999, -999):
		result.message = "No room to summon a creature."
		return result

	summon.position = spawn_pos

	# Add to entity manager
	EntityManager.entities.append(summon)

	# Add to caster's summons (if player)
	if caster.has_method("add_summon"):
		caster.add_summon(summon)

	result.effects_applied.append("summon")
	result.message = "You summon a %s!" % summon.name

	return result


## Find a valid position near the caster to spawn a summon
static func _find_summon_spawn_position(caster_pos: Vector2i) -> Vector2i:
	# Check adjacent tiles first, then further out
	var offsets = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
		Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)
	]

	for offset in offsets:
		var check_pos = caster_pos + offset
		if MapManager.current_map and MapManager.current_map.is_walkable(check_pos):
			# Check no entity there
			if not EntityManager.get_blocking_entity_at(check_pos):
				return check_pos

	return Vector2i(-999, -999)  # No valid position found


## Apply terrain change effect from a spell
## Modifies a tile's terrain type
static func _apply_terrain_change(caster, spell, target, terrain_data: Dictionary, result: Dictionary) -> Dictionary:
	if not target:
		result.message = "No target for terrain spell."
		return result

	# Get target position (either from entity or direct position)
	var target_pos: Vector2i
	if target is Vector2i:
		target_pos = target
	elif target.has_method("get") and "position" in target:
		target_pos = target.position
	else:
		result.message = "Invalid target."
		return result

	if not MapManager.current_map:
		result.message = "No map loaded."
		return result

	var current_tile = MapManager.current_map.get_tile(target_pos)
	if not current_tile:
		result.message = "Invalid tile."
		return result

	var from_type = terrain_data.get("from_type", "any")
	var to_type = terrain_data.get("to_type", "")

	# Validate terrain change
	if not _can_change_terrain(current_tile, from_type):
		result.message = "This terrain cannot be changed."
		# Refund mana
		if caster and caster.get("survival"):
			caster.survival.mana += spell.get_mana_cost()
		return result

	# Check if tile is occupied (can't create wall on occupied tile)
	if to_type == "wall":
		var entity_at = EntityManager.get_blocking_entity_at(target_pos)
		if entity_at:
			result.message = "Something is in the way."
			if caster and caster.get("survival"):
				caster.survival.mana += spell.get_mana_cost()
			return result

	# Apply the terrain change
	_apply_tile_type_change(target_pos, to_type)
	EventBus.terrain_changed.emit(target_pos, to_type)

	result.effects_applied.append("terrain_change")
	result.message = spell.cast_message if spell.cast_message != "" else "The terrain changes!"

	return result


## Check if terrain can be changed
static func _can_change_terrain(tile, from_type: String) -> bool:
	match from_type:
		"wall":
			return tile.tile_type == "wall"
		"floor":
			return tile.walkable and tile.tile_type != "water"
		"any":
			return true
		_:
			return tile.tile_type == from_type


## Apply a tile type change to the map
static func _apply_tile_type_change(pos: Vector2i, new_type: String) -> void:
	if not MapManager.current_map:
		return

	var tile = MapManager.current_map.get_tile(pos)
	if not tile:
		return

	# Update tile properties based on new type
	match new_type:
		"wall":
			tile.tile_type = "wall"
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "#"
		"floor":
			tile.tile_type = "floor"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "."
		"mud":
			tile.tile_type = "mud"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "~"
		"water":
			tile.tile_type = "water"
			tile.walkable = false
			tile.transparent = true
			tile.ascii_char = "~"
			tile.harvestable_resource_id = "water"
		_:
			# Default to floor-like behavior
			tile.tile_type = new_type
			tile.walkable = true
			tile.transparent = true

	# Emit tile changed event for rendering update
	EventBus.tile_changed.emit(pos)


## Get all entities within an AOE radius
static func get_entities_in_aoe(center: Vector2i, radius: int, shape: String = "circle") -> Array:
	var entities: Array = []

	for entity in EntityManager.entities:
		if not entity.is_alive:
			continue

		var distance = abs(entity.position.x - center.x) + abs(entity.position.y - center.y)

		match shape:
			"circle":
				# Use Chebyshev distance for circle approximation
				var dx = abs(entity.position.x - center.x)
				var dy = abs(entity.position.y - center.y)
				if max(dx, dy) <= radius:
					entities.append(entity)
			"square":
				if distance <= radius * 2:
					entities.append(entity)
			_:
				if distance <= radius:
					entities.append(entity)

	return entities


## Apply AOE damage spell
static func apply_aoe_damage(caster, spell, center: Vector2i, result: Dictionary) -> Dictionary:
	var radius = spell.targeting.get("aoe_radius", 2)
	var shape = spell.targeting.get("aoe_shape", "circle")
	var entities = get_entities_in_aoe(center, radius, shape)

	var spell_mgr = Engine.get_main_loop().root.get_node("SpellManager")
	var damage = spell_mgr.calculate_spell_damage(spell, caster)
	var damage_type = spell.effects.damage.get("type", "magical") if spell.effects.has("damage") else "magical"

	result["targets_hit"] = 0
	result["total_damage"] = 0

	for entity in entities:
		# Skip caster (self-protection)
		if entity == caster:
			continue

		# Check for friendly fire on summons
		var is_friendly = false
		if caster.has_method("get") and "active_summons" in caster:
			is_friendly = entity in caster.active_summons

		# Apply damage
		entity.take_damage(damage, caster.name if caster else "AOE Spell", spell.name)
		result.targets_hit += 1
		result.total_damage += damage

		if is_friendly:
			EventBus.message_logged.emit("Your %s is caught in the blast!" % entity.name, Color.ORANGE)

		if not entity.is_alive:
			result["kills"] = result.get("kills", 0) + 1

	if result.targets_hit > 0:
		result.message = "%s hits %d targets for %d %s damage!" % [spell.name, result.targets_hit, damage, damage_type]
	else:
		result.message = "%s explodes but hits nothing." % spell.name

	result.effects_applied.append("aoe_damage")
	return result


## Apply mind effect (charm, fear, calm, enrage)
static func _apply_mind_effect(caster, spell, target, effect_type: String, result: Dictionary) -> Dictionary:
	if not target:
		result.message = "No target for mind spell."
		return result

	# Check mind control immunity
	if target.has_method("can_be_mind_controlled") and not target.can_be_mind_controlled():
		result.message = "%s is immune to mind control." % target.name
		# Refund mana
		if caster and caster.get("survival"):
			caster.survival.mana += spell.get_mana_cost()
		return result

	# Calculate save DC with mind save modifier
	var dc = calculate_save_dc(caster, spell)
	var save_mod = 0
	if target.has_method("get_mind_save_modifier"):
		save_mod = target.get_mind_save_modifier()

	# Attempt saving throw (with modifier)
	var adjusted_dc = dc - save_mod
	var save_result = attempt_saving_throw(target, spell.save.get("type", "WIS"), adjusted_dc)

	if save_result.success:
		result.message = "%s resists the %s!" % [target.name, spell.name]
		return result

	# Calculate duration
	var spell_mgr = Engine.get_main_loop().root.get_node("SpellManager")
	var duration = spell_mgr.calculate_spell_duration(spell, caster)

	# Apply the specific mind effect
	match effect_type:
		"charm":
			result = _apply_charm_effect(caster, spell, target, duration, result)
		"fear":
			result = _apply_fear_effect(caster, spell, target, duration, result)
		"calm":
			result = _apply_calm_effect(caster, spell, target, duration, result)
		"enrage":
			result = _apply_enrage_effect(caster, spell, target, duration, result)
		_:
			result.message = "Unknown mind effect."

	return result


## Apply charm effect - target fights for caster
static func _apply_charm_effect(caster, spell, target, duration: int, result: Dictionary) -> Dictionary:
	var effect = {
		"id": "charm_effect",
		"type": "charm",
		"original_faction": target.faction,
		"remaining_duration": duration,
		"source_spell": spell.id
	}

	target.faction = "player"
	target.ai_state = "normal"
	target.add_magical_effect(effect)

	# Charm requires concentration
	if spell.concentration and caster.has_method("start_concentration"):
		caster.start_concentration(spell.id)

	result.effects_applied.append("charm")
	result.message = "%s is now under your control!" % target.name
	return result


## Apply fear effect - target flees from caster
static func _apply_fear_effect(caster, spell, target, duration: int, result: Dictionary) -> Dictionary:
	var effect = {
		"id": "fear_effect",
		"type": "fear",
		"flee_from": caster.position,
		"remaining_duration": duration,
		"source_spell": spell.id
	}

	target.ai_state = "fleeing"
	target.add_magical_effect(effect)

	result.effects_applied.append("fear")
	result.message = "%s flees in terror!" % target.name
	return result


## Apply calm effect - target becomes neutral
static func _apply_calm_effect(caster, spell, target, duration: int, result: Dictionary) -> Dictionary:
	var effect = {
		"id": "calm_effect",
		"type": "calm",
		"original_faction": target.faction,
		"remaining_duration": duration,
		"source_spell": spell.id
	}

	target.faction = "neutral"
	target.ai_state = "idle"
	target.add_magical_effect(effect)

	result.effects_applied.append("calm")
	result.message = "%s becomes calm and non-hostile." % target.name
	return result


## Apply enrage effect - target attacks everything
static func _apply_enrage_effect(caster, spell, target, duration: int, result: Dictionary) -> Dictionary:
	var effect = {
		"id": "enrage_effect",
		"type": "enrage",
		"original_faction": target.faction,
		"remaining_duration": duration,
		"source_spell": spell.id
	}

	target.faction = "hostile_to_all"
	target.ai_state = "berserk"
	target.add_magical_effect(effect)

	result.effects_applied.append("enrage")
	result.message = "%s flies into a rage!" % target.name
	return result
