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
		"hit_chance": 0
	}
	
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
		defender.take_damage(damage)
		
		# Check if defender died
		if not defender.is_alive:
			result.defender_died = true
	
	# Emit attack signal
	EventBus.attack_performed.emit(attacker, defender, result)
	
	return result

## Calculate attacker's accuracy
## Formula: 50% + (DEX × 2)%
static func get_accuracy(entity: Entity) -> int:
	var dex = entity.attributes.get("DEX", 10)
	return 50 + (dex * 2)

## Calculate defender's evasion
## Formula: 5% + (DEX × 1)%
static func get_evasion(entity: Entity) -> int:
	var dex = entity.attributes.get("DEX", 10)
	return 5 + dex

## Calculate damage for an attack
## Formula: Base Damage + STR modifier - Armor
## STR modifier: +1 per 2 STR above 10
static func calculate_damage(attacker: Entity, defender: Entity) -> int:
	var base_damage = attacker.base_damage
	
	# STR modifier: +1 per 2 points above 10
	var str_stat = attacker.attributes.get("STR", 10)
	@warning_ignore("integer_division")
	var str_modifier = (str_stat - 10) / 2
	
	# Armor reduction
	var armor = defender.armor
	
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
	
	if result.hit:
		if result.defender_died:
			if is_player_attacker:
				return "You kill the %s!" % defender
			else:
				return "The %s kills you!" % attacker
		else:
			if is_player_attacker:
				return "You hit the %s for %d damage." % [defender, result.damage]
			else:
				return "The %s hits you for %d damage." % [attacker, result.damage]
	else:
		if is_player_attacker:
			return "You miss the %s." % defender
		else:
			return "The %s misses you." % attacker
