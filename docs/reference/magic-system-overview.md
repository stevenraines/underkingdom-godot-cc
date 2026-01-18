# Magic System Overview (Planned)

The magic system is designed but not yet implemented. See `plans/features/magic-system/` for the 25-phase implementation plan.

---

## Overview

- **Spells**: Instant-cast, mana-based, level+INT requirements
- **Rituals**: Multi-turn channeling, component-based, no level requirement
- 8 schools of magic (Evocation, Conjuration, Enchantment, Transmutation, Divination, Necromancy, Abjuration, Illusion)
- Minimum 8 INT required for all magic

---

## Planned Keybindings

Current keybinding conflicts to resolve:
- `C` is used for Crafting menu
- `M` is used for World map

Proposed alternatives:
- `K` - Open spell casting menu
- `Shift+K` - View known spells
- `Shift+T` - Open ritual menu
- `Shift+S` - Summon commands

---

## Schools of Magic

| School | Focus |
|--------|-------|
| Evocation | Direct damage, energy manipulation |
| Conjuration | Summoning, teleportation |
| Enchantment | Mind control, buffs |
| Transmutation | Shape changing, material alteration |
| Divination | Detection, knowledge |
| Necromancy | Undead, life/death manipulation |
| Abjuration | Protection, dispelling |
| Illusion | Deception, sensory manipulation |

---

## Documentation

- `docs/systems/magic-system.md` - System overview
- `docs/data/spells.md` - Spell JSON format
- `docs/data/rituals.md` - Ritual JSON format
- `plans/features/magic-system/` - Implementation phases

---

## Data Locations

- `data/spells/` - Spell definitions by school
- `data/rituals/` - Ritual definitions (planned)
- `autoload/spell_manager.gd` - Spell loading and requirements
- `autoload/ritual_manager.gd` - Ritual loading (planned)
