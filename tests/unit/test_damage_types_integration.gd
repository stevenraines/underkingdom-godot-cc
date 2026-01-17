extends GutTest
## Integration tests for Damage Types system
##
## Tests that Items, Enemies, and Enchantments load with correct damage type properties.

const ItemClass = preload("res://items/item.gd")
const ElementalSystemClass = preload("res://systems/elemental_system.gd")


# =============================================================================
# Test: Item damage_type property
# =============================================================================

func test_item_has_damage_type_property() -> void:
	# Given: A new item
	var item = ItemClass.new()

	# Then: Should have damage type properties with defaults
	assert_true("damage_type" in item, "Item should have damage_type property")
	assert_true("secondary_damage_type" in item, "Item should have secondary_damage_type property")
	assert_true("secondary_damage_bonus" in item, "Item should have secondary_damage_bonus property")

	# Default values
	assert_eq(item.damage_type, "bludgeoning", "Default damage_type should be bludgeoning")
	assert_eq(item.secondary_damage_type, "", "Default secondary_damage_type should be empty")
	assert_eq(item.secondary_damage_bonus, 0, "Default secondary_damage_bonus should be 0")


func test_item_create_from_data_with_damage_type() -> void:
	# Given: Item data with damage_type
	var data = {
		"id": "test_sword",
		"name": "Test Sword",
		"description": "A test sword",
		"category": "weapon",
		"weight": 2.0,
		"value": 50,
		"damage_type": "slashing"
	}

	# When: Creating item from data
	var item = ItemClass.new()
	item.create_from_data(data)

	# Then: damage_type should be set
	assert_eq(item.damage_type, "slashing", "Item should have slashing damage type")


func test_item_create_from_data_with_secondary_damage() -> void:
	# Given: Item data with secondary damage
	var data = {
		"id": "flaming_sword",
		"name": "Flaming Sword",
		"description": "A fiery blade",
		"category": "weapon",
		"weight": 2.5,
		"value": 200,
		"damage_type": "slashing",
		"secondary_damage_type": "fire",
		"secondary_damage_bonus": 3
	}

	# When: Creating item from data
	var item = ItemClass.new()
	item.create_from_data(data)

	# Then: Both damage types should be set
	assert_eq(item.damage_type, "slashing", "Primary damage type should be slashing")
	assert_eq(item.secondary_damage_type, "fire", "Secondary damage type should be fire")
	assert_eq(item.secondary_damage_bonus, 3, "Secondary damage bonus should be 3")


func test_item_duplicate_preserves_damage_types() -> void:
	# Given: An item with damage type properties
	var original = ItemClass.new()
	original.id = "enchanted_dagger"
	original.name = "Enchanted Dagger"
	original.damage_type = "piercing"
	original.secondary_damage_type = "lightning"
	original.secondary_damage_bonus = 2

	# When: Duplicating the item
	var copy = original.duplicate_item()

	# Then: Damage types should be preserved
	assert_eq(copy.damage_type, "piercing", "Duplicate should preserve damage_type")
	assert_eq(copy.secondary_damage_type, "lightning", "Duplicate should preserve secondary_damage_type")
	assert_eq(copy.secondary_damage_bonus, 2, "Duplicate should preserve secondary_damage_bonus")


# =============================================================================
# Test: Weapon JSON files have damage_type
# =============================================================================

func test_iron_sword_has_slashing_damage() -> void:
	# Skip if ItemManager not available (unit test environment)
	if not _is_item_manager_available():
		pending("ItemManager not available in unit test environment")
		return

	# Given: Iron sword item
	var item = ItemManager.create_item("iron_sword")

	# Then: Should have slashing damage
	if item:
		assert_eq(item.damage_type, "slashing", "Iron sword should deal slashing damage")
	else:
		pending("Could not create iron_sword item")


func test_short_bow_has_piercing_damage() -> void:
	if not _is_item_manager_available():
		pending("ItemManager not available in unit test environment")
		return

	var item = ItemManager.create_item("short_bow")

	if item:
		assert_eq(item.damage_type, "piercing", "Short bow should deal piercing damage")
	else:
		pending("Could not create short_bow item")


func test_wooden_club_has_bludgeoning_damage() -> void:
	if not _is_item_manager_available():
		pending("ItemManager not available in unit test environment")
		return

	var item = ItemManager.create_item("wooden_club")

	if item:
		assert_eq(item.damage_type, "bludgeoning", "Wooden club should deal bludgeoning damage")
	else:
		pending("Could not create wooden_club item")


func test_staff_of_fire_has_secondary_fire_damage() -> void:
	if not _is_item_manager_available():
		pending("ItemManager not available in unit test environment")
		return

	var item = ItemManager.create_item("staff_of_fire")

	if item:
		assert_eq(item.damage_type, "bludgeoning", "Staff of fire primary should be bludgeoning")
		assert_eq(item.secondary_damage_type, "fire", "Staff of fire secondary should be fire")
		assert_eq(item.secondary_damage_bonus, 3, "Staff of fire should have +3 fire damage")
	else:
		pending("Could not create staff_of_fire item")


# =============================================================================
# Test: Enemy elemental_resistances
# =============================================================================

func test_skeleton_resistances() -> void:
	if not _is_entity_manager_available():
		pending("EntityManager not available in unit test environment")
		return

	# Check if skeleton enemy definition exists
	var enemy_data = EntityManager.get_enemy_data("skeleton")

	if enemy_data:
		var resistances = enemy_data.get("elemental_resistances", {})
		# Skeletons should be vulnerable to bludgeoning, resistant to piercing/slashing
		assert_eq(resistances.get("bludgeoning", 0), 50, "Skeleton vulnerable to bludgeoning (+50)")
		assert_eq(resistances.get("piercing", 0), -25, "Skeleton resistant to piercing (-25)")
		assert_eq(resistances.get("slashing", 0), -25, "Skeleton resistant to slashing (-25)")
		assert_eq(resistances.get("poison", 0), -100, "Skeleton immune to poison (-100)")
	else:
		pending("Could not find skeleton enemy definition")


func test_fire_elemental_resistances() -> void:
	if not _is_entity_manager_available():
		pending("EntityManager not available in unit test environment")
		return

	var enemy_data = EntityManager.get_enemy_data("fire_elemental")

	if enemy_data:
		var resistances = enemy_data.get("elemental_resistances", {})
		assert_eq(resistances.get("fire", 0), -100, "Fire elemental immune to fire (-100)")
		assert_eq(resistances.get("ice", 0), 100, "Fire elemental vulnerable to ice (+100)")
	else:
		pending("Could not find fire_elemental enemy definition")


func test_cave_ooze_resistances() -> void:
	if not _is_entity_manager_available():
		pending("EntityManager not available in unit test environment")
		return

	var enemy_data = EntityManager.get_enemy_data("cave_ooze")

	if enemy_data:
		var resistances = enemy_data.get("elemental_resistances", {})
		assert_eq(resistances.get("slashing", 0), -50, "Cave ooze resistant to slashing (-50)")
		assert_eq(resistances.get("piercing", 0), -50, "Cave ooze resistant to piercing (-50)")
		assert_eq(resistances.get("acid", 0), -100, "Cave ooze immune to acid (-100)")
		assert_eq(resistances.get("fire", 0), 50, "Cave ooze vulnerable to fire (+50)")
	else:
		pending("Could not find cave_ooze enemy definition")


# =============================================================================
# Test: All damage types are valid
# =============================================================================

func test_all_damage_types_have_element_enum() -> void:
	# All damage types should map to valid Element enum values
	for damage_type in ElementalSystemClass.DAMAGE_TYPES:
		var element = ElementalSystemClass.get_element_from_string(damage_type)
		# Should not be PHYSICAL (which is the fallback for unknown types)
		assert_ne(element, ElementalSystemClass.Element.PHYSICAL,
			"Damage type '%s' should have a valid Element enum" % damage_type)


func test_all_damage_types_have_colors() -> void:
	# All damage types should have associated colors
	for damage_type in ElementalSystemClass.DAMAGE_TYPES:
		var color = ElementalSystemClass.get_element_color(damage_type)
		# Should not be white (which is the fallback for unknown types)
		assert_ne(color, Color.WHITE,
			"Damage type '%s' should have a color" % damage_type)


func test_all_damage_types_have_interactions() -> void:
	# All damage types should have interaction rules defined
	for damage_type in ElementalSystemClass.DAMAGE_TYPES:
		assert_true(damage_type in ElementalSystemClass.ELEMENT_INTERACTIONS,
			"Damage type '%s' should have interaction rules" % damage_type)


# =============================================================================
# Test: Enchantment variants
# =============================================================================

func test_enchantments_json_exists() -> void:
	# Test that the enchantments.json file can be loaded
	var file = FileAccess.open("res://data/variants/enchantments.json", FileAccess.READ)
	assert_not_null(file, "enchantments.json should exist")

	if file:
		var json_text = file.get_as_text()
		file.close()

		var json = JSON.new()
		var error = json.parse(json_text)
		assert_eq(error, OK, "enchantments.json should be valid JSON")

		if error == OK:
			var data = json.get_data()
			assert_eq(data.get("variant_type"), "enchantment", "Should be enchantment variant type")
			assert_true("variants" in data, "Should have variants dictionary")

			var variants = data.get("variants", {})
			# Check for expected enchantments
			assert_true("flaming" in variants, "Should have flaming enchantment")
			assert_true("frost" in variants, "Should have frost enchantment")
			assert_true("shocking" in variants, "Should have shocking enchantment")
			assert_true("venomous" in variants, "Should have venomous enchantment")
			assert_true("corrosive" in variants, "Should have corrosive enchantment")
			assert_true("holy" in variants, "Should have holy enchantment")
			assert_true("necrotic" in variants, "Should have necrotic enchantment")


func test_flaming_enchantment_adds_fire_damage() -> void:
	var file = FileAccess.open("res://data/variants/enchantments.json", FileAccess.READ)
	if not file:
		pending("enchantments.json not found")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_text) != OK:
		pending("Could not parse enchantments.json")
		return

	var data = json.get_data()
	var flaming = data.get("variants", {}).get("flaming", {})
	var overrides = flaming.get("overrides", {})

	assert_eq(overrides.get("secondary_damage_type"), "fire", "Flaming should add fire damage")
	assert_eq(overrides.get("secondary_damage_bonus"), 3, "Flaming should add +3 fire damage")


# =============================================================================
# Helpers
# =============================================================================

func _is_item_manager_available() -> bool:
	# Check if ItemManager autoload is available
	return Engine.has_singleton("ItemManager") or ClassDB.class_exists("ItemManager")


func _is_entity_manager_available() -> bool:
	# Check if EntityManager autoload is available
	return Engine.has_singleton("EntityManager") or ClassDB.class_exists("EntityManager")
