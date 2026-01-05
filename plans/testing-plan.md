# Underkingdom Unit Testing Plan

## Overview

This document outlines the comprehensive unit testing strategy for the Underkingdom roguelike using **GUT (Godot Unit Test)** framework v9.3.0.

## Testing Infrastructure

### Framework: GUT v9.3.0
- **Location**: `addons/gut/`
- **Config**: `.gutconfig.json`
- **Test Directory**: `test/unit/`

### Running Tests
```bash
# From command line
godot --headless -s addons/gut/gut_cmdln.gd

# From editor
# Click the GUT tab at bottom of editor, then "Run All"
```

### Test File Naming Convention
- Prefix: `test_`
- Location: `test/unit/`
- Example: `test_combat_system.gd`

---

## Test Categories by Priority

### Priority 1: Core Game Mechanics (Critical Path)

These systems directly affect gameplay and must be thoroughly tested.

#### 1.1 CombatSystem (`systems/combat_system.gd`)
**Type**: Static methods - Easy to test
**File**: `test/unit/test_combat_system.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_are_adjacent_cardinal` | `are_adjacent()` | Cardinal adjacency returns true |
| `test_are_adjacent_diagonal` | `are_adjacent()` | Diagonal adjacency returns true (8-way) |
| `test_are_adjacent_not_adjacent` | `are_adjacent()` | Distance 2+ returns false |
| `test_are_cardinally_adjacent` | `are_cardinally_adjacent()` | Only 4-way adjacency |
| `test_get_accuracy_base` | `get_accuracy()` | Base accuracy calculation |
| `test_get_accuracy_with_dex` | `get_accuracy()` | DEX modifier applied correctly |
| `test_get_evasion_base` | `get_evasion()` | Base evasion calculation |
| `test_get_evasion_with_dex` | `get_evasion()` | DEX modifier applied correctly |
| `test_calculate_damage_unarmed` | `calculate_damage()` | Unarmed damage formula |
| `test_calculate_damage_with_weapon` | `calculate_damage()` | Weapon damage bonus applied |
| `test_calculate_damage_with_armor` | `calculate_damage()` | Armor reduction applied |
| `test_calculate_damage_minimum` | `calculate_damage()` | Minimum 1 damage on hit |
| `test_attack_message_hit` | `get_attack_message()` | Hit message formatting |
| `test_attack_message_miss` | `get_attack_message()` | Miss message formatting |
| `test_attack_message_kill` | `get_attack_message()` | Kill message formatting |

#### 1.2 RangedCombatSystem (`systems/ranged_combat_system.gd`)
**Type**: Static methods - Easy to test
**File**: `test/unit/test_ranged_combat_system.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_get_distance` | `get_distance()` | Chebyshev distance calculation |
| `test_calculate_ranged_accuracy_base` | `calculate_ranged_accuracy()` | Base accuracy at optimal range |
| `test_calculate_ranged_accuracy_range_penalty` | `calculate_ranged_accuracy()` | -5% per tile beyond half range |
| `test_calculate_ranged_damage` | `calculate_ranged_damage()` | Weapon + ammo damage |
| `test_has_line_of_sight_clear` | `has_line_of_sight()` | Clear LOS returns true |
| `test_has_line_of_sight_blocked` | `has_line_of_sight()` | Wall blocks LOS |
| `test_calculate_miss_landing` | `calculate_miss_landing()` | Miss location calculation |

#### 1.3 SurvivalSystem (`systems/survival_system.gd`)
**Type**: Instance-based - Needs mock owner
**File**: `test/unit/test_survival_system.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_hunger_drain_rate` | `process_turn()` | 1 point per 20 turns |
| `test_thirst_drain_rate` | `process_turn()` | 1 point per 15 turns |
| `test_hunger_state_satiated` | `get_hunger_state()` | 80-100 = "satiated" |
| `test_hunger_state_hungry` | `get_hunger_state()` | 40-79 = "hungry" |
| `test_hunger_state_starving` | `get_hunger_state()` | 0-39 = "starving" |
| `test_thirst_state_hydrated` | `get_thirst_state()` | 80-100 = "hydrated" |
| `test_thirst_state_thirsty` | `get_thirst_state()` | 40-79 = "thirsty" |
| `test_thirst_state_dehydrated` | `get_thirst_state()` | 0-39 = "dehydrated" |
| `test_stamina_consumption` | `consume_stamina()` | Stamina decreases correctly |
| `test_stamina_regen` | `regenerate_stamina()` | Stamina regenerates |
| `test_fatigue_accumulation` | `consume_stamina()` | Fatigue increases when stamina hits 0 |
| `test_fatigue_reduces_max_stamina` | `get_max_stamina()` | Fatigue reduces max stamina |
| `test_eat_restores_hunger` | `eat()` | Eating increases hunger |
| `test_drink_restores_thirst` | `drink()` | Drinking increases thirst |
| `test_stat_modifiers_from_hunger` | `get_stat_modifiers()` | Hunger affects STR |
| `test_stat_modifiers_from_thirst` | `get_stat_modifiers()` | Thirst affects WIS |
| `test_temperature_comfortable` | `get_temperature_state()` | 15-25°C = "comfortable" |
| `test_temperature_cold` | `get_temperature_state()` | Below 15°C = "cold" |
| `test_temperature_hot` | `get_temperature_state()` | Above 25°C = "hot" |

---

### Priority 2: Inventory & Items

#### 2.1 Inventory (`systems/inventory_system.gd`)
**Type**: Instance-based - Easy to test
**File**: `test/unit/test_inventory_system.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_add_item_success` | `add_item()` | Item added to inventory |
| `test_add_item_stacking` | `add_item()` | Stackable items stack |
| `test_add_item_stacking_overflow` | `add_item()` | Overflow creates new stack |
| `test_remove_item` | `remove_item()` | Item removed from inventory |
| `test_remove_item_by_id` | `remove_item_by_id()` | Remove by ID and count |
| `test_get_total_weight` | `get_total_weight()` | Total weight calculated |
| `test_get_encumbrance_ratio` | `get_encumbrance_ratio()` | Weight/capacity ratio |
| `test_encumbrance_no_penalty` | `get_encumbrance_penalty()` | 0-75% = no penalty |
| `test_encumbrance_moderate` | `get_encumbrance_penalty()` | 75-100% = +50% stamina |
| `test_encumbrance_heavy` | `get_encumbrance_penalty()` | 100-125% = 2 turn movement |
| `test_encumbrance_overloaded` | `get_encumbrance_penalty()` | 125%+ = cannot move |
| `test_equip_item` | `equip_item()` | Item equipped to slot |
| `test_equip_two_handed_blocks_offhand` | `is_off_hand_blocked()` | Two-handed blocks off_hand |
| `test_has_item` | `has_item()` | Check item presence |
| `test_get_item_count` | `get_item_count()` | Count items by ID |
| `test_serialize_deserialize` | `serialize()` / `deserialize()` | Round-trip preserves data |

#### 2.2 Item (`items/item.gd`)
**Type**: Data class - Easy to test
**File**: `test/unit/test_item.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_create_from_data` | `create_from_data()` | Factory creates item |
| `test_get_total_weight` | `get_total_weight()` | weight × count |
| `test_can_stack_with_same` | `can_stack_with()` | Same stackable items stack |
| `test_can_stack_with_different` | `can_stack_with()` | Different items don't stack |
| `test_can_stack_unstackable` | `can_stack_with()` | Unstackable items don't stack |
| `test_add_to_stack` | `add_to_stack()` | Adds up to max_stack |
| `test_add_to_stack_overflow` | `add_to_stack()` | Returns overflow count |
| `test_remove_from_stack` | `remove_from_stack()` | Decreases count |
| `test_is_equippable` | `is_equippable()` | Has equip slots |
| `test_can_equip_to_slot` | `can_equip_to_slot()` | Valid slot check |
| `test_is_two_handed` | `is_two_handed()` | Two-handed detection |
| `test_get_weapon_damage` | `get_weapon_damage()` | Damage calculation |

#### 2.3 ItemFactory (`items/item_factory.gd`)
**Type**: Static methods - Needs VariantManager mock
**File**: `test/unit/test_item_factory.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_create_item_base` | `create_item()` | Creates base item from template |
| `test_create_item_with_material` | `create_item()` | Material variant applied |
| `test_create_item_with_quality` | `create_item()` | Quality variant applied |
| `test_create_item_stacked_variants` | `create_item()` | Multiple variants stack |
| `test_generate_item_id` | `generate_item_id()` | ID format correct |
| `test_get_item_display_name` | `get_item_display_name()` | Name composition |
| `test_is_valid_combination` | `is_valid_combination()` | Variant compatibility |
| `test_create_default_item` | `create_default_item()` | Default variants applied |

---

### Priority 3: Crafting & Harvesting

#### 3.1 CraftingSystem (`systems/crafting_system.gd`)
**Type**: Static methods - Needs manager mocks
**File**: `test/unit/test_crafting_system.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_calculate_success_chance_easy` | `calculate_success_chance()` | Difficulty 1, INT 10 |
| `test_calculate_success_chance_hard` | `calculate_success_chance()` | Difficulty 5, INT 5 |
| `test_calculate_success_chance_capped` | `calculate_success_chance()` | Max 95%, min 5% |
| `test_get_success_chance_string` | `get_success_chance_string()` | Display formatting |
| `test_get_discovery_hint_low_int` | `get_discovery_hint()` | INT < 5 gets vague hints |
| `test_get_discovery_hint_high_int` | `get_discovery_hint()` | INT >= 8 gets specific hints |

#### 3.2 HarvestSystem (`systems/harvest_system.gd`)
**Type**: Static with state - Moderate difficulty
**File**: `test/unit/test_harvest_system.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_has_required_tool_success` | `has_required_tool()` | Player has correct tool |
| `test_has_required_tool_failure` | `has_required_tool()` | Player lacks tool |
| `test_has_required_tool_priority` | `has_required_tool()` | Best tool selected |
| `test_get_resource` | `get_resource()` | Resource lookup |
| `test_serialize_renewable` | `serialize_renewable_resources()` | State saved |
| `test_deserialize_renewable` | `deserialize_renewable_resources()` | State restored |

---

### Priority 4: Map & FOV

#### 4.1 GameTile (`maps/game_tile.gd`)
**Type**: Data class - Trivial
**File**: `test/unit/test_game_tile.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_create_floor` | `create()` | Floor tile properties |
| `test_create_wall` | `create()` | Wall tile properties |
| `test_create_water` | `create()` | Water tile properties |
| `test_walkable_property` | properties | Walkability correct |
| `test_transparent_property` | properties | Transparency correct |

#### 4.2 GameMap (`maps/map.gd`)
**Type**: Data container - Easy
**File**: `test/unit/test_game_map.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_get_tile` | `get_tile()` | Tile retrieval |
| `test_set_tile` | `set_tile()` | Tile assignment |
| `test_is_walkable` | `is_walkable()` | Walkability check |
| `test_is_transparent` | `is_transparent()` | Transparency check |
| `test_fill` | `fill()` | Fill with tile type |
| `test_bounds_check` | `get_tile()` | Out of bounds handling |

#### 4.3 FOVSystem (`systems/fov_system.gd`)
**Type**: Static with cache - Needs mock map
**File**: `test/unit/test_fov_system.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_calculate_fov_open` | `calculate_fov()` | Open area visibility |
| `test_calculate_fov_walls` | `calculate_fov()` | Walls block vision |
| `test_calculate_fov_range` | `calculate_fov()` | Range limit respected |
| `test_fov_symmetry` | `calculate_fov()` | If A sees B, B sees A |
| `test_invalidate_cache` | `invalidate_cache()` | Cache cleared |
| `test_transform_tile` | `transform_tile()` | Octant transformation |

---

### Priority 5: Procedural Generation

#### 5.1 SeededRandom (`generation/seeded_random.gd`)
**Type**: Instance - Easy
**File**: `test/unit/test_seeded_random.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_deterministic` | all | Same seed = same sequence |
| `test_randi_range` | `randi_range()` | Within bounds |
| `test_randf_range` | `randf_range()` | Within bounds |
| `test_choice` | `choice()` | Returns array element |
| `test_different_seeds` | all | Different seeds differ |

#### 5.2 World Generation (Integration Tests)
**File**: `test/unit/test_world_generation.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_deterministic_overworld` | `generate_overworld()` | Same seed = same map |
| `test_deterministic_dungeon` | `generate_floor()` | Same seed = same floor |
| `test_overworld_has_town` | `generate_overworld()` | Town placed |
| `test_dungeon_has_stairs` | `generate_floor()` | Stairs placed |
| `test_dungeon_connectivity` | `generate_floor()` | All rooms reachable |

---

### Priority 6: Entity System

#### 6.1 Entity (`entities/entity.gd`)
**Type**: Base class - Easy
**File**: `test/unit/test_entity.gd`

| Test | Method | Description |
|------|--------|-------------|
| `test_take_damage` | `take_damage()` | Health reduced |
| `test_take_damage_kills` | `take_damage()` | Dies at 0 health |
| `test_heal` | `heal()` | Health increased |
| `test_heal_capped` | `heal()` | Can't exceed max |
| `test_get_effective_attribute` | `get_effective_attribute()` | Base + modifiers |
| `test_apply_stat_modifiers` | `apply_stat_modifiers()` | Modifiers applied |

---

### Priority 7: Save/Load (Integration)

#### 7.1 SaveManager Integration
**File**: `test/unit/test_save_system.gd`

| Test | Description |
|------|-------------|
| `test_save_load_round_trip` | Save and load preserves all state |
| `test_save_slot_management` | Three slots work correctly |
| `test_deterministic_regeneration` | Same seed regenerates same world |

---

## Test Utilities & Helpers

### Mock Classes Needed

Create `test/mocks/` directory for:

```
test/mocks/
├── mock_entity.gd      # Entity with configurable stats
├── mock_player.gd      # Player with inventory/survival
├── mock_map.gd         # Map with configurable tiles
└── mock_managers.gd    # Autoload mocks for isolation
```

### Example Mock Entity

```gdscript
# test/mocks/mock_entity.gd
extends RefCounted
class_name MockEntity

var position: Vector2i = Vector2i.ZERO
var current_health: int = 100
var max_health: int = 100
var is_alive: bool = true
var attributes: Dictionary = {
    "STR": 10, "DEX": 10, "CON": 10,
    "INT": 10, "WIS": 10, "CHA": 10
}
var stat_modifiers: Dictionary = {}
var equipped_weapon: Dictionary = {}
var equipped_armor: Dictionary = {}

func get_effective_attribute(attr: String) -> int:
    var base = attributes.get(attr, 10)
    var mod = stat_modifiers.get(attr, 0)
    return base + mod

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    if current_health <= 0:
        is_alive = false
```

---

## Implementation Order

### Phase 1: Foundation (Week 1)
1. `test_combat_system.gd` - Core combat formulas
2. `test_item.gd` - Item data class
3. `test_game_tile.gd` - Tile properties
4. `test_seeded_random.gd` - RNG determinism

### Phase 2: Core Systems (Week 2)
5. `test_survival_system.gd` - Survival mechanics
6. `test_inventory_system.gd` - Inventory management
7. `test_ranged_combat_system.gd` - Ranged attacks

### Phase 3: Advanced Systems (Week 3)
8. `test_crafting_system.gd` - Crafting formulas
9. `test_harvest_system.gd` - Resource harvesting
10. `test_item_factory.gd` - Item generation

### Phase 4: Maps & FOV (Week 4)
11. `test_game_map.gd` - Map operations
12. `test_fov_system.gd` - Shadowcasting
13. `test_world_generation.gd` - Procedural gen

### Phase 5: Integration (Week 5)
14. `test_entity.gd` - Entity base class
15. `test_save_system.gd` - Save/load round-trip

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/tests.yml
name: Unit Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.3.0

      - name: Run GUT Tests
        run: |
          godot --headless -s addons/gut/gut_cmdln.gd \
            -gdir=res://test/unit \
            -gexit
```

---

## Coverage Goals

| Category | Target | Current |
|----------|--------|---------|
| Combat System | 90% | 0% |
| Survival System | 85% | 0% |
| Inventory System | 90% | 0% |
| Item System | 95% | 0% |
| Crafting System | 80% | 0% |
| FOV System | 75% | 0% |
| Generation | 70% | 0% |
| **Overall** | **80%** | **0%** |

---

## Best Practices

1. **Test Naming**: `test_<method>_<scenario>` (e.g., `test_take_damage_kills`)
2. **One Assert Per Concept**: Multiple asserts OK if testing same concept
3. **AAA Pattern**: Arrange, Act, Assert
4. **Isolation**: Tests should not depend on each other
5. **Determinism**: Use SeededRandom for any RNG in tests
6. **Speed**: Unit tests should complete in <100ms each
7. **Mocking**: Mock autoloads to avoid side effects

---

## Next Steps

1. Close and reopen Godot to see the GUT tab
2. Run the sample test (`test_combat_system.gd`) to verify setup
3. Implement Priority 1 tests first
4. Add mocks as needed for complex systems

---

**Created**: January 4, 2026
**Framework**: GUT v9.3.0
**Target**: Godot 4.5
