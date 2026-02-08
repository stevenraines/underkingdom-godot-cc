# Feature - Cursed Items System
**Goal**: Hide curse status until items are used/identified, prevent unequipping without Remove Curse spell

---

## Overview

Cursed items add risk and excitement to looting. When a player finds a cursed item, it appears normal (or even beneficial) until equipped or identified. Once a cursed item is equipped, it cannot be removed until the curse is lifted via the Remove Curse spell or a priest's service.

This feature builds on the existing identification system and adds:
1. Hidden curse status (revealed on equip/use or via Identify spell)
2. Binding mechanic preventing unequip of cursed items
3. Multiple curse types with different negative effects
4. Remove Curse spell implementation (targeting specific items)
5. Priest NPC services for curse removal and spell teaching

---

## Core Mechanics

### Curse Discovery

**Before Discovery:**
- Item shows `name` instead of `true_name` (if defined)
- Item shows `fake_passive_effects` instead of real `passive_effects`
- `curse_revealed` flag is `false`
- Curse is completely hidden from player

**Revelation Triggers:**
1. **Equipping the item** - Curse is revealed when item is equipped
2. **Using the item** - Curse is revealed on use (for consumables/usables)
3. **Identify spell** - Divination spell reveals curse without equipping

**After Discovery:**
- `curse_revealed` flag becomes `true`
- Item shows `true_name` and `true_description`
- Real `passive_effects` are displayed
- If equipped, binding curse prevents removal
- EventBus signal `curse_revealed` is emitted

### Curse Types

#### 1. Binding Curse
- **Effect**: Item cannot be unequipped once worn
- **Curse Type ID**: `"binding"`
- **Mechanic**: Inventory system blocks unequip action for cursed items
- **Example**: Ring of Weakness (appears as "Ring of Strength +2" before reveal)

#### 2. Stat Penalty Curse
- **Effect**: Reduces one or more stats (STR, DEX, INT, CON, WIS, CHA)
- **Curse Type ID**: `"stat_penalty"`
- **Fake Effects**: Shows positive stat bonuses before reveal
- **Real Effects**: Applies negative stat modifiers while equipped
- **Example**: Cursed Amulet shows +1 STR, actually applies -2 STR

#### 3. Draining Curse
- **Effect**: Drains health, mana, or stamina over time
- **Curse Type ID**: `"draining"`
- **Mechanic**: Each turn, applies drain effect (similar to DoT)
- **Data**: `curse_drain_type` ("health", "mana", "stamina"), `curse_drain_amount` (per turn)
- **Example**: Ring of Vampirism drains 2 HP per turn

#### 4. Unlucky Curse
- **Effect**: Reduces luck-based mechanics (accuracy, dodge, crit chance)
- **Curse Type ID**: `"unlucky"`
- **Mechanic**: Applies combat penalties, increased enemy encounter rate
- **Data**: `curse_accuracy_penalty`, `curse_dodge_penalty`, `curse_encounter_modifier`
- **Example**: Cursed Boots reduce dodge by 15%

### Remove Curse Implementation

**Spell Casting (Player):**
1. Player casts Remove Curse spell (Level 4 Abjuration, 20 mana cost)
2. Spell targeting mode: `"item"` - Player selects equipped item
3. Spell calls `Item.remove_curse()` on targeted item
4. Curse is lifted, item can now be unequipped
5. Item retains other properties (durability, enchantments if not curse-related)

**Priest Service:**
1. Player interacts with Priest NPC
2. Priest offers "Remove Curse" service if player has cursed equipped items
3. Service cost: 100 gold (configurable in NPC definition)
4. On payment, priest casts Remove Curse on selected item
5. Success message displayed

**Spell Teaching:**
- Priests offer Remove Curse spell training for 500 gold
- Requires: INT 11, Character Level 4 (spell prerequisites)
- Once learned, spell is added to player's known spells
- Player can cast it using mana (20 mana per cast)

---

## Data Structures

### Item JSON Properties (Existing + New)

```json
{
  "id": "cursed_ring_strength",
  "name": "Cursed Ring of Weakness",
  "true_name": "Ring of Weakness",
  "description": "A beautiful gold ring emanating faint magical energy.",
  "true_description": "This ring bears an ancient curse that saps the wearer's strength.",
  "category": "misc",
  "subtype": "ring",
  "equip_slots": ["accessory"],
  "flags": {"equippable": true, "cursed": true},
  "is_cursed": true,
  "curse_type": "stat_penalty",
  "curse_revealed": false,
  "value": 50,
  "weight": 0.1,
  "ascii_char": "=",
  "ascii_color": "#FFD700",

  "fake_passive_effects": {
    "stat_bonuses": {
      "STR": 2
    }
  },
  "passive_effects": {
    "stat_bonuses": {
      "STR": -2
    }
  }
}
```

### New Curse Type Properties

**Draining Curse:**
```json
{
  "curse_type": "draining",
  "curse_drain_type": "health",
  "curse_drain_amount": 2
}
```

**Unlucky Curse:**
```json
{
  "curse_type": "unlucky",
  "curse_accuracy_penalty": -15,
  "curse_dodge_penalty": -10,
  "curse_encounter_modifier": 1.25
}
```

### NPC JSON Extension (Priest)

```json
{
  "id": "priest",
  "name": "Father Aldric",
  "npc_type": "trainer",
  "spells_for_sale": [
    {"spell_id": "remove_curse", "base_price": 500}
  ],
  "services": [
    {
      "service_id": "remove_curse_service",
      "name": "Remove Curse",
      "description": "I can lift the curse from your equipment.",
      "base_price": 100,
      "action": "remove_curse"
    }
  ]
}
```

---

## Implementation Plan

### Phase 1: Curse Reveal System
1. Modify `Inventory.equip_item()` to trigger curse reveal
   - Check `item.is_cursed` and `!item.curse_revealed`
   - Call `item.reveal_curse()`
   - Display curse reveal message to player
2. Modify `ItemUsageHandler.use()` to reveal curse on use
   - Add curse check for usable cursed items
3. Update Identify spell handler to reveal curses
   - Modify `magic/spell_effects/divination_effects.gd`
   - Add curse reveal to identify effect

### Phase 2: Binding Mechanic
1. Add `can_unequip_item()` check in `Inventory` class
   - Returns `false` if item has binding curse and curse is revealed
   - Returns reason string for UI display
2. Modify `Inventory.unequip_slot()` to check binding
   - Call `can_unequip_item()` before unequipping
   - Display error message if blocked
3. Update equipment UI to show curse status
   - Display "CURSED (bound)" indicator on cursed equipped items
   - Disable unequip action for bound items

### Phase 3: Curse Effects
1. Create `CurseEffects` autoload manager (or extend existing effects system)
   - Handle draining curse per-turn damage
   - Handle unlucky curse combat modifiers
2. Modify stat calculation to apply curse penalties
   - Update `Player.get_stat_with_bonuses()` to check cursed equipment
   - Apply negative modifiers from `passive_effects`
3. Add turn-based draining logic
   - Hook into turn system for draining curse tick
   - Emit damage events for drain effects

### Phase 4: Remove Curse Spell
1. Update Remove Curse spell JSON targeting mode
   - Change `targeting.mode` from `"self"` to `"equipped_item"`
   - Add targeting filter for cursed items only
2. Create spell effect handler for Remove Curse
   - Implement item selection UI for equipped cursed items
   - Call `Item.remove_curse()` on selected item
   - Display success/failure messages
3. Test spell functionality
   - Verify curse removal works
   - Verify item can be unequipped after curse removal

### Phase 5: Priest Services
1. Extend NPC data structure for services
   - Add `services` array to NPC JSON schema
   - Add `spells_for_sale` array to NPC JSON schema
2. Modify `NPC` class to support spell teaching
   - Add `spells_for_sale` property (similar to `recipes_for_sale`)
   - Add `get_spell_for_sale()`, `remove_spell_for_sale()` methods
3. Create service handler system
   - Add `NPCServiceHandler` class or extend NPC interaction
   - Implement `remove_curse_service` action
4. Update Priest NPC definition
   - Add Remove Curse spell to `spells_for_sale`
   - Add Remove Curse service to `services`
5. Create spell learning UI
   - Extend training screen to show spells
   - Display spell details, cost, requirements
   - Handle spell purchase and learning
6. Update NPC menu screen
   - Add "Services" option if NPC has services
   - Add "Learn Spells" option if NPC has spells_for_sale

### Phase 6: Cursed Item Generation
1. Create cursed item data files
   - `data/items/cursed/cursed_ring_weakness.json`
   - `data/items/cursed/cursed_amulet_draining.json`
   - `data/items/cursed/cursed_boots_unlucky.json`
   - Add 5-10 cursed items across different slots
2. Add cursed items to loot tables
   - Low probability in dungeon chests (5-10%)
   - Boss loot may have higher chance
   - Never appear in shop inventories
3. Update VariantManager (optional)
   - Create "cursed" variant type for dynamic generation
   - Allows any item to become cursed with random curse type

---

## New Files Required

### Code Files
```
magic/spell_effects/remove_curse_effect.gd  # Spell effect handler for Remove Curse
systems/curse_effects_system.gd             # Handles draining and unlucky curse mechanics (or extend existing effects system)
ui/spell_learning_screen.gd                 # UI for learning spells from NPCs (extends or mirrors recipe training)
ui/item_targeting_overlay.gd                # UI for selecting equipped items (for Remove Curse targeting)
```

### Data Files
```
data/items/cursed/
├── cursed_ring_weakness.json
├── cursed_ring_draining.json
├── cursed_amulet_unlucky.json
├── cursed_boots_binding.json
├── cursed_gloves_penalty.json
└── cursed_necklace_vampiric.json
```

### Modified Files
- `items/item.gd` - Add draining/unlucky curse properties, update reveal_curse()
- `systems/inventory_system.gd` - Add binding checks to equip/unequip
- `entities/npc.gd` - Add spells_for_sale and services support
- `autoload/npc_manager.gd` - Load services and spells from NPC JSON
- `data/npcs/priest.json` - Add Remove Curse service and spell training
- `data/spells/abjuration/remove_curse.json` - Update targeting mode
- `items/item_usage_handler.gd` - Add curse reveal on item use
- `magic/spell_effects/divination_effects.gd` - Add curse reveal to Identify
- `ui/equipment_screen.gd` - Display curse status, disable unequip for cursed
- `ui/npc_menu_screen.gd` - Add services and spell learning options
- `autoload/event_bus.gd` - Add signals (curse_revealed, curse_removed already exist)
- `entities/player.gd` - Hook curse effects into stat calculations and turn processing

---

## Input Bindings

No new input bindings required. Uses existing interaction keys:
- `i` - Open inventory/equipment (to see curse status)
- `c` - Cast spell (for Remove Curse)
- `Enter` - Select item when targeting

---

## UI Messages

**Curse Revelation:**
- "The {item_name} reveals its true nature - it is cursed!" (on equip)
- "You sense a dark aura emanating from the {item_name}..." (on Identify)
- "The curse prevents you from removing the {item_name}!" (on blocked unequip)

**Remove Curse:**
- "Select a cursed item to remove the curse from:" (targeting prompt)
- "The curse dissipates!" (success message from spell JSON)
- "The {item_name} is no longer cursed. You can now remove it." (post-removal)

**Priest Services:**
- "Father Aldric offers to remove the curse for 100 gold. Accept?" (service prompt)
- "The priest chants a prayer, and the curse is lifted!" (service success)
- "I can teach you the sacred art of removing curses for 500 gold." (teaching offer)
- "You have learned the Remove Curse spell!" (learning success)

**Curse Effects:**
- "The {item_name} drains your life force! (-{amount} HP)" (draining curse)
- "You feel weaker while wearing the {item_name}." (stat penalty reveal)
- "The curse brings misfortune upon you..." (unlucky curse)

---

## Testing Checklist

### Curse Discovery
- [ ] Equipping a cursed item reveals the curse
- [ ] Using a cursed consumable reveals the curse
- [ ] Identify spell reveals curse without equipping
- [ ] Curse reveal shows true_name and true_description
- [ ] Curse reveal emits EventBus signal
- [ ] Unidentified cursed items show fake effects before reveal

### Binding Mechanic
- [ ] Cannot unequip cursed item after curse is revealed
- [ ] Unequip attempt shows appropriate error message
- [ ] Equipment UI shows "CURSED" indicator
- [ ] Unequip button is disabled for cursed items
- [ ] Non-cursed items can still be unequipped normally

### Curse Effects
- [ ] Stat penalty curses reduce stats while equipped
- [ ] Draining curse deals damage each turn
- [ ] Unlucky curse applies combat penalties
- [ ] Curse effects stop when curse is removed
- [ ] Multiple curse types can coexist on different items

### Remove Curse Spell
- [ ] Spell targets only equipped cursed items
- [ ] Spell removes curse from selected item
- [ ] Item can be unequipped after curse removal
- [ ] Spell consumes mana correctly
- [ ] Spell fails if player lacks requirements

### Priest Services
- [ ] Priest offers Remove Curse service if player has cursed items
- [ ] Service costs 100 gold
- [ ] Service successfully removes curse
- [ ] Priest offers to teach Remove Curse spell
- [ ] Spell teaching costs 500 gold
- [ ] Spell learning checks prerequisites (INT 11, Level 4)
- [ ] Learned spell appears in player's spell list

### Item Generation
- [ ] Cursed items appear in dungeon loot
- [ ] Cursed items never appear in shops
- [ ] Cursed items have appropriate rarity
- [ ] All curse types are represented in loot pool

### Save/Load
- [ ] Cursed items save curse_revealed state
- [ ] Equipped cursed items remain equipped after load
- [ ] Binding curse persists across save/load
- [ ] Curse effects continue after loading save

---

## Future Enhancements

1. **Curse Transformation** - Some curses transform items over time (e.g., sword becomes rusty)
2. **Spreading Curses** - Cursed items can spread to other equipment slots
3. **Beneficial Curses** - Powerful items with binding curse but strong bonuses (risk/reward)
4. **Curse Resistance** - Certain classes/races have resistance to curses
5. **Curse Crafting** - Allow players to apply curses to items (necromancy)
6. **Greater Remove Curse** - Higher level spell that removes all curses at once
7. **Curse Transferal** - Move curse from one item to another
8. **Cursed Item Quests** - NPCs ask player to retrieve specific cursed items

---

**Last Updated**: February 8, 2026
**Status**: Planning Phase
**Estimated Complexity**: Medium-High (touches multiple systems)
