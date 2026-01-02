# Combat System

**Source File**: `systems/combat_system.gd`
**Type**: Game System (Static Class)

## Overview

The Combat System handles all melee combat resolution in Underkingdom. Combat is turn-based and uses bump-to-attack mechanics where moving into an enemy triggers an attack. The system calculates hit chance, damage, and manages the attack resolution flow.

## Key Concepts

- **Bump-to-Attack**: Moving into an enemy's tile initiates a melee attack
- **Cardinal Adjacency**: Melee attacks require being directly adjacent (not diagonal for basic attacks)
- **Attack Roll**: A d100 roll determines if an attack hits based on accuracy vs evasion

## Core Mechanics

### Hit Chance Calculation

The chance to hit is determined by comparing attacker accuracy against defender evasion.

**Formula**:
```
Hit Chance = Attacker Accuracy - Defender Evasion
Clamped to range: 5% minimum, 95% maximum
```

A random roll of 1-100 is made. If the roll is less than or equal to the hit chance, the attack hits.

### Accuracy Calculation

Accuracy represents how skilled an attacker is at landing blows.

**Formula**:
```
Accuracy = 50 + (DEX × 2)
```

| DEX | Accuracy |
|-----|----------|
| 8   | 66%      |
| 10  | 70%      |
| 12  | 74%      |
| 14  | 78%      |
| 16  | 82%      |
| 18  | 86%      |
| 20  | 90%      |

### Evasion Calculation

Evasion represents how well a defender can avoid incoming attacks.

**Formula**:
```
Evasion = 5 + DEX
```

| DEX | Evasion |
|-----|---------|
| 8   | 13%     |
| 10  | 15%     |
| 12  | 17%     |
| 14  | 19%     |
| 16  | 21%     |
| 18  | 23%     |
| 20  | 25%     |

### Hit Chance Example

**Player (DEX 12) attacking Barrow Wight (DEX 8):**
- Player Accuracy: 50 + (12 × 2) = 74%
- Wight Evasion: 5 + 8 = 13%
- Hit Chance: 74 - 13 = 61%
- Result: Player has 61% chance to hit

**Grave Rat (DEX 12) attacking Player (DEX 14):**
- Rat Accuracy: 50 + (12 × 2) = 74%
- Player Evasion: 5 + 14 = 19%
- Hit Chance: 74 - 19 = 55%
- Result: Rat has 55% chance to hit

### Damage Calculation

When an attack hits, damage is calculated based on weapon, strength, and armor.

**Formula**:
```
Damage = Base Damage + STR Modifier - Armor
Minimum Damage: 1 (attacks always deal at least 1 damage)
```

### STR Modifier

Strength affects melee damage output.

**Formula**:
```
STR Modifier = floor((STR - 10) / 2)
```

| STR | Modifier |
|-----|----------|
| 6   | -2       |
| 8   | -1       |
| 10  | +0       |
| 12  | +1       |
| 14  | +2       |
| 16  | +3       |
| 18  | +4       |
| 20  | +5       |

### Base Damage

- **Unarmed**: Uses entity's `base_damage` property (typically 1-2)
- **Armed**: Uses weapon's `damage_bonus` property (e.g., Iron Sword = 6)

### Armor Reduction

Armor provides flat damage reduction. Total armor is the sum of all equipped items' `armor_value` properties.

### Damage Example

**Player (STR 14, Iron Sword) attacking Wight (Armor 2):**
- Base Damage: 6 (from iron_sword.json `damage_bonus`)
- STR Modifier: floor((14 - 10) / 2) = +2
- Armor Reduction: -2
- Final Damage: 6 + 2 - 2 = **6 damage**

**Grave Rat (STR 4, base_damage 2) attacking Player (Armor 3 from leather_armor):**
- Base Damage: 2
- STR Modifier: floor((4 - 10) / 2) = -3
- Armor Reduction: -3
- Calculated: 2 + (-3) - 3 = -4
- Final Damage: **1 damage** (minimum enforced)

## Attack Resolution Flow

1. Player bumps into enemy (or enemy bumps into player)
2. `CombatSystem.attempt_attack(attacker, defender)` is called
3. System calculates accuracy and evasion
4. Hit chance is computed and clamped to 5-95%
5. Random roll 1-100 is made
6. If roll ≤ hit_chance: attack hits
   - Calculate damage using formula
   - Apply damage to defender via `defender.take_damage(damage)`
   - Check if defender died
7. `EventBus.attack_performed` signal is emitted with result
8. Result dictionary returned to caller

## Result Dictionary

The `attempt_attack()` function returns a dictionary with:

| Key | Type | Description |
|-----|------|-------------|
| `hit` | bool | Whether the attack connected |
| `damage` | int | Damage dealt (0 if missed) |
| `attacker_name` | String | Name of attacker |
| `defender_name` | String | Name of defender |
| `defender_died` | bool | Whether defender was killed |
| `critical` | bool | Reserved for future critical hit system |
| `roll` | int | The d100 roll made (1-100) |
| `hit_chance` | int | Calculated hit percentage |
| `weapon_name` | String | Name of weapon used (if any) |

## Signals Emitted

| Signal | Parameters | Description |
|--------|------------|-------------|
| `attack_performed` | attacker: Entity, defender: Entity, result: Dictionary | Emitted after every attack attempt |

## Utility Functions

### Adjacency Checks

```gdscript
# Check if two positions are adjacent (including diagonals)
CombatSystem.are_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool

# Check if two positions are cardinally adjacent (not diagonal)
CombatSystem.are_cardinally_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool
```

### Message Generation

```gdscript
# Get a formatted combat message for UI display
CombatSystem.get_attack_message(result: Dictionary, is_player_attacker: bool) -> String
```

## Integration with Other Systems

- **SurvivalSystem**: Attacks cost 3 stamina (STAMINA_COST_ATTACK constant)
- **InventorySystem**: Gets equipped weapon `damage_bonus` and total `armor_value`
- **EntityManager**: Processes enemy turns after player attacks
- **RangedCombatSystem**: Uses similar formulas but with range penalties

## Data Dependencies

- **Items** (`data/items/weapons/`): `damage_bonus` property on weapons
- **Items** (`data/items/armor/`): `armor_value` property on armor
- **Enemies** (`data/enemies/`): `base_damage`, `armor`, and stat properties

## Related Documentation

- [Ranged Combat System](./ranged-combat-system.md) - Ranged weapon mechanics
- [Survival System](./survival-system.md) - Stamina costs for attacks
- [Inventory System](./inventory-system.md) - Equipment and stat bonuses
- [Items Data](../data/items.md) - Weapon and armor properties
