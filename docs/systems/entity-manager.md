# Entity Manager

**Source File**: `autoload/entity_manager.gd`
**Type**: Autoload Singleton

## Overview

The Entity Manager handles all game entities including enemies, NPCs, and ground items. It loads enemy definitions from JSON, manages entity spawning/removal, coordinates entity turns, and provides queries for entities at positions. The player reference is also stored here.

## Key Concepts

- **Entity**: Base class for all game objects (Player, Enemy, NPC, GroundItem)
- **Enemy Definitions**: JSON templates loaded from `data/enemies/`
- **Entity Tracking**: All entities stored in central array
- **Turn Processing**: Coordinates enemy AI during turn advancement

## Core Properties

```gdscript
var entities: Array[Entity] = []     # All active entities (excluding player)
var enemy_definitions: Dictionary = {} # Enemy ID -> definition
var player: Player = null             # Player reference
```

## Enemy Definition Loading

Enemy definitions are loaded recursively from `data/enemies/`:

```gdscript
const ENEMY_DATA_BASE_PATH = "res://data/enemies"

func _load_enemy_definitions():
    _load_enemies_from_folder(ENEMY_DATA_BASE_PATH)
```

Supports both single-enemy files and legacy multi-enemy format.

## Core Functionality

### Spawning Enemies

```gdscript
var enemy = EntityManager.spawn_enemy("skeleton", Vector2i(10, 20))
```

1. Look up enemy definition
2. Create Enemy instance from definition
3. Set position
4. Add to entities array
5. Add to current map's entity list
6. Return enemy reference

### Spawning Ground Items

```gdscript
var ground_item = EntityManager.spawn_ground_item(item, position, despawn_turns)
```

Creates a GroundItem entity for items on the ground.

### Spawning NPCs

```gdscript
var npc = EntityManager.spawn_npc(spawn_data)
```

Spawn data includes:
- `npc_id`: Identifier
- `npc_type`: "shop", "generic", etc.
- `position`: Vector2i
- `name`: Display name
- `gold`: Starting gold
- `restock_interval`: Turns between restocks

### Removing Entities

```gdscript
EntityManager.remove_entity(entity)
```

Removes from both global array and current map.

## Query Functions

### Entities at Position

```gdscript
var entities = EntityManager.get_entities_at(position)
# Returns: Array[Entity] of alive entities at position
```

### Ground Items at Position

```gdscript
var items = EntityManager.get_ground_items_at(position)
# Returns: Array[GroundItem]
```

### Blocking Entity at Position

```gdscript
var blocker = EntityManager.get_blocking_entity_at(position)
# Returns: First blocking entity or null
```

## Enemy Definition Queries

```gdscript
EntityManager.has_enemy_definition(enemy_id)  # Check if exists
EntityManager.get_enemy_definition(enemy_id)   # Get definition dict
EntityManager.get_all_enemy_ids()              # All enemy IDs
EntityManager.get_enemies_by_behavior(type)    # Filter by behavior
```

## Turn Processing

```gdscript
EntityManager.process_entity_turns()
```

Called by TurnManager after player turn:

```gdscript
for entity in entities:
    if entity.is_alive:
        if entity is Enemy:
            entity.take_turn()
        elif entity.has_method("process_turn"):
            entity.process_turn()
```

## Map State Persistence

### Saving Entity States

```gdscript
EntityManager.save_entity_states_to_map(map)
```

Stores enemies, items, and NPCs in map metadata for later restoration.

### Restoring Entity States

```gdscript
var restored = EntityManager.restore_entity_states_from_map(map)
# Returns: true if map was visited before and entities restored
```

Used when returning to previously visited maps.

## Saved Entity Data

### Enemies

```gdscript
{
    "enemy_id": "skeleton",
    "position": Vector2i(10, 20),
    "current_health": 12,
    "max_health": 15
}
```

### NPCs

```gdscript
{
    "npc_id": "shop_keeper",
    "name": "Olaf the Trader",
    "position": Vector2i(5, 5),
    "npc_type": "shop",
    "gold": 500,
    "trade_inventory": [...]
}
```

### Ground Items

```gdscript
{
    "item_id": "iron_sword",
    "item_count": 1,
    "position": Vector2i(8, 12)
}
```

## Utility Functions

```gdscript
EntityManager.clear_entities()            # Clear all entities
EntityManager.get_current_map_entities()  # Get alive entities on current map
```

## Shop NPC Setup

When spawning a shop NPC:

```gdscript
if npc.npc_type == "shop":
    npc.dialogue = {
        "greeting": "Welcome to my shop...",
        "buy": "Take a look at my wares...",
        "sell": "Let me see what you have...",
        "farewell": "Safe travels..."
    }
    npc.load_shop_inventory()
```

## Integration with Other Systems

- **TurnManager**: Calls process_entity_turns each turn
- **MapManager**: Entities added to current map's list
- **ItemManager**: Creates items for ground items
- **CombatSystem**: Queries entities for combat resolution

## Related Documentation

- [Enemies Data](../data/enemies.md) - Enemy JSON format
- [Combat System](./combat-system.md) - Enemy combat
- [Turn Manager](./turn-manager.md) - Turn processing
- [Map Manager](./map-manager.md) - Map entity tracking
