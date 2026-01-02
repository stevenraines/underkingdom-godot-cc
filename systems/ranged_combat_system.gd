class_name RangedCombatSystem
extends RefCounted

## RangedCombatSystem - Handles ranged weapon combat mechanics
##
## Supports bows, crossbows, slings (with ammunition) and thrown weapons.
## Includes line-of-sight checking, range validation, and ammo recovery.

## Attempt a ranged attack from attacker to target
## weapon: The ranged weapon being used
## ammo: The ammunition being consumed (null for thrown weapons)
## Returns a dictionary with attack results
static func attempt_ranged_attack(attacker: Entity, target: Entity, weapon: Item, ammo: Item = null) -> Dictionary:
	var result = {
		"hit": false,
		"damage": 0,
		"attacker_name": attacker.name,
		"defender_name": target.name,
		"defender_died": false,
		"critical": false,
		"roll": 0,
		"hit_chance": 0,
		"weapon_name": weapon.name,
		"ammo_name": ammo.name if ammo else "",
		"distance": 0,
		"ammo_recovered": false,
		"recovery_position": Vector2i.ZERO,
		"is_ranged": true,
		"is_thrown": weapon.is_thrown_weapon()
	}

	# Calculate distance
	var distance = get_distance(attacker.position, target.position)
	result.distance = distance

	# Get effective range
	var str_stat = attacker.attributes.get("STR", 10)
	var effective_range = weapon.get_effective_range(str_stat)

	# Check if target is in range
	if distance > effective_range:
		result.hit = false
		result.error = "Target is out of range"
		return result

	# Check line of sight
	if not has_line_of_sight(attacker.position, target.position):
		result.hit = false
		result.error = "No line of sight to target"
		return result

	# Calculate hit chance with range penalty
	var hit_chance = calculate_ranged_accuracy(attacker, target, weapon, distance, effective_range)
	result.hit_chance = hit_chance

	# Roll for hit (1-100)
	var roll = randi_range(1, 100)
	result.roll = roll

	if roll <= hit_chance:
		result.hit = true

		# Calculate damage
		var damage = calculate_ranged_damage(attacker, weapon, ammo)
		result.damage = damage

		# Apply damage to target
		target.take_damage(damage)

		# Check if target died
		if not target.is_alive:
			result.defender_died = true

		# Ammo/thrown recovery on hit - add to pending drops
		if ammo or weapon.is_thrown_weapon():
			var recovery_item = ammo if ammo else weapon
			var recovery_chance = recovery_item.recovery_chance
			if randf() < recovery_chance:
				result.ammo_recovered = true
				result.recovery_position = target.position
				# Add to target's pending_drops if they have it
				if target.has_method("add_pending_drop"):
					target.add_pending_drop(recovery_item.id, 1)
	else:
		# Miss - calculate where projectile lands
		var landing_pos = calculate_miss_landing(attacker.position, target.position, effective_range)
		result.recovery_position = landing_pos

		# Check recovery chance on miss
		if ammo or weapon.is_thrown_weapon():
			var recovery_item = ammo if ammo else weapon
			var recovery_chance = recovery_item.recovery_chance
			# Slightly lower recovery on miss (hitting ground/walls)
			if randf() < (recovery_chance * 0.7):
				result.ammo_recovered = true

	# Emit attack signal
	EventBus.attack_performed.emit(attacker, target, result)

	return result


## Calculate accuracy for ranged attacks
## Includes range penalty: -5% per tile beyond half range
static func calculate_ranged_accuracy(attacker: Entity, target: Entity, weapon: Item, distance: int, effective_range: int) -> int:
	# Base accuracy from DEX
	var dex = attacker.attributes.get("DEX", 10)
	var base_accuracy = 50 + (dex * 2)

	# Weapon accuracy modifier
	base_accuracy += weapon.accuracy_modifier

	# Target evasion
	var target_dex = target.attributes.get("DEX", 10)
	var evasion = 5 + target_dex

	# Range penalty: -5% per tile beyond half range
	@warning_ignore("integer_division")
	var half_range = effective_range / 2
	var range_penalty = 0
	if distance > half_range:
		range_penalty = (distance - half_range) * 5

	# Calculate final hit chance (clamped to 5-95%)
	var hit_chance = clampi(base_accuracy - evasion - range_penalty, 5, 95)

	return hit_chance


## Calculate damage for ranged attacks
## Formula: Weapon damage + Ammo damage + (STR/2 for thrown weapons)
static func calculate_ranged_damage(attacker: Entity, weapon: Item, ammo: Item = null) -> int:
	var damage = weapon.damage_bonus

	# Add ammo damage bonus if present
	if ammo:
		damage += ammo.damage_bonus

	# Thrown weapons get STR bonus
	if weapon.is_thrown_weapon():
		var str_stat = attacker.attributes.get("STR", 10)
		@warning_ignore("integer_division")
		damage += (str_stat - 10) / 2

	# Minimum 1 damage
	return maxi(1, damage)


## Check if there's a clear line of sight between two positions
## Uses Bresenham's line algorithm
static func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var line = get_line_between(from, to)

	# Check each tile along the line (except start and end)
	for i in range(1, line.size() - 1):
		var pos = line[i]
		# Check if this tile blocks vision
		if not is_tile_transparent(pos):
			return false

	return true


## Get all tiles along a line between two points using Bresenham's algorithm
static func get_line_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = []

	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx - dy

	var current = from

	while true:
		line.append(current)

		if current == to:
			break

		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			current.x += sx
		if e2 < dx:
			err += dx
			current.y += sy

	return line


## Check if a tile is transparent (doesn't block vision/projectiles)
static func is_tile_transparent(pos: Vector2i) -> bool:
	if not MapManager.current_map:
		return false

	# Use chunk system to get tile
	var tile = ChunkManager.get_tile_at(pos)
	if not tile:
		return false

	return tile.transparent


## Get Euclidean distance between two positions (rounded to int)
static func get_distance(from: Vector2i, to: Vector2i) -> int:
	var diff = to - from
	return int(sqrt(float(diff.x * diff.x + diff.y * diff.y)))


## Get Chebyshev distance (max of x/y difference - used for tile-based range)
static func get_tile_distance(from: Vector2i, to: Vector2i) -> int:
	var diff = to - from
	return maxi(abs(diff.x), abs(diff.y))


## Calculate where a missed projectile lands
## Traces line past target until hitting wall or max range
static func calculate_miss_landing(from: Vector2i, to: Vector2i, max_range: int) -> Vector2i:
	# Get direction from attacker to target
	var diff = Vector2(to.x - from.x, to.y - from.y)
	if diff.length() == 0:
		return to

	var direction = diff.normalized()

	# Trace line from target in same direction
	var current = Vector2(to.x, to.y)
	var current_tile = to

	# Continue until hitting wall or reaching max range from origin
	for i in range(max_range):
		current += direction
		var next_tile = Vector2i(int(round(current.x)), int(round(current.y)))

		if next_tile == current_tile:
			continue

		# Check if we've gone too far
		if get_distance(from, next_tile) > max_range:
			break

		# Check if next tile blocks
		if not is_tile_transparent(next_tile):
			return current_tile  # Land just before the wall

		current_tile = next_tile

	return current_tile


## Get all valid targets in range from a position
## Returns enemies within range and line of sight
static func get_valid_targets(attacker: Entity, weapon: Item) -> Array[Entity]:
	var targets: Array[Entity] = []

	var str_stat = attacker.attributes.get("STR", 10)
	var effective_range = weapon.get_effective_range(str_stat)

	# Get all entities from EntityManager
	for entity in EntityManager.entities:
		# Skip self, non-enemies, and dead entities
		if entity == attacker:
			continue
		if not entity is Enemy:
			continue
		if not entity.is_alive:
			continue

		# Check range
		var distance = get_tile_distance(attacker.position, entity.position)
		if distance > effective_range:
			continue
		if distance < 1:
			continue  # Can't ranged attack adjacent (use melee)

		# Check line of sight
		if not has_line_of_sight(attacker.position, entity.position):
			continue

		targets.append(entity)

	# Sort by distance (closest first)
	targets.sort_custom(func(a, b):
		return get_distance(attacker.position, a.position) < get_distance(attacker.position, b.position)
	)

	return targets


## Get a combat message for ranged attack result
static func get_ranged_attack_message(result: Dictionary, is_player_attacker: bool) -> String:
	var attacker = result.attacker_name
	var defender = result.defender_name
	var weapon = result.weapon_name
	var ammo = result.get("ammo_name", "")
	var is_thrown = result.get("is_thrown", false)

	# Build weapon phrase
	var weapon_phrase = ""
	if is_player_attacker:
		if is_thrown:
			weapon_phrase = " with a %s" % weapon
		elif ammo != "":
			weapon_phrase = " with your %s" % weapon
		else:
			weapon_phrase = " with your %s" % weapon

	if result.hit:
		if result.defender_died:
			if is_player_attacker:
				return "You kill the %s%s!" % [defender, weapon_phrase]
			else:
				return "The %s kills you with a ranged attack!" % attacker
		else:
			if is_player_attacker:
				return "You hit the %s%s for %d damage." % [defender, weapon_phrase, result.damage]
			else:
				return "The %s hits you for %d damage from range." % [attacker, result.damage]
	else:
		if is_player_attacker:
			if is_thrown:
				return "You throw a %s at the %s but miss." % [weapon, defender]
			else:
				return "Your shot misses the %s." % defender
		else:
			return "The %s's shot misses you." % attacker
