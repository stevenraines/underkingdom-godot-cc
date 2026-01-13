# Phase 13: Identification System

## Overview
Implement the classic roguelike identification system where scrolls, wands, and potions appear with randomized descriptions until identified.

## Dependencies
- Phase 9: Scrolls
- Phase 11: Wands & Staves

## Implementation Steps

### 13.1 Create Identification Manager
**File:** `autoload/identification_manager.gd` (new)

```gdscript
class_name IdentificationManager
extends Node

# Maps true_id -> appearance for this playthrough
var scroll_appearances: Dictionary = {}  # "scroll_spark" -> "ZELGO MOR"
var wand_appearances: Dictionary = {}    # "wand_of_sparks" -> "oak"
var potion_appearances: Dictionary = {}  # "mana_potion" -> "murky blue"

# Set of identified item IDs for this playthrough
var identified_items: Array[String] = []

const SCROLL_SYLLABLES = ["ZELGO", "MOR", "XYZZY", "FOOBAR", "KLAATU", "BARADA", "NIKTO", "LOREM", "IPSUM", "DOLOR", "AMET", "VERITAS", "ARCANA", "MYSTIS", "UMBRA"]
const WAND_MATERIALS = ["oak", "bone", "crystal", "iron", "silver", "obsidian", "willow", "ash", "copper", "jade"]
const POTION_COLORS = ["murky blue", "bubbling red", "glowing green", "swirling purple", "shimmering gold", "dark black", "clear", "fizzing orange", "luminous white", "oily brown"]

func _ready() -> void:
    # Generate appearances on new game
    EventBus.game_started.connect(_on_game_started)

func _on_game_started():
    _generate_random_appearances()

func _generate_random_appearances() -> void:
    # Shuffle and assign appearances to items
    var syllables = SCROLL_SYLLABLES.duplicate()
    syllables.shuffle()

    var materials = WAND_MATERIALS.duplicate()
    materials.shuffle()

    var colors = POTION_COLORS.duplicate()
    colors.shuffle()

    # Assign to each unidentified item type
    # This needs to iterate through all items that can be unidentified
    for item_id in ItemManager.get_all_item_ids():
        var item_data = ItemManager.get_item_data(item_id)
        if item_data.get("unidentified", false):
            match item_data.subtype:
                "scroll":
                    var idx = scroll_appearances.size() % syllables.size()
                    scroll_appearances[item_id] = syllables[idx] + " " + syllables[(idx + 1) % syllables.size()]
                "wand":
                    var idx = wand_appearances.size() % materials.size()
                    wand_appearances[item_id] = materials[idx]
                "potion":
                    var idx = potion_appearances.size() % colors.size()
                    potion_appearances[item_id] = colors[idx]

func is_identified(item_id: String) -> bool:
    return item_id in identified_items

func identify_item(item_id: String) -> void:
    if not is_identified(item_id):
        identified_items.append(item_id)
        EventBus.item_identified.emit(item_id)

func get_display_name(item: Item) -> String:
    if is_identified(item.id) or not item.get("unidentified", false):
        return item.name

    match item.subtype:
        "scroll":
            return "Scroll labeled %s" % scroll_appearances.get(item.id, "???")
        "wand":
            return "%s wand" % wand_appearances.get(item.id, "strange").capitalize()
        "potion":
            return "%s potion" % potion_appearances.get(item.id, "unknown").capitalize()

    return item.name
```

### 13.2 Add Unidentified Flag to Items
**File:** `items/item.gd`

```gdscript
var unidentified: bool = false
var true_name: String = ""  # Actual name once identified

func get_display_name() -> String:
    return IdentificationManager.get_display_name(self)
```

### 13.3 Update Item JSON Files
Add `"unidentified": true` to scrolls, wands, and potions:

**Example scroll_spark.json update:**
```json
{
  "id": "scroll_spark",
  "name": "Scroll of Spark",
  "unidentified": true,
  ...
}
```

### 13.4 Implement Identify on Use
**File:** `items/item.gd`

```gdscript
func use(user: Entity) -> Dictionary:
    var result = # ... existing use logic ...

    # Identify item on use
    if unidentified and result.success:
        IdentificationManager.identify_item(id)
        result.message += " (It was a %s!)" % name

    return result
```

### 13.5 Create Identify Spell
**File:** `data/spells/divination/identify.json`

```json
{
  "id": "identify",
  "name": "Identify",
  "description": "Reveal the true nature of a magical item.",
  "school": "divination",
  "level": 3,
  "mana_cost": 12,
  "requirements": {"character_level": 3, "intelligence": 10},
  "targeting": {"mode": "inventory"},
  "effects": {
    "identify": true
  },
  "cast_message": "The item's true nature is revealed!"
}
```

### 13.6 Implement Identify Spell Effect
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_inventory_spell(caster: Entity, spell: Spell, target_item: Item, result: Dictionary) -> Dictionary:
    if "identify" in spell.effects:
        if not target_item.unidentified:
            result.success = false
            result.message = "That item is already identified."
            # Don't consume mana for failed identify
            caster.survival.mana += spell.mana_cost
            return result

        IdentificationManager.identify_item(target_item.id)
        result.message = "The %s is revealed!" % target_item.name
        result.success = true

    return result
```

### 13.7 Create Scroll of Identify
**File:** `data/items/consumables/scrolls/scroll_identify.json`

```json
{
  "id": "scroll_identify",
  "name": "Scroll of Identify",
  "unidentified": true,
  "casts_spell": "identify",
  ...
}
```

### 13.8 High INT Auto-Identification
**File:** `autoload/identification_manager.gd`

```gdscript
func check_auto_identify(item: Item, user: Entity) -> bool:
    if is_identified(item.id):
        return true

    # INT 14+ auto-identifies level 1-2 spells
    var user_int = user.get_effective_attribute("INT")
    var spell = SpellManager.get_spell(item.casts_spell) if item.casts_spell else null

    if spell and user_int >= 14 and spell.level <= 2:
        identify_item(item.id)
        EventBus.message_logged.emit("Your keen intellect reveals this to be a %s." % item.name, Color.CYAN)
        return true

    return false
```

### 13.9 Add Identification to Save/Load
**File:** `autoload/save_manager.gd`

Save and restore:
- `scroll_appearances`
- `wand_appearances`
- `potion_appearances`
- `identified_items`

### 13.10 Update UI to Use Display Names
**File:** `ui/inventory_screen.gd`

Use `item.get_display_name()` instead of `item.name` everywhere.

### 13.11 Add Mage NPC Identification Service
To be implemented in Phase 19 (Town Mage):
- Pay 10-50 gold to identify an item
- Price based on item rarity

### 13.12 Add EventBus Signal
**File:** `autoload/event_bus.gd`

```gdscript
signal item_identified(item_id: String)
```

## Testing Checklist

- [ ] New game generates random scroll/wand/potion appearances
- [ ] Scroll shows "Scroll labeled ZELGO MOR" when unidentified
- [ ] Wand shows "Oak wand" when unidentified
- [ ] Potion shows "Murky blue potion" when unidentified
- [ ] Same appearance = same item throughout playthrough
- [ ] Using item identifies it
- [ ] "It was a Scroll of Spark!" message on identify
- [ ] Identify spell reveals item's true nature
- [ ] Scroll of Identify works
- [ ] High INT (14+) auto-identifies low-level items
- [ ] Identified items show true name
- [ ] Identification persists through save/load
- [ ] Appearances persist through save/load (same playthrough)
- [ ] New playthrough generates different appearances

## Files Modified
- `items/item.gd`
- `systems/magic_system.gd`
- `autoload/save_manager.gd`
- `autoload/event_bus.gd`
- `ui/inventory_screen.gd`
- Various item JSON files (add unidentified flag)

## Files Created
- `autoload/identification_manager.gd`
- `data/spells/divination/identify.json`
- `data/items/consumables/scrolls/scroll_identify.json`

## Next Phase
Once identification works, proceed to **Phase 14: DoT & Concentration**
