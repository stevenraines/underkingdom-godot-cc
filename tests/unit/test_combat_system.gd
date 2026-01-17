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
# Test: calculate_damage_with_types()
# =============================================================================

func test_calculate_damage_with_types_bludgeoning() -> void:
	# Given: Attacker with base damage 5, STR 12, defender with 2 armor
	var attacker = _create_mock_entity({"STR": 12})
	attacker.base_damage = 5
	var defender = _create_mock_entity({})
	defender.armor = 2

	# Weapon with bludgeoning damage
	var weapon = MockWeapon.new()
	weapon.damage_type = "bludgeoning"

	# When: Calculating damage
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, weapon)

	# Then: Damage = 5 + 1 (STR mod) - 2 (armor) = 4
	# STR modifier = (12 - 10) / 2 = 1
	assert_eq(result.primary_damage, 4, "Bludgeoning damage should be 4")
	assert_eq(result.secondary_damage, 0, "No secondary damage")


func test_calculate_damage_with_types_piercing_bypasses_armor() -> void:
	# Given: Attacker with base damage 5, STR 10, defender with 4 armor
	var attacker = _create_mock_entity({"STR": 10})
	attacker.base_damage = 5
	var defender = _create_mock_entity({})
	defender.armor = 4

	# Weapon with piercing damage
	var weapon = MockWeapon.new()
	weapon.damage_type = "piercing"

	# When: Calculating damage
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, weapon)

	# Then: Piercing bypasses 50% armor
	# Effective armor = 4 / 2 = 2
	# Damage = 5 + 0 (STR mod) - 2 (effective armor) = 3
	assert_eq(result.primary_damage, 3, "Piercing should bypass 50% of armor")


func test_calculate_damage_with_types_slashing_full_armor() -> void:
	# Given: Attacker with base damage 5, STR 10, defender with 4 armor
	var attacker = _create_mock_entity({"STR": 10})
	attacker.base_damage = 5
	var defender = _create_mock_entity({})
	defender.armor = 4

	# Weapon with slashing damage
	var weapon = MockWeapon.new()
	weapon.damage_type = "slashing"

	# When: Calculating damage
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, weapon)

	# Then: Full armor applies
	# Damage = 5 + 0 (STR mod) - 4 (armor) = 1
	assert_eq(result.primary_damage, 1, "Slashing should apply full armor")


func test_calculate_damage_with_types_secondary_fire_damage() -> void:
	# Given: Attacker with base damage 5, defender with no armor/resistance
	var attacker = _create_mock_entity({"STR": 10})
	attacker.base_damage = 5
	var defender = _create_mock_entity({})
	defender.armor = 0

	# Enchanted weapon with fire secondary damage
	var weapon = MockWeapon.new()
	weapon.damage_type = "slashing"
	weapon.secondary_damage_type = "fire"
	weapon.secondary_damage_bonus = 3

	# When: Calculating damage
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, weapon)

	# Then: Primary = 5, Secondary = 3
	assert_eq(result.primary_damage, 5, "Primary slashing damage should be 5")
	assert_eq(result.secondary_damage, 3, "Secondary fire damage should be 3")


func test_calculate_damage_with_types_resistant_to_primary() -> void:
	# Given: Defender with 50% fire resistance
	var attacker = _create_mock_entity({"STR": 10})
	attacker.base_damage = 10
	var defender = _create_mock_entity({})
	defender.armor = 0
	defender.elemental_resistances["fire"] = -50  # -50 = 50% resistant

	# Weapon with fire damage
	var weapon = MockWeapon.new()
	weapon.damage_type = "fire"

	# When: Calculating damage
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, weapon)

	# Then: 50% resistance = 50% damage
	assert_eq(result.primary_damage, 5, "50% fire resistance should halve damage")
	assert_true(result.resisted, "Should be marked as resisted")


func test_calculate_damage_with_types_vulnerable_to_secondary() -> void:
	# Given: Defender with 50% ice vulnerability
	var attacker = _create_mock_entity({"STR": 10})
	attacker.base_damage = 6
	var defender = _create_mock_entity({})
	defender.armor = 0
	defender.elemental_resistances["ice"] = 50  # +50 = 50% vulnerable

	# Weapon with frost secondary damage
	var weapon = MockWeapon.new()
	weapon.damage_type = "slashing"
	weapon.secondary_damage_type = "ice"
	weapon.secondary_damage_bonus = 4

	# When: Calculating damage
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, weapon)

	# Then: Primary = 6, Secondary = 4 * 1.5 = 6
	assert_eq(result.primary_damage, 6, "Primary slashing damage should be 6")
	assert_eq(result.secondary_damage, 6, "Secondary ice damage should be 6 (4 * 1.5)")
	assert_true(result.vulnerable, "Should be marked as vulnerable")


func test_calculate_damage_with_types_immune_to_damage() -> void:
	# Given: Defender immune to fire
	var attacker = _create_mock_entity({"STR": 10})
	attacker.base_damage = 10
	var defender = _create_mock_entity({})
	defender.armor = 0
	defender.elemental_resistances["fire"] = -100  # -100 = immune

	# Weapon with fire damage
	var weapon = MockWeapon.new()
	weapon.damage_type = "fire"

	# When: Calculating damage
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, weapon)

	# Then: Immune = 0 damage
	assert_eq(result.primary_damage, 0, "Immune should deal 0 damage")
	assert_true(result.resisted, "Should be marked as resisted")


func test_calculate_damage_with_types_null_weapon_defaults_bludgeoning() -> void:
	# Given: Unarmed attack (no weapon)
	var attacker = _create_mock_entity({"STR": 10})
	attacker.base_damage = 2
	var defender = _create_mock_entity({})
	defender.armor = 0

	# When: Calculating damage with null weapon
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, null)

	# Then: Default to bludgeoning, damage = 2
	assert_eq(result.primary_damage, 2, "Unarmed should deal base damage")
	assert_eq(result.secondary_damage, 0, "No secondary damage")


func test_calculate_damage_with_types_minimum_one_damage() -> void:
	# Given: Low damage vs high armor, not resisted
	var attacker = _create_mock_entity({"STR": 10})
	attacker.base_damage = 1
	var defender = _create_mock_entity({})
	defender.armor = 10  # High armor

	var weapon = MockWeapon.new()
	weapon.damage_type = "slashing"

	# When: Calculating damage
	var result = CombatSystemClass.calculate_damage_with_types(attacker, defender, weapon)

	# Then: Minimum 1 damage when not resisted
	assert_eq(result.primary_damage, 1, "Should deal minimum 1 damage when not resisted")


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
	var creature_type: String = "humanoid"
	var elemental_resistances: Dictionary = {
		"slashing": 0,
		"piercing": 0,
		"bludgeoning": 0,
		"fire": 0,
		"ice": 0,
		"lightning": 0,
		"poison": 0,
		"acid": 0,
		"necrotic": 0,
		"radiant": 0
	}

	func take_damage(amount: int, _source: String = "", _method: String = "") -> void:
		current_health -= amount
		if current_health <= 0:
			is_alive = false

	func get_effective_attribute(attr_name: String) -> int:
		return attributes.get(attr_name, 10)

	func heal(amount: int) -> void:
		current_health = min(current_health + amount, max_health)

	func get_active_effects() -> Array:
		return []


class MockWeapon extends RefCounted:
	var name: String = "Mock Weapon"
	var damage_type: String = "bludgeoning"
	var secondary_damage_type: String = ""
	var secondary_damage_bonus: int = 0
	var damage_bonus: int = 0
