extends GutTest
## Unit tests for CombatSystem
##
## Tests combat formulas, hit calculations, and damage resolution.

const CombatSystemClass = preload("res://systems/combat_system.gd")


# =============================================================================
# Test: get_accuracy()
# =============================================================================

func test_get_accuracy_with_default_dex() -> void:
	# Given: An entity with DEX 10 (default)
	var entity = _create_mock_entity({"DEX": 10})

	# When: Calculating accuracy
	var accuracy = CombatSystemClass.get_accuracy(entity)

	# Then: Accuracy should be 50 + (10 * 2) = 70%
	assert_eq(accuracy, 70, "Accuracy with DEX 10 should be 70")


func test_get_accuracy_with_high_dex() -> void:
	# Given: An entity with high DEX
	var entity = _create_mock_entity({"DEX": 18})

	# When: Calculating accuracy
	var accuracy = CombatSystemClass.get_accuracy(entity)

	# Then: Accuracy should be 50 + (18 * 2) = 86%
	assert_eq(accuracy, 86, "Accuracy with DEX 18 should be 86")


func test_get_accuracy_with_low_dex() -> void:
	# Given: An entity with low DEX
	var entity = _create_mock_entity({"DEX": 5})

	# When: Calculating accuracy
	var accuracy = CombatSystemClass.get_accuracy(entity)

	# Then: Accuracy should be 50 + (5 * 2) = 60%
	assert_eq(accuracy, 60, "Accuracy with DEX 5 should be 60")


# =============================================================================
# Test: get_evasion()
# =============================================================================

func test_get_evasion_with_default_dex() -> void:
	# Given: An entity with DEX 10 (default)
	var entity = _create_mock_entity({"DEX": 10})

	# When: Calculating evasion
	var evasion = CombatSystemClass.get_evasion(entity)

	# Then: Evasion should be 5 + 10 = 15%
	assert_eq(evasion, 15, "Evasion with DEX 10 should be 15")


func test_get_evasion_with_high_dex() -> void:
	# Given: An entity with high DEX
	var entity = _create_mock_entity({"DEX": 18})

	# When: Calculating evasion
	var evasion = CombatSystemClass.get_evasion(entity)

	# Then: Evasion should be 5 + 18 = 23%
	assert_eq(evasion, 23, "Evasion with DEX 18 should be 23")


# =============================================================================
# Test: are_adjacent()
# =============================================================================

func test_are_adjacent_cardinal_neighbors() -> void:
	var center = Vector2i(5, 5)

	# Cardinal directions
	assert_true(CombatSystemClass.are_adjacent(center, Vector2i(5, 4)), "North should be adjacent")
	assert_true(CombatSystemClass.are_adjacent(center, Vector2i(5, 6)), "South should be adjacent")
	assert_true(CombatSystemClass.are_adjacent(center, Vector2i(4, 5)), "West should be adjacent")
	assert_true(CombatSystemClass.are_adjacent(center, Vector2i(6, 5)), "East should be adjacent")


func test_are_adjacent_diagonal_neighbors() -> void:
	var center = Vector2i(5, 5)

	# Diagonal directions
	assert_true(CombatSystemClass.are_adjacent(center, Vector2i(4, 4)), "NW should be adjacent")
	assert_true(CombatSystemClass.are_adjacent(center, Vector2i(6, 4)), "NE should be adjacent")
	assert_true(CombatSystemClass.are_adjacent(center, Vector2i(4, 6)), "SW should be adjacent")
	assert_true(CombatSystemClass.are_adjacent(center, Vector2i(6, 6)), "SE should be adjacent")


func test_are_adjacent_not_adjacent() -> void:
	var center = Vector2i(5, 5)

	# Non-adjacent positions
	assert_false(CombatSystemClass.are_adjacent(center, Vector2i(5, 3)), "2 tiles away should not be adjacent")
	assert_false(CombatSystemClass.are_adjacent(center, Vector2i(7, 5)), "2 tiles away should not be adjacent")
	assert_false(CombatSystemClass.are_adjacent(center, Vector2i(10, 10)), "Far away should not be adjacent")


func test_are_adjacent_same_position() -> void:
	var pos = Vector2i(5, 5)

	# Same position is NOT adjacent (can't attack yourself)
	assert_false(CombatSystemClass.are_adjacent(pos, pos), "Same position should not be adjacent")


# =============================================================================
# Test: are_cardinally_adjacent()
# =============================================================================

func test_are_cardinally_adjacent_cardinal() -> void:
	var center = Vector2i(5, 5)

	# Cardinal directions should be true
	assert_true(CombatSystemClass.are_cardinally_adjacent(center, Vector2i(5, 4)), "North is cardinal")
	assert_true(CombatSystemClass.are_cardinally_adjacent(center, Vector2i(5, 6)), "South is cardinal")
	assert_true(CombatSystemClass.are_cardinally_adjacent(center, Vector2i(4, 5)), "West is cardinal")
	assert_true(CombatSystemClass.are_cardinally_adjacent(center, Vector2i(6, 5)), "East is cardinal")


func test_are_cardinally_adjacent_diagonal_is_false() -> void:
	var center = Vector2i(5, 5)

	# Diagonals should be false
	assert_false(CombatSystemClass.are_cardinally_adjacent(center, Vector2i(4, 4)), "NW is diagonal")
	assert_false(CombatSystemClass.are_cardinally_adjacent(center, Vector2i(6, 4)), "NE is diagonal")
	assert_false(CombatSystemClass.are_cardinally_adjacent(center, Vector2i(4, 6)), "SW is diagonal")
	assert_false(CombatSystemClass.are_cardinally_adjacent(center, Vector2i(6, 6)), "SE is diagonal")


# =============================================================================
# Test: get_attack_message()
# =============================================================================

func test_get_attack_message_player_hit() -> void:
	var result = {
		"hit": true,
		"damage": 5,
		"attacker_name": "Player",
		"defender_name": "Goblin",
		"defender_died": false,
		"weapon_name": "Iron Sword"
	}

	var message = CombatSystemClass.get_attack_message(result, true)

	assert_eq(message, "You hit the Goblin with your Iron Sword for 5 damage.")


func test_get_attack_message_player_kill() -> void:
	var result = {
		"hit": true,
		"damage": 10,
		"attacker_name": "Player",
		"defender_name": "Rat",
		"defender_died": true,
		"weapon_name": ""
	}

	var message = CombatSystemClass.get_attack_message(result, true)

	assert_eq(message, "You kill the Rat!")


func test_get_attack_message_player_miss() -> void:
	var result = {
		"hit": false,
		"damage": 0,
		"attacker_name": "Player",
		"defender_name": "Wolf",
		"defender_died": false,
		"weapon_name": "Wooden Club"
	}

	var message = CombatSystemClass.get_attack_message(result, true)

	assert_eq(message, "You miss the Wolf with your Wooden Club.")


func test_get_attack_message_enemy_hit() -> void:
	var result = {
		"hit": true,
		"damage": 3,
		"attacker_name": "Skeleton",
		"defender_name": "Player",
		"defender_died": false
	}

	var message = CombatSystemClass.get_attack_message(result, false)

	assert_eq(message, "The Skeleton hits you for 3 damage.")


func test_get_attack_message_enemy_kill() -> void:
	var result = {
		"hit": true,
		"damage": 20,
		"attacker_name": "Dragon",
		"defender_name": "Player",
		"defender_died": true
	}

	var message = CombatSystemClass.get_attack_message(result, false)

	assert_eq(message, "The Dragon kills you!")


func test_get_attack_message_enemy_miss() -> void:
	var result = {
		"hit": false,
		"damage": 0,
		"attacker_name": "Orc",
		"defender_name": "Player",
		"defender_died": false
	}

	var message = CombatSystemClass.get_attack_message(result, false)

	assert_eq(message, "The Orc misses you.")


# =============================================================================
# Helper: Create mock entity for testing
# =============================================================================

func _create_mock_entity(attrs: Dictionary) -> RefCounted:
	# Create a simple mock entity with the required attributes
	var mock = MockEntity.new()
	mock.attributes = {
		"STR": attrs.get("STR", 10),
		"DEX": attrs.get("DEX", 10),
		"CON": attrs.get("CON", 10),
		"INT": attrs.get("INT", 10),
		"WIS": attrs.get("WIS", 10),
		"CHA": attrs.get("CHA", 10)
	}
	return mock


# =============================================================================
# Mock Entity class for testing
# =============================================================================

class MockEntity extends RefCounted:
	var attributes: Dictionary = {}
	var name: String = "MockEntity"
	var base_damage: int = 1
	var armor: int = 0
	var is_alive: bool = true
	var current_health: int = 10
	var max_health: int = 10

	func take_damage(amount: int) -> void:
		current_health -= amount
		if current_health <= 0:
			is_alive = false

	func get_effective_attribute(attr_name: String) -> int:
		return attributes.get(attr_name, 10)
