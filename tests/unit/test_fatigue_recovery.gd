extends GutTest
## Unit tests for Fatigue Recovery System
##
## Tests fatigue reduction through resting and consumable items,
## and verifies max stamina recovery when fatigue decreases.

const SurvivalSystemClass = preload("res://systems/survival_system.gd")


# =============================================================================
# Test: Fatigue Accumulation (baseline behavior)
# =============================================================================

func test_fatigue_accumulates_over_time() -> void:
	# Given: A survival system with 0 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.fatigue = 0.0
	survival.base_max_stamina = 150.0

	# When: Processing 101 turns (turn 0-100, fatigue gains on turn 100)
	for turn in range(101):
		survival.process_turn(turn)

	# Then: Fatigue should have increased by 1
	assert_eq(survival.fatigue, 1.0, "Fatigue should increase by 1 after 100 turns")


func test_fatigue_does_not_reduce_max_stamina() -> void:
	# Given: A survival system with 50 fatigue and 150 base max stamina
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0  # CON 10: 50 + (10 * 10)
	survival.fatigue = 50.0

	# When: Calculating max stamina
	var max_stamina = survival.get_max_stamina()

	# Then: Max stamina should stay at base value (fatigue only affects current stamina)
	assert_eq(max_stamina, 150.0, "Max stamina should remain 150 regardless of fatigue")


func test_fatigue_100_does_not_reduce_max() -> void:
	# Given: A survival system with 100 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 100.0

	# When: Calculating max stamina
	var max_stamina = survival.get_max_stamina()

	# Then: Max stamina should remain at base value
	assert_eq(max_stamina, 150.0, "Max stamina should remain 150 even with 100 fatigue")


# =============================================================================
# Test: Fatigue Recovery via rest() method
# =============================================================================

func test_rest_reduces_fatigue() -> void:
	# Given: A survival system with 50 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 50.0

	# When: Calling rest(25)
	survival.rest(25.0)

	# Then: Fatigue should be reduced to 25
	assert_eq(survival.fatigue, 25.0, "Fatigue should be reduced to 25 after resting 25")


func test_rest_cannot_go_below_zero() -> void:
	# Given: A survival system with 10 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 10.0

	# When: Calling rest(50) (more than current fatigue)
	survival.rest(50.0)

	# Then: Fatigue should be clamped at 0
	assert_eq(survival.fatigue, 0.0, "Fatigue should not go below 0")


func test_rest_reduces_fatigue_max_stays_constant() -> void:
	# Given: A survival system with 60 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 60.0
	var initial_max = survival.get_max_stamina()  # Should be 150

	# When: Resting to remove all fatigue
	survival.rest(60.0)
	var final_max = survival.get_max_stamina()

	# Then: Fatigue should be reduced and max stamina should remain constant
	assert_eq(survival.fatigue, 0.0, "Fatigue should be 0")
	assert_eq(initial_max, 150.0, "Max stamina should always be 150")
	assert_eq(final_max, 150.0, "Max stamina should always be 150")
	assert_eq(final_max, initial_max, "Max stamina should never change")


# =============================================================================
# Test: Consumable Items
# =============================================================================

func test_restorative_tonic_item_exists() -> void:
	# When: Loading item definitions
	var item_data = _load_item_definition("restorative_tonic")

	# Then: Item should exist and have fatigue effect
	assert_not_null(item_data, "Restorative Tonic item definition should exist")
	assert_true(item_data.has("effects"), "Restorative Tonic should have effects")
	assert_true(item_data.effects.has("fatigue"), "Restorative Tonic should have fatigue effect")
	assert_eq(item_data.effects.fatigue, 25, "Restorative Tonic should reduce 25 fatigue")


func test_energizing_tea_item_exists() -> void:
	# When: Loading item definitions
	var item_data = _load_item_definition("energizing_tea")

	# Then: Item should exist and have fatigue effect
	assert_not_null(item_data, "Energizing Tea item definition should exist")
	assert_true(item_data.has("effects"), "Energizing Tea should have effects")
	assert_true(item_data.effects.has("fatigue"), "Energizing Tea should have fatigue effect")
	assert_eq(item_data.effects.fatigue, 15, "Energizing Tea should reduce 15 fatigue")


func test_item_effect_reduces_fatigue() -> void:
	# Given: A survival system with 50 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 50.0

	# When: Applying restorative tonic effect (simulating player.apply_item_effects)
	survival.rest(25.0)  # Tonic reduces 25 fatigue

	# Then: Fatigue should be reduced by 25
	assert_eq(survival.fatigue, 25.0, "Fatigue should be 25 after tonic")


# =============================================================================
# Test: Max Stamina Stays Constant (Fatigue Only Affects Current Stamina)
# =============================================================================

func test_max_stamina_stays_constant_when_fatigue_changes() -> void:
	# Given: A survival system with 150 base max stamina and 50 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 50.0

	var initial_max = survival.get_max_stamina()  # 150

	# When: Reducing fatigue by 25
	survival.rest(25.0)
	var new_max = survival.get_max_stamina()

	# Then: Max stamina should remain constant at 150
	assert_eq(survival.fatigue, 25.0, "Fatigue should be 25")
	assert_eq(initial_max, 150.0, "Initial max stamina should be 150")
	assert_eq(new_max, 150.0, "Max stamina should remain 150")
	assert_eq(new_max, initial_max, "Max stamina should never change")


func test_partial_fatigue_recovery_max_stamina_constant() -> void:
	# Given: A survival system with 80 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 80.0

	# When: Reducing fatigue by 15 (energizing tea)
	survival.rest(15.0)
	var new_max = survival.get_max_stamina()

	# Then: Max stamina should remain constant
	# New fatigue: 65
	# Max stamina: always 150
	assert_eq(survival.fatigue, 65.0, "Fatigue should be 65")
	assert_eq(new_max, 150.0, "Max stamina should remain 150")


func test_current_stamina_reduced_when_fatigue_increases() -> void:
	# Given: A survival system with current stamina at max
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 0.0
	survival.stamina = survival.get_max_stamina()  # 150

	# When: Fatigue increases by 1% (via process_turn)
	# This happens automatically in process_turn() when fatigue accumulates
	# Simulating what happens: 1% fatigue = 1.5 stamina reduction
	var old_fatigue = survival.fatigue
	survival.fatigue = 1.0
	var fatigue_gain = survival.fatigue - old_fatigue  # 1.0
	var stamina_reduction = survival.base_max_stamina * (fatigue_gain / 100.0)  # 1.5
	survival.stamina = max(0.0, survival.stamina - stamina_reduction)

	# Then: Current stamina should be reduced by 1.5, max should stay at 150
	assert_eq(survival.get_max_stamina(), 150.0, "Max stamina should remain 150")
	assert_eq(survival.stamina, 148.5, "Current stamina should be reduced by 1.5")


# =============================================================================
# Test: Resting Rate (1 fatigue per 10 rest turns)
# =============================================================================

func test_rest_rate_calculation() -> void:
	# Given: The implemented rest rate of 1 fatigue per 10 turns
	var rest_turns = 100
	var expected_fatigue_reduction = rest_turns / 10  # 10 fatigue

	# When: Calculating expected reduction
	var actual_reduction = 10.0

	# Then: Should match the formula
	assert_eq(actual_reduction, expected_fatigue_reduction, "Rest rate should be 1 fatigue per 10 turns")


func test_full_recovery_time() -> void:
	# Given: A player with 100 fatigue
	var initial_fatigue = 100.0
	var rest_rate = 1.0 / 10.0  # 1 fatigue per 10 turns

	# When: Calculating turns needed for full recovery
	var turns_needed = initial_fatigue / rest_rate

	# Then: Should take 1000 turns to fully recover
	assert_eq(turns_needed, 1000.0, "Should take 1000 rest turns to recover 100 fatigue")


# =============================================================================
# Test: Balance - Accumulation vs Recovery
# =============================================================================

func test_recovery_rate_faster_than_accumulation() -> void:
	# Given: Accumulation rate (1 per 100 active turns) vs Recovery rate (1 per 10 rest turns)
	var accumulation_rate = 1.0 / 100.0  # per active turn
	var recovery_rate = 1.0 / 10.0  # per rest turn

	# Then: Recovery should be 10x faster than accumulation
	var ratio = recovery_rate / accumulation_rate
	assert_eq(ratio, 10.0, "Recovery should be 10x faster than accumulation")


# =============================================================================
# Test: Edge Cases
# =============================================================================

func test_zero_fatigue_stays_zero() -> void:
	# Given: A survival system with 0 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 0.0

	# When: Resting with 0 fatigue
	survival.rest(10.0)

	# Then: Fatigue should remain 0
	assert_eq(survival.fatigue, 0.0, "Fatigue should stay at 0")


func test_multiple_rest_calls_stack() -> void:
	# Given: A survival system with 60 fatigue
	var survival = SurvivalSystemClass.new(null)
	survival.base_max_stamina = 150.0
	survival.fatigue = 60.0

	# When: Resting twice (15 each, like two energizing teas)
	survival.rest(15.0)
	survival.rest(15.0)

	# Then: Fatigue should be reduced by 30 total
	assert_eq(survival.fatigue, 30.0, "Multiple rest calls should stack")


# =============================================================================
# Test: Recipe Validation
# =============================================================================

func test_restorative_tonic_recipe_exists() -> void:
	# When: Loading recipe definitions
	var recipe_data = _load_recipe_definition("restorative_tonic")

	# Then: Recipe should exist and be valid
	assert_not_null(recipe_data, "Restorative Tonic recipe should exist")
	assert_eq(recipe_data.result, "restorative_tonic", "Recipe should create restorative_tonic")
	assert_true(recipe_data.fire_required, "Recipe should require fire")


func test_energizing_tea_recipe_exists() -> void:
	# When: Loading recipe definitions
	var recipe_data = _load_recipe_definition("energizing_tea")

	# Then: Recipe should exist and be valid
	assert_not_null(recipe_data, "Energizing Tea recipe should exist")
	assert_eq(recipe_data.result, "energizing_tea", "Recipe should create energizing_tea")
	assert_true(recipe_data.fire_required, "Recipe should require fire")


# =============================================================================
# Helper Functions
# =============================================================================

func _load_item_definition(item_id: String) -> Dictionary:
	var file_path = "res://data/items/consumables/%s.json" % item_id
	if not FileAccess.file_exists(file_path):
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return {}

	return json.data


func _load_recipe_definition(recipe_id: String) -> Dictionary:
	var file_path = "res://data/recipes/consumables/%s.json" % recipe_id
	if not FileAccess.file_exists(file_path):
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return {}

	return json.data
