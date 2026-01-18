# Loot Tables Data Format

**Location**: `data/loot_tables/`
**Loaded By**: LootTableManager

## Overview

Loot tables define what items drop from enemies and containers. The system supports:
- **Multiple loot tables per entity** - Creature type defaults + entity-specific tables
- **CR-based scaling** - Currency and gems scale with Challenge Rating
- **Guaranteed and chance drops** - Always-drop and probability-based items

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
  "chance": 0.5,
  "cr_scales": true
}
```

### Drop Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `item_id` | string | Yes | Item definition ID |
| `min_count` | int | No | Minimum quantity (default: 1) |
| `max_count` | int | No | Maximum quantity (default: 1) |
| `chance` | float | No* | Drop probability 0.0-1.0 |
| `cr_scales` | bool | No | If true, quantity scales with CR (default: false) |

*`chance` only used in `drops` array, ignored in `guaranteed_drops`.

## CR-Based Scaling

Items marked with `"cr_scales": true` have their quantities multiplied based on the entity's CR:

| CR Band | CR Range | Multiplier |
|---------|----------|------------|
| 0 | 0-4 | 1.0x |
| 1 | 5-10 | 2.0x |
| 2 | 11-16 | 5.0x |
| 3 | 17+ | 10.0x |

Example: A CR 8 undead with `"gold_coin", "min_count": 5, "max_count": 10, "cr_scales": true` will drop 10-20 gold coins (2x multiplier).

## Creature Type Defaults

Each creature type can define default loot tables that all creatures of that type inherit:

```json
// data/creature_types/undead.json
{
  "id": "undead",
  "default_loot_tables": ["undead_common"],
  ...
}
```

Creatures automatically roll on their creature type's default tables, plus any entity-specific tables.

## Loot Table Categories

### Creature Type Tables

| ID | Creature Type | Contents |
|----|---------------|----------|
| `beast_common` | Beasts/Animals | Bone, feather (organic only) |
| `humanoid_common` | Humanoids | Gold, supplies, keys |
| `humanoid_armed` | Armed humanoids | Ammunition |
| `humanoid_mage` | Spellcasters | Scrolls, potions, gems |
| `undead_common` | Undead | Bone, gold, cloth |
| `undead_boss` | Undead bosses | Gold, gems, artifacts |
| `elemental_common` | Elementals | Gems, soul gems |
| `construct_common` | Constructs | Metal, gems |
| `demon_common` | Demons | Soul gems, gold |
| `ooze_common` | Oozes | Swallowed treasure |
| `monstrosity_common` | Monstrosities | Mixed organic/treasure |
| `aberration_common` | Aberrations | Gems, scrolls |

### CR Treasure Tables

| ID | CR Range | Contents |
|----|----------|----------|
| `cr_0_4_treasure` | 0-4 | Small gold, basic items |
| `cr_5_10_treasure` | 5-10 | Gold, gems, potions |
| `cr_11_16_treasure` | 11-16 | Large gold, rare items |
| `cr_17_plus_treasure` | 17+ | Legendary treasure |

### Container Tables

| ID | Purpose |
|----|---------|
| `ancient_treasure` | Chests, burial sites |
| `shop_general` | General store inventory |
| `shop_blacksmith` | Blacksmith inventory |

## Enemy Loot Configuration

### New Format (Recommended)

Use `loot_tables` array for multiple tables:

```json
{
  "id": "barrow_lord",
  "creature_type": "undead",
  "cr": 6,
  "loot_tables": ["undead_boss"],
  ...
}
```

This enemy will roll on:
1. `undead_common` (from creature type default)
2. `undead_boss` (entity-specific)

### Legacy Format (Backward Compatible)

Single `loot_table` string still works:

```json
{
  "id": "skeleton",
  "creature_type": "undead",
  "loot_table": "undead_common",
  ...
}
```

### Minimal Format

Creatures can rely entirely on creature type defaults:

```json
{
  "id": "skeleton",
  "creature_type": "undead",
  ...
}
```

This skeleton will only roll on `undead_common` (from creature type default).

## Complete Examples

### Humanoid Loot with Arms

```json
{
  "id": "humanoid_armed",
  "name": "Armed Humanoid Loot",
  "description": "Drops from armed humanoids. Only creatures with arms can carry weapons.",
  "drops": [
    {"item_id": "iron_arrow", "min_count": 3, "max_count": 10, "chance": 0.2},
    {"item_id": "bolt", "min_count": 2, "max_count": 8, "chance": 0.15}
  ]
}
```

### Spellcaster Loot with CR Scaling

```json
{
  "id": "humanoid_mage",
  "name": "Humanoid Mage Loot",
  "description": "Drops from intelligent spellcasters. Gold and gems scale with CR.",
  "drops": [
    {"item_id": "gold_coin", "min_count": 5, "max_count": 30, "chance": 0.8, "cr_scales": true},
    {"item_id": "mana_potion", "min_count": 1, "max_count": 2, "chance": 0.35},
    {"item_id": "scroll_spark", "min_count": 1, "max_count": 1, "chance": 0.12},
    {"item_id": "gem", "min_count": 1, "max_count": 2, "chance": 0.15, "cr_scales": true}
  ]
}
```

### Legendary Treasure

```json
{
  "id": "cr_17_plus_treasure",
  "name": "Legendary CR Treasure",
  "description": "Legendary treasure for CR 17+ creatures.",
  "guaranteed_drops": [
    {"item_id": "gold_coin", "min_count": 100, "max_count": 500, "cr_scales": true}
  ],
  "drops": [
    {"item_id": "gem", "min_count": 3, "max_count": 10, "chance": 0.7, "cr_scales": true},
    {"item_id": "soul_gem", "min_count": 1, "max_count": 3, "chance": 0.4, "cr_scales": true},
    {"item_id": "ancient_artifact", "min_count": 1, "max_count": 1, "chance": 0.2}
  ]
}
```

## Generation Algorithm

```gdscript
func generate_loot_for_entity(entity, rng):
    var all_loot = []
    var cr = entity.cr

    # Get all tables: creature type defaults + entity-specific
    var tables = get_loot_tables_for_entity(entity)

    # Roll on each table with CR scaling
    for table_id in tables:
        var table_loot = generate_loot_with_scaling(table_id, cr, rng)
        all_loot.append_array(table_loot)

    # Combine duplicate items
    return combine_loot(all_loot)
```

## Design Guidelines

### Which Creatures Get Which Loot

| Creature Type | Gold | Weapons | Magic Items | Organic |
|---------------|------|---------|-------------|---------|
| Beasts/Animals | No | No | No | Yes |
| Humanoids (armed) | Yes | Yes | If intelligent | Some |
| Humanoids (mage) | Yes | Staves | Yes | No |
| Undead | Yes* | If armed | If intelligent | Bone |
| Elementals | Gems | No | No | No |
| Constructs | Some | No | Gems | Metal |
| Demons | Yes | If armed | Yes | No |
| Oozes | Yes* | No | No | No |
| Monstrosities | Some* | No | Rare | Some |
| Aberrations | Gems | Rare | Some | No |

*Swallowed treasure from victims

### Probability Guidelines

| Drop Type | Recommended Chance |
|-----------|-------------------|
| Common consumables | 0.7-0.9 |
| Basic materials | 0.5-0.7 |
| Currency | 0.3-0.5 |
| Equipment | 0.1-0.2 |
| Rare items | 0.05-0.1 |
| Very rare items | 0.01-0.05 |

## Validation Rules

1. `id` must be unique across all loot tables
2. `id` should use snake_case format
3. `item_id` must match an item in ItemManager
4. `chance` must be 0.0-1.0 (decimal, not percentage)
5. `min_count` must be <= `max_count`
6. `min_count` must be >= 1
7. Don't put `chance` in guaranteed_drops (ignored)
8. Use `cr_scales` for currency and gems

## Related Documentation

- [Loot Table Manager](../systems/loot-table-manager.md) - System mechanics
- [Creature Types Data](./creature-types.md) - Default loot tables
- [Enemies Data](./enemies.md) - Enemy loot_tables property
- [Features Data](./features.md) - Container loot
- [Dungeons Data](./dungeons.md) - Floor loot config
- [Items Data](./items.md) - Item definitions
