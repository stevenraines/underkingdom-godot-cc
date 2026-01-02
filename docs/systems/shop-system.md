# Shop System

**Source File**: `systems/shop_system.gd`
**Type**: Game System (Node instance)

## Overview

The Shop System handles all buy/sell transactions between the player and shop NPCs. Prices are dynamically calculated based on the player's Charisma (CHA) stat, allowing charismatic characters to get better deals.

## Key Concepts

- **CHA-Based Pricing**: Charisma affects both buy and sell prices
- **Buy Ratio**: Shops buy items at 50% of base value
- **Price Modifiers**: CHA changes prices by 5% per point from baseline
- **Gold Tracking**: Both player and NPC gold are managed

## Core Mechanics

### CHA Price Modifier

Charisma affects prices at 5% per point difference from 10.

```
Modifier = (CHA - 10) × 5%
```

| CHA | Buy Price Modifier | Sell Price Modifier |
|-----|-------------------|---------------------|
| 6   | +20% (pay more) | -20% (get less) |
| 8   | +10% | -10% |
| 10  | 0% (baseline) | 0% |
| 12  | -10% (pay less) | +10% (get more) |
| 14  | -20% | +20% |
| 16  | -30% | +30% |
| 18  | -40% | +40% |
| 20  | -50% (minimum) | +50% (maximum) |

### Buy Price Calculation

When player buys from shop, higher CHA = lower price.

**Formula**:
```
Modifier = 1.0 - ((CHA - 10) × 0.05)
Modifier = clamp(Modifier, 0.5, 1.5)
Buy Price = max(1, floor(Base Price × Modifier))
```

**Examples** (Item with 100g base price):

| CHA | Modifier | Final Price |
|-----|----------|-------------|
| 6   | 1.20 | 120g |
| 8   | 1.10 | 110g |
| 10  | 1.00 | 100g |
| 12  | 0.90 | 90g |
| 14  | 0.80 | 80g |
| 18  | 0.60 | 60g |
| 20  | 0.50 | 50g |

### Sell Price Calculation

When player sells to shop, higher CHA = higher price.

**Formula**:
```
Base Sell = Base Price × 0.5  (50% ratio)
Modifier = 1.0 + ((CHA - 10) × 0.05)
Modifier = clamp(Modifier, 0.5, 1.5)
Sell Price = max(1, floor(Base Sell × Modifier))
```

**Examples** (Item with 100g base value):

| CHA | Base Sell | Modifier | Final Price |
|-----|-----------|----------|-------------|
| 6   | 50g | 0.80 | 40g |
| 8   | 50g | 0.90 | 45g |
| 10  | 50g | 1.00 | 50g |
| 12  | 50g | 1.10 | 55g |
| 14  | 50g | 1.20 | 60g |
| 18  | 50g | 1.40 | 70g |
| 20  | 50g | 1.50 | 75g |

### Price Range Summary

- **Buying**: 50% to 150% of base price
- **Selling**: 25% to 75% of base price (50% × modifier range)

## Purchase Flow

```gdscript
attempt_purchase(shop_npc, item_id, count, player) -> bool
```

### Validation Checks
1. Shop has the requested item
2. Shop has enough stock
3. Player has enough gold
4. Player can carry the weight

### Process
1. Calculate unit price using CHA modifier
2. Calculate total price (unit × count)
3. Validate player gold
4. Validate carry capacity
5. Deduct gold from player
6. Add gold to NPC
7. Remove item from NPC inventory
8. Create item and add to player inventory
9. Emit signals

### Error Messages
- "Shop doesn't sell that item."
- "Shop only has X available."
- "Not enough gold. Need Xg."
- "Too heavy to carry."

## Sale Flow

```gdscript
attempt_sell(shop_npc, item, count, player) -> bool
```

### Validation Checks
1. Player has the item
2. Player has enough quantity
3. Shop has enough gold

### Process
1. Calculate unit price using CHA modifier
2. Calculate total price
3. Validate shop gold
4. Add gold to player
5. Deduct gold from NPC
6. Remove item from player inventory
7. Add item to NPC inventory
8. Emit signals

### Error Messages
- "You don't have enough [item]."
- "Shop doesn't have enough gold."

## Price Display

The system provides formatted price strings for UI.

```gdscript
get_price_display(base_price, player_cha, is_buying) -> String
```

### Display Format
- Base price: "100g"
- Discount: "90g (-10%)"
- Markup: "110g (+10%)"

## Constants

```gdscript
CHARISMA_PRICE_MODIFIER = 0.05  # 5% per CHA point
SHOP_BUY_RATIO = 0.5            # Shops buy at 50%
```

## Signals Emitted

| Signal | Parameters | Description |
|--------|------------|-------------|
| `item_purchased` | item: Item, price: int | After successful purchase |
| `item_sold` | item: Item, price: int | After successful sale |
| `message_logged` | message: String | Status messages |
| `inventory_changed` | (none) | After transaction completes |

## NPC Shop Integration

Shop NPCs provide inventory via methods:

```gdscript
shop_npc.get_shop_item(item_id) -> Dictionary
# Returns: {item_id, count, base_price}

shop_npc.remove_shop_item(item_id, count)
shop_npc.add_shop_item(item_id, count, base_price)
```

## Gold Management

Both player and NPC have gold properties:

```gdscript
player.gold: int  # Player's current gold
shop_npc.gold: int  # NPC's current gold
```

Gold is transferred directly between entities during transactions.

## Weight Validation

Before purchase, system checks if player can carry the items:

```gdscript
item_weight = item_template.weight × count
current_weight = player.inventory.get_total_weight()
max_weight = player.inventory.max_weight

if current_weight + item_weight > max_weight:
    # Transaction blocked - "Too heavy to carry"
```

## Profit Margin Analysis

With CHA 10 (baseline):
- Buy for 100g, sell for 50g
- **Loss: 50%** on reselling same item

With CHA 20 (maximum):
- Buy for 50g, sell for 75g
- **Profit: 50%** on arbitrage

## Integration with Other Systems

- **InventorySystem**: Item transfer, weight checking
- **ItemManager**: Item creation, template lookup
- **NPC**: Shop inventory management
- **EventBus**: Transaction notifications
- **Player Entity**: Gold management

## Data Dependencies

- **Items** (`data/items/`): `value` property for base prices
- **NPCs**: Shop inventory configuration

## Related Documentation

- [Inventory System](./inventory-system.md) - Item and weight management
- [Items Data](../data/items.md) - Item value properties
