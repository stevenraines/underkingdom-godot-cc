# Map Manager

**Source File**: `autoload/map_manager.gd`
**Type**: Autoload Singleton

## Overview

The Map Manager handles all map-related operations including loading, caching, transitions between maps, and dungeon floor management. It serves as the central hub for map access, coordinating between the overworld chunk system and dungeon floor generation.

## Key Concepts

- **Map Cache**: Previously generated maps stored for quick reload
- **Map Transitions**: Moving between overworld and dungeon floors
- **Dungeon Tracking**: Current dungeon type and floor number
- **Feature Loading**: Initializing features and hazards on map load

## Core Properties

```gdscript
var loaded_maps: Dictionary = {}     # map_id -> GameMap (cache)
var current_map: GameMap = null      # Currently active map
var current_dungeon_floor: int = 0   # 0 = overworld
var current_dungeon_type: String = "" # e.g., "burial_barrow"
```

## Map ID Format

| Map Type | Format | Example |
|----------|--------|---------|
| Overworld | `"overworld"` | `"overworld"` |
| Dungeon Floor | `"{type}_floor_{N}"` | `"burial_barrow_floor_1"` |

## Core Functionality

### Getting Maps

```gdscript
var map = MapManager.get_or_generate_map(map_id, world_seed)
```

1. Check cache for existing map
2. If not cached, generate new map
3. Store in cache
4. Return map

### Map Transitions

```gdscript
MapManager.transition_to_map(map_id)
```

1. Get or generate the target map
2. Update GameManager current map state
3. Enable/disable chunk mode based on map type
4. Load features and hazards for dungeons
5. Emit `map_changed` signal

### Dungeon Navigation

```gdscript
MapManager.enter_dungeon(dungeon_type)  # Enter floor 1
MapManager.descend_dungeon()            # Go deeper (+1 floor)
MapManager.ascend_dungeon()             # Go up (-1 floor or exit)
```

### Dungeon Entrance Detection

```gdscript
var entrance = MapManager.get_dungeon_entrance_at(position)
# Returns: {dungeon_type, position} or null
```

## Map Generation

### Overworld

```gdscript
# Creates chunk-based map shell
var map = GameMap.new("overworld", 10000, 10000, seed)
map.chunk_based = true
```

Overworld uses ChunkManager for on-demand terrain generation.

**Special Features Placed**:
- Town center position
- Player spawn position
- Dungeon entrance positions
- Shop NPC spawn data

### Dungeon Floors

```gdscript
# Delegates to DungeonManager
return DungeonManager.generate_floor(dungeon_type, floor_number, world_seed)
```

## Feature and Hazard Loading

When transitioning to a dungeon floor:

```gdscript
func _load_features_and_hazards(map: GameMap) -> void:
    # Load hints from dungeon definition
    var hints = _load_dungeon_hints(dungeon_id)
    FeatureManager.set_dungeon_hints(hints)

    # Load from map metadata
    FeatureManager.load_features_from_map(map)
    HazardManager.load_hazards_from_map(map)
```

## Map Metadata

### Overworld Metadata

```gdscript
map.set_meta("town_center", Vector2i)
map.set_meta("player_spawn", Vector2i)
map.set_meta("dungeon_entrances", Array)
map.metadata["npc_spawns"] = [{...}]
```

### Dungeon Metadata

```gdscript
map.metadata["floor_number"] = int
map.metadata["dungeon_id"] = String
map.metadata["pending_features"] = Array
map.metadata["pending_hazards"] = Array
```

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `map_changed` | map_id: String | Emitted via EventBus after transition |

## Dungeon Floor Transition Flow

```
Player on stairs_down
    ↓
MapManager.descend_dungeon()
    ↓
current_dungeon_floor += 1
    ↓
transition_to_map("{type}_floor_{N}")
    ↓
get_or_generate_map() - check cache
    ↓
DungeonManager.generate_floor() if not cached
    ↓
_load_features_and_hazards()
    ↓
EventBus.map_changed.emit()
```

## Cache Management

```gdscript
MapManager.clear_cache()  # Clear all cached maps
```

Maps remain cached for the session to allow quick transitions back to previously visited floors.

## Integration with Other Systems

- **GameManager**: Stores current map ID, world seed
- **ChunkManager**: Manages overworld chunk loading
- **DungeonManager**: Generates dungeon floors
- **FeatureManager**: Receives feature data from map
- **HazardManager**: Receives hazard data from map
- **EventBus**: Emits map_changed signal

## Map ID Parsing

For dungeon floors, the map ID is parsed to extract components:

```gdscript
# "burial_barrow_floor_3"
var floor_idx = map_id.find("_floor_")
var dungeon_type = map_id.substr(0, floor_idx)  # "burial_barrow"
var floor_number = int(map_id.substr(floor_idx + 7))  # 3
```

## Related Documentation

- [Chunk Manager](./chunk-manager.md) - Overworld chunk streaming
- [Dungeon Manager](./dungeon-manager.md) - Dungeon floor generation
- [Feature Manager](./feature-manager.md) - Interactive features
- [Hazard Manager](./hazard-manager.md) - Traps and hazards
