# Biome & Chunking System - Improvement Plan

**Branch**: `claude/biome-chunking-optimization-ntBBt`
**Base Commit**: cc925a9
**Current Commit**: 4d33460
**Changes**: 17 files, +1509/-87 lines

## Review Summary

### ✅ What Works Well

1. **Solid Foundation**
   - Chunk system cleanly separates overworld (infinite) from dungeons (static)
   - Biome generation is deterministic and varied
   - FOV shadowcasting is accurate and performant
   - Save/load properly handles both chunk and non-chunk maps

2. **Good Architecture**
   - Clean separation of concerns (ChunkManager, BiomeGenerator, ResourceSpawner)
   - Event-driven with proper signals
   - Transparent chunk access through GameMap

3. **Performance Gains**
   - 50%+ memory reduction
   - 2-3× rendering improvement
   - Efficient chunk loading/unloading

### ⚠️ Issues & Improvements Needed

## Critical Issues

### 1. **Duplicate Resource Spawning Logic** 🔴

**Problem**: Resources spawn in TWO places:
- `generation/world_generator.gd` calls `ResourceSpawner.spawn_resources()`
- `maps/world_chunk.gd` also spawns resources in `generate()`

**Current State**:
```gdscript
// world_generator.gd (Line 33-34)
ResourceSpawner.spawn_resources(map, seed_value)  // ❌ Called but map is empty for chunks

// world_chunk.gd (Line 54-73)
// Try to spawn resources  // ✅ Actually works for chunks
```

**Impact**: Confusion, potential double-spawning if both paths execute

**Solution**:
- Remove resource spawning from `WorldGenerator` for chunk-based maps
- Keep it only in `WorldChunk.generate()`
- Update `WorldGenerator` to only place special features (dungeon entrance, town, water sources)

---

### 2. **Hardcoded Special Feature Placement** 🔴

**Problem**: Dungeon entrance and town are hardcoded to chunk 5,5

```gdscript
// map_manager.gd (Line 57-63)
var entrance_pos = Vector2i(5 * 32 + 16, 5 * 32 + 16)  // ❌ Hardcoded
map.set_meta("dungeon_entrance", entrance_pos)
map.set_meta("town_center", Vector2i(4 * 32 + 16, 5 * 32 + 16))  // ❌ Hardcoded
```

**Impact**:
- Not actually placed in chunks (metadata doesn't create tiles)
- Player always spawns near same location
- No variety in world layout

**Solution**:
- Create `SpecialFeaturePlacer` system
- Use biome data to find suitable locations (town in grassland, dungeon in rocky hills)
- Place features when chunks generate
- Store in world metadata for persistence

---

### 3. **Minimap Not Integrated** 🟡

**Problem**: `ui/minimap.gd` exists but isn't added to HUD

**Impact**: Feature is implemented but not visible to player

**Solution**:
- Add minimap scene to HUD
- Position in corner of screen
- Add toggle key (M) to show/hide

---

### 4. **FOV Recalculation on Every Move** 🟡

**Problem**: FOV shadowcasting runs on every player move, even within same visible area

```gdscript
// game.gd (Line 327-328)
var visible_tiles = FOVSystem.calculate_fov(...)  // ❌ Every move
renderer.update_fov(visible_tiles)
```

**Impact**: Unnecessary CPU usage for shadowcasting

**Solution**:
- Cache FOV results
- Only recalculate when:
  - Player moves to different tile (not just pixel movement)
  - Map changes
  - Perception range changes (time of day)
  - Tiles around player are modified

---

## Medium Priority Issues

### 5. **No Biome Transition Smoothing** 🟡

**Problem**: Sharp boundaries between biomes

**Current**: Forest chunk directly adjacent to desert chunk

**Solution**:
- Implement biome blending at chunk edges
- Mix tree densities in transition zones
- Create "edge biomes" (forest-edge, desert-scrub, etc.)

---

### 6. **Chunk Edge Entity Rendering** 🟡

**Problem**: Entities near chunk boundaries might not render correctly if chunk unloads

**Potential Issue**:
```gdscript
// Entity at position (96, 50) - at edge of chunk (3, 1)
// If chunk (3, 1) unloads, entity might disappear
```

**Solution**:
- Keep entities in `EntityManager`, not in chunks
- Chunks only store tiles and resources
- Entity spatial hash for efficient queries

---

### 7. **No Async Chunk Generation** 🟡

**Problem**: Chunk generation happens on main thread

**Impact**: Potential frame drops when generating complex chunks

**Solution**:
- Use `Thread` or `WorkerThreadPool` for chunk generation
- Generate chunks asynchronously when player approaches
- Show loading indicator for slow chunks

---

### 8. **Memory Optimization Opportunities** 🟢

**Current**: All cached chunks kept in full detail

**Optimization**:
- Compress distant chunk data (keep only modifications)
- Save/load chunks to disk beyond cache size
- Implement LRU cache for chunks

---

### 9. **WorldGenerator Still Has Old Code** 🟢

**Problem**: `world_generator.gd` still has full map generation code for chunk-based maps

```gdscript
// Lines 16-30 - generates 80x40 map even for chunks
for y in range(map.height):  // ❌ Unnecessary for chunk mode
    for x in range(map.width):
        var biome = BiomeGenerator.get_biome_at(...)
        map.set_tile(...)  // ❌ Sets tiles that are never used
```

**Impact**: Confusing code, wasted CPU on map transition

**Solution**:
- Split into `generate_overworld_static()` and `generate_overworld_chunked()`
- Chunk mode only places special features
- Remove full tile generation for chunk mode

---

### 10. **No Chunk Generation Visualization** 🟢

**Problem**: No feedback when chunks are loading

**Solution**:
- Add chunk loading indicator
- Show "generating world" message on first load
- Display chunk coordinates in debug mode

---

## Low Priority Enhancements

### 11. **Biome-Specific Features** 🟢

**Enhancement**: Add biome-specific content
- Desert: Cacti, oases
- Forest: Berry bushes, mushrooms
- Mountains: Ore veins, caves
- Swamp: Poisonous plants, quicksand

---

### 12. **Weather & Seasons** 🟢

**Enhancement**: Dynamic biome modifiers
- Rain increases moisture temporarily
- Winter reduces tree density visibility
- Fog reduces FOV range

---

### 13. **Exploration Achievements** 🟢

**Enhancement**: Use visited chunks for progression
- "Explorer" - visit 50 chunks
- "Cartographer" - visit 100 chunks
- "World Wanderer" - visit all biome types

---

### 14. **Minimap Enhancements** 🟢

**Enhancement**: More minimap features
- Biome color-coding
- Mark special locations (dungeon, town)
- Waypoint system
- Zoom levels

---

### 15. **Chunk Prefetching** 🟢

**Enhancement**: Predict player movement
- Preload chunks in direction of player movement
- Smart caching based on player behavior
- Faster response when exploring new areas

---

## Implementation Priority

### Phase 1: Critical Fixes (4-6 hours)
1. ✅ Fix duplicate resource spawning
2. ✅ Implement proper special feature placement
3. ✅ Integrate minimap into HUD
4. ✅ Add FOV caching

### Phase 2: Medium Improvements (4-6 hours)
5. ✅ Add chunk edge safety checks
6. ✅ Clean up WorldGenerator code
7. ✅ Add biome transition smoothing
8. ✅ Implement chunk generation feedback

### Phase 3: Optimizations (3-4 hours)
9. ✅ Async chunk generation
10. ✅ Memory optimization (LRU cache)
11. ✅ Chunk compression

### Phase 4: Enhancements (Optional)
12. ✅ Biome-specific features
13. ✅ Weather system
14. ✅ Exploration achievements
15. ✅ Advanced minimap

---

## Detailed Implementation Plans

### Fix 1: Consolidate Resource Spawning

**File**: `generation/world_generator.gd`

**Remove** (Lines 32-34):
```gdscript
# Spawn procedural resources (trees, rocks) based on biome densities
print("[WorldGenerator] Spawning procedural resources...")
ResourceSpawner.spawn_resources(map, seed_value)
```

**Keep**: Only for non-chunk maps (future non-overworld static maps)

---

### Fix 2: Dynamic Special Feature Placement

**Create**: `generation/special_feature_placer.gd`

```gdscript
class_name SpecialFeaturePlacer

static func place_dungeon_entrance(world_seed: int) -> Vector2i:
    # Find rocky hills or barren rock biome
    # Search outward from spawn (chunk 5,5)
    # Return suitable position

static func place_town(world_seed: int, entrance_pos: Vector2i) -> Vector2i:
    # Find grassland or woodland near spawn
    # Not too close to dungeon
    # Return suitable position
```

**Update**: `autoload/chunk_manager.gd`
- Add `special_features` dictionary
- Place features when chunks generate
- Check metadata before generating

---

### Fix 3: Integrate Minimap

**Update**: `scenes/game.gd` or HUD scene
```gdscript
# Add minimap instance
var minimap = preload("res://ui/minimap.tscn").instantiate()
add_child(minimap)
minimap.position = Vector2(screen_width - 170, 20)  # Top-right corner
```

**Add**: Toggle key handling
```gdscript
if Input.is_action_just_pressed("toggle_minimap"):
    minimap.visible = !minimap.visible
```

---

### Fix 4: FOV Caching

**Update**: `systems/fov_system.gd`

```gdscript
static var cached_fov: Array[Vector2i] = []
static var cache_origin: Vector2i = Vector2i(-999, -999)
static var cache_range: int = -1
static var cache_time: String = ""
static var cache_dirty: bool = true

static func calculate_fov_cached(origin: Vector2i, range: int, map: GameMap) -> Array[Vector2i]:
    var current_time = TurnManager.time_of_day

    # Check if cache is valid
    if origin == cache_origin and range == cache_range and current_time == cache_time and not cache_dirty:
        return cached_fov

    # Recalculate
    cached_fov = calculate_fov(origin, range, map)
    cache_origin = origin
    cache_range = range
    cache_time = current_time
    cache_dirty = false

    return cached_fov

static func invalidate_cache():
    cache_dirty = true
```

---

## Testing Checklist

### Critical Fixes
- [ ] No duplicate resources spawn
- [ ] Dungeon entrance appears in suitable biome
- [ ] Town generates in appropriate location
- [ ] Minimap displays and updates correctly
- [ ] FOV doesn't recalculate unnecessarily

### Medium Improvements
- [ ] Entities render at chunk boundaries
- [ ] Biome transitions look smooth
- [ ] No performance drops during exploration
- [ ] Chunk generation doesn't block gameplay

### Optimizations
- [ ] Memory usage stays reasonable after long play
- [ ] Chunk cache doesn't grow infinitely
- [ ] Save/load times remain fast

---

## Rollback Strategy

Each fix should be in separate commits for easy rollback:
1. Fix duplicate spawning → Rollback if resources disappear
2. Fix special features → Rollback if placement breaks
3. Integrate minimap → Rollback if UI issues
4. Add FOV cache → Rollback if vision bugs occur

---

## Success Metrics

| Metric | Before | Target | Measurement |
|--------|--------|--------|-------------|
| Resource Spawn Bugs | Potential doubles | 0 | Manual testing |
| Special Feature Placement | 100% hardcoded | 100% dynamic | Code review |
| Minimap Usability | Not visible | Functional | User test |
| FOV Calculations/Move | 1 | 0.1-0.3 | Profiling |
| Memory Growth Rate | Unknown | <1MB/hour | Long play test |

---

## Timeline Estimate

- **Phase 1** (Critical): 6-8 hours
- **Phase 2** (Medium): 6-8 hours
- **Phase 3** (Optimization): 4-6 hours
- **Phase 4** (Enhancements): 8-12 hours (optional)

**Total for Core Improvements**: 16-22 hours (2-3 days)

---

**Created**: 2026-01-01
**Status**: Ready for Implementation
**Branch**: `claude/biome-chunking-optimization-ntBBt`
