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

	# Simple AI for Phase 1.7 - will be expanded in Phase 1.8
	# For now, enemies just stand still
	pass

## Get distance to player
func distance_to_player() -> int:
	# This will be implemented when we have player reference in EntityManager
	return 999
