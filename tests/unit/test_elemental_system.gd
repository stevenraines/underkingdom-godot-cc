extends GutTest
## Unit tests for ElementalSystem
##
## Tests damage type calculations, resistance modifiers, and special damage type effects.

const ElementalSystemClass = preload("res://systems/elemental_system.gd")


# =============================================================================
# Test: get_element_from_string()
# =============================================================================

func test_get_element_from_string_physical_types() -> void:
	# Physical damage types
	assert_eq(ElementalSystemClass.get_element_from_string("slashing"), ElementalSystemClass.Element.SLASHING)
	assert_eq(ElementalSystemClass.get_element_from_string("piercing"), ElementalSystemClass.Element.PIERCING)
	assert_eq(ElementalSystemClass.get_element_from_string("bludgeoning"), ElementalSystemClass.Element.BLUDGEONING)


func test_get_element_from_string_elemental_types() -> void:
	# Elemental damage types
	assert_eq(ElementalSystemClass.get_element_from_string("fire"), ElementalSystemClass.Element.FIRE)
	assert_eq(ElementalSystemClass.get_element_from_string("ice"), ElementalSystemClass.Element.ICE)
	assert_eq(ElementalSystemClass.get_element_from_string("cold"), ElementalSystemClass.Element.ICE, "cold should map to ICE")
	assert_eq(ElementalSystemClass.get_element_from_string("lightning"), ElementalSystemClass.Element.LIGHTNING)
	assert_eq(ElementalSystemClass.get_element_from_string("electric"), ElementalSystemClass.Element.LIGHTNING, "electric should map to LIGHTNING")
	assert_eq(ElementalSystemClass.get_element_from_string("poison"), ElementalSystemClass.Element.POISON)
	assert_eq(ElementalSystemClass.get_element_from_string("acid"), ElementalSystemClass.Element.ACID)


func test_get_element_from_string_magic_types() -> void:
	# Magic damage types
	assert_eq(ElementalSystemClass.get_element_from_string("necrotic"), ElementalSystemClass.Element.NECROTIC)
	assert_eq(ElementalSystemClass.get_element_from_string("dark"), ElementalSystemClass.Element.NECROTIC, "dark should map to NECROTIC")
	assert_eq(ElementalSystemClass.get_element_from_string("radiant"), ElementalSystemClass.Element.RADIANT)
	assert_eq(ElementalSystemClass.get_element_from_string("holy"), ElementalSystemClass.Element.RADIANT, "holy should map to RADIANT")


func test_get_element_from_string_case_insensitive() -> void:
	# Case insensitivity
	assert_eq(ElementalSystemClass.get_element_from_string("FIRE"), ElementalSystemClass.Element.FIRE)
	assert_eq(ElementalSystemClass.get_element_from_string("Fire"), ElementalSystemClass.Element.FIRE)
	assert_eq(ElementalSystemClass.get_element_from_string("SLASHING"), ElementalSystemClass.Element.SLASHING)


func test_get_element_from_string_unknown_returns_physical() -> void:
	# Unknown types should return PHYSICAL
	assert_eq(ElementalSystemClass.get_element_from_string("unknown"), ElementalSystemClass.Element.PHYSICAL)
	assert_eq(ElementalSystemClass.get_element_from_string(""), ElementalSystemClass.Element.PHYSICAL)
	assert_eq(ElementalSystemClass.get_element_from_string("magic"), ElementalSystemClass.Element.PHYSICAL)


# =============================================================================
# Test: get_element_name()
# =============================================================================

func test_get_element_name_physical_types() -> void:
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.SLASHING), "slashing")
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.PIERCING), "piercing")
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.BLUDGEONING), "bludgeoning")


func test_get_element_name_elemental_types() -> void:
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.FIRE), "fire")
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.ICE), "ice")
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.LIGHTNING), "lightning")
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.POISON), "poison")
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.ACID), "acid")


func test_get_element_name_magic_types() -> void:
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.NECROTIC), "necrotic")
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.RADIANT), "radiant")


func test_get_element_name_fallback() -> void:
	assert_eq(ElementalSystemClass.get_element_name(ElementalSystemClass.Element.PHYSICAL), "physical")


# =============================================================================
# Test: get_element_color()
# =============================================================================

func test_get_element_color_physical_types() -> void:
	assert_eq(ElementalSystemClass.get_element_color("slashing"), Color.SILVER)
	assert_eq(ElementalSystemClass.get_element_color("piercing"), Color.LIGHT_GRAY)
	assert_eq(ElementalSystemClass.get_element_color("bludgeoning"), Color.GRAY)


func test_get_element_color_elemental_types() -> void:
	assert_eq(ElementalSystemClass.get_element_color("fire"), Color.ORANGE_RED)
	assert_eq(ElementalSystemClass.get_element_color("ice"), Color.CYAN)
	assert_eq(ElementalSystemClass.get_element_color("cold"), Color.CYAN, "cold should have same color as ice")
	assert_eq(ElementalSystemClass.get_element_color("lightning"), Color.YELLOW)
	assert_eq(ElementalSystemClass.get_element_color("poison"), Color.GREEN)
	assert_eq(ElementalSystemClass.get_element_color("acid"), Color.LIME_GREEN)


func test_get_element_color_magic_types() -> void:
	assert_eq(ElementalSystemClass.get_element_color("necrotic"), Color.PURPLE)
	assert_eq(ElementalSystemClass.get_element_color("radiant"), Color.GOLD)
	assert_eq(ElementalSystemClass.get_element_color("holy"), Color.GOLD, "holy should have same color as radiant")


func test_get_element_color_unknown_returns_white() -> void:
	assert_eq(ElementalSystemClass.get_element_color("unknown"), Color.WHITE)
	assert_eq(ElementalSystemClass.get_element_color(""), Color.WHITE)


# =============================================================================
# Test: calculate_elemental_damage() - Resistance calculations
# =============================================================================

func test_calculate_damage_normal_resistance() -> void:
	# Given: An entity with 0 resistance (normal)
	var target = _create_mock_entity_with_resistances({})

	# When: Calculating fire damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "fire", target)

	# Then: Full damage should apply
	assert_eq(result.final_damage, 10, "Normal resistance should deal full damage")
	assert_false(result.resisted, "Should not be marked as resisted")
	assert_false(result.vulnerable, "Should not be marked as vulnerable")
	assert_false(result.immune, "Should not be marked as immune")


func test_calculate_damage_resistant() -> void:
	# Given: An entity with -50 fire resistance (50% resistant)
	var target = _create_mock_entity_with_resistances({"fire": -50})

	# When: Calculating fire damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "fire", target)

	# Then: Half damage should apply (modifier = 1.0 + (-50/100) = 0.5)
	assert_eq(result.final_damage, 5, "50% resistance should deal half damage")
	assert_true(result.resisted, "Should be marked as resisted")
	assert_false(result.vulnerable, "Should not be marked as vulnerable")


func test_calculate_damage_immune() -> void:
	# Given: An entity with -100 fire resistance (immune)
	var target = _create_mock_entity_with_resistances({"fire": -100})

	# When: Calculating fire damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "fire", target)

	# Then: No damage should apply
	assert_eq(result.final_damage, 0, "Immune should deal no damage")
	assert_true(result.immune, "Should be marked as immune")


func test_calculate_damage_vulnerable() -> void:
	# Given: An entity with +50 fire resistance (vulnerable)
	var target = _create_mock_entity_with_resistances({"fire": 50})

	# When: Calculating fire damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "fire", target)

	# Then: 150% damage should apply (modifier = 1.0 + (50/100) = 1.5)
	assert_eq(result.final_damage, 15, "50% vulnerability should deal 150% damage")
	assert_true(result.vulnerable, "Should be marked as vulnerable")
	assert_false(result.resisted, "Should not be marked as resisted")


func test_calculate_damage_double_vulnerable() -> void:
	# Given: An entity with +100 resistance (double vulnerable)
	var target = _create_mock_entity_with_resistances({"ice": 100})

	# When: Calculating ice damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "ice", target)

	# Then: Double damage should apply
	assert_eq(result.final_damage, 20, "100% vulnerability should deal double damage")
	assert_true(result.vulnerable, "Should be marked as vulnerable")


func test_calculate_damage_partial_resistance() -> void:
	# Given: An entity with -25 resistance (25% resistant)
	var target = _create_mock_entity_with_resistances({"lightning": -25})

	# When: Calculating lightning damage
	var result = ElementalSystemClass.calculate_elemental_damage(20, "lightning", target)

	# Then: 75% damage should apply (modifier = 1.0 + (-25/100) = 0.75)
	assert_eq(result.final_damage, 15, "25% resistance should deal 75% damage")
	# -25 is not below -50, so resisted flag should be false
	assert_false(result.resisted, "25% resistance should not trigger resisted message")


# =============================================================================
# Test: calculate_elemental_damage() - Creature type interactions
# =============================================================================

func test_poison_immunity_for_undead() -> void:
	# Given: An undead creature
	var target = _create_mock_entity_with_creature_type("undead")

	# When: Calculating poison damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "poison", target)

	# Then: No damage should apply
	assert_eq(result.final_damage, 0, "Undead should be immune to poison")
	assert_true(result.immune, "Should be marked as immune")
	assert_true("immune to poison" in result.message.to_lower(), "Message should mention poison immunity")


func test_poison_immunity_for_construct() -> void:
	# Given: A construct creature
	var target = _create_mock_entity_with_creature_type("construct")

	# When: Calculating poison damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "poison", target)

	# Then: No damage should apply
	assert_eq(result.final_damage, 0, "Constructs should be immune to poison")
	assert_true(result.immune, "Should be marked as immune")


func test_necrotic_heals_undead() -> void:
	# Given: An undead creature
	var target = _create_mock_entity_with_creature_type("undead")

	# When: Calculating necrotic damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "necrotic", target)

	# Then: Should heal instead of damage
	assert_eq(result.final_damage, 0, "Necrotic should not damage undead")
	assert_true(result.healed, "Should be marked as healed")
	assert_true("absorbs" in result.message.to_lower(), "Message should mention absorption")


func test_poison_affects_humanoid_normally() -> void:
	# Given: A humanoid creature with no poison resistance
	var target = _create_mock_entity_with_creature_type("humanoid")

	# When: Calculating poison damage
	var result = ElementalSystemClass.calculate_elemental_damage(10, "poison", target)

	# Then: Full damage should apply
	assert_eq(result.final_damage, 10, "Humanoids should take full poison damage")
	assert_false(result.immune, "Should not be immune")


# =============================================================================
# Test: DAMAGE_TYPES constant
# =============================================================================

func test_damage_types_constant_contains_all_types() -> void:
	# Verify all 10 damage types are in the constant
	assert_eq(ElementalSystemClass.DAMAGE_TYPES.size(), 10, "Should have exactly 10 damage types")

	# Physical
	assert_true("slashing" in ElementalSystemClass.DAMAGE_TYPES, "Should contain slashing")
	assert_true("piercing" in ElementalSystemClass.DAMAGE_TYPES, "Should contain piercing")
	assert_true("bludgeoning" in ElementalSystemClass.DAMAGE_TYPES, "Should contain bludgeoning")

	# Elemental
	assert_true("fire" in ElementalSystemClass.DAMAGE_TYPES, "Should contain fire")
	assert_true("ice" in ElementalSystemClass.DAMAGE_TYPES, "Should contain ice")
	assert_true("lightning" in ElementalSystemClass.DAMAGE_TYPES, "Should contain lightning")
	assert_true("poison" in ElementalSystemClass.DAMAGE_TYPES, "Should contain poison")
	assert_true("acid" in ElementalSystemClass.DAMAGE_TYPES, "Should contain acid")

	# Magic
	assert_true("necrotic" in ElementalSystemClass.DAMAGE_TYPES, "Should contain necrotic")
	assert_true("radiant" in ElementalSystemClass.DAMAGE_TYPES, "Should contain radiant")


# =============================================================================
# Test: ELEMENT_INTERACTIONS constant
# =============================================================================

func test_piercing_has_armor_effectiveness_half() -> void:
	# Piercing should bypass 50% of armor
	var piercing_info = ElementalSystemClass.ELEMENT_INTERACTIONS["piercing"]
	assert_eq(piercing_info.armor_effectiveness, 0.5, "Piercing should have 0.5 armor effectiveness")


func test_slashing_has_full_armor_effectiveness() -> void:
	var slashing_info = ElementalSystemClass.ELEMENT_INTERACTIONS["slashing"]
	assert_eq(slashing_info.armor_effectiveness, 1.0, "Slashing should have full armor effectiveness")


func test_bludgeoning_has_bonus_vs_skeletal() -> void:
	var bludgeoning_info = ElementalSystemClass.ELEMENT_INTERACTIONS["bludgeoning"]
	assert_true(bludgeoning_info.get("bonus_vs_skeletal", false), "Bludgeoning should have bonus vs skeletal")


func test_fire_strong_vs_ice() -> void:
	var fire_info = ElementalSystemClass.ELEMENT_INTERACTIONS["fire"]
	assert_true("ice" in fire_info.strong_vs, "Fire should be strong vs ice")


func test_radiant_strong_vs_necrotic() -> void:
	var radiant_info = ElementalSystemClass.ELEMENT_INTERACTIONS["radiant"]
	assert_true("necrotic" in radiant_info.strong_vs, "Radiant should be strong vs necrotic")
	assert_true(radiant_info.get("bonus_vs_undead", false), "Radiant should have bonus vs undead")


func test_poison_living_only() -> void:
	var poison_info = ElementalSystemClass.ELEMENT_INTERACTIONS["poison"]
	assert_true(poison_info.get("living_only", false), "Poison should only affect living creatures")


# =============================================================================
# Test: calculate_elemental_damage() with null target
# =============================================================================

func test_calculate_damage_null_target() -> void:
	# When: Calculating damage with null target
	var result = ElementalSystemClass.calculate_elemental_damage(10, "fire", null)

	# Then: Should return base damage unchanged
	assert_eq(result.final_damage, 10, "Null target should return base damage")
	assert_false(result.resisted, "Should not be resisted")
	assert_false(result.vulnerable, "Should not be vulnerable")
	assert_false(result.immune, "Should not be immune")


# =============================================================================
# Helper: Create mock entity with resistances
# =============================================================================

func _create_mock_entity_with_resistances(resistances: Dictionary) -> MockElementalEntity:
	var mock = MockElementalEntity.new()
	mock.elemental_resistances = {
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
	# Apply custom resistances
	for element in resistances:
		mock.elemental_resistances[element] = resistances[element]
	return mock


func _create_mock_entity_with_creature_type(type: String) -> MockElementalEntity:
	var mock = MockElementalEntity.new()
	mock.creature_type = type
	mock.elemental_resistances = {
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
	return mock


# =============================================================================
# Mock Entity class for elemental testing
# =============================================================================

class MockElementalEntity extends RefCounted:
	var name: String = "MockEntity"
	var creature_type: String = "humanoid"
	var elemental_resistances: Dictionary = {}
	var equipment: Dictionary = {}
	var current_health: int = 100
	var max_health: int = 100

	func heal(amount: int) -> void:
		current_health = min(current_health + amount, max_health)

	func has_method(method_name: String) -> bool:
		return method_name in ["heal", "take_damage", "get_active_effects"]

	func get_active_effects() -> Array:
		return []

	func take_damage(amount: int, _source: String = "", _element: String = "") -> void:
		current_health -= amount
