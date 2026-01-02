# Game Manager

**Source File**: `autoload/game_manager.gd`
**Type**: Autoload Singleton

## Overview

The Game Manager handles high-level game state including world seed generation, game state transitions, and coordination between major systems. It manages the overall game lifecycle from new game creation to pause/resume.

## Key Concepts

- **World Seed**: Deterministic seed for procedural generation
- **Game State**: Current state (menu, playing, paused)
- **World Name**: Player-provided or generated world identifier

## Core Properties

```gdscript
var world_seed: int = 0                    # Seed for all generation
var world_name: String = ""                # World display name
var game_state: String = "menu"            # Current state
var current_map_id: String = ""            # Active map ID
var is_loading_save: bool = false          # Load operation in progress
var last_overworld_position: Vector2i      # Position before entering dungeon
```

## Game States

| State | Description |
|-------|-------------|
| `menu` | Main menu, no game active |
| `playing` | Active gameplay |
| `paused` | Game paused |

## Core Functions

### Starting New Game

```gdscript
GameManager.start_new_game(world_name)
```

**With World Name**:
```gdscript
GameManager.start_new_game("My Adventure")
# Uses hash of name as seed
# world_seed = abs("My Adventure".hash())
```

**Without World Name**:
```gdscript
GameManager.start_new_game("")
# Generates random seed
# world_name = "World 1234"
```

### New Game Process

1. Generate or hash world seed
2. Set world name
3. Set game_state to "playing"
4. Reset TurnManager
5. Clear map cache
6. Clear chunk cache
7. Reset overworld position

### Setting Current Map

```gdscript
GameManager.set_current_map("burial_barrow_floor_1")
```

Updates current_map_id tracking.

### Pause/Resume

```gdscript
GameManager.pause_game()   # playing -> paused
GameManager.resume_game()  # paused -> playing
```

## Seed Generation

### From World Name

```gdscript
world_seed = abs(world_name_input.hash())
if world_seed == 0:
    world_seed = 12345  # Fallback for unlikely hash collision
```

### Random Generation

```gdscript
randomize()
world_seed = randi()
world_name = "World %d" % (world_seed % 10000)
```

## Deterministic Generation

The world seed ensures consistent procedural generation:

```
world_seed
    ├── Overworld terrain (via ChunkManager)
    ├── Town placement (via SpecialFeaturePlacer)
    ├── Dungeon entrances (via SpecialFeaturePlacer)
    └── Dungeon floors (seed + floor_number)
```

Same seed always produces same world.

## Initialization

At startup:
```gdscript
func _ready():
    _HarvestSystem.load_resources()
    print("GameManager initialized")
```

Loads harvestable resources on game start.

## Integration with Other Systems

- **TurnManager**: Reset on new game
- **MapManager**: Clear cache on new game
- **ChunkManager**: Clear chunks on new game
- **HarvestSystem**: Load resources at startup
- **SaveManager**: Provides state for serialization

## State Checks

```gdscript
# Check if game is active
if GameManager.game_state == "playing":
    # Process game logic

# Check if in dungeon
if GameManager.current_map_id != "overworld":
    # In dungeon

# Check if loading
if GameManager.is_loading_save:
    # Skip normal initialization
```

## Overworld Position Tracking

When entering a dungeon, store the overworld position:
```gdscript
GameManager.last_overworld_position = player.position
```

When exiting dungeon, restore position.

## Related Documentation

- [Save Manager](./save-manager.md) - Save/load state
- [Map Manager](./map-manager.md) - Map transitions
- [Turn Manager](./turn-manager.md) - Turn tracking
- [Chunk Manager](./chunk-manager.md) - World generation
