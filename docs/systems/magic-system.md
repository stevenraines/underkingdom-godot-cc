# Magic System

The magic system provides spellcasting and ritual mechanics for the player.

## Overview

The magic system consists of two main components:
- **Spells** - Instant-cast abilities that consume mana
- **Rituals** - Multi-turn channeled abilities that consume components

## Implementation Status

- **Phase 01** (Mana System) - Implemented
- **Phase 02** (Spell Data & Manager) - Implemented

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

**Note:** These are planned keybindings. Some may conflict with existing controls and will be adjusted during implementation.

Conflicts identified:
- `C` is used for Crafting menu
- `M` is used for World map

Proposed keybindings:
| Key | Action |
|-----|--------|
| K | Open spell casting menu |
| Shift+K | View known spells |
| Shift+T | Open ritual menu (T alone is Talk) |
| Shift+S | Summon commands (if summons active) |

## Related Documentation

- [Spell Data Format](../data/spells.md)
- [Ritual Data Format](../data/rituals.md)
- [Spell Manager](spell-manager.md) (to be created)
- [Ritual System](ritual-system.md) (to be created)

## Implementation Phases

The magic system is implemented across 25 phases. See `plans/features/magic-system/` for detailed implementation plans.
