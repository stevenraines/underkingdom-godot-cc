# Input Handler

**Source File**: `systems/input_handler.gd`
**Type**: Node Component

## Overview

The Input Handler converts keyboard input to player actions. It handles movement, combat, interactions, UI toggles, and special modes like targeting and look mode. Supports continuous movement while holding keys.

## Key Concepts

- **Turn-Based Input**: Actions advance the turn
- **Continuous Movement**: Hold keys to repeat movement
- **Input Modes**: Normal, targeting, look, harvest direction
- **UI Blocking**: Some UIs prevent game input

## Core Properties

```gdscript
var player: Player = null
var ui_blocking_input: bool = false

# Continuous movement
var move_delay: float = 0.12
var initial_delay: float = 0.2
var move_timer: float = 0.0
var blocked_direction: Vector2i = Vector2i.ZERO

# Special modes
var targeting_system = null
var look_mode_active: bool = false
var _awaiting_harvest_direction: bool = false
var current_target: Entity = null
```

## Keybindings

### Movement

| Key | Action |
|-----|--------|
| Arrow Keys / WASD | Move or attack |
| . (period) | Wait one turn (bonus stamina regen) |
| Shift+R | Rest menu (rest multiple turns) |
| Hold keys | Continuous movement |

### Navigation

| Key | Action |
|-----|--------|
| > (Shift+.) | Descend stairs / Enter dungeon |
| < (Shift+,) | Ascend stairs |

### Combat

| Key | Action |
|-----|--------|
| Tab | Cycle targets |
| R | Fire at current target |
| U | Clear current target |

### Interactions

| Key | Action |
|-----|--------|
| E | Interact with structure |
| F | Interact with dungeon feature |
| G | Toggle auto-pickup |
| O | Toggle auto-open doors |
| , (comma) | Manual pickup |
| H | Harvest (then direction) |
| T | Talk to adjacent NPC |
| X | Open/close adjacent door |
| Y | Pick lock / re-lock door or chest |

### UI

| Key | Action |
|-----|--------|
| I | Toggle inventory |
| C | Open crafting |
| B | Toggle build mode |
| M | Toggle world map |
| Shift+M | Toggle spellbook |
| K | Open spell casting (alias for Shift+M) |
| P | Character sheet |
| F1 / ? | Help screen |
| L | Look mode |

## Continuous Movement

Hold movement keys for repeated movement:

```gdscript
if direction != Vector2i.ZERO:
    move_timer -= delta
    if move_timer <= 0.0:
        var action_taken = _try_move_or_attack(direction)
        if action_taken:
            TurnManager.advance_turn()
        else:
            blocked_direction = direction  # Stop if blocked
        move_timer = initial_delay if is_initial_press else move_delay
```

- Initial delay: 0.2s before repeat starts
- Repeat delay: 0.12s between repeats
- Stops when blocked by obstacle

## Movement and Attack

```gdscript
func _try_move_or_attack(direction: Vector2i) -> bool:
    var target_pos = player.position + direction
    var blocking_entity = EntityManager.get_blocking_entity_at(target_pos)

    if blocking_entity and blocking_entity is Enemy:
        player.attack(blocking_entity)
        return true
    else:
        return player.move(direction)
```

Bump-to-attack: Moving into an enemy attacks them.

## Special Input Modes

### Targeting Mode

When targeting_system.is_active():
```gdscript
Tab/→/D: Cycle next target
←/A: Cycle previous target
Enter/Space/R/F: Confirm and fire
Escape: Cancel targeting
```

### Look Mode

When look_mode_active:
```gdscript
Tab/→/D: Cycle next object
←/A: Cycle previous object
Enter: Target if enemy
Escape: Exit look mode
```

### Harvest Mode

When _awaiting_harvest_direction:
```gdscript
Arrow/WASD: Harvest in direction
Escape: Cancel harvest
```

### Spell Targeting Mode

When spell_targeting_active (casting ranged spell):
```gdscript
Tab/→/D: Cycle next target
←/A: Cycle previous target
Enter/Space/R/F: Cast spell on target
Escape: Cancel spell targeting
```

Spell targeting is similar to ranged weapon targeting but casts the pending spell instead of firing a weapon.

## Wait Action

```gdscript
func _do_wait_action():
    player.regenerate_stamina()
    player.regenerate_stamina()  # Double regen for waiting
```

Waiting gives bonus stamina regeneration.

## Rest System

The rest menu (Shift+R) allows resting for multiple turns:

**Rest Options:**
1. **Until fully rested** - Rest until stamina is restored
2. **Until next time period** - Rest until dawn/day/dusk/night changes
3. **X turns** - Rest for a specific number of turns

**Interruption:**
- Rest is automatically interrupted if any event occurs
- Events are detected via the `message_logged` signal
- Combat, item pickups, or any logged message stops rest

```gdscript
# Rest is handled in game.gd
func _on_rest_requested(type: String, turns: int):
    is_resting = true
    rest_turns_remaining = turns
    # Connect to message_logged for interruption
    EventBus.message_logged.connect(_on_rest_interrupted_by_message)
```

## Stair Navigation

```gdscript
# Descend (> key)
if tile.tile_type == "dungeon_entrance":
    MapManager.enter_dungeon(dungeon_type)
elif tile.tile_type == "stairs_down":
    MapManager.descend_dungeon()

# Ascend (< key)
if tile.tile_type == "stairs_up":
    if MapManager.current_dungeon_floor == 1:
        # Return to overworld
    else:
        MapManager.ascend_dungeon()
```

## Target Cycling

```gdscript
func _cycle_target():
    var valid_targets = _get_valid_targets_in_range()
    var next_index = (current_index + 1) % valid_targets.size()
    _set_current_target(valid_targets[next_index])
```

Cycles through enemies within perception range.

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `target_changed` | target: Entity | Target selection changed |
| `look_object_changed` | obj | Look mode selection changed |

## Process vs Unhandled Input

- `_process()`: Continuous movement/waiting
- `_unhandled_input()`: Single-press actions

## UI Blocking

```gdscript
ui_blocking_input = true  # Block game input when UI is open
```

Set when:
- Targeting mode active
- Harvest direction prompt
- Modal UI screens

## Integration with Other Systems

- **Player**: Executes movement, attacks, interactions
- **TurnManager**: Advance turn after actions
- **EntityManager**: Query entities at positions
- **StructureManager**: Structure interactions
- **FeatureManager**: Feature interactions
- **RangedCombatSystem**: Ranged attacks

## Related Documentation

- [Targeting System](./targeting-system.md) - Target selection
- [Combat System](./combat-system.md) - Attack resolution
- [Player Entity](../entities/player.md) - Player actions
