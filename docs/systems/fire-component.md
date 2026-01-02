# Fire Component

**Source File**: `systems/components/fire_component.gd`
**Type**: Component Class
**Class Name**: `FireComponent`

## Overview

The Fire Component provides heat, cooking capability, and light for structures like campfires. It calculates area of effect for temperature bonuses and enables proximity-based crafting requirements.

## Key Concepts

- **Heat Radius**: Area warmed by the fire (Manhattan distance)
- **Temperature Bonus**: Degrees added to ambient temperature
- **Light Radius**: Area illuminated (future FOV integration)
- **Toggle State**: Fire can be lit or extinguished

## Core Properties

```gdscript
var heat_radius: int = 3          # Tiles (Manhattan distance)
var temperature_bonus: float = 15.0  # Degrees Fahrenheit
var is_lit: bool = true           # Can be toggled on/off
var provides_light: bool = true   # Light source flag
var light_radius: int = 5         # Tiles
```

## Default Values

| Property | Default | Description |
|----------|---------|-------------|
| `heat_radius` | 3 | Tiles warmed in each direction |
| `temperature_bonus` | 15.0 | °F added when in range |
| `is_lit` | true | Initially burning |
| `light_radius` | 5 | Future FOV extension |

## Area of Effect

### Heat Range Calculation

Uses Manhattan distance (taxicab geometry):

```gdscript
func affects_position(fire_pos: Vector2i, target_pos: Vector2i) -> bool:
    if not is_lit:
        return false

    var distance = abs(target_pos.x - fire_pos.x) + abs(target_pos.y - fire_pos.y)
    return distance <= heat_radius
```

### Visual Representation

```
      3
    3 2 3
  3 2 1 2 3
3 2 1 F 1 2 3
  3 2 1 2 3
    3 2 3
      3
```

F = Fire, Numbers = Manhattan distance from fire

With `heat_radius = 3`, all numbered positions receive heat bonus.

## Temperature Bonus

```gdscript
func get_temperature_bonus() -> float:
    return temperature_bonus if is_lit else 0.0
```

Returns:
- Full bonus when lit
- 0.0 when extinguished

## Usage by Survival System

```gdscript
# In survival_system.gd
func _get_fire_bonus(player_pos: Vector2i) -> float:
    var bonus = 0.0
    for structure in StructureManager.get_nearby_structures(player_pos):
        if structure.fire_component:
            if structure.fire_component.affects_position(structure.position, player_pos):
                bonus += structure.fire_component.get_temperature_bonus()
    return bonus
```

## Usage by Crafting System

Fire proximity check for recipes requiring fire:

```gdscript
# In crafting_system.gd
func _is_near_fire(player: Player) -> bool:
    return StructureManager.is_near_fire_source(
        player.position,
        MapManager.current_map.map_id,
        3  # Default fire radius
    )
```

## JSON Configuration

From structure definition:

```json
"components": {
    "fire": {
        "heat_radius": 3,
        "temperature_bonus": 15.0,
        "light_radius": 5
    }
}
```

## State Management

### Extinguishing Fire

```gdscript
fire_component.is_lit = false
# Heat and light effects stop immediately
```

### Relighting Fire

```gdscript
fire_component.is_lit = true
# Effects resume
```

## Future Features

- **Fuel consumption**: Fire burns out without fuel
- **Light integration**: Extend FOV radius at night
- **Visual effects**: Animated fire character
- **Enemy behavior**: Some creatures fear fire

## Integration with Other Systems

- **SurvivalSystem**: Temperature bonus calculation
- **CraftingSystem**: Fire proximity requirement
- **StructureManager**: Tracks all fire sources
- **FOVSystem**: Future light radius integration

## Related Documentation

- [Shelter Component](./shelter-component.md) - Weather protection
- [Survival System](./survival-system.md) - Temperature mechanics
- [Crafting System](./crafting-system.md) - Fire requirements
- [Structures Data](../data/structures.md) - Fire component config
