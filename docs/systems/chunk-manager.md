# Chunk Manager

**Source File**: `autoload/chunk_manager.gd`
**Type**: Autoload Singleton

## Overview

The Chunk Manager handles infinite world streaming through chunk-based loading and unloading. Only chunks near the player are kept in memory, allowing for large procedurally generated worlds. Chunks are generated deterministically from the world seed.

## Key Concepts

- **Chunk**: 32×32 tile region of the world
- **Active Chunks**: Currently loaded and rendered
- **Chunk Cache**: LRU cache of generated chunks
- **Load Radius**: Distance from player to load chunks
- **Unload Radius**: Distance beyond which chunks unload

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| `chunk_size` | 32 | Tiles per chunk dimension |
| `load_radius` | 2 | Load chunks within N distance |
| `unload_radius` | 4 | Unload chunks beyond N distance |
| `cache_max_size` | 100 | Maximum cached chunks |

Configuration loaded from `data/world_generation_config.json`.

## Core Properties

```gdscript
var active_chunks: Dictionary = {}     # Vector2i -> WorldChunk
var chunk_cache: Dictionary = {}       # LRU cache
var chunk_access_order: Array = []     # LRU tracking
var visited_chunks: Dictionary = {}    # For minimap
var world_seed: int = 0
var is_chunk_mode: bool = false
```

## Coordinate System

### World to Chunk Conversion

```gdscript
static func world_to_chunk(world_pos: Vector2i) -> Vector2i:
    return Vector2i(
        floori(float(world_pos.x) / CHUNK_SIZE),
        floori(float(world_pos.y) / CHUNK_SIZE)
    )
```

**Example**: World position (100, 75) → Chunk (3, 2) with CHUNK_SIZE=32.

### Local Position

```gdscript
var local_pos = world_pos - (chunk_coords * CHUNK_SIZE)
```

## Core Functionality

### Enabling Chunk Mode

```gdscript
ChunkManager.enable_chunk_mode("overworld", seed)
```

Only enabled for overworld; dungeons use fixed maps.

### Getting Chunks

```gdscript
var chunk = ChunkManager.get_chunk(chunk_coords)
```

1. Check active chunks
2. Check cache
3. Generate new chunk if needed

### Loading Chunks

```gdscript
var chunk = ChunkManager.load_chunk(chunk_coords)
```

1. Check island bounds
2. Create new WorldChunk
3. Generate terrain
4. Add to active and cache
5. Update LRU tracking
6. Emit `chunk_loaded` signal

### Updating Active Chunks

```gdscript
ChunkManager.update_active_chunks(player_position)
```

Called on player movement:
1. Calculate player's chunk
2. Determine chunks to load (within load_radius)
3. Load new chunks
4. Unload distant chunks (beyond unload_radius)

## LRU Cache

The cache uses Least Recently Used eviction:

```gdscript
func _touch_chunk_lru(chunk_coords):
    # Remove from current position
    chunk_access_order.erase(chunk_coords)
    # Add to end (most recent)
    chunk_access_order.append(chunk_coords)
```

When cache exceeds `max_cache_size`, oldest chunks are evicted.

## Island Bounds

Chunks outside island bounds return null/ocean:

```gdscript
var island = BiomeManager.get_island_settings()
if chunk_x < 0 or chunk_x >= island.width_chunks:
    return null  # Outside bounds
```

Default island size: 25×25 chunks (800×800 tiles).

## Tile Access

### Get Tile

```gdscript
var tile = ChunkManager.get_tile(world_pos)
```

Returns the tile at world position, loading chunk if needed.

### Set Tile

```gdscript
ChunkManager.set_tile(world_pos, tile)
```

Modifies tile at world position.

## Serialization

### Save

```gdscript
var data = ChunkManager.save_chunks()
# Returns array of chunk dictionaries
```

### Load

```gdscript
ChunkManager.load_chunks(chunks_data)
```

Restores chunks from save, adds to cache.

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `chunk_loaded` | chunk_coords | Via EventBus when chunk generates |
| `chunk_unloaded` | chunk_coords | Via EventBus when chunk unloads |

## Distance Calculation

Uses Chebyshev distance (max of x/y differences) for consistent square loading area:

```gdscript
var distance = max(abs(coords.x - player_chunk.x),
                   abs(coords.y - player_chunk.y))
```

## Loading Pattern

With `load_radius = 2`:
```
. . . . .
. X X X .
. X P X .
. X X X .
. . . . .
```
P = Player, X = Loaded, . = Unloaded

Total: 5×5 = 25 chunks around player.

## Memory Management

```gdscript
ChunkManager.clear_chunks()  # Clear all chunks
```

Called automatically on dungeon entry to free memory.

## Performance Considerations

- **Chunk Size**: 32×32 = 1024 tiles per chunk
- **Active Chunks**: ~25 chunks at load_radius=2
- **Cache Size**: 100 chunks max (3,200,000 tiles cached)
- **Generation**: On-demand, seeded for determinism

## Integration with Other Systems

- **MapManager**: Enables chunk mode for overworld
- **BiomeManager**: Provides island and chunk settings
- **WorldChunk**: Actual chunk data and generation
- **Renderer**: Renders only active chunks

## Visited Chunks

Tracks which chunks player has visited for minimap:

```gdscript
var visited = ChunkManager.get_visited_chunks()
# Returns Array[Vector2i] of all visited chunk coordinates
```

## Related Documentation

- [Map Manager](./map-manager.md) - Map transitions
- [Biome Manager](./biome-manager.md) - Terrain generation config
- [Biomes Data](../data/biomes.md) - Biome definitions
- [World Generation](../data/world-generation.md) - Generation config
