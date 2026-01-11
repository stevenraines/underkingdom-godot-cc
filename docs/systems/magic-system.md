# Magic System

The magic system provides spellcasting and ritual mechanics for the player.

## Overview

The magic system consists of two main components:
- **Spells** - Instant-cast abilities that consume mana
- **Rituals** - Multi-turn channeled abilities that consume components

## Status: Not Yet Implemented

This documentation will be updated as each magic system phase is implemented.

## Planned Features

### Mana System
- Mana pool: Base 30 + (INT × 5)
- Regenerates during rest
- Required for all spellcasting

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
