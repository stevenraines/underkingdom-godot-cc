# Phase 11: Wands & Staves

## Overview
Implement wands (charged spell items) and staves (melee weapons with casting bonuses).

## Dependencies
- Phase 6: Damage Spells
- Phase 9: Scrolls (for spell casting pattern)

## Implementation Steps

### 11.1 Add Wand Properties to Item
**File:** `items/item.gd`

```gdscript
var is_wand: bool = false
var charges: int = 0
var max_charges: int = 0
var recharge_cost: int = 0
var spell_level_override: int = -1  # -1 means use spell's default
```

### 11.2 Implement Wand Usage
**File:** `items/item.gd`

```gdscript
func _use_wand(user: Entity) -> Dictionary:
    if user.get_effective_attribute("INT") < 8:
        return {success = false, message = "You lack the intelligence to use wands."}

    if charges <= 0:
        return {success = false, message = "The wand is depleted."}

    var spell = SpellManager.get_spell(casts_spell)
    if spell == null:
        return {success = false, message = "The wand's magic is corrupted."}

    if spell.targeting.mode == "ranged":
        EventBus.wand_targeting_started.emit(self, spell)
        return {success = true, message = "Select a target..."}
    else:
        return _cast_wand_spell(user, spell)

func _cast_wand_spell(user: Entity, spell: Spell) -> Dictionary:
    charges -= 1
    var cast_level = spell_level_override if spell_level_override > 0 else spell.level
    var result = MagicSystem.cast_from_item(user, spell, [], cast_level)
    result.message = "The wand releases a %s!" % spell.name
    return result
```

### 11.3 Add Wand Targeting Handler
**File:** `systems/input_handler.gd`

```gdscript
var pending_wand: Item = null

func _on_wand_targeting_started(wand: Item, spell: Spell):
    pending_wand = wand
    targeting_system.start_spell_targeting(player, spell)

func _on_targeting_confirmed_wand():
    if pending_wand:
        pending_wand._cast_wand_spell(player, SpellManager.get_spell(pending_wand.casts_spell))
        pending_wand = null
```

### 11.4 Add Staff Properties to Item
**File:** `items/item.gd`

```gdscript
var is_casting_focus: bool = false
var casting_bonuses: Dictionary = {}
# Example: {success_modifier: 10, school_affinity: "evocation", school_damage_bonus: 2, mana_cost_modifier: -10}
```

### 11.5 Apply Staff Bonuses to Spellcasting
**File:** `systems/magic_system.gd`

```gdscript
static func get_casting_bonuses(caster: Entity) -> Dictionary:
    var bonuses = {
        success_modifier = 0,
        damage_bonus = 0,
        mana_cost_modifier = 0,
        school_bonuses = {}
    }

    # Check equipped items for casting focus
    if caster.inventory:
        var main_hand = caster.inventory.get_equipped("main_hand")
        if main_hand and main_hand.is_casting_focus:
            var cb = main_hand.casting_bonuses
            bonuses.success_modifier += cb.get("success_modifier", 0)
            bonuses.mana_cost_modifier += cb.get("mana_cost_modifier", 0)

            var affinity = cb.get("school_affinity", "")
            if affinity != "":
                bonuses.school_bonuses[affinity] = cb.get("school_damage_bonus", 0)

    return bonuses

static func calculate_failure_chance(caster: Entity, spell: Spell) -> float:
    var base_chance = # ... existing calculation ...

    # Apply staff bonus
    var bonuses = get_casting_bonuses(caster)
    base_chance -= bonuses.success_modifier

    return clampf(base_chance, MIN_FAILURE_CHANCE, MAX_FAILURE_CHANCE)

static func calculate_final_mana_cost(caster: Entity, spell: Spell) -> int:
    var cost = spell.mana_cost
    var bonuses = get_casting_bonuses(caster)
    cost = int(cost * (100 + bonuses.mana_cost_modifier) / 100.0)
    return max(1, cost)
```

### 11.6 Create Wand JSON Files
**Directory:** `data/items/weapons/wands/`

**wand_of_sparks.json:**
```json
{
  "id": "wand_of_sparks",
  "name": "Wand of Sparks",
  "description": "A slender wand crackling with electrical energy.",
  "category": "weapon",
  "subtype": "wand",
  "flags": {
    "magical": true,
    "wand": true,
    "charged": true
  },
  "casts_spell": "spark",
  "spell_level_override": 3,
  "charges": 15,
  "max_charges": 15,
  "recharge_cost": 50,
  "weight": 0.5,
  "value": 150,
  "ascii_char": "/",
  "ascii_color": "#FFFF00"
}
```

**wand_of_fireballs.json:**
```json
{
  "id": "wand_of_fireballs",
  "name": "Wand of Fireballs",
  "description": "A charred wand radiating heat.",
  "category": "weapon",
  "subtype": "wand",
  "flags": {
    "magical": true,
    "wand": true,
    "charged": true
  },
  "casts_spell": "fireball",
  "spell_level_override": 7,
  "charges": 5,
  "max_charges": 5,
  "recharge_cost": 200,
  "weight": 0.5,
  "value": 400,
  "ascii_char": "/",
  "ascii_color": "#FF6600"
}
```

### 11.7 Create Staff JSON Files
**Directory:** `data/items/weapons/staves/`

**wooden_staff.json:**
```json
{
  "id": "wooden_staff",
  "name": "Wooden Staff",
  "description": "A sturdy wooden staff suitable for both combat and spellcasting.",
  "category": "weapon",
  "subtype": "staff",
  "flags": {
    "equippable": true,
    "two_handed": true,
    "casting_focus": true
  },
  "equip_slots": ["main_hand"],
  "damage_bonus": 4,
  "attack_type": "melee",
  "casting_bonuses": {
    "success_modifier": 5
  },
  "weight": 2.0,
  "value": 30,
  "ascii_char": "/",
  "ascii_color": "#8B4513"
}
```

**staff_of_fire.json:**
```json
{
  "id": "staff_of_fire",
  "name": "Staff of Fire",
  "description": "A staff crowned with an ever-burning flame.",
  "category": "weapon",
  "subtype": "staff",
  "flags": {
    "equippable": true,
    "magical": true,
    "two_handed": true,
    "casting_focus": true
  },
  "equip_slots": ["main_hand"],
  "damage_bonus": 5,
  "attack_type": "melee",
  "casting_bonuses": {
    "success_modifier": 10,
    "school_affinity": "evocation",
    "school_damage_bonus": 2
  },
  "weight": 2.5,
  "value": 250,
  "ascii_char": "/",
  "ascii_color": "#FF6600"
}
```

**archmage_staff.json:**
```json
{
  "id": "archmage_staff",
  "name": "Archmage Staff",
  "description": "A legendary staff of immense magical power.",
  "category": "weapon",
  "subtype": "staff",
  "flags": {
    "equippable": true,
    "magical": true,
    "two_handed": true,
    "casting_focus": true
  },
  "equip_slots": ["main_hand"],
  "damage_bonus": 8,
  "attack_type": "melee",
  "casting_bonuses": {
    "success_modifier": 15,
    "mana_cost_modifier": -10
  },
  "weight": 3.0,
  "value": 1000,
  "ascii_char": "/",
  "ascii_color": "#AA44FF"
}
```

### 11.8 Add Wand Recharging at Mage NPC
**File:** To be integrated in Phase 19 (Town Mage)

Mage NPC offers recharge service for depleted wands.

### 11.9 Display Charges in UI
**File:** `ui/inventory_screen.gd`

Show wand charges: "Wand of Sparks (12/15 charges)"

### 11.10 Add EventBus Signal
**File:** `autoload/event_bus.gd`

```gdscript
signal wand_targeting_started(wand: Item, spell: Spell)
```

## Testing Checklist

- [ ] Wand can be used from inventory
- [ ] Wand enters targeting mode for ranged spells
- [ ] Wand consumes 1 charge per use
- [ ] Wand shows "depleted" when charges = 0
- [ ] Wand charges display in inventory
- [ ] Wand requires 8 INT to use
- [ ] Wand does NOT require knowing the spell
- [ ] Wand does NOT consume mana
- [ ] Staff can be equipped as two-handed weapon
- [ ] Staff can be used for melee attacks
- [ ] Staff provides success_modifier to spell failure chance
- [ ] Staff of Fire provides bonus damage to evocation spells
- [ ] Archmage Staff reduces mana costs by 10%
- [ ] Multiple staves don't stack (only equipped counts)

## Files Modified
- `items/item.gd`
- `systems/magic_system.gd`
- `systems/input_handler.gd`
- `autoload/event_bus.gd`
- `ui/inventory_screen.gd`

## Files Created
- `data/items/weapons/wands/wand_of_sparks.json`
- `data/items/weapons/wands/wand_of_fireballs.json`
- `data/items/weapons/wands/wand_of_frost.json`
- `data/items/weapons/staves/wooden_staff.json`
- `data/items/weapons/staves/staff_of_fire.json`
- `data/items/weapons/staves/staff_of_mind.json`
- `data/items/weapons/staves/necromancer_staff.json`
- `data/items/weapons/staves/archmage_staff.json`

## Next Phase
Once wands and staves work, proceed to **Phase 12: Magic Rings**
