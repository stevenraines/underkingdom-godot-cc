class_name Enemy
extends Entity

## Enemy - Base class for all enemy entities
##
## Handles enemy-specific behavior, AI, and loot.

const _FOVSystem = preload("res://systems/fov_system.gd")

# AI properties
var behavior_type: String = "wander"  # "wander", "guardian", "aggressive", "pack"
var aggro_range: int = 5
var is_aggressive: bool = false
var feared_components: Array[String] = []  # Component types to avoid (e.g., "fire", "holy")
var fear_distance: int = 4  # How close they'll get to feared components

# Loot
var loot_table: String = ""  # Reference to loot table ID
var xp_value: int = 0
var yields: Array[Dictionary] = []

# AI state
var target_position: Vector2i = Vector2i.ZERO
var last_known_player_pos: Vector2i = Vector2i.ZERO
var is_alerted: bool = false  # Has detected player

func _init() -> void:
	super()

## Create an enemy from data
static func create(enemy_data: Dictionary) -> Enemy:
	var enemy = Enemy.new()

	# Basic properties
	enemy.entity_id = enemy_data.get("id", "unknown_enemy")
	enemy.entity_type = "enemy"
	enemy.name = enemy_data.get("name", "Unknown Enemy")
	enemy.ascii_char = enemy_data.get("ascii_char", "E")

	# Parse color from hex string
	var ascii_color = enemy_data.get("ascii_color", "#FF0000")
	enemy.color = Color(ascii_color) if enemy_data.has("ascii_color") else Color.RED

	# Stats
	var stats = enemy_data.get("stats", {})
	enemy.attributes["STR"] = stats.get("str", 10)
	enemy.attributes["DEX"] = stats.get("dex", 10)
	enemy.attributes["CON"] = stats.get("con", 10)
	enemy.attributes["INT"] = stats.get("int", 10)
	enemy.attributes["WIS"] = stats.get("wis", 10)
	enemy.attributes["CHA"] = stats.get("cha", 10)

	# Recalculate derived stats with new attributes
	enemy._calculate_derived_stats()

	# If health is specified directly, use that instead
	if stats.has("health"):
		enemy.max_health = stats["health"]
		enemy.current_health = stats["health"]

	# AI properties
	enemy.behavior_type = enemy_data.get("behavior", "wander")
	enemy.loot_table = enemy_data.get("loot_table", "")
	enemy.xp_value = enemy_data.get("xp_value", 10)

	# Feared components (convert from JSON array to typed array)
	var feared_comps = enemy_data.get("feared_components", [])
	for comp in feared_comps:
		enemy.feared_components.append(comp)
	enemy.fear_distance = enemy_data.get("fear_distance", 4)

	# Combat properties
	enemy.base_damage = enemy_data.get("base_damage", 2)
	enemy.armor = enemy_data.get("armor", 0)

	# Yields on death (drops)
	enemy.yields.assign(enemy_data.get("yields", []))

	# Aggro range based on INT
	enemy.aggro_range = 3 + enemy.attributes["INT"]

	return enemy

## Take turn (called by turn manager for enemy AI)
func take_turn() -> void:
	if not is_alive:
		return

	var player = EntityManager.player
	if not player or not player.is_alive:
		return

	var distance = _distance_to(player.position)

	# Check if player is in aggro range
	if distance <= aggro_range:
		is_alerted = true
		last_known_player_pos = player.position

	# Execute behavior based on type and alert state
	if is_alerted:
		_execute_behavior(player)

## Execute AI behavior
func _execute_behavior(player: Player) -> void:
	# First, check if we should attack (player is adjacent)
	if _attempt_attack_if_adjacent():
		return  # Attack consumes the turn

	# Check for feared components - flee if near any
	if not feared_components.is_empty() and _is_near_feared_component():
		var threat_pos = _get_nearest_feared_component_position()
		_move_away_from(threat_pos)
		return  # Fleeing consumes the turn

	# Otherwise, execute movement behavior
	match behavior_type:
		"aggressive":
			# Always chase and attack
			_move_toward_target(player.position)
		"guardian":
			# Chase if player is close, otherwise hold position
			var distance = _distance_to(player.position)
			if distance <= aggro_range:
				_move_toward_target(player.position)
		"pack":
			# Similar to aggressive but could coordinate (future)
			_move_toward_target(player.position)
		"wander":
			# Move randomly, but toward player if alerted
			if is_alerted:
				_move_toward_target(last_known_player_pos)
			else:
				_wander()
		_:
			_move_toward_target(player.position)

## Attempt to attack player if adjacent
func _attempt_attack_if_adjacent() -> bool:
	if not EntityManager.player or not EntityManager.player.is_alive:
		return false
	
	# Check if player is cardinally adjacent (not diagonal for now)
	if CombatSystem.are_cardinally_adjacent(position, EntityManager.player.position):
		CombatSystem.attempt_attack(self, EntityManager.player)
		return true
	
	return false

## Move one step toward target position
func _move_toward_target(target: Vector2i) -> void:
	if position == target:
		return

	# Calculate direction to target
	var diff = target - position
	var move_dir = Vector2i.ZERO

	# Prefer the larger difference to move diagonally-ish
	if abs(diff.x) >= abs(diff.y):
		move_dir.x = sign(diff.x)
	else:
		move_dir.y = sign(diff.y)

	# Try to move in that direction
	var new_pos = position + move_dir

	# Check if player is at the target position (don't move into player)
	if EntityManager.player and EntityManager.player.position == new_pos:
		# Player is blocking - attack handled in _attempt_attack_if_adjacent
		return

	# Check if moving would put enemy inside a feared area (e.g., campfire light)
	# Only block if enemy is not already inside the feared area
	if not feared_components.is_empty() and _is_position_in_feared_area(new_pos) and not _is_position_in_feared_area(position):
		# Don't enter the feared area - stand ground instead
		return

	# Check for closed door - INT 5+ can open doors
	if MapManager.current_map:
		var tile = MapManager.current_map.get_tile(new_pos)
		if tile and tile.tile_type == "door" and not tile.is_open:
			if attributes["INT"] >= 5:
				# Open the door (spends this turn)
				tile.open_door()
				EventBus.combat_message.emit("%s opens a door." % name, Color.GRAY)
				_FOVSystem.invalidate_cache()
				EventBus.tile_changed.emit(new_pos)
				return  # Opening door consumes the turn
			else:
				# Can't open door, try alternate path
				pass

	# Check if position is walkable
	if MapManager.current_map and MapManager.current_map.is_walkable(new_pos):
		_move_to(new_pos)
	else:
		# Try alternate direction
		var alt_dir = Vector2i.ZERO
		if move_dir.x != 0:
			alt_dir.y = sign(diff.y) if diff.y != 0 else 1
		else:
			alt_dir.x = sign(diff.x) if diff.x != 0 else 1

		var alt_pos = position + alt_dir

		# Check for closed door on alternate path too
		if MapManager.current_map:
			var alt_tile = MapManager.current_map.get_tile(alt_pos)
			if alt_tile and alt_tile.tile_type == "door" and not alt_tile.is_open:
				if attributes["INT"] >= 5:
					alt_tile.open_door()
					EventBus.combat_message.emit("%s opens a door." % name, Color.GRAY)
					_FOVSystem.invalidate_cache()
					EventBus.tile_changed.emit(alt_pos)
					return

		if MapManager.current_map and MapManager.current_map.is_walkable(alt_pos):
			_move_to(alt_pos)

## Move to a new position and update visuals
func _move_to(new_pos: Vector2i) -> void:
	var old_pos = position
	position = new_pos

	# Emit movement signal for rendering update
	EventBus.entity_moved.emit(self, old_pos, new_pos)

## Wander randomly
func _wander() -> void:
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	directions.shuffle()

	for dir in directions:
		var new_pos = position + dir
		# Don't wander into feared areas
		if not feared_components.is_empty() and _is_position_in_feared_area(new_pos) and not _is_position_in_feared_area(position):
			continue
		if MapManager.current_map and MapManager.current_map.is_walkable(new_pos):
			_move_to(new_pos)
			return

## Calculate Manhattan distance to a position
func _distance_to(target: Vector2i) -> int:
	return abs(target.x - position.x) + abs(target.y - position.y)


## Override take_damage to alert enemy when hit
func take_damage(amount: int, source: String = "Unknown", method: String = "") -> void:
	super.take_damage(amount, source, method)

	# Being attacked alerts the enemy and makes them aware of the player's location
	if is_alive and EntityManager.player:
		is_alerted = true
		last_known_player_pos = EntityManager.player.position
		print("[Enemy] %s was hit and is now alerted! Knows player is at %v" % [name, last_known_player_pos])

## Check if there's a feared component nearby that we should avoid
func _is_near_feared_component() -> bool:
	if feared_components.is_empty() or not MapManager.current_map:
		return false

	var map_id = MapManager.current_map.map_id
	var structures = StructureManager.get_structures_on_map(map_id)

	for structure in structures:
		# Check if this structure has any component we fear
		for feared_comp in feared_components:
			var comp = structure.get_component(feared_comp)
			if comp:
				# Special handling for fire component - check if lit
				if feared_comp == "fire" and "is_lit" in comp:
					if not comp.is_lit:
						continue

				# Check distance
				var distance = _distance_to(structure.position)
				if distance <= fear_distance:
					return true

	return false

## Check if moving to a position would put enemy inside a feared component's radius
## Returns true if the position is inside a feared area (should avoid)
func _is_position_in_feared_area(check_pos: Vector2i) -> bool:
	if feared_components.is_empty() or not MapManager.current_map:
		return false

	var map_id = MapManager.current_map.map_id
	var structures = StructureManager.get_structures_on_map(map_id)

	for structure in structures:
		for feared_comp in feared_components:
			var comp = structure.get_component(feared_comp)
			if comp:
				# Special handling for fire component - check if lit and use light_radius
				if feared_comp == "fire":
					if "is_lit" in comp and not comp.is_lit:
						continue
					# Use light_radius for fire avoidance (enemies won't enter the lit area)
					var avoidance_radius = comp.light_radius if "light_radius" in comp else fear_distance
					var distance = abs(check_pos.x - structure.position.x) + abs(check_pos.y - structure.position.y)
					if distance <= avoidance_radius:
						return true
				else:
					# For other feared components, use fear_distance
					var distance = abs(check_pos.x - structure.position.x) + abs(check_pos.y - structure.position.y)
					if distance <= fear_distance:
						return true

	return false

## Find the nearest feared component position (for fleeing away from it)
func _get_nearest_feared_component_position() -> Vector2i:
	if not MapManager.current_map:
		return position

	var map_id = MapManager.current_map.map_id
	var structures = StructureManager.get_structures_on_map(map_id)
	var nearest_pos = position
	var nearest_distance = 999

	for structure in structures:
		# Check if this structure has any component we fear
		for feared_comp in feared_components:
			var comp = structure.get_component(feared_comp)
			if comp:
				# Special handling for fire component - check if lit
				if feared_comp == "fire" and "is_lit" in comp:
					if not comp.is_lit:
						continue

				# Check distance
				var distance = _distance_to(structure.position)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest_pos = structure.position

	return nearest_pos

## Move away from a position (flee behavior)
func _move_away_from(threat: Vector2i) -> void:
	var diff = position - threat
	var move_dir = Vector2i.ZERO

	# Move in the direction AWAY from the threat
	if abs(diff.x) >= abs(diff.y):
		move_dir.x = sign(diff.x) if diff.x != 0 else 1
	else:
		move_dir.y = sign(diff.y) if diff.y != 0 else 1

	var new_pos = position + move_dir
	var old_pos = position

	# Check for closed door - INT 5+ can open doors even when fleeing
	if MapManager.current_map:
		var tile = MapManager.current_map.get_tile(new_pos)
		if tile and tile.tile_type == "door" and not tile.is_open:
			if attributes["INT"] >= 5:
				tile.open_door()
				EventBus.combat_message.emit("%s opens a door." % name, Color.GRAY)
				_FOVSystem.invalidate_cache()
				EventBus.tile_changed.emit(new_pos)
				return  # Opening door consumes the turn

	# Check if position is walkable
	if MapManager.current_map and MapManager.current_map.is_walkable(new_pos):
		_move_to(new_pos)
		# INT 8+ closes doors behind when fleeing
		_try_close_door_behind(old_pos, move_dir)
	else:
		# Try alternate direction
		var alt_dir = Vector2i.ZERO
		if move_dir.x != 0:
			alt_dir.y = sign(diff.y) if diff.y != 0 else 1
		else:
			alt_dir.x = sign(diff.x) if diff.x != 0 else 1

		var alt_pos = position + alt_dir

		# Check for closed door on alternate path
		if MapManager.current_map:
			var alt_tile = MapManager.current_map.get_tile(alt_pos)
			if alt_tile and alt_tile.tile_type == "door" and not alt_tile.is_open:
				if attributes["INT"] >= 5:
					alt_tile.open_door()
					EventBus.combat_message.emit("%s opens a door." % name, Color.GRAY)
					_FOVSystem.invalidate_cache()
					EventBus.tile_changed.emit(alt_pos)
					return

		if MapManager.current_map and MapManager.current_map.is_walkable(alt_pos):
			_move_to(alt_pos)
			# INT 8+ closes doors behind when fleeing
			_try_close_door_behind(old_pos, alt_dir)

## Try to close a door behind when fleeing (INT 8+ only)
func _try_close_door_behind(old_pos: Vector2i, _move_dir: Vector2i) -> void:
	if attributes["INT"] < 8:
		return

	if not MapManager.current_map:
		return

	# Check if there was an open door at our old position
	var tile = MapManager.current_map.get_tile(old_pos)
	if tile and tile.tile_type == "door" and tile.is_open:
		# Check if position is empty (no entities blocking)
		if not EntityManager.get_blocking_entity_at(old_pos):
			tile.close_door()
			EventBus.combat_message.emit("%s closes a door." % name, Color.GRAY)
			_FOVSystem.invalidate_cache()
			EventBus.tile_changed.emit(old_pos)
