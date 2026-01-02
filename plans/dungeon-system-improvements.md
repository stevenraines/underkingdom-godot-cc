# Dungeon System Improvements

## Overview

This plan transforms the dungeon generation system from hardcoded, single-type dungeons into a flexible, data-driven architecture supporting multiple dungeon types (caves, mines, compounds, towers, forts, ruins, barrows). The improvements maintain SOLID principles, enable modding, and provide unique gameplay experiences for each dungeon type.

## Current System Analysis

### Existing Implementation

**Current Dungeon System**:
- **Single Type**: Only burial barrows exist
- **Hardcoded Generator**: `generation/dungeon_generators/burial_barrow.gd`
- **Fixed Algorithm**: Rectangular rooms + corridors
- **Static Depth**: 50 floors hardcoded
- **No Variation**: All floors feel identical

**Current Generation Code** (`generation/dungeon_generators/burial_barrow.gd`):
```gdscript
static func generate_floor(world_seed: int, floor_number: int) -> GameMap:
    # Hardcoded 50×50 size
    var map = GameMap.new("dungeon_barrow_floor_%d" % floor_number, 50, 50)

    # Hardcoded room parameters
    var num_rooms = rng.randi_range(5, 8)
    var min_room_size = 3
    var max_room_size = 8

    # Hardcoded wall/floor tiles
    _fill_with_walls(map)
    _generate_rooms(map, num_rooms, min_room_size, max_room_size, rng)
    _connect_rooms(map, rooms)

    return map
```

### Critical Issues

1. **Hardcoded Dungeon Type**: Only barrows exist, no variety
2. **Fixed Generation Algorithm**: Rectangular rooms don't fit caves/towers/etc.
3. **No Data-Driven Config**: All parameters in code
4. **No Type-Specific Features**: No lava in mines, no traps in forts, etc.
5. **Uniform Difficulty**: No progression or specialization
6. **Single Aesthetic**: All dungeons look/feel the same

### Architecture Violations

1. **Open/Closed Principle**: Adding new dungeon type requires new .gd file
2. **Single Responsibility**: Generator does layout + enemies + items + features
3. **No Abstraction**: No base dungeon generator interface
4. **Hardcoded Metadata**: Depth, size, difficulty all in code

---

## Dungeon Type Analysis

### Dungeon Types to Support

#### 1. Burial Barrows (Existing)
**Theme**: Ancient tombs, undead guardians
**Layout**: Rectangular rooms connected by corridors
**Depth**: 10-20 floors
**Special Features**: Crypts, sarcophagi, treasure chambers
**Enemies**: Undead (wights, skeletons, ghosts)
**Hazards**: Curses, traps, collapsing floors
**Loot**: Ancient artifacts, gold, cursed items

#### 2. Natural Caves
**Theme**: Organic underground networks
**Layout**: Irregular caverns connected by winding passages (cellular automata)
**Depth**: 15-30 floors
**Special Features**: Underground lakes, stalactites/stalagmites, crystal formations
**Enemies**: Cave creatures (bats, spiders, oozes, cave bears)
**Hazards**: Pitfalls, dark zones (reduced visibility), unstable ground
**Loot**: Minerals, crystals, mushrooms, animal pelts

#### 3. Abandoned Mines
**Theme**: Dwarven/human mining operations
**Layout**: Grid-like tunnels with mining shafts, support beams
**Depth**: 20-40 floors
**Special Features**: Minecart tracks, ore veins, flooded sections, collapsed tunnels
**Enemies**: Miners-turned-monsters, earth elementals, giant insects
**Hazards**: Cave-ins, toxic gas, flooding, unstable supports
**Loot**: Ore (iron, copper, gold), mining tools, explosives

#### 4. Military Compounds
**Theme**: Active or abandoned military installations
**Layout**: Rectangular barracks, armories, training yards (grid-based)
**Depth**: 3-5 floors (wider, not deeper)
**Special Features**: Guard towers, weapon racks, prison cells, command centers
**Enemies**: Soldiers, guards, war machines, captains
**Hazards**: Patrols, alarm systems, locked doors, ballistas
**Loot**: Military equipment, armor, weapons, strategic maps

#### 5. Wizard Towers
**Theme**: Magical research facilities
**Layout**: Vertical tower (circular or square floors ascending)
**Depth**: 10-15 floors (going UP, not down)
**Special Features**: Laboratories, libraries, summoning circles, observatories
**Enemies**: Magical constructs, summoned creatures, rogue spells, wizards
**Hazards**: Magical traps, dimensional rifts, cursed items, wild magic zones
**Loot**: Spell scrolls, magical components, enchanted items, research notes

#### 6. Ancient Forts
**Theme**: Ruined defensive structures
**Layout**: Concentric walls, courtyards, keeps (fortress architecture)
**Depth**: 2-4 floors + underground dungeons
**Special Features**: Battlements, gatehouses, moats, siege equipment
**Enemies**: Bandits, deserters, monsters claiming territory
**Hazards**: Crumbling walls, arrow slits (environmental attacks), portcullises
**Loot**: Ancient armor, siege weapons, treasure vaults, historical artifacts

#### 7. Temple Ruins
**Theme**: Forgotten religious sites
**Layout**: Symmetrical halls, sanctuaries, catacombs (sacred geometry)
**Depth**: 8-12 floors
**Special Features**: Altars, prayer halls, reliquaries, crypts
**Enemies**: Cultists, possessed statues, divine guardians, fallen priests
**Hazards**: Divine curses, holy/unholy auras, sanctified ground (affects undead)
**Loot**: Religious artifacts, blessed items, tithes, scripture

---

## Design Patterns for Each Type

### Generation Algorithm Mapping

| Dungeon Type | Algorithm | Key Parameters |
|-------------|-----------|----------------|
| **Burial Barrows** | Rectangular Rooms + Corridors | room_count, room_size_range, corridor_width |
| **Natural Caves** | Cellular Automata | birth_limit, death_limit, iteration_count, smoothing |
| **Abandoned Mines** | Grid Tunnels + Shafts | tunnel_spacing, shaft_frequency, support_density |
| **Military Compounds** | BSP (Binary Space Partition) | min_room_size, max_room_size, split_ratio |
| **Wizard Towers** | Circular/Square Floors | floor_radius, room_segments, spiral_stairs |
| **Ancient Forts** | Concentric Rings | wall_count, courtyard_size, keep_size |
| **Temple Ruins** | Symmetric Mirroring | symmetry_axis, chamber_count, hallway_width |

### Common Components Across All Types

**Every dungeon needs**:
1. **Entry Point**: Stairs up to overworld
2. **Exit Point**: Stairs down to next floor (or boss room)
3. **Connectivity**: All rooms reachable from entry
4. **Enemy Spawning**: Type-appropriate creatures
5. **Loot Placement**: Treasure in logical locations
6. **Special Features**: Type-specific elements

---

## Implementation Phases

### Phase 1: Data-Driven Dungeon Architecture (Critical)
**Goal**: Replace hardcoded burial barrow generator with flexible, JSON-driven system

**Estimated Time**: 4-5 hours
**Dependencies**: None
**Risk**: Medium (large refactor of existing system)

### Phase 2: Multi-Type Generation Algorithms
**Goal**: Implement generation algorithms for 7 dungeon types

**Estimated Time**: 8-10 hours
**Dependencies**: Phase 1 (dungeon framework)
**Risk**: High (complex algorithms, each type unique)

### Phase 3: Type-Specific Features & Hazards
**Goal**: Add unique elements to each dungeon type (traps, environmental effects, special rooms)

**Estimated Time**: 5-6 hours
**Dependencies**: Phase 2 (dungeon types exist)
**Risk**: Medium (gameplay balance, testing required)

### Phase 4: Dungeon Registry & Discovery
**Goal**: Overworld integration, dungeon discovery system, boss encounters

**Estimated Time**: 3-4 hours
**Dependencies**: Phase 3 (complete dungeons)
**Risk**: Low (wrapper around existing systems)

**Total Estimated Time**: 20-25 hours

---

## Phase 1: Data-Driven Dungeon Architecture

### Task 1.1: Create Dungeon Definition Schema & JSON Files

**Assignee**: [Data Designer]
**Priority**: Critical
**Estimated Time**: 2 hours
**Dependencies**: None

**Objective**: Define comprehensive JSON schema for dungeon types and create definition files for all 7 types.

**Dungeon Definition Schema**:

```json
{
  "id": "burial_barrow",
  "name": "Burial Barrow",
  "description": "An ancient tomb filled with restless undead",

  // Map Properties
  "map_size": {
    "width": 50,
    "height": 50
  },
  "floor_count": {
    "min": 10,
    "max": 20
  },

  // Generation Algorithm
  "generator_type": "rectangular_rooms",  // References algorithm
  "generation_params": {
    "room_count_range": [5, 8],
    "room_size_range": [3, 8],
    "corridor_width": 1,
    "connectivity": 0.7  // 70% rooms connected
  },

  // Visual Theme
  "tiles": {
    "wall": "stone_wall",
    "floor": "stone_floor",
    "door": "wooden_door"
  },
  "lighting": {
    "base_visibility": 0.3,  // Dark dungeons
    "torch_radius": 5
  },

  // Spawnable Content
  "enemy_pools": [
    {
      "enemy_id": "skeleton",
      "weight": 0.4,
      "floor_range": [1, 10]
    },
    {
      "enemy_id": "wight",
      "weight": 0.3,
      "floor_range": [5, 20]
    },
    {
      "enemy_id": "barrow_lord",  // Boss
      "weight": 1.0,
      "floor_range": [20, 20],
      "max_per_floor": 1
    }
  ],

  "loot_tables": [
    {
      "item_id": "ancient_gold",
      "chance": 0.3,
      "count_range": [10, 50]
    },
    {
      "item_id": "cursed_sword",
      "chance": 0.05,
      "count_range": [1, 1]
    }
  ],

  // Special Features
  "room_features": [
    {
      "feature_id": "sarcophagus",
      "spawn_chance": 0.2,
      "room_types": ["large", "end"]
    },
    {
      "feature_id": "treasure_chest",
      "spawn_chance": 0.15,
      "room_types": ["end"]
    }
  ],

  "hazards": [
    {
      "hazard_id": "floor_trap",
      "density": 0.05,
      "damage": 10
    },
    {
      "hazard_id": "curse_zone",
      "density": 0.02,
      "effect": "stat_drain"
    }
  ],

  // Difficulty Scaling
  "difficulty_curve": {
    "enemy_level_multiplier": 1.0,  // Floor * multiplier
    "enemy_count_base": 3,
    "enemy_count_per_floor": 0.5,
    "loot_quality_multiplier": 1.2
  }
}
```

**Implementation Steps**:

1. **Create dungeon definition directory**: `data/dungeons/`

2. **Create JSON file for each type**:
   - `data/dungeons/burial_barrow.json` (existing type, refactored)
   - `data/dungeons/natural_cave.json`
   - `data/dungeons/abandoned_mine.json`
   - `data/dungeons/military_compound.json`
   - `data/dungeons/wizard_tower.json`
   - `data/dungeons/ancient_fort.json`
   - `data/dungeons/temple_ruins.json`

3. **Define algorithm-specific parameters** for each:

   **Burial Barrow** (rectangular_rooms):
   ```json
   "generation_params": {
     "room_count_range": [5, 8],
     "room_size_range": [3, 8],
     "corridor_width": 1
   }
   ```

   **Natural Cave** (cellular_automata):
   ```json
   "generation_params": {
     "fill_probability": 0.45,
     "birth_limit": 4,
     "death_limit": 3,
     "iteration_count": 5,
     "smoothing_passes": 2
   }
   ```

   **Abandoned Mine** (grid_tunnels):
   ```json
   "generation_params": {
     "tunnel_spacing": 5,
     "shaft_frequency": 0.2,
     "support_beam_density": 0.3,
     "ore_vein_count": 3
   }
   ```

   **Military Compound** (bsp_rooms):
   ```json
   "generation_params": {
     "min_room_size": 5,
     "max_room_size": 12,
     "split_ratio": 0.5,
     "courtyard_chance": 0.3
   }
   ```

   **Wizard Tower** (circular_floors):
   ```json
   "generation_params": {
     "floor_radius": 12,
     "room_segments": 6,
     "spiral_staircase": true,
     "lab_room_chance": 0.4
   }
   ```

   **Ancient Fort** (concentric_rings):
   ```json
   "generation_params": {
     "wall_count": 3,
     "courtyard_size": 15,
     "keep_size": 8,
     "gatehouse_positions": 4
   }
   ```

   **Temple Ruins** (symmetric_layout):
   ```json
   "generation_params": {
     "symmetry_axis": "both",  // horizontal, vertical, both
     "chamber_count": 4,
     "hallway_width": 3,
     "sanctum_size": 10
   }
   ```

4. **Define enemy pools for each dungeon**:
   - Burial Barrow: Undead (skeletons, wights, ghosts)
   - Natural Cave: Cave creatures (bats, spiders, oozes)
   - Abandoned Mine: Corrupted miners, earth elementals
   - Military Compound: Soldiers, guards, war machines
   - Wizard Tower: Magical constructs, summoned demons
   - Ancient Fort: Bandits, deserters, ogres
   - Temple Ruins: Cultists, possessed statues, divine guardians

5. **Define loot tables for each**:
   - Match theme (barrows = ancient gold, mines = ore, towers = scrolls)

6. **Define special features**:
   - Sarcophagi in barrows
   - Crystal formations in caves
   - Minecart tracks in mines
   - Summoning circles in towers

**Files Created**:
- NEW: `data/dungeons/burial_barrow.json`
- NEW: `data/dungeons/natural_cave.json`
- NEW: `data/dungeons/abandoned_mine.json`
- NEW: `data/dungeons/military_compound.json`
- NEW: `data/dungeons/wizard_tower.json`
- NEW: `data/dungeons/ancient_fort.json`
- NEW: `data/dungeons/temple_ruins.json`

**Data Validation Checklist**:
- [ ] All generator_type values reference valid algorithms
- [ ] Enemy IDs reference existing enemy definitions
- [ ] Item IDs reference existing item definitions
- [ ] Tile IDs will reference TileManager (from terrain plan Task 1.1)
- [ ] floor_count min <= max
- [ ] Difficulty curves are reasonable (not exponential)
- [ ] Hazard densities sum to < 0.5 (avoid overcrowding)

**Benefits**:
- ✅ Dungeon types defined in data, not code
- ✅ Easy to add new dungeon types (just add JSON)
- ✅ Balancing via config files
- ✅ Modders can create custom dungeons

---

### Task 1.2: Create DungeonManager Autoload

**Assignee**: [Backend Developer]
**Priority**: Critical
**Estimated Time**: 1.5 hours
**Dependencies**: Task 1.1 (dungeon JSON files exist)

**Objective**: Create autoload singleton to load and manage dungeon definitions from JSON files.

**DungeonManager Implementation**:

```gdscript
// autoload/dungeon_manager.gd
extends Node
class_name DungeonManager

const DUNGEON_DATA_PATH = "res://data/dungeons"

var dungeon_definitions: Dictionary = {}  # id -> dungeon data
var loaded: bool = false

func _ready() -> void:
    load_dungeon_definitions()

## Load all dungeon definitions from JSON files
func load_dungeon_definitions() -> void:
    if loaded:
        return

    var dir = DirAccess.open(DUNGEON_DATA_PATH)
    if not dir:
        push_error("Failed to open dungeon data directory: " + DUNGEON_DATA_PATH)
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()

    while file_name != "":
        if file_name.ends_with(".json"):
            var file_path = DUNGEON_DATA_PATH + "/" + file_name
            _load_dungeon_file(file_path)
        file_name = dir.get_next()

    dir.list_dir_end()
    loaded = true
    print("[DungeonManager] Loaded %d dungeon types" % dungeon_definitions.size())

func _load_dungeon_file(file_path: String) -> void:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        push_error("Failed to open dungeon file: " + file_path)
        return

    var json = JSON.new()
    var error = json.parse(file.get_as_text())

    if error != OK:
        push_error("JSON parse error in %s: %s" % [file_path, json.get_error_message()])
        return

    var data = json.data
    if not data.has("id"):
        push_error("Dungeon definition missing 'id' field: " + file_path)
        return

    dungeon_definitions[data["id"]] = data
    print("[DungeonManager] Loaded dungeon type: %s" % data["id"])

## Get dungeon definition by ID
func get_dungeon(dungeon_id: String) -> Dictionary:
    if not dungeon_definitions.has(dungeon_id):
        push_warning("Unknown dungeon type: " + dungeon_id)
        return _get_fallback_definition()

    return dungeon_definitions[dungeon_id]

## Get all available dungeon types
func get_all_dungeon_types() -> Array[String]:
    var types: Array[String] = []
    for id in dungeon_definitions:
        types.append(id)
    return types

## Get random dungeon type (for procedural placement in overworld)
func get_random_dungeon_type(rng: SeededRandom) -> String:
    var types = get_all_dungeon_types()
    if types.size() == 0:
        return "burial_barrow"  # Fallback
    return types[rng.randi_range(0, types.size() - 1)]

## Get dungeon floor count (random within range)
func get_floor_count(dungeon_id: String, rng: SeededRandom) -> int:
    var def = get_dungeon(dungeon_id)
    var floor_count = def.get("floor_count", {"min": 10, "max": 20})
    return rng.randi_range(floor_count.min, floor_count.max)

## Get map size for dungeon type
func get_map_size(dungeon_id: String) -> Vector2i:
    var def = get_dungeon(dungeon_id)
    var size = def.get("map_size", {"width": 50, "height": 50})
    return Vector2i(size.width, size.height)

## Fallback definition (if JSON fails to load)
func _get_fallback_definition() -> Dictionary:
    return {
        "id": "unknown",
        "name": "Unknown Dungeon",
        "generator_type": "rectangular_rooms",
        "map_size": {"width": 50, "height": 50},
        "floor_count": {"min": 5, "max": 10},
        "generation_params": {
            "room_count_range": [5, 8],
            "room_size_range": [3, 8]
        },
        "tiles": {
            "wall": "stone_wall",
            "floor": "stone_floor"
        },
        "enemy_pools": [],
        "loot_tables": []
    }
```

**Integration Steps**:

1. Create `autoload/dungeon_manager.gd`
2. Register in `project.godot` autoload section:
   ```
   [autoload]
   DungeonManager="*res://autoload/dungeon_manager.gd"
   ```

3. **Modify MapManager** to use DungeonManager instead of hardcoded generator:
   ```gdscript
   // autoload/map_manager.gd

   func get_or_generate_map(map_id: String) -> GameMap:
       # ... existing cache check ...

       # NEW: Detect dungeon type from map_id
       if map_id.begins_with("dungeon_"):
           return _generate_dungeon_floor(map_id, seed)

       # ... existing overworld generation ...

   func _generate_dungeon_floor(map_id: String, seed: int) -> GameMap:
       # Parse map_id: "dungeon_burial_barrow_floor_5"
       var parts = map_id.split("_")
       var dungeon_type = parts[1]  # "burial", "cave", etc.
       var floor_number = int(parts[parts.size() - 1])

       # Get dungeon definition
       var dungeon_def = DungeonManager.get_dungeon(dungeon_type)

       # Delegate to appropriate generator
       var generator = DungeonGeneratorFactory.create(dungeon_def.generator_type)
       var map = generator.generate_floor(dungeon_def, floor_number, seed)

       return map
   ```

**Files Modified**:
- NEW: `autoload/dungeon_manager.gd`
- MODIFIED: `project.godot` (autoload registration)
- MODIFIED: `autoload/map_manager.gd` (use DungeonManager)

**Testing Checklist**:
- [ ] DungeonManager loads all 7 dungeon JSON files
- [ ] `get_dungeon("burial_barrow")` returns correct data
- [ ] `get_all_dungeon_types()` returns 7 types
- [ ] `get_random_dungeon_type()` is deterministic with same seed
- [ ] `get_floor_count()` returns value within min/max range
- [ ] Fallback definition works for unknown dungeon types
- [ ] MapManager correctly parses dungeon map_id

**Benefits**:
- ✅ Single source of truth for dungeon data
- ✅ Consistent with BiomeManager/ItemManager/EntityManager pattern
- ✅ Easy to query dungeon properties
- ✅ Supports runtime dungeon type queries

---

### Task 1.3: Create Generator Factory Pattern

**Assignee**: [Backend Developer]
**Priority**: Critical
**Estimated Time**: 1.5 hours
**Dependencies**: Task 1.2 (DungeonManager exists)

**Objective**: Implement factory pattern to instantiate appropriate dungeon generator based on `generator_type` from JSON.

**Generator Interface**:

```gdscript
// generation/dungeon_generators/base_dungeon_generator.gd
class_name BaseDungeonGenerator
extends RefCounted

## Base interface for all dungeon generators
## Each generator type implements generate_floor() differently

## Generate a single dungeon floor
## @param dungeon_def: Dictionary from DungeonManager (JSON data)
## @param floor_number: Current floor depth
## @param world_seed: Global world seed for determinism
## @returns: Generated GameMap
func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    push_error("BaseDungeonGenerator.generate_floor() must be overridden")
    return null

## Helper: Create floor seed from world seed + dungeon + floor
func _create_floor_seed(world_seed: int, dungeon_id: String, floor_number: int) -> int:
    var combined = "%s_%s_%d" % [world_seed, dungeon_id, floor_number]
    return combined.hash()

## Helper: Get generation parameters from dungeon definition
func _get_param(dungeon_def: Dictionary, key: String, default):
    return dungeon_def.get("generation_params", {}).get(key, default)
```

**Generator Factory Implementation**:

```gdscript
// generation/dungeon_generator_factory.gd
class_name DungeonGeneratorFactory
extends RefCounted

## Factory for creating dungeon generators based on type string

static func create(generator_type: String) -> BaseDungeonGenerator:
    match generator_type:
        "rectangular_rooms":
            return RectangularRoomsGenerator.new()
        "cellular_automata":
            return CellularAutomataGenerator.new()
        "grid_tunnels":
            return GridTunnelsGenerator.new()
        "bsp_rooms":
            return BSPRoomsGenerator.new()
        "circular_floors":
            return CircularFloorsGenerator.new()
        "concentric_rings":
            return ConcentricRingsGenerator.new()
        "symmetric_layout":
            return SymmetricLayoutGenerator.new()
        _:
            push_warning("Unknown generator type: %s, using rectangular_rooms" % generator_type)
            return RectangularRoomsGenerator.new()

static func get_all_generator_types() -> Array[String]:
    return [
        "rectangular_rooms",
        "cellular_automata",
        "grid_tunnels",
        "bsp_rooms",
        "circular_floors",
        "concentric_rings",
        "symmetric_layout"
    ]
```

**MapManager Integration**:

```gdscript
// autoload/map_manager.gd (MODIFIED)

func get_or_generate_map(map_id: String) -> GameMap:
    # Check cache first
    if cached_maps.has(map_id):
        return cached_maps[map_id]

    var generated_map: GameMap = null

    # NEW: Detect dungeon maps
    if map_id.begins_with("dungeon_"):
        generated_map = _generate_dungeon_floor(map_id)
    elif map_id == "overworld":
        generated_map = WorldGenerator.generate_overworld(GameManager.world_seed)
    elif map_id == "town":
        generated_map = TownGenerator.generate_town(GameManager.world_seed)
    else:
        push_error("Unknown map type: " + map_id)
        return null

    # Cache and return
    cached_maps[map_id] = generated_map
    return generated_map

## NEW: Generate dungeon floor using factory pattern
func _generate_dungeon_floor(map_id: String) -> GameMap:
    # Parse map_id: "dungeon_burial_barrow_floor_5"
    var regex = RegEx.new()
    regex.compile("dungeon_([a-z_]+)_floor_(\\d+)")
    var result = regex.search(map_id)

    if not result:
        push_error("Invalid dungeon map_id format: " + map_id)
        return null

    var dungeon_type = result.get_string(1)  # "burial_barrow"
    var floor_number = int(result.get_string(2))  # 5

    # Get dungeon definition
    var dungeon_def = DungeonManager.get_dungeon(dungeon_type)

    # Create generator via factory
    var generator = DungeonGeneratorFactory.create(dungeon_def.generator_type)

    # Generate floor
    var floor_seed = _create_dungeon_seed(dungeon_type, floor_number)
    var map = generator.generate_floor(dungeon_def, floor_number, floor_seed)

    return map

func _create_dungeon_seed(dungeon_type: String, floor_number: int) -> int:
    var combined = "%s_%s_%d" % [GameManager.world_seed, dungeon_type, floor_number]
    return combined.hash()
```

**Files Created/Modified**:
- NEW: `generation/dungeon_generators/base_dungeon_generator.gd`
- NEW: `generation/dungeon_generator_factory.gd`
- MODIFIED: `autoload/map_manager.gd`

**Testing Checklist**:
- [ ] Factory creates correct generator for each type
- [ ] Unknown generator type returns fallback (rectangular_rooms)
- [ ] MapManager correctly parses dungeon map_id format
- [ ] Floor seed generation is deterministic
- [ ] Same floor_number + dungeon_type always produces same seed

**Benefits**:
- ✅ Open/Closed Principle: Add new generators without modifying factory
- ✅ Single Responsibility: Factory only creates, generators only generate
- ✅ Consistent interface for all generator types
- ✅ Easy to test each generator in isolation

---

### Task 1.4: Refactor Existing Burial Barrow Generator

**Assignee**: [Backend Developer]
**Priority**: High
**Estimated Time**: 1 hour
**Dependencies**: Task 1.3 (factory exists)

**Objective**: Refactor existing `burial_barrow.gd` generator to use new interface and JSON data.

**Current Code** (`generation/dungeon_generators/burial_barrow.gd`):
```gdscript
static func generate_floor(world_seed: int, floor_number: int) -> GameMap:
    # Hardcoded parameters
    var map = GameMap.new("dungeon_barrow_floor_%d" % floor_number, 50, 50)
    var num_rooms = rng.randi_range(5, 8)
    # ... rest of generation ...
```

**Refactored Code** (NEW: `generation/dungeon_generators/rectangular_rooms_generator.gd`):
```gdscript
// generation/dungeon_generators/rectangular_rooms_generator.gd
class_name RectangularRoomsGenerator
extends BaseDungeonGenerator

## Generates dungeons with rectangular rooms connected by corridors
## Used by: Burial Barrows, Military Compounds (when using rectangular layout)

func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    var dungeon_id = dungeon_def.get("id", "unknown")
    var map_size = dungeon_def.get("map_size", {"width": 50, "height": 50})

    # Create map
    var map_id = "dungeon_%s_floor_%d" % [dungeon_id, floor_number]
    var map = GameMap.new(map_id, map_size.width, map_size.height)

    # Create seeded RNG
    var floor_seed = _create_floor_seed(world_seed, dungeon_id, floor_number)
    var rng = SeededRandom.new(floor_seed)

    # Get parameters from JSON
    var room_count_range = _get_param(dungeon_def, "room_count_range", [5, 8])
    var room_size_range = _get_param(dungeon_def, "room_size_range", [3, 8])
    var corridor_width = _get_param(dungeon_def, "corridor_width", 1)
    var connectivity = _get_param(dungeon_def, "connectivity", 0.7)

    # Generate structure
    _fill_with_walls(map, dungeon_def)
    var rooms = _generate_rooms(map, rng, room_count_range, room_size_range)
    _connect_rooms(map, rooms, rng, corridor_width, connectivity)
    _add_stairs(map, rooms, rng)

    # Populate with content
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)
    _add_features(map, dungeon_def, rooms, rng)

    # Wall culling (remove inaccessible walls)
    _cull_inaccessible_walls(map)

    return map

func _fill_with_walls(map: GameMap, dungeon_def: Dictionary) -> void:
    var wall_tile = dungeon_def.get("tiles", {}).get("wall", "stone_wall")

    for x in range(map.width):
        for y in range(map.height):
            map.set_tile(x, y, TileManager.get_tile(wall_tile))

func _generate_rooms(map: GameMap, rng: SeededRandom, count_range: Array, size_range: Array) -> Array:
    var rooms = []
    var num_rooms = rng.randi_range(count_range[0], count_range[1])

    for i in range(num_rooms):
        var room = _try_place_room(map, rng, size_range)
        if room:
            rooms.append(room)

    return rooms

# ... additional helper methods ...
```

**Migration Steps**:

1. **Rename file**:
   - OLD: `generation/dungeon_generators/burial_barrow.gd`
   - NEW: `generation/dungeon_generators/rectangular_rooms_generator.gd`

2. **Update class name**:
   - OLD: `class_name BurialBarrowGenerator`
   - NEW: `class_name RectangularRoomsGenerator`

3. **Change to instance method**:
   - OLD: `static func generate_floor(world_seed, floor_number)`
   - NEW: `func generate_floor(dungeon_def, floor_number, world_seed)`

4. **Replace hardcoded values with JSON parameters**:
   - Room count: `_get_param(dungeon_def, "room_count_range", [5, 8])`
   - Room size: `_get_param(dungeon_def, "room_size_range", [3, 8])`
   - Tiles: `dungeon_def.get("tiles", {}).get("wall", "stone_wall")`

5. **Add content population methods**:
   - `_spawn_enemies()` - uses `dungeon_def.enemy_pools`
   - `_spawn_loot()` - uses `dungeon_def.loot_tables`
   - `_add_features()` - uses `dungeon_def.room_features`

**Files Modified**:
- RENAMED: `burial_barrow.gd` → `rectangular_rooms_generator.gd`
- MODIFIED: Class implementation to use JSON data

**Testing Checklist**:
- [ ] Burial barrow dungeons generate identically to before (same seed)
- [ ] Room count respects JSON parameters
- [ ] Tile types come from JSON definition
- [ ] Enemies spawn according to enemy_pools
- [ ] Loot spawns according to loot_tables
- [ ] Connectivity parameter affects corridor generation

**Benefits**:
- ✅ Removes all hardcoded values
- ✅ Reusable for any rectangular room dungeon type
- ✅ Consistent with new architecture
- ✅ Backwards compatible (same generation for burial barrows)

---

## Phase 2: Multi-Type Generation Algorithms

### Task 2.1: Cellular Automata Generator (Natural Caves)

**Assignee**: [Procedural Generation Specialist]
**Priority**: High
**Estimated Time**: 1.5 hours
**Dependencies**: Phase 1 complete

**Objective**: Implement cellular automata algorithm for organic cave generation.

**Algorithm Overview**:
Cellular automata creates organic-looking caves by simulating natural erosion:
1. Fill map with random walls/floors based on `fill_probability`
2. For each cell, count neighboring walls
3. Apply rules: If neighbors >= `birth_limit`, cell becomes wall; if neighbors <= `death_limit`, cell becomes floor
4. Repeat for `iteration_count` iterations
5. Smooth with additional passes
6. Ensure connectivity via flood fill
7. Add stalagmites/stalactites as decorative walls

**Implementation**:

```gdscript
// generation/dungeon_generators/cellular_automata_generator.gd
class_name CellularAutomataGenerator
extends BaseDungeonGenerator

## Generates organic cave systems using cellular automata
## Used by: Natural Caves

func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    var dungeon_id = dungeon_def.get("id", "unknown")
    var map_size = dungeon_def.get("map_size", {"width": 50, "height": 50})
    var map_id = "dungeon_%s_floor_%d" % [dungeon_id, floor_number]
    var map = GameMap.new(map_id, map_size.width, map_size.height)

    var floor_seed = _create_floor_seed(world_seed, dungeon_id, floor_number)
    var rng = SeededRandom.new(floor_seed)

    # Get parameters
    var fill_prob = _get_param(dungeon_def, "fill_probability", 0.45)
    var birth_limit = _get_param(dungeon_def, "birth_limit", 4)
    var death_limit = _get_param(dungeon_def, "death_limit", 3)
    var iterations = _get_param(dungeon_def, "iteration_count", 5)
    var smoothing = _get_param(dungeon_def, "smoothing_passes", 2)

    # Generate cave
    _initialize_random_cells(map, dungeon_def, rng, fill_prob)
    _run_cellular_automata(map, iterations, birth_limit, death_limit)
    _smooth_caves(map, smoothing)
    _ensure_connectivity(map, dungeon_def)
    _add_cave_features(map, dungeon_def, rng)
    _add_stairs(map, rng)

    # Populate
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)

    return map

func _initialize_random_cells(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom, fill_prob: float) -> void:
    var wall_tile = dungeon_def.get("tiles", {}).get("wall", "cave_wall")
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "cave_floor")

    for x in range(map.width):
        for y in range(map.height):
            # Edge is always wall
            if x == 0 or x == map.width - 1 or y == 0 or y == map.height - 1:
                map.set_tile(x, y, TileManager.get_tile(wall_tile))
            else:
                var is_wall = rng.randf() < fill_prob
                var tile = wall_tile if is_wall else floor_tile
                map.set_tile(x, y, TileManager.get_tile(tile))

func _run_cellular_automata(map: GameMap, iterations: int, birth_limit: int, death_limit: int) -> void:
    for i in range(iterations):
        var new_tiles = []

        for x in range(1, map.width - 1):
            for y in range(1, map.height - 1):
                var wall_count = _count_adjacent_walls(map, x, y)
                var current_is_wall = not map.tiles[x][y].walkable

                var should_be_wall = false
                if current_is_wall:
                    should_be_wall = wall_count >= birth_limit
                else:
                    should_be_wall = wall_count >= death_limit

                new_tiles.append({"x": x, "y": y, "is_wall": should_be_wall})

        # Apply changes
        for tile_data in new_tiles:
            var tile_type = "cave_wall" if tile_data.is_wall else "cave_floor"
            map.set_tile(tile_data.x, tile_data.y, TileManager.get_tile(tile_type))

func _count_adjacent_walls(map: GameMap, x: int, y: int) -> int:
    var count = 0
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            if dx == 0 and dy == 0:
                continue
            var nx = x + dx
            var ny = y + dy
            if nx >= 0 and nx < map.width and ny >= 0 and ny < map.height:
                if not map.tiles[nx][ny].walkable:
                    count += 1
    return count

func _smooth_caves(map: GameMap, smoothing_passes: int) -> void:
    # Additional smoothing iterations with relaxed rules
    for i in range(smoothing_passes):
        _run_cellular_automata(map, 1, 5, 4)

func _ensure_connectivity(map: GameMap, dungeon_def: Dictionary) -> void:
    # Find all disconnected regions via flood fill
    var regions = _find_regions(map)

    if regions.size() <= 1:
        return  # Already connected

    # Connect largest regions with corridors
    var largest_region = regions[0]
    for i in range(1, regions.size()):
        _connect_regions(map, largest_region, regions[i], dungeon_def)

func _add_cave_features(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
    # Add stalagmites/stalactites as decorative blocking tiles
    var feature_density = 0.03  # 3% of floor tiles
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "cave_floor")

    for x in range(1, map.width - 1):
        for y in range(1, map.height - 1):
            if map.tiles[x][y].walkable and rng.randf() < feature_density:
                # Randomly place stalagmite or stalactite
                var feature = "stalagmite" if rng.randf() < 0.5 else "stalactite"
                map.set_tile(x, y, TileManager.get_tile(feature))

# ... additional helper methods ...
```

**Files Created**:
- NEW: `generation/dungeon_generators/cellular_automata_generator.gd`

**Testing Checklist**:
- [ ] Caves appear organic and irregular
- [ ] No isolated regions (all areas connected)
- [ ] Parameters affect cave density/openness
- [ ] Edge tiles are always walls
- [ ] Stalagmites/stalactites add visual interest

**Benefits**:
- ✅ Organic, natural-looking caves
- ✅ Highly configurable via parameters
- ✅ Deterministic with same seed
- ✅ Distinct from rectangular rooms

---

### Task 2.2: Grid Tunnels Generator (Abandoned Mines)

**Assignee**: [Procedural Generation Specialist]
**Priority**: High
**Estimated Time**: 1.5 hours
**Dependencies**: Phase 1 complete

**Objective**: Implement grid-based tunnel system for mining operations.

**Algorithm Overview**:
Creates structured mine tunnels reminiscent of real mining operations:
1. Fill map with walls
2. Create horizontal tunnels at regular intervals
3. Create vertical tunnels at regular intervals
4. Add mining shafts (vertical connections between levels)
5. Place support beams along tunnels
6. Add ore veins as special features
7. Occasionally collapse sections for variety

**Implementation**:

```gdscript
// generation/dungeon_generators/grid_tunnels_generator.gd
class_name GridTunnelsGenerator
extends BaseDungeonGenerator

## Generates grid-like mining tunnels with shafts
## Used by: Abandoned Mines

func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    var dungeon_id = dungeon_def.get("id", "unknown")
    var map_size = dungeon_def.get("map_size", {"width": 50, "height": 50})
    var map_id = "dungeon_%s_floor_%d" % [dungeon_id, floor_number]
    var map = GameMap.new(map_id, map_size.width, map_size.height)

    var floor_seed = _create_floor_seed(world_seed, dungeon_id, floor_number)
    var rng = SeededRandom.new(floor_seed)

    # Get parameters
    var tunnel_spacing = _get_param(dungeon_def, "tunnel_spacing", 5)
    var shaft_freq = _get_param(dungeon_def, "shaft_frequency", 0.2)
    var support_density = _get_param(dungeon_def, "support_beam_density", 0.3)
    var ore_vein_count = _get_param(dungeon_def, "ore_vein_count", 3)

    # Generate mine
    _fill_with_walls(map, dungeon_def)
    _carve_horizontal_tunnels(map, dungeon_def, tunnel_spacing)
    _carve_vertical_tunnels(map, dungeon_def, tunnel_spacing)
    _add_mining_shafts(map, dungeon_def, rng, shaft_freq)
    _place_support_beams(map, rng, support_density)
    _add_ore_veins(map, dungeon_def, rng, ore_vein_count)
    _add_collapsed_sections(map, dungeon_def, rng)
    _add_stairs(map, rng)

    # Populate
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)

    return map

func _carve_horizontal_tunnels(map: GameMap, dungeon_def: Dictionary, spacing: int) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "stone_floor")

    var y = spacing
    while y < map.height - spacing:
        for x in range(1, map.width - 1):
            map.set_tile(x, y, TileManager.get_tile(floor_tile))
            # Carve 3-wide tunnels
            if y > 0:
                map.set_tile(x, y - 1, TileManager.get_tile(floor_tile))
            if y < map.height - 1:
                map.set_tile(x, y + 1, TileManager.get_tile(floor_tile))

        y += spacing

func _carve_vertical_tunnels(map: GameMap, dungeon_def: Dictionary, spacing: int) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "stone_floor")

    var x = spacing
    while x < map.width - spacing:
        for y in range(1, map.height - 1):
            map.set_tile(x, y, TileManager.get_tile(floor_tile))
            # Carve 3-wide tunnels
            if x > 0:
                map.set_tile(x - 1, y, TileManager.get_tile(floor_tile))
            if x < map.width - 1:
                map.set_tile(x + 1, y, TileManager.get_tile(floor_tile))

        x += spacing

func _add_mining_shafts(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom, frequency: float) -> void:
    # Mining shafts are special tiles that connect vertically between floors
    var shaft_tile = "mining_shaft"  # Special tile type

    for x in range(5, map.width - 5, 10):
        for y in range(5, map.height - 5, 10):
            if rng.randf() < frequency:
                # Create 2×2 shaft area
                for dx in range(2):
                    for dy in range(2):
                        map.set_tile(x + dx, y + dy, TileManager.get_tile(shaft_tile))

func _place_support_beams(map: GameMap, rng: SeededRandom, density: float) -> void:
    # Support beams are non-walkable decorative elements along tunnels
    for x in range(1, map.width - 1):
        for y in range(1, map.height - 1):
            if map.tiles[x][y].walkable and rng.randf() < density:
                # Check if in tunnel (has walls on both sides)
                var has_horizontal_walls = (not map.tiles[x-1][y].walkable or not map.tiles[x+1][y].walkable)
                var has_vertical_walls = (not map.tiles[x][y-1].walkable or not map.tiles[x][y+1].walkable)

                if has_horizontal_walls or has_vertical_walls:
                    map.set_tile(x, y, TileManager.get_tile("support_beam"))

func _add_ore_veins(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom, count: int) -> void:
    # Ore veins are special harvestable wall tiles
    for i in range(count):
        var vein_x = rng.randi_range(5, map.width - 6)
        var vein_y = rng.randi_range(5, map.height - 6)
        var vein_size = rng.randi_range(3, 7)

        # Create irregular vein shape
        for j in range(vein_size):
            var ox = vein_x + rng.randi_range(-2, 2)
            var oy = vein_y + rng.randi_range(-2, 2)

            if ox > 0 and ox < map.width and oy > 0 and oy < map.height:
                if not map.tiles[ox][oy].walkable:  # Only replace walls
                    map.set_tile(ox, oy, TileManager.get_tile("iron_ore_vein"))

func _add_collapsed_sections(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
    # Randomly collapse some tunnel sections for variety
    var collapse_count = rng.randi_range(2, 5)

    for i in range(collapse_count):
        var cx = rng.randi_range(5, map.width - 6)
        var cy = rng.randi_range(5, map.height - 6)

        # Fill 3×3 area with rubble
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                var x = cx + dx
                var y = cy + dy
                if x > 0 and x < map.width and y > 0 and y < map.height:
                    map.set_tile(x, y, TileManager.get_tile("rubble"))

# ... additional helper methods ...
```

**Files Created**:
- NEW: `generation/dungeon_generators/grid_tunnels_generator.gd`

**Testing Checklist**:
- [ ] Tunnels form regular grid pattern
- [ ] Mining shafts appear at reasonable frequency
- [ ] Support beams align with tunnels
- [ ] Ore veins are harvestable
- [ ] Collapsed sections don't block all paths

**Benefits**:
- ✅ Structured, man-made appearance
- ✅ Distinct from organic caves
- ✅ Mining theme reinforced by features
- ✅ Harvestable resources (ore veins)

---

### Task 2.3: BSP Rooms Generator (Military Compounds)

**Assignee**: [Procedural Generation Specialist]
**Priority**: High
**Estimated Time**: 1.5 hours
**Dependencies**: Phase 1 complete

**Objective**: Implement Binary Space Partition algorithm for structured military layouts.

**Algorithm Overview**:
BSP creates organized room structures by recursively splitting space:
1. Start with entire map as single region
2. Recursively split region horizontally or vertically
3. Stop when regions reach minimum size
4. Convert leaf regions to rooms
5. Connect sibling rooms with corridors
6. Add doors at corridor entrances
7. Designate special rooms (armory, barracks, etc.)

**Implementation**:

```gdscript
// generation/dungeon_generators/bsp_rooms_generator.gd
class_name BSPRoomsGenerator
extends BaseDungeonGenerator

## Generates structured room layouts using Binary Space Partitioning
## Used by: Military Compounds

class BSPNode:
    var x: int
    var y: int
    var width: int
    var height: int
    var left_child: BSPNode = null
    var right_child: BSPNode = null
    var room: Rect2i = Rect2i()

    func _init(px: int, py: int, w: int, h: int):
        x = px
        y = py
        width = w
        height = h

    func is_leaf() -> bool:
        return left_child == null and right_child == null

func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    var dungeon_id = dungeon_def.get("id", "unknown")
    var map_size = dungeon_def.get("map_size", {"width": 50, "height": 50})
    var map_id = "dungeon_%s_floor_%d" % [dungeon_id, floor_number]
    var map = GameMap.new(map_id, map_size.width, map_size.height)

    var floor_seed = _create_floor_seed(world_seed, dungeon_id, floor_number)
    var rng = SeededRandom.new(floor_seed)

    # Get parameters
    var min_room_size = _get_param(dungeon_def, "min_room_size", 5)
    var max_room_size = _get_param(dungeon_def, "max_room_size", 12)
    var split_ratio = _get_param(dungeon_def, "split_ratio", 0.5)
    var courtyard_chance = _get_param(dungeon_def, "courtyard_chance", 0.3)

    # Generate compound
    _fill_with_walls(map, dungeon_def)
    var root = BSPNode.new(1, 1, map.width - 2, map.height - 2)
    _split_node(root, rng, min_room_size, split_ratio)
    var rooms = _create_rooms(root, rng, min_room_size, max_room_size)
    _carve_rooms(map, dungeon_def, rooms)
    _connect_rooms_recursive(map, dungeon_def, root, rng)
    _add_doors(map, dungeon_def, rooms)
    _designate_special_rooms(rooms, rng, courtyard_chance)
    _add_stairs(map, rooms, rng)

    # Populate
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)

    return map

func _split_node(node: BSPNode, rng: SeededRandom, min_size: int, split_ratio: float) -> void:
    # Stop if too small
    if node.width < min_size * 2 and node.height < min_size * 2:
        return

    # Determine split direction
    var split_horizontal = true
    if node.width > node.height and node.height >= min_size * 2:
        split_horizontal = false
    elif node.height > node.width and node.width >= min_size * 2:
        split_horizontal = true
    elif node.width >= min_size * 2 and node.height >= min_size * 2:
        split_horizontal = rng.randf() < 0.5
    else:
        return  # Can't split

    # Calculate split position
    var split_pos: int
    if split_horizontal:
        var max_split = node.height - min_size
        split_pos = rng.randi_range(min_size, max_split)
        node.left_child = BSPNode.new(node.x, node.y, node.width, split_pos)
        node.right_child = BSPNode.new(node.x, node.y + split_pos, node.width, node.height - split_pos)
    else:
        var max_split = node.width - min_size
        split_pos = rng.randi_range(min_size, max_split)
        node.left_child = BSPNode.new(node.x, node.y, split_pos, node.height)
        node.right_child = BSPNode.new(node.x + split_pos, node.y, node.width - split_pos, node.height)

    # Recursively split children
    _split_node(node.left_child, rng, min_size, split_ratio)
    _split_node(node.right_child, rng, min_size, split_ratio)

func _create_rooms(node: BSPNode, rng: SeededRandom, min_size: int, max_size: int) -> Array:
    var rooms = []

    if node.is_leaf():
        # Create room within this leaf
        var room_width = rng.randi_range(min_size, min(max_size, node.width - 2))
        var room_height = rng.randi_range(min_size, min(max_size, node.height - 2))
        var room_x = node.x + rng.randi_range(1, node.width - room_width - 1)
        var room_y = node.y + rng.randi_range(1, node.height - room_height - 1)

        node.room = Rect2i(room_x, room_y, room_width, room_height)
        rooms.append(node.room)
    else:
        # Recursively get rooms from children
        if node.left_child:
            rooms.append_array(_create_rooms(node.left_child, rng, min_size, max_size))
        if node.right_child:
            rooms.append_array(_create_rooms(node.right_child, rng, min_size, max_size))

    return rooms

func _carve_rooms(map: GameMap, dungeon_def: Dictionary, rooms: Array) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "stone_floor")

    for room in rooms:
        for x in range(room.position.x, room.position.x + room.size.x):
            for y in range(room.position.y, room.position.y + room.size.y):
                map.set_tile(x, y, TileManager.get_tile(floor_tile))

func _connect_rooms_recursive(map: GameMap, dungeon_def: Dictionary, node: BSPNode, rng: SeededRandom) -> void:
    if node.is_leaf():
        return

    # Recursively connect children first
    if node.left_child:
        _connect_rooms_recursive(map, dungeon_def, node.left_child, rng)
    if node.right_child:
        _connect_rooms_recursive(map, dungeon_def, node.right_child, rng)

    # Connect left and right subtrees
    if node.left_child and node.right_child:
        var left_room = _get_random_room_from_subtree(node.left_child, rng)
        var right_room = _get_random_room_from_subtree(node.right_child, rng)
        _connect_two_rooms(map, dungeon_def, left_room, right_room)

func _designate_special_rooms(rooms: Array, rng: SeededRandom, courtyard_chance: float) -> void:
    # Designate certain rooms as special (armory, barracks, courtyard, etc.)
    for room in rooms:
        if rng.randf() < courtyard_chance:
            room.metadata = {"type": "courtyard"}  # Open-air room
        elif rng.randf() < 0.2:
            room.metadata = {"type": "armory"}
        elif rng.randf() < 0.3:
            room.metadata = {"type": "barracks"}

# ... additional helper methods ...
```

**Files Created**:
- NEW: `generation/dungeon_generators/bsp_rooms_generator.gd`

**Testing Checklist**:
- [ ] Rooms are well-organized and non-overlapping
- [ ] All rooms connected via corridors
- [ ] Special rooms designated correctly
- [ ] Doors appear at room entrances
- [ ] Looks like military compound

**Benefits**:
- ✅ Organized, structured layout
- ✅ Efficient space usage
- ✅ Natural room hierarchy
- ✅ Suitable for military theme

---

### Task 2.4: Circular Floors Generator (Wizard Towers)

**Assignee**: [Procedural Generation Specialist]
**Priority**: Medium
**Estimated Time**: 1.5 hours
**Dependencies**: Phase 1 complete

**Objective**: Implement circular floor generator for vertical wizard towers.

**Algorithm Overview**:
Creates circular tower floors that go UP instead of down:
1. Define circle center and radius
2. Carve circular floor area
3. Divide perimeter into segments (rooms)
4. Place spiral staircase in center or offset
5. Create lab rooms, libraries, observatories
6. Add magical features (summoning circles, etc.)

**Implementation**:

```gdscript
// generation/dungeon_generators/circular_floors_generator.gd
class_name CircularFloorsGenerator
extends BaseDungeonGenerator

## Generates circular tower floors (vertical dungeons going UP)
## Used by: Wizard Towers

func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    var dungeon_id = dungeon_def.get("id", "unknown")
    var map_size = dungeon_def.get("map_size", {"width": 50, "height": 50})
    var map_id = "dungeon_%s_floor_%d" % [dungeon_id, floor_number]
    var map = GameMap.new(map_id, map_size.width, map_size.height)

    var floor_seed = _create_floor_seed(world_seed, dungeon_id, floor_number)
    var rng = SeededRandom.new(floor_seed)

    # Get parameters
    var floor_radius = _get_param(dungeon_def, "floor_radius", 12)
    var room_segments = _get_param(dungeon_def, "room_segments", 6)
    var spiral_stairs = _get_param(dungeon_def, "spiral_staircase", true)
    var lab_chance = _get_param(dungeon_def, "lab_room_chance", 0.4)

    # Generate tower floor
    _fill_with_walls(map, dungeon_def)
    var center = Vector2i(map.width / 2, map.height / 2)
    _carve_circular_floor(map, dungeon_def, center, floor_radius)
    _create_segmented_rooms(map, dungeon_def, center, floor_radius, room_segments, rng)
    _add_central_feature(map, dungeon_def, center, rng, spiral_stairs)
    _add_magical_elements(map, dungeon_def, rng, lab_chance)
    _add_stairs(map, rng, true)  # Stairs go UP

    # Populate
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)

    return map

func _carve_circular_floor(map: GameMap, dungeon_def: Dictionary, center: Vector2i, radius: int) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "stone_floor")

    for x in range(max(0, center.x - radius), min(map.width, center.x + radius + 1)):
        for y in range(max(0, center.y - radius), min(map.height, center.y + radius + 1)):
            var dist = center.distance_to(Vector2i(x, y))
            if dist <= radius:
                map.set_tile(x, y, TileManager.get_tile(floor_tile))

func _create_segmented_rooms(map: GameMap, dungeon_def: Dictionary, center: Vector2i, radius: int, segments: int, rng: SeededRandom) -> void:
    var wall_tile = dungeon_def.get("tiles", {}).get("wall", "stone_wall")

    # Divide circle into segments with walls
    for i in range(segments):
        var angle = (PI * 2 / segments) * i
        var wall_length = radius - 3  # Leave center open

        for r in range(3, wall_length):
            var x = center.x + int(cos(angle) * r)
            var y = center.y + int(sin(angle) * r)

            if x >= 0 and x < map.width and y >= 0 and y < map.height:
                map.set_tile(x, y, TileManager.get_tile(wall_tile))

                # Make walls 2-thick for stability
                var x2 = center.x + int(cos(angle) * r + sin(angle))
                var y2 = center.y + int(sin(angle) * r - cos(angle))
                if x2 >= 0 and x2 < map.width and y2 >= 0 and y2 < map.height:
                    map.set_tile(x2, y2, TileManager.get_tile(wall_tile))

func _add_central_feature(map: GameMap, dungeon_def: Dictionary, center: Vector2i, rng: SeededRandom, spiral: bool) -> void:
    if spiral:
        # Spiral staircase in center
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                var x = center.x + dx
                var y = center.y + dy
                if x >= 0 and x < map.width and y >= 0 and y < map.height:
                    map.set_tile(x, y, TileManager.get_tile("spiral_stairs"))
    else:
        # Central platform or pedestal
        map.set_tile(center.x, center.y, TileManager.get_tile("pedestal"))

func _add_magical_elements(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom, lab_chance: float) -> void:
    # Add summoning circles, magical wards, enchantment tables, etc.
    var circles_added = 0

    for x in range(1, map.width - 1):
        for y in range(1, map.height - 1):
            if map.tiles[x][y].walkable and rng.randf() < 0.02:  # 2% chance
                var feature = _pick_magical_feature(rng, lab_chance)
                map.set_tile(x, y, TileManager.get_tile(feature))
                circles_added += 1

                if circles_added >= 3:
                    return  # Limit to 3 features per floor

func _pick_magical_feature(rng: SeededRandom, lab_chance: float) -> String:
    if rng.randf() < lab_chance:
        var lab_features = ["enchantment_table", "alchemy_station", "arcane_workbench"]
        return lab_features[rng.randi_range(0, lab_features.size() - 1)]
    else:
        var magic_features = ["summoning_circle", "magical_ward", "crystal_focus"]
        return magic_features[rng.randi_range(0, magic_features.size() - 1)]

# ... additional helper methods ...
```

**Files Created**:
- NEW: `generation/dungeon_generators/circular_floors_generator.gd`

**Testing Checklist**:
- [ ] Floors are circular with proper radius
- [ ] Segmented rooms divide space evenly
- [ ] Central staircase or feature present
- [ ] Magical elements appear appropriately
- [ ] Distinct tower aesthetic

**Benefits**:
- ✅ Unique vertical dungeon (goes UP)
- ✅ Magical tower atmosphere
- ✅ Circular layout distinct from other types
- ✅ Room segments create interesting encounters

---

### Task 2.5: Concentric Rings Generator (Ancient Forts)

**Assignee**: [Procedural Generation Specialist]
**Priority**: Medium
**Estimated Time**: 1.5 hours
**Dependencies**: Phase 1 complete

**Objective**: Implement concentric ring fortress layout for ancient forts.

**Algorithm Overview**:
Creates defensive fortress structures with walls and courtyards:
1. Define center keep
2. Create concentric wall rings around keep
3. Add gatehouses at cardinal directions
4. Create courtyards between walls
5. Place defensive structures (towers, battlements)
6. Add underground dungeons beneath keep

**Implementation**:

```gdscript
// generation/dungeon_generators/concentric_rings_generator.gd
class_name ConcentricRingsGenerator
extends BaseDungeonGenerator

## Generates fortress layouts with concentric defensive walls
## Used by: Ancient Forts

func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    var dungeon_id = dungeon_def.get("id", "unknown")
    var map_size = dungeon_def.get("map_size", {"width": 50, "height": 50})
    var map_id = "dungeon_%s_floor_%d" % [dungeon_id, floor_number]
    var map = GameMap.new(map_id, map_size.width, map_size.height)

    var floor_seed = _create_floor_seed(world_seed, dungeon_id, floor_number)
    var rng = SeededRandom.new(floor_seed)

    # Get parameters
    var wall_count = _get_param(dungeon_def, "wall_count", 3)
    var courtyard_size = _get_param(dungeon_def, "courtyard_size", 15)
    var keep_size = _get_param(dungeon_def, "keep_size", 8)
    var gatehouse_count = _get_param(dungeon_def, "gatehouse_positions", 4)

    # Generate fort
    _fill_with_walls(map, dungeon_def)
    var center = Vector2i(map.width / 2, map.height / 2)
    _create_keep(map, dungeon_def, center, keep_size)
    _create_concentric_walls(map, dungeon_def, center, wall_count, courtyard_size)
    _add_gatehouses(map, dungeon_def, center, gatehouse_count, rng)
    _add_defensive_structures(map, dungeon_def, center, rng)
    _add_stairs(map, rng)

    # Populate
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)

    return map

func _create_keep(map: GameMap, dungeon_def: Dictionary, center: Vector2i, size: int) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "stone_floor")
    var wall_tile = dungeon_def.get("tiles", {}).get("wall", "fortress_wall")

    # Outer walls of keep
    for x in range(center.x - size, center.x + size + 1):
        for y in range(center.y - size, center.y + size + 1):
            if x >= 0 and x < map.width and y >= 0 and y < map.height:
                # Hollow square (walls only on perimeter)
                if x == center.x - size or x == center.x + size or y == center.y - size or y == center.y + size:
                    map.set_tile(x, y, TileManager.get_tile(wall_tile))
                else:
                    map.set_tile(x, y, TileManager.get_tile(floor_tile))

func _create_concentric_walls(map: GameMap, dungeon_def: Dictionary, center: Vector2i, count: int, spacing: int) -> void:
    var wall_tile = dungeon_def.get("tiles", {}).get("wall", "fortress_wall")
    var courtyard_tile = dungeon_def.get("tiles", {}).get("floor", "dirt_floor")

    for ring in range(1, count + 1):
        var radius = spacing * ring

        # Draw square ring
        for x in range(center.x - radius, center.x + radius + 1):
            for y in range(center.y - radius, center.y + radius + 1):
                if x < 0 or x >= map.width or y < 0 or y >= map.height:
                    continue

                # Check if on perimeter of square
                if x == center.x - radius or x == center.x + radius or y == center.y - radius or y == center.y + radius:
                    map.set_tile(x, y, TileManager.get_tile(wall_tile))
                elif ring > 1:  # Courtyard between walls
                    var prev_radius = spacing * (ring - 1)
                    if abs(x - center.x) > prev_radius or abs(y - center.y) > prev_radius:
                        map.set_tile(x, y, TileManager.get_tile(courtyard_tile))

func _add_gatehouses(map: GameMap, dungeon_def: Dictionary, center: Vector2i, count: int, rng: SeededRandom) -> void:
    var gate_tile = "gatehouse"

    # Place gatehouses at cardinal directions
    var directions = [
        Vector2i(0, -1),  # North
        Vector2i(1, 0),   # East
        Vector2i(0, 1),   # South
        Vector2i(-1, 0)   # West
    ]

    for i in range(min(count, 4)):
        var dir = directions[i]
        var gate_distance = 15  # Distance from center

        var gate_x = center.x + dir.x * gate_distance
        var gate_y = center.y + dir.y * gate_distance

        if gate_x >= 0 and gate_x < map.width and gate_y >= 0 and gate_y < map.height:
            # Create 3×3 gatehouse
            for dx in range(-1, 2):
                for dy in range(-1, 2):
                    var x = gate_x + dx
                    var y = gate_y + dy
                    if x >= 0 and x < map.width and y >= 0 and y < map.height:
                        if dx == 0 and dy == 0:
                            map.set_tile(x, y, TileManager.get_tile(gate_tile))
                        else:
                            map.set_tile(x, y, TileManager.get_tile("stone_floor"))

func _add_defensive_structures(map: GameMap, dungeon_def: Dictionary, center: Vector2i, rng: SeededRandom) -> void:
    # Add towers at corners
    var tower_positions = [
        Vector2i(center.x - 20, center.y - 20),
        Vector2i(center.x + 20, center.y - 20),
        Vector2i(center.x - 20, center.y + 20),
        Vector2i(center.x + 20, center.y + 20)
    ]

    for tower_pos in tower_positions:
        if tower_pos.x >= 0 and tower_pos.x < map.width and tower_pos.y >= 0 and tower_pos.y < map.height:
            _place_tower(map, tower_pos)

func _place_tower(map: GameMap, pos: Vector2i) -> void:
    # Create small 2×2 tower
    for dx in range(2):
        for dy in range(2):
            var x = pos.x + dx
            var y = pos.y + dy
            if x >= 0 and x < map.width and y >= 0 and y < map.height:
                map.set_tile(x, y, TileManager.get_tile("tower_wall"))

# ... additional helper methods ...
```

**Files Created**:
- NEW: `generation/dungeon_generators/concentric_rings_generator.gd`

**Testing Checklist**:
- [ ] Keep is centered and accessible
- [ ] Concentric walls form proper rings
- [ ] Gatehouses provide entrances
- [ ] Defensive towers at corners
- [ ] Fortress aesthetic achieved

**Benefits**:
- ✅ Defensive fortress layout
- ✅ Strategic gameplay (walls, choke points)
- ✅ Visually distinct from other types
- ✅ Thematic ancient fort feel

---

### Task 2.6: Symmetric Layout Generator (Temple Ruins)

**Assignee**: [Procedural Generation Specialist]
**Priority**: Medium
**Estimated Time**: 1.5 hours
**Dependencies**: Phase 1 complete

**Objective**: Implement symmetric temple layout using mirroring.

**Algorithm Overview**:
Creates symmetrical sacred structures:
1. Define central sanctum
2. Generate one quadrant procedurally
3. Mirror across horizontal/vertical/both axes
4. Create hallways connecting symmetrical chambers
5. Place altars, reliquaries, prayer halls
6. Add sacred geometry patterns

**Implementation**:

```gdscript
// generation/dungeon_generators/symmetric_layout_generator.gd
class_name SymmetricLayoutGenerator
extends BaseDungeonGenerator

## Generates symmetrical temple layouts using mirroring
## Used by: Temple Ruins

func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    var dungeon_id = dungeon_def.get("id", "unknown")
    var map_size = dungeon_def.get("map_size", {"width": 50, "height": 50})
    var map_id = "dungeon_%s_floor_%d" % [dungeon_id, floor_number]
    var map = GameMap.new(map_id, map_size.width, map_size.height)

    var floor_seed = _create_floor_seed(world_seed, dungeon_id, floor_number)
    var rng = SeededRandom.new(floor_seed)

    # Get parameters
    var symmetry_axis = _get_param(dungeon_def, "symmetry_axis", "both")  # horizontal, vertical, both
    var chamber_count = _get_param(dungeon_def, "chamber_count", 4)
    var hallway_width = _get_param(dungeon_def, "hallway_width", 3)
    var sanctum_size = _get_param(dungeon_def, "sanctum_size", 10)

    # Generate temple
    _fill_with_walls(map, dungeon_def)
    var center = Vector2i(map.width / 2, map.height / 2)
    _create_central_sanctum(map, dungeon_def, center, sanctum_size)
    _generate_quadrant(map, dungeon_def, center, chamber_count, rng)
    _apply_symmetry(map, dungeon_def, center, symmetry_axis)
    _create_hallways(map, dungeon_def, center, hallway_width)
    _add_sacred_features(map, dungeon_def, center, rng)
    _add_stairs(map, rng)

    # Populate
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)

    return map

func _create_central_sanctum(map: GameMap, dungeon_def: Dictionary, center: Vector2i, size: int) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "marble_floor")

    # Create square sanctum
    for x in range(center.x - size/2, center.x + size/2 + 1):
        for y in range(center.y - size/2, center.y + size/2 + 1):
            if x >= 0 and x < map.width and y >= 0 and y < map.height:
                map.set_tile(x, y, TileManager.get_tile(floor_tile))

    # Place altar in center
    map.set_tile(center.x, center.y, TileManager.get_tile("altar"))

func _generate_quadrant(map: GameMap, dungeon_def: Dictionary, center: Vector2i, chamber_count: int, rng: SeededRandom) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "stone_floor")

    # Generate chambers in top-right quadrant only (will be mirrored)
    for i in range(chamber_count):
        var chamber_size = rng.randi_range(4, 7)
        var chamber_x = center.x + rng.randi_range(5, 15)
        var chamber_y = center.y - rng.randi_range(5, 15)

        for x in range(chamber_x, chamber_x + chamber_size):
            for y in range(chamber_y, chamber_y + chamber_size):
                if x >= 0 and x < map.width and y >= 0 and y < map.height:
                    map.set_tile(x, y, TileManager.get_tile(floor_tile))

func _apply_symmetry(map: GameMap, dungeon_def: Dictionary, center: Vector2i, axis: String) -> void:
    match axis:
        "horizontal":
            _mirror_horizontal(map, center)
        "vertical":
            _mirror_vertical(map, center)
        "both":
            _mirror_horizontal(map, center)
            _mirror_vertical(map, center)

func _mirror_horizontal(map: GameMap, center: Vector2i) -> void:
    # Mirror top half to bottom half
    for x in range(map.width):
        for y in range(center.y):
            var source_tile = map.tiles[x][y]
            var mirror_y = center.y + (center.y - y)

            if mirror_y >= 0 and mirror_y < map.height:
                map.tiles[x][mirror_y] = source_tile

func _mirror_vertical(map: GameMap, center: Vector2i) -> void:
    # Mirror left half to right half
    for x in range(center.x):
        for y in range(map.height):
            var source_tile = map.tiles[x][y]
            var mirror_x = center.x + (center.x - x)

            if mirror_x >= 0 and mirror_x < map.width:
                map.tiles[mirror_x][y] = source_tile

func _create_hallways(map: GameMap, dungeon_def: Dictionary, center: Vector2i, width: int) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "marble_floor")

    # Create cross-shaped hallways
    # Horizontal hallway
    for x in range(map.width):
        for dy in range(-width/2, width/2 + 1):
            var y = center.y + dy
            if y >= 0 and y < map.height:
                map.set_tile(x, y, TileManager.get_tile(floor_tile))

    # Vertical hallway
    for y in range(map.height):
        for dx in range(-width/2, width/2 + 1):
            var x = center.x + dx
            if x >= 0 and x < map.width:
                map.set_tile(x, y, TileManager.get_tile(floor_tile))

func _add_sacred_features(map: GameMap, dungeon_def: Dictionary, center: Vector2i, rng: SeededRandom) -> void:
    # Add reliquaries, prayer halls, statues
    var feature_count = rng.randi_range(2, 4)

    for i in range(feature_count):
        var feature_x = rng.randi_range(5, map.width - 6)
        var feature_y = rng.randi_range(5, map.height - 6)

        if map.tiles[feature_x][feature_y].walkable:
            var feature = _pick_sacred_feature(rng)
            map.set_tile(feature_x, feature_y, TileManager.get_tile(feature))

func _pick_sacred_feature(rng: SeededRandom) -> String:
    var features = ["reliquary", "prayer_mat", "holy_statue", "offering_bowl"]
    return features[rng.randi_range(0, features.size() - 1)]

# ... additional helper methods ...
```

**Files Created**:
- NEW: `generation/dungeon_generators/symmetric_layout_generator.gd`

**Testing Checklist**:
- [ ] Layout is perfectly symmetrical
- [ ] Central sanctum with altar present
- [ ] Hallways connect all chambers
- [ ] Sacred features distributed evenly
- [ ] Temple aesthetic achieved

**Benefits**:
- ✅ Unique symmetrical layout
- ✅ Sacred, deliberate design
- ✅ Visually striking patterns
- ✅ Thematic temple feel

---

