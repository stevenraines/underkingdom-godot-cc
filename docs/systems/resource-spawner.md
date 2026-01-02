# Resource Spawner

**Source File**: `systems/resource_spawner.gd`
**Type**: Static Class
**Class Name**: `ResourceSpawner`

## Overview

The Resource Spawner procedurally places harvestable resources (trees, rocks) across maps based on biome densities. It handles initial spawn, harvest removal, and renewable resource respawning. Resources are stored as map metadata for persistence.

## Key Concepts

- **Biome-Based Density**: Resource frequency determined by biome type
- **Seeded Generation**: Same seed produces identical resource placement
- **Resource Instances**: Track individual resource state
- **Respawn System**: Renewable resources regenerate after N turns

## ResourceInstance Class

Inner class representing a single spawned resource:

```gdscript
class ResourceInstance:
    var resource_id: String      # "tree", "rock", etc.
    var position: Vector2i       # World position
    var chunk_coords: Vector2i   # Parent chunk (future chunking)
    var despawn_turn: int        # Respawn turn (0 = permanent)
    var is_active: bool          # Currently rendered
```

### Serialization

```gdscript
func to_dict() -> Dictionary:
    return {
        "resource_id": resource_id,
        "position": [position.x, position.y],
        "chunk_coords": [chunk_coords.x, chunk_coords.y],
        "despawn_turn": despawn_turn,
        "is_active": is_active
    }

static func from_dict(data: Dictionary) -> ResourceInstance
```

## Core Functions

### Spawn Resources

```gdscript
static func spawn_resources(map: GameMap, seed_value: int) -> void
```

Iterates all map tiles and spawns resources based on biome density:

```gdscript
for y in range(map.height):
    for x in range(map.width):
        var tile = map.get_tile(pos)

        # Only spawn on walkable floor tiles
        if not tile.walkable or tile.tile_type != "floor":
            continue

        var biome = BiomeGenerator.get_biome_at(x, y, seed_value)

        # Try tree spawn
        if rng.randf() < biome.tree_density:
            # Spawn tree, mark tile as blocked

        # Try rock spawn (if no tree)
        if rng.randf() < biome.rock_density:
            # Spawn rock, mark tile as blocked
```

### Tile Modification

When resource spawns:

```gdscript
# Tree
tile.walkable = false
tile.transparent = false
tile.ascii_char = "T"
tile.harvestable_resource_id = "tree"

# Rock
tile.walkable = false
tile.transparent = false
tile.ascii_char = "◆"
tile.harvestable_resource_id = "rock"
```

### Get Resource at Position

```gdscript
static func get_resource_at(map: GameMap, position: Vector2i) -> ResourceInstance
```

Returns resource instance or `null` if none at position.

### Remove Resource

```gdscript
static func remove_resource_at(map: GameMap, position: Vector2i) -> bool
```

Called when resource is harvested permanently.

### Schedule Respawn

```gdscript
static func schedule_respawn(map: GameMap, resource: ResourceInstance, respawn_turns: int) -> void
```

For renewable resources:

```gdscript
resource.despawn_turn = TurnManager.current_turn + respawn_turns
resource.is_active = false
```

### Process Respawns

```gdscript
static func process_respawns(map: GameMap) -> void
```

Called by TurnManager each turn:

```gdscript
for resource in resources:
    if not resource.is_active:
        if current_turn >= resource.despawn_turn:
            # Respawn: set is_active = true, restore tile
```

## Seeded Generation

Uses offset from world seed:

```gdscript
var rng = SeededRandom.new(seed_value + 5000)  # Offset for resources
```

This ensures:
- Same world seed → same resource placement
- Resources differ from terrain generation (different offset)

## Biome Density Values

From biome definitions:

| Biome | Tree Density | Rock Density |
|-------|--------------|--------------|
| Forest | 0.15 | 0.02 |
| Grassland | 0.03 | 0.01 |
| Mountain | 0.01 | 0.10 |
| Desert | 0.00 | 0.05 |

## Map Metadata Storage

Resources stored as map metadata:

```gdscript
# Store
map.set_meta("resources", resources)

# Retrieve
var resources: Array = map.get_meta("resources")
```

## Chunk Coordinates

Future chunking support:

```gdscript
var chunk_coords = Vector2i(x / 32, y / 32)
```

Resources track their chunk for potential streaming optimization.

## Resource Spawn Flow

```
1. Map generated
2. spawn_resources(map, seed) called
3. For each walkable floor tile:
   a. Get biome at position
   b. Roll against tree_density
   c. If success: spawn tree, skip rock
   d. Roll against rock_density
   e. If success: spawn rock
4. Resources stored in map metadata
5. Tiles modified (walkable, char, etc.)
```

## Respawn Flow

```
1. Player harvests renewable resource
2. HarvestSystem calls schedule_respawn()
3. Resource marked inactive, despawn_turn set
4. Each turn, process_respawns() checks all inactive
5. When current_turn >= despawn_turn:
   a. Resource reactivated
   b. Tile restored to blocking
   c. ASCII char restored
```

## ASCII Characters

| Resource | Character |
|----------|-----------|
| Tree | `T` |
| Rock | `◆` |

## Integration with Other Systems

- **BiomeGenerator**: Provides density values per biome
- **HarvestSystem**: Triggers removal/respawn
- **TurnManager**: Calls process_respawns() each turn
- **MapManager**: Provides maps for resource storage

## Related Documentation

- [Harvest System](./harvest-system.md) - Resource harvesting
- [Biome Manager](./biome-manager.md) - Biome densities
- [Resources Data](../data/resources.md) - Resource definitions
