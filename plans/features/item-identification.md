# Feature - Item Identification System

**Goal**: Hide magic item properties until revealed through use or identification spells.

---

## Overview

This feature extends the existing `IdentificationManager` system (currently used for scrolls, wands, and potions) to cover all magic items including rings, amulets, enchanted weapons, and enchanted armor. When a player finds or purchases a magic item, it will appear with a randomized appearance description until identified. For example, a "Ring of Power" might appear as "silver ring" or "ornate ring" and won't show its stat bonuses until the player equips it, uses it in combat, casts Identify on it, or has high enough INT to auto-identify it.

This creates classic roguelike gameplay where players must decide whether to risk equipping an unknown item or spend resources to identify it safely. Cursed items integrate seamlessly - they appear as regular unidentified items and reveal their curse when equipped or used.

The system follows the per-item-type identification pattern: once you've identified one "Ring of Power", all future Rings of Power are automatically recognized.

---

## Core Mechanics

### Unidentified Item Display

When an unidentified magic item appears in the game:

1. **Randomized Appearance**: Each magic item type gets a random appearance descriptor from predefined pools
   - **Rings**: "silver ring", "gold ring", "ornate ring", "bronze ring", "jade ring", "ruby ring"
   - **Amulets**: "silver amulet", "bone amulet", "crystal pendant", "leather necklace", "copper amulet"
   - **Enchanted Weapons**: "fine [weapon]", "ornate [weapon]", "gleaming [weapon]", "engraved [weapon]"
   - **Enchanted Armor**: "fine [armor]", "ornate [armor]", "gleaming [armor]", "masterwork [armor]"

2. **Appearance Assignment**: On game start, `IdentificationManager` assigns random appearances to all magic items from the item database
   - Uses the same shuffle-and-assign pattern as existing scroll/wand/potion system
   - Appearances persist throughout the playthrough
   - Saved/loaded with game state

3. **Display Name**: `Item.get_display_name()` returns the appearance name instead of the true name
   - Example: "Silver ring" instead of "Ring of Power"
   - Works in inventory, tooltips, messages, shops, loot

4. **Hidden Properties**: Stats, passive effects, and enchantments are not shown in tooltips
   - Tooltip shows basic item properties (weight, value, equipment slot)
   - Does NOT show: stat bonuses, damage bonuses, armor bonuses, passive effects

### Identification Triggers

An item becomes identified when ANY of the following occurs:

1. **Equipping the Item**:
   - When player equips an unidentified item, it is immediately identified
   - Passive effects apply and the true name is revealed
   - Message: "You equip the silver ring. It is a Ring of Power! (+1 STR)"

2. **Using in Combat** (additional reveal for weapons/armor):
   - **Weapons**: First successful hit with weapon reveals enchantments
   - **Armor**: First time taking damage while wearing armor reveals enchantments
   - This is a secondary reveal - equipping already identifies it
   - Useful for showing combat-specific effects player might have missed

3. **Identify Spell/Scroll**:
   - Casting "Identify" spell or using "Scroll of Identify"
   - Opens item selection dialog (existing `spell_item_selection_dialog.tscn`)
   - Selected item is identified without needing to equip
   - Message: "The silver ring is revealed to be a Ring of Power!"

4. **High INT Auto-Identify**:
   - If player has INT 16+, automatically identifies magic items on pickup
   - Message: "Your keen intellect reveals this to be a Ring of Power."
   - Similar to existing INT 14+ scroll/wand auto-identify mechanic

### Cursed Item Integration

Cursed items work identically to magic items:

1. **Same Appearance System**: Cursed ring appears as "silver ring" just like a normal magic ring
2. **Equip Reveals Curse**: When equipped, curse is revealed along with true name
   - If `curse_revealed = false`, equipping sets `curse_revealed = true`
   - Message: "You equip the silver ring. It is a Vampiric Ring! The ring clings to your finger - you cannot remove it."
3. **Identify Spell Works**: Can safely identify cursed items without equipping them
   - Reveals both the true name and the curse
   - Message: "The silver ring is revealed to be a Vampiric Ring (cursed - drains 2 HP/turn)."

### Item Data Marking

To mark an item as requiring identification, add `"unidentified": true` to its JSON data:

```json
{
  "id": "ring_of_power",
  "name": "Ring of Power",
  "unidentified": true,
  "subtype": "ring",
  "passive_effects": {
    "stat_bonuses": {
      "STR": 1
    }
  }
}
```

The `IdentificationManager` will automatically assign it a random appearance.

---

## Data Structures

### Extended IdentificationManager

```gdscript
# New appearance pools (added to existing scroll/wand/potion pools)
const RING_APPEARANCES = [
    "silver", "gold", "ornate", "bronze", "jade", "ruby",
    "platinum", "iron", "copper", "bone", "crystal"
]

const AMULET_APPEARANCES = [
    "silver", "bone", "crystal", "leather", "copper",
    "jade", "obsidian", "wooden", "ivory", "golden"
]

const WEAPON_PREFIXES = [
    "fine", "ornate", "gleaming", "engraved", "masterwork",
    "polished", "decorated", "well-crafted"
]

const ARMOR_PREFIXES = [
    "fine", "ornate", "gleaming", "masterwork", "polished",
    "decorated", "well-made", "reinforced"
]

# New appearance mappings (added to existing)
var ring_appearances: Dictionary = {}      # "ring_of_power" -> "silver"
var amulet_appearances: Dictionary = {}    # "amulet_of_fortune" -> "bone"
var weapon_appearances: Dictionary = {}    # "sword_of_flame" -> "fine"
var armor_appearances: Dictionary = {}     # "boots_of_speed" -> "ornate"
```

### Item.gd (Already Exists)

The `Item` class already has all necessary properties:
- `unidentified: bool` - Marks item as needing identification
- `true_name: String` - Real name (currently used for cursed items)
- `true_description: String` - Real description (currently used for cursed items)

We'll reuse these for all magic items, not just cursed ones.

---

## Implementation Plan

### Phase 1: Extend IdentificationManager

1. **Add New Appearance Pools**
   - Add `RING_APPEARANCES`, `AMULET_APPEARANCES`, `WEAPON_PREFIXES`, `ARMOR_PREFIXES` constants
   - Add `ring_appearances`, `amulet_appearances`, `weapon_appearances`, `armor_appearances` dictionaries

2. **Update `_generate_random_appearances()`**
   - Extend existing function to handle new item types
   - Check item subtype: "ring", "amulet", or check category: "weapon", "armor"
   - Assign appearances from appropriate pools
   - For weapons/armor: combine prefix with base item type (e.g., "fine sword")

3. **Update `get_display_name()`**
   - Add cases for "ring", "amulet" subtypes
   - For weapons: return prefix + base weapon name (e.g., "fine sword")
   - For armor: return prefix + base armor name (e.g., "ornate boots")

4. **Update Serialization**
   - Add new appearance dictionaries to `serialize()` return
   - Add new dictionaries to `deserialize()` loading
   - Update `reset()` to clear new dictionaries

### Phase 2: Update Item Display Logic

1. **Item.get_tooltip() Modifications**
   - Check `if unidentified and not is_identified()` at start
   - Hide passive effects, stat bonuses, enchantment info
   - Show only basic properties: type, weight, value, equipment slot
   - Show full details after identification

2. **Item.get_display_name() Verification**
   - Already calls `IdentificationManager.get_display_name()`
   - Verify it works for new item types (should be automatic)

### Phase 3: Identification Triggers

1. **Equip Trigger**
   - Modify `InventorySystem.equip_item()`
   - Before applying passive effects, check if item is unidentified
   - If unidentified, call `IdentificationManager.identify_item(item.id)`
   - Show identification message with true name and effects
   - Emit `EventBus.item_identified` signal

2. **Combat Reveal Trigger**
   - **Weapons**: Modify `CombatSystem` - on successful hit, check if weapon is newly identified
     - If identified this turn (check signal?), show combat reveal message
   - **Armor**: Modify damage processing - when taking damage, check if worn armor is newly identified
     - If identified this turn, show armor reveal message
   - Note: This is cosmetic only - equipping already identified the item

3. **Identify Spell Integration**
   - `SpellCastingSystem.cast_identify()` already exists
   - Verify it calls `IdentificationManager.identify_item()`
   - Works with `spell_item_selection_dialog.tscn`

4. **High INT Auto-Identify**
   - Modify `InventorySystem.add_item()` or item pickup logic
   - Check player INT >= 16
   - If true, auto-identify unidentified items on pickup
   - Show "keen intellect" message

### Phase 4: Mark Magic Items as Unidentified

1. **Update Existing Magic Item JSON**
   - Add `"unidentified": true` to all magic rings in `data/items/accessories/`
   - Add `"unidentified": true` to all magic amulets
   - Add `"unidentified": true` to enchanted weapons (boots of speed, gloves of dexterity, etc.)
   - Add `"unidentified": true` to enchanted armor pieces

2. **Cursed Items Already Have unidentified**
   - Verify cursed items in `data/items/cursed/` already marked as unidentified
   - They already have `true_name` and `true_description` set

### Phase 5: Testing & Polish

1. **Test Appearance Assignment**
   - Start new game, verify appearances are randomized
   - Check appearances are consistent within same playthrough
   - Verify appearances are different in different playthroughs

2. **Test Identification Triggers**
   - Test equipping unidentified ring/amulet
   - Test Identify spell on unidentified item
   - Test INT 16+ auto-identify
   - Test cursed item reveal

3. **Test Save/Load**
   - Save game with some items identified, some not
   - Load game, verify identification state persists
   - Verify appearances persist

4. **UI Verification**
   - Check inventory tooltips hide magic properties
   - Check shop displays show appearance names
   - Check combat messages use appearance names until identified

---

## New Files Required

None - all changes are to existing files.

---

## Modified Files

### Autoload Files
- `autoload/identification_manager.gd` - Add new appearance pools and generation logic
  - Add ring/amulet/weapon/armor appearance constants
  - Extend `_generate_random_appearances()` to handle new item types
  - Extend `get_display_name()` for new item types
  - Update serialization to include new appearance dictionaries

### Item System Files
- `items/item.gd` - Update `get_tooltip()` to hide properties for unidentified items
  - Add check at start of `get_tooltip()`
  - Hide passive effects, stat bonuses if unidentified

### System Files
- `systems/inventory_system.gd` - Add identification on equip and INT auto-identify on pickup
  - Modify `equip_item()` to identify item before applying effects
  - Modify `add_item()` to check INT 16+ for auto-identify
  - Add identification messages

- `systems/combat_system.gd` - Add optional combat reveal messages (cosmetic)
  - Check if weapon was just identified during equip
  - Show special message on first hit with newly identified weapon

- `systems/spell_casting_system.gd` - Verify Identify spell integration
  - Ensure `cast_identify()` properly identifies selected item
  - No changes likely needed (already implemented)

### Data Files
- `data/items/accessories/*.json` - Add `"unidentified": true` to magic rings/amulets
  - `ring_of_power.json`
  - `ring_of_strength.json`
  - `ring_of_vitality.json`
  - `amulet_of_fortune.json`
  - `arcane_pendant.json`

- `data/items/armor/*.json` - Add `"unidentified": true` to enchanted armor
  - `boots_of_speed.json`
  - `gloves_of_dexterity.json`

- `data/items/cursed/*.json` - Verify `"unidentified": true` already present
  - All cursed items should already have this flag

---

## Input Bindings

No new input bindings required. Uses existing inventory and spell-casting controls.

---

## UI Messages

### Identification Messages

- **Equip Reveal**: "You equip the {appearance}. It is a {true_name}! {effects_summary}"
  - Example: "You equip the silver ring. It is a Ring of Power! (+1 STR)"

- **Cursed Equip Reveal**: "You equip the {appearance}. It is a {true_name}! {curse_warning}"
  - Example: "You equip the silver ring. It is a Vampiric Ring! The ring clings to your finger - you cannot remove it."

- **Identify Spell**: "The {appearance} is revealed to be a {true_name}!"
  - Example: "The silver ring is revealed to be a Ring of Power!"

- **Identify Cursed**: "The {appearance} is revealed to be a {true_name} (cursed - {curse_effect})."
  - Example: "The silver ring is revealed to be a Vampiric Ring (cursed - drains 2 HP/turn)."

- **INT Auto-Identify**: "Your keen intellect reveals this to be a {true_name}."
  - Example: "Your keen intellect reveals this to be a Ring of Power."

- **Combat Weapon Reveal**: "{weapon_name} glows with power as it strikes! {effects}"
  - Example: "The fine sword glows with power as it strikes! +2 fire damage"
  - Only shown if weapon was just identified this combat turn

- **Combat Armor Reveal**: "As the blow lands, you feel {armor_name} protecting you! {effects}"
  - Example: "As the blow lands, you feel the ornate boots protecting you! +5 speed"
  - Only shown if armor was just identified this combat turn

---

## Future Enhancements

1. **Merchants Know Their Inventory**
   - Shop items could be pre-identified when purchased from certain merchants
   - "Honest trader" NPCs sell identified items at higher prices
   - "Shady merchant" NPCs sell unidentified items at discounts

2. **Lore-Based Identification**
   - Finding item lore books could auto-identify specific item types
   - "Book of Ancient Rings" identifies all rings in your inventory

3. **Identification Skill/Class Feature**
   - Certain classes (Wizard, Scholar) could have better auto-identify thresholds
   - Lower INT requirement or identify more item types

4. **Partial Identification**
   - First use reveals one property, full reveal requires Identify spell
   - "You sense this ring enhances strength, but what else...?"

5. **Identify All Spell**
   - Higher-level spell that identifies all items in inventory at once
   - Expensive but convenient for batch identification

6. **Appraisal Skill**
   - Non-magical way to identify items through inspection
   - Takes time/turns but doesn't cost mana

---

## Testing Checklist

### Appearance Generation
- [ ] New game generates random appearances for all magic items
- [ ] Appearances are consistent within a playthrough
- [ ] Different playthroughs have different random appearances
- [ ] Ring appearances use ring pool correctly
- [ ] Amulet appearances use amulet pool correctly
- [ ] Weapon appearances use weapon prefix pool correctly
- [ ] Armor appearances use armor prefix pool correctly

### Display Names
- [ ] Unidentified rings show appearance name (e.g., "silver ring")
- [ ] Unidentified amulets show appearance name (e.g., "bone amulet")
- [ ] Unidentified weapons show prefix + type (e.g., "fine sword")
- [ ] Unidentified armor shows prefix + type (e.g., "ornate boots")
- [ ] Identified items show true name
- [ ] Shop displays show appearance names for unidentified items
- [ ] Ground items show appearance names for unidentified items

### Tooltips
- [ ] Unidentified item tooltips hide passive effects
- [ ] Unidentified item tooltips hide stat bonuses
- [ ] Unidentified item tooltips hide enchantments
- [ ] Unidentified item tooltips show basic info (weight, value, slot)
- [ ] Identified item tooltips show full information

### Identification Triggers
- [ ] Equipping unidentified ring identifies it and shows message
- [ ] Equipping unidentified amulet identifies it and shows message
- [ ] Equipping unidentified weapon identifies it and shows message
- [ ] Equipping unidentified armor identifies it and shows message
- [ ] Equipping cursed item reveals curse and shows warning
- [ ] Identify spell opens item selection dialog
- [ ] Identify spell identifies selected item and shows message
- [ ] Identify spell on cursed item reveals curse safely
- [ ] INT 16+ auto-identifies items on pickup
- [ ] Auto-identify shows "keen intellect" message

### Per-Type Identification
- [ ] Identifying one Ring of Power identifies all Rings of Power
- [ ] Finding second unidentified ring of same type shows true name
- [ ] Different ring types remain separate (identifying Ring of Power doesn't identify Ring of Strength)

### Cursed Item Integration
- [ ] Cursed items appear with random appearance like normal magic items
- [ ] Equipping cursed item reveals true name and curse
- [ ] Cannot distinguish cursed from normal magic items when unidentified
- [ ] Identify spell reveals curse without equipping
- [ ] Cursed item fake effects shown before identification (if applicable)

### Save/Load
- [ ] Save game preserves identification state
- [ ] Load game restores which items are identified
- [ ] Load game restores appearance assignments
- [ ] Unidentified items in saved inventory remain unidentified
- [ ] Identified items in saved inventory remain identified

### Combat Messages
- [ ] First hit with newly identified weapon shows reveal message (optional)
- [ ] Taking damage with newly identified armor shows reveal message (optional)
- [ ] Messages only show for items identified this turn

### Edge Cases
- [ ] Non-magic items are never marked unidentified
- [ ] Items without `unidentified: true` flag always show true name
- [ ] Stackable items (potions) work with identification system
- [ ] Inscribed items show inscription with appearance name
- [ ] Dropping and picking up identified item keeps it identified
- [ ] Trading identified item to merchant and buying back keeps it identified

---

**Implementation Notes**:
- Reuse existing `Item.unidentified`, `Item.true_name`, `Item.true_description` properties
- Follow existing `IdentificationManager` patterns for scrolls/wands/potions
- Use existing `spell_item_selection_dialog.tscn` for Identify spell targeting
- Emit `EventBus.item_identified` signal for all identification events
- Keep identification logic centralized in `IdentificationManager`
- Item display logic (tooltips, names) should query `IdentificationManager.is_identified()`
