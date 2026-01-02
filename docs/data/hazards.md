# Hazards Data Format

**Location**: `data/hazards/`
**File Count**: 12 files
**Loaded By**: HazardManager

## Overview

Hazards are dangerous dungeon elements including traps, environmental dangers, and magical wards. Each hazard definition specifies its appearance, trigger condition, damage, and whether it can be detected or disarmed. Hazards are placed during dungeon generation based on the `hazards` configuration.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique identifier (snake_case) | HazardManager |
| `name` | string | Display name | UI, messages |
| `ascii_char` | string | Display character | Renderer |
| `color` | string | Hex color code | Renderer |
| `trigger_type` | string | Activation method | HazardManager |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `hidden` | bool | false | Requires detection to see | FOVSystem |
| `damage_type` | string | "physical" | Type of damage dealt | CombatSystem |
| `base_damage` | int | 0 | Default damage amount | CombatSystem |
| `one_time` | bool | true | Deactivates after triggering | HazardManager |
| `can_disarm` | bool | false | Can be neutralized | HazardManager |
| `detection_difficulty` | int | 10 | Perception check DC | HazardManager |
| `disarm_difficulty` | int | 12 | Skill check DC | HazardManager |
| `effect` | string | "" | Status effect applied | SurvivalSystem |
| `duration` | int | 0 | Effect duration in turns | SurvivalSystem |
| `proximity_radius` | int | 1 | Trigger distance for proximity | HazardManager |
| `range` | int | 1 | Attack range for ranged | HazardManager |
| `radius` | int | 0 | Area of effect | HazardManager |

## Trigger Types

### `step`
Activates when entity moves onto the tile.

```json
"trigger_type": "step"
```

Used for: floor traps, pitfalls, pressure plates.

### `proximity`
Activates when entity enters radius.

```json
"trigger_type": "proximity",
"proximity_radius": 2
```

Used for: magical wards, curse zones, alarms.

### `pressure_plate`
Similar to step but may have delayed or mechanical effects.

```json
"trigger_type": "pressure_plate"
```

Used for: collapsing ceilings, dart traps.

### `line_of_sight`
Activates when entity is visible to hazard.

```json
"trigger_type": "line_of_sight",
"range": 10
```

Used for: arrow slits, turrets.

### `fire`
Activates when fire source is nearby.

```json
"trigger_type": "fire"
```

Used for: explosive gas, oil slicks.

## Damage Types

| Type | Description |
|------|-------------|
| `physical` | Standard physical damage |
| `fire` | Fire/heat damage |
| `poison` | Poison damage + effect |
| `magical` | Magical energy damage |
| `drowning` | Water-based damage |
| `cold` | Freezing damage |

## Hazard Categories

### Physical Traps

| ID | Trigger | Damage | Hidden | Disarmable |
|----|---------|--------|--------|------------|
| `floor_trap` | step | 10 | Yes | Yes |
| `pitfall` | step | 15 | Yes | No |
| `collapsing_ceiling` | pressure_plate | 20 | Yes | Yes |
| `unstable_ground` | step | 10 | Yes | No |

### Ranged Hazards

| ID | Trigger | Damage | Range |
|----|---------|--------|-------|
| `arrow_slit` | line_of_sight | 8 | 10 |

### Environmental Hazards

| ID | Trigger | Damage | Effect |
|----|---------|--------|--------|
| `toxic_water` | step | 3/turn | poison |
| `explosive_gas` | fire | 30 | area |
| `sudden_flood` | step | 0 | trap |

### Magical Hazards

| ID | Trigger | Damage | Hidden |
|----|---------|--------|--------|
| `magical_ward` | proximity | 15 | Yes |
| `curse_zone` | proximity | 0 | No |
| `disease_zone` | step | 0 | No |
| `divine_curse` | step | 5 | Yes |

## Complete Examples

### Hidden Step Trap

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

### Proximity Magical Ward

```json
{
  "id": "magical_ward",
  "name": "Magical Ward",
  "ascii_char": "*",
  "color": "#00FFFF",
  "hidden": true,
  "trigger_type": "proximity",
  "proximity_radius": 1,
  "damage_type": "magical",
  "base_damage": 15,
  "one_time": true,
  "can_disarm": true,
  "detection_difficulty": 16,
  "disarm_difficulty": 18
}
```

### Effect-Only Hazard

```json
{
  "id": "curse_zone",
  "name": "Curse Zone",
  "ascii_char": "~",
  "color": "#800080",
  "hidden": false,
  "trigger_type": "proximity",
  "proximity_radius": 1,
  "damage_type": "magical",
  "base_damage": 0,
  "one_time": true,
  "effect": "stat_drain",
  "duration": 100,
  "can_disarm": false
}
```

### Fire-Triggered Area Hazard

```json
{
  "id": "explosive_gas",
  "name": "Explosive Gas",
  "ascii_char": "*",
  "color": "#FFA500",
  "hidden": false,
  "trigger_type": "fire",
  "damage_type": "fire",
  "base_damage": 30,
  "one_time": true,
  "radius": 3,
  "can_disarm": false
}
```

## Hazard Placement

Hazards are placed via dungeon `hazards` configuration:

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

### Placement Properties

| Property | Description |
|----------|-------------|
| `hazard_id` | Must match a hazard definition |
| `density` | Hazards per floor tile (0.01 = 1%) |
| `damage` | Override base_damage |
| `detection_difficulty` | Override detection DC |
| `effect` | Override status effect |
| `duration` | Override effect duration |

### Density Calculation

```
Hazard Count = floor_positions × density
Clamped to: 1-10 hazards per type
```

Example: 2500 floor tiles × 0.01 density = 25 → clamped to 10 hazards.

## Detection System

Hidden hazards require perception checks to reveal.

### Detection Check

```
If perception >= detection_difficulty:
  Hazard becomes visible (detected = true)
```

### Detection Difficulty Guidelines

| Difficulty | Perception Needed | Example |
|------------|-------------------|---------|
| 10 | Low | Obvious tripwire |
| 12 | Medium | Standard floor trap |
| 15 | High | Well-hidden pit |
| 18 | Very High | Magical ward |

## Disarming System

Detected hazards with `can_disarm: true` can be neutralized.

### Disarm Check

```
If skill_value >= disarm_difficulty:
  Hazard neutralized (disarmed = true)
Else:
  Disarm failed, hazard triggers!
```

**Warning**: Failed disarm attempts trigger the hazard.

## Hazard States

Each placed hazard tracks:

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

### State Transitions

```
Hidden → Detected (perception check)
Detected → Disarmed (successful disarm)
Detected → Triggered (failed disarm)
Any → Triggered (trigger condition met)
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

## Validation Rules

1. `id` must be unique across all hazards
2. `id` should use snake_case format
3. `ascii_char` must be a single character
4. `color` must be valid hex format (#RRGGBB)
5. `trigger_type` must be valid type
6. `detection_difficulty` typically 10-20
7. `disarm_difficulty` typically 12-20
8. `density` should be 0.001-0.05 (reasonable coverage)

## Related Documentation

- [Hazard Manager](../systems/hazard-manager.md) - Hazard system mechanics
- [Dungeons Data](./dungeons.md) - Dungeon hazards config
- [Combat System](../systems/combat-system.md) - Damage application
- [Survival System](../systems/survival-system.md) - Status effects
