# Phase 10: Scroll Transcription

## Overview
Allow players to transcribe spells from scrolls into their spellbook, with a success chance based on level and INT.

**Terminology Note:**
- **Transcribing** = copying a spell from a scroll into a spellbook
- **Inscribing** = assigning a custom name to an item in inventory (existing feature)

## Dependencies
- Phase 3: Spellbook & Learning
- Phase 9: Scrolls

## Pre-Implementation Check

**IMPORTANT:** Before implementing, check for existing inscription/naming systems:
1. Search for "inscribe" or "inscription" in `ui/inventory_screen.gd`
2. Ensure the new "Transcribe" option is clearly separate from item inscription (naming)
3. If the inventory already has an "Inscribe" option for naming items, the spell transcription option should use different terminology

## Implementation Steps

### 10.1 Add Transcribe Option for Scrolls
**File:** `ui/inventory_screen.gd`

When selecting a scroll, show both "Use" and "Transcribe" options:
```gdscript
func _show_scroll_options(scroll: Item):
    var options = ["Use Scroll", "Transcribe to Spellbook", "Cancel"]
    # Show option menu
```

### 10.2 Implement Transcription Logic
**File:** `entities/player.gd`

```gdscript
func attempt_transcription(scroll: Item) -> Dictionary:
    if not has_spellbook():
        return {success = false, message = "You need a spellbook to transcribe spells."}

    var spell = SpellManager.get_spell(scroll.casts_spell)
    if spell == null:
        return {success = false, message = "This scroll contains corrupted magic."}

    # Check if already known
    if knows_spell(spell.id):
        return {success = false, message = "You already know this spell.", consumed = false}

    # Check requirements - must meet spell requirements to transcribe
    if get_effective_attribute("INT") < spell.requirements.intelligence:
        return {success = false, message = "This spell is too complex for you to understand.", consumed = false}
    if level < spell.requirements.character_level:
        return {success = false, message = "You lack the experience to comprehend this magic.", consumed = false}

    # Calculate success chance
    var success_chance = calculate_transcription_chance(spell)

    # Roll for success
    var roll = randf() * 100
    var success = roll < success_chance

    if success:
        learn_spell(spell.id)
        return {
            success = true,
            consumed = true,
            message = "You successfully transcribe %s into your spellbook!" % spell.name
        }
    else:
        return {
            success = false,
            consumed = true,
            message = "The arcane symbols blur and fade. The scroll crumbles to dust."
        }

func calculate_transcription_chance(spell: Spell) -> float:
    var level_diff = level - spell.level
    var base_chance: float

    # Base chance from level difference
    match level_diff:
        var d when d <= 0: base_chance = 50.0
        1: base_chance = 65.0
        2: base_chance = 75.0
        3: base_chance = 85.0
        _: base_chance = 95.0

    # INT bonus: +2% per INT above requirement
    var int_above_req = get_effective_attribute("INT") - spell.requirements.intelligence
    base_chance += int_above_req * 2.0

    return clampf(base_chance, 10.0, 98.0)
```

### 10.3 Add Transcription UI Feedback
**IMPORTANT:** Use the `ui-implementation` agent for creating this UI.

**File:** `ui/transcription_dialog.gd` (new)

Show confirmation dialog before transcribing:
```
Transcribe "Fireball" into your spellbook?

Success Chance: 65%

The scroll will be consumed regardless of success.

[Transcribe] [Cancel]
```

### 10.4 Handle Transcription from Inventory
**File:** `ui/inventory_screen.gd`

```gdscript
func _on_transcribe_selected(scroll: Item):
    var spell = SpellManager.get_spell(scroll.casts_spell)
    var chance = player.calculate_transcription_chance(spell)

    # Show confirmation dialog
    transcription_dialog.show_dialog(scroll, spell, chance)

func _on_transcription_confirmed(scroll: Item):
    var result = player.attempt_transcription(scroll)

    if result.consumed:
        player.inventory.remove_item(scroll, 1)

    EventBus.message_logged.emit(result.message,
        Color.GREEN if result.success else Color.RED)
```

### 10.5 Add EventBus Signal
**File:** `autoload/event_bus.gd`

```gdscript
signal transcription_attempted(scroll: Item, spell: Spell, success: bool)
```

### 10.6 Show Transcription Chance in Scroll Tooltip
**File:** `ui/inventory_screen.gd`

When hovering over a scroll, show:
```
Scroll of Fireball
Casts: Fireball (Level 7)
Transcription Chance: 65%
Requires: Level 7, INT 14
```

## Testing Checklist

- [ ] "Transcribe" option appears for scrolls in inventory
- [ ] "Transcribe" is distinct from "Inscribe" (item naming) if both exist
- [ ] Cannot transcribe without spellbook
- [ ] Cannot transcribe spell you already know
- [ ] Cannot transcribe spell above your level requirement
- [ ] Cannot transcribe spell above your INT requirement
- [ ] Success chance formula correct (level diff + INT bonus)
- [ ] Successful transcription adds spell to known_spells
- [ ] Failed transcription consumes scroll
- [ ] Successful transcription consumes scroll
- [ ] Confirmation dialog shows before transcribing
- [ ] Success chance displayed in confirmation
- [ ] Success chance displayed in scroll tooltip
- [ ] Appropriate success/failure messages shown

## Documentation Updates

- [ ] CLAUDE.md updated with transcription mechanics
- [ ] Help screen updated with transcription info
- [ ] `docs/systems/magic-system.md` updated with transcription
- [ ] `docs/data/items.md` updated if scroll format changed

## Files Modified
- `entities/player.gd`
- `ui/inventory_screen.gd`
- `autoload/event_bus.gd`

## Files Created
- `ui/transcription_dialog.gd`
- `ui/transcription_dialog.tscn`

## Next Phase
Once transcription works, proceed to **Phase 11: Wands & Staves**
