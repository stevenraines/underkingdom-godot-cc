# Structure Manager

**Source File**: `autoload/structure_manager.gd`
**Type**: Autoload Singleton

## Overview

The Structure Manager loads structure definitions from JSON and manages all placed structures. It tracks structures per map for persistence, provides queries for structures by position or radius, and handles serialization for save/load.

## Key Concepts

- **Structure Definitions**: JSON templates in `data/structures/`
- **Placed Structures**: Runtime instances on specific maps
- **Persistence**: Structures survive map regeneration
- **Fire Sources**: Special query for crafting proximity

## Core Properties

```gdscript
var structure_definitions: Dictionary = {}  # id -> definition
var placed_structures: Dictionary = {}       # map_id -> Array[Structure]
```

## Core Functions

### Creating Structures

```gdscript
var structure = StructureManager.create_structure("campfire", position)
```

Creates a Structure instance from definition (not placed yet).

### Placing Structures

```gdscript
StructureManager.place_structure(map_id, structure)
```

1. Add to placed_structures for map
2. Invalidate FOV cache (vision may change)
3. Emit `structure_placed` signal

### Removing Structures

```gdscript
StructureManager.remove_structure(map_id, structure)
```

1. Remove from placed_structures
2. Invalidate FOV cache
3. Emit `structure_removed` signal

## Query Functions

### Structures on Map

```gdscript
var structures = StructureManager.get_structures_on_map(map_id)
# Returns: Array of all structures on map
```

### Structures at Position

```gdscript
var structures = StructureManager.get_structures_at(position, map_id)
# Returns: Array of structures at exact position
```

### Structures in Radius

```gdscript
var nearby = StructureManager.get_structures_in_radius(center, radius, map_id)
# Returns: Array within Manhattan distance
```

### Fire Sources in Radius

```gdscript
var fires = StructureManager.get_fire_sources_in_radius(center, 3, map_id)
# Returns: Active fire sources within range
```

Used for proximity crafting (cooking near campfire).

## Serialization

### Save

```gdscript
var data = StructureManager.serialize()
# Returns: {"placed_structures": {map_id: [structure_data, ...]}}
```

### Load

```gdscript
StructureManager.deserialize(data)
```

Clears current structures and restores from save data.

### Clear All

```gdscript
StructureManager.clear_all_structures()
```

Used when starting new game.

## Structure Definition Loading

Definitions loaded from `data/structures/*.json`:

```gdscript
const STRUCTURE_DATA_PATH = "res://data/structures"

func _load_structure_definitions():
    # Scans directory for all .json files
```

## Integration with Other Systems

- **StructurePlacement**: Validates and places structures
- **FOVSystem**: Structures may block vision
- **CraftingSystem**: Queries fire sources for proximity
- **SaveManager**: Serializes/deserializes structures
- **Renderer**: Displays structure tiles

## Signals

| Signal | Description |
|--------|-------------|
| `structure_placed` | Via EventBus when structure added |
| `structure_removed` | Via EventBus when structure removed |

## Structure Instance Properties

Created structures have:
- Position (Vector2i)
- Definition reference
- is_fire_source (bool)
- is_active (bool) - for fires, whether lit
- Components (fire, shelter, container)

## Related Documentation

- [Structure Placement](./structure-placement.md) - Placement validation
- [Structures Data](../data/structures.md) - JSON format
- [Crafting System](./crafting-system.md) - Fire source proximity
