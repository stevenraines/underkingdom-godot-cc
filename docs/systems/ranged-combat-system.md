# Ranged Combat System

**Source File**: `systems/ranged_combat_system.gd`
**Type**: Game System (Static Class)

## Overview

The Ranged Combat System handles all ranged weapon combat in Underkingdom, including bows, crossbows, slings (with ammunition), and thrown weapons. It includes line-of-sight checking, range validation, accuracy penalties for distance, and ammunition recovery mechanics.

## Key Concepts

- **Ranged Weapons**: Bows, crossbows, and slings that require ammunition
- **Thrown Weapons**: Throwing knives, axes that are consumed on use
- **Ammunition**: Projectiles consumed when firing ranged weapons
- **Recovery**: Chance to recover ammunition/thrown weapons after use
- **Line of Sight**: Clear path required between attacker and target

## Weapon Types

### Ranged Weapons (Require Ammunition)
| Weapon | Range | Ammunition Type | Accuracy Mod | Damage |
|--------|-------|-----------------|--------------|--------|
| Short Bow | 10 | arrow | +5 | 3 |
| Long Bow | 15 | arrow | +0 | 5 |
| Crossbow | 12 | bolt | +10 | 6 |
| Sling | 8 | sling_stone | +0 | 2 |

### Thrown Weapons (Consumed on Use)
| Weapon | Range | Recovery Chance | Damage |
|--------|-------|-----------------|--------|
| Throwing Knife | 6 | 70% | 4 |
| Throwing Axe | 5 | 60% | 6 |

## Core Mechanics

### Range Calculation

Effective range depends on the weapon. Some weapons scale with STR.

**Standard Range**:
```
Effective Range = weapon.attack_range
```

**STR-Scaled Range** (for thrown weapons):
```
Effective Range = weapon.attack_range + floor((STR - 10) / 4)
```

### Line of Sight

Uses Bresenham's line algorithm to trace a path from attacker to target. Every tile along the path (except start and end) must be transparent.

```
For each tile in line from attacker to target:
  If tile.transparent == false:
    Return "No line of sight"
```

### Accuracy Calculation

Ranged accuracy uses DEX like melee, but adds weapon modifiers and range penalties.

**Formula**:
```
Base Accuracy = 50 + (DEX × 2)
Weapon Modifier = weapon.accuracy_modifier
Target Evasion = 5 + target.DEX
Range Penalty = max(0, (distance - half_range) × 5)

Hit Chance = Base Accuracy + Weapon Modifier - Target Evasion - Range Penalty
Clamped to: 5% minimum, 95% maximum
```

### Range Penalty

Attacks beyond half the weapon's effective range suffer accuracy penalties.

**Formula**:
```
Half Range = floor(Effective Range / 2)
If distance > Half Range:
  Range Penalty = (distance - Half Range) × 5%
```

**Example (Short Bow, Range 10):**
| Distance | Penalty |
|----------|---------|
| 1-5 tiles | 0% |
| 6 tiles | -5% |
| 7 tiles | -10% |
| 8 tiles | -15% |
| 9 tiles | -20% |
| 10 tiles | -25% |

### Accuracy Example

**Player (DEX 12) firing Short Bow at Grave Rat (DEX 12) at 7 tiles:**
- Base Accuracy: 50 + (12 × 2) = 74%
- Weapon Modifier: +5% (short_bow accuracy_modifier)
- Target Evasion: 5 + 12 = 17%
- Range Penalty: (7 - 5) × 5 = -10%
- Hit Chance: 74 + 5 - 17 - 10 = **52%**

### Damage Calculation

Ranged damage combines weapon and ammunition bonuses.

**For Ranged Weapons**:
```
Damage = weapon.damage_bonus + ammo.damage_bonus
```

**For Thrown Weapons** (STR bonus applies):
```
Damage = weapon.damage_bonus + floor((STR - 10) / 2)
```

**Minimum Damage**: 1 (always deals at least 1 damage)

### Damage Example

**Short Bow (damage 3) + Arrow (damage 1):**
- Total Damage: 3 + 1 = **4 damage**

**Throwing Knife (damage 4) with STR 14:**
- Base Damage: 4
- STR Modifier: floor((14 - 10) / 2) = +2
- Total Damage: 4 + 2 = **6 damage**

## Ammunition Recovery

Ammunition and thrown weapons can be recovered after use.

### Recovery Chance

**On Hit**:
```
Recovery Chance = item.recovery_chance
```

**On Miss** (projectile hits ground/wall):
```
Recovery Chance = item.recovery_chance × 0.7
```

| Ammunition | Base Recovery | On Miss Recovery |
|------------|---------------|------------------|
| Arrow | 85% | 59.5% |
| Iron Arrow | 90% | 63% |
| Bolt | 80% | 56% |
| Sling Stone | 50% | 35% |

### Recovery Location

- **On Hit**: Projectile lands at target's position (added to enemy drops if killed)
- **On Miss**: Projectile traces past target until hitting a wall or max range

### Recovery Mechanic

When ammunition is recovered:
1. If target dies: Added to `pending_drops` for loot generation
2. If target survives: Dropped as ground item at target position
3. If missed: Dropped as ground item at landing position

When ammunition is NOT recovered:
- Message displayed: "The [ammo name] broke."

## Targeting Mode

Press `R` with a ranged weapon equipped to enter targeting mode.

### Controls
| Key | Action |
|-----|--------|
| `Tab` | Cycle to next valid target |
| `Shift+Tab` | Cycle to previous target |
| Arrow Keys | Cycle targets |
| `Enter` / `F` | Fire at selected target |
| `Escape` | Cancel targeting |

### Valid Targets
Targets must meet all criteria:
- Is an Enemy entity
- Is alive (`is_alive == true`)
- Within effective range
- Not adjacent (distance > 1, use melee instead)
- Has line of sight

## Attack Resolution Flow

1. Player presses `R` to enter targeting mode
2. System finds all valid targets via `get_valid_targets()`
3. Player cycles targets and confirms
4. `attempt_ranged_attack()` is called
5. Distance and range validation
6. Line of sight check
7. Accuracy calculation with range penalty
8. Roll 1-100 for hit determination
9. If hit: Calculate and apply damage
10. Process ammunition recovery
11. Emit `attack_performed` signal
12. Return result dictionary

## Result Dictionary

| Key | Type | Description |
|-----|------|-------------|
| `hit` | bool | Whether attack connected |
| `damage` | int | Damage dealt (0 if missed) |
| `attacker_name` | String | Name of attacker |
| `defender_name` | String | Name of target |
| `defender_died` | bool | Whether target was killed |
| `roll` | int | The d100 roll (1-100) |
| `hit_chance` | int | Calculated hit percentage |
| `weapon_name` | String | Weapon used |
| `ammo_name` | String | Ammunition used (if any) |
| `distance` | int | Distance to target in tiles |
| `ammo_recovered` | bool | Whether ammo can be recovered |
| `recovery_position` | Vector2i | Where ammo lands |
| `is_ranged` | bool | Always true |
| `is_thrown` | bool | True for thrown weapons |

## Signals Emitted

| Signal | Parameters | Description |
|--------|------------|-------------|
| `attack_performed` | attacker, defender, result | After ranged attack attempt |

## Integration with Other Systems

- **TargetingSystem**: Manages target selection UI and state
- **InventorySystem**: Checks equipped weapon and available ammunition
- **MapManager**: Provides tile transparency for LOS checks
- **ChunkManager**: Tile access for chunk-based maps
- **EntityManager**: Provides list of potential targets

## Data Dependencies

### Weapons (`data/items/weapons/`)
| Property | Description |
|----------|-------------|
| `attack_type` | Must be "ranged" or "thrown" |
| `attack_range` | Maximum range in tiles |
| `ammunition_type` | Required ammo ID (for ranged) |
| `accuracy_modifier` | Added to hit chance |
| `damage_bonus` | Base damage value |

### Ammunition (`data/items/ammunition/`)
| Property | Description |
|----------|-------------|
| `ammunition_type` | Type ID (matches weapon requirement) |
| `damage_bonus` | Added to weapon damage |
| `recovery_chance` | 0.0-1.0 recovery probability |

## Related Documentation

- [Combat System](./combat-system.md) - Melee combat mechanics
- [Targeting System](./targeting-system.md) - Target selection
- [Items Data](../data/items.md) - Weapon and ammunition properties
