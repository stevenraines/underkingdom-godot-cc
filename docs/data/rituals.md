# Ritual Data Format

Rituals are defined as JSON files in the `data/rituals/` directory.

## Status: Not Yet Implemented

This documentation will be updated as the ritual system is implemented in Phases 24-25.

## Overview

Rituals differ from spells in several ways:
- Require multiple turns to channel
- Consume material components
- No level requirement (only INT)
- Can be interrupted by damage
- Generally more powerful effects

## Directory Structure

```
data/rituals/
├── enchant_item.json
├── scrying.json
├── resurrection.json
├── summon_demon.json
├── bind_soul.json
└── ward_area.json
```

## JSON Schema

```json
{
  "id": "ritual_id",
  "name": "Display Name",
  "description": "What the ritual does.",
  "school": "transmutation",
  "components": [
    {"item_id": "mana_crystal", "quantity": 5},
    {"item_id": "arcane_essence", "quantity": 2, "consumed": true}
  ],
  "channeling_turns": 10,
  "requirements": {
    "intelligence": 14,
    "near_altar": true,
    "night_only": false
  },
  "effects": {
    "enchant_item": {
      "enchantment_pool": ["sharpness", "protection"]
    }
  },
  "failure_effects": {
    "destroy_item_chance": 0.3,
    "summon_hostile": false
  },
  "discovery_location": "ancient_library"
}
```

## Property Reference

### Core Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| id | string | Yes | Unique ritual identifier |
| name | string | Yes | Display name |
| description | string | Yes | Ritual description |
| school | string | Yes | Magic school |
| channeling_turns | int | Yes | Turns required to complete |

### Components

Array of required materials:

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| item_id | string | - | Item identifier |
| quantity | int | 1 | Number required |
| consumed | bool | true | Whether component is consumed |

### Requirements

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| intelligence | int | 8 | Minimum INT attribute |
| near_altar | bool | false | Must be adjacent to altar |
| night_only | bool | false | Can only perform at night |
| near_corpse | bool | false | Requires corpse nearby |
| target_low_health | bool | false | Target must be < 25% HP |

### Effect Types

#### Enchant Item
```json
"enchant_item": {
  "enchantment_pool": ["sharpness", "protection", "mana_regen"]
}
```

#### Reveal Map (Scrying)
```json
"reveal_map": {
  "radius": 30,
  "reveals_enemies": true,
  "reveals_items": true
}
```

#### Resurrect
```json
"resurrect": {
  "health_percent": 25,
  "temporary_weakness": true
}
```

#### Summon
```json
"summon": {
  "creature_id": "bound_demon",
  "duration": 200,
  "behavior": "aggressive"
}
```

#### Bind Soul
```json
"bind_soul": {
  "kills_target": true,
  "creates_item": "filled_soul_gem"
}
```

#### Create Ward
```json
"create_ward": {
  "radius": 5,
  "duration": 500,
  "effects": ["blocks_undead", "blocks_demons", "alarm_on_entry"]
}
```

### Failure Effects

What happens if the ritual is interrupted:

| Property | Type | Description |
|----------|------|-------------|
| destroy_item_chance | float | Chance target item is destroyed (0.0-1.0) |
| summon_hostile | bool | Summons hostile creature on failure |
| summon_hostile_undead | bool | Summons hostile undead on failure |

## Planned Rituals

| Ritual | School | Channeling | Effect |
|--------|--------|------------|--------|
| Enchant Item | Transmutation | 10 turns | Add permanent enchantment to item |
| Scrying | Divination | 5 turns | Reveal large map area |
| Resurrection | Necromancy | 20 turns | Return fallen ally to life |
| Summon Demon | Conjuration | 15 turns | Summon powerful demon ally |
| Bind Soul | Necromancy | 8 turns | Trap creature's soul in gem |
| Ward Area | Abjuration | 12 turns | Create protective barrier |

## Learning Rituals

Rituals are learned by finding and reading ritual tomes:
- `ritual_tome_enchant` - Tome of Enchantment
- `ritual_tome_scrying` - Tome of Far Sight
- `ritual_tome_resurrection` - Book of Life
- etc.

Tomes are found in specific locations noted in the `discovery_location` field.

## Related Documentation

- [Magic System](../systems/magic-system.md)
- [Spell Data Format](spells.md)
- [Items Data Format](items.md) - For ritual components
