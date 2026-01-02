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

