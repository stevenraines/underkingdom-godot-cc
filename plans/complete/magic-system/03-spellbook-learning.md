# Phase 3: Spellbook & Spell Learning

## Overview
Implement the spellbook item and the system for learning/tracking known spells.

## Dependencies
- Phase 1: Mana System
- Phase 2: Spell Data & Manager

## Implementation Steps

### 3.1 Create Spellbook Item
**File:** `data/items/books/spellbook.json`

```json
{
  "id": "spellbook",
  "name": "Spellbook",
  "description": "A leather-bound tome for recording arcane knowledge.",
  "category": "book",
  "subtype": "spellbook",
  "flags": {
    "spellbook": true
  },
  "weight": 2.0,
  "value": 50,
  "max_stack": 1,
  "ascii_char": "+",
  "ascii_color": "#8844AA"
}
```

### 3.2 Add Known Spells to Player
**File:** `entities/player.gd`

```gdscript
var known_spells: Array[String] = []  # Array of spell IDs

func has_spellbook() -> bool:
    return inventory.has_item_with_flag("spellbook")

func knows_spell(spell_id: String) -> bool:
    return spell_id in known_spells

func learn_spell(spell_id: String) -> bool:
    if not has_spellbook():
        return false
    if knows_spell(spell_id):
        return false
    var spell = SpellManager.get_spell(spell_id)
    if spell == null:
        return false
    known_spells.append(spell_id)
    EventBus.spell_learned.emit(spell_id)
    return true

func get_castable_spells() -> Array[Spell]:
    var castable: Array[Spell] = []
    for spell_id in known_spells:
        var spell = SpellManager.get_spell(spell_id)
        if spell and SpellManager.can_cast(self, spell).can_cast:
            castable.append(spell)
    return castable
```

### 3.3 Add Spell Learning EventBus Signal
**File:** `autoload/event_bus.gd`

```gdscript
signal spell_learned(spell_id: String)
signal spell_cast(caster: Entity, spell: Spell, targets: Array, result: Dictionary)
```

### 3.4 Add Spell Learning Item Property
**File:** `items/item.gd`

Add support for items that teach spells:
```gdscript
var teaches_spell: String = ""  # spell_id to teach when read
```

### 3.5 Create Spell Teaching Books
**File:** `data/items/books/tome_of_spark.json`

```json
{
  "id": "tome_of_spark",
  "name": "Tome of Spark",
  "description": "An instructional text on channeling lightning.",
  "category": "book",
  "subtype": "spell_tome",
  "flags": {
    "readable": true,
    "magical": true
  },
  "teaches_spell": "spark",
  "weight": 1.0,
  "value": 75,
  "max_stack": 1,
  "ascii_char": "+",
  "ascii_color": "#FFFF00"
}
```

### 3.6 Implement Reading Spell Tomes
**File:** `items/item.gd` or `entities/player.gd`

When reading a spell tome:
1. Check if player has spellbook
2. Check if player meets spell requirements (level, INT)
3. If requirements not met: "The arcane symbols are incomprehensible to you."
4. If already known: "You already know this spell."
5. If can learn: Add spell to known_spells, consume tome (optional)

```gdscript
func _use_spell_tome(user: Entity) -> Dictionary:
    if not user.has_spellbook():
        return {success = false, message = "You need a spellbook to learn spells."}

    var spell = SpellManager.get_spell(teaches_spell)
    if spell == null:
        return {success = false, message = "This tome contains corrupted knowledge."}

    # Check requirements
    if user.get_effective_attribute("INT") < spell.requirements.intelligence:
        return {success = false, message = "The arcane symbols are incomprehensible to you."}
    if user.level < spell.requirements.character_level:
        return {success = false, message = "This magic is beyond your current abilities."}

    if user.knows_spell(teaches_spell):
        return {success = false, message = "You already know this spell."}

    user.learn_spell(teaches_spell)
    return {success = true, consumed = true, message = "You inscribe %s into your spellbook!" % spell.name}
```

### 3.7 Add Known Spells to Save/Load
**File:** `autoload/save_manager.gd`

Include `known_spells` array in player serialization.

### 3.8 Create Basic Spell List UI
**IMPORTANT:** Use the `ui-implementation` agent for creating this UI.

**File:** `ui/spell_list.gd` and `ui/spell_list.tscn` (new)

Simple UI to show known spells:
- List all known spells with name, school, level, mana cost
- Show "No spellbook" if player lacks one
- Show "No spells learned" if spellbook but empty
- Keybind: 'M' for magic/spell list

## Testing Checklist

- [ ] Spellbook item exists and can be picked up
- [ ] `has_spellbook()` returns true when spellbook in inventory
- [ ] `has_spellbook()` returns false without spellbook
- [ ] Spell tome can be read
- [ ] Reading tome without spellbook shows error message
- [ ] Reading tome with low INT shows "incomprehensible" message
- [ ] Reading tome with low level shows "beyond abilities" message
- [ ] Successfully reading tome adds spell to known_spells
- [ ] `knows_spell()` returns true for learned spells
- [ ] `spell_learned` signal fires when spell learned
- [ ] Known spells persist through save/load
- [ ] Spell list UI shows known spells (press M)
- [ ] Spell list shows requirements not met for high-level spells

## Files Modified
- `entities/player.gd`
- `autoload/event_bus.gd`
- `autoload/save_manager.gd`
- `items/item.gd`

## Files Created
- `data/items/books/spellbook.json`
- `data/items/books/tome_of_spark.json`
- `data/items/books/tome_of_shield.json`
- `ui/spell_list.gd`
- `ui/spell_list.tscn`

## Next Phase
Once spellbook and learning work, proceed to **Phase 4: Basic Spell Casting**
