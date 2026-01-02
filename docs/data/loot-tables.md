# Loot Tables Data Format

**Location**: `data/loot_tables/`
**File Count**: 5 files
**Loaded By**: LootTableManager

## Overview

Loot tables define what items drop from enemies and containers. Each table specifies guaranteed drops (always included) and chance-based drops (probability rolls). Loot tables are referenced by enemy definitions, dungeon features, and container configurations.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique identifier (snake_case) | LootTableManager |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `name` | string | "" | Display name | Debug, UI |
| `description` | string | "" | Table description | Debug |
| `guaranteed_drops` | array | [] | Always-dropped items | LootTableManager |
| `drops` | array | [] | Chance-based items | LootTableManager |

## Drop Entry Structure

Each entry in `guaranteed_drops` or `drops`:

```json
{
  "item_id": "gold_coin",
  "min_count": 1,
  "max_count": 10,
  "chance": 0.5
}
```

### Drop Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `item_id` | string | Yes | Item definition ID |
| `min_count` | int | No | Minimum quantity (default: 1) |
| `max_count` | int | No | Maximum quantity (default: 1) |
| `chance` | float | No* | Drop probability 0.0-1.0 |

*`chance` only used in `drops` array, ignored in `guaranteed_drops`.

## Guaranteed vs Chance Drops

### Guaranteed Drops
Items that **always** drop. Quantity is random within range.

```json
"guaranteed_drops": [
  {"item_id": "gold_coin", "min_count": 5, "max_count": 20}
]
```

Result: Always drops 5-20 gold coins.

### Chance Drops
Items that **may** drop based on probability.

```json
"drops": [
  {"item_id": "gem", "min_count": 1, "max_count": 1, "chance": 0.3}
]
```

Result: 30% chance to drop 1 gem.

## Probability Format

**CRITICAL**: Use decimal format (0.0-1.0), not percentages.

| Desired Chance | Correct | Incorrect |
|----------------|---------|-----------|
| 50% | `0.5` | `50` |
| 100% | `1.0` | `100` |
| 10% | `0.1` | `10` |
| 85% | `0.85` | `85` |

## Complete Examples

### Enemy Loot (Chance Only)

```json
{
  "id": "undead_common",
  "name": "Undead Common Loot",
  "description": "Common drops from undead creatures like skeletons and wights",
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
  "description": "Treasure found in ancient chests and burial sites",
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

### Animal Loot

```json
{
  "id": "beast_common",
  "name": "Beast Common Loot",
  "description": "Drops from animal enemies",
  "drops": [
    {"item_id": "raw_meat", "min_count": 1, "max_count": 2, "chance": 0.9},
    {"item_id": "animal_hide", "min_count": 1, "max_count": 1, "chance": 0.7},
    {"item_id": "bone", "min_count": 1, "max_count": 2, "chance": 0.5}
  ]
}
```

### Boss Loot

```json
{
  "id": "undead_boss",
  "name": "Undead Boss Loot",
  "description": "Drops from powerful undead bosses",
  "guaranteed_drops": [
    {"item_id": "gold_coin", "min_count": 50, "max_count": 200},
    {"item_id": "ancient_key", "min_count": 1, "max_count": 1}
  ],
  "drops": [
    {"item_id": "legendary_weapon", "min_count": 1, "max_count": 1, "chance": 0.2},
    {"item_id": "rare_armor", "min_count": 1, "max_count": 1, "chance": 0.3},
    {"item_id": "soul_gem", "min_count": 1, "max_count": 3, "chance": 0.5}
  ]
}
```

## Current Loot Tables

| ID | Purpose | Guaranteed | Chance Drops |
|----|---------|------------|--------------|
| `rat_common` | Rat enemies | None | Meat, gold |
| `beast_common` | Animal enemies | None | Meat, hide, bone |
| `undead_common` | Undead enemies | None | Bone, gold, cloth |
| `undead_boss` | Undead bosses | Gold, key | Weapons, armor |
| `ancient_treasure` | Treasure chests | Gold | Artifacts, gems |

## Generation Algorithm

```gdscript
func generate_loot(table_id, rng):
    var loot = []

    # Guaranteed drops - always included
    for drop in table.guaranteed_drops:
        var count = random_range(drop.min_count, drop.max_count)
        loot.append({item_id: drop.item_id, count: count})

    # Chance drops - roll for each
    for drop in table.drops:
        if random_float() < drop.chance:
            var count = random_range(drop.min_count, drop.max_count)
            loot.append({item_id: drop.item_id, count: count})

    return loot
```

## Usage References

### Enemy Definitions

```json
{
  "id": "skeleton",
  "loot_table": "undead_common"
}
```

### Dungeon Features

```json
"room_features": [
  {
    "feature_id": "treasure_chest",
    "loot_table": "ancient_treasure"
  }
]
```

### Dungeon Floor Loot

```json
"loot_tables": [
  {
    "item_id": "ancient_gold",
    "chance": 0.3,
    "count_range": [10, 50]
  }
]
```

## Expected Drop Calculation

For chance-based items, expected drops per kill/open:

```
Expected = chance × average_count
Average Count = (min_count + max_count) / 2
```

Example: 30% chance for 1-10 gold
```
Expected = 0.3 × 5.5 = 1.65 gold per drop
```

## Validation Rules

1. `id` must be unique across all loot tables
2. `id` should use snake_case format
3. `item_id` must match an item in ItemManager
4. `chance` must be 0.0-1.0 (decimal, not percentage)
5. `min_count` must be ≤ `max_count`
6. `min_count` must be ≥ 1
7. Don't put `chance` in guaranteed_drops (ignored)

## Best Practices

### Balance Guidelines

| Drop Type | Recommended Chance |
|-----------|-------------------|
| Common consumables | 0.7-0.9 |
| Basic materials | 0.5-0.7 |
| Currency | 0.3-0.5 |
| Equipment | 0.1-0.2 |
| Rare items | 0.05-0.1 |
| Very rare items | 0.01-0.05 |

### Quantity Guidelines

| Item Type | Recommended Range |
|-----------|------------------|
| Currency | 1-20 (scales with difficulty) |
| Consumables | 1-3 |
| Materials | 1-5 |
| Equipment | 1 (always) |
| Rare items | 1 (always) |

## Related Documentation

- [Loot Table Manager](../systems/loot-table-manager.md) - System mechanics
- [Enemies Data](./enemies.md) - Enemy loot_table property
- [Features Data](./features.md) - Container loot
- [Dungeons Data](./dungeons.md) - Floor loot config
- [Items Data](./items.md) - Item definitions
