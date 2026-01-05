# Underkingdom Testing Implementation Plan

## Overview

This document outlines the comprehensive testing strategy for the Underkingdom roguelike project using GUT (Godot Unit Test) v9.5.0.

## Test Framework Setup

### Installation (Completed)
- GUT v9.5.0 installed in `addons/gut/`
- Plugin enabled in `project.godot`
- Configuration in `.gutconfig.json`
- Test directories: `tests/unit/` and `tests/integration/`

### Running Tests

**From Godot Editor:**
1. Open Godot and the project
2. Bottom panel shows "GUT" tab
3. Click "Run All" or select specific tests

**From Command Line:**
```bash
godot --headless -s addons/gut/gut_cmdln.gd
```

**Test File Naming Convention:**
- All test files must be prefixed with `test_`
- Example: `test_combat_system.gd`

---

## Test Categories

### Priority Levels
- **P0 (Critical)**: Core game loop, combat, survival - must work
- **P1 (High)**: Inventory, crafting, items - player-facing features
- **P2 (Medium)**: Generation, managers - important but less frequent issues
- **P3 (Low)**: Utilities, edge cases - nice to have

---

## Phase 1: Core Systems (P0) - 8 Test Files

### 1.1 CombatSystem Tests ✅ (Sample Created)
**File**: `tests/unit/test_combat_system.gd`
**Status**: Sample implementation complete

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_get_accuracy_*` | `get_accuracy()` | Verify 50 + (DEX × 2) formula |
| `test_get_evasion_*` | `get_evasion()` | Verify 5 + DEX formula |
| `test_calculate_damage_*` | `calculate_damage()` | Verify base + STR mod - armor |
| `test_are_adjacent_*` | `are_adjacent()` | Cardinal + diagonal adjacency |
| `test_are_cardinally_adjacent_*` | `are_cardinally_adjacent()` | Cardinal only |
| `test_get_attack_message_*` | `get_attack_message()` | Message formatting |
| `test_attempt_attack_*` | `attempt_attack()` | Full attack resolution |

**Mocking Required**: Entity class (attributes, take_damage)

---

### 1.2 RangedCombatSystem Tests
**File**: `tests/unit/test_ranged_combat_system.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_calculate_ranged_accuracy_*` | `calculate_ranged_accuracy()` | Range penalty calculation |
| `test_calculate_ranged_damage_*` | `calculate_ranged_damage()` | Ammo damage bonus |
| `test_has_line_of_sight_*` | `has_line_of_sight()` | LOS through tiles |
| `test_get_distance_*` | `get_distance()` | Chebyshev distance |
| `test_calculate_miss_landing_*` | `calculate_miss_landing()` | Miss offset calculation |

**Mocking Required**: Entity, MapManager.current_map

---

### 1.3 SurvivalSystem Tests
**File**: `tests/unit/test_survival_system.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_process_turn_hunger_drain` | `process_turn()` | 1 point per 20 turns |
| `test_process_turn_thirst_drain` | `process_turn()` | 1 point per 15 turns |
| `test_consume_stamina_*` | `consume_stamina()` | Stamina consumption |
| `test_regenerate_stamina_*` | `regenerate_stamina()` | Stamina recovery |
| `test_get_max_stamina_*` | `get_max_stamina()` | Fatigue reduction |
| `test_get_stat_modifiers_*` | `get_stat_modifiers()` | Penalty calculation |
| `test_eat_*` | `eat()` | Hunger restoration |
| `test_drink_*` | `drink()` | Thirst restoration |
| `test_get_hunger_state_*` | `get_hunger_state()` | State thresholds |
| `test_get_thirst_state_*` | `get_thirst_state()` | State thresholds |
| `test_temperature_effects_*` | `update_temperature()` | Hot/cold penalties |

**Mocking Required**: CalendarManager, owner entity

---

### 1.4 FOVSystem Tests
**File**: `tests/unit/test_fov_system.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_calculate_fov_empty_room` | `calculate_fov()` | Basic visibility |
| `test_calculate_fov_with_walls` | `calculate_fov()` | Wall blocking |
| `test_calculate_fov_corners` | `calculate_fov()` | Corner visibility |
| `test_calculate_visibility_*` | `calculate_visibility()` | Light radius integration |
| `test_invalidate_cache_*` | `invalidate_cache()` | Cache behavior |

**Mocking Required**: GameMap with tiles

---

### 1.5 TurnManager Tests
**File**: `tests/unit/test_turn_manager.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_advance_turn_*` | `advance_turn()` | Turn counter increment |
| `test_get_time_of_day_*` | `get_time_of_day()` | Time period calculation |
| `test_day_number_*` | Various | Day rollover |

**Note**: Integration test - uses actual autoload

---

### 1.6 Entity Tests
**File**: `tests/unit/test_entity.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_take_damage_*` | `take_damage()` | Health reduction |
| `test_heal_*` | `heal()` | Health restoration |
| `test_die_*` | `die()` | Death handling |
| `test_get_effective_attribute_*` | `get_effective_attribute()` | Modifier application |
| `test_apply_stat_modifiers_*` | `apply_stat_modifiers()` | Modifier stacking |

---

### 1.7 GameTile Tests
**File**: `tests/unit/test_game_tile.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_create_floor` | `create()` | Floor tile properties |
| `test_create_wall` | `create()` | Wall tile properties |
| `test_create_door` | `create()` | Door walkable/transparent |
| `test_create_water` | `create()` | Water tile properties |
| `test_lock_properties` | Various | Lock level, lock ID |

---

### 1.8 GameMap Tests
**File**: `tests/unit/test_game_map.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_get_tile_*` | `get_tile()` | Tile access |
| `test_set_tile_*` | `set_tile()` | Tile modification |
| `test_is_walkable_*` | `is_walkable()` | Movement validation |
| `test_is_transparent_*` | `is_transparent()` | LOS check |
| `test_fill_*` | `fill()` | Map initialization |

---

## Phase 2: Item & Inventory Systems (P1) - 5 Test Files

### 2.1 Item Tests
**File**: `tests/unit/test_item.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_create_from_data_*` | `create_from_data()` | Item instantiation |
| `test_get_total_weight_*` | `get_total_weight()` | Stack weight calculation |
| `test_can_stack_with_*` | `can_stack_with()` | Stacking validation |
| `test_add_to_stack_*` | `add_to_stack()` | Stack increase |
| `test_remove_from_stack_*` | `remove_from_stack()` | Stack decrease |
| `test_is_equippable_*` | `is_equippable()` | Equipment check |
| `test_can_equip_to_slot_*` | `can_equip_to_slot()` | Slot validation |
| `test_is_two_handed_*` | `is_two_handed()` | Two-hand detection |
| `test_is_thrown_weapon_*` | `is_thrown_weapon()` | Thrown weapon check |
| `test_use_consumable_*` | `use()` | Consumable effects |

---

### 2.2 ItemFactory Tests
**File**: `tests/unit/test_item_factory.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_create_item_basic` | `create_item()` | Basic item creation |
| `test_create_item_with_variants` | `create_item()` | Variant application |
| `test_create_default_item_*` | `create_default_item()` | Default variants |
| `test_is_valid_combination_*` | `is_valid_combination()` | Template + variant validation |
| `test_generate_item_id_*` | `generate_item_id()` | ID generation |
| `test_get_item_display_name_*` | `get_item_display_name()` | Name composition |
| `test_variant_modifier_multiply` | Various | 0.5 = 50% modifier |
| `test_variant_modifier_add` | Various | +2 modifier |
| `test_variant_modifier_override` | Various | Replace value |

**Mocking Required**: VariantManager

---

### 2.3 Inventory Tests
**File**: `tests/unit/test_inventory.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_add_item_*` | `add_item()` | Item addition |
| `test_add_item_stacking` | `add_item()` | Stack merging |
| `test_remove_item_*` | `remove_item()` | Item removal |
| `test_remove_item_by_id_*` | `remove_item_by_id()` | ID-based removal |
| `test_get_total_weight_*` | `get_total_weight()` | Weight calculation |
| `test_get_encumbrance_ratio_*` | `get_encumbrance_ratio()` | Ratio calculation |
| `test_get_encumbrance_penalty_*` | `get_encumbrance_penalty()` | Penalty tiers |
| `test_equip_item_*` | `equip_item()` | Equipment handling |
| `test_equip_two_handed_*` | `equip_item()` | Off-hand blocking |
| `test_use_item_*` | `use_item()` | Item usage |
| `test_has_item_*` | `has_item()` | Item check |
| `test_serialize_*` | `serialize()` | Save data |
| `test_deserialize_*` | `deserialize()` | Load data |

---

### 2.4 CraftingSystem Tests
**File**: `tests/unit/test_crafting_system.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_calculate_success_chance_*` | `calculate_success_chance()` | INT-based chance |
| `test_attempt_craft_success` | `attempt_craft()` | Successful craft |
| `test_attempt_craft_failure` | `attempt_craft()` | Failed craft |
| `test_attempt_craft_missing_ingredients` | `attempt_craft()` | Missing materials |
| `test_is_near_fire_*` | `is_near_fire()` | Fire proximity |
| `test_get_discovery_hint_*` | `get_discovery_hint()` | Hint generation |
| `test_attempt_experiment_*` | `attempt_experiment()` | Recipe discovery |

**Mocking Required**: Player, RecipeManager, StructureManager

---

### 2.5 HarvestSystem Tests
**File**: `tests/unit/test_harvest_system.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_has_required_tool_*` | `has_required_tool()` | Tool matching |
| `test_has_required_tool_priority` | `has_required_tool()` | Tool priority |
| `test_harvest_single_turn` | `harvest()` | Instant harvest |
| `test_harvest_multi_turn` | `harvest()` | Progress tracking |
| `test_harvest_yields_*` | `harvest()` | Yield generation |
| `test_process_renewable_resources` | `process_renewable_resources()` | Respawn logic |
| `test_serialize_renewable_*` | `serialize_renewable_resources()` | Save data |

---

## Phase 3: Generation Systems (P2) - 4 Test Files

### 3.1 SeededRandom Tests
**File**: `tests/unit/test_seeded_random.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_deterministic_randi` | `randi()` | Same seed = same sequence |
| `test_deterministic_randf` | `randf()` | Same seed = same sequence |
| `test_randi_range_bounds` | `randi_range()` | Within bounds |
| `test_randf_range_bounds` | `randf_range()` | Within bounds |
| `test_choice_*` | `choice()` | Array selection |
| `test_different_seeds_different_results` | Various | Seed variation |

---

### 3.2 WorldGenerator Tests
**File**: `tests/integration/test_world_generator.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_generate_overworld_deterministic` | `generate_overworld()` | Same seed = same map |
| `test_generate_overworld_dimensions` | `generate_overworld()` | 100x100 size |
| `test_generate_overworld_spawn_point` | `generate_overworld()` | Valid spawn location |
| `test_generate_overworld_town` | `generate_overworld()` | Town generation |
| `test_generate_overworld_dungeon_entrances` | `generate_overworld()` | Dungeon placement |

---

### 3.3 TownGenerator Tests
**File**: `tests/integration/test_town_generator.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_generate_town_dimensions` | Various | Town size |
| `test_generate_town_buildings` | Various | Building placement |
| `test_generate_town_npcs` | Various | NPC spawning |
| `test_generate_town_shops` | Various | Shop placement |

---

### 3.4 DungeonGenerator Tests
**File**: `tests/integration/test_dungeon_generator.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_generate_floor_deterministic` | Various | Same seed = same floor |
| `test_generate_floor_connectivity` | Various | All rooms connected |
| `test_generate_floor_stairs` | Various | Stair placement |
| `test_generate_floor_features` | Various | Feature spawning |
| `test_floor_depth_scaling` | Various | Difficulty scaling |

---

## Phase 4: Manager & Data Systems (P2) - 5 Test Files

### 4.1 ItemManager Tests
**File**: `tests/integration/test_item_manager.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_load_items_*` | `_load_definitions()` | JSON loading |
| `test_create_item_*` | `create_item()` | Item creation |
| `test_get_item_data_*` | `get_item_data()` | Data retrieval |
| `test_item_not_found` | Various | Missing item handling |

---

### 4.2 RecipeManager Tests
**File**: `tests/integration/test_recipe_manager.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_load_recipes_*` | Various | JSON loading |
| `test_get_recipe_*` | `get_recipe()` | Recipe retrieval |
| `test_find_recipe_by_ingredients_*` | `find_recipe_by_ingredients()` | Ingredient matching |

---

### 4.3 EntityManager Tests
**File**: `tests/integration/test_entity_manager.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_load_enemies_*` | Various | JSON loading |
| `test_spawn_enemy_*` | `spawn_enemy()` | Enemy creation |
| `test_get_enemy_data_*` | `get_enemy_data()` | Data retrieval |
| `test_process_entity_turns_*` | `process_entity_turns()` | Turn processing |

---

### 4.4 SaveManager Tests
**File**: `tests/integration/test_save_manager.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_save_game_*` | `save_game()` | Save creation |
| `test_load_game_*` | `load_game()` | Save loading |
| `test_save_slot_management` | Various | Slot operations |
| `test_save_data_integrity` | Various | Round-trip verification |
| `test_version_compatibility` | Various | Save version handling |

---

### 4.5 LootTableManager Tests
**File**: `tests/integration/test_loot_table_manager.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_load_loot_tables_*` | Various | JSON loading |
| `test_generate_loot_*` | `generate_loot()` | Loot generation |
| `test_loot_probability_*` | Various | Drop rates |
| `test_loot_count_range_*` | Various | Quantity ranges |

---

## Phase 5: Specialized Systems (P3) - 4 Test Files

### 5.1 FishingSystem Tests
**File**: `tests/unit/test_fishing_system.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_can_fish_*` | `can_fish()` | Fishing validation |
| `test_has_adjacent_water_*` | `has_adjacent_water()` | Water detection |
| `test_count_contiguous_water_*` | `_count_contiguous_water()` | Water body size |
| `test_roll_for_catch_*` | `_roll_for_catch()` | Catch probability |
| `test_session_management_*` | Various | Session tracking |

---

### 5.2 LockSystem Tests
**File**: `tests/unit/test_lock_system.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_unlock_with_key_*` | Various | Key matching |
| `test_unlock_with_skeleton_key_*` | Various | Skeleton key usage |
| `test_lock_level_*` | Various | Lock difficulty |

---

### 5.3 ShopSystem Tests
**File**: `tests/unit/test_shop_system.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_calculate_buy_price_*` | Various | CHA-based pricing |
| `test_calculate_sell_price_*` | Various | Sell value calculation |
| `test_can_afford_*` | Various | Gold check |
| `test_transaction_*` | Various | Buy/sell operations |

---

### 5.4 StructurePlacement Tests
**File**: `tests/unit/test_structure_placement.gd`

| Test Case | Method | Description |
|-----------|--------|-------------|
| `test_can_place_*` | Various | Placement validation |
| `test_footprint_collision_*` | Various | Overlap detection |
| `test_terrain_requirements_*` | Various | Ground type check |

---

## Implementation Order

### Week 1: Foundation
1. `test_combat_system.gd` ✅ (Sample complete)
2. `test_game_tile.gd`
3. `test_game_map.gd`
4. `test_entity.gd`

### Week 2: Core Combat & Survival
5. `test_ranged_combat_system.gd`
6. `test_survival_system.gd`
7. `test_fov_system.gd`
8. `test_turn_manager.gd`

### Week 3: Items
9. `test_item.gd`
10. `test_item_factory.gd`
11. `test_inventory.gd`

### Week 4: Crafting & Harvest
12. `test_crafting_system.gd`
13. `test_harvest_system.gd`
14. `test_seeded_random.gd`

### Week 5: Generation
15. `test_world_generator.gd`
16. `test_town_generator.gd`
17. `test_dungeon_generator.gd`

### Week 6: Managers
18. `test_item_manager.gd`
19. `test_recipe_manager.gd`
20. `test_entity_manager.gd`

### Week 7: Save & Specialized
21. `test_save_manager.gd`
22. `test_loot_table_manager.gd`
23. `test_fishing_system.gd`
24. `test_lock_system.gd`

### Week 8: Final
25. `test_shop_system.gd`
26. `test_structure_placement.gd`
27. Review and polish

---

## Test Writing Guidelines

### Test Structure (AAA Pattern)
```gdscript
func test_something_specific() -> void:
    # Arrange (Given)
    var entity = _create_mock_entity({"DEX": 15})

    # Act (When)
    var result = CombatSystem.get_accuracy(entity)

    # Assert (Then)
    assert_eq(result, 80, "DEX 15 should give 80% accuracy")
```

### Naming Convention
- Test files: `test_<system_name>.gd`
- Test functions: `test_<method>_<scenario>`
- Example: `test_get_accuracy_with_high_dex`

### Common Assertions
```gdscript
assert_eq(actual, expected, "message")      # Equality
assert_ne(actual, expected, "message")      # Not equal
assert_true(condition, "message")           # Boolean true
assert_false(condition, "message")          # Boolean false
assert_gt(a, b, "message")                  # Greater than
assert_lt(a, b, "message")                  # Less than
assert_between(value, low, high, "message") # Range check
assert_null(value, "message")               # Null check
assert_not_null(value, "message")           # Not null
assert_has(array, value, "message")         # Contains
```

### Mocking Autoloads
For tests that need autoloads, use GUT's doubling:
```gdscript
var _mock_event_bus

func before_each() -> void:
    _mock_event_bus = double(EventBus).new()
    # Configure stub responses

func after_each() -> void:
    _mock_event_bus = null
```

### Parameterized Tests
```gdscript
var params = ParameterFactory.named_parameters(
    ["dex", "expected"],
    [
        [5, 60],
        [10, 70],
        [15, 80],
        [20, 90]
    ]
)

func test_get_accuracy_parametrized(p = use_parameters(params)) -> void:
    var entity = _create_mock_entity({"DEX": p.dex})
    var result = CombatSystem.get_accuracy(entity)
    assert_eq(result, p.expected)
```

---

## CI/CD Integration

### GitHub Actions Workflow
```yaml
name: Run Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Download Godot
        run: |
          wget -q https://downloads.tuxfamily.org/godotengine/4.5/Godot_v4.5-stable_linux.x86_64.zip
          unzip Godot_v4.5-stable_linux.x86_64.zip
      - name: Run Tests
        run: |
          ./Godot_v4.5-stable_linux.x86_64 --headless -s addons/gut/gut_cmdln.gd -gexit
```

---

## Coverage Goals

| System Category | Target Coverage |
|-----------------|----------------|
| Combat Systems | 90%+ |
| Survival System | 85%+ |
| Item/Inventory | 85%+ |
| Generation | 70%+ |
| Managers | 75%+ |
| Specialized | 70%+ |

---

## Files Created

- `addons/gut/` - GUT v9.5.0 testing framework
- `.gutconfig.json` - GUT configuration
- `tests/unit/` - Unit test directory
- `tests/integration/` - Integration test directory
- `tests/unit/test_combat_system.gd` - Sample test file

---

## Next Steps

1. Open Godot to initialize the GUT plugin
2. Run the sample combat system tests
3. Begin implementing Phase 1 tests in order
4. Add CI/CD workflow after initial tests pass

---

## References

- [GUT Documentation](https://gut.readthedocs.io/)
- [GUT GitHub Repository](https://github.com/bitwes/Gut)
- [GUT Asset Library](https://godotengine.org/asset-library/asset/1709)
