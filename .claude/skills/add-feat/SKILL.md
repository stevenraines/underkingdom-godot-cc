# Add Feat Skill

Workflow for adding new feats (special abilities) to the game.

---

## Overview

Feats are special abilities that provide bonuses or special actions. They come from two sources:
- **Racial Traits**: Defined in race files as `traits`
- **Class Feats**: Defined in class files as `feats`

---

## Steps

### 1. Racial Trait (in `data/races/[race].json`)

```json
"traits": [
  {
    "id": "poison_resistance",
    "name": "Poison Resistance",
    "description": "+50% resistance to poison damage",
    "type": "passive",
    "effect": {
      "elemental_resistance": {
        "poison": -50
      }
    }
  },
  {
    "id": "stonecunning",
    "name": "Stonecunning",
    "description": "+1 to mining yield",
    "type": "passive",
    "effect": {
      "harvest_bonus": {
        "stone": 1,
        "iron_ore": 1
      }
    }
  }
]
```

### 2. Class Feat (in `data/classes/[class].json`)

```json
"feats": [
  {
    "id": "battle_hardened",
    "name": "Battle Hardened",
    "description": "+5 max health",
    "type": "passive",
    "effect": {
      "max_health_bonus": 5
    }
  },
  {
    "id": "second_wind",
    "name": "Second Wind",
    "description": "Recover 25% of max health once per day",
    "type": "active",
    "uses_per_day": 1,
    "activation_pattern": "direct_effect",
    "effect": {
      "heal_percent": 0.25,
      "activation_message": "Second Wind! You recover health."
    }
  }
]
```

### 3. Feat Types

| Type | Description |
|------|-------------|
| `passive` | Always active, provides constant bonus |
| `active` | Must be activated, limited uses |

### 4. Activation Patterns (for active feats)

| Pattern | Description |
|---------|-------------|
| `direct_effect` | Instant effect on self |
| `targeted` | Requires selecting a target |
| `toggle` | On/off state |
| `reaction` | Triggers on specific event |

### 5. Effect Types

#### Stat Bonuses
```json
"effect": {
  "max_health_bonus": 5,
  "stamina_bonus": 10,
  "stat_bonus": {"STR": 1, "CON": 1}
}
```

#### Resistances
```json
"effect": {
  "elemental_resistance": {
    "fire": -25,
    "poison": -50
  }
}
```

#### Harvest Bonuses
```json
"effect": {
  "harvest_bonus": {
    "wood": 1,
    "stone": 1
  }
}
```

#### Combat Bonuses
```json
"effect": {
  "damage_bonus": 2,
  "accuracy_bonus": 5,
  "armor_bonus": 1
}
```

#### Healing
```json
"effect": {
  "heal_percent": 0.25,
  "heal_flat": 10
}
```

#### Special
```json
"effect": {
  "darkvision": true,
  "water_breathing": true,
  "immunity": "poison"
}
```

### 6. Active Feat Configuration

```json
{
  "id": "rage",
  "name": "Rage",
  "description": "+2 damage, +10 temp HP for 10 turns",
  "type": "active",
  "uses_per_day": 2,
  "activation_pattern": "toggle",
  "duration": 10,
  "effect": {
    "damage_bonus": 2,
    "temp_health": 10,
    "activation_message": "You enter a battle rage!"
  },
  "end_effect": {
    "fatigue_gain": 20,
    "end_message": "Your rage subsides."
  }
}
```

---

## Verification

1. Check feat appears in character sheet (Traits/Abilities tab)
2. Verify passive effects apply correctly
3. Test active feat activation
4. Check uses_per_day resets at dawn
5. Verify activation messages appear

---

## Key Files

- `data/races/*.json` - Racial traits
- `data/classes/*.json` - Class feats
- `entities/player.gd` - Feat tracking
- `ui/character_sheet.gd` - Feat display
