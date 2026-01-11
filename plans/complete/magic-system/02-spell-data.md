# Phase 2: Spell Data & Manager

## Overview
Create the SpellManager autoload to load and manage spell definitions from JSON files.

## Dependencies
- Phase 1: Mana System (for mana cost validation)

## Implementation Steps

### 2.1 Create Spell Data Structure
**File:** `magic/spell.gd` (new)

Create Spell class to hold spell data:
```gdscript
class_name Spell
extends RefCounted

var id: String
var name: String
var description: String
var school: String  # evocation, conjuration, etc.
var level: int  # 1-10
var mana_cost: int
var requirements: Dictionary  # {character_level: int, intelligence: int}
var targeting: Dictionary  # {mode: String, range: int, aoe_radius: int}
var effects: Dictionary  # spell-specific effects
var save: Dictionary  # {type: String, on_success: String}
var concentration: bool = false
var duration: Dictionary  # {base: int, scaling: int}
var scaling: Dictionary  # {damage: int, duration: int, etc.}
var cast_message: String
var ascii_char: String
var ascii_color: String

static func from_dict(data: Dictionary) -> Spell:
    # Parse JSON data into Spell object
```

### 2.2 Create SpellManager Autoload
**File:** `autoload/spell_manager.gd` (new)

```gdscript
class_name SpellManager
extends Node

const SPELL_DATA_PATH = "res://data/spells"

var spells: Dictionary = {}  # spell_id -> Spell
var spells_by_school: Dictionary = {}  # school -> Array[Spell]
var spells_by_level: Dictionary = {}  # level -> Array[Spell]

func _ready() -> void:
    _load_spells_recursive(SPELL_DATA_PATH)

func get_spell(spell_id: String) -> Spell
func get_spells_by_school(school: String) -> Array[Spell]
func get_spells_by_level(level: int) -> Array[Spell]
func can_cast(caster: Entity, spell: Spell) -> Dictionary  # {can_cast: bool, reason: String}
```

### 2.3 Register SpellManager Autoload
**File:** `project.godot`

Add SpellManager to autoload list after ItemManager.

### 2.4 Create Data Directory Structure
Create directories:
```
data/spells/
├── evocation/
├── conjuration/
├── enchantment/
├── transmutation/
├── divination/
├── necromancy/
├── abjuration/
└── illusion/
```

### 2.5 Create Initial Spell JSON Files
Create a few test spells to validate the system:

**File:** `data/spells/evocation/spark.json`
```json
{
  "id": "spark",
  "name": "Spark",
  "description": "A small bolt of lightning strikes the target.",
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
    "requires_los": true
  },
  "effects": {
    "damage": {
      "type": "lightning",
      "base": 8,
      "scaling": 3
    }
  },
  "cast_message": "You release a spark of lightning!",
  "ascii_char": "*",
  "ascii_color": "#FFFF00"
}
```

**File:** `data/spells/abjuration/shield.json`
```json
{
  "id": "shield",
  "name": "Shield",
  "description": "A magical barrier provides temporary protection.",
  "school": "abjuration",
  "level": 1,
  "mana_cost": 5,
  "requirements": {
    "character_level": 1,
    "intelligence": 8
  },
  "targeting": {
    "mode": "self"
  },
  "effects": {
    "buff": {
      "armor_bonus": 3,
      "duration": 20,
      "duration_scaling": 5
    }
  },
  "cast_message": "A shimmering shield surrounds you!",
  "ascii_char": "O",
  "ascii_color": "#4444FF"
}
```

### 2.6 Add Spell Requirement Checking
**File:** `autoload/spell_manager.gd`

```gdscript
func can_cast(caster: Entity, spell: Spell) -> Dictionary:
    # Check minimum INT (8 for all magic)
    if caster.get_effective_attribute("INT") < 8:
        return {can_cast = false, reason = "Insufficient intelligence for magic"}

    # Check spell-specific INT requirement
    if caster.get_effective_attribute("INT") < spell.requirements.intelligence:
        return {can_cast = false, reason = "Insufficient intelligence for this spell"}

    # Check level requirement
    if caster.level < spell.requirements.character_level:
        return {can_cast = false, reason = "Insufficient level"}

    # Check mana
    if caster.survival.mana < spell.mana_cost:
        return {can_cast = false, reason = "Insufficient mana"}

    return {can_cast = true, reason = ""}
```

## Testing Checklist

- [ ] SpellManager loads on game start
- [ ] Spells load from JSON files in data/spells/
- [ ] Spells organized by school subdirectories
- [ ] `get_spell("spark")` returns valid Spell object
- [ ] `get_spells_by_school("evocation")` returns array of evocation spells
- [ ] `can_cast()` returns false for low INT character
- [ ] `can_cast()` returns false for low level character
- [ ] `can_cast()` returns false when mana insufficient
- [ ] `can_cast()` returns true when all requirements met
- [ ] Spell properties (damage, range, etc.) accessible from Spell object

## Files Modified
- `project.godot` (add autoload)

## Files Created
- `magic/spell.gd`
- `autoload/spell_manager.gd`
- `data/spells/evocation/spark.json`
- `data/spells/abjuration/shield.json`

## Next Phase
Once spell data loads correctly, proceed to **Phase 3: Spellbook & Learning**
