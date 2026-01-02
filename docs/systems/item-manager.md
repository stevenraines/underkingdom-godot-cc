# Item Manager

**Source File**: `autoload/item_manager.gd`
**Type**: Autoload Singleton

## Overview

The Item Manager loads item definitions from JSON files and creates item instances. Items are loaded recursively from `data/items/` and all subdirectories. The manager provides factory methods for creating items and querying item data.

## Key Concepts

- **Item Definitions**: JSON templates loaded from `data/items/`
- **Item Instances**: Runtime Item objects created from definitions
- **Data Normalization**: Compatibility layer for different JSON formats
- **Recursive Loading**: Scans subdirectories automatically

## Core Properties

```gdscript
var _item_data: Dictionary = {}  # item_id -> data dictionary

const ITEM_DATA_BASE_PATH = "res://data/items"
```

## Item Loading

Items are loaded recursively at startup:

```gdscript
func _load_all_items():
    _load_items_from_folder(ITEM_DATA_BASE_PATH)
```

Scans these subdirectories:
- `ammunition/`
- `armor/`
- `consumables/`
- `materials/`
- `misc/`
- `tools/`
- `weapons/`

## Creating Items

### Single Item

```gdscript
var sword = ItemManager.create_item("iron_sword", 1)
```

Returns an Item instance with properties from definition.

### Multiple Stacks

```gdscript
var arrows = ItemManager.create_item_stacks("arrow", 50)
# Returns: Array[Item] with multiple stacks if count > max_stack
```

Automatically splits into multiple stacks when count exceeds max_stack.

## Query Functions

### Check Item Exists

```gdscript
var exists = ItemManager.has_item("iron_sword")
```

### Get Raw Data

```gdscript
var data = ItemManager.get_item_data("iron_sword")
# Returns: Dictionary with all item properties
```

### Filter by Type

```gdscript
var weapons = ItemManager.get_items_by_type("weapon")
var consumables = ItemManager.get_items_by_type("consumable")
```

### Filter by Category

```gdscript
var armor_items = ItemManager.get_items_by_category("armor")
```

### Filter by Flag

```gdscript
var equippable = ItemManager.get_items_with_flag("equippable")
var craftable = ItemManager.get_items_with_flag("craftable")
```

### Check Item Flags

```gdscript
var can_equip = ItemManager.item_has_flag("iron_sword", "equippable")
var flags = ItemManager.get_item_flags("iron_sword")
```

### Get All Items

```gdscript
var all_ids = ItemManager.get_all_item_ids()
```

## Data Normalization

The manager normalizes different JSON formats for compatibility:

```gdscript
func _normalize_item_data(data):
    # Convert 'category' to 'item_type'
    if "category" in data and "item_type" not in data:
        data["item_type"] = data["category"]

    # Handle consumable flag
    if flags.get("consumable", false):
        data["item_type"] = "consumable"

    # Handle tool flag
    if flags.get("tool", false):
        data["item_type"] = "tool"
```

## Supported File Formats

### Single Item (Current)

```json
{
  "id": "iron_sword",
  "name": "Iron Sword",
  "category": "weapon",
  ...
}
```

### Multi-Item (Legacy)

```json
{
  "items": [
    {"id": "iron_sword", ...},
    {"id": "iron_dagger", ...}
  ]
}
```

## Item Instance Creation

```gdscript
func create_item(item_id: String, count: int = 1) -> Item:
    var data = _item_data[item_id]
    var item = Item.create_from_data(data)

    if item.max_stack > 1 and count > 1:
        item.stack_size = min(count, item.max_stack)

    return item
```

## Stack Splitting

When creating stacks larger than max_stack:

```gdscript
func create_item_stacks(item_id: String, total_count: int) -> Array[Item]:
    var items: Array[Item] = []
    var remaining = total_count
    var max_stack = data.get("max_stack", 1)

    while remaining > 0:
        var stack_count = min(remaining, max_stack)
        var item = create_item(item_id, stack_count)
        items.append(item)
        remaining -= stack_count

    return items
```

Example: Creating 50 arrows with max_stack=20:
- Stack 1: 20 arrows
- Stack 2: 20 arrows
- Stack 3: 10 arrows

## Debug Functions

```gdscript
ItemManager.debug_print_items()
# Prints all loaded items with ID, name, and type
```

## Integration with Other Systems

- **InventorySystem**: Creates items for inventory operations
- **CraftingSystem**: Creates crafted items
- **LootTableManager**: Creates items for loot drops
- **EntityManager**: Creates items for ground items
- **SaveManager**: Creates items when loading saves

## Error Handling

```gdscript
if not has_item(item_id):
    push_error("ItemManager: Unknown item ID: %s" % item_id)
    return null
```

Returns null for unknown item IDs with error logging.

## Related Documentation

- [Items Data](../data/items.md) - Item JSON format
- [Inventory System](./inventory-system.md) - Item storage
- [Crafting System](./crafting-system.md) - Item creation
- [Loot Table Manager](./loot-table-manager.md) - Loot generation
