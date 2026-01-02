# Targeting System

**Source File**: `systems/targeting_system.gd`
**Type**: Instance Class
**Class Name**: `TargetingSystem`

## Overview

The Targeting System manages target selection for ranged combat. It handles target cycling, validation, hit chance calculation, and attack confirmation. An instance is created by InputHandler for each targeting session.

## Key Concepts

- **Targeting Session**: Active period of target selection
- **Valid Targets**: Enemies within range and line of sight
- **Target Cycling**: Moving between available targets
- **Hit Chance**: Calculated accuracy display

## Core Properties

```gdscript
var is_targeting: bool = false
var current_target: Entity = null
var valid_targets: Array[Entity] = []
var target_index: int = 0
var attacker: Entity = null
var weapon: Item = null
var ammo: Item = null
```

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `target_changed` | target: Entity | Selection changed |
| `targeting_started` | (none) | Session began |
| `targeting_cancelled` | (none) | User cancelled |
| `targeting_confirmed` | target: Entity | Attack confirmed |

## Starting a Session

```gdscript
var has_targets = targeting_system.start_targeting(attacker, weapon, ammo)
```

### Process

1. Store attacker, weapon, ammo references
2. Get valid targets from RangedCombatSystem
3. If no targets, return false
4. Set is_targeting = true
5. Select first target
6. Emit targeting_started and target_changed
7. Return true

## Target Cycling

```gdscript
targeting_system.cycle_next()     # Move to next target
targeting_system.cycle_previous() # Move to previous target
```

Wraps around at list boundaries.

## Confirming Attack

```gdscript
var result = targeting_system.confirm_target()
```

### Process

1. Validate targeting active and target exists
2. Execute attack via RangedCombatSystem
3. End targeting session
4. Emit targeting_confirmed
5. Return attack result dictionary

## Cancelling

```gdscript
targeting_system.cancel()
```

Ends session and emits targeting_cancelled.

## Query Functions

### Current Target

```gdscript
var target = targeting_system.get_current_target()
var count = targeting_system.get_target_count()
var display_index = targeting_system.get_target_index_display()  # 1-based
```

### Distance

```gdscript
var tiles = targeting_system.get_target_distance()
```

### Hit Chance

```gdscript
var percent = targeting_system.get_hit_chance()
```

Calculates accuracy based on:
- Attacker DEX
- Weapon accuracy modifier
- Distance penalty
- Target evasion

### Active Check

```gdscript
if targeting_system.is_active():
    # In targeting mode
```

## UI Text

### Status Text

```gdscript
var status = targeting_system.get_status_text()
# Returns: "Target: Skeleton (1/3) | Distance: 5 | Hit: 75%"
```

### Help Text

```gdscript
var help = targeting_system.get_help_text()
# Returns: "[Tab/←→] Cycle | [Enter/F] Fire | [Esc] Cancel"
```

## Valid Target Criteria

From RangedCombatSystem:
- Is an Enemy
- Is alive
- Within weapon range
- Has line of sight from attacker
- Not at melee range (distance < 1)

## Session Lifecycle

```
Start Session
    ↓
[Target Cycling]  ←→  [Cycle Next/Previous]
    ↓
[Confirm Attack] or [Cancel]
    ↓
End Session
```

## Internal Reset

```gdscript
func _end_targeting():
    is_targeting = false
    current_target = null
    valid_targets.clear()
    target_index = 0
    attacker = null
    weapon = null
    ammo = null
```

## Integration with Other Systems

- **InputHandler**: Creates instance, handles input routing
- **RangedCombatSystem**: Provides valid targets, executes attacks
- **Game Scene**: Displays targeting UI

## Usage in InputHandler

```gdscript
# Start targeting
var has_targets = targeting_system.start_targeting(player, weapon, ammo)
if has_targets:
    ui_blocking_input = true
    game.show_targeting_ui(targeting_system)

# Handle input in targeting mode
func _handle_targeting_input(event):
    match event.keycode:
        KEY_TAB: targeting_system.cycle_next()
        KEY_ENTER: targeting_system.confirm_target()
        KEY_ESCAPE: targeting_system.cancel()
```

## Related Documentation

- [Ranged Combat System](./ranged-combat-system.md) - Attack resolution
- [Input Handler](./input-handler.md) - Input routing
- [Combat System](./combat-system.md) - Damage calculation
