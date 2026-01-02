# Terrain Generation & Rendering Improvements

## Overview

This plan addresses critical architectural issues in the terrain generation system and adds realistic environmental features to create a more immersive, data-driven world. The improvements maintain SOLID principles, eliminate code duplication, and provide a modding-friendly foundation.

## Current System Analysis

### Strengths
- ✅ Chunk-based infinite world streaming (32×32 tiles)
- ✅ Dual Perlin noise biome generation (elevation × moisture)
- ✅ LRU cache for chunk management
- ✅ Biome definitions loaded from JSON
- ✅ World generation config in JSON

### Critical Issues
- ❌ **Biome colors defined in JSON but never used by renderer**
- ❌ **Tile properties hardcoded in GameTile.create() instead of JSON**
- ❌ **Duplicate biome systems (BiomeDefinition.gd unused legacy code)**
- ❌ **Resource appearances hardcoded despite having resource JSON files**
- ❌ **Elevation calculated but not visually represented**
- ❌ **Resources spawn uniformly (unrealistic, should cluster)**
- ❌ **No terrain features (rivers, roads, paths)**

### Architecture Violations
1. **Open/Closed Principle**: Adding new tiles requires modifying GameTile.create()
2. **Single Responsibility**: GameTile mixes definition with runtime state
3. **Dependency Inversion**: Renderer depends on hardcoded colors instead of abstraction
4. **DRY**: Resource characters defined in 3 places (WorldChunk, GameTile, ASCIIRenderer)

## Implementation Phases

### Phase 1: Fix Data-Driven Architecture (Critical)
**Goal**: Make the rendering pipeline respect data-driven tile and biome definitions

**Estimated Time**: 2-3 hours
**Dependencies**: None
**Risk**: Low (fixes existing broken pipeline)

### Phase 2: Biome Resource & Enemy Population
**Goal**: Data-driven spawn logic for biome-specific resources, flora, and creatures

**Estimated Time**: 3-4 hours
**Dependencies**: Phase 1 (TileManager)
**Risk**: Medium (requires refactoring spawn logic)

### Phase 3: Realistic Terrain Features
**Goal**: Add rivers, roads, elevation rendering, resource clustering

**Estimated Time**: 4-5 hours
**Dependencies**: Phase 1
**Risk**: Medium (new generation algorithms)

### Phase 4: Extensible Generation Architecture
**Goal**: Feature generator registry for modding support

**Estimated Time**: 2-3 hours
**Dependencies**: Phase 3
**Risk**: Low (wrapper around existing systems)

---

## Phase 1: Fix Data-Driven Architecture

### Task 1.1: Create TileManager Autoload & Tile JSON Definitions

**Assignee**: [Backend Developer]
**Priority**: Critical
**Estimated Time**: 1.5 hours
**Dependencies**: None

**Objective**: Replace hardcoded tile definitions with JSON-based system matching items/enemies/recipes architecture.

**Current Problem**:
```gdscript
// maps/game_tile.gd:23-89
static func create(type: String) -> GameTile:
    match type:
        "floor": tile.ascii_char = "."
        "wall": tile.ascii_char = "░"
        "tree": tile.ascii_char = "T"  # 50+ lines of hardcoded values
```

**Solution Architecture**:

1. **Create TileManager autoload** (`autoload/tile_manager.gd`)
   - Mirrors ItemManager/EntityManager pattern
   - Loads tile definitions from `data/tiles/*.json`
   - Provides `get_tile_definition(tile_id: String) -> Dictionary`
   - Caches definitions in `tile_definitions: Dictionary`

2. **Create tile JSON schema** (`data/tiles/`)
   ```json
   {
     "id": "tree",
     "name": "Tree",
     "walkable": false,
     "transparent": false,
     "ascii_char": "T",
     "color": [0.0, 0.71, 0.0],
     "harvestable_resource_id": "tree",
     "movement_cost": 1,
     "is_fire_source": false,
     "description": "A sturdy tree with harvestable wood"
   }
   ```

3. **Refactor GameTile.create()** to use TileManager
   ```gdscript
   static func create(tile_id: String) -> GameTile:
       var def = TileManager.get_tile_definition(tile_id)
       var tile = GameTile.new()
       tile.tile_type = tile_id
       tile.walkable = def.get("walkable", true)
       tile.transparent = def.get("transparent", true)
       tile.ascii_char = def.get("ascii_char", "?")
       tile.harvestable_resource_id = def.get("harvestable_resource_id", "")
       tile.is_fire_source = def.get("is_fire_source", false)
       return tile
   ```

**Implementation Steps**:

1. Create `autoload/tile_manager.gd`
   - Add `const TILE_DATA_PATH = "res://data/tiles"`
   - Implement recursive JSON loading (copy from ItemManager pattern)
   - Add error handling for missing/invalid tiles
   - Add `get_tile_definition()`, `get_tile_color()`, `get_tile_char()` methods

2. Create `data/tiles/` directory structure
   ```
   data/tiles/
   ├── terrain/
   │   ├── floor.json
   │   ├── wall.json
   │   └── water.json
   ├── resources/
   │   ├── tree.json
   │   ├── rock.json
   │   └── iron_ore.json
   └── structures/
       ├── door.json
       └── stairs_down.json
   ```

3. Create JSON files for all existing tile types (15+ tiles)
   - floor, wall, water, deep_water
   - tree, rock, iron_ore, wheat
   - stairs_down, stairs_up
   - door_closed, door_open
   - campfire

4. Register TileManager in `project.godot` autoload section
   ```
   [autoload]
   TileManager="*res://autoload/tile_manager.gd"
   ```

5. Refactor `maps/game_tile.gd`
   - Replace match statement with TileManager lookups
   - Keep `create()` method signature for compatibility
   - Add fallback for unknown tile types

6. Update all tile creation call sites
   - `maps/world_chunk.gd` (biome tile creation)
   - `generation/world_generator.gd`
   - `generation/dungeon_generators/burial_barrow.gd`

**Files Modified**:
- NEW: `autoload/tile_manager.gd`
- NEW: `data/tiles/**/*.json` (15+ files)
- MODIFIED: `project.godot` (autoload registration)
- MODIFIED: `maps/game_tile.gd` (remove match statement)
- MODIFIED: `maps/world_chunk.gd` (use tile IDs)
- MODIFIED: `generation/world_generator.gd`
- MODIFIED: `generation/dungeon_generators/burial_barrow.gd`

**Testing Checklist**:
- [ ] TileManager loads all tile JSON files without errors
- [ ] `TileManager.get_tile_definition("floor")` returns correct data
- [ ] GameTile.create("tree") produces correct tile properties
- [ ] Unknown tile ID shows warning and returns fallback
- [ ] World generation creates correct tiles
- [ ] Dungeon generation creates correct tiles
- [ ] All tile colors/characters match previous hardcoded values

**Benefits**:
- ✅ Modders can add tiles without code changes
- ✅ Consistent with items/enemies/recipes architecture
- ✅ Open/Closed Principle compliance
- ✅ Single source of truth for tile properties

---

### Task 1.2: Fix Biome Color Rendering Pipeline

**Assignee**: [Rendering Engineer]
**Priority**: Critical
**Estimated Time**: 1 hour
**Dependencies**: Task 1.1 (TileManager)

**Objective**: Connect biome color data from JSON to the actual renderer, fixing the broken data flow.

**Current Problem**:
```
BiomeManager JSON → BiomeGenerator returns colors → WorldChunk IGNORES them → ASCIIRenderer uses HARDCODED colors
```

Result: All grasslands, forests, tundras render with same gray floor despite having unique colors in JSON.

**Data Flow Analysis**:

1. **Biome JSON defines colors** (`data/biomes/grassland.json`):
   ```json
   {
     "color_floor": [0.4, 0.6, 0.3],
     "color_grass": [0.5, 0.7, 0.4]
   }
   ```

2. **BiomeGenerator converts to Color objects** (`generation/biome_generator.gd:63-73`):
   ```gdscript
   return {
       "color_floor": Color(0.4, 0.6, 0.3),
       "color_grass": Color(0.5, 0.7, 0.4)
   }
   ```

3. **WorldChunk DISCARDS the colors** (`maps/world_chunk.gd:48`):
   ```gdscript
   var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)
   var tile = GameTile.create(biome.base_tile)
   # biome.color_floor is NEVER USED!
   ```

4. **ASCIIRenderer uses hardcoded colors** (`rendering/ascii_renderer.gd:80-89`):
   ```gdscript
   var default_terrain_colors: Dictionary = {
       ".": Color(0.31, 0.31, 0.31),  # Gray floor (WRONG)
       "T": Color(0.0, 0.71, 0.0),    # Green tree (WRONG)
   }
   ```

**Solution Architecture**:

1. **Extend GameTile with color property**:
   ```gdscript
   class_name GameTile
   var color: Color  # NEW: Biome-specific or tile-specific color
   ```

2. **Store biome color in tile during chunk generation**:
   ```gdscript
   # maps/world_chunk.gd:generate()
   var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)
   var tile = GameTile.create(biome.base_tile)
   tile.color = biome.color_floor  # NEW: Store biome color
   ```

3. **Use tile color in renderer with fallback**:
   ```gdscript
   # rendering/ascii_renderer.gd
   func _get_tile_color(tile: GameTile) -> Color:
       if tile.color != Color(0, 0, 0):  # Has custom color
           return tile.color
       # Fallback to tile definition color
       var tile_def = TileManager.get_tile_definition(tile.tile_type)
       return Color(tile_def.color[0], tile_def.color[1], tile_def.color[2])
   ```

**Implementation Steps**:

1. Add `color: Color` property to `maps/game_tile.gd`
   - Initialize to `Color(0, 0, 0)` (black = no override)
   - Add to serialization methods (`to_dict()`, `from_dict()`)

2. Modify `maps/world_chunk.gd:generate()`
   - After creating tile from biome, set `tile.color = biome.color_floor`
   - For grass variations, set `tile.color = biome.color_grass`
   - For resources (trees/rocks), use tile definition color from TileManager

3. Modify `rendering/ascii_renderer.gd`
   - Create `_get_tile_color(tile: GameTile) -> Color` helper method
   - Priority: tile.color → TileManager definition → default fallback
   - Update `render_terrain()` to use this method
   - Remove hardcoded `default_terrain_colors` dictionary

4. Update `rendering/terrain_layer.gd` (if needed)
   - Ensure color modulation applies to TileMapLayer cells correctly

**Files Modified**:
- MODIFIED: `maps/game_tile.gd` (add color property)
- MODIFIED: `maps/world_chunk.gd` (store biome colors in tiles)
- MODIFIED: `rendering/ascii_renderer.gd` (use tile colors, remove hardcoded colors)
- MODIFIED: `rendering/terrain_layer.gd` (optional, if color application needs adjustment)

**Testing Checklist**:
- [ ] Grassland biomes render with green floor (not gray)
- [ ] Forest biomes render with darker green
- [ ] Tundra biomes render with tan/brown
- [ ] Snow biomes render with white
- [ ] Ocean biomes render with blue
- [ ] Trees still render with green color
- [ ] Rocks still render with gray color
- [ ] Colors persist across chunk load/unload
- [ ] Colors serialize/deserialize correctly in saves

**Expected Visual Changes**:
- **Before**: All overworld tiles are gray/white/generic
- **After**: Each biome has distinct color palette, realistic appearance

**Benefits**:
- ✅ Biome diversity visually apparent
- ✅ JSON color data actually used
- ✅ Completes data-driven rendering pipeline
- ✅ No more renderer hardcoded values

---

### Task 1.3: Remove Duplicate BiomeDefinition.gd (Legacy Code Cleanup)

**Assignee**: [Code Maintainer]
**Priority**: Medium
**Estimated Time**: 15 minutes
**Dependencies**: None (can be done anytime)

**Objective**: Delete unused legacy biome system to eliminate code duplication and confusion.

**Current Problem**:
Two biome systems exist:
1. `generation/biome_definition.gd` (82 lines, class-based, **NEVER USED**)
2. `autoload/biome_manager.gd` (193 lines, JSON-based, **ACTUALLY USED**)

**Evidence of Non-Use**:
```bash
# Search for BiomeDefinition usage
$ grep -r "BiomeDefinition" --include="*.gd"
generation/biome_definition.gd:class_name BiomeDefinition  # Definition only
# NO OTHER FILES REFERENCE IT
```

**Why It Exists**:
- Legacy implementation before data-driven refactor
- Was replaced by BiomeManager but never deleted
- Contains hardcoded if/else chains for biome selection

**Why It Must Go**:
- ❌ Violates DRY (Don't Repeat Yourself)
- ❌ Creates confusion about which system is authoritative
- ❌ Contains 50+ lines of hardcoded biome selection logic
- ❌ New developers might accidentally use it

**Implementation Steps**:

1. **Verify it's truly unused**:
   ```bash
   grep -r "BiomeDefinition" --include="*.gd" --exclude-dir=".git"
   grep -r "biome_definition" --include="*.gd" --exclude-dir=".git"
   ```

2. **Delete the file**:
   ```bash
   rm generation/biome_definition.gd
   ```

3. **Verify nothing breaks**:
   - Run the game
   - Generate new world
   - Confirm biomes still work
   - Check for any errors in console

**Files Modified**:
- DELETED: `generation/biome_definition.gd`

**Testing Checklist**:
- [ ] Game starts without errors
- [ ] New world generates successfully
- [ ] Biomes appear correctly (grassland, forest, ocean, etc.)
- [ ] No "biome_definition" references in console errors
- [ ] Grep confirms no code references BiomeDefinition class

**Benefits**:
- ✅ Eliminates code duplication
- ✅ Removes 82 lines of dead code
- ✅ Clarifies that BiomeManager is the single source of truth
- ✅ Prevents accidental use of legacy system

---

## Phase 2: Biome-Specific Resource & Enemy Population

**Goal**: Create rich, diverse biomes with appropriate flora, fauna, resources, and hazards. Each biome should feel unique and provide different gameplay opportunities.

**Current Spawn System Analysis**:

**Problems with Current Implementation**:
1. **Only 2 resource types spawn** (trees, rocks) - very limited
2. **Spawn logic hardcoded in WorldChunk.generate()** (`maps/world_chunk.gd:75-103`)
3. **No biome-specific resources** (iron ore should spawn in mountains, not oceans)
4. **No enemy spawning in chunks** (enemies only spawn in dungeons)
5. **No flora variety** (no mushrooms, herbs, flowers, berries)
6. **No biome hazards** (no poisonous plants, dangerous terrain)

**Current Hardcoded Spawn Logic**:
```gdscript
// maps/world_chunk.gd:82-94
if rng.randf() < blended_data.tree_density:
    var resource_instance = ResourceSpawner.ResourceInstance.new("tree", world_pos, chunk_coords)
    resources.append(resource_instance)
    tile.ascii_char = "T"  # HARDCODED

if rng.randf() < blended_data.rock_density:
    var resource_instance = ResourceSpawner.ResourceInstance.new("rock", world_pos, chunk_coords)
    resources.append(resource_instance)
    tile.ascii_char = "◆"  # HARDCODED
```

**Data-Driven Solution**:

Move spawn definitions from code to biome JSON:
```json
{
  "id": "grassland",
  "spawnable_resources": [
    {"id": "wheat", "density": 0.08, "clustering": 0.6},
    {"id": "berry_bush", "density": 0.02, "clustering": 0.4},
    {"id": "herb_patch", "density": 0.05, "clustering": 0.3}
  ],
  "spawnable_flora": [
    {"id": "wildflower", "density": 0.15, "clustering": 0.2},
    {"id": "tall_grass", "density": 0.25, "clustering": 0.5}
  ],
  "spawnable_creatures": [
    {"id": "rabbit", "density": 0.01, "max_per_chunk": 2},
    {"id": "deer", "density": 0.005, "max_per_chunk": 1}
  ]
}
```

---

### Task 2.1: Expand Biome JSON Schema with Spawn Data

**Assignee**: [Data Designer]
**Priority**: High
**Estimated Time**: 2 hours
**Dependencies**: None

**Objective**: Define spawnable resources, flora, and creatures for all 15 biomes in JSON format.

**New Biome Schema**:

```json
{
  "id": "biome_id",
  "name": "Display Name",

  // Existing properties
  "base_tile": "floor",
  "grass_char": "\"",
  "color_floor": [0.4, 0.6, 0.3],
  "color_grass": [0.5, 0.7, 0.4],

  // NEW: Spawnable resources (harvestable)
  "spawnable_resources": [
    {
      "id": "resource_id",
      "density": 0.05,           // Spawn probability per tile (0-1)
      "clustering": 0.6,         // Clustering factor (0=random, 1=highly clustered)
      "elevation_min": 0.0,      // Optional elevation constraints
      "elevation_max": 1.0,
      "moisture_min": 0.0,       // Optional moisture constraints
      "moisture_max": 1.0
    }
  ],

  // NEW: Decorative flora (non-harvestable, visual only)
  "spawnable_flora": [
    {
      "id": "flora_id",
      "density": 0.15,
      "clustering": 0.2,
      "blocks_movement": false,  // Can walk through?
      "blocks_vision": false      // Can see through?
    }
  ],

  // NEW: Creatures (passive/hostile animals)
  "spawnable_creatures": [
    {
      "id": "creature_id",
      "density": 0.01,           // Spawn probability
      "max_per_chunk": 2,        // Limit population
      "min_distance_from_player": 10,  // Don't spawn too close
      "time_of_day": ["day", "dusk"]   // When they spawn
    }
  ],

  // NEW: Hazards (traps, dangerous terrain)
  "spawnable_hazards": [
    {
      "id": "hazard_id",
      "density": 0.005,
      "damage_type": "poison",
      "requires_perception": 5    // WIS check to notice
    }
  ],

  // DEPRECATED: Remove these (replaced by spawnable_resources)
  "tree_density": 0.05,  // DELETE
  "rock_density": 0.01   // DELETE
}
```

**Implementation Steps**:

1. **Define resource types** for each biome category:

   **Forest Biomes** (forest, woodland, rainforest):
   - Resources: tree, mushroom, herb_patch, berry_bush
   - Flora: fern, undergrowth, fallen_log
   - Creatures: deer, rabbit, squirrel, wolf (rare)

   **Grassland Biomes** (grassland, plains):
   - Resources: wheat, wildflower, herb_patch
   - Flora: tall_grass, thistle, wildflower
   - Creatures: rabbit, deer, prairie_dog

   **Mountain Biomes** (rocky_hills, mountains, snow_mountains):
   - Resources: iron_ore, rock, copper_ore, crystal
   - Flora: lichen, alpine_flower
   - Creatures: mountain_goat, eagle (ambient), bear (rare)

   **Ocean/Water Biomes** (ocean, deep_ocean, beach):
   - Resources: seaweed, shellfish, driftwood
   - Flora: kelp, coral (deep ocean)
   - Creatures: crab, seagull (ambient)

   **Wetland Biomes** (marsh, swamp):
   - Resources: reed, lily_pad, peat
   - Flora: cattail, moss, swamp_flower
   - Creatures: frog, snake, alligator (hostile, rare)
   - Hazards: quicksand, poisonous_gas_vent

   **Cold Biomes** (tundra, snow):
   - Resources: ice_chunk, frozen_berry_bush
   - Flora: ice_formation, snow_drift
   - Creatures: arctic_fox, wolf

   **Arid Biomes** (barren_rock, desert - if added):
   - Resources: cactus, dry_wood, salt_deposit
   - Flora: tumbleweed, dead_bush
   - Creatures: lizard, scorpion, vulture (ambient)

2. **Update all 15 existing biome JSON files** in `data/biomes/`
   - Add spawnable_resources array
   - Add spawnable_flora array
   - Add spawnable_creatures array
   - Add spawnable_hazards array (where appropriate)
   - Remove deprecated tree_density/rock_density

3. **Create new resource definition files** in `data/resources/`
   - mushroom.json, herb_patch.json, berry_bush.json
   - iron_ore.json (already exists), copper_ore.json, crystal.json
   - seaweed.json, reed.json, cactus.json
   - etc. (~20-30 new resource files)

4. **Create new flora definition files** in `data/flora/` (new directory)
   - Follow tile JSON schema from Task 1.1
   - wildflower.json, tall_grass.json, fern.json
   - lichen.json, moss.json, cattail.json
   - etc. (~15-20 flora files)

5. **Create new creature definition files** in `data/enemies/wildlife/` (new subdirectory)
   - rabbit.json, deer.json, wolf.json
   - mountain_goat.json, eagle.json, bear.json
   - crab.json, snake.json, alligator.json
   - etc. (~15-20 creature files)

**Files Modified**:
- MODIFIED: `data/biomes/*.json` (all 15 biome files)
- NEW: `data/resources/**/*.json` (~25 new resource files)
- NEW: `data/flora/**/*.json` (~20 new flora files)
- NEW: `data/enemies/wildlife/*.json` (~20 new creature files)
- NEW: `data/hazards/*.json` (optional, 5-10 hazard files)

**Data Validation**:
- [ ] All spawn densities sum to < 1.0 per biome (avoid overcrowding)
- [ ] Creature max_per_chunk values are reasonable
- [ ] Resource IDs reference valid resource definitions
- [ ] Creature IDs reference valid enemy definitions
- [ ] Elevation/moisture constraints make sense for biome

**Benefits**:
- ✅ Biomes feel unique and alive
- ✅ Player has location-based strategic decisions (where to gather what)
- ✅ Wildlife adds ambient life to world
- ✅ Data-driven spawning enables easy balancing
- ✅ Modders can create custom biomes easily

---

### Task 2.2: Refactor WorldChunk Spawn Logic to Use Biome Data

**Assignee**: [Gameplay Programmer]
**Priority**: High
**Estimated Time**: 2 hours
**Dependencies**: Task 2.1 (biome spawn data must exist)

**Objective**: Replace hardcoded tree/rock spawning with generic data-driven spawn system that reads from biome JSON.

**Current Spawn Code to Replace**:
```gdscript
// maps/world_chunk.gd:75-103 (DELETE THIS)
# Try to spawn tree
var blended_data = BiomeGenerator.get_blended_biome_data(world_pos.x, world_pos.y, world_seed)

if rng.randf() < blended_data.tree_density:
    var resource_instance = ResourceSpawner.ResourceInstance.new("tree", world_pos, chunk_coords)
    resources.append(resource_instance)
    tile.walkable = false
    tile.transparent = false
    tile.ascii_char = "T"  # HARDCODED
    tile.harvestable_resource_id = "tree"
    continue

# Try to spawn rock
if rng.randf() < blended_data.rock_density:
    var resource_instance = ResourceSpawner.ResourceInstance.new("rock", world_pos, chunk_coords)
    resources.append(resource_instance)
    tile.walkable = false
    tile.transparent = false
    tile.ascii_char = "◆"  # HARDCODED
    tile.harvestable_resource_id = "rock"
```

**New Data-Driven Spawn System**:

```gdscript
// maps/world_chunk.gd:generate()
func generate(world_seed: int) -> void:
    var rng = SeededRandom.new(seed)

    for local_y in range(CHUNK_SIZE):
        for local_x in range(CHUNK_SIZE):
            var world_pos = chunk_to_world_position(Vector2i(local_x, local_y))
            var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

            # Create base tile
            var tile = GameTile.create(biome.base_tile)
            tile.color = biome.color_floor
            tiles[Vector2i(local_x, local_y)] = tile

            # Skip spawning in special areas (town, dungeon entrance)
            if _is_special_area(world_pos):
                continue

            # NEW: Data-driven spawning
            if tile.walkable:
                _spawn_biome_content(world_pos, biome, rng, tile)
```

**New Helper Method**:

```gdscript
func _spawn_biome_content(world_pos: Vector2i, biome: Dictionary, rng: SeededRandom, tile: GameTile) -> void:
    # Get biome definition from BiomeManager
    var biome_id = biome.biome_name
    var biome_def = BiomeManager.get_biome(biome_id)

    # 1. Spawn resources (harvestable)
    if biome_def.has("spawnable_resources"):
        for spawn_data in biome_def.spawnable_resources:
            if _should_spawn(spawn_data, biome, rng):
                _spawn_resource(spawn_data.id, world_pos, tile)
                return  # Only one thing per tile

    # 2. Spawn flora (decorative)
    if biome_def.has("spawnable_flora"):
        for spawn_data in biome_def.spawnable_flora:
            if _should_spawn(spawn_data, biome, rng):
                _spawn_flora(spawn_data.id, world_pos, tile, spawn_data)
                return

    # 3. Spawn creatures (handled separately, not per-tile)
    # Creatures spawn at chunk level, not tile level
```

**Spawn Decision Logic**:

```gdscript
func _should_spawn(spawn_data: Dictionary, biome: Dictionary, rng: SeededRandom) -> bool:
    # Base density check
    var density = spawn_data.get("density", 0.0)

    # Apply clustering (uses separate noise layer)
    if spawn_data.has("clustering"):
        var cluster_factor = _get_cluster_factor(world_pos, rng, spawn_data.clustering)
        density *= cluster_factor

    # Optional elevation constraints
    if spawn_data.has("elevation_min") or spawn_data.has("elevation_max"):
        var elevation = biome.get("elevation", 0.5)
        if elevation < spawn_data.get("elevation_min", 0.0):
            return false
        if elevation > spawn_data.get("elevation_max", 1.0):
            return false

    # Optional moisture constraints
    if spawn_data.has("moisture_min") or spawn_data.has("moisture_max"):
        var moisture = biome.get("moisture", 0.5)
        if moisture < spawn_data.get("moisture_min", 0.0):
            return false
        if moisture > spawn_data.get("moisture_max", 1.0):
            return false

    return rng.randf() < density
```

**Resource Spawning**:

```gdscript
func _spawn_resource(resource_id: String, world_pos: Vector2i, tile: GameTile) -> void:
    # Get resource definition from HarvestSystem
    var resource_def = HarvestSystem.resources.get(resource_id)
    if not resource_def:
        push_warning("Unknown resource: " + resource_id)
        return

    # Create resource instance
    var resource_instance = ResourceSpawner.ResourceInstance.new(resource_id, world_pos, chunk_coords)
    resources.append(resource_instance)

    # Get tile appearance from TileManager (not hardcoded!)
    var tile_def = TileManager.get_tile_definition(resource_id)
    tile.ascii_char = tile_def.get("ascii_char", "?")
    tile.color = Color(tile_def.color[0], tile_def.color[1], tile_def.color[2])
    tile.walkable = tile_def.get("walkable", false)
    tile.transparent = tile_def.get("transparent", false)
    tile.harvestable_resource_id = resource_id
```

**Flora Spawning**:

```gdscript
func _spawn_flora(flora_id: String, world_pos: Vector2i, tile: GameTile, spawn_data: Dictionary) -> void:
    # Flora doesn't create resource instances, just visual tiles
    var tile_def = TileManager.get_tile_definition(flora_id)

    tile.ascii_char = tile_def.get("ascii_char", "*")
    tile.color = Color(tile_def.color[0], tile_def.color[1], tile_def.color[2])
    tile.walkable = spawn_data.get("blocks_movement", false) == false
    tile.transparent = spawn_data.get("blocks_vision", false) == false
```

**Creature Spawning (Chunk-Level)**:

```gdscript
# Called after tile generation completes
func _spawn_creatures(biome_def: Dictionary, player_pos: Vector2i) -> void:
    if not biome_def.has("spawnable_creatures"):
        return

    for spawn_data in biome_def.spawnable_creatures:
        var density = spawn_data.get("density", 0.0)
        var max_count = spawn_data.get("max_per_chunk", 1)
        var min_distance = spawn_data.get("min_distance_from_player", 10)

        # Check time of day filter
        var time_filter = spawn_data.get("time_of_day", [])
        if time_filter.size() > 0 and not TurnManager.time_of_day in time_filter:
            continue

        # Spawn attempts
        var spawn_count = 0
        for attempt in range(max_count * 3):  # 3x attempts to account for failures
            if spawn_count >= max_count:
                break

            if rng.randf() < density:
                # Find random walkable tile
                var spawn_pos = _find_random_walkable_position(rng)
                if spawn_pos == Vector2i(-1, -1):
                    continue

                # Check distance from player
                if spawn_pos.distance_to(player_pos) < min_distance:
                    continue

                # Spawn creature via EntityManager
                var world_spawn_pos = chunk_to_world_position(spawn_pos)
                EntityManager.spawn_enemy(spawn_data.id, world_spawn_pos)
                spawn_count += 1
```

**Implementation Steps**:

1. **Create helper methods** in `maps/world_chunk.gd`:
   - `_spawn_biome_content()` - Main spawn coordinator
   - `_should_spawn()` - Density check with constraints
   - `_spawn_resource()` - Create harvestable resource
   - `_spawn_flora()` - Create decorative flora
   - `_spawn_creatures()` - Spawn wildlife
   - `_get_cluster_factor()` - Clustering noise calculation
   - `_find_random_walkable_position()` - Helper for creature spawn
   - `_is_special_area()` - Check for town/dungeon override

2. **Modify `generate()` method**:
   - Replace hardcoded tree/rock spawning
   - Call `_spawn_biome_content()` for each tile
   - Call `_spawn_creatures()` after tile generation

3. **Update BiomeGenerator** to include elevation/moisture in returned data:
   ```gdscript
   return {
       "biome_name": biome_id,
       "elevation": elevation,  // NEW
       "moisture": moisture,    // NEW
       "color_floor": ...,
       // ...
   }
   ```

4. **Remove deprecated biome properties** from BiomeGenerator:
   - Delete tree_density usage
   - Delete rock_density usage
   - These are now in biome JSON spawnable_resources

**Files Modified**:
- MODIFIED: `maps/world_chunk.gd` (refactor spawn logic, add helper methods)
- MODIFIED: `generation/biome_generator.gd` (return elevation/moisture data)
- MODIFIED: `data/biomes/*.json` (remove tree_density/rock_density)

**Testing Checklist**:
- [ ] Grassland spawns wheat, wildflowers, and rabbits
- [ ] Forest spawns trees, mushrooms, and deer
- [ ] Mountains spawn rocks, iron ore, and mountain goats
- [ ] Ocean spawns seaweed (not trees)
- [ ] Swamp spawns reeds, cattails, and snakes
- [ ] Creatures don't spawn within 10 tiles of player
- [ ] Resources cluster naturally (not uniform distribution)
- [ ] Elevation constraints work (ore only at high elevation)
- [ ] Time of day filters work (nocturnal creatures at night)
- [ ] Flora is walkable/transparent based on spawn data

**Benefits**:
- ✅ Eliminates all hardcoded spawn logic
- ✅ Biomes spawn appropriate content automatically
- ✅ Easy to add new resources without code changes
- ✅ Clustering creates realistic resource distribution
- ✅ Constraint system enables fine-tuned spawning

---

## Phase 3: Realistic Terrain Features

**Goal**: Add natural terrain features (rivers, roads, elevation rendering, resource clustering) to create a believable, varied world.

**Current Limitations**:
- Flat appearance (no visual elevation despite elevation noise)
- No water flow (rivers, streams)
- No paths connecting locations (town to dungeon)
- Resources spawn uniformly (unrealistic distribution)

---

### Task 3.1: Implement Resource Clustering System

**Assignee**: [Procedural Generation Engineer]
**Priority**: Medium
**Estimated Time**: 1.5 hours
**Dependencies**: Task 2.2 (biome spawn system)

**Objective**: Make resources spawn in natural clusters (tree groves, rock formations, ore veins) instead of uniform scatter.

**Current Problem**:
```
UNIFORM (current):    CLUSTERED (realistic):
T . . T . . .         . . . T T . .
. . T . . . .    →    . . T T T . .
. T . . . T .         . . . T . . .
```

**Solution**: Use cluster noise layer to modulate spawn density.

**Cluster Noise Implementation**:

```gdscript
// maps/world_chunk.gd

# Static cluster noise cache (shared across all chunks)
static var cluster_noise_cache: Dictionary = {}

static func _get_cluster_noise(seed: int) -> FastNoiseLite:
    if not cluster_noise_cache.has(seed):
        var noise = FastNoiseLite.new()
        noise.seed = seed + 9999  # Offset from elevation/moisture
        noise.noise_type = FastNoiseLite.TYPE_CELLULAR
        noise.frequency = 0.08  # Larger features than biome noise
        noise.fractal_octaves = 2
        cluster_noise_cache[seed] = noise
    return cluster_noise_cache[seed]

func _get_cluster_factor(world_pos: Vector2i, seed: int, clustering: float) -> float:
    if clustering <= 0.0:
        return 1.0  # No clustering

    var noise = _get_cluster_noise(seed)
    var noise_value = noise.get_noise_2d(world_pos.x, world_pos.y)

    # Normalize to 0-1
    var normalized = (noise_value + 1.0) / 2.0

    # Apply clustering strength
    # clustering=1.0 → all-or-nothing (very clustered)
    # clustering=0.5 → moderate clustering
    # clustering=0.0 → no clustering (uniform)
    var threshold = 1.0 - clustering
    if normalized < threshold:
        return 0.0  # Suppressed
    else:
        return (normalized - threshold) / clustering * 3.0  # Boosted density in cluster
```

**Modified Spawn Logic**:

```gdscript
func _should_spawn(spawn_data: Dictionary, biome: Dictionary, rng: SeededRandom, world_pos: Vector2i, seed: int) -> bool:
    var density = spawn_data.get("density", 0.0)

    # Apply clustering
    if spawn_data.has("clustering"):
        var cluster_factor = _get_cluster_factor(world_pos, seed, spawn_data.clustering)
        density *= cluster_factor

    # ... elevation/moisture constraints

    return rng.randf() < density
```

**Clustering Config** (in biome JSON):
```json
{
  "spawnable_resources": [
    {
      "id": "tree",
      "density": 0.3,
      "clustering": 0.7  // Trees form groves
    },
    {
      "id": "iron_ore",
      "density": 0.1,
      "clustering": 0.9  // Ore in veins
    },
    {
      "id": "wildflower",
      "density": 0.15,
      "clustering": 0.3  // Flowers slightly clustered
    }
  ]
}
```

**Implementation Steps**:

1. Add static `cluster_noise_cache` to `maps/world_chunk.gd`
2. Implement `_get_cluster_noise()` method
3. Implement `_get_cluster_factor()` method
4. Modify `_should_spawn()` to accept `world_pos` and `seed` parameters
5. Apply cluster factor to density calculation
6. Test with different clustering values (0.0, 0.5, 1.0)

**Files Modified**:
- MODIFIED: `maps/world_chunk.gd` (add clustering logic)

**Testing Checklist**:
- [ ] Trees form visible groves in forests
- [ ] Iron ore appears in veins (not scattered)
- [ ] Wildflowers have mild clustering
- [ ] clustering=0.0 produces uniform distribution
- [ ] clustering=1.0 produces tight clusters
- [ ] Clusters are deterministic (same seed = same clusters)

**Benefits**:
- ✅ Realistic resource distribution
- ✅ Strategic gameplay (find the grove/vein)
- ✅ Visual variety in terrain
- ✅ Configurable per resource type

---

### Task 3.2: Add Elevation-Based Visual Rendering

**Assignee**: [Rendering Engineer]
**Priority**: Medium
**Estimated Time**: 1 hour
**Dependencies**: Task 1.2 (color pipeline), Task 2.2 (elevation data in biome)

**Objective**: Visually represent elevation using characters and color gradients, making mountains look tall and valleys look low.

**Current Problem**: Elevation is calculated but only used for biome selection. All tiles at same elevation look identical.

**Visual Representation Strategy**:

1. **Character Variation** (based on elevation)
2. **Color Tinting** (darken valleys, brighten peaks)
3. **Shadow Effect** (optional, slopes cast shadows)

**Elevation Rendering**:

```gdscript
// maps/game_tile.gd

var elevation: float = 0.5  // NEW: Store elevation (0-1)

func get_display_char() -> String:
    # Special tiles override elevation rendering
    if tile_type in ["water", "tree", "rock", "stairs_down"]:
        return ascii_char

    # Elevation-based characters for floor tiles
    if tile_type == "floor":
        if elevation > 0.85:
            return "▲"  # Mountain peak
        elif elevation > 0.7:
            return "∧"  # High mountain
        elif elevation > 0.55:
            return "^"  # Hill
        elif elevation < 0.3:
            return "v"  # Valley/depression
        else:
            return ascii_char  # Normal floor (grass char)

    return ascii_char

func get_display_color() -> Color:
    var base_color = color if color != Color(0, 0, 0) else Color(1, 1, 1)

    # Apply elevation tinting to floor tiles
    if tile_type == "floor":
        # Darken valleys
        if elevation < 0.3:
            base_color = base_color.darkened(0.2)
        # Brighten peaks
        elif elevation > 0.7:
            base_color = base_color.lightened(0.15)

    return base_color
```

**WorldChunk Integration**:

```gdscript
// maps/world_chunk.gd:generate()

for local_y in range(CHUNK_SIZE):
    for local_x in range(CHUNK_SIZE):
        var world_pos = chunk_to_world_position(Vector2i(local_x, local_y))
        var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

        var tile = GameTile.create(biome.base_tile)
        tile.color = biome.color_floor
        tile.elevation = biome.elevation  // NEW: Store elevation
        tiles[Vector2i(local_x, local_y)] = tile
```

**Renderer Update**:

```gdscript
// rendering/ascii_renderer.gd

func render_tile(tile: GameTile, position: Vector2i) -> void:
    var char = tile.get_display_char()  // Use dynamic char
    var color = tile.get_display_color()  // Use dynamic color

    terrain_layer.set_cell_char(position, char)
    terrain_layer.set_cell_color(position, color)
```

**Implementation Steps**:

1. Add `elevation: float` property to `maps/game_tile.gd`
2. Add `get_display_char()` method to GameTile
3. Add `get_display_color()` method to GameTile
4. Modify `maps/world_chunk.gd` to store elevation in tiles
5. Update `rendering/ascii_renderer.gd` to use dynamic char/color
6. Tune elevation thresholds for visual appeal

**Files Modified**:
- MODIFIED: `maps/game_tile.gd` (add elevation property and display methods)
- MODIFIED: `maps/world_chunk.gd` (store elevation)
- MODIFIED: `rendering/ascii_renderer.gd` (use dynamic rendering)

**Testing Checklist**:
- [ ] Mountains display "▲" peaks at high elevation
- [ ] Hills display "^" or "∧" characters
- [ ] Valleys display "v" character
- [ ] Flatlands use grass char (".", "\"", etc.)
- [ ] Peaks are brighter than surroundings
- [ ] Valleys are darker than surroundings
- [ ] Water/trees/rocks ignore elevation characters
- [ ] Minimap shows elevation variation

**Expected Visual Change**:
```
BEFORE:                AFTER:
" " " " " " " "        v v " " " ^ ▲
" " " " " " " "   →    v " " " ^ ^ ∧
" " " " " " " "        " " " " " ^ ^
```

**Benefits**:
- ✅ 3D-like appearance on 2D grid
- ✅ Terrain features visually obvious
- ✅ Navigation easier (see high/low ground)
- ✅ No performance cost (pure rendering)

---

### Task 3.3: Add River Generation System

**Assignee**: [Procedural Generation Engineer]
**Priority**: Medium
**Estimated Time**: 2.5 hours
**Dependencies**: Task 3.2 (elevation data in tiles)

**Objective**: Generate realistic rivers that flow from high elevation to low elevation, creating natural water networks.

**River Generation Algorithm**:

1. **Find river sources** (high elevation points)
2. **Trace downhill paths** using elevation gradient
3. **Widen rivers** based on distance from source
4. **Merge tributaries** when paths cross
5. **Terminate at ocean/lake** (low elevation or existing water)

**Implementation**:

```gdscript
// generation/river_generator.gd
class_name RiverGenerator

static func generate_rivers(map: GameMap, seed: int) -> void:
    var config = BiomeManager.get_world_config().get("rivers", {})
    var river_count = config.get("count", 3)
    var min_length = config.get("min_length", 50)

    var rng = SeededRandom.new(seed + 7777)  # Offset for river seed

    for i in range(river_count):
        var source = _find_river_source(map, rng, seed)
        if source != Vector2i(-1, -1):
            _trace_river(map, source, min_length, seed)

static func _find_river_source(map: GameMap, rng: SeededRandom, seed: int) -> Vector2i:
    # Search for high-elevation tiles (> 0.7) that are not already water
    var attempts = 100
    for attempt in range(attempts):
        var chunk_coords = Vector2i(
            rng.randi_range(-10, 10),
            rng.randi_range(-10, 10)
        )
        var world_pos = chunk_coords * 32 + Vector2i(16, 16)

        var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, seed)
        if biome.elevation > 0.7 and biome.base_tile != "water":
            return world_pos

    return Vector2i(-1, -1)  # No source found

static func _trace_river(map: GameMap, start: Vector2i, min_length: int, seed: int) -> void:
    var current = start
    var path: Array[Vector2i] = [start]
    var width = 1

    while path.size() < min_length * 3:  # Max 3x min_length
        # Find downhill neighbor
        var next = _find_downhill_neighbor(current, seed)
        if next == Vector2i(-1, -1):
            break  # Dead end (local minimum)

        # Check if reached ocean/existing water
        var tile = ChunkManager.get_tile(next)
        if tile.tile_type == "water":
            path.append(next)
            break  # River flows into existing water

        # Add to path
        path.append(next)
        current = next

        # Widen river as it flows (more water accumulates)
        if path.size() % 30 == 0:
            width += 1

    # Apply river to map (if long enough)
    if path.size() >= min_length:
        _carve_river(path, width)

static func _find_downhill_neighbor(pos: Vector2i, seed: int) -> Vector2i:
    var current_elevation = BiomeGenerator.get_biome_at(pos.x, pos.y, seed).elevation
    var best_neighbor = Vector2i(-1, -1)
    var lowest_elevation = current_elevation

    # Check 8 neighbors
    for dy in range(-1, 2):
        for dx in range(-1, 2):
            if dx == 0 and dy == 0:
                continue

            var neighbor = pos + Vector2i(dx, dy)
            var neighbor_biome = BiomeGenerator.get_biome_at(neighbor.x, neighbor.y, seed)

            if neighbor_biome.elevation < lowest_elevation:
                lowest_elevation = neighbor_biome.elevation
                best_neighbor = neighbor

    return best_neighbor

static func _carve_river(path: Array[Vector2i], width: int) -> void:
    for pos in path:
        # Carve main channel
        var tile = GameTile.create("water")
        ChunkManager.set_tile(pos, tile)

        # Carve width (simple circle around path point)
        if width > 1:
            for dy in range(-width + 1, width):
                for dx in range(-width + 1, width):
                    if dx * dx + dy * dy < width * width:  # Circle check
                        var river_pos = pos + Vector2i(dx, dy)
                        var river_tile = GameTile.create("water")
                        ChunkManager.set_tile(river_pos, river_tile)
```

**Config Addition** (`data/world_generation_config.json`):
```json
{
  "rivers": {
    "count": 3,
    "min_length": 50,
    "source_elevation_threshold": 0.7,
    "width_growth_rate": 1.0
  }
}
```

**Integration with MapManager**:

```gdscript
// autoload/map_manager.gd:get_or_generate_map()

# After chunks are generated
if map_id == "overworld":
    # Generate rivers
    RiverGenerator.generate_rivers(map, seed)

    # Generate roads (after rivers, so roads bridge rivers)
    RoadGenerator.generate_roads(map, seed)
```

**Implementation Steps**:

1. Create `generation/river_generator.gd`
2. Implement river source finding (high elevation search)
3. Implement downhill pathfinding
4. Implement river carving with width
5. Add river config to `data/world_generation_config.json`
6. Integrate with MapManager
7. Handle river/chunk interaction (rivers can span multiple chunks)

**Files Modified**:
- NEW: `generation/river_generator.gd`
- MODIFIED: `autoload/map_manager.gd` (call river generator)
- MODIFIED: `data/world_generation_config.json` (add river settings)

**Testing Checklist**:
- [ ] Rivers spawn at high elevations
- [ ] Rivers flow downhill consistently
- [ ] Rivers terminate at oceans or low points
- [ ] Rivers widen as they flow
- [ ] River count matches config
- [ ] Rivers don't spawn in impossible locations
- [ ] Rivers are deterministic (same seed = same rivers)

**Benefits**:
- ✅ Natural water features
- ✅ Strategic navigation (cross rivers, follow to ocean)
- ✅ Visual landmarks for orientation
- ✅ Realistic biome interactions

---

### Task 3.4: Add Road/Path Generation System

**Assignee**: [Procedural Generation Engineer]
**Priority**: Low
**Estimated Time**: 1.5 hours
**Dependencies**: Task 3.3 (rivers, for bridge logic)

**Objective**: Generate roads connecting town to dungeon entrance, clearing resources and creating navigation paths.

**Road Generation Algorithm**:

1. **A\* pathfinding** from town center to dungeon entrance
2. **Clear resources** along path (remove trees/rocks)
3. **Bridge rivers** where path crosses water
4. **Widen path** slightly (3-tile wide road)
5. **Mark tiles** with road character

**Implementation**:

```gdscript
// generation/road_generator.gd
class_name RoadGenerator

static func generate_roads(map: GameMap, seed: int) -> void:
    # Get special feature locations
    var town_center = map.get_meta("town_center", Vector2i(-1, -1))
    var dungeon_entrance = map.get_meta("dungeon_entrance", Vector2i(-1, -1))

    if town_center == Vector2i(-1, -1) or dungeon_entrance == Vector2i(-1, -1):
        return  # No road if locations missing

    # Generate path
    var path = _find_path(town_center, dungeon_entrance, seed)

    if path.size() > 0:
        _carve_road(path)

static func _find_path(start: Vector2i, goal: Vector2i, seed: int) -> Array[Vector2i]:
    # A* pathfinding
    var open_set: Array[Vector2i] = [start]
    var came_from: Dictionary = {}
    var g_score: Dictionary = {start: 0}
    var f_score: Dictionary = {start: start.distance_to(goal)}

    while open_set.size() > 0:
        # Find node with lowest f_score
        var current = _get_lowest_f_score(open_set, f_score)

        if current == goal:
            return _reconstruct_path(came_from, current)

        open_set.erase(current)

        # Check neighbors
        for neighbor in _get_neighbors(current):
            var tentative_g = g_score.get(current, INF) + _get_cost(current, neighbor, seed)

            if tentative_g < g_score.get(neighbor, INF):
                came_from[neighbor] = current
                g_score[neighbor] = tentative_g
                f_score[neighbor] = tentative_g + neighbor.distance_to(goal)

                if neighbor not in open_set:
                    open_set.append(neighbor)

    return []  # No path found

static func _get_cost(from: Vector2i, to: Vector2i, seed: int) -> float:
    var tile = ChunkManager.get_tile(to)

    # Base cost
    var cost = 1.0

    # Penalize water (expensive to bridge)
    if tile.tile_type == "water":
        cost += 10.0

    # Penalize non-walkable (expensive to clear)
    if not tile.walkable:
        cost += 3.0

    # Prefer flat terrain
    var biome = BiomeGenerator.get_biome_at(to.x, to.y, seed)
    cost += abs(biome.elevation - 0.5) * 2.0  # Prefer mid-elevation

    return cost

static func _carve_road(path: Array[Vector2i]) -> void:
    for pos in path:
        # Clear resources at this position
        _clear_tile(pos)

        # Widen road (3 tiles wide)
        for dy in [-1, 0, 1]:
            for dx in [-1, 0, 1]:
                if abs(dx) + abs(dy) <= 1:  # Cross pattern
                    var road_pos = pos + Vector2i(dx, dy)
                    _clear_tile(road_pos)

static func _clear_tile(pos: Vector2i) -> void:
    var tile = ChunkManager.get_tile(pos)

    # Don't modify water or special tiles
    if tile.tile_type in ["water", "stairs_down", "wall"]:
        return

    # Create road tile (or clear to floor)
    var road_tile = GameTile.create("road")  # New tile type
    road_tile.ascii_char = "·"  # Middle dot
    road_tile.color = Color(0.6, 0.5, 0.4)  # Brown/tan
    road_tile.walkable = true
    road_tile.transparent = true

    ChunkManager.set_tile(pos, road_tile)
```

**New Tile Definition** (`data/tiles/terrain/road.json`):
```json
{
  "id": "road",
  "name": "Road",
  "walkable": true,
  "transparent": true,
  "ascii_char": "·",
  "color": [0.6, 0.5, 0.4],
  "movement_cost": 0.5,
  "description": "A worn dirt road connecting settlements"
}
```

**Implementation Steps**:

1. Create `generation/road_generator.gd`
2. Implement A* pathfinding with terrain costs
3. Implement road carving with clearing logic
4. Create road tile definition JSON
5. Integrate with MapManager (call after river generation)
6. Test path quality (roads should look natural)

**Files Modified**:
- NEW: `generation/road_generator.gd`
- NEW: `data/tiles/terrain/road.json`
- MODIFIED: `autoload/map_manager.gd` (call road generator)

**Testing Checklist**:
- [ ] Road connects town to dungeon entrance
- [ ] Road clears trees and rocks along path
- [ ] Road avoids water when possible
- [ ] Road bridges water when necessary
- [ ] Road is 3 tiles wide
- [ ] Road uses "·" character
- [ ] Road is deterministic (same seed = same road)

**Benefits**:
- ✅ Clear navigation path
- ✅ Faster travel (no obstacles)
- ✅ Visual connection between locations
- ✅ Gameplay aid for new players

---

## Phase 4: Extensible Generation Architecture

**Goal**: Create a plugin-style architecture for terrain features that allows modders to add custom generators without modifying core code.

---

### Task 4.1: Create Feature Generator Interface & Registry

**Assignee**: [Software Architect]
**Priority**: Low
**Estimated Time**: 2 hours
**Dependencies**: Phase 3 complete (river/road generators exist)

**Objective**: Establish a plugin-style system for terrain feature generation, enabling Open/Closed Principle compliance and mod support.

**Architecture Pattern**: Strategy Pattern + Registry Pattern

**Base Interface**:

```gdscript
// generation/feature_generator.gd
class_name FeatureGenerator

## Base class for all terrain feature generators
## Subclass this to create custom generators (rivers, roads, structures, etc.)

## Priority determines generation order (lower = earlier)
## Example: Rivers=10, Roads=20 (roads come after rivers)
var priority: int = 50

## Called during world generation
## Implementations should modify the map in place
func generate(map: GameMap, seed: int) -> void:
    push_error("FeatureGenerator.generate() must be overridden")

## Optional: Check if this generator should run for this map
func should_generate(map: GameMap) -> bool:
    return true  # Default: always generate
```

**Concrete Implementations**:

```gdscript
// generation/river_generator.gd
extends FeatureGenerator
class_name RiverGenerator

func _init():
    priority = 10  # Generate early

func generate(map: GameMap, seed: int) -> void:
    # ... existing river generation code ...

func should_generate(map: GameMap) -> bool:
    return map.map_id == "overworld"  # Only in overworld


// generation/road_generator.gd
extends FeatureGenerator
class_name RoadGenerator

func _init():
    priority = 20  # After rivers

func generate(map: GameMap, seed: int) -> void:
    # ... existing road generation code ...

func should_generate(map: GameMap) -> bool:
    return map.map_id == "overworld"
```

**Feature Registry**:

```gdscript
// generation/feature_registry.gd
class_name FeatureRegistry

static var generators: Array[FeatureGenerator] = []
static var registered: bool = false

## Register built-in generators (called once on startup)
static func register_builtin_generators() -> void:
    if registered:
        return

    register(RiverGenerator.new())
    register(RoadGenerator.new())
    # Future: StructureGenerator, CaveGenerator, etc.

    registered = true

## Register a custom generator (for mods)
static func register(generator: FeatureGenerator) -> void:
    generators.append(generator)
    _sort_by_priority()

## Remove a generator by class name (for mods overriding defaults)
static func unregister(generator_class: String) -> void:
    generators = generators.filter(func(g): return g.get_class() != generator_class)

## Generate all features for a map
static func generate_all(map: GameMap, seed: int) -> void:
    register_builtin_generators()

    for generator in generators:
        if generator.should_generate(map):
            generator.generate(map, seed)

static func _sort_by_priority() -> void:
    generators.sort_custom(func(a, b): return a.priority < b.priority)
```

**MapManager Integration**:

```gdscript
// autoload/map_manager.gd

func get_or_generate_map(map_id: String) -> GameMap:
    # ... existing chunk/biome generation ...

    # NEW: Apply all registered feature generators
    if map_id == "overworld":
        FeatureRegistry.generate_all(map, seed)

    return map
```

**Implementation Steps**:

1. Create `generation/feature_generator.gd` base class
2. Refactor `generation/river_generator.gd` to extend FeatureGenerator
3. Refactor `generation/road_generator.gd` to extend FeatureGenerator
4. Create `generation/feature_registry.gd`
5. Update `autoload/map_manager.gd` to use registry
6. Document how mods can register custom generators

**Mod Example** (hypothetical):

```gdscript
// mods/volcanic_features/volcano_generator.gd
extends FeatureGenerator
class_name VolcanoGenerator

func _init():
    priority = 15  # After rivers, before roads

func generate(map: GameMap, seed: int) -> void:
    # Spawn volcanoes at high elevation in specific biomes
    # ...

func should_generate(map: GameMap) -> bool:
    return map.map_id == "overworld"

// mods/volcanic_features/mod_init.gd
func _ready():
    FeatureRegistry.register(VolcanoGenerator.new())
```

**Files Modified**:
- NEW: `generation/feature_generator.gd` (base class)
- NEW: `generation/feature_registry.gd` (registry system)
- MODIFIED: `generation/river_generator.gd` (extend FeatureGenerator)
- MODIFIED: `generation/road_generator.gd` (extend FeatureGenerator)
- MODIFIED: `autoload/map_manager.gd` (use registry instead of direct calls)

**Testing Checklist**:
- [ ] Rivers and roads still generate correctly
- [ ] Generation order is correct (rivers before roads)
- [ ] Registry.generate_all() calls all generators
- [ ] should_generate() filters correctly
- [ ] Custom generator can be registered at runtime
- [ ] Unregister works correctly

**Benefits**:
- ✅ Open/Closed Principle (add features without modifying core)
- ✅ Modding support (register custom generators)
- ✅ Priority-based ordering (control generation sequence)
- ✅ Conditional generation (filter by map type)
- ✅ Clean separation of concerns

---

## Summary & Metrics

### Total Implementation Time

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| **Phase 1: Data-Driven Architecture** | 3 tasks | 2.75 hours |
| **Phase 2: Biome Population** | 2 tasks | 5 hours |
| **Phase 3: Realistic Features** | 4 tasks | 7.5 hours |
| **Phase 4: Extensible Architecture** | 1 task | 2 hours |
| **Total** | 10 tasks | **17.25 hours** |

### Files Impact

**New Files**: ~85 files
- TileManager autoload
- 15+ tile JSON definitions
- 25+ new resource definitions
- 20+ flora definitions
- 20+ creature definitions
- RiverGenerator, RoadGenerator, FeatureRegistry classes

**Modified Files**: ~15 files
- BiomeManager, BiomeGenerator, WorldChunk
- GameTile, ASCIIRenderer, MapManager
- 15 existing biome JSONs (updated schema)

### Code Quality Improvements

**SOLID Principles**:
- ✅ Single Responsibility: TileManager, FeatureRegistry separation
- ✅ Open/Closed: JSON-driven tiles, feature generator plugins
- ✅ Dependency Inversion: Renderer uses tile abstraction, not hardcoded values

**DRY Violations Fixed**:
- ✅ Tile properties (was in 3 places, now 1)
- ✅ Resource appearance (was hardcoded, now in JSON)
- ✅ Biome definitions (deleted duplicate BiomeDefinition.gd)

**Data-Driven Coverage**:
- Before: ~60% (biomes, items, enemies in JSON)
- After: ~95% (tiles, spawns, features also in JSON)

### Player-Facing Improvements

**Visual**:
- Biomes have distinct colors (green forests, white snow, blue oceans)
- Elevation visible (peaks, valleys, hills)
- Rivers flow naturally
- Roads connect locations

**Gameplay**:
- Biome-specific resources (iron in mountains, fish in oceans)
- Wildlife adds ambient life (deer in forests, crabs on beaches)
- Clustering creates strategic resource hunting
- Roads provide navigation aid

**World Quality**:
- Feels hand-crafted despite being procedural
- Every biome unique and worth exploring
- Natural features create landmarks

---

## Implementation Order Recommendation

**Critical Path** (do first):
1. Task 1.1 - TileManager (blocks everything else)
2. Task 1.2 - Color pipeline fix (visual impact)
3. Task 2.1 - Biome spawn data (enables rich world)
4. Task 2.2 - Refactor spawn logic (apply spawn data)

**Enhancement Path** (do next):
5. Task 3.1 - Resource clustering (better feel)
6. Task 3.2 - Elevation rendering (visual depth)
7. Task 3.3 - Rivers (major feature)
8. Task 3.4 - Roads (navigation)

**Polish Path** (do last):
9. Task 1.3 - Delete BiomeDefinition.gd (cleanup)
10. Task 4.1 - Feature registry (modding support)

---

## Risk Assessment

### Low Risk
- Task 1.2 (color pipeline) - Simple data flow fix
- Task 1.3 (delete legacy code) - No dependencies
- Task 3.1 (clustering) - Additive feature
- Task 4.1 (registry) - Wrapper around existing code

### Medium Risk
- Task 1.1 (TileManager) - Large refactor, touches many files
- Task 3.2 (elevation rendering) - May need visual tuning
- Task 3.3 (rivers) - Complex algorithm, chunk interaction

### Mitigation Strategies
1. **Incremental Testing**: Test each task in isolation
2. **Fallback Values**: All new systems have sensible defaults
3. **Config Toggles**: Add enable/disable flags for new features
4. **Backward Compatibility**: Old save files still work (generate missing data)

---

## Future Enhancements (Not in Scope)

- **Temperature Noise Layer** (third biome dimension)
- **Seasonal Changes** (tiles change over time)
- **Weather System** (rain, snow based on biome)
- **Cave Networks** (underground rivers, ore veins)
- **Biome Transitions** (smooth blending at borders)
- **Dynamic Events** (forest fires, floods, earthquakes)
- **Player Terraforming** (dam rivers, clear forests, build roads)

---

**Status**: 📋 Plan Complete - Ready for Implementation
**Created**: 2026-01-01
**Plan Version**: 1.0

