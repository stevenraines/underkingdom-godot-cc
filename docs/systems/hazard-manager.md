# Hazard Manager

**Source File**: `autoload/hazard_manager.gd`
**Type**: Autoload Singleton
**Class Name**: `HazardManagerClass`

## Overview

The Hazard Manager handles dungeon hazards including traps, environmental dangers, and magical wards. Hazards are loaded from JSON definitions and placed during dungeon generation. They can be hidden (requiring detection), triggered by various conditions, and potentially disarmed by skilled players.

## Key Concepts

- **Hazard Definitions**: JSON templates defining hazard types
- **Active Hazards**: Runtime instances on current map
- **Trigger Types**: How hazards activate (step, proximity, pressure plate)
- **Detection**: Revealing hidden hazards based on perception
- **Disarming**: Safely neutralizing hazards

## Hazard States

Each hazard can be in multiple states:

| State | Description |
|-------|-------------|
| **Hidden** | Not visible to player (requires detection) |
| **Detected** | Visible but still dangerous |
| **Triggered** | Has activated (may be one-time) |
| **Disarmed** | Safely neutralized |

## Core Functionality

### Loading Definitions

```gdscript
HazardManager.hazard_definitions: Dictionary  # {hazard_id: definition}
```

All JSON files in `data/hazards/` are loaded at startup.

### Active Hazards

```gdscript
HazardManager.active_hazards: Dictionary  # {Vector2i: hazard_data}
```

### Trigger Checking

```gdscript
var result = HazardManager.check_hazard_trigger(position, entity)
# Returns: {triggered: bool, hazard_id, damage, damage_type, effects: [...]}
```

### Detection

```gdscript
var detected = HazardManager.try_detect_hazard(pos, perception)
# Returns: true if hazard was revealed
```

### Disarming

```gdscript
var result = HazardManager.try_disarm_hazard(pos, skill_value)
# Returns: {success: bool, message: String, triggered?: bool}
```

## Hazard Definition Structure

```json
{
  "id": "floor_trap",
  "name": "Floor Trap",
  "ascii_char": "^",
  "color": "#8B0000",
  "hidden": true,
  "trigger_type": "step",
  "damage_type": "physical",
  "base_damage": 10,
  "one_time": true,
  "can_disarm": true,
  "detection_difficulty": 12,
  "disarm_difficulty": 15
}
```

## Hazard Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | string | Unique identifier |
| `name` | string | Display name |
| `ascii_char` | string | Render character when visible |
| `color` | string | Hex color code |
| `hidden` | bool | Requires detection to see |
| `trigger_type` | string | Activation method |
| `damage_type` | string | Type of damage dealt |
| `base_damage` | int | Default damage amount |
| `one_time` | bool | Deactivates after triggering |
| `can_disarm` | bool | Can be neutralized |
| `detection_difficulty` | int | Perception check DC |
| `disarm_difficulty` | int | Skill check DC |
| `effect` | string | Status effect applied |
| `duration` | int | Effect duration in turns |
| `proximity_radius` | int | Trigger distance (proximity type) |
| `range` | int | Attack range (ranged hazards) |

## Trigger Types

### Step Trigger
Activates when entity moves onto tile.
```json
"trigger_type": "step"
```

### Proximity Trigger
Activates when entity enters radius.
```json
"trigger_type": "proximity",
"proximity_radius": 2
```

### Pressure Plate Trigger
Similar to step but may have delayed effect.
```json
"trigger_type": "pressure_plate"
```

### Line of Sight Trigger
Activates when entity is visible (arrow slits, etc.).
```json
"trigger_type": "line_of_sight",
"range": 10
```

## Damage Types

| Type | Description |
|------|-------------|
| `physical` | Standard physical damage |
| `fire` | Fire/heat damage |
| `poison` | Poison damage + effect |
| `magical` | Magical energy damage |
| `drowning` | Water-based damage |
| `cold` | Freezing damage |

## Detection System

Hidden hazards require perception checks to reveal.

### Detection Check
```
If perception >= detection_difficulty:
  Hazard becomes visible (detected = true)
```

Detection is checked:
- When player moves near hazard
- During active searching (future)
- Via special abilities

### Detection Difficulty
| Difficulty | Perception Needed | Example |
|------------|------------------|---------|
| 10 | Low | Obvious tripwire |
| 12 | Medium | Standard floor trap |
| 15 | High | Well-hidden pit |
| 18 | Very High | Magical ward |

## Disarming System

Detected hazards can be disarmed if `can_disarm: true`.

### Disarm Check
```
If skill_value >= disarm_difficulty:
  Hazard neutralized (disarmed = true)
Else:
  Disarm failed, hazard triggers!
```

**Warning**: Failed disarm attempts trigger the hazard!

## Hazard Placement

Hazards are placed by dungeon generators based on `hazards` in dungeon definition:

```json
"hazards": [
  {
    "hazard_id": "floor_trap",
    "density": 0.01,
    "damage": 10,
    "detection_difficulty": 15
  }
]
```

### Density Calculation
```
Hazard Count = floor_positions × density
Clamped to: 1-10 hazards per type
```

## Trigger Result

When triggered, hazards return:

```gdscript
{
  "triggered": true,
  "hazard_id": "floor_trap",
  "damage": 10,
  "damage_type": "physical",
  "effects": [
    {"type": "poison", "duration": 100}
  ]
}
```

## Proximity Hazard Checking

For proximity triggers, check all hazards in area:

```gdscript
var triggered = HazardManager.check_proximity_hazards(center, max_radius, entity)
# Returns: Array of trigger results
```

## Hazard State Persistence

Each active hazard tracks:

```gdscript
{
  "hazard_id": "floor_trap",
  "position": Vector2i,
  "definition": {...},
  "config": {...},
  "triggered": false,
  "detected": false,
  "disarmed": false,
  "damage": 10
}
```

Stored in `map.metadata.hazards` for save/load.

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `hazard_triggered` | hazard_id, position, target, damage | When hazard activates |
| `hazard_detected` | hazard_id, position | When hazard revealed |
| `hazard_disarmed` | hazard_id, position | When hazard neutralized |

## Current Hazard Types

| ID | Name | Trigger | Damage | Hidden | Disarmable |
|----|------|---------|--------|--------|------------|
| `floor_trap` | Floor Trap | step | 10 | Yes | Yes |
| `pitfall` | Pitfall | step | 15 | Yes | No |
| `arrow_slit` | Arrow Slit | line_of_sight | 8 | No | No |
| `curse_zone` | Curse Zone | step | 0 | No | No (effect) |
| `disease_zone` | Disease Zone | step | 0 | No | No (effect) |
| `divine_curse` | Divine Curse | step | 5 | Yes | No |
| `explosive_gas` | Explosive Gas | proximity | 20 | No | Yes |
| `toxic_water` | Toxic Water | step | 3/turn | No | No |
| `unstable_ground` | Unstable Ground | step | 10 | Yes | No |
| `collapsing_ceiling` | Collapsing Ceiling | pressure_plate | 20 | Yes | Yes |
| `sudden_flood` | Sudden Flood | step | 0 | Yes | No (trap) |
| `magical_ward` | Magical Ward | proximity | 15 | Yes | Yes |

## Integration with Other Systems

- **DungeonManager**: Calls hazard processing after generation
- **MapManager**: Triggers hazard loading on map change
- **Player**: Triggers hazard checks on movement
- **FOVSystem**: Detection based on visibility
- **SurvivalSystem**: Status effects from hazards

## Data Dependencies

- **Hazards** (`data/hazards/`): Hazard definitions

## Related Documentation

- [Hazards Data](../data/hazards.md) - Hazard file format
- [Dungeon Manager](./dungeon-manager.md) - Hazard placement
- [Combat System](./combat-system.md) - Damage application
