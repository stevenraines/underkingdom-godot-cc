# Phase 18: Town Mage NPC

## Overview
Implement Eldric the Mage NPC in the starting town who sells spellbooks, teaches spells, and offers identification services.

## Dependencies
- Phase 3: Spellbook & Learning
- Phase 13: Identification System
- Phase 1.14: Town & Shop (existing NPC/shop system)

## Implementation Steps

### 18.1 Create Mage NPC Data
**File:** `data/npcs/town/eldric_mage.json`

```json
{
  "id": "eldric_mage",
  "name": "Eldric",
  "title": "Town Mage",
  "description": "An elderly mage who sells magical supplies and offers services.",
  "ascii_char": "@",
  "ascii_color": "#9966FF",
  "dialogue": {
    "greeting": "Ah, a seeker of arcane knowledge! How may I assist you?",
    "farewell": "May your spells fly true.",
    "no_gold": "Alas, you lack the coin for that.",
    "insufficient_int": "Your mind is not yet ready for such magic."
  },
  "services": ["shop", "teach_spell", "identify"],
  "shop_inventory": [
    {"item_id": "spellbook", "stock": 1, "restock_turns": 5000},
    {"item_id": "scroll_spark", "stock": 3, "restock_turns": 1000},
    {"item_id": "scroll_light", "stock": 2, "restock_turns": 1000},
    {"item_id": "scroll_heal", "stock": 2, "restock_turns": 1500},
    {"item_id": "scroll_shield", "stock": 1, "restock_turns": 2000},
    {"item_id": "wand_spark", "stock": 1, "restock_turns": 5000},
    {"item_id": "mana_potion_minor", "stock": 3, "restock_turns": 500},
    {"item_id": "mana_potion", "stock": 1, "restock_turns": 1000}
  ],
  "teachable_spells": [
    {"spell_id": "spark", "price": 50, "min_int": 8},
    {"spell_id": "light", "price": 30, "min_int": 8},
    {"spell_id": "detect_magic", "price": 40, "min_int": 9},
    {"spell_id": "heal", "price": 100, "min_int": 10},
    {"spell_id": "flame_bolt", "price": 150, "min_int": 11},
    {"spell_id": "shield", "price": 120, "min_int": 10}
  ],
  "identify_price": 25,
  "spawn_location": "town_magic_shop"
}
```

### 18.2 Extend NPC Class for Mage Services
**File:** `entities/npc.gd`

```gdscript
# Add to existing NPC class
var services: Array[String] = []
var teachable_spells: Array = []
var identify_price: int = 25

func can_teach_spell(spell_id: String, player: Entity) -> Dictionary:
    for teachable in teachable_spells:
        if teachable.spell_id == spell_id:
            # Check if player already knows
            if spell_id in player.known_spells:
                return {can_teach = false, reason = "You already know this spell."}

            # Check INT requirement
            if player.get_effective_attribute("INT") < teachable.min_int:
                return {can_teach = false, reason = "Insufficient Intelligence."}

            # Check gold
            if player.gold < teachable.price:
                return {can_teach = false, reason = "Not enough gold."}

            # Check if player has spellbook
            if not player.has_spellbook():
                return {can_teach = false, reason = "You need a spellbook to learn spells."}

            return {can_teach = true, price = teachable.price}

    return {can_teach = false, reason = "I cannot teach that spell."}

func teach_spell(spell_id: String, player: Entity) -> bool:
    var check = can_teach_spell(spell_id, player)
    if not check.can_teach:
        return false

    player.gold -= check.price
    player.learn_spell(spell_id)
    EventBus.spell_learned.emit(player, spell_id)
    EventBus.message_logged.emit("You learn %s!" % SpellManager.get_spell(spell_id).name, Color.CYAN)
    return true

func get_identify_price() -> int:
    return identify_price

func identify_item(item: Item, player: Entity) -> bool:
    if player.gold < identify_price:
        EventBus.message_logged.emit(dialogue.no_gold, Color.YELLOW)
        return false

    player.gold -= identify_price
    IdentificationManager.identify_item(item)
    EventBus.message_logged.emit("The %s is identified!" % item.display_name, Color.CYAN)
    return true
```

### 18.3 Create Mage Services UI
**IMPORTANT:** Use the `ui-implementation` agent for creating this UI.

**File:** `ui/mage_services_menu.gd` (new)

The menu should have three tabs/options:
1. **Shop** - Standard buy/sell interface for scrolls, wands, potions
2. **Learn Spells** - List teachable spells with prices and requirements
3. **Identify** - Select unidentified items to identify for gold

### 18.4 Add Spell Teaching Dialog
**File:** `ui/spell_teaching_dialog.gd` (new)

Display:
- Spell name and school
- Mana cost and level
- Brief description
- Price in gold
- INT requirement (highlight if not met)
- "Learn" button (disabled if requirements not met)

### 18.5 Spawn Mage in Town
**File:** `generation/town_generator.gd`

```gdscript
func _spawn_town_npcs(map: Map) -> void:
    # ... existing merchant spawning ...

    # Spawn mage at magic shop location
    var mage_pos = _get_building_interior_position("magic_shop")
    if mage_pos:
        var mage = EntityManager.spawn_npc("eldric_mage", mage_pos)
        map.entities.append(mage)
```

### 18.6 Add Magic Shop Building to Town
**File:** `generation/town_generator.gd`

```gdscript
const TOWN_BUILDINGS = [
    {"type": "general_store", "size": Vector2i(6, 5)},
    {"type": "magic_shop", "size": Vector2i(5, 5)},  # Add this
    {"type": "inn", "size": Vector2i(7, 6)}
]

func _generate_magic_shop(pos: Vector2i, size: Vector2i) -> void:
    # Generate shop interior
    # Add arcane decorations (pentagram floor, bookshelves)
    # Mark spawn point for mage NPC
```

### 18.7 Handle Mage Interaction
**File:** `systems/input_handler.gd`

```gdscript
func _handle_npc_interaction(npc: NPC) -> void:
    if "teach_spell" in npc.services or "identify" in npc.services:
        # Open mage services menu
        EventBus.mage_services_requested.emit(npc)
    elif "shop" in npc.services:
        # Standard shop
        EventBus.shop_requested.emit(npc)
```

### 18.8 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal mage_services_requested(npc: NPC)
signal spell_teaching_requested(npc: NPC, spell_id: String)
signal identification_requested(npc: NPC, item: Item)
```

### 18.9 Add Mage-Specific Dialogue
**File:** `data/npcs/town/eldric_mage.json`

Extended dialogue for different situations:
```json
{
  "dialogue": {
    "greeting": "Ah, a seeker of arcane knowledge! How may I assist you?",
    "farewell": "May your spells fly true.",
    "no_gold": "Alas, you lack the coin for that.",
    "insufficient_int": "Your mind is not yet ready for such magic.",
    "already_known": "You already possess knowledge of that spell.",
    "no_spellbook": "You need a spellbook to record spells. I sell them, you know.",
    "spell_taught": "The arcane knowledge flows into your mind. Use it wisely.",
    "item_identified": "Ah yes, I see now what this truly is...",
    "nothing_to_identify": "I sense no mystery in your possessions."
  }
}
```

## Testing Checklist

- [ ] Eldric spawns in magic shop in town
- [ ] Can interact with Eldric to open services menu
- [ ] Shop tab shows scrolls, wands, potions for sale
- [ ] Learn Spells tab shows available spells with prices
- [ ] Cannot learn spell without spellbook
- [ ] Cannot learn spell without sufficient INT
- [ ] Cannot learn spell without enough gold
- [ ] Learning spell deducts gold and adds to known_spells
- [ ] Identify tab shows unidentified items
- [ ] Identifying item deducts gold and reveals true name
- [ ] Eldric restocks items over time
- [ ] Dialogue changes based on situation

## Documentation Updates

- [ ] CLAUDE.md updated with mage NPC info
- [ ] Help screen updated with mage services info
- [ ] `docs/systems/npc-system.md` updated with mage services
- [ ] `docs/data/npcs.md` updated with mage NPC format

## Files Modified
- `entities/npc.gd`
- `generation/town_generator.gd`
- `systems/input_handler.gd`
- `autoload/event_bus.gd`

## Files Created
- `data/npcs/town/eldric_mage.json`
- `ui/mage_services_menu.gd`
- `ui/mage_services_menu.tscn`
- `ui/spell_teaching_dialog.gd`
- `ui/spell_teaching_dialog.tscn`

## Next Phase
Once the town mage works, proceed to **Phase 19: Enemy Spellcasters**
