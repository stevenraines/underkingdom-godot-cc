class_name CombatSystem
extends RefCounted

## CombatSystem - Centralized combat resolution logic
##
## Handles attack resolution, damage calculation, and combat formulas.
## All combat in the game flows through this system.

const ElementalSystemClass = preload("res://systems/elemental_system.gd")

## Attempt an attack from attacker to defender
## Returns a dictionary with attack results
static func attempt_attack(attacker: Entity, defender: Entity) -> Dictionary:
	var result = {
		"hit": false,
		"damage": 0,
		"attacker_name": attacker.name,
		"defender_name": defender.name,
		"defender_died": false,
		"critical": false,
		"roll": 0,
		"hit_chance": 0,
		"weapon_name": "",
		"damage_type": "bludgeoning",
		"secondary_damage": 0,
		"secondary_damage_type": "",
		"resisted": false,
		"vulnerable": false
	}

	# Get equipped weapon if attacker has inventory
	var weapon = null
	if attacker.has_method("get_component") or "inventory" in attacker:
		var inventory = attacker.get("inventory")
		if inventory and inventory.equipment.get("main_hand"):
			weapon = inventory.equipment["main_hand"]
			result.weapon_name = weapon.name
			result.damage_type = weapon.damage_type if weapon.damage_type != "" else "bludgeoning"
			result.secondary_damage_type = weapon.secondary_damage_type if weapon.secondary_damage_type != "" else ""

	# Calculate hit chance with evasion breakdown for logging
	var accuracy = get_accuracy(attacker)
	var evasion_data = get_evasion_with_breakdown(defender)
	var hit_chance = clampi(accuracy - evasion_data.total, 5, 95)  # Always 5-95% chance

	result.hit_chance = hit_chance

	# Roll for hit (1-100)
	var roll = randi_range(1, 100)
	result.roll = roll

	# Check for Lucky trait reroll on miss (Halfling)
	if roll > hit_chance:
		if attacker.has_method("has_racial_trait") and attacker.has_racial_trait("lucky"):
			if attacker.has_method("can_use_racial_ability") and attacker.can_use_racial_ability("lucky"):
				# Reroll the attack
				var reroll = randi_range(1, 100)
				attacker.use_racial_ability("lucky")
				EventBus.message_logged.emit("[color=yellow]Lucky! Rerolling attack... (%d -> %d)[/color]" % [roll, reroll])
				roll = reroll
				result.roll = roll
				result.lucky_reroll = true

	# Check if Nimble (evasion bonus) made the difference
	if roll > hit_chance and evasion_data.racial_bonus > 0:
		# Would have hit without racial bonus?
		var hit_chance_without_bonus = clampi(accuracy - evasion_data.base, 5, 95)
		if roll <= hit_chance_without_bonus:
			EventBus.message_logged.emit("[color=cyan]Nimble! Your agility helps you dodge the attack![/color]")

	if roll <= hit_chance:
		result.hit = true

		# Calculate and apply damage with damage types
		var damage_result = calculate_damage_with_types(attacker, defender, weapon)
		result.damage = damage_result.primary_damage
		result.secondary_damage = damage_result.secondary_damage
		result.resisted = damage_result.resisted
		result.vulnerable = damage_result.vulnerable

		# Total damage is primary + secondary
		var total_damage = result.damage + result.secondary_damage

		# Apply damage to defender
		# Pass source and method for death tracking
		var source = attacker.name if attacker else "Unknown"
		var natural_weapon = attacker.get("natural_weapon") if attacker else null
		var method = result.weapon_name if result.weapon_name != "" else (natural_weapon if natural_weapon else "")

		if defender.has_method("take_damage") and total_damage > 0:
			defender.take_damage(total_damage, source, method)

		# Check if defender died
		if not defender.is_alive:
			result.defender_died = true

	# Emit attack signal
	EventBus.attack_performed.emit(attacker, defender, result)

	return result

## Calculate attacker's accuracy
## Formula: 50% + (DEX × 2)% + weapon_skill_bonus%
static func get_accuracy(entity: Entity) -> int:
	var dex = entity.attributes.get("DEX", 10)
	var base_accuracy = 50 + (dex * 2)

	# Add weapon skill bonus if entity has the method
	var skill_bonus = 0
	if entity.has_method("get_weapon_skill_bonus"):
		skill_bonus = entity.get_weapon_skill_bonus()

	return base_accuracy + skill_bonus

## Calculate defender's evasion
## Formula: 5% + (DEX × 1)% + racial bonuses
## Returns dictionary with total and bonus breakdown for logging
static func get_evasion_with_breakdown(entity: Entity) -> Dictionary:
	var dex = entity.attributes.get("DEX", 10)
	var base_evasion = 5 + dex
	var racial_bonus = 0

	# Add racial evasion bonus (e.g., Halfling Nimble)
	if entity.has_method("get_racial_evasion_bonus"):
		racial_bonus = entity.get_racial_evasion_bonus()

	return {
		"total": base_evasion + racial_bonus,
		"base": base_evasion,
		"racial_bonus": racial_bonus
	}


## Calculate defender's evasion (simple version for backwards compatibility)
## Formula: 5% + (DEX × 1)% + racial bonuses
static func get_evasion(entity: Entity) -> int:
	return get_evasion_with_breakdown(entity).total

## Calculate damage for an attack (legacy - used for backwards compatibility)
## Formula: Base Damage + STR modifier - Armor
## STR modifier: +1 per 2 STR above 10
static func calculate_damage(attacker: Entity, defender: Entity) -> int:
	# Get weapon damage - check if attacker has get_weapon_damage method (Player)
	var base_damage = attacker.base_damage
	if attacker.has_method("get_weapon_damage"):
		base_damage = attacker.get_weapon_damage()

	# STR modifier: +1 per 2 points above 10
	var str_stat = attacker.get_effective_attribute("STR") if attacker.has_method("get_effective_attribute") else attacker.attributes.get("STR", 10)
	@warning_ignore("integer_division")
	var str_modifier = (str_stat - 10) / 2

	# Armor reduction - check if defender has get_total_armor method (Player)
	var armor = defender.armor
	if defender.has_method("get_total_armor"):
		armor = defender.get_total_armor()

	# Calculate total damage (minimum 1)
	var damage = maxi(1, base_damage + str_modifier - armor)

	return damage


## Calculate damage with damage type system
## Returns dictionary with primary_damage, secondary_damage, resisted, vulnerable flags
static func calculate_damage_with_types(attacker: Entity, defender: Entity, weapon) -> Dictionary:
	var result = {
		"primary_damage": 0,
		"secondary_damage": 0,
		"resisted": false,
		"vulnerable": false
	}

	# Get base weapon damage
	var base_damage = attacker.base_damage
	if attacker.has_method("get_weapon_damage"):
		base_damage = attacker.get_weapon_damage()

	# STR modifier: +1 per 2 points above 10
	var str_stat = attacker.get_effective_attribute("STR") if attacker.has_method("get_effective_attribute") else attacker.attributes.get("STR", 10)
	@warning_ignore("integer_division")
	var str_modifier = (str_stat - 10) / 2

	# Get armor - check if defender has get_total_armor method (Player)
	var armor = defender.armor
	if defender.has_method("get_total_armor"):
		armor = defender.get_total_armor()

	# Determine damage type
	var damage_type = "bludgeoning"  # Default for unarmed
	var secondary_damage_type = ""
	var secondary_damage_bonus = 0

	if weapon:
		damage_type = weapon.damage_type if weapon.damage_type != "" else "bludgeoning"
		secondary_damage_type = weapon.secondary_damage_type if weapon.secondary_damage_type != "" else ""
		secondary_damage_bonus = weapon.secondary_damage_bonus if weapon.secondary_damage_bonus > 0 else 0

	# Apply armor based on damage type
	# Piercing weapons bypass 50% of armor
	var effective_armor = armor
	if damage_type == "piercing":
		@warning_ignore("integer_division")
		effective_armor = armor / 2

	# Calculate raw physical damage before resistance
	var raw_damage = maxi(0, base_damage + str_modifier - effective_armor)

	# Add class melee damage bonus (e.g., Barbarian Rage when low HP)
	if attacker.has_method("get_class_melee_bonus"):
		var melee_bonus = attacker.get_class_melee_bonus()
		if melee_bonus > 0:
			raw_damage += melee_bonus
			EventBus.message_logged.emit("[color=red]Rage: +%d melee damage![/color]" % melee_bonus)

	# Apply damage type resistance/vulnerability for primary damage
	var primary_result = ElementalSystemClass.calculate_elemental_damage(raw_damage, damage_type, defender, attacker)
	result.primary_damage = primary_result.final_damage

	# Track resistance/vulnerability for messaging
	if primary_result.resisted or primary_result.immune:
		result.resisted = true
	if primary_result.vulnerable:
		result.vulnerable = true

	# Handle secondary damage type (e.g., fire on an enchanted sword)
	if secondary_damage_type != "" and secondary_damage_bonus > 0:
		# Secondary damage doesn't get STR modifier or armor reduction
		var secondary_result = ElementalSystemClass.calculate_elemental_damage(secondary_damage_bonus, secondary_damage_type, defender, attacker)
		result.secondary_damage = secondary_result.final_damage

		if secondary_result.resisted or secondary_result.immune:
			result.resisted = true
		if secondary_result.vulnerable:
			result.vulnerable = true

	# Ensure minimum 1 damage if we hit (unless fully immune)
	if result.primary_damage == 0 and result.secondary_damage == 0 and not result.resisted:
		result.primary_damage = 1

	return result

## Check if two positions are adjacent (including diagonals)
static func are_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var diff = pos2 - pos1
	return abs(diff.x) <= 1 and abs(diff.y) <= 1 and diff != Vector2i.ZERO

## Check if two positions are cardinally adjacent (not diagonal)
static func are_cardinally_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var diff = pos2 - pos1
	return (abs(diff.x) + abs(diff.y)) == 1

## Get a combat message based on attack result
static func get_attack_message(result: Dictionary, is_player_attacker: bool) -> String:
	var attacker = result.attacker_name
	var defender = result.defender_name
	var weapon = result.get("weapon_name", "")

	# Build weapon phrase for player attacks
	var weapon_phrase = ""
	if is_player_attacker and weapon != "":
		weapon_phrase = " with your %s" % weapon

	# Build roll info string (grey colored)
	var roll_info = _format_attack_roll(result.roll, result.hit_chance)

	# Get resistance/vulnerability cue
	var cue = _get_resistance_cue(result, is_player_attacker)

	if result.hit:
		if result.defender_died:
			if is_player_attacker:
				return "You kill the %s%s! %s" % [defender, weapon_phrase, roll_info]
			else:
				return "The %s kills you!" % attacker
		else:
			if is_player_attacker:
				var base_msg = "You hit the %s%s for %d damage. %s" % [defender, weapon_phrase, result.damage, roll_info]
				return base_msg + cue
			else:
				var base_msg = "The %s hits you for %d damage." % [attacker, result.damage]
				return base_msg + cue
	else:
		if is_player_attacker:
			return "You miss the %s%s. %s" % [defender, weapon_phrase, roll_info]
		else:
			return "The %s misses you." % attacker


## Get a flavorful cue for resistance, immunity, or vulnerability
## Returns empty string if no special resistance applies
static func _get_resistance_cue(result: Dictionary, is_player_attacker: bool) -> String:
	var total_damage = result.get("damage", 0) + result.get("secondary_damage", 0)
	var resisted = result.get("resisted", false)
	var vulnerable = result.get("vulnerable", false)

	# Immunity - no damage dealt despite a hit
	if total_damage == 0 and resisted:
		if is_player_attacker:
			return " [color=gray]Your attack seems to have no effect![/color]"
		else:
			return " [color=cyan]The attack has no effect on you![/color]"

	# Resistance - reduced damage
	if resisted:
		if is_player_attacker:
			return " [color=gray]It seems to shrug off some of the damage.[/color]"
		else:
			return " [color=cyan]You resist some of the damage.[/color]"

	# Vulnerability - increased damage
	if vulnerable:
		if is_player_attacker:
			return " [color=yellow]It recoils - the attack is especially effective![/color]"
		else:
			return " [color=red]The attack is especially painful![/color]"

	return ""


## Format attack roll breakdown for display (d100 system)
## Returns: "[X (Roll) vs Y% (Hit Chance)]" in grey
static func _format_attack_roll(roll: int, hit_chance: int) -> String:
	return "[color=gray][%d (Roll) vs %d%% (Hit Chance)][/color]" % [roll, hit_chance]
