# Add Spell Skill

Workflow for adding new spells to the game.

---

## Steps

### 1. Create Spell JSON

Create `data/spells/[school]/spell_name.json`:

```json
{
  "id": "flame_bolt",
  "name": "Flame Bolt",
  "description": "A bolt of fire streaks toward your target.",
  "school": "evocation",
  "level": 2,
  "mana_cost": 8,
  "requirements": {
    "character_level": 2,
    "intelligence": 9
  },
  "targeting": {
    "mode": "ranged",
    "range": 8,
    "requires_los": true
  },
  "effects": {
    "damage": {
      "type": "fire",
      "base": 12,
      "scaling": 4
    },
    "status_chance": 0.2,
    "status": "burning"
  },
  "duration": {
    "type": "instant"
  },
  "cast_message": "You hurl a bolt of flame!",
  "ascii_char": "*",
  "ascii_color": "#FF6600"
}
```

### 2. Schools of Magic

| School | Focus | Data Path |
|--------|-------|-----------|
| Evocation | Direct damage | `data/spells/evocation/` |
| Conjuration | Summoning, healing | `data/spells/conjuration/` |
| Abjuration | Protection, dispelling | `data/spells/abjuration/` |
| Transmutation | Transformation | `data/spells/transmutation/` |
| Enchantment | Mind control, buffs | `data/spells/enchantment/` |
| Necromancy | Death, undead | `data/spells/necromancy/` |
| Divination | Detection, knowledge | `data/spells/divination/` |
| Illusion | Deception | `data/spells/illusion/` |
| Cantrips | Level 0 spells | `data/spells/cantrips/` |

### 3. Targeting Modes

```json
// Single target ranged
"targeting": {
  "mode": "ranged",
  "range": 8,
  "requires_los": true
}

// Self-cast
"targeting": {
  "mode": "self"
}

// Area of effect
"targeting": {
  "mode": "area",
  "range": 6,
  "radius": 3,
  "requires_los": true
}

// Touch
"targeting": {
  "mode": "touch"
}
```

### 4. Effect Types

#### Damage
```json
"effects": {
  "damage": {
    "type": "fire",
    "base": 12,
    "scaling": 4
  }
}
```
Damage types: `fire`, `ice`, `lightning`, `necrotic`, `poison`, `arcane`

#### Healing
```json
"effects": {
  "heal": {
    "base": 15,
    "scaling": 5
  }
}
```

#### Status Effect
```json
"effects": {
  "status_chance": 0.3,
  "status": "burning",
  "status_duration": 5
}
```
Statuses: `burning`, `frozen`, `poisoned`, `cursed`, `charmed`, `feared`

#### Buff/Debuff
```json
"effects": {
  "buff": {
    "stat": "armor",
    "modifier": 5,
    "duration": 10
  }
}
```

#### Summon
```json
"effects": {
  "summon": {
    "creature_id": "wolf",
    "duration": 20,
    "count": 1
  }
}
```

### 5. Duration Types

```json
// Instant (damage, healing)
"duration": {"type": "instant"}

// Timed (buffs, summons)
"duration": {"type": "turns", "value": 10}

// Concentration
"duration": {"type": "concentration", "max_turns": 20}
```

---

## Verification

1. Restart game (SpellManager loads on startup)
2. Verify spell appears in spell list (K key)
3. Check requirements are enforced
4. Test casting and effects
5. Verify mana consumption

---

## Key Files

- `data/spells/` - Spell definitions by school
- `autoload/spell_manager.gd` - Spell loading and validation
- `magic/spell.gd` - Spell data class
- `docs/data/spells.md` - Full format documentation
