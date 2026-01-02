# Loot Table Manager

**Source File**: `autoload/loot_table_manager.gd`
**Type**: Autoload Singleton
**Class Name**: `LootTableManagerClass`

## Overview

The Loot Table Manager handles procedural loot generation from enemies and containers. It loads loot table definitions from JSON files and provides deterministic item drops using seeded randomness. Loot tables support both guaranteed drops and probability-based drops.

## Key Concepts

- **Loot Tables**: JSON definitions specifying possible drops
- **Guaranteed Drops**: Items that always drop (100% chance)
- **Chance Drops**: Items with probability-based drops
- **Seeded Generation**: Deterministic loot for consistent regeneration

## Core Functionality

### Loading Tables

```gdscript
LootTableManager.loot_tables: Dictionary  # {table_id: definition}
```

All JSON files in `data/loot_tables/` are loaded at startup.

### Generating Loot

```gdscript
var drops = LootTableManager.generate_loot(table_id, rng)
# Returns: [{item_id: String, count: int}, ...]
```

### Checking Tables

```gdscript
var exists = LootTableManager.has_loot_table(table_id)
```

## Loot Generation Process

1. Lookup table by ID
2. Process guaranteed drops (always included)
3. Process chance drops (roll for each)
4. Return array of {item_id, count} dictionaries

### Guaranteed Drops

Every item in `guaranteed_drops` is always included:

```gdscript
for drop in guaranteed_drops:
    count = random_range(min_count, max_count)
    loot.append({item_id, count})
```

### Chance Drops

Each item in `drops` is rolled independently:

```gdscript
for drop in drops:
    if random_float() < drop.chance:
        count = random_range(min_count, max_count)
        loot.append({item_id, count})
```

## Loot Table Structure

```json
{
  "id": "table_id",
  "name": "Display Name",
  "description": "Description text",
  "guaranteed_drops": [
    {"item_id": "gold_coin", "min_count": 5, "max_count": 20}
  ],
  "drops": [
    {"item_id": "gem", "min_count": 1, "max_count": 2, "chance": 0.3}
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

*`chance` only applies to entries in `drops`, not `guaranteed_drops`.

## Seeded Randomness

The system supports optional `SeededRandom` for deterministic generation:

```gdscript
# Deterministic loot (same seed = same drops)
var rng = SeededRandom.new(floor_seed)
var loot = LootTableManager.generate_loot("undead_common", rng)

# Non-deterministic (varies each call)
var loot = LootTableManager.generate_loot("undead_common")
```

### Random Functions

```gdscript
_random_range(min, max, rng)  # Integer range
_random_float(rng)            # Float 0.0-1.0
```

Both functions use `SeededRandom` if provided, otherwise global `randi_range()`/`randf()`.

## Current Loot Tables

| ID | Name | Description |
|----|------|-------------|
| `rat_common` | Rat Common | Drops from rat enemies |
| `beast_common` | Beast Common | Drops from animal enemies |
| `undead_common` | Undead Common | Drops from undead enemies |
| `undead_boss` | Undead Boss | Drops from undead bosses |
| `ancient_treasure` | Ancient Treasure | Treasure chests and burial sites |

## Example Loot Tables

### Enemy Loot (Chance Only)

```json
{
  "id": "undead_common",
  "name": "Undead Common Loot",
  "description": "Common drops from undead creatures",
  "drops": [
    {"item_id": "bone", "min_count": 1, "max_count": 3, "chance": 0.8},
    {"item_id": "gold_coin", "min_count": 1, "max_count": 10, "chance": 0.3},
    {"item_id": "rusty_sword", "min_count": 1, "max_count": 1, "chance": 0.1},
    {"item_id": "tattered_cloth", "min_count": 1, "max_count": 2, "chance": 0.4}
  ]
}
```

### Treasure (Guaranteed + Chance)

```json
{
  "id": "ancient_treasure",
  "name": "Ancient Treasure",
  "description": "Treasure found in ancient chests",
  "guaranteed_drops": [
    {"item_id": "gold_coin", "min_count": 15, "max_count": 60}
  ],
  "drops": [
    {"item_id": "ancient_artifact", "min_count": 1, "max_count": 1, "chance": 0.3},
    {"item_id": "gem", "min_count": 1, "max_count": 2, "chance": 0.4},
    {"item_id": "ancient_scroll", "min_count": 1, "max_count": 1, "chance": 0.2},
    {"item_id": "cursed_ring", "min_count": 1, "max_count": 1, "chance": 0.1}
  ]
}
```

## Integration with Other Systems

- **EntityManager**: Enemies reference loot tables via `loot_table` property
- **FeatureManager**: Containers use loot tables for contents
- **DungeonManager**: Passes floor RNG for deterministic drops
- **ItemManager**: Creates actual Item instances from generated drops

## Usage Flow

```
Enemy dies
    ↓
EntityManager gets enemy.loot_table
    ↓
LootTableManager.generate_loot(table_id, rng)
    ↓
Returns [{item_id, count}, ...]
    ↓
ItemManager creates Item instances
    ↓
GroundItems spawned at death location
```

## Data Dependencies

- **Loot Tables** (`data/loot_tables/`): Table definitions
- **Items** (`data/items/`): Item IDs must exist in ItemManager

## Validation Rules

1. `id` must be unique across all loot tables
2. `item_id` values must match items in ItemManager
3. `chance` must be 0.0-1.0 (decimal, not percentage)
4. `min_count` must be ≤ `max_count`
5. Counts must be positive integers

## Related Documentation

- [Loot Tables Data](../data/loot-tables.md) - JSON file format
- [Enemies Data](../data/enemies.md) - Enemy loot_table reference
- [Feature Manager](./feature-manager.md) - Container loot generation
- [Items Data](../data/items.md) - Item definitions
