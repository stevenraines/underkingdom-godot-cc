# Spell Data Format

Spells are defined as JSON files in `data/spells/{school}/` directories.

## Status: Phase 2 Implemented

SpellManager autoload loads spell definitions from JSON files at startup.

**Current spells:**
- `light` (evocation, cantrip) - Creates a light that follows you
- `spark` (evocation, level 1) - Lightning bolt attack
- `heal` (conjuration, level 1) - Restore health
- `shield` (abjuration, level 1) - Temporary armor buff

## Directory Structure

```
data/spells/
├── evocation/
│   ├── spark.json
│   ├── flame_bolt.json
│   └── fireball.json
├── conjuration/
│   ├── create_light.json
│   └── summon_creature.json
├── enchantment/
│   ├── charm.json
│   └── fear.json
├── transmutation/
│   ├── stone_skin.json
│   └── wall_to_mud.json
├── divination/
│   ├── detect_magic.json
│   └── identify.json
├── necromancy/
│   ├── drain_life.json
│   └── poison.json
├── abjuration/
│   ├── shield.json
│   └── remove_curse.json
└── illusion/
    └── minor_illusion.json
```

## JSON Schema

```json
{
  "id": "spell_id",
  "name": "Display Name",
  "description": "What the spell does.",
  "school": "evocation",
  "level": 1,
  "mana_cost": 5,
  "requirements": {
    "character_level": 1,
    "intelligence": 8
  },
  "targeting": {
    "mode": "ranged",
    "range": 6,
    "requires_los": true,
    "aoe_radius": 0,
    "aoe_shape": "circle"
  },
  "effects": {
    "damage": {
      "type": "fire",
      "base": 10,
      "scaling": 2
    }
  },
  "save": {
    "type": "DEX",
    "on_success": "half_damage"
  },
  "concentration": false,
  "cooldown": 0,
  "cast_message": "Flames erupt from your hands!"
}
```

## Property Reference

### Core Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| id | string | Yes | Unique spell identifier |
| name | string | Yes | Display name |
| description | string | Yes | Spell description |
| school | string | Yes | Magic school (see list below) |
| level | int | Yes | Spell level (0-10, 0 = cantrip) |
| mana_cost | int | Yes | Mana required to cast |

### Requirements

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| character_level | int | 1 | Minimum player level |
| intelligence | int | 8 | Minimum INT attribute |

### Targeting

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| mode | string | "self" | Targeting mode (see below) |
| range | int | 0 | Maximum range in tiles |
| requires_los | bool | true | Requires line of sight |
| aoe_radius | int | 0 | Area of effect radius |
| aoe_shape | string | "circle" | AOE shape |
| requires_empty | bool | false | Target tile must be empty |

### Targeting Modes

- `self` - Affects caster only
- `ranged` - Single target at range
- `tile` - Targets a tile (for terrain/summon)
- `aoe` - Area of effect at target location
- `self_or_ally` - Caster or adjacent ally

### Effect Types

Effects are defined in the `effects` object. Multiple effect types can be combined.

#### Damage Effect
```json
"damage": {
  "type": "fire",
  "base": 10,
  "scaling": 2
}
```
- `type`: fire, ice, lightning, poison, necrotic, holy, physical
- `base`: Base damage amount
- `scaling`: Additional damage per caster level above spell level

#### Buff/Debuff Effect
```json
"buff": {
  "id": "shield_effect",
  "stat": "armor",
  "modifier": 5,
  "duration": 50
}
```

#### DoT Effect
```json
"dot": {
  "type": "poison",
  "damage_per_turn": 3,
  "duration": 10
}
```

#### Mind Effect
```json
"mind_effect": "charm"
```
Values: charm, fear, calm, enrage

#### Summon Effect
```json
"summon": {
  "creature_id": "summoned_wolf",
  "base_duration": 50,
  "duration_per_level": 10
}
```

### Saving Throws

| Property | Type | Description |
|----------|------|-------------|
| type | string | Save attribute (STR, DEX, CON, INT, WIS, CHA) |
| on_success | string | Effect on successful save |

On Success Values:
- `no_effect` - Spell completely resisted
- `half_damage` - Take half damage
- `half_duration` - Effect lasts half as long

### Schools of Magic

- `evocation` - Damage and energy manipulation
- `conjuration` - Creation and summoning
- `enchantment` - Mind control and influence
- `transmutation` - Transformation and alteration
- `divination` - Knowledge and detection
- `necromancy` - Death and undead
- `abjuration` - Protection and warding
- `illusion` - Deception and trickery

## Examples

### Cantrip (Level 0)
```json
{
  "id": "spark",
  "name": "Spark",
  "description": "A tiny arc of electricity.",
  "school": "evocation",
  "level": 0,
  "mana_cost": 0,
  "requirements": {"intelligence": 8},
  "targeting": {"mode": "ranged", "range": 3},
  "effects": {
    "damage": {"type": "lightning", "base": 2, "scaling": 0}
  }
}
```

### Damage Spell
```json
{
  "id": "fireball",
  "name": "Fireball",
  "description": "A ball of fire explodes at the target location.",
  "school": "evocation",
  "level": 7,
  "mana_cost": 45,
  "requirements": {"character_level": 7, "intelligence": 14},
  "targeting": {
    "mode": "aoe",
    "range": 8,
    "aoe_radius": 3,
    "requires_los": true
  },
  "effects": {
    "damage": {"type": "fire", "base": 25, "scaling": 5}
  },
  "save": {"type": "DEX", "on_success": "half_damage"}
}
```

### Buff Spell
```json
{
  "id": "shield",
  "name": "Shield",
  "description": "Create a magical barrier around yourself.",
  "school": "abjuration",
  "level": 2,
  "mana_cost": 8,
  "requirements": {"character_level": 2, "intelligence": 9},
  "targeting": {"mode": "self"},
  "effects": {
    "buff": {
      "id": "shield_effect",
      "stat": "armor",
      "modifier": 5,
      "duration": 30
    }
  }
}
```

## Related Documentation

- [Magic System](../systems/magic-system.md)
- [Items Data Format](items.md) - For scrolls, wands, staves
- [Enemies Data Format](enemies.md) - For enemy spellcasters
