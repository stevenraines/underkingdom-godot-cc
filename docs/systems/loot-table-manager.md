# Loot Table Manager

**Source File**: `autoload/loot_table_manager.gd`
**Type**: Autoload Singleton
**Class Name**: `LootTableManagerClass`

## Overview

The Loot Table Manager handles procedural loot generation from enemies and containers. It supports:
- **Multiple loot tables per entity** via creature type defaults and entity-specific tables
- **CR-based scaling** for currency and gems based on creature Challenge Rating
- **Seeded randomness** for deterministic dungeon loot

## Key Concepts

- **Loot Tables**: JSON definitions specifying possible drops
- **Creature Type Defaults**: Inherited from creature type definitions
- **Entity-Specific Tables**: Additional tables defined per-enemy
- **CR Scaling**: Items marked `cr_scales: true` scale with Challenge Rating
- **Seeded Generation**: Deterministic loot for consistent regeneration

## Core API

### Entity-Based Generation (Recommended)

```gdscript
# Generate loot for an entity with CR scaling
var drops = LootTableManager.generate_loot_for_entity(entity)
# Returns: [{item_id: String, count: int}, ...]

# Get all loot tables for an entity
var tables = LootTableManager.get_loot_tables_for_entity(entity)
# Returns: ["undead_common", "undead_boss"] (creature type + entity-specific)
```

### Single Table Generation

```gdscript
# Generate from single table with CR scaling
var drops = LootTableManager.generate_loot_with_scaling(table_id, cr, rng)

# Generate from single table (no scaling, legacy)
var drops = LootTableManager.generate_loot(table_id, rng)
```

### Utility

```gdscript
var exists = LootTableManager.has_loot_table(table_id)
```

## CR-Based Scaling

Items marked with `cr_scales: true` have quantities multiplied by CR band:

| CR Band | CR Range | Multiplier |
|---------|----------|------------|
| 0 | 0-4 | 1.0x |
| 1 | 5-10 | 2.0x |
| 2 | 11-16 | 5.0x |
| 3 | 17+ | 10.0x |

```gdscript
const CR_MULTIPLIERS = {
    0: 1.0,   # CR 0-4
    1: 2.0,   # CR 5-10
    2: 5.0,   # CR 11-16
    3: 10.0   # CR 17+
}

func _get_cr_band(cr: int) -> int:
    if cr >= 17: return 3
    elif cr >= 11: return 2
    elif cr >= 5: return 1
    else: return 0
```

## Loot Table Resolution

When `generate_loot_for_entity()` is called:

1. **Get creature type defaults** from `CreatureTypeManager.get_default_loot_tables()`
2. **Add entity-specific tables** from `entity.loot_tables` array
3. **Roll on each table** with CR scaling applied
4. **Combine duplicate items** into single entries

```gdscript
func get_loot_tables_for_entity(entity) -> Array[String]:
    var result: Array[String] = []

    # Get creature type defaults
    var type_defaults = CreatureTypeManager.get_default_loot_tables(entity.creature_type)
    for table_id in type_defaults:
        if has_loot_table(table_id):
            result.append(table_id)

    # Add entity-specific (no duplicates)
    for table_id in entity.loot_tables:
        if has_loot_table(table_id) and table_id not in result:
            result.append(table_id)

    return result
```

## Loot Table Structure

```json
{
  "id": "table_id",
  "name": "Display Name",
  "description": "Description text",
  "guaranteed_drops": [
    {"item_id": "gold_coin", "min_count": 5, "max_count": 20, "cr_scales": true}
  ],
  "drops": [
    {"item_id": "gem", "min_count": 1, "max_count": 2, "chance": 0.3, "cr_scales": true}
  ]
}
```

## Drop Entry Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `item_id` | string | Yes | Item to drop |
| `min_count` | int | No | Minimum quantity (default: 1) |
| `max_count` | int | No | Maximum quantity (default: 1) |
| `chance` | float | No* | Drop probability 0.0-1.0 |
| `cr_scales` | bool | No | Scale quantity with CR (default: false) |

*`chance` only applies to entries in `drops`, not `guaranteed_drops`.

## Seeded Randomness

The system supports optional `SeededRandom` for deterministic generation:

```gdscript
# Deterministic loot (same seed = same drops)
var rng = SeededRandom.new(floor_seed)
var loot = LootTableManager.generate_loot_for_entity(entity, rng)

# Non-deterministic (varies each call)
var loot = LootTableManager.generate_loot_for_entity(entity)
```

## Current Loot Tables

### Creature Type Defaults

| ID | Creature Type | Contents |
|----|---------------|----------|
| `beast_common` | beast | Bone, feather |
| `humanoid_common` | humanoid | Gold, supplies |
| `humanoid_armed` | armed humanoid | Ammunition |
| `humanoid_mage` | spellcaster | Scrolls, potions, gems |
| `undead_common` | undead | Bone, gold, cloth |
| `elemental_common` | elemental | Gems, soul gems |
| `construct_common` | construct | Metal, gems |
| `demon_common` | demon | Soul gems, gold |
| `ooze_common` | ooze | Swallowed treasure |
| `monstrosity_common` | monstrosity | Mixed organic/treasure |
| `aberration_common` | aberration | Gems, scrolls |

### Special Tables

| ID | Purpose |
|----|---------|
| `undead_boss` | Undead boss creatures |
| `ancient_treasure` | Treasure chests, burial sites |
| `cr_0_4_treasure` | Low CR creatures |
| `cr_5_10_treasure` | Mid CR creatures |
| `cr_11_16_treasure` | High CR creatures |
| `cr_17_plus_treasure` | Legendary creatures |

## Integration with Other Systems

- **CreatureTypeManager**: Provides default loot tables per creature type
- **Enemy**: Has `loot_tables` array and `cr` for scaling
- **EntityManager**: Enemies reference creature types
- **FeatureManager**: Containers use loot tables for contents
- **DungeonManager**: Passes floor RNG for deterministic drops
- **ItemManager**: Creates actual Item instances from generated drops

## Usage Flow

```
Enemy dies
    ↓
game.gd calls LootTableManager.generate_loot_for_entity(entity)
    ↓
Get creature type defaults: ["undead_common"]
Add entity-specific: ["undead_boss"]
    ↓
For each table, generate_loot_with_scaling(table_id, cr, rng)
    ↓
Apply CR multipliers to items with cr_scales: true
    ↓
Combine duplicate items
    ↓
Returns [{item_id, count}, ...]
    ↓
ItemManager creates Item instances
    ↓
GroundItems spawned at death location
```

## Validation Rules

1. `id` must be unique across all loot tables
2. `item_id` values must match items in ItemManager
3. `chance` must be 0.0-1.0 (decimal, not percentage)
4. `min_count` must be ≤ `max_count`
5. Counts must be positive integers
6. Use `cr_scales` for currency and gems

## Related Documentation

- [Loot Tables Data](../data/loot-tables.md) - JSON file format
- [Creature Types Data](../data/creature-types.md) - Default loot tables
- [Enemies Data](../data/enemies.md) - Enemy loot_tables property
- [Feature Manager](./feature-manager.md) - Container loot generation
- [Items Data](../data/items.md) - Item definitions
