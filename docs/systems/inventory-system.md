# Inventory System

**Source File**: `systems/inventory_system.gd`
**Type**: Game System (Instance per Entity)
**Class Name**: `Inventory`

## Overview

The Inventory System manages all items carried and equipped by entities. It handles item storage, equipment slots, weight tracking, encumbrance penalties, and item stacking. Each entity that can carry items has its own Inventory instance.

## Key Concepts

- **Inventory**: Array of carried items (not equipped)
- **Equipment**: Dictionary of items in equipment slots
- **Weight**: Total mass of all carried and equipped items
- **Encumbrance**: Penalties applied when carrying too much weight
- **Stacking**: Combining multiple identical items into one slot

## Equipment Slots

The system provides 9 equipment slots:

| Slot | Display Name | Typical Items |
|------|--------------|---------------|
| `head` | Head | Helmets, caps |
| `torso` | Torso | Armor, robes |
| `hands` | Hands | Gloves, gauntlets |
| `legs` | Legs | Pants, greaves |
| `feet` | Feet | Boots, shoes |
| `main_hand` | Main Hand | Weapons, tools |
| `off_hand` | Off Hand | Shields, secondary weapons |
| `accessory_1` | Accessory | Rings, amulets |
| `accessory_2` | Accessory | Rings, amulets |

### Two-Handed Weapons

Two-handed weapons (bows, staves, etc.) occupy `main_hand` and block the `off_hand` slot:
- Equipping a two-handed weapon auto-unequips off_hand item
- Cannot equip to off_hand while two-handed weapon is in main_hand
- Check with `is_off_hand_blocked()` method

## Weight and Capacity

### Maximum Carry Weight

```
Max Weight = 20 + (STR × 5) kg
```

| STR | Max Weight |
|-----|------------|
| 8   | 60 kg |
| 10  | 70 kg |
| 12  | 80 kg |
| 14  | 90 kg |
| 16  | 100 kg |
| 18  | 110 kg |
| 20  | 120 kg |

### Total Weight Calculation

```
Total Weight = Sum of (item.weight × item.stack_size) for all items
            + Sum of equipped item weights
```

### Encumbrance Ratio

```
Encumbrance Ratio = Total Weight / Max Weight
```

## Encumbrance System

Carrying too much weight applies penalties:

| Ratio | State | Stamina Cost | Movement Cost | Can Move |
|-------|-------|--------------|---------------|----------|
| 0-75% | Normal | ×1.0 | 1 turn | Yes |
| 75-100% | Encumbered | ×1.5 | 1 turn | Yes |
| 100-125% | Overburdened | ×2.0 | 2 turns | Yes |
| >125% | Immobile | N/A | N/A | **No** |

### Encumbrance Examples

**Player with STR 10 (70 kg capacity):**

| Carrying | Ratio | State |
|----------|-------|-------|
| 50 kg | 71% | Normal |
| 55 kg | 79% | Encumbered (+50% stamina costs) |
| 75 kg | 107% | Overburdened (+100% stamina, 2-turn moves) |
| 90 kg | 129% | Immobile (cannot move) |

## Item Stacking

Items with `max_stack > 1` can be combined into a single inventory slot.

### Stacking Rules
- Items must have same `id` to stack
- Stack size limited by `max_stack` property
- When adding items, system auto-stacks with existing items first
- Overflow creates new inventory slot

### Stack Example

Adding 15 arrows (max_stack: 20) to inventory with 8 arrows:
1. Find existing arrow stack (8)
2. Add to existing: 8 + 15 = 23
3. Existing stack capped at 20
4. Leftover: 3 arrows in new stack

## Adding Items

```gdscript
inventory.add_item(item: Item) -> bool
```

### Process
1. If item is stackable, search for existing stack
2. Add to existing stack if found (up to max_stack)
3. Create new inventory slot for remaining items
4. Emit `inventory_changed` signal
5. Emit `encumbrance_changed` signal
6. Return true (always succeeds currently)

## Removing Items

### By Item Instance
```gdscript
inventory.remove_item(item: Item) -> bool
```

### By Item ID and Count
```gdscript
inventory.remove_item_by_id(item_id: String, count: int = 1) -> int
# Returns actual number removed
```

Removes from stacks, cleans up empty stacks automatically.

## Equipping Items

```gdscript
inventory.equip_item(item: Item, target_slot: String = "") -> Array[Item]
```

### Process
1. Validate item is equippable
2. Determine slot (auto-select if not specified)
3. Handle two-handed weapon special case
4. Remove item from inventory
5. Swap with currently equipped item (if any)
6. Add previous item to inventory
7. Emit `item_equipped` signal
8. Return array of unequipped items

### Auto Slot Selection
If no slot specified:
1. Check item's `equip_slots` array
2. Find first empty slot in that list
3. If all occupied, use first slot (will swap)

### Two-Handed Handling
When equipping two-handed weapon to main_hand:
1. Check if off_hand has item
2. Unequip off_hand item first
3. Add to inventory
4. Equip two-handed weapon

## Unequipping Items

```gdscript
inventory.unequip_slot(slot: String) -> Item
```

Removes item from slot, adds to inventory, returns the item.

## Using Items

```gdscript
inventory.use_item(item: Item) -> Dictionary
```

### Process
1. Call item's `use()` method with owner
2. If item consumed:
   - Check for `transforms_into` (e.g., waterskin_full → waterskin_empty)
   - Create transformed item if applicable
   - Reduce stack or remove item
3. Emit `item_used` signal
4. Return result dictionary

### Use Result
```gdscript
{
    "success": bool,    # Whether use succeeded
    "consumed": bool,   # Whether item was consumed
    "message": String   # Description of effect
}
```

## Querying Inventory

### Check for Items
```gdscript
inventory.has_item(item_id: String, count: int = 1) -> bool
inventory.get_item_count(item_id: String) -> int
inventory.get_item_by_id(item_id: String) -> Item  # First match
inventory.contains_item(item: Item) -> bool  # Exact instance
```

### Check for Tools
```gdscript
inventory.has_tool(tool_type: String) -> bool  # Checks inventory AND equipped
inventory.get_tool(tool_type: String) -> Item  # Returns first match
```

### Get Equipment
```gdscript
inventory.get_equipped(slot: String) -> Item
inventory.get_items_for_slot(slot: String) -> Array[Item]  # Inventory items valid for slot
```

## Combat Integration

### Weapon Damage
```gdscript
inventory.get_weapon_damage_bonus() -> int
# Returns damage_bonus from main_hand weapon, or 0 if unarmed
```

### Armor Value
```gdscript
inventory.get_total_armor() -> int
# Sum of armor_value from all equipped items
```

## Serialization

### Save
```gdscript
inventory.serialize() -> Dictionary
# Returns:
{
    "items": [
        {"id": "iron_sword", "stack_size": 1, "durability": 100},
        ...
    ],
    "equipment": {
        "main_hand": {"id": "iron_sword", "stack_size": 1, "durability": 95},
        "torso": {"id": "leather_armor", "stack_size": 1, "durability": 100}
    }
}
```

### Load
```gdscript
inventory.deserialize(data: Dictionary) -> void
```
Clears current inventory, loads items and equipment from save data.

## Signals Emitted

| Signal | Parameters | Description |
|--------|------------|-------------|
| `inventory_changed` | (none) | When items added/removed |
| `encumbrance_changed` | ratio: float | When weight changes |
| `item_equipped` | item: Item, slot: String | When item equipped |
| `item_unequipped` | item: Item, slot: String | When item unequipped |
| `item_used` | item: Item, result: Dictionary | When item used |

## Integration with Other Systems

- **Player Entity**: Owns primary inventory, provides STR for capacity
- **CombatSystem**: Reads weapon damage and armor values
- **SurvivalSystem**: Uses items via `use_item()` for eating/drinking
- **HarvestSystem**: Checks for required tools
- **CraftingSystem**: Checks for ingredients, adds crafted items
- **ShopSystem**: Transfers items during buy/sell
- **GroundItem**: Created when items dropped

## Data Dependencies

### Items (`data/items/`)
| Property | Usage |
|----------|-------|
| `weight` | Added to total weight |
| `max_stack` | Stacking limit |
| `equip_slots` | Valid equipment slots |
| `damage_bonus` | Combat damage |
| `armor_value` | Damage reduction |
| `flags.equippable` | Can be equipped |
| `flags.consumable` | Can be used |

## Related Documentation

- [Combat System](./combat-system.md) - Weapon and armor stats
- [Survival System](./survival-system.md) - Consumable effects
- [Shop System](./shop-system.md) - Buying and selling
- [Crafting System](./crafting-system.md) - Using ingredients
- [Items Data](../data/items.md) - Item properties reference
