class_name CombatSystem
extends RefCounted

## CombatSystem - Centralized combat resolution logic
##
## Handles attack resolution, damage calculation, and combat formulas.
## All combat in the game flows through this system.

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
		"weapon_name": ""
	}
	
	# Get equipped weapon name if attacker has inventory
	if attacker.has_method("get_component") or "inventory" in attacker:
		var inventory = attacker.get("inventory")
		if inventory and inventory.equipment.get("main_hand"):
			result.weapon_name = inventory.equipment["main_hand"].name
	
	# Calculate hit chance
	var accuracy = get_accuracy(attacker)
	var evasion = get_evasion(defender)
	var hit_chance = clampi(accuracy - evasion, 5, 95)  # Always 5-95% chance
	
	result.hit_chance = hit_chance
	
	# Roll for hit (1-100)
	var roll = randi_range(1, 100)
	result.roll = roll
	
	if roll <= hit_chance:
		result.hit = true
		
		# Calculate and apply damage
		var damage = calculate_damage(attacker, defender)
		result.damage = damage

		# Apply damage to defender
		# Pass source and method for death tracking
		var source = attacker.name if attacker else "Unknown"
		var natural_weapon = attacker.get("natural_weapon") if attacker else null
		var method = result.weapon_name if result.weapon_name != "" else (natural_weapon if natural_weapon else "")

		if defender.has_method("take_damage"):
			defender.take_damage(damage, source, method)

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
## Formula: 5% + (DEX × 1)%
static func get_evasion(entity: Entity) -> int:
	var dex = entity.attributes.get("DEX", 10)
	return 5 + dex

## Calculate damage for an attack
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
	
	if result.hit:
		if result.defender_died:
			if is_player_attacker:
				return "You kill the %s%s!" % [defender, weapon_phrase]
			else:
				return "The %s kills you!" % attacker
		else:
			if is_player_attacker:
				return "You hit the %s%s for %d damage." % [defender, weapon_phrase, result.damage]
			else:
				return "The %s hits you for %d damage." % [attacker, result.damage]
	else:
		if is_player_attacker:
			return "You miss the %s%s." % [defender, weapon_phrase]
		else:
			return "The %s misses you." % attacker
