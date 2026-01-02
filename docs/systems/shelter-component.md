# Shelter Component

**Source File**: `systems/components/shelter_component.gd`
**Type**: Component Class
**Class Name**: `ShelterComponent`

## Overview

The Shelter Component provides protection from weather and mild temperature bonuses for structures like lean-tos. It defines a sheltered area where the player is protected from environmental effects.

## Key Concepts

- **Shelter Radius**: Protected area around structure (Manhattan distance)
- **Temperature Bonus**: Mild warming effect from shelter
- **Rain Blocking**: Future weather system integration

## Core Properties

```gdscript
var shelter_radius: int = 2          # Tiles (Manhattan distance)
var temperature_bonus: float = 5.0   # Degrees Fahrenheit
var blocks_rain: bool = true         # Future: weather system
```

## Default Values

| Property | Default | Description |
|----------|---------|-------------|
| `shelter_radius` | 2 | Protected tiles in each direction |
| `temperature_bonus` | 5.0 | °F added when sheltered |
| `blocks_rain` | true | Prevents rain effects |

## Area of Effect

### Shelter Check

Uses Manhattan distance (taxicab geometry):

```gdscript
func is_sheltered(shelter_pos: Vector2i, target_pos: Vector2i) -> bool:
    var distance = abs(target_pos.x - shelter_pos.x) + abs(target_pos.y - shelter_pos.y)
    return distance <= shelter_radius
```

### Visual Representation

```
    2
  2 1 2
2 1 S 1 2
  2 1 2
    2
```

S = Shelter structure, Numbers = Manhattan distance

With `shelter_radius = 2`, all numbered positions are sheltered.

## Shelter vs Fire Comparison

| Feature | Fire Component | Shelter Component |
|---------|----------------|-------------------|
| Default radius | 3 tiles | 2 tiles |
| Temperature bonus | +15.0°F | +5.0°F |
| Primary purpose | Cooking, warmth | Weather protection |
| State toggle | Can extinguish | Always active |
| Future effects | Light source | Rain blocking |

## Usage by Survival System

```gdscript
# In survival_system.gd
func _get_shelter_bonus(player_pos: Vector2i) -> float:
    var bonus = 0.0
    for structure in StructureManager.get_nearby_structures(player_pos):
        if structure.shelter_component:
            if structure.shelter_component.is_sheltered(structure.position, player_pos):
                bonus += structure.shelter_component.temperature_bonus
    return bonus
```

## JSON Configuration

From structure definition:

```json
"components": {
    "shelter": {
        "shelter_radius": 2,
        "temperature_bonus": 5.0,
        "blocks_rain": true
    }
}
```

## Combined Effects

Fire and shelter can stack:

```
Player near both campfire and lean-to:
- Fire bonus: +15.0°F
- Shelter bonus: +5.0°F
- Total bonus: +20.0°F
```

## Future Weather Integration

When weather system is implemented:

```gdscript
# Planned functionality
func get_weather_protection(shelter_pos: Vector2i, target_pos: Vector2i) -> Dictionary:
    if not is_sheltered(shelter_pos, target_pos):
        return {"rain": false, "wind": false}

    return {
        "rain": blocks_rain,
        "wind": true  # Shelter always blocks wind
    }
```

## Stacking Rules

Multiple shelters in range:
- Temperature bonuses stack additively
- Rain blocking from any shelter protects

## Integration with Other Systems

- **SurvivalSystem**: Temperature and future weather protection
- **StructureManager**: Tracks all shelter structures

## Related Documentation

- [Fire Component](./fire-component.md) - Heat source
- [Survival System](./survival-system.md) - Temperature mechanics
- [Structures Data](../data/structures.md) - Shelter component config
