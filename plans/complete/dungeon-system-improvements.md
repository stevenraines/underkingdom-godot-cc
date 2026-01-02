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

#### 8. Sewers
**Theme**: Underground waste systems beneath cities/towns
**Layout**: Winding tunnels with central channels, grates, maintenance platforms
**Depth**: 5-10 floors
**Special Features**: Sluice gates, drainage pipes, maintenance alcoves, rat nests
**Enemies**: Rats (swarms), oozes, crocodiles, criminals, plague victims
**Hazards**: Toxic water, disease zones, flooding, gas pockets (explosive)
**Loot**: Lost valuables, smuggled goods, alchemical waste, town refuse

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
| **Sewers** | Winding Tunnels + Channels | tunnel_width, channel_width, platform_frequency, branching_factor |

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
        "winding_tunnels":
            return WindingTunnelsGenerator.new()
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
        "symmetric_layout",
        "winding_tunnels"
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

### Task 2.7: Winding Tunnels Generator (Sewers)

**Assignee**: [Procedural Generation Specialist]
**Priority**: Medium
**Estimated Time**: 1.5 hours
**Dependencies**: Phase 1 complete

**Objective**: Implement winding sewer tunnels with central channels and platforms.

**Algorithm Overview**:
Creates realistic sewer systems beneath towns:
1. Generate main trunk line (central channel)
2. Branch off into secondary tunnels
3. Add maintenance platforms along channels
4. Create alcoves and side chambers
5. Place grates connecting to surface
6. Add sluice gates and drainage systems

**Implementation**:

```gdscript
// generation/dungeon_generators/winding_tunnels_generator.gd
class_name WindingTunnelsGenerator
extends BaseDungeonGenerator

## Generates winding sewer tunnels with water channels
## Used by: Sewers

func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    var dungeon_id = dungeon_def.get("id", "unknown")
    var map_size = dungeon_def.get("map_size", {"width": 50, "height": 50})
    var map_id = "dungeon_%s_floor_%d" % [dungeon_id, floor_number]
    var map = GameMap.new(map_id, map_size.width, map_size.height)

    var floor_seed = _create_floor_seed(world_seed, dungeon_id, floor_number)
    var rng = SeededRandom.new(floor_seed)

    # Get parameters
    var tunnel_width = _get_param(dungeon_def, "tunnel_width", 3)
    var channel_width = _get_param(dungeon_def, "channel_width", 1)
    var platform_freq = _get_param(dungeon_def, "platform_frequency", 0.3)
    var branching = _get_param(dungeon_def, "branching_factor", 0.4)

    # Generate sewers
    _fill_with_walls(map, dungeon_def)
    var main_path = _generate_main_trunk(map, dungeon_def, tunnel_width, rng)
    _add_branching_tunnels(map, dungeon_def, main_path, branching, tunnel_width, rng)
    _carve_water_channels(map, dungeon_def, channel_width)
    _add_maintenance_platforms(map, dungeon_def, rng, platform_freq)
    _add_sewer_features(map, dungeon_def, rng)
    _add_stairs(map, rng)

    # Populate
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)

    return map

func _generate_main_trunk(map: GameMap, dungeon_def: Dictionary, width: int, rng: SeededRandom) -> Array:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "stone_floor")
    var path = []

    # Create winding path from top to bottom
    var x = map.width / 2
    var y = 2

    while y < map.height - 2:
        # Carve tunnel segment
        for dx in range(-width/2, width/2 + 1):
            for dy in range(width):
                var tx = x + dx
                var ty = y + dy
                if tx > 0 and tx < map.width - 1 and ty > 0 and ty < map.height - 1:
                    map.set_tile(tx, ty, TileManager.get_tile(floor_tile))
                    path.append(Vector2i(tx, ty))

        # Random horizontal drift
        if rng.randf() < 0.3:
            x += rng.randi_range(-2, 2)
            x = clampi(x, width + 1, map.width - width - 1)

        y += width

    return path

func _add_branching_tunnels(map: GameMap, dungeon_def: Dictionary, main_path: Array, branching: float, width: int, rng: SeededRandom) -> void:
    var floor_tile = dungeon_def.get("tiles", {}).get("floor", "stone_floor")

    # Create side tunnels branching from main path
    for i in range(0, main_path.size(), 10):
        if rng.randf() < branching:
            var start_pos = main_path[i]
            var direction = Vector2i(rng.randi_range(-1, 1), 0) if rng.randf() < 0.5 else Vector2i(0, rng.randi_range(-1, 1))

            if direction == Vector2i.ZERO:
                continue

            # Carve branch tunnel
            var length = rng.randi_range(5, 15)
            var current = start_pos

            for step in range(length):
                for dx in range(-width/2, width/2 + 1):
                    for dy in range(-width/2, width/2 + 1):
                        var x = current.x + dx
                        var y = current.y + dy
                        if x > 0 and x < map.width - 1 and y > 0 and y < map.height - 1:
                            map.set_tile(x, y, TileManager.get_tile(floor_tile))

                current += direction * 2

                # Occasionally change direction
                if rng.randf() < 0.2:
                    direction = Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))

func _carve_water_channels(map: GameMap, dungeon_def: Dictionary, width: int) -> void:
    var water_tile = "sewer_water"  # Toxic water tile

    # Add water channel down center of main tunnels
    for x in range(map.width):
        for y in range(map.height):
            if map.tiles[x][y].walkable:
                # Check if center of tunnel (has walls on both sides)
                var has_left_wall = x > 0 and not map.tiles[x-1][y].walkable
                var has_right_wall = x < map.width - 1 and not map.tiles[x+1][y].walkable

                if has_left_wall or has_right_wall:
                    map.set_tile(x, y, TileManager.get_tile(water_tile))

func _add_maintenance_platforms(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom, frequency: float) -> void:
    # Add platforms beside water channels
    var platform_tile = "wooden_platform"

    for x in range(1, map.width - 1):
        for y in range(1, map.height - 1):
            var tile = map.tiles[x][y]
            if tile.tile_type == "sewer_water" and rng.randf() < frequency:
                # Place platform adjacent to water
                var adjacent = [Vector2i(x-1, y), Vector2i(x+1, y), Vector2i(x, y-1), Vector2i(x, y+1)]
                for adj in adjacent:
                    if adj.x > 0 and adj.x < map.width and adj.y > 0 and adj.y < map.height:
                        if not map.tiles[adj.x][adj.y].walkable:
                            map.set_tile(adj.x, adj.y, TileManager.get_tile(platform_tile))

func _add_sewer_features(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
    # Add sluice gates, drainage grates, etc.
    var feature_count = rng.randi_range(3, 6)

    for i in range(feature_count):
        var feature_type = ["sluice_gate", "drainage_grate", "maintenance_ladder"][rng.randi_range(0, 2)]
        var x = rng.randi_range(2, map.width - 3)
        var y = rng.randi_range(2, map.height - 3)

        if map.tiles[x][y].walkable:
            map.set_tile(x, y, TileManager.get_tile(feature_type))

# ... additional helper methods ...
```

**Files Created**:
- NEW: `generation/dungeon_generators/winding_tunnels_generator.gd`

**Testing Checklist**:
- [ ] Main trunk runs through map
- [ ] Branching tunnels create maze-like structure
- [ ] Water channels flow through center
- [ ] Platforms accessible beside water
- [ ] Sewer aesthetic achieved

**Benefits**:
- ✅ Realistic sewer layout
- ✅ Connects to town (grates to surface)
- ✅ Hazardous water zones
- ✅ Urban dungeon alternative

---

## Phase 3: Type-Specific Features & Hazards

### Task 3.1: Feature Generator System

**Assignee**: [Systems Programmer]
**Priority**: High
**Estimated Time**: 2 hours
**Dependencies**: Phase 2 (dungeon generators exist)

**Objective**: Create generic feature/hazard placement system that all generators can use.

**Feature Types**:
1. **Interactive Objects**: Chests, levers, pressure plates
2. **Environmental Hazards**: Spike traps, lava, poison gas
3. **Decorative Elements**: Furniture, statues, debris
4. **Special Tiles**: Teleporters, one-way doors, breakable walls

**System Design**:

```gdscript
// systems/feature_generator.gd
class_name FeatureGenerator
extends RefCounted

## Generic system for placing features/hazards in dungeons
## Used by all dungeon generators

## Place features from dungeon definition into map
static func place_features(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
    var room_features = dungeon_def.get("room_features", [])
    var hazards = dungeon_def.get("hazards", [])

    _place_room_features(map, room_features, rng)
    _place_hazards(map, hazards, rng)

static func _place_room_features(map: GameMap, features: Array, rng: SeededRandom) -> void:
    for feature_def in features:
        var feature_id = feature_def.get("feature_id", "")
        var spawn_chance = feature_def.get("spawn_chance", 0.1)
        var room_types = feature_def.get("room_types", ["any"])

        # Find suitable rooms based on type
        var eligible_rooms = _find_rooms_by_type(map, room_types)

        for room in eligible_rooms:
            if rng.randf() < spawn_chance:
                var pos = _find_valid_position_in_room(map, room, rng)
                if pos:
                    _place_feature_at(map, pos, feature_id)

static func _place_hazards(map: GameMap, hazards: Array, rng: SeededRandom) -> void:
    for hazard_def in hazards:
        var hazard_id = hazard_def.get("hazard_id", "")
        var density = hazard_def.get("density", 0.05)

        # Scatter hazards across walkable tiles
        for x in range(map.width):
            for y in range(map.height):
                if map.tiles[x][y].walkable and rng.randf() < density:
                    _place_hazard_at(map, Vector2i(x, y), hazard_id)

static func _place_feature_at(map: GameMap, pos: Vector2i, feature_id: String) -> void:
    # Create feature entity (chest, lever, etc.)
    var feature = _create_feature_entity(feature_id, pos)
    map.add_entity(feature)

static func _place_hazard_at(map: GameMap, pos: Vector2i, hazard_id: String) -> void:
    # Modify tile or add hazard entity
    match hazard_id:
        "floor_trap":
            map.tiles[pos.x][pos.y].metadata["trap"] = true
        "lava":
            map.set_tile(pos.x, pos.y, TileManager.get_tile("lava"))
        "poison_gas":
            var gas_zone = PoisonGasHazard.new(pos)
            map.add_entity(gas_zone)

static func _find_rooms_by_type(map: GameMap, room_types: Array) -> Array:
    # Parse map metadata for room information
    var rooms = map.metadata.get("rooms", [])
    var filtered = []

    for room in rooms:
        var room_type = room.get("type", "any")
        if "any" in room_types or room_type in room_types:
            filtered.append(room)

    return filtered

static func _find_valid_position_in_room(map: GameMap, room: Dictionary, rng: SeededRandom) -> Variant:
    var rect = room.get("rect", Rect2i())
    var attempts = 20

    for i in range(attempts):
        var x = rng.randi_range(rect.position.x + 1, rect.position.x + rect.size.x - 2)
        var y = rng.randi_range(rect.position.y + 1, rect.position.y + rect.size.y - 2)

        if map.tiles[x][y].walkable and not map.has_entity_at(x, y):
            return Vector2i(x, y)

    return null  # No valid position found

# ... additional helper methods ...
```

**Integration with Generators**:

All dungeon generators should call the feature system after basic generation:

```gdscript
// Example from rectangular_rooms_generator.gd
func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
    # ... existing generation code ...

    # NEW: Place features and hazards
    FeatureGenerator.place_features(map, dungeon_def, rng)

    # Populate with content
    _spawn_enemies(map, dungeon_def, floor_number, rng)
    _spawn_loot(map, dungeon_def, floor_number, rng)

    return map
```

**Files Created**:
- NEW: `systems/feature_generator.gd`
- MODIFIED: All 6 generator files to call FeatureGenerator

**Testing Checklist**:
- [ ] Features spawn in appropriate rooms
- [ ] Hazard density matches configuration
- [ ] Features don't block critical paths
- [ ] Hazards affect player as expected
- [ ] Room type filtering works correctly

**Benefits**:
- ✅ DRY: One feature system for all dungeon types
- ✅ Data-driven: Features defined in JSON
- ✅ Extensible: Easy to add new feature types
- ✅ Consistent: Same placement logic everywhere

---

### Task 3.2: Dungeon-Specific Content Definitions

**Assignee**: [Content Designer]
**Priority**: High
**Estimated Time**: 2 hours
**Dependencies**: Task 3.1 (FeatureGenerator exists)

**Objective**: Define type-specific features, hazards, and special mechanics for each dungeon type in JSON.

**Burial Barrows - Content**:

```json
{
  "id": "burial_barrow",
  "room_features": [
    {
      "feature_id": "sarcophagus",
      "spawn_chance": 0.3,
      "room_types": ["large", "end"],
      "contains_loot": true,
      "summons_enemy": "skeleton"
    },
    {
      "feature_id": "treasure_chest",
      "spawn_chance": 0.15,
      "room_types": ["end"],
      "loot_table": "ancient_treasure"
    },
    {
      "feature_id": "tomb_inscription",
      "spawn_chance": 0.2,
      "room_types": ["any"],
      "provides_hint": true
    }
  ],
  "hazards": [
    {
      "hazard_id": "floor_trap",
      "density": 0.05,
      "damage": 10,
      "detection_difficulty": 15
    },
    {
      "hazard_id": "curse_zone",
      "density": 0.02,
      "effect": "stat_drain",
      "duration": 100
    },
    {
      "hazard_id": "collapsing_ceiling",
      "density": 0.01,
      "trigger": "pressure_plate",
      "damage": 20
    }
  ],
  "special_rooms": [
    {
      "room_type": "crypt",
      "chance": 0.2,
      "contains": "boss_enemy",
      "loot_multiplier": 2.0
    },
    {
      "room_type": "treasure_chamber",
      "chance": 0.1,
      "requires": "key_item",
      "loot_multiplier": 3.0
    }
  ]
}
```

**Natural Caves - Content**:

```json
{
  "id": "natural_cave",
  "room_features": [
    {
      "feature_id": "crystal_formation",
      "spawn_chance": 0.25,
      "room_types": ["large"],
      "provides_light": true,
      "harvestable": true
    },
    {
      "feature_id": "underground_lake",
      "spawn_chance": 0.15,
      "room_types": ["large"],
      "contains": "water_enemies",
      "source_of_water": true
    },
    {
      "feature_id": "mushroom_patch",
      "spawn_chance": 0.2,
      "room_types": ["any"],
      "harvestable": true,
      "poisons_on_damage": true
    }
  ],
  "hazards": [
    {
      "hazard_id": "pitfall",
      "density": 0.03,
      "damage": 15,
      "falls_to_lower_floor": true
    },
    {
      "hazard_id": "unstable_ground",
      "density": 0.04,
      "trigger": "weight",
      "creates_pitfall": true
    },
    {
      "hazard_id": "darkness_zone",
      "density": 0.1,
      "reduces_vision": 0.5,
      "permanent": true
    }
  ],
  "environmental_effects": {
    "ambient_darkness": true,
    "echo_sound": true,
    "dampness": 0.8
  }
}
```

**Abandoned Mines - Content**:

```json
{
  "id": "abandoned_mine",
  "room_features": [
    {
      "feature_id": "ore_vein",
      "spawn_chance": 0.4,
      "room_types": ["any"],
      "harvestable": true,
      "requires_tool": "pickaxe",
      "yields": "iron_ore"
    },
    {
      "feature_id": "mine_cart",
      "spawn_chance": 0.15,
      "room_types": ["tunnel"],
      "rideable": true,
      "contains_loot": true
    },
    {
      "feature_id": "support_beam",
      "spawn_chance": 0.3,
      "room_types": ["tunnel"],
      "destructible": true,
      "causes_collapse": true
    }
  ],
  "hazards": [
    {
      "hazard_id": "cave_in",
      "density": 0.02,
      "trigger": "explosion",
      "blocks_path": true,
      "damage": 30
    },
    {
      "hazard_id": "toxic_gas",
      "density": 0.05,
      "damage_per_turn": 2,
      "reduces_stamina_regen": true
    },
    {
      "hazard_id": "flooded_section",
      "density": 0.03,
      "slows_movement": true,
      "rusts_equipment": true
    }
  ],
  "special_rooms": [
    {
      "room_type": "foreman_office",
      "chance": 0.15,
      "contains": "lore_documents",
      "has_safe": true
    }
  ]
}
```

**Military Compounds - Content**:

```json
{
  "id": "military_compound",
  "room_features": [
    {
      "feature_id": "weapon_rack",
      "spawn_chance": 0.3,
      "room_types": ["armory"],
      "contains_loot": true,
      "loot_type": "weapons"
    },
    {
      "feature_id": "training_dummy",
      "spawn_chance": 0.2,
      "room_types": ["training_yard"],
      "interactive": true,
      "improves_combat_skill": true
    },
    {
      "feature_id": "guard_tower",
      "spawn_chance": 0.1,
      "room_types": ["courtyard"],
      "spawns_archers": true,
      "provides_overwatch": true
    }
  ],
  "hazards": [
    {
      "hazard_id": "patrol_route",
      "density": 0.1,
      "moving_enemies": true,
      "alert_on_sight": true
    },
    {
      "hazard_id": "alarm_bell",
      "density": 0.05,
      "summons_reinforcements": true,
      "detection_radius": 10
    },
    {
      "hazard_id": "ballista_trap",
      "density": 0.02,
      "damage": 40,
      "piercing": true
    }
  ],
  "special_rooms": [
    {
      "room_type": "command_center",
      "chance": 0.1,
      "contains": "boss_enemy",
      "has_strategic_map": true
    }
  ]
}
```

**Wizard Towers - Content**:

```json
{
  "id": "wizard_tower",
  "room_features": [
    {
      "feature_id": "summoning_circle",
      "spawn_chance": 0.2,
      "room_types": ["lab"],
      "spawns_demons": true,
      "destroyable": true
    },
    {
      "feature_id": "enchantment_table",
      "spawn_chance": 0.25,
      "room_types": ["lab"],
      "allows_enchanting": true,
      "requires_components": true
    },
    {
      "feature_id": "spell_scroll_shelf",
      "spawn_chance": 0.3,
      "room_types": ["library"],
      "contains_loot": true,
      "loot_type": "scrolls"
    }
  ],
  "hazards": [
    {
      "hazard_id": "magical_ward",
      "density": 0.08,
      "damage": 15,
      "element": "arcane",
      "dispellable": true
    },
    {
      "hazard_id": "dimensional_rift",
      "density": 0.03,
      "teleports_randomly": true,
      "summons_enemies": true
    },
    {
      "hazard_id": "wild_magic_zone",
      "density": 0.05,
      "random_spell_effects": true,
      "unpredictable": true
    }
  ],
  "environmental_effects": {
    "ambient_magic": 0.8,
    "levitation": 0.2,
    "time_distortion": 0.1
  }
}
```

**Ancient Forts - Content**:

```json
{
  "id": "ancient_fort",
  "room_features": [
    {
      "feature_id": "siege_weapon",
      "spawn_chance": 0.15,
      "room_types": ["battlement"],
      "usable": true,
      "damage": 50
    },
    {
      "feature_id": "treasure_vault",
      "spawn_chance": 0.1,
      "room_types": ["keep"],
      "requires_key": true,
      "loot_multiplier": 3.0
    }
  ],
  "hazards": [
    {
      "hazard_id": "arrow_slit",
      "density": 0.1,
      "damage": 10,
      "ranged_attack": true,
      "cover_blocks": true
    },
    {
      "hazard_id": "crumbling_wall",
      "density": 0.05,
      "damage": 20,
      "creates_rubble": true
    },
    {
      "hazard_id": "portcullis",
      "density": 0.03,
      "blocks_path": true,
      "requires_lever": true
    }
  ]
}
```

**Temple Ruins - Content**:

```json
{
  "id": "temple_ruins",
  "room_features": [
    {
      "feature_id": "altar",
      "spawn_chance": 0.3,
      "room_types": ["sanctum"],
      "allows_prayer": true,
      "grants_blessing": true
    },
    {
      "feature_id": "reliquary",
      "spawn_chance": 0.2,
      "room_types": ["chamber"],
      "contains_loot": true,
      "guarded_by_spirit": true
    },
    {
      "feature_id": "holy_statue",
      "spawn_chance": 0.25,
      "room_types": ["any"],
      "animated": true,
      "attacks_undead": true
    }
  ],
  "hazards": [
    {
      "hazard_id": "divine_curse",
      "density": 0.06,
      "effect": "stat_drain",
      "affects_blasphemers": true
    },
    {
      "hazard_id": "sanctified_ground",
      "density": 0.08,
      "damages_undead": true,
      "heals_faithful": true
    },
    {
      "hazard_id": "possessed_statue",
      "density": 0.03,
      "animates_when_approached": true,
      "becomes_enemy": true
    }
  ],
  "environmental_effects": {
    "holy_aura": 0.5,
    "echoing_prayers": true
  }
}
```

**Sewers - Content**:

```json
{
  "id": "sewers",
  "room_features": [
    {
      "feature_id": "sluice_gate",
      "spawn_chance": 0.2,
      "room_types": ["junction"],
      "controllable": true,
      "redirects_water_flow": true
    },
    {
      "feature_id": "rat_nest",
      "spawn_chance": 0.25,
      "room_types": ["alcove"],
      "spawns_enemies": true,
      "destroyable": true
    },
    {
      "feature_id": "drainage_grate",
      "spawn_chance": 0.15,
      "room_types": ["main_tunnel"],
      "connects_to_surface": true,
      "provides_escape": true
    },
    {
      "feature_id": "smuggler_cache",
      "spawn_chance": 0.1,
      "room_types": ["side_chamber"],
      "contains_loot": true,
      "hidden": true
    }
  ],
  "hazards": [
    {
      "hazard_id": "toxic_water",
      "density": 0.3,
      "damage_per_turn": 1,
      "causes_disease": true,
      "slows_movement": 0.5
    },
    {
      "hazard_id": "disease_zone",
      "density": 0.08,
      "effect": "plague",
      "duration": 500,
      "contagious": true
    },
    {
      "hazard_id": "explosive_gas",
      "density": 0.04,
      "trigger": "fire",
      "damage": 25,
      "area_of_effect": 3
    },
    {
      "hazard_id": "sudden_flood",
      "density": 0.02,
      "trigger": "sluice_gate",
      "sweeps_entities": true,
      "damage": 15
    }
  ],
  "special_rooms": [
    {
      "room_type": "junction_chamber",
      "chance": 0.2,
      "contains": "multiple_sluice_gates",
      "puzzle_element": true
    },
    {
      "room_type": "abandoned_hideout",
      "chance": 0.15,
      "contains": "criminal_npcs",
      "trade_available": true
    }
  ],
  "environmental_effects": {
    "foul_odor": true,
    "poor_visibility": 0.6,
    "dampness": 0.9,
    "echo_chamber": true
  }
}
```

**Files Modified**:
- MODIFIED: All 8 dungeon JSON files with features, hazards, special rooms

**Testing Checklist**:
- [ ] Each dungeon type has unique features
- [ ] Hazards match thematic expectations
- [ ] Special rooms spawn at correct rates
- [ ] Environmental effects apply correctly
- [ ] Content balances well with enemy difficulty

**Benefits**:
- ✅ Rich, varied dungeon content
- ✅ Each type feels unique
- ✅ Thematic consistency
- ✅ Gameplay depth via hazards/features

---

## Phase 4: Dungeon Registry & Discovery

### Task 4.1: Overworld Dungeon Placement

**Assignee**: [Systems Programmer]
**Priority**: High
**Estimated Time**: 2 hours
**Dependencies**: Phase 2 (dungeon generators exist)

**Objective**: Integrate dungeons into overworld generation with entrance placement.

**Dungeon Entrance System**:

```gdscript
// generation/world_generator.gd (MODIFIED)

static func generate_overworld(world_seed: int) -> GameMap:
    # ... existing overworld generation ...

    # NEW: Place dungeon entrances
    _place_dungeon_entrances(map, rng)

    return map

static func _place_dungeon_entrances(map: GameMap, rng: SeededRandom) -> void:
    var dungeon_types = DungeonManager.get_all_dungeon_types()
    var entrance_count = rng.randi_range(5, 10)  # 5-10 dungeons per overworld

    for i in range(entrance_count):
        var dungeon_type = DungeonManager.get_random_dungeon_type(rng)
        var pos = _find_suitable_dungeon_location(map, dungeon_type, rng)

        if pos:
            _place_dungeon_entrance(map, pos, dungeon_type)

static func _find_suitable_dungeon_location(map: GameMap, dungeon_type: String, rng: SeededRandom) -> Variant:
    # Different dungeon types prefer different terrain
    var preferred_biomes = _get_preferred_biomes(dungeon_type)
    var attempts = 100

    for i in range(attempts):
        var x = rng.randi_range(10, map.width - 10)
        var y = rng.randi_range(10, map.height - 10)
        var biome = map.tiles[x][y].metadata.get("biome", "temperate")

        if biome in preferred_biomes and map.tiles[x][y].walkable:
            return Vector2i(x, y)

    return null

static func _get_preferred_biomes(dungeon_type: String) -> Array[String]:
    match dungeon_type:
        "burial_barrow":
            return ["temperate", "plains"]  # Open fields
        "natural_cave":
            return ["mountain", "hills"]  # Rocky terrain
        "abandoned_mine":
            return ["mountain", "hills"]  # Mineral-rich areas
        "military_compound":
            return ["plains", "temperate"]  # Strategic locations
        "wizard_tower":
            return ["any"]  # Can be anywhere
        "ancient_fort":
            return ["hills", "plains"]  # Defensive positions
        "temple_ruins":
            return ["temperate", "desert"]  # Sacred sites
        "sewers":
            return ["town"]  # Beneath settlements
        _:
            return ["any"]

static func _place_dungeon_entrance(map: GameMap, pos: Vector2i, dungeon_type: String) -> void:
    # Place entrance tile
    var entrance_tile = "dungeon_entrance_%s" % dungeon_type
    map.set_tile(pos.x, pos.y, TileManager.get_tile(entrance_tile))

    # Store dungeon metadata
    map.tiles[pos.x][pos.y].metadata["dungeon_type"] = dungeon_type
    map.tiles[pos.x][pos.y].metadata["dungeon_id"] = "dungeon_%s_%d" % [dungeon_type, pos.hash()]
```

**Player Interaction**:

```gdscript
// systems/input_handler.gd (MODIFIED)

func _handle_enter_dungeon(player_pos: Vector2i) -> void:
    var tile = MapManager.current_map.tiles[player_pos.x][player_pos.y]

    if tile.tile_type.begins_with("dungeon_entrance"):
        var dungeon_type = tile.metadata.get("dungeon_type", "burial_barrow")
        var dungeon_id = tile.metadata.get("dungeon_id")

        # Transition to dungeon floor 1
        var dungeon_map_id = "%s_floor_1" % dungeon_id
        MapManager.transition_to_map(dungeon_map_id)
        EventBus.dungeon_entered.emit(dungeon_type, 1)
```

**Files Modified**:
- MODIFIED: `generation/world_generator.gd`
- MODIFIED: `systems/input_handler.gd`
- NEW: Dungeon entrance tile definitions in TileManager

**Testing Checklist**:
- [ ] Dungeons spawn in appropriate biomes
- [ ] Entrance tiles are visually distinct
- [ ] Player can enter dungeons
- [ ] Correct dungeon type loads
- [ ] 5-10 dungeons per overworld

**Benefits**:
- ✅ Dungeons integrated into overworld
- ✅ Logical placement based on terrain
- ✅ Discoverable by exploration
- ✅ Multiple dungeon types per world

---

### Task 4.2: Dungeon Discovery & Progression Tracking

**Assignee**: [Systems Programmer]
**Priority**: Medium
**Estimated Time**: 1.5 hours
**Dependencies**: Task 4.1 (dungeon entrances exist)

**Objective**: Track discovered dungeons and player progression through floors.

**Discovery System**:

```gdscript
// autoload/game_manager.gd (MODIFIED)

var discovered_dungeons: Dictionary = {}  # dungeon_id -> {type, deepest_floor, cleared}

func discover_dungeon(dungeon_id: String, dungeon_type: String) -> void:
    if not discovered_dungeons.has(dungeon_id):
        discovered_dungeons[dungeon_id] = {
            "type": dungeon_type,
            "deepest_floor": 0,
            "cleared": false,
            "discovered_at_turn": TurnManager.current_turn
        }
        EventBus.dungeon_discovered.emit(dungeon_id, dungeon_type)

func record_floor_reached(dungeon_id: String, floor_number: int) -> void:
    if discovered_dungeons.has(dungeon_id):
        var dungeon = discovered_dungeons[dungeon_id]
        if floor_number > dungeon.deepest_floor:
            dungeon.deepest_floor = floor_number
            EventBus.new_floor_reached.emit(dungeon_id, floor_number)

func mark_dungeon_cleared(dungeon_id: String) -> void:
    if discovered_dungeons.has(dungeon_id):
        discovered_dungeons[dungeon_id].cleared = true
        EventBus.dungeon_cleared.emit(dungeon_id)

func get_discovered_dungeon_count() -> int:
    return discovered_dungeons.size()

func get_cleared_dungeon_count() -> int:
    var count = 0
    for dungeon_id in discovered_dungeons:
        if discovered_dungeons[dungeon_id].cleared:
            count += 1
    return count
```

**UI Integration**:

```gdscript
// ui/dungeon_journal.gd (NEW)
extends Control

## Displays discovered dungeons and progression

var journal_entries: VBoxContainer

func _ready() -> void:
    EventBus.dungeon_discovered.connect(_on_dungeon_discovered)
    EventBus.new_floor_reached.connect(_on_floor_reached)
    _refresh_journal()

func _refresh_journal() -> void:
    _clear_entries()

    for dungeon_id in GameManager.discovered_dungeons:
        var dungeon = GameManager.discovered_dungeons[dungeon_id]
        var entry = _create_journal_entry(dungeon_id, dungeon)
        journal_entries.add_child(entry)

func _create_journal_entry(dungeon_id: String, dungeon: Dictionary) -> Control:
    var entry = HBoxContainer.new()

    var type_label = Label.new()
    type_label.text = dungeon.type.capitalize()

    var progress_label = Label.new()
    progress_label.text = "Floor %d/%d" % [dungeon.deepest_floor, _get_max_floors(dungeon.type)]

    var status_label = Label.new()
    status_label.text = "CLEARED" if dungeon.cleared else "In Progress"

    entry.add_child(type_label)
    entry.add_child(progress_label)
    entry.add_child(status_label)

    return entry

func _get_max_floors(dungeon_type: String) -> int:
    var dungeon_def = DungeonManager.get_dungeon(dungeon_type)
    var floor_count = dungeon_def.get("floor_count", {"min": 10, "max": 20})
    return floor_count.max
```

**Files Created/Modified**:
- MODIFIED: `autoload/game_manager.gd`
- NEW: `ui/dungeon_journal.gd`
- NEW: EventBus signals (`dungeon_discovered`, `new_floor_reached`, `dungeon_cleared`)

**Testing Checklist**:
- [ ] Dungeons marked as discovered on first visit
- [ ] Deepest floor tracked correctly
- [ ] Cleared status updates when boss defeated
- [ ] Journal UI displays all discovered dungeons
- [ ] Progression persists across sessions

**Benefits**:
- ✅ Player progression tracking
- ✅ Sense of accomplishment
- ✅ Journal provides overview
- ✅ Integrates with save system

---

## Summary & Metrics

### Implementation Summary

**Total Phases**: 4
**Total Tasks**: 13
**Estimated Total Time**: 22-27 hours

### Phase Breakdown

| Phase | Tasks | Est. Time | Complexity | Priority |
|-------|-------|-----------|------------|----------|
| Phase 1: Data-Driven Architecture | 4 | 4-5 hours | Medium | Critical |
| Phase 2: Multi-Type Generation Algorithms | 7 | 10.5-12 hours | High | Critical |
| Phase 3: Type-Specific Features & Hazards | 2 | 4 hours | Medium | High |
| Phase 4: Dungeon Registry & Discovery | 2 | 3.5-4 hours | Low | Medium |

### Files Impacted

**New Files (18)**:
- `data/dungeons/*.json` (8 dungeon definitions)
- `autoload/dungeon_manager.gd`
- `generation/dungeon_generator_factory.gd`
- `generation/dungeon_generators/base_dungeon_generator.gd`
- `generation/dungeon_generators/rectangular_rooms_generator.gd`
- `generation/dungeon_generators/cellular_automata_generator.gd`
- `generation/dungeon_generators/grid_tunnels_generator.gd`
- `generation/dungeon_generators/bsp_rooms_generator.gd`
- `generation/dungeon_generators/circular_floors_generator.gd`
- `generation/dungeon_generators/concentric_rings_generator.gd`
- `generation/dungeon_generators/symmetric_layout_generator.gd`
- `generation/dungeon_generators/winding_tunnels_generator.gd`
- `systems/feature_generator.gd`
- `ui/dungeon_journal.gd`

**Modified Files (4)**:
- `autoload/map_manager.gd`
- `autoload/game_manager.gd`
- `generation/world_generator.gd`
- `systems/input_handler.gd`
- `project.godot` (autoload registration)

**Deleted Files (1)**:
- `generation/dungeon_generators/burial_barrow.gd` (replaced by rectangular_rooms_generator.gd)

### Content Additions

**Dungeon Types**: 8
1. Burial Barrows
2. Natural Caves
3. Abandoned Mines
4. Military Compounds
5. Wizard Towers
6. Ancient Forts
7. Temple Ruins
8. Sewers

**Generation Algorithms**: 7
- Rectangular Rooms + Corridors
- Cellular Automata
- Grid Tunnels
- Binary Space Partition (BSP)
- Circular Floors
- Concentric Rings
- Symmetric Mirroring
- Winding Tunnels

**Feature Types**: 50+ unique features across all dungeon types
**Hazard Types**: 40+ unique hazards
**Special Room Types**: 15+ unique special rooms

### Code Metrics (Estimated)

**Total Lines of Code**: ~3,500 lines
**JSON Configuration**: ~2,000 lines
**Average Generator Length**: ~300 lines
**Test Coverage Target**: 80%

### Testing Requirements

**Unit Tests**: 25-30 tests
- DungeonManager loading
- Factory pattern creation
- Each generator algorithm
- Feature placement logic

**Integration Tests**: 10-15 tests
- End-to-end dungeon generation
- Overworld integration
- Discovery system
- Save/load with dungeons

**Playtest Scenarios**: 8 scenarios
- One playthrough per dungeon type
- Verify unique feel
- Balance testing
- Performance validation

---

## Implementation Order Recommendation

### Phase 1: Foundation (Week 1)
**Priority**: Must complete before anything else

1. **Day 1-2**: Task 1.1 (Dungeon Definitions)
   - Create all 8 JSON files
   - Validate schema
   - Review with team

2. **Day 2-3**: Task 1.2 (DungeonManager)
   - Implement autoload
   - Test JSON loading
   - Integrate with project

3. **Day 3-4**: Task 1.3 (Generator Factory)
   - Create base interface
   - Implement factory
   - Wire up MapManager

4. **Day 4-5**: Task 1.4 (Refactor Burial Barrow)
   - Convert to new system
   - Verify backwards compatibility
   - Test deterministic generation

### Phase 2: Generation Algorithms (Week 2-3)
**Priority**: Core feature development

**Recommended Order**:
1. Task 2.1: Cellular Automata (Natural Caves)
2. Task 2.2: Grid Tunnels (Abandoned Mines)
3. Task 2.4: Circular Floors (Wizard Towers) - Unique vertical mechanic
4. Task 2.3: BSP Rooms (Military Compounds)
5. Task 2.5: Concentric Rings (Ancient Forts)
6. Task 2.6: Symmetric Layout (Temple Ruins)
7. Task 2.7: Winding Tunnels (Sewers)

**Rationale**: Start with organic (caves), then structured (mines, towers), then complex spatial (BSP, concentric, symmetric), finish with hybrid (sewers)

### Phase 3: Content & Polish (Week 3-4)
**Priority**: High, adds depth

1. **Day 1-2**: Task 3.1 (Feature Generator System)
   - Implement generic system
   - Test with simple features
   - Integrate with all generators

2. **Day 3-4**: Task 3.2 (Dungeon-Specific Content)
   - Add features/hazards to all 8 JSON files
   - Balance testing
   - Playtest each type

### Phase 4: Integration (Week 4)
**Priority**: Medium, polish

1. **Day 1-2**: Task 4.1 (Overworld Placement)
   - Implement entrance system
   - Test biome preferences
   - Verify transitions

2. **Day 2-3**: Task 4.2 (Discovery Tracking)
   - Add progression system
   - Build dungeon journal UI
   - Integrate with save system

### Parallel Work Opportunities

**Can be done in parallel**:
- Phase 2 generators (after Phase 1 complete)
- Phase 3 content definitions (while generators in progress)
- UI work (Task 4.2) can start early

**Blockers**:
- Phase 1 must complete before Phase 2
- Generators must exist before features (Task 3.1)
- Overworld integration (Task 4.1) needs generators

---

## Risk Assessment

### High Risk Areas

#### 1. Algorithm Complexity (High Risk, High Impact)
**Risk**: Cellular automata, BSP, and symmetric layout algorithms are complex and error-prone.

**Mitigation**:
- Implement extensive unit tests for each algorithm
- Create visual debugging tools to inspect generation
- Reference existing roguelike implementations (RogueBasin, Godot examples)
- Start with simpler algorithms (rectangular rooms) before complex ones

**Contingency**: Fall back to simpler variants if algorithm fails (e.g., use rectangular rooms instead of BSP)

#### 2. Performance (Medium Risk, High Impact)
**Risk**: Generating complex dungeons on-the-fly may cause lag/hitches.

**Mitigation**:
- Profile generation performance early
- Implement loading screens for large dungeons
- Consider async generation with progress bars
- Cache generated floors aggressively

**Contingency**: Pre-generate floors during world creation, reduce map sizes

#### 3. Save System Integration (Medium Risk, Medium Impact)
**Risk**: Dungeon state serialization complex (floors, progression, discoveries).

**Mitigation**:
- Use existing SaveManager patterns
- Store only critical state (floor seeds, not full maps)
- Test save/load extensively
- Document serialization format

**Contingency**: Simplify by not saving full dungeon state, regenerate on load

### Medium Risk Areas

#### 4. Backwards Compatibility (Low Risk, Medium Impact)
**Risk**: Existing burial barrow saves break after refactor.

**Mitigation**:
- Implement save version migration
- Test with existing save files
- Keep old generator as fallback temporarily

**Contingency**: Force world reset, provide conversion tool

#### 5. Balance (Medium Risk, Low Impact)
**Risk**: Some dungeon types too easy/hard compared to others.

**Mitigation**:
- Extensive playtest all types
- Tune enemy pools, loot tables, hazard density
- Gather feedback early

**Contingency**: Adjust JSON parameters post-launch, hotfix

### Low Risk Areas

#### 6. Feature Placement (Low Risk, Low Impact)
**Risk**: Features spawn incorrectly or block paths.

**Mitigation**:
- Validate feature positions before placement
- Ensure connectivity after all features placed
- Test with extreme densities

**Contingency**: Reduce spawn rates, disable problematic features

#### 7. UI/UX (Low Risk, Low Impact)
**Risk**: Dungeon journal unclear or not useful.

**Mitigation**:
- User testing with journal
- Iterate on layout/information shown

**Contingency**: Simplify journal, show less detail

---

## Future Enhancements

### Post-Launch Additions

#### 1. Dynamic Difficulty Scaling
**Description**: Adjust dungeon difficulty based on player level/gear.

**Implementation**:
- Add `difficulty_multiplier` to dungeon definitions
- Scale enemy stats, loot quality, hazard damage
- Calculate based on player stats when entering

**Estimated Effort**: 2-3 hours

#### 2. Procedural Boss Encounters
**Description**: Generate unique boss rooms with special mechanics.

**Implementation**:
- Define boss templates in JSON
- Special room generation for boss arenas
- Custom AI behaviors per dungeon type

**Estimated Effort**: 8-10 hours

#### 3. Dungeon Modifiers/Affixes
**Description**: Apply random modifiers to dungeons (e.g., "Flooded", "Cursed", "Infested").

**Implementation**:
- Define modifiers in JSON
- Apply effects to generation parameters
- Display modifier in dungeon name/description

**Estimated Effort**: 4-5 hours

#### 4. Multi-Floor Special Rooms
**Description**: Rare rooms that span multiple floors (shafts, vertical chambers).

**Implementation**:
- Mark tiles as "vertical connectors"
- Align features across floors
- Handle entity/loot placement

**Estimated Effort**: 5-6 hours

#### 5. Branching Paths & Shortcuts
**Description**: Optional paths, secret passages, shortcuts between floors.

**Implementation**:
- Add alternate stairways during generation
- Create hidden door mechanics
- Track discovered shortcuts

**Estimated Effort**: 3-4 hours

#### 6. Dungeon Events/Encounters
**Description**: Scripted events triggered at specific floors or conditions.

**Implementation**:
- Event definition system
- Trigger conditions (floor number, time, items)
- Narrative integration

**Estimated Effort**: 6-8 hours

#### 7. Procedural Puzzle Rooms
**Description**: Generate solvable puzzles (lever sequences, tile patterns, riddles).

**Implementation**:
- Puzzle generator system
- Solution validator
- Reward upon completion

**Estimated Effort**: 10-12 hours

#### 8. Additional Dungeon Types
**Description**: Expand dungeon variety with new types.

**Candidates**:
- **Ice Caverns**: Frozen wasteland dungeons, slippery floors, ice walls
- **Volcanic Depths**: Lava-filled dungeons, heat zones, fire enemies
- **Sunken Ruins**: Underwater dungeons, limited air, swimming mechanics
- **Sky Citadels**: Floating island dungeons, falling hazards, wind effects
- **Planar Rifts**: Otherworldly dungeons, reality distortions, alien geometry
- **Catacombs**: Dense bone-filled crypts, narrow passages, undead swarms
- **Research Labs**: Sci-fi/modern dungeons, security systems, experimental creatures

**Estimated Effort per Type**: 6-8 hours

### Modding Support

#### 9. Custom Dungeon API
**Description**: Allow modders to create custom dungeon types without code.

**Features**:
- Extended JSON schema for custom generators
- Hook system for custom generation logic
- Asset loading for custom tiles/enemies

**Estimated Effort**: 15-20 hours

#### 10. Dungeon Editor Tool
**Description**: Visual tool for designing dungeon layouts.

**Features**:
- Tile-based editor
- Feature placement
- Enemy/loot configuration
- Export to JSON

**Estimated Effort**: 20-30 hours

---

## Conclusion

This comprehensive plan transforms the dungeon generation system from a single hardcoded type into a flexible, data-driven architecture supporting 8 unique dungeon types with 7 different procedural generation algorithms. The phased approach ensures incremental progress with testable milestones, while the risk assessment identifies potential blockers and mitigation strategies.

**Key Success Factors**:
1. ✅ Complete Phase 1 before starting Phase 2 (solid foundation)
2. ✅ Extensive testing of each generator algorithm
3. ✅ Playtest all dungeon types for balance and feel
4. ✅ Performance profiling early and often
5. ✅ Clear documentation for future maintainers

**Expected Outcomes**:
- **Gameplay**: 8 unique dungeon experiences with distinct aesthetics and mechanics
- **Replayability**: Deterministic yet varied dungeons for each playthrough
- **Extensibility**: Easy to add new dungeon types via JSON
- **Performance**: Efficient generation with caching and optimization
- **Player Engagement**: Discovery system and progression tracking

**Estimated Completion**: 4 weeks for full implementation and testing

**Next Steps**: Review plan with team, prioritize phases, begin Phase 1 implementation.

---

**Document Version**: 1.0
**Last Updated**: 2026-01-02
**Author**: Claude (AI Assistant)
**Status**: Ready for Review

