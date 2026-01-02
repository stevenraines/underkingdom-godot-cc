# Turn Manager

**Source File**: `autoload/turn_manager.gd`
**Type**: Autoload Singleton

## Overview

The Turn Manager controls the turn-based game flow and day/night cycle. It manages the turn counter, coordinates entity turns, processes survival systems, and tracks time of day. The game only advances when the player takes an action.

## Key Concepts

- **Turn**: Single unit of game time, advanced by player actions
- **Day Cycle**: 100 turns per day (dawn → day → dusk → night)
- **Turn Processing**: Player → Survival → Enemies → Resources

## Core Properties

```gdscript
var current_turn: int = 0           # Total turns elapsed
var current_day: int = 1            # Day counter
var time_of_day: String = "dawn"    # Current period
var is_player_turn: bool = true     # Player can act
```

## Day/Night Cycle

| Period | Start Turn | End Turn | Duration |
|--------|------------|----------|----------|
| Dawn | 0 | 15 | 15 turns |
| Day | 15 | 70 | 55 turns |
| Dusk | 70 | 85 | 15 turns |
| Night | 85 | 100 | 15 turns |

**Total**: 100 turns = 1 day

### Time Calculation

```gdscript
var turn_in_day = current_turn % TURNS_PER_DAY
```

Time period affects:
- Visibility range
- Enemy spawn rates
- Survival drain rates

## Turn Flow

```
Player takes action (move, attack, interact, wait)
    ↓
TurnManager.advance_turn()
    ↓
current_turn += 1
    ↓
_update_time_of_day()
    ↓
_process_player_survival()
    ↓
EntityManager.process_entity_turns()
    ↓
HarvestSystem.process_renewable_resources()
    ↓
EventBus.turn_advanced.emit()
    ↓
is_player_turn = true
```

## Core Functions

### Advancing Turns

```gdscript
TurnManager.advance_turn()
```

Called after each player action. Triggers all per-turn processing.

### Getting Time of Day

```gdscript
var period = TurnManager.get_time_of_day()
# Returns: "dawn", "day", "dusk", or "night"
```

### Waiting for Player

```gdscript
await TurnManager.wait_for_player()
```

Blocks until player completes their turn.

## Survival Processing

Each turn processes player survival:

```gdscript
func _process_player_survival():
    var effects = player.process_survival_turn(current_turn)
    player.regenerate_stamina()

    for warning in effects.get("warnings", []):
        EventBus.survival_warning.emit(warning, severity)
```

### Warning Severities

| Severity | Keywords |
|----------|----------|
| `critical` | "dying", "death", "starving to" |
| `severe` | "starving", "dehydrated", "freezing", "overheating" |
| `warning` | "very", "severely" |
| `minor` | Other warnings |

## Day Transitions

When transitioning from night to dawn:

```gdscript
if time_of_day == "night" and new_time == "dawn":
    current_day += 1
    print("Day %d has begun" % current_day)
```

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `turn_advanced` | turn_number: int | Emitted via EventBus each turn |
| `time_of_day_changed` | period: String | Emitted via EventBus on period change |

## Constants

```gdscript
const DAWN_START = 0
const DAWN_END = 15
const DAY_START = 15
const DAY_END = 70
const DUSK_START = 70
const DUSK_END = 85
const NIGHT_START = 85
const NIGHT_END = 100
const TURNS_PER_DAY = 100
```

## Integration with Other Systems

- **EntityManager**: Processes all enemy turns
- **SurvivalSystem**: Drains survival stats each turn
- **HarvestSystem**: Respawns renewable resources
- **EventBus**: Emits turn and time signals

## Time of Day Effects

| Period | Visibility | Survival | Enemies |
|--------|------------|----------|---------|
| Dawn | Normal | Normal | Sparse |
| Day | Maximum | Normal | Normal |
| Dusk | Reduced | Normal | Increasing |
| Night | Minimum | Faster drain | Maximum |

## Related Documentation

- [Survival System](./survival-system.md) - Turn-based survival processing
- [Combat System](./combat-system.md) - Combat turn resolution
- [Event Bus](./event-bus.md) - Signal system
