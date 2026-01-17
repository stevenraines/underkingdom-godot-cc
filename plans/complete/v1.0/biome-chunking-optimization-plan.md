# Biome Generation and Chunk-Based Map Optimization Plan

## Problem Statement

The current world generator creates performance issues:
1. **Single-noise terrain**: Uses one Perlin noise layer, resulting in simplistic biome distribution
2. **Trees as terrain**: Trees are baked into tiles, not procedurally spawned resources
3. **Full map generation**: Generates entire 80×40 map upfront, all tiles stored in memory
4. **Full map rendering**: Renders all tiles every frame, including those far from player
5. **Island generation**: Creates water-surrounded islands that can grow too large

## Goals

1. **Rich Biome System**: Use elevation + moisture noise for varied, realistic biomes
2. **Procedural Tree Spawning**: Trees as harvestable resources, spawned based on biome density
3. **Chunk-Based Management**: Only load/manage chunks near player for performance
4. **Optimized Rendering**: Only render visible chunks, not entire map
5. **Infinite World Support**: Foundation for potentially infinite world generation

## Design Overview

### 1. Biome System Architecture

Based on Red Blob Games polygon map generation principles ([source](http://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation/)):

**Dual-Noise Approach**:
```
Elevation Noise (octaves: 3, frequency: 0.03)
    ↓
Moisture Noise (octaves: 2, frequency: 0.05)
    ↓
Biome Lookup Table (Whittaker-style diagram)
    ↓
Terrain Tiles + Resource Density
```

**Biome Definitions** (elevation × moisture matrix):

| Elevation | Low Moisture | Medium Moisture | High Moisture |
|-----------|--------------|-----------------|---------------|
| **Ocean** (<0.25) | Deep Water | Shallow Water | Marsh |
| **Low** (0.25-0.4) | Beach/Sand | Grassland | Wetland |
| **Medium** (0.4-0.65) | Scrubland | Woodland | Forest |
| **High** (0.65-0.85) | Rocky Hills | Taiga | Dense Forest |
| **Mountain** (>0.85) | Barren Rock | Snow | Glacier |

**Biome Properties**:
```gdscript
class BiomeDefinition:
    var biome_id: String  # "woodland", "forest", "scrubland", etc.
    var base_tile: String  # "floor", "water", etc.
    var tree_density: float  # 0.0-1.0 (probability of tree at position)
    var rock_density: float  # 0.0-1.0
    var grass_char: String  # Visual variation for floor tiles
    var movement_cost: int  # Future: stamina cost multiplier
```

### 2. Chunk-Based World Management

**Chunk Size**: 32×32 tiles (optimized for TileMapLayer rendering)

**Chunk Coordinates**:
- World position `(x, y)` → Chunk `(x / 32, y / 32)`
- Chunk `(cx, cy)` → World bounds `(cx*32, cy*32)` to `(cx*32+31, cy*32+31)`

**Chunk Loading System**:
```gdscript
class WorldChunk:
    var chunk_coords: Vector2i  # Chunk grid position
    var tiles: Dictionary  # Vector2i (local) -> GameTile
    var resources: Array[ResourceInstance]  # Trees, rocks spawned in this chunk
    var seed: int  # Deterministic generation seed
    var is_loaded: bool
```

**Active Chunk Management**:
- Load radius: 3 chunks (96 tiles) around player
- Unload chunks beyond 5 chunk radius (160 tiles)
- Total active chunks: ~7×7 = 49 chunks max (1,568 tiles vs 3,200 full map)
- **50% memory reduction**, more as player explores less

**Chunk State Machine**:
```
Unloaded → [Player approaches] → Generating → Loaded → [Player leaves] → Unloaded
```

### 3. Procedural Resource Spawning

**Current Problem**: Trees are `GameTile` objects embedded in terrain
**Solution**: Trees as separate `ResourceInstance` entities spawned per chunk

**ResourceInstance Structure**:
```gdscript
class ResourceInstance:
    var resource_id: String  # "tree", "rock", "iron_ore"
    var position: Vector2i  # World position
    var chunk_coords: Vector2i  # Parent chunk
    var despawn_turn: int  # For renewable resources (0 = permanent)
    var is_active: bool  # Currently loaded
```

**Spawning Algorithm** (per chunk):
```gdscript
func spawn_chunk_resources(chunk: WorldChunk, biome: BiomeDefinition):
    var rng = SeededRandom.new(chunk.seed)

    for local_y in range(32):
        for local_x in range(32):
            var world_pos = chunk.chunk_coords * 32 + Vector2i(local_x, local_y)
            var tile = chunk.tiles[Vector2i(local_x, local_y)]

            # Only spawn on walkable floor tiles
            if not tile.walkable or tile.tile_type != "floor":
                continue

            # Check tree spawning based on biome density
            if rng.randf() < biome.tree_density:
                chunk.resources.append(ResourceInstance.new("tree", world_pos, chunk.chunk_coords))

            # Check rock spawning
            elif rng.randf() < biome.rock_density:
                chunk.resources.append(ResourceInstance.new("rock", world_pos, chunk.chunk_coords))
```

**Rendering Integration**:
- Resources render as blocking tiles on terrain layer (like current trees)
- When harvested, remove from chunk's `resources` array
- For renewable: store `despawn_turn` in save data

### 4. Implementation Plan

#### Phase 1: Biome System (3-4 hours)

**Files to Create**:
- `generation/biome_definitions.gd` - Biome data structures
- `generation/biome_generator.gd` - Elevation + moisture noise → biome lookup

**Files to Modify**:
- `generation/world_generator.gd` - Replace single noise with dual-noise + biome lookup

**Steps**:
1. Create `BiomeDefinition` class with properties (id, base_tile, densities, colors)
2. Define 12-15 biomes in biome table (elevation × moisture matrix)
3. Implement `BiomeGenerator.get_biome_at(x, y, seed)`:
   - Generate elevation noise (octaves: 3, frequency: 0.03)
   - Generate moisture noise (octaves: 2, frequency: 0.05)
   - Return biome from lookup table
4. Update `WorldGenerator.generate_overworld()`:
   - For each tile, call `get_biome_at()`
   - Set base tile from biome definition
   - **Don't spawn trees yet** (Phase 2)
5. Test: Verify varied biomes render correctly, no performance regression

**Expected Output**: Overworld with ocean, beaches, grasslands, forests, mountains

#### Phase 2: Tree Resource Spawning (2-3 hours)

**Files to Create**:
- `systems/resource_spawner.gd` - Procedural resource spawning logic

**Files to Modify**:
- `generation/world_generator.gd` - Call resource spawner after terrain generation
- `maps/game_tile.gd` - Remove tree tile type (trees become resources)
- `rendering/ascii_renderer.gd` - Add resource rendering layer

**Steps**:
1. Create `ResourceInstance` class (resource_id, position, chunk_coords)
2. Implement `ResourceSpawner.spawn_resources(map, biome_generator)`:
   - For each floor tile, get biome
   - Roll for tree spawn based on `biome.tree_density`
   - Add to map metadata: `map.set_meta("resources", resources_array)`
3. Update `_render_map()`:
   - After rendering tiles, render resources as blocking entities
   - Use existing tree character 'T'
4. Update `HarvestSystem`:
   - Check if position has resource in metadata array
   - Remove from array when harvested
   - For renewable, add to respawn tracking
5. Test: Trees spawn in forests (high density), sparse in grasslands, none in deserts

**Expected Output**: Trees as harvestable resources, density varies by biome

#### Phase 3: Chunk System Foundation (4-5 hours)

**Files to Create**:
- `maps/world_chunk.gd` - Chunk data structure
- `autoload/chunk_manager.gd` - Chunk loading/unloading, active chunk tracking

**Files to Modify**:
- `autoload/map_manager.gd` - Delegate to ChunkManager for overworld
- `maps/map.gd` - Add chunk-aware tile access methods

**Steps**:
1. Create `WorldChunk` class:
   - `chunk_coords: Vector2i`, `tiles: Dictionary`, `resources: Array`
   - `generate(biome_generator, seed)` - Generate 32×32 tiles + resources
2. Create `ChunkManager` autoload:
   - `active_chunks: Dictionary` - (chunk_coords → WorldChunk)
   - `load_chunk(chunk_coords)` - Generate or retrieve from cache
   - `unload_chunk(chunk_coords)` - Remove from active, keep in disk cache
   - `update_active_chunks(player_pos)` - Load/unload based on player position
3. Update `GameMap`:
   - Add `chunk_based: bool` flag (true for overworld, false for dungeons)
   - Modify `get_tile(pos)`:
     ```gdscript
     if chunk_based:
         var chunk_coords = pos / 32
         var chunk = ChunkManager.get_chunk(chunk_coords)
         return chunk.tiles[pos % 32]
     else:
         return tiles[pos]  # Old behavior for dungeons
     ```
4. Update `game.gd`:
   - Connect to `EventBus.player_moved`
   - Call `ChunkManager.update_active_chunks(player.position)`
5. Test: Walk around overworld, verify chunks load/unload, no visual glitches

**Expected Output**: Chunks load dynamically, only ~49 chunks active at once

#### Phase 4: Chunk-Optimized Rendering (3-4 hours)

**Files to Modify**:
- `scenes/game.gd` - `_render_map()` only renders active chunks
- `rendering/ascii_renderer.gd` - Add `render_chunk()` method

**Steps**:
1. Add `ASCIIRenderer.render_chunk(chunk)`:
   - Only render tiles within chunk bounds
   - Use TileMapLayer batch operations for efficiency
2. Modify `_render_map()`:
   ```gdscript
   if MapManager.current_map.chunk_based:
       for chunk_coords in ChunkManager.active_chunks:
           var chunk = ChunkManager.active_chunks[chunk_coords]
           renderer.render_chunk(chunk)
   else:
       # Old full-map rendering for dungeons
       for y in range(height):
           for x in range(width):
               renderer.render_tile(...)
   ```
3. Optimize FOV calculation:
   - Only calculate FOV for tiles in active chunks
   - Skip out-of-bounds checks for unloaded chunks
4. Update wall culling for dungeons:
   - Keep existing flood-fill for dungeon maps (small, static)
5. Test: Measure FPS improvement, verify rendering correctness

**Expected Output**: 2-3× FPS improvement, seamless chunk transitions

#### Phase 5: Save/Load Integration (2-3 hours)

**Files to Modify**:
- `autoload/save_manager.gd` - Serialize active chunks + resource states

**Steps**:
1. Add chunk serialization:
   ```gdscript
   func save_chunks(slot: int):
       var chunk_data = []
       for coords in ChunkManager.active_chunks:
           chunk_data.append({
               "coords": coords,
               "resources": serialize_resources(chunk.resources),
               "modified_tiles": chunk.modified_tiles  # Player-built structures
           })
       save_data["chunks"] = chunk_data
   ```
2. Add resource state tracking:
   - Store harvested resource positions per chunk
   - Store renewable resource respawn timers
3. Update load system:
   - Restore player position first
   - Load surrounding chunks
   - Apply resource modifications from save
4. Test: Save game, harvest trees, reload, verify trees remain harvested

**Expected Output**: Chunk states persist across saves

### 5. Additional Performance Optimizations

#### A. Entity Spatial Hashing (2 hours)

**Problem**: Current `entities` array requires O(n) search for collision checks

**Solution**: Spatial hash grid for O(1) entity lookup

```gdscript
class EntitySpatialHash:
    var grid: Dictionary  # Vector2i → Array[Entity]
    var cell_size: int = 8  # 8×8 tile cells

    func add_entity(entity):
        var cell = entity.position / cell_size
        grid.get_or_add(cell, []).append(entity)

    func get_entities_near(pos, radius):
        var results = []
        var center_cell = pos / cell_size
        for dy in range(-radius/cell_size, radius/cell_size+1):
            for dx in range(-radius/cell_size, radius/cell_size+1):
                results.append_array(grid.get(center_cell + Vector2i(dx, dy), []))
        return results
```

**Impact**: Collision checks O(n) → O(1), AI range queries faster

#### B. Lazy FOV Calculation (1 hour)

**Problem**: FOV recalculated every player move, even when visibility doesn't change

**Solution**: Cache FOV, only recalculate when perception range changes or map modified

```gdscript
var cached_fov: Array[Vector2i] = []
var last_fov_position: Vector2i = Vector2i(-999, -999)
var fov_dirty: bool = true

func calculate_fov_lazy(pos, range):
    if pos == last_fov_position and not fov_dirty:
        return cached_fov

    cached_fov = FOVSystem.calculate_fov(pos, range, map)
    last_fov_position = pos
    fov_dirty = false
    return cached_fov
```

**Impact**: 50-70% reduction in FOV calculations

#### C. TileMapLayer Dirty Rectangles (1 hour)

**Problem**: Entire terrain layer redrawn on entity move

**Solution**: Use Godot's built-in dirty rect tracking, only redraw changed regions

```gdscript
func render_tile_dirty(pos, char):
    terrain_layer.set_cell(pos, 0, _char_to_atlas_coords(char))
    # Godot automatically marks only this cell as dirty
```

**Impact**: Reduced GPU overdraw, better performance on large maps

#### D. Enemy AI Tick Budgeting (2 hours)

**Problem**: All enemies process AI every turn, can spike with many enemies

**Solution**: Process N enemies per frame, spread over multiple frames

```gdscript
var enemy_ai_index: int = 0
const ENEMIES_PER_TICK: int = 5

func process_enemy_turns():
    var enemies = EntityManager.get_all_enemies()
    var processed = 0

    while processed < ENEMIES_PER_TICK and enemy_ai_index < enemies.size():
        enemies[enemy_ai_index].process_turn()
        enemy_ai_index += 1
        processed += 1

    if enemy_ai_index >= enemies.size():
        enemy_ai_index = 0
        EventBus.all_enemies_processed.emit()
```

**Impact**: Prevents turn lag spikes, smoother framerate

## Testing Strategy

### Unit Tests
- Biome generation: Same seed → same biomes
- Chunk loading: Correct chunk coords for world positions
- Resource spawning: Density matches biome definition

### Integration Tests
- Walk across chunk boundaries, verify seamless loading
- Harvest tree, save, reload, verify tree remains harvested
- Spawn 100 enemies, verify FPS remains stable

### Performance Benchmarks
- **Before**: 80×40 map (3,200 tiles), ~45 FPS, 120MB RAM
- **After**: 7×7 chunks (1,568 active tiles), target: ~120 FPS, 80MB RAM

## Rollback Plan

If critical bugs found:
1. Use git to revert to pre-chunking commit
2. Keep biome system (Phase 1), disable chunking (Phase 3-4)
3. Trees as resources still works without chunking

## Migration Path

**Existing saves**: Incompatible, must start new game
- Add version number to save format: `"save_version": 2`
- Show warning message: "This save is from an older version, please start a new game"

## Timeline Estimate

- **Phase 1** (Biome System): 3-4 hours
- **Phase 2** (Tree Resources): 2-3 hours
- **Phase 3** (Chunk Foundation): 4-5 hours
- **Phase 4** (Chunk Rendering): 3-4 hours
- **Phase 5** (Save/Load): 2-3 hours
- **Phase 6** (Performance Opts): 4-6 hours
- **Testing & Polish**: 3-4 hours

**Total**: 21-29 hours (~3-4 work days)

## Future Enhancements

- Infinite world support (chunk persistence to disk)
- Biome transition smoothing (gradient blending)
- Rivers and lakes using moisture flow simulation
- Dynamic weather affecting biome moisture values
- Chunk-based structure placement (villages, ruins)

## References

1. [Red Blob Games: Voronoi Maps Tutorial](https://www.redblobgames.com/x/2022-voronoi-maps-tutorial/)
2. [Red Blob Games: Polygon Map Generation](http://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation/)
3. [Mapgen2 Implementation](https://github.com/redblobgames/mapgen2)
4. Whittaker Life Zones diagram (elevation × moisture biome classification)

---

**Plan Status**: Ready for implementation
**Branch**: `claude/biome-chunking-optimization-ntBBt`
**Author**: Claude Code
**Date**: 2026-01-01
