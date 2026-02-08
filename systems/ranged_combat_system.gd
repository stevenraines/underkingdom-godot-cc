class_name RangedCombatSystem
extends RefCounted

## RangedCombatSystem - Handles ranged weapon combat mechanics
##
## Supports bows, crossbows, slings (with ammunition) and thrown weapons.
## Includes line-of-sight checking, range validation, and ammo recovery.

const ElementalSystemClass = preload("res://systems/elemental_system.gd")

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
		"range_penalty": 0,
		"weapon_name": weapon.name,
		"ammo_name": ammo.name if ammo else "",
		"distance": 0,
		"ammo_recovered": false,
		"recovery_position": Vector2i.ZERO,
		"is_ranged": true,
		"is_thrown": weapon.is_thrown_weapon(),
		"damage_type": weapon.damage_type if weapon.damage_type != "" else "piercing",
		"secondary_damage": 0,
		"secondary_damage_type": weapon.secondary_damage_type if weapon.secondary_damage_type != "" else "",
		"resisted": false,
		"vulnerable": false
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

	# Calculate range penalty for display
	@warning_ignore("integer_division")
	var half_range = effective_range / 2
	var range_penalty = 0
	if distance > half_range:
		range_penalty = (distance - half_range) * 5
	result.range_penalty = range_penalty

	# Calculate hit chance with range penalty
	var hit_chance = calculate_ranged_accuracy(attacker, target, weapon, distance, effective_range)
	result.hit_chance = hit_chance

	# Roll for hit (1-100)
	var roll = randi_range(1, 100)
	result.roll = roll

	# Check for proactive buff triggers on miss (generic system)
	if roll > hit_chance:
		for effect in attacker.active_effects:
			if effect.get("trigger_on", "") == "attack_miss":
				match effect.get("trigger_effect", ""):
					"reroll_attack":
						var reroll = randi_range(1, 100)
						var effect_name = effect.get("name", "Effect")
						attacker.remove_magical_effect(effect.id)
						EventBus.message_logged.emit("[color=yellow]%s[/color]" % effect_name)
						EventBus.message_logged.emit("[color=yellow]Rerolling attack... (%d -> %d)[/color]" % [roll, reroll])
						roll = reroll
						result.roll = roll
						break  # Only one reroll per attack

	if roll <= hit_chance:
		result.hit = true

		# Check for proactive buff triggers on ranged hit (generic system)
		var damage_multiplier = 1.0
		var self_damage_amount = 0
		for effect in attacker.active_effects:
			if effect.get("trigger_on", "") == "ranged_hit":
				match effect.get("trigger_effect", ""):
					"double_damage":
						damage_multiplier = effect.get("damage_multiplier", 2.0)
						self_damage_amount = effect.get("self_damage", 0)
						var trigger_msg = effect.get("trigger_message", "")
						if trigger_msg != "":
							EventBus.message_logged.emit("[color=green]%s[/color]" % trigger_msg)
						attacker.remove_magical_effect(effect.id)
						break  # Only one damage modifier per attack

		# Calculate damage with damage types
		var damage_result = calculate_ranged_damage_with_types(attacker, target, weapon, ammo)

		# Apply damage multiplier from triggered effects
		if damage_multiplier != 1.0:
			damage_result.primary_damage = int(damage_result.primary_damage * damage_multiplier)
			damage_result.secondary_damage = int(damage_result.secondary_damage * damage_multiplier)
		result.damage = damage_result.primary_damage
		result.secondary_damage = damage_result.secondary_damage
		result.resisted = damage_result.resisted
		result.vulnerable = damage_result.vulnerable

		# Total damage is primary + secondary
		var total_damage = result.damage + result.secondary_damage

		# Check if target will die from this damage (before applying it)
		# This allows us to emit the attack message before the death triggers loot drops
		if target.current_health - total_damage <= 0:
			result.defender_died = true

		# Emit attack signal BEFORE applying damage
		# This ensures the kill message appears before loot drop messages
		EventBus.attack_performed.emit(attacker, target, result)

		# Apply damage to target
		# Pass source and weapon for death tracking
		var source = attacker.name if attacker else "Unknown"
		var method = weapon.name if weapon else "Projectile"

		if target.has_method("take_damage") and total_damage > 0:
			target.take_damage(total_damage, source, method)

		# Apply self-damage from triggered effects
		if self_damage_amount > 0 and attacker.has_method("take_damage"):
			attacker.take_damage(self_damage_amount, "Self", "Ability")
			EventBus.message_logged.emit("[color=red]You take %d damage from the exertion![/color]" % self_damage_amount)

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

		# Emit attack signal for misses
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

	# Add weapon skill bonus if attacker has the method
	if attacker.has_method("get_weapon_skill_bonus"):
		base_accuracy += attacker.get_weapon_skill_bonus()

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


## Calculate damage for ranged attacks (legacy - backwards compatibility)
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


## Calculate ranged damage with damage type system
## Returns dictionary with primary_damage, secondary_damage, resisted, vulnerable flags
static func calculate_ranged_damage_with_types(attacker: Entity, target: Entity, weapon: Item, ammo: Item = null) -> Dictionary:
	var result = {
		"primary_damage": 0,
		"secondary_damage": 0,
		"resisted": false,
		"vulnerable": false
	}

	# Base damage from weapon
	var base_damage = weapon.damage_bonus

	# Add ammo damage bonus if present
	if ammo:
		base_damage += ammo.damage_bonus

	# Thrown weapons get STR bonus
	if weapon.is_thrown_weapon():
		var str_stat = attacker.attributes.get("STR", 10)
		@warning_ignore("integer_division")
		base_damage += (str_stat - 10) / 2

	# Determine damage type (ranged weapons default to piercing)
	var damage_type = weapon.damage_type if weapon.damage_type != "" else "piercing"
	var secondary_damage_type = weapon.secondary_damage_type if weapon.secondary_damage_type != "" else ""
	var secondary_damage_bonus = weapon.secondary_damage_bonus if weapon.secondary_damage_bonus > 0 else 0

	# Ranged attacks typically bypass armor (projectiles find gaps)
	# But piercing already has armor bypass built in, so we just use base damage

	# Add class ranged damage bonus (e.g., Ranger Hunter's Mark)
	if attacker.has_method("get_class_ranged_bonus"):
		var ranged_bonus = attacker.get_class_ranged_bonus()
		if ranged_bonus > 0:
			base_damage += ranged_bonus
			EventBus.message_logged.emit("[color=green]Hunter's Mark: +%d ranged damage![/color]" % ranged_bonus)

	# Apply damage type resistance/vulnerability for primary damage
	var primary_result = ElementalSystemClass.calculate_elemental_damage(base_damage, damage_type, target, attacker)
	result.primary_damage = primary_result.final_damage

	# Track resistance/vulnerability for messaging
	if primary_result.resisted or primary_result.immune:
		result.resisted = true
	if primary_result.vulnerable:
		result.vulnerable = true

	# Handle secondary damage type (e.g., fire on enchanted arrows)
	if secondary_damage_type != "" and secondary_damage_bonus > 0:
		var secondary_result = ElementalSystemClass.calculate_elemental_damage(secondary_damage_bonus, secondary_damage_type, target, attacker)
		result.secondary_damage = secondary_result.final_damage

		if secondary_result.resisted or secondary_result.immune:
			result.resisted = true
		if secondary_result.vulnerable:
			result.vulnerable = true

	# Ensure minimum 1 damage if we hit (unless fully immune)
	if result.primary_damage == 0 and result.secondary_damage == 0 and not result.resisted:
		result.primary_damage = 1

	return result


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

	# Use chunk system for chunk-based maps, otherwise use map directly
	var tile = null
	if MapManager.current_map.chunk_based:
		tile = ChunkManager.get_tile(pos)
	else:
		tile = MapManager.current_map.get_tile(pos)

	if not tile:
		# CRITICAL FIX: During turn processing, ChunkManager is frozen and may return null
		# for tiles in unloaded chunks. For dungeons (chunk-based maps), treat null tiles
		# as transparent during frozen state to prevent AI from freezing when checking LOS.
		# This is safe because dungeon rooms are fully generated - missing tiles are due to
		# freeze state, not actual walls.
		if MapManager.current_map.chunk_based and ChunkManager.is_frozen():
			return true
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
## Returns enemies within range, line of sight, and visibility (illuminated)
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

		# Check if target is currently visible (in FOV and illuminated)
		if not FogOfWarSystem.is_visible(entity.position):
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

	# Determine the projectile name (ammo for ranged weapons, weapon for thrown)
	var projectile = ammo if ammo != "" else weapon

	# Build roll info string (grey colored)
	var roll_info = _format_ranged_roll(result.roll, result.hit_chance, result.get("range_penalty", 0))

	# Get resistance/vulnerability cue
	var cue = _get_resistance_cue(result, is_player_attacker)

	if result.hit:
		if result.defender_died:
			if is_player_attacker:
				if is_thrown:
					return "Your %s kills the %s! %s" % [projectile, defender, roll_info]
				else:
					return "Your %s kills the %s! %s" % [projectile, defender, roll_info]
			else:
				return "The %s kills you with a ranged attack!" % attacker
		else:
			if is_player_attacker:
				if is_thrown:
					var base_msg = "Your %s hits the %s for %d damage. %s" % [projectile, defender, result.damage, roll_info]
					return base_msg + cue
				else:
					var base_msg = "Your %s hits the %s for %d damage. %s" % [projectile, defender, result.damage, roll_info]
					return base_msg + cue
			else:
				var base_msg = "The %s hits you for %d damage from range." % [attacker, result.damage]
				return base_msg + cue
	else:
		if is_player_attacker:
			if is_thrown:
				return "You throw a %s at the %s but miss. %s" % [projectile, defender, roll_info]
			else:
				return "Your %s misses the %s. %s" % [projectile, defender, roll_info]
		else:
			return "The %s's shot misses you." % attacker


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


## Format ranged attack roll breakdown for display (d100 system with range penalty)
## Returns: "[X (Roll) vs Y% (Hit Chance)]" or with range penalty in grey
static func _format_ranged_roll(roll: int, hit_chance: int, range_penalty: int) -> String:
	if range_penalty > 0:
		return "[color=gray][%d (Roll) vs %d%% (Hit Chance, -%d%% Range)][/color]" % [roll, hit_chance, range_penalty]
	else:
		return "[color=gray][%d (Roll) vs %d%% (Hit Chance)][/color]" % [roll, hit_chance]
