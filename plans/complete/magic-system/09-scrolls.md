# Phase 9: Scrolls

## Overview
Implement scroll items that allow one-time spell casting without knowing the spell.

## Dependencies
- Phase 6: Damage Spells
- Phase 7: Buff/Debuff Spells

## Implementation Steps

### 9.1 Create Scroll Item Subtype
**File:** `items/item.gd`

Add scroll-specific properties:
```gdscript
var casts_spell: String = ""  # spell_id to cast when used
var is_scroll: bool = false
```

### 9.2 Implement Scroll Usage
**File:** `items/item.gd`

```gdscript
func _use_scroll(user: Entity) -> Dictionary:
    if user.get_effective_attribute("INT") < 8:
        return {success = false, message = "You lack the intelligence to use scrolls."}

    var spell = SpellManager.get_spell(casts_spell)
    if spell == null:
        return {success = false, message = "This scroll contains corrupted magic."}

    # Scrolls bypass level/INT requirements but still need targeting
    if spell.targeting.mode == "self":
        # Cast immediately
        var result = MagicSystem.cast_from_scroll(user, spell)
        result.consumed = true
        return result
    elif spell.targeting.mode == "ranged":
        # Enter targeting mode, consume on cast
        EventBus.scroll_targeting_started.emit(self, spell)
        return {success = true, consumed = false, message = "Select a target..."}

    return {success = false, message = "Unknown scroll type."}
```

### 9.3 Add Scroll Casting to MagicSystem
**File:** `systems/magic_system.gd`

```gdscript
static func cast_from_scroll(caster: Entity, spell: Spell, targets: Array = []) -> Dictionary:
    # Scrolls don't consume mana
    # Scrolls don't fail (the magic is already imbued)
    # Scrolls cast at minimum spell level (no scaling)

    var result = {
        success = true,
        damage_dealt = 0,
        effects_applied = [],
        message = "",
        from_scroll = true
    }

    # Apply effects at spell's base level (no caster level scaling)
    result = _apply_spell_effects_at_level(caster, spell, targets, spell.level, result)

    EventBus.spell_cast.emit(caster, spell, targets, result)
    return result
```

### 9.4 Handle Scroll Targeting
**File:** `systems/input_handler.gd`

```gdscript
var pending_scroll: Item = null

func _on_scroll_targeting_started(scroll: Item, spell: Spell):
    pending_scroll = scroll
    targeting_system.start_spell_targeting(player, spell)

func _on_targeting_confirmed():
    if pending_scroll:
        # Consume the scroll after successful cast
        player.inventory.remove_item(pending_scroll, 1)
        pending_scroll = null
```

### 9.5 Add EventBus Signal
**File:** `autoload/event_bus.gd`

```gdscript
signal scroll_targeting_started(scroll: Item, spell: Spell)
```

### 9.6 Create Scroll JSON Files
**Directory:** `data/items/consumables/scrolls/`

**scroll_spark.json:**
```json
{
  "id": "scroll_spark",
  "name": "Scroll of Spark",
  "description": "A parchment inscribed with the Spark incantation.",
  "category": "consumable",
  "subtype": "scroll",
  "flags": {
    "consumable": true,
    "magical": true,
    "scroll": true
  },
  "casts_spell": "spark",
  "weight": 0.1,
  "value": 25,
  "max_stack": 5,
  "ascii_char": "~",
  "ascii_color": "#FFFF00"
}
```

**scroll_shield.json:**
```json
{
  "id": "scroll_shield",
  "name": "Scroll of Shield",
  "description": "A parchment inscribed with the Shield incantation.",
  "category": "consumable",
  "subtype": "scroll",
  "flags": {
    "consumable": true,
    "magical": true,
    "scroll": true
  },
  "casts_spell": "shield",
  "weight": 0.1,
  "value": 25,
  "max_stack": 5,
  "ascii_char": "~",
  "ascii_color": "#4444FF"
}
```

**scroll_fireball.json:**
```json
{
  "id": "scroll_fireball",
  "name": "Scroll of Fireball",
  "description": "A parchment inscribed with the Fireball incantation.",
  "category": "consumable",
  "subtype": "scroll",
  "flags": {
    "consumable": true,
    "magical": true,
    "scroll": true
  },
  "casts_spell": "fireball",
  "weight": 0.1,
  "value": 150,
  "max_stack": 3,
  "ascii_char": "~",
  "ascii_color": "#FF6600"
}
```

### 9.7 Add Scrolls to Loot Tables
**File:** `data/loot_tables/dungeon_common.json` (or appropriate file)

Add scroll entries to dungeon loot.

### 9.8 Add Scroll Option in Inventory
**File:** `ui/inventory_screen.gd`

When selecting a scroll, show "Use" option that triggers `_use_scroll()`.

## Testing Checklist

- [ ] Scroll of Spark can be used from inventory
- [ ] Using scroll enters targeting mode (for ranged spells)
- [ ] Scroll consumed after successful cast
- [ ] Scroll NOT consumed if targeting cancelled
- [ ] Scroll of Shield casts immediately (self-target)
- [ ] Scrolls work without spellbook
- [ ] Scrolls work even if player doesn't know spell
- [ ] Scrolls require minimum 8 INT
- [ ] Scrolls don't consume mana
- [ ] Scrolls don't have failure chance
- [ ] Scroll damage uses base spell level (no scaling)
- [ ] Scrolls stack in inventory (max 3-5)
- [ ] Scrolls can be found in dungeon loot

## Files Modified
- `items/item.gd`
- `systems/magic_system.gd`
- `systems/input_handler.gd`
- `autoload/event_bus.gd`
- `ui/inventory_screen.gd`

## Files Created
- `data/items/consumables/scrolls/scroll_spark.json`
- `data/items/consumables/scrolls/scroll_shield.json`
- `data/items/consumables/scrolls/scroll_fireball.json`
- `data/items/consumables/scrolls/scroll_flame_bolt.json`
- `data/items/consumables/scrolls/scroll_lightning_bolt.json`

## Next Phase
Once scrolls work, proceed to **Phase 10: Scroll Inscription**
