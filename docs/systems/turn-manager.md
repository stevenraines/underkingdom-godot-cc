# Turn Manager

**Source File**: `autoload/turn_manager.gd`
**Type**: Autoload Singleton

## Overview

The Turn Manager controls the turn-based game flow and day/night cycle. It manages the turn counter, coordinates entity turns, processes survival systems, and tracks time of day. The game only advances when the player takes an action.

## Key Concepts

- **Turn**: Single unit of game time, advanced by player actions
- **Day Cycle**: Configurable via `data/calendar.json`, turns_per_day calculated from time period durations
- **Turn Processing**: Player → Survival → Enemies → Resources

## Core Properties

```gdscript
var current_turn: int = 0           # Total turns elapsed
var time_of_day: String = "dawn"    # Current period
var is_player_turn: bool = true     # Player can act
var _time_periods: Array = []       # Cached time periods from CalendarManager
```

## Day/Night Cycle

Time periods are defined in `data/calendar.json` as an array with durations. The total turns per day is automatically calculated from the sum of all period durations.

### Default Configuration (100 turns/day)

| Period | Duration | Start Turn | End Turn | Temp Modifier |
|--------|----------|------------|----------|---------------|
| Dawn | 15 | 0 | 15 | -5°F |
| Day | 27 | 15 | 42 | 0°F |
| Mid-day | 1 | 42 | 43 | +2°F |
| Day | 27 | 43 | 70 | 0°F |
| Dusk | 15 | 70 | 85 | -4°F |
| Night | 7 | 85 | 92 | -14°F |
| Midnight | 1 | 92 | 93 | -18°F |
| Night | 7 | 93 | 100 | -14°F |

**Total**: 100 turns = 1 day (calculated from sum of durations)

### Time Period Configuration

Time periods are defined in `data/calendar.json`:

```json
"time_periods": [
  { "id": "dawn", "duration": 15, "temp_modifier": -5 },
  { "id": "day", "duration": 27, "temp_modifier": 0 },
  { "id": "mid_day", "duration": 1, "temp_modifier": 2 },
  { "id": "day", "duration": 27, "temp_modifier": 0 },
  { "id": "dusk", "duration": 15, "temp_modifier": -4 },
  { "id": "night", "duration": 7, "temp_modifier": -14 },
  { "id": "midnight", "duration": 1, "temp_modifier": -18 },
  { "id": "night", "duration": 7, "temp_modifier": -14 }
]
```

- `duration`: Number of turns this period lasts
- `temp_modifier`: Temperature adjustment in °F for this period
- Start/end turns are computed automatically by CalendarManager

### Time Calculation

```gdscript
var turn_in_day = current_turn % CalendarManager.get_turns_per_day()
```

Time period affects:
- Visibility range
- Enemy spawn rates
- Survival drain rates
- Ambient temperature

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
# Returns: "dawn", "day", "mid_day", "dusk", "night", or "midnight"
```

### Getting Turns Per Day

```gdscript
var turns = TurnManager.get_turns_per_day()
# Returns turns_per_day from CalendarManager (calculated from time period durations)
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
    CalendarManager.advance_day(GameManager.world_seed)
    print("[TurnManager] %s" % CalendarManager.get_full_date_string())
```

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `turn_advanced` | turn_number: int | Emitted via EventBus each turn |
| `time_of_day_changed` | period: String | Emitted via EventBus on period change |

## Integration with Other Systems

- **CalendarManager**: Provides time period data and turns_per_day calculation
- **EntityManager**: Processes all enemy turns
- **SurvivalSystem**: Drains survival stats each turn
- **HarvestSystem**: Respawns renewable resources
- **EventBus**: Emits turn and time signals

## Time of Day Effects

| Period | Visibility | Survival | Enemies | Temperature |
|--------|------------|----------|---------|-------------|
| Dawn | Normal | Normal | Sparse | Cool (-5°F) |
| Day | Maximum | Normal | Normal | Base (0°F) |
| Mid-day | Maximum | Normal | Normal | Warm (+2°F) |
| Dusk | Reduced | Normal | Increasing | Cool (-4°F) |
| Night | Minimum | Faster drain | Maximum | Cold (-14°F) |
| Midnight | Minimum | Faster drain | Maximum | Coldest (-18°F) |

## Related Documentation

- [Survival System](./survival-system.md) - Turn-based survival processing
- [Combat System](./combat-system.md) - Combat turn resolution
- [Event Bus](./event-bus.md) - Signal system
- [Configuration](../data/configuration.md) - Game configuration including calendar
