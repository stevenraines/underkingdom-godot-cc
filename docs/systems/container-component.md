# Container Component

**Source File**: `systems/components/container_component.gd`
**Type**: Component Class
**Class Name**: `ContainerComponent`

## Overview

The Container Component provides item storage functionality for structures like chests. It wraps the Inventory class to enable structures to hold items independently of entities, with support for weight limits and future locking mechanics.

## Key Concepts

- **Inventory Wrapper**: Uses Inventory class for item management
- **Weight Limit**: Maximum total weight the container can hold
- **Lock State**: Future support for locked containers
- **Serialization**: Full save/load support

## Core Properties

```gdscript
var inventory: Inventory = null   # Item storage
var max_weight: float = 50.0      # kg capacity
var is_locked: bool = false       # Future: lock/key system
```

## Default Values

| Property | Default | Description |
|----------|---------|-------------|
| `max_weight` | 50.0 | Maximum weight in kg |
| `is_locked` | false | Lock state |

## Initialization

```gdscript
func _init(max_weight_kg: float = 50.0) -> void:
    max_weight = max_weight_kg
    # Create inventory without an owner (structures don't have stats)
    inventory = Inventory.new(null)
    inventory.max_weight = max_weight
```

Note: Structures don't have entity owners, so inventory is created with `null` owner.

## Core Functions

### Add Item

```gdscript
func add_item(item: Item) -> bool:
    if is_locked:
        return false
    return inventory.add_item(item)
```

Returns `false` if:
- Container is locked
- Would exceed weight limit
- Item is invalid

### Remove Item

```gdscript
func remove_item(item: Item) -> bool:
    if is_locked:
        return false
    return inventory.remove_item(item)
```

### Query Functions

```gdscript
func get_items() -> Array[Item]     # All items in container
func get_total_weight() -> float    # Current weight
func is_full() -> bool              # At capacity?
```

### Full Check

```gdscript
func is_full() -> bool:
    return inventory.get_total_weight() >= max_weight
```

## Serialization

### Save State

```gdscript
func serialize() -> Dictionary:
    return {
        "max_weight": max_weight,
        "is_locked": is_locked,
        "inventory": inventory.serialize()
    }
```

### Load State

```gdscript
func deserialize(data: Dictionary) -> void:
    max_weight = data.get("max_weight", 50.0)
    is_locked = data.get("is_locked", false)

    if data.has("inventory"):
        inventory.deserialize(data.inventory)
```

## JSON Configuration

From structure definition:

```json
"components": {
    "container": {
        "max_weight": 50.0
    }
}
```

## Usage Flow

### Player Interaction

```
1. Player presses 'E' near container structure
2. Game opens container UI
3. Player can transfer items between inventory and container
4. Changes saved automatically
```

### Code Usage

```gdscript
# Get container from structure
var structure = StructureManager.get_structure_at(position)
if structure and structure.container_component:
    var container = structure.container_component

    # Check capacity
    if not container.is_full():
        # Transfer item
        if container.add_item(item):
            player.inventory.remove_item(item)
```

## Weight Calculation

Uses underlying Inventory class:

```gdscript
# Weight check happens in Inventory.add_item()
if inventory.get_total_weight() + item.get_total_weight() > max_weight:
    return false  # Would exceed limit
```

## Future Lock System

```gdscript
# Planned functionality
func lock(key_id: String) -> void:
    is_locked = true
    required_key = key_id

func unlock(key_item: Item) -> bool:
    if key_item.id == required_key:
        is_locked = false
        return true
    return false
```

## Container Types Comparison

| Container | Max Weight | Notes |
|-----------|------------|-------|
| Chest | 50.0 kg | Standard storage |
| Barrel | 100.0 kg | Liquid storage (future) |
| Crate | 75.0 kg | Bulk materials (future) |

## Integration with Other Systems

- **Inventory**: Uses Inventory class for item management
- **StructureManager**: Tracks container structures
- **SaveManager**: Serializes container state
- **UI**: Container screen for item transfer

## Related Documentation

- [Inventory System](./inventory-system.md) - Item management
- [Structure Manager](./structure-manager.md) - Structure tracking
- [Structures Data](../data/structures.md) - Container config
