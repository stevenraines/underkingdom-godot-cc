# Ranged Combat Implementation Plan

## Overview

Add ranged weapon combat including bows, crossbows, slings, and thrown items. The system supports ammunition management, target selection at range, and projectile recovery mechanics.

---

## Architecture

### Core Components

1. **RangedCombatSystem** (`systems/ranged_combat_system.gd`)
   - Handles ranged attack resolution
   - Line-of-sight validation
   - Damage calculation with range modifiers
   - Ammunition consumption and recovery

2. **TargetingSystem** (`systems/targeting_system.gd`)
   - Visual target selection UI
   - Cycles through valid targets in range/LoS
   - Shows targeting reticle on selected entity

3. **Extended Item Properties**
   - `attack_type`: "melee" | "ranged" | "thrown"
   - `attack_range`: Maximum attack distance
   - `ammunition_type`: Required ammo type (e.g., "arrow", "bolt")
   - `recovery_chance`: % chance ammo can be recovered (0-100)

4. **Ammunition Items**
   - Stackable items consumed on ranged attack
   - Can be recovered from ground or enemy corpses
   - Different types: arrows, bolts, sling_stones, throwing_knives

---

## Data Structures

### Weapon JSON Extensions

```json
{
  "id": "short_bow",
  "name": "Short Bow",
  "category": "weapon",
  "subtype": "bow",
  "attack_type": "ranged",
  "attack_range": 6,
  "ammunition_type": "arrow",
  "damage_bonus": 3,
  "accuracy_modifier": 0,
  "equip_slots": ["main_hand", "off_hand"],
  "flags": { "two_handed": true, "equippable": true }
}
```

### Thrown Weapon JSON

```json
{
  "id": "throwing_knife",
  "name": "Throwing Knife",
  "category": "weapon",
  "subtype": "thrown",
  "attack_type": "thrown",
  "attack_range": 4,
  "damage_bonus": 2,
  "recovery_chance": 75,
  "flags": { "equippable": false, "throwable": true }
}
```

### Ammunition JSON

```json
{
  "id": "arrow",
  "name": "Arrow",
  "category": "ammunition",
  "ammunition_type": "arrow",
  "damage_bonus": 1,
  "recovery_chance": 50,
  "max_stack": 20,
  "flags": { "ammunition": true }
}
```

---

## Implementation Steps

### Phase 1: Item System Extensions

1. **Extend Item class** (`items/item.gd`)
   - Add properties: `attack_type`, `attack_range`, `ammunition_type`, `recovery_chance`
   - Add helper methods: `is_ranged_weapon()`, `is_thrown_weapon()`, `is_ammunition()`

2. **Create ammunition items** (`data/items/ammunition/`)
   - `arrow.json` - For bows
   - `bolt.json` - For crossbows
   - `sling_stone.json` - For slings

3. **Create ranged weapons** (`data/items/weapons/`)
   - `short_bow.json` - Range 6, uses arrows
   - `long_bow.json` - Range 10, uses arrows
   - `crossbow.json` - Range 8, uses bolts, higher damage
   - `sling.json` - Range 5, uses sling_stones

4. **Create thrown weapons** (`data/items/weapons/`)
   - `throwing_knife.json` - Range based on STR
   - `throwing_axe.json` - Range based on STR

### Phase 2: Combat System

1. **Create RangedCombatSystem** (`systems/ranged_combat_system.gd`)
   ```gdscript
   func attempt_ranged_attack(attacker: Entity, target: Entity, weapon: Item, ammo: Item = null) -> Dictionary
   func calculate_ranged_accuracy(attacker: Entity, target: Entity, weapon: Item, distance: int) -> int
   func calculate_ranged_damage(attacker: Entity, weapon: Item, ammo: Item) -> int
   func check_line_of_sight(from: Vector2i, to: Vector2i) -> bool
   func get_valid_targets_in_range(attacker: Entity, weapon: Item) -> Array[Entity]
   ```

2. **Line-of-sight checking**
   - Use Bresenham's line algorithm
   - Check each tile for transparency
   - Return false if any blocking tile encountered

3. **Accuracy calculation**
   - Base: 50% + (DEX × 2)%
   - Range penalty: -5% per tile beyond half range
   - Weapon modifier: `accuracy_modifier` from weapon
   - Cover penalty (future): -20% if target has partial cover

4. **Damage calculation**
   - Weapon `damage_bonus` + Ammo `damage_bonus` (if any)
   - STR modifier for thrown weapons
   - No range damage falloff initially

### Phase 3: Targeting System

1. **Create TargetingSystem** (`systems/targeting_system.gd`)
   ```gdscript
   signal target_selected(target: Entity)
   signal targeting_cancelled

   var is_targeting: bool = false
   var current_target: Entity = null
   var valid_targets: Array[Entity] = []
   var target_index: int = 0

   func start_targeting(attacker: Entity, weapon: Item)
   func cycle_target(direction: int)  # +1 next, -1 previous
   func confirm_target() -> Entity
   func cancel_targeting()
   func get_current_target() -> Entity
   ```

2. **Visual feedback**
   - Highlight current target with colored border/glyph
   - Show range indicator (tiles within range)
   - Display target info (name, HP if known)

3. **Input handling** (in `input_handler.gd`)
   - `F` or `R`: Enter targeting mode with ranged weapon
   - Arrow keys / Tab: Cycle through targets
   - Enter / Space: Confirm attack
   - Escape: Cancel targeting

### Phase 4: Ammunition Management

1. **Consumption on attack**
   - Check inventory for matching `ammunition_type`
   - Consume 1 ammo per shot
   - Block attack if no ammo available

2. **Recovery mechanics**
   - On hit: Add ammo to target's `pending_drops` (recovered when killed)
   - On miss: Calculate landing position, spawn ground item if recovered
   - Recovery check: `randf() * 100 < recovery_chance`

3. **Landing position calculation**
   - Trace line from attacker to target
   - Continue past target up to weapon range
   - Stop at first blocking tile (wall)
   - Spawn recoverable ammo at final position

### Phase 5: Thrown Weapons

1. **Thrown weapon handling**
   - No separate ammo - weapon IS the projectile
   - Remove from inventory on throw
   - Recovery places weapon on ground (not in inventory)
   - Range = base_range + (STR / 2)

2. **Damage calculation**
   - Weapon `damage_bonus` + STR modifier
   - No ammo bonus

### Phase 6: Enemy AI

1. **Extend enemy behavior** (`entities/enemy.gd`)
   - Check if enemy has ranged weapon equipped
   - If target in range and LoS: attempt ranged attack
   - If no ammo or out of range: fall back to melee behavior
   - Simple AI: don't approach if can attack at range

2. **Enemy ammunition**
   - Enemies have limited ammo (defined in spawn data)
   - When out of ammo, switch to melee
   - Drop remaining ammo on death

---

## File Changes Summary

### New Files
- `systems/ranged_combat_system.gd`
- `systems/targeting_system.gd`
- `data/items/ammunition/arrow.json`
- `data/items/ammunition/bolt.json`
- `data/items/ammunition/sling_stone.json`
- `data/items/weapons/short_bow.json`
- `data/items/weapons/long_bow.json`
- `data/items/weapons/crossbow.json`
- `data/items/weapons/sling.json`
- `data/items/weapons/throwing_knife.json`

### Modified Files
- `items/item.gd` - Add ranged properties
- `systems/combat_system.gd` - Add ranged attack entry point
- `systems/input_handler.gd` - Add targeting mode input
- `entities/player.gd` - Add ranged attack method
- `entities/enemy.gd` - Add ranged AI behavior
- `scenes/game.gd` - Render targeting UI
- `autoload/item_manager.gd` - Load ammunition category

---

## UI/UX Flow

### Ranged Attack Flow
1. Player presses `F` (fire/ranged attack)
2. If no ranged weapon equipped: show message "No ranged weapon equipped"
3. If no ammo: show message "No ammunition for [weapon]"
4. Enter targeting mode:
   - Screen tints slightly
   - Valid targets highlighted
   - First target auto-selected
   - UI shows: "[Tab] Cycle Target | [Enter] Fire | [Esc] Cancel"
5. Player cycles targets with Tab/Arrow keys
6. Player confirms with Enter:
   - Attack resolved
   - Ammo consumed
   - Miss/hit message displayed
   - Turn advances
7. Or player cancels with Escape

### Thrown Attack Flow
1. Player opens inventory, selects throwable item
2. Press `T` to throw
3. Enter targeting mode (same as ranged)
4. Confirm target
5. Item removed from inventory
6. Attack resolved
7. If recovered: item appears on ground near target

---

## Testing Checklist

- [ ] Ranged weapons can be equipped
- [ ] Attacking requires appropriate ammunition
- [ ] Attack fails gracefully with no ammo
- [ ] Line of sight blocks attacks through walls
- [ ] Targets beyond range cannot be selected
- [ ] Accuracy decreases at longer ranges
- [ ] Ammunition is consumed on attack
- [ ] Hit ammunition can be recovered from enemy drops
- [ ] Missed ammunition appears on ground (with recovery chance)
- [ ] Thrown weapons are removed from inventory
- [ ] Thrown weapons can be recovered from ground
- [ ] Enemy AI uses ranged weapons when equipped
- [ ] Targeting UI shows valid targets
- [ ] Targeting can be cancelled
- [ ] Turn advances after ranged attack
