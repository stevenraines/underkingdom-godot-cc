class_name Enemy
extends Entity

## Enemy - Base class for all enemy entities
##
## Handles enemy-specific behavior, AI, and loot.

# AI properties
var behavior_type: String = "wander"  # "wander", "guardian", "aggressive", "pack"
var aggro_range: int = 5
var is_aggressive: bool = false

# Loot
var loot_table: String = ""  # Reference to loot table ID
var xp_value: int = 0

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

	# Check if player is at the target position (attack instead of move)
	if EntityManager.player and EntityManager.player.position == new_pos:
		# Attack will be implemented in combat phase
		# For now, just stay adjacent
		return

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
		if MapManager.current_map and MapManager.current_map.is_walkable(new_pos):
			_move_to(new_pos)
			return

## Calculate Manhattan distance to a position
func _distance_to(target: Vector2i) -> int:
	return abs(target.x - position.x) + abs(target.y - position.y)
