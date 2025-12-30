# Combat System Implementation Plan - Phase 1.8

**Scope**: Task 1.8 (Combat) from PRD
**Goal**: Functional turn-based combat with bump-to-attack, hit/miss resolution, and death handling

---

## Overview

Phase 1.8 implements the core combat mechanics that enable tactical engagement between the player and enemies. This phase builds directly on the entity system (Phase 1.7) and establishes the foundation for all future combat-related features.

---

## Combat Formula Reference (from PRD)

### Attack Resolution
```
Hit Chance = Attacker Accuracy - Defender Evasion + Situational Modifiers
Damage = Weapon Base + (STR or DEX modifier) - Armor
```

### Derived Stats (from PRD)
- **Base Accuracy**: 50% + (DEX × 2)%
- **Base Evasion**: 5% + (DEX × 1)%
- **Health**: Base 10 + (CON × 5)

---

## Implementation Components

### 1. Combat System (New Class)
**File**: `res://systems/combat_system.gd`
**Status**: ✅ Complete

**Purpose**: Centralized combat resolution logic

**Key Methods:**
```gdscript
static func attempt_attack(attacker: Entity, defender: Entity) -> Dictionary
static func calculate_hit_chance(attacker: Entity, defender: Entity) -> int
static func calculate_damage(attacker: Entity, defender: Entity) -> int
static func get_accuracy(entity: Entity) -> int
static func get_evasion(entity: Entity) -> int
```

**Attack Resolution Flow:**
1. Calculate attacker's accuracy (50 + DEX × 2)
2. Calculate defender's evasion (5 + DEX × 1)
3. Roll d100 - if roll < (accuracy - evasion), hit
4. On hit: Calculate damage (base weapon + STR modifier - armor)
5. Apply damage to defender
6. Check for death
7. Return result dictionary with details

**Return Dictionary:**
```gdscript
{
    "hit": bool,
    "damage": int,
    "attacker_name": String,
    "defender_name": String,
    "defender_died": bool,
    "critical": bool  # Future: critical hit system
}
```

---

### 2. Event Bus Combat Signals
**File**: `res://autoload/event_bus.gd`
**Status**: ✅ Complete

**New Signals:**
```gdscript
signal attack_performed(attacker: Entity, defender: Entity, result: Dictionary)
signal combat_message(message: String, color: Color)
```

---

### 3. Entity Combat Integration
**File**: `res://entities/entity.gd`
**Status**: ✅ Complete

**Existing Methods (already implemented):**
- `take_damage(amount: int)`
- `heal(amount: int)`
- `die()`

**New Properties:**
```gdscript
var base_damage: int = 1  # Unarmed/natural weapon damage
var armor: int = 0  # Damage reduction
```

---

### 4. Player Combat
**File**: `res://entities/player.gd`
**Status**: ✅ Complete

**New Methods:**
```gdscript
func attack(target: Entity) -> Dictionary:
    return CombatSystem.attempt_attack(self, target)
```

**Bump-to-Attack Logic:**
- When player tries to move into a tile with an enemy
- Instead of moving, perform attack
- Return true (turn consumed) regardless of hit/miss

---

### 5. Enemy Combat AI
**File**: `res://entities/enemy.gd`
**Status**: ✅ Complete

**Updates to `_move_toward_target()`:**
- If player is adjacent, attack instead of moving
- Attack consumes the enemy's turn

**New Attack Behavior:**
```gdscript
func _attempt_attack_if_adjacent() -> bool:
    if not EntityManager.player:
        return false
    
    var distance = _distance_to(EntityManager.player.position)
    if distance <= 1:  # Adjacent (including diagonals if needed)
        CombatSystem.attempt_attack(self, EntityManager.player)
        return true
    return false
```

---

### 6. Input Handler Combat Integration
**File**: `res://systems/input_handler.gd`
**Status**: ✅ Complete

**Updates:**
- Check for enemy at target position before moving
- If enemy present, trigger attack instead of move
- Attack still consumes a turn

```gdscript
func _try_move_or_attack(direction: Vector2i) -> bool:
    var target_pos = player.position + direction
    var blocking_enemy = EntityManager.get_blocking_entity_at(target_pos)
    
    if blocking_enemy and blocking_enemy is Enemy:
        # Attack the enemy
        player.attack(blocking_enemy)
        return true  # Turn consumed
    else:
        # Try to move
        return player.move(direction)
```

---

### 7. Combat Message Display
**File**: `res://scenes/game.gd`
**Status**: ✅ Complete

**Signal Handler:**
```gdscript
func _on_attack_performed(attacker: Entity, defender: Entity, result: Dictionary):
    var message: String
    var color: Color
    
    if result.hit:
        if result.defender_died:
            message = "%s kills %s!" % [attacker.name, defender.name]
            color = Color.RED
        else:
            message = "%s hits %s for %d damage." % [
                attacker.name, defender.name, result.damage
            ]
            color = Color.ORANGE if attacker == player else Color.YELLOW
    else:
        message = "%s misses %s." % [attacker.name, defender.name]
        color = Color.GRAY
    
    _add_message(message, color)
```

---

### 8. Player Death Handling
**File**: `res://scenes/game.gd`
**Status**: ✅ Complete

**Implementation:**
- Override `_on_entity_died()` to check if entity is player
- If player dies:
  - Display "You have died!" message
  - Show game over overlay/screen
  - Options: Load save (future) or Return to main menu

**Game Over UI:**
- Simple CanvasLayer overlay
- "You have died." text
- "Press any key to return to menu" or retry option

---

## Phase 1 Weapon Baseline

Since inventory system isn't implemented yet, use baseline values:

**Player (Unarmed):**
- Base Damage: 2
- STR modifier: +1 per 2 STR above 10
- No weapon bonus yet

**Enemies:**
| Enemy | Base Damage | Notes |
|-------|-------------|-------|
| Grave Rat | 2 | Quick, low damage |
| Barrow Wight | 5 | Heavy hitter |
| Woodland Wolf | 4 | Moderate damage |

---

## Combat Stats Summary

### Player (Base Attributes: 10 all)
- Accuracy: 50 + (10 × 2) = 70%
- Evasion: 5 + (10 × 1) = 15%
- Health: 10 + (10 × 5) = 60
- Base Damage: 2

### Grave Rat (DEX 12)
- Accuracy: 50 + (12 × 2) = 74%
- Evasion: 5 + (12 × 1) = 17%
- Health: 8 (from JSON, overrides formula)
- Base Damage: 2

### Barrow Wight (DEX 8)
- Accuracy: 50 + (8 × 2) = 66%
- Evasion: 5 + (8 × 1) = 13%
- Health: 25 (from JSON)
- Base Damage: 5

### Woodland Wolf (DEX 14)
- Accuracy: 50 + (14 × 2) = 78%
- Evasion: 5 + (14 × 1) = 19%
- Health: 18 (from JSON)
- Base Damage: 4

---

## Implementation Order

### Stage 1: Combat Core
1. ✅ Create `combat_system.gd` with attack resolution
2. ✅ Add combat signals to EventBus
3. ✅ Add `base_damage` and `armor` to Entity class

### Stage 2: Combat Integration
4. ✅ Update Player with `attack()` method
5. ✅ Update Enemy AI to attack when adjacent
6. ✅ Update InputHandler for bump-to-attack

### Stage 3: Feedback & Polish
7. ✅ Connect combat signals in game.gd
8. ✅ Add combat message logging
9. ✅ Update HUD to show health clearly
10. ✅ Implement player death handling

---

## Testing Checklist

### Attack Resolution
- [x] Player can attack enemy by walking into them
- [x] Attack uses accuracy vs evasion formula
- [x] Hit/miss is properly determined
- [x] Damage is calculated correctly
- [x] Damage is applied to defender

### Enemy Combat
- [x] Enemies attack player when adjacent
- [x] Enemy attacks use same formula
- [x] Enemies prioritize attacking over moving when adjacent

### Death Handling
- [x] Enemies die when health reaches 0
- [x] Dead enemies are removed from play
- [x] Player death triggers game over state
- [x] Death messages display correctly

### Combat Feedback
- [x] Attack messages show in message log
- [x] Hit shows damage amount
- [x] Miss shows miss message
- [x] Death shows kill message
- [x] Player health updates in HUD

---

## Files to Create/Modify

### New Files
- `res://systems/combat_system.gd` - Combat resolution logic
- `res://plans/combat-system-implementation.md` - This document

### Modified Files
- `res://autoload/event_bus.gd` - Add combat signals
- `res://entities/entity.gd` - Add base_damage, armor properties
- `res://entities/player.gd` - Add attack() method
- `res://entities/enemy.gd` - Add attack behavior to AI
- `res://systems/input_handler.gd` - Bump-to-attack logic
- `res://scenes/game.gd` - Combat message handling, player death
- `res://data/enemies/*.json` - Add base_damage values

---

## Success Criteria

Phase 1.8 is complete when:
1. ✅ Player can attack enemies by bumping into them
2. ✅ Attack resolution uses hit chance formula
3. ✅ Damage is calculated and applied correctly
4. ✅ Enemies attack player when adjacent during their turn
5. ✅ Combat messages display in the message log
6. ✅ Enemy death removes them from the game
7. ✅ Player death triggers game over state
8. ✅ Health displays correctly in HUD
9. ✅ Combat feels balanced (rats are easy, wights are dangerous)

---

## Future Enhancements (Not in Phase 1.8)

- **Critical Hits**: Extra damage on natural 20 or high roll
- **Armor System**: Equipment reduces incoming damage
- **Weapons**: Equipment adds to base damage
- **Special Attacks**: Abilities with cooldowns
- **Status Effects**: Poison, bleed, stun
- **Corpse Loot**: Enemies drop items on death

---

**Phase Status**: ✅ COMPLETE

**Git Branch**: `feature/combat-system`
**Files Created:**
- `res://systems/combat_system.gd` - Combat resolution logic
- `res://plans/combat-system-implementation.md` - This document

**Files Modified:**
- `res://autoload/event_bus.gd` - Added combat signals
- `res://entities/entity.gd` - Added base_damage, armor properties
- `res://entities/player.gd` - Added attack() method
- `res://entities/enemy.gd` - Added attack behavior to AI
- `res://systems/input_handler.gd` - Bump-to-attack logic
- `res://scenes/game.gd` - Combat message handling, player death
- `res://data/enemies/*.json` - Added base_damage and armor values

---

*Document Version: 1.0*
*Last Updated: December 30, 2025*
