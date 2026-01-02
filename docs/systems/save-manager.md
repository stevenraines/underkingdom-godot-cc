# Save Manager

**Source File**: `autoload/save_manager.gd`
**Type**: Autoload Singleton

## Overview

The Save Manager handles game state serialization and persistence. It manages three save slots, save/load operations, and complete state serialization including player, world, maps, and entities. Save files are stored as JSON in the user directory.

## Key Concepts

- **Save Slots**: Three numbered slots for saves
- **Serialization**: Convert game state to JSON
- **Deserialization**: Restore game state from JSON
- **Deferred Loading**: Two-phase load process

## Configuration

```gdscript
const SAVE_DIR = "user://saves/"
const SAVE_FILE_PATTERN = "save_slot_%d.json"
const MAX_SLOTS = 3
const SAVE_VERSION = "1.0.0"
```

## Core Functions

### Saving

```gdscript
var success = SaveManager.save_game(slot)  # slot: 1-3
```

Returns true on success, emits signals.

### Loading

```gdscript
var success = SaveManager.load_game(slot)  # slot: 1-3
```

Loads data into pending_save_data, requires apply step.

### Apply Pending Save

```gdscript
SaveManager.apply_pending_save()
```

Called by game scene after initialization to apply loaded data.

### Get Slot Info

```gdscript
var info = SaveManager.get_save_slot_info(slot)
# Returns SaveSlotInfo with metadata
```

### Delete Save

```gdscript
SaveManager.delete_save(slot)
```

## Save File Structure

```json
{
  "metadata": {
    "save_name": "Adventure Save",
    "timestamp": "2024-01-15T14:30:00",
    "slot_number": 1,
    "playtime_turns": 1500,
    "version": "1.0.0"
  },
  "world": {...},
  "player": {...},
  "maps": {...},
  "entities": {...}
}
```

## Serialized Data

### World State

```json
{
  "seed": 12345,
  "world_name": "My World",
  "current_turn": 1500,
  "time_of_day": "day",
  "current_map_id": "overworld",
  "current_dungeon_floor": 0
}
```

### Player State

```json
{
  "position": {"x": 100, "y": 50},
  "attributes": {"STR": 12, "DEX": 10, ...},
  "health": {"current": 45, "max": 50},
  "survival": {
    "hunger": 75.5,
    "thirst": 60.2,
    "temperature": 20.0,
    "stamina": 80.0,
    "fatigue": 10.0
  },
  "inventory": [...],
  "equipment": {...},
  "gold": 150,
  "experience": 500,
  "known_recipes": ["flint_knife", "cooked_meat"]
}
```

### Inventory Items

```json
{
  "item_id": "iron_sword",
  "count": 1,
  "durability": 95
}
```

### Equipment

```json
{
  "main_hand": "iron_sword",
  "torso": "leather_armor",
  "head": null
}
```

### Maps

```json
{
  "overworld": {
    "width": 10000,
    "height": 10000,
    "chunk_based": true,
    "chunks": [...]
  },
  "burial_barrow_floor_1": {
    "width": 50,
    "height": 50,
    "chunk_based": false,
    "tiles": [...]
  }
}
```

### Entities

```json
{
  "npcs": [
    {
      "npc_id": "shop_keeper",
      "npc_type": "shop",
      "position": {"x": 50, "y": 50},
      "name": "Olaf",
      "gold": 500,
      "inventory": [...]
    }
  ],
  "enemies": [
    {
      "enemy_id": "skeleton",
      "position": {"x": 30, "y": 20},
      "current_health": 12,
      "max_health": 15,
      "is_aggressive": true
    }
  ]
}
```

## Load Process

1. `load_game(slot)` - Read JSON, store in pending_save_data
2. Game scene initializes
3. `apply_pending_save()` called by game scene
4. Deserialization proceeds:
   - Set is_deserializing flag
   - Clear map cache
   - Restore world state
   - Restore player state
   - Transition to saved map
   - Restore map tiles
   - Restore entities
   - Clear flag

## SaveSlotInfo Class

```gdscript
class SaveSlotInfo:
    var slot_number: int = 0
    var exists: bool = false
    var save_name: String = "Empty Slot"
    var world_name: String = ""
    var timestamp: String = ""
    var playtime_turns: int = 0
```

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `game_saved` | slot: int | Via EventBus on success |
| `game_loaded` | slot: int | Via EventBus on success |
| `save_failed` | error: String | Via EventBus on failure |
| `load_failed` | error: String | Via EventBus on failure |

## Chunk Saving

For chunk-based maps (overworld):
```gdscript
maps_data[map_id] = {
    "chunk_based": true,
    "chunks": ChunkManager.save_chunks()
}
```

## Tile Preservation

Non-chunked maps save all tiles to preserve:
- Harvested resources (trees cut, ores mined)
- Modified terrain
- Tile state changes

## Entity State Preservation

Enemies save combat state:
- Current health
- Alert status
- Target position
- Last known player position

## Error Handling

```gdscript
if slot < 1 or slot > MAX_SLOTS:
    EventBus.emit_signal("save_failed", "Invalid slot number")
    return false

if not FileAccess.file_exists(file_path):
    EventBus.emit_signal("load_failed", "Save file does not exist")
    return false
```

## Integration with Other Systems

- **GameManager**: World seed, state
- **TurnManager**: Turn counter, time of day
- **EntityManager**: Player, enemies, NPCs
- **MapManager**: Current map, cache
- **ChunkManager**: Overworld chunks
- **ItemManager**: Item creation during load

## Related Documentation

- [Game Manager](./game-manager.md) - Game state
- [Entity Manager](./entity-manager.md) - Entity serialization
- [Inventory System](./inventory-system.md) - Item serialization
- [Chunk Manager](./chunk-manager.md) - Chunk serialization
