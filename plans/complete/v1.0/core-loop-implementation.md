# Core Loop Implementation Plan - Roguelike Survival Game

**Scope**: Tasks 1.1-1.6 (Project Setup through Player Movement)
**Approach**: Modular parallel implementation tracks
**Goal**: Playable core loop - walk around procedurally generated world with day/night cycle

---

## Implementation Strategy

This plan organizes work into **3 parallel tracks** that can be developed independently, then integrated:

- **Track A**: Core Infrastructure (Turn System, Events, Game Loop)
- **Track B**: Rendering & Visuals (ASCII renderer, camera, FOV)
- **Track C**: World & Maps (Procedural generation, map system, transitions)

After parallel development, **Track D** integrates everything with the player entity and movement.

---

## TRACK A: Core Infrastructure

### A1. Project Initialization
**Files to create:**
- `project.godot` (Godot 4 project file)
- `.gitignore` (exclude .godot/, .import/)

**Actions:**
1. Open Godot 4.x and create new project at current directory
2. Set project settings:
   - Display > Window > Size > Width: 1280, Height: 720
   - Display > Window > Stretch > Mode: "canvas_items"
   - Input Map: Configure WASD + Arrow keys for movement (ui_up, ui_down, ui_left, ui_right)

### A2. Folder Structure
**Create directory structure:**
```
res://
├── autoload/
├── entities/
├── systems/
├── maps/
├── generation/
│   └── dungeon_generators/
├── rendering/
│   └── tilesets/
├── ui/
├── data/
│   └── biomes/
└── scenes/
```

### A3. Event Bus (Autoload)
**File**: `res://autoload/event_bus.gd`

**Purpose**: Central signal hub for loose coupling between systems

**Key Signals:**
```gdscript
signal turn_advanced(turn_number: int)
signal time_of_day_changed(period: String)  # "dawn", "day", "dusk", "night"
signal player_moved(old_pos: Vector2i, new_pos: Vector2i)
signal map_changed(map_id: String)
```

**Implementation:**
- Singleton pattern via Godot autoload
- Pure signal relay (no game logic)

### A4. Turn Manager (Autoload)
**File**: `res://autoload/turn_manager.gd`

**Purpose**: Controls turn-based game flow and day/night cycle

**Key Properties:**
- `current_turn: int` (starts at 0)
- `time_of_day: String` (dawn/day/dusk/night)
- `is_player_turn: bool`

**Key Methods:**
- `advance_turn()` - Increments turn, emits signals, updates time of day
- `get_time_of_day() -> String` - Returns current period based on turn % 1000
- `wait_for_player()` - Blocks until player takes action

**Day/Night Mapping:**
- Dawn: 0-150
- Day: 150-700
- Dusk: 700-850
- Night: 850-1000
- Wraps at 1000 (modulo arithmetic)

**Integration**: Emits `EventBus.turn_advanced` and `EventBus.time_of_day_changed`

### A5. Game Manager (Autoload)
**File**: `res://autoload/game_manager.gd`

**Purpose**: High-level game state and coordination

**Key Properties:**
- `world_seed: int` (generated or loaded)
- `game_state: String` ("menu", "playing", "paused")
- `current_map_id: String`

**Key Methods:**
- `start_new_game(seed: int = -1)` - Initialize new game (random seed if -1)
- `set_current_map(map_id: String)` - Track active map

**Integration**: Coordinates between TurnManager and MapManager

### A6. Autoload Configuration
**File**: `project.godot` (manual edit or via Godot editor)

**Configure autoloads (in order):**
1. EventBus - `res://autoload/event_bus.gd`
2. TurnManager - `res://autoload/turn_manager.gd`
3. GameManager - `res://autoload/game_manager.gd`

---

## TRACK B: Rendering & Visuals

### B1. Render Interface (Abstract Base)
**File**: `res://rendering/render_interface.gd`

**Purpose**: Abstract rendering layer - game logic never touches visuals directly

**Key Methods (virtual, must override):**
```gdscript
func render_tile(position: Vector2i, tile_type: String, variant: int = 0) -> void
func render_entity(position: Vector2i, entity_type: String, color: Color) -> void
func clear_entity(position: Vector2i) -> void
func update_fov(visible_tiles: Array[Vector2i]) -> void
func center_camera(position: Vector2i) -> void
```

**Design Pattern**: Strategy pattern - swap renderers without changing game logic

### B2. ASCII Tileset Creation
**File**: `res://rendering/tilesets/ascii_tileset.tres` (TileSet resource)

**Approach**: Programmatic generation using Godot's Image API

**Character Map (Phase 1 Core Loop):**
- `@` - Player (bright yellow)
- `.` - Floor (gray)
- `#` - Wall (white)
- `+` - Door (brown)
- `>` - Stairs down (cyan)
- `<` - Stairs up (cyan)
- `T` - Tree (green)
- `~` - Water (blue)

**Implementation Steps:**
1. Create 16x16 sprite for each ASCII character using bitmap font or draw programmatically
2. Use monospace font (IBM Plex Mono or similar)
3. Create TileSet with atlas, assign each tile an ID
4. Store tile ID mapping in ASCIIRenderer (e.g., `tile_map = {"@": 0, ".": 1, ...}`)

**Alternative**: Use TileMapLayer's built-in font rendering if supported

### B3. ASCII Renderer
**File**: `res://rendering/ascii_renderer.gd`

**Purpose**: Concrete implementation of RenderInterface using TileMapLayer

**Node Structure:**
```
ASCIIRenderer (Node2D)
├── TerrainLayer (TileMapLayer)
├── EntityLayer (TileMapLayer)
└── Camera (Camera2D)
```

**Key Properties:**
- `terrain_layer: TileMapLayer` - Renders floors, walls, terrain
- `entity_layer: TileMapLayer` - Renders player, enemies, items (separate for easy clearing)
- `camera: Camera2D` - Follows player
- `tile_map: Dictionary` - Maps character strings to tile IDs
- `visible_tiles: Array[Vector2i]` - Tracks FOV for dimming/hiding

**Key Methods:**
```gdscript
func render_tile(position: Vector2i, tile_type: String, variant: int = 0):
    var tile_id = tile_map.get(tile_type, 0)
    terrain_layer.set_cell(position, 0, Vector2i(tile_id, 0))

func render_entity(position: Vector2i, entity_type: String, color: Color):
    var tile_id = tile_map.get(entity_type, 0)
    entity_layer.set_cell(position, 0, Vector2i(tile_id, 0))
    # Apply color modulation if TileMapLayer supports it

func center_camera(position: Vector2i):
    camera.position = position * TILE_SIZE  # e.g., 16px per tile

func update_fov(visible_tiles: Array[Vector2i]):
    # Dim/hide tiles outside FOV
    # Can use TileMapLayer's modulate or custom shader
```

**Integration**: Instantiated in main game scene, receives rendering commands from game logic

### B4. FOV (Field of View) System
**File**: `res://systems/fov_system.gd`

**Purpose**: Calculate visible tiles based on player position and perception range

**Algorithm**: Shadowcasting or simple radial distance check (for Phase 1)

**Key Method:**
```gdscript
func calculate_fov(origin: Vector2i, range: int, map: Map) -> Array[Vector2i]:
    # Returns array of visible tile positions
    # Blocked by opaque tiles (walls)
```

**Day/Night Integration:**
- Night (850-1000): Reduce perception range by 50%
- Day (150-700): Normal range
- Dawn/Dusk: Slight reduction (25%)

**Note**: For Core Loop, can use simple circle check. Full shadowcasting in later phase.

### B5. Camera System
**File**: Built into ASCIIRenderer

**Behavior:**
- Follow player position (centered)
- Smooth following (optional lerp)
- Constrain to map bounds (prevent showing void)

**Implementation:**
```gdscript
func _process(delta):
    if player_position:
        camera.position = lerp(camera.position, player_position * TILE_SIZE, 0.1)
```

---

## TRACK C: World & Maps

### C1. Tile Data Structure
**File**: `res://maps/tile_data.gd`

**Purpose**: Represents a single tile's properties

**Properties:**
```gdscript
class_name TileData

var tile_type: String  # "floor", "wall", "tree", "water", "stairs_down", etc.
var walkable: bool
var transparent: bool  # For FOV
var ascii_char: String  # "@", "#", ".", etc.
```

**Factory Method:**
```gdscript
static func create(type: String) -> TileData:
    # Returns TileData with properties based on type
```

### C2. Map Class
**File**: `res://maps/map.gd`

**Purpose**: Holds a single map's tiles and metadata

**Properties:**
```gdscript
class_name Map

var map_id: String  # "overworld" or "dungeon_barrow_1_floor_5"
var width: int
var height: int
var tiles: Array  # 2D array of TileData (or Dictionary with Vector2i keys)
var seed: int  # Seed used to generate this map
var entities: Array  # Placeholder for future (Track D needs this)
```

**Key Methods:**
```gdscript
func get_tile(pos: Vector2i) -> TileData
func set_tile(pos: Vector2i, tile: TileData)
func is_walkable(pos: Vector2i) -> bool
func is_transparent(pos: Vector2i) -> bool
```

### C3. Map Manager (Autoload)
**File**: `res://autoload/map_manager.gd`

**Purpose**: Manages multiple maps, handles transitions, caching

**Properties:**
```gdscript
var loaded_maps: Dictionary  # map_id -> Map
var current_map: Map
```

**Key Methods:**
```gdscript
func get_or_generate_map(map_id: String, seed: int) -> Map:
    # Check cache first, generate if missing
    if map_id in loaded_maps:
        return loaded_maps[map_id]
    else:
        var map = _generate_map(map_id, seed)
        loaded_maps[map_id] = map
        return map

func transition_to_map(map_id: String):
    current_map = get_or_generate_map(map_id, GameManager.world_seed)
    EventBus.emit_signal("map_changed", map_id)
    # Re-render entire map via renderer
```

**Integration**: Add to autoloads in `project.godot` (after GameManager)

### C4. Seeded Random Wrapper
**File**: `res://generation/seeded_random.gd`

**Purpose**: Deterministic random number generation

**Implementation:**
```gdscript
class_name SeededRandom

var rng: RandomNumberGenerator

func _init(seed: int):
    rng = RandomNumberGenerator.new()
    rng.seed = seed

func randi() -> int:
    return rng.randi()

func randf() -> float:
    return rng.randf()

func randi_range(from: int, to: int) -> int:
    return rng.randi_range(from, to)

func randf_range(from: float, to: float) -> float:
    return rng.randf_range(from, to)
```

**Usage**: Pass seed to generators, ensures same seed = same world

### C5. Overworld Generator
**File**: `res://generation/world_generator.gd`

**Purpose**: Generate 100x100 overworld with temperate woodland biome

**Dependencies**: Gaea plugin (user installs manually - see instructions below)

**Key Method:**
```gdscript
static func generate_overworld(seed: int) -> Map:
    var rng = SeededRandom.new(seed)
    var map = Map.new()
    map.map_id = "overworld"
    map.width = 100
    map.height = 100
    map.seed = seed

    # Use Gaea for heightmap/noise generation
    # For Phase 1: Simple approach
    for y in range(100):
        for x in range(100):
            var noise_val = _get_gaea_noise(x, y, seed)  # Gaea integration
            var tile_type = _biome_from_noise(noise_val)  # Map to woodland tiles
            map.set_tile(Vector2i(x, y), TileData.create(tile_type))

    # Place dungeon entrance (random location, walkable tile)
    var entrance_pos = _find_valid_location(map, rng)
    map.set_tile(entrance_pos, TileData.create("stairs_down"))

    return map
```

**Biome Logic (Temperate Woodland):**
- 60% floor (grass/dirt)
- 30% trees
- 5% water (ponds/streams)
- 5% special (rocks, flowers)

**Gaea Integration Notes:**
- If Gaea is complex: Start with Godot's built-in `FastNoiseLite` for Phase 1
- Gaea research can happen in parallel with other tracks
- Fallback: Use simple Perlin noise without Gaea initially

### C6. Burial Barrow Generator
**File**: `res://generation/dungeon_generators/burial_barrow.gd`

**Purpose**: Generate dungeon floors (1-50 depth) with rectangular rooms and corridors

**Key Method:**
```gdscript
static func generate_floor(world_seed: int, floor_number: int) -> Map:
    # Combine world seed + floor number for unique but deterministic seed
    var floor_seed = hash([world_seed, "barrow", floor_number])
    var rng = SeededRandom.new(floor_seed)

    var map = Map.new()
    map.map_id = "dungeon_barrow_floor_%d" % floor_number
    map.width = 50
    map.height = 50
    map.seed = floor_seed

    # 1. Fill with walls
    # 2. Generate 5-10 rectangular rooms
    # 3. Connect with corridors (BSP or simple pathfinding)
    # 4. Place stairs up (entrance)
    # 5. Place stairs down (exit to next floor, unless floor 50)

    return map
```

**Room Generation Algorithm (Simple):**
1. Divide floor into grid
2. Place random-sized rectangles (rooms)
3. Carve corridors between room centers
4. Ensure all rooms connected

**Future**: Add tomb alcoves, cave-ins, loot spawns (Phase 1 just walkable dungeon)

### C7. Map Regeneration Test
**File**: `res://tests/regeneration_test.gd` (optional unit test)

**Purpose**: Verify same seed produces identical map

**Test:**
```gdscript
func test_deterministic_generation():
    var map1 = WorldGenerator.generate_overworld(12345)
    var map2 = WorldGenerator.generate_overworld(12345)
    assert_tiles_equal(map1, map2)
```

---

## TRACK D: Integration & Player

**Prerequisites**: Tracks A, B, C must be complete

### D1. Entity Base Class
**File**: `res://entities/entity.gd`

**Purpose**: Base class for all game entities (player, enemies, NPCs, items)

**Properties:**
```gdscript
class_name Entity

var entity_id: String
var position: Vector2i
var ascii_char: String
var color: Color
var blocks_movement: bool
```

**Note**: For Core Loop, minimal implementation. Full component system in Phase 1.7

### D2. Player Entity
**File**: `res://entities/player.gd`

**Extends**: Entity

**Additional Properties:**
```gdscript
var attributes: Dictionary  # STR, DEX, CON, INT, WIS, CHA (stub for now)
var perception_range: int = 10
```

**Key Methods:**
```gdscript
func move(direction: Vector2i) -> bool:
    var new_pos = position + direction
    if MapManager.current_map.is_walkable(new_pos):
        position = new_pos
        EventBus.emit_signal("player_moved", position - direction, position)
        return true
    return false

func interact_with_tile() -> void:
    var tile = MapManager.current_map.get_tile(position)
    if tile.tile_type == "stairs_down":
        _descend_stairs()
    elif tile.tile_type == "stairs_up":
        _ascend_stairs()

func _descend_stairs():
    # Transition to dungeon or next floor
    # Emit map change event

func _ascend_stairs():
    # Return to previous floor or overworld
```

### D3. Input Handler
**File**: `res://systems/input_handler.gd`

**Purpose**: Convert keyboard input to player actions on player's turn

**Implementation:**
```gdscript
func _unhandled_input(event):
    if not TurnManager.is_player_turn:
        return

    if event.is_action_pressed("ui_up"):
        player.move(Vector2i.UP)
        TurnManager.advance_turn()
    elif event.is_action_pressed("ui_down"):
        player.move(Vector2i.DOWN)
        TurnManager.advance_turn()
    # ... similar for left, right
    elif event.is_action_pressed("ui_select"):  # e.g., Enter/Space
        player.interact_with_tile()
        TurnManager.advance_turn()
```

**Note**: Attach to main game scene node

### D4. Game Scene Setup
**File**: `res://scenes/game.tscn`

**Node Tree:**
```
Game (Node2D)
├── ASCIIRenderer (Node2D)
│   ├── TerrainLayer (TileMapLayer)
│   ├── EntityLayer (TileMapLayer)
│   └── Camera (Camera2D)
├── HUD (CanvasLayer)
│   └── TurnCounter (Label)
└── InputHandler (Node)
```

**Script**: `res://scenes/game.gd`

```gdscript
extends Node2D

var player: Player
var renderer: ASCIIRenderer

func _ready():
    # 1. Start new game
    GameManager.start_new_game()

    # 2. Generate overworld
    MapManager.transition_to_map("overworld")

    # 3. Create player
    player = Player.new()
    player.position = Vector2i(50, 50)  # Center of 100x100 map
    MapManager.current_map.entities.append(player)

    # 4. Initial render
    _render_map()
    renderer.render_entity(player.position, "@", Color.YELLOW)
    renderer.center_camera(player.position)

    # 5. Calculate initial FOV
    var visible = FOVSystem.calculate_fov(player.position, player.perception_range, MapManager.current_map)
    renderer.update_fov(visible)

    # 6. Connect signals
    EventBus.player_moved.connect(_on_player_moved)
    EventBus.map_changed.connect(_on_map_changed)
    EventBus.turn_advanced.connect(_on_turn_advanced)

func _render_map():
    for y in range(MapManager.current_map.height):
        for x in range(MapManager.current_map.width):
            var pos = Vector2i(x, y)
            var tile = MapManager.current_map.get_tile(pos)
            renderer.render_tile(pos, tile.ascii_char)

func _on_player_moved(old_pos, new_pos):
    renderer.clear_entity(old_pos)
    renderer.render_entity(new_pos, "@", Color.YELLOW)
    renderer.center_camera(new_pos)
    var visible = FOVSystem.calculate_fov(new_pos, player.perception_range, MapManager.current_map)
    renderer.update_fov(visible)

func _on_map_changed(map_id):
    _render_map()

func _on_turn_advanced(turn_number):
    $HUD/TurnCounter.text = "Turn: %d | %s" % [turn_number, TurnManager.time_of_day]
```

### D5. Main Menu Scene
**File**: `res://scenes/main_menu.tscn`

**Simple menu:**
- "Start New Game" button → Load game.tscn
- "Quit" button → Exit

**Script**: Connect button to `get_tree().change_scene_to_file("res://scenes/game.tscn")`

### D6. Main Scene
**File**: `res://scenes/main.tscn`

**Purpose**: Entry point, starts with main menu

**Set in project settings**: Project > Project Settings > Application > Run > Main Scene

---

## Gaea Plugin Installation Guide

**Note**: User will install manually before Track C implementation

### Option 1: Godot Asset Library (Recommended)
1. Open Godot 4.x editor
2. Click "AssetLib" tab (top center)
3. Search for "Gaea"
4. Click "Download" → "Install"
5. Enable plugin: Project > Project Settings > Plugins > Check "Gaea"

### Option 2: GitHub Manual Install
1. Visit: https://github.com/BenjaTK/Gaea
2. Download latest release (check Godot 4 compatibility)
3. Extract to `res://addons/gaea/`
4. Enable in Project Settings > Plugins

### Option 3: Fallback (No Gaea)
If Gaea doesn't suit roguelike generation or has issues:
- Use Godot's built-in `FastNoiseLite` for terrain
- Implement custom room/corridor algorithm without Gaea
- Gaea is optional for Phase 1 - can be added later

### Verification
After installation, test:
```gdscript
# In a test script
var gaea_generator = load("res://addons/gaea/generator.gd").new()
print("Gaea loaded successfully!")
```

---

## Implementation Order (Parallel + Sequential)

### Stage 1: Foundation (Parallel)
**Do in parallel (any order):**
- Track A1-A6: Autoloads, project setup
- Track B1-B2: Render interface, ASCII tileset
- Track C1-C4: Tile data, Map class, seeded random

**Outcome**: Core systems exist independently

### Stage 2: Rendering & Generation (Parallel)
**Do in parallel:**
- Track B3-B5: ASCII renderer, FOV, camera
- Track C5-C7: World generator, dungeon generator (after Gaea installed)

**Outcome**: Renderer can display maps, generators can create maps

### Stage 3: Integration (Sequential)
**Must do in order:**
1. D1: Entity base class
2. D2: Player entity
3. D3: Input handler
4. D4: Game scene setup
5. D5-D6: Main menu, main scene

**Outcome**: Playable game loop

---

## Testing Milestones

### Milestone 1: Turn System Works
**Test**: Run game, check turn counter increments, time of day changes every 1000 turns

**Verify**: Console logs or UI label showing turn number and time period

### Milestone 2: Map Renders
**Test**: Generate map, render to screen

**Verify**: See ASCII grid of terrain (walls, floors, trees)

### Milestone 3: Deterministic Generation
**Test**: Generate same seed twice, compare maps

**Verify**: Identical tile layout

### Milestone 4: Player Movement
**Test**: Press arrow keys, player @ symbol moves

**Verify**: Camera follows, FOV updates, turn advances

### Milestone 5: Map Transitions
**Test**: Walk onto stairs, press interact

**Verify**: Map changes, player appears in new location (dungeon or back to overworld)

### Milestone 6: Day/Night Cycle Affects Gameplay
**Test**: Wait 1000 turns (or manually set turn number)

**Verify**: FOV range changes between day/night

---

## Critical Files Summary

### Core Infrastructure (Track A)
- `project.godot` - Project configuration
- `res://autoload/event_bus.gd` - Signal hub
- `res://autoload/turn_manager.gd` - Turn system
- `res://autoload/game_manager.gd` - Game state
- `res://autoload/map_manager.gd` - Map management

### Rendering (Track B)
- `res://rendering/render_interface.gd` - Abstract base
- `res://rendering/ascii_renderer.gd` - ASCII implementation
- `res://rendering/tilesets/ascii_tileset.tres` - TileSet resource
- `res://systems/fov_system.gd` - Field of view

### World & Maps (Track C)
- `res://maps/tile_data.gd` - Tile properties
- `res://maps/map.gd` - Map data structure
- `res://generation/seeded_random.gd` - RNG wrapper
- `res://generation/world_generator.gd` - Overworld gen
- `res://generation/dungeon_generators/burial_barrow.gd` - Dungeon gen

### Integration (Track D)
- `res://entities/entity.gd` - Base entity
- `res://entities/player.gd` - Player entity
- `res://systems/input_handler.gd` - Input processing
- `res://scenes/game.tscn` - Main game scene
- `res://scenes/game.gd` - Game scene script
- `res://scenes/main_menu.tscn` - Menu
- `res://scenes/main.tscn` - Entry point

---

## Success Criteria

Core Loop is complete when:
1. ✅ Godot project runs without errors
2. ✅ Player can move with WASD/arrows
3. ✅ Overworld (100x100) renders in ASCII
4. ✅ Camera follows player
5. ✅ Turn counter increments on movement
6. ✅ Day/night cycle visible (time period text changes)
7. ✅ Dungeon entrance exists on overworld
8. ✅ Player can descend into dungeon
9. ✅ Dungeon has multiple floors (at least 3 testable)
10. ✅ Re-entering dungeon shows same layout (deterministic)
11. ✅ FOV shows only nearby tiles
12. ✅ Night reduces visibility range

---

## Next Steps After Core Loop

Once Core Loop is playable, continue with:
- **Phase 1.7**: Entity System (enemies)
- **Phase 1.8**: Combat
- **Phase 1.9**: Survival Systems
- **Phase 1.10**: Inventory
- **Phase 1.11**: Crafting
- ...continuing through Phase 1.17

---

## Notes & Considerations

### Gaea Uncertainty
If Gaea proves unsuitable for roguelike room/corridor generation:
- Fallback to custom BSP (Binary Space Partitioning) algorithm
- Use `FastNoiseLite` for organic overworld terrain
- Gaea is a nice-to-have, not blocking

### Performance
- 100x100 overworld = 10,000 tiles (manageable)
- 50x50 dungeon floors = 2,500 tiles (lightweight)
- Rendering via TileMapLayer is efficient in Godot 4
- No performance issues expected for Core Loop

### Architecture Validation
This Core Loop validates:
- ✅ Event-driven architecture (EventBus works)
- ✅ Render separation (game logic doesn't touch visuals)
- ✅ Seeded generation (deterministic maps)
- ✅ Turn-based game flow
- ✅ Map management and transitions

These are the foundational patterns for all future systems.

---

**End of Plan**
