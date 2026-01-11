# Magic System

The magic system provides spellcasting and ritual mechanics for the player.

## Overview

The magic system consists of two main components:
- **Spells** - Instant-cast abilities that consume mana
- **Rituals** - Multi-turn channeled abilities that consume components

## Implementation Status

- **Phase 01** (Mana System) - Implemented
- **Phase 02** (Spell Data & Manager) - Implemented
- **Phase 03** (Spellbook & Spell Learning) - Implemented

Remaining phases are planned.

## Mana System (Implemented)

The mana system is fully integrated with the SurvivalSystem.

### Mana Pool Formula
```
Max Mana = Base (30) + (INT - 10) × 5 + (Level - 1) × 5
```

### Mana Regeneration
- **Base Rate**: 1 mana per turn
- **Shelter Bonus**: 3× regeneration when in shelter
- Regeneration occurs automatically each turn via TurnManager

### Key Constants
```gdscript
MANA_REGEN_PER_TURN = 1.0
MANA_REGEN_SHELTER_MULTIPLIER = 3.0
MANA_PER_LEVEL = 5.0
MANA_PER_INT = 5.0
BASE_MAX_MANA = 30.0
```

### Integration Points
- **HUD**: Displays current/max mana alongside stamina
- **Rest Menu**: "Until mana restored" option (key 5)
- **Save/Load**: Mana persists between sessions
- **Signals**: `mana_changed`, `mana_depleted` via EventBus

### Related Methods (SurvivalSystem)
- `get_max_mana()` - Calculate max mana from INT and level
- `consume_mana(amount)` - Deduct mana for spell casting
- `regenerate_mana(multiplier)` - Called each turn
- `restore_mana(amount)` - Instant mana restoration

For detailed mana documentation, see [Survival System - Mana](./survival-system.md#mana-system).

## Spell Data & Manager (Implemented)

SpellManager autoload loads spell definitions from JSON files.

### Data Location
```
data/spells/
├── evocation/      # Damage and energy spells
├── conjuration/    # Creation, summoning, healing
├── enchantment/    # Mind control
├── transmutation/  # Transformation
├── divination/     # Detection, knowledge
├── necromancy/     # Death, undead
├── abjuration/     # Protection, warding
└── illusion/       # Deception
```

### SpellManager Methods

```gdscript
# Get spell by ID
SpellManager.get_spell("spark") -> Spell

# Query spells
SpellManager.get_spells_by_school("evocation") -> Array[Spell]
SpellManager.get_spells_by_level(1) -> Array[Spell]
SpellManager.get_cantrips() -> Array[Spell]
SpellManager.get_all_spell_ids() -> Array[String]

# Check casting requirements
SpellManager.can_cast(caster, spell) -> {can_cast: bool, reason: String}

# Calculate scaled values
SpellManager.calculate_spell_damage(spell, caster) -> int
SpellManager.calculate_spell_duration(spell, caster) -> int
```

### Spell Properties

| Property | Type | Description |
|----------|------|-------------|
| id | String | Unique identifier |
| name | String | Display name |
| school | String | Magic school |
| level | int | 0-10 (0 = cantrip) |
| mana_cost | int | Mana required |
| requirements | Dict | {character_level, intelligence} |
| targeting | Dict | {mode, range, requires_los} |
| effects | Dict | Spell effects (damage, buff, heal) |

### Current Spells

| Spell | School | Level | Cost | Effect |
|-------|--------|-------|------|--------|
| light | evocation | 0 | 0 | +2 vision for 100 turns |
| spark | evocation | 1 | 5 | 8 lightning damage |
| heal | conjuration | 1 | 8 | Restore 10 HP |
| shield | abjuration | 1 | 5 | +3 armor for 20 turns |

For spell JSON format, see [Spell Data Format](../data/spells.md).

## Spellbook & Spell Learning (Implemented)

Players must possess a spellbook item to learn and access spells.

### Spellbook Item

A spellbook is a book item with the `spellbook` flag:
```json
{
  "id": "spellbook",
  "category": "book",
  "flags": {"readable": true, "magical": true, "spellbook": true}
}
```

### Player Known Spells

- `known_spells: Array[String]` - List of learned spell IDs
- Persisted in save/load
- Accessed via `player.get_known_spells()` which returns full Spell objects

### Learning Spells

Spells are learned from **Spell Tomes** - book items with `teaches_spell` property:

```json
{
  "id": "tome_of_spark",
  "name": "Tome of Spark",
  "category": "book",
  "subtype": "spell_tome",
  "teaches_spell": "spark"
}
```

**Learning Requirements:**
- Player must have a spellbook in inventory
- Player must meet spell's INT requirement
- Player must meet spell's level requirement
- Player must not already know the spell
- Spell tome is consumed on successful learning

### Player Methods

```gdscript
player.has_spellbook() -> bool       # Check for spellbook item
player.knows_spell(spell_id) -> bool # Check if spell is known
player.learn_spell(spell_id) -> bool # Learn a new spell
player.get_known_spells() -> Array   # Get all known Spell objects
```

### EventBus Signals

```gdscript
signal spell_learned(spell_id: String)
signal spell_cast(caster, spell, targets: Array, result: Dictionary)
```

### Spell List UI

Open with **Shift+M** to view known spells:
- Shows all learned spells with name, school, level, mana cost
- Detail panel shows requirements and whether player can cast
- School colors: Evocation (orange), Conjuration (purple), etc.

### Current Spell Tomes

| Tome | Teaches | Value |
|------|---------|-------|
| Tome of Light | light cantrip | 25 |
| Tome of Spark | spark (Lv1) | 75 |
| Tome of Healing | heal (Lv1) | 100 |
| Tome of Shield | shield (Lv1) | 75 |

## Planned Features

### Spellcasting
- Minimum 8 INT required for all magic
- Spells require level + INT to cast
- Spell schools: Evocation, Conjuration, Enchantment, Transmutation, Divination, Necromancy, Abjuration, Illusion
- Failure modes: Fizzle, Backfire, Wild Magic

### Magic Items
- Spellbooks - Required to store learned spells
- Scrolls - Cast spells without knowing them
- Wands - Charged items with limited uses
- Staves - Melee weapons with casting bonuses
- Magic Rings/Amulets - Passive effect equipment

### Rituals
- Multi-turn channeling
- Component consumption
- No level requirement (only INT)
- Interruptible by damage

## Keybindings

### Implemented
| Key | Action |
|-----|--------|
| Shift+M | Open spellbook (view known spells) |

### Planned
| Key | Action |
|-----|--------|
| K | Open spell casting menu |
| Shift+T | Open ritual menu (T alone is Talk) |
| Shift+S | Summon commands (if summons active) |

## Related Documentation

- [Spell Data Format](../data/spells.md)
- [Ritual Data Format](../data/rituals.md)
- [Spell Manager](spell-manager.md) (to be created)
- [Ritual System](ritual-system.md) (to be created)

## Implementation Phases

The magic system is implemented across 25 phases. See `plans/features/magic-system/` for detailed implementation plans.
