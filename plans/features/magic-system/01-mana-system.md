# Phase 1: Mana System

## Overview
Add mana as a new resource to the player, similar to stamina. This is the foundation for all spellcasting.

## Dependencies
- None (this is the foundation)

## Implementation Steps

### 1.1 Add Mana to SurvivalSystem
**File:** `systems/survival_system.gd`

- Add mana properties:
  ```gdscript
  var mana: float = 0.0
  var base_max_mana: float = 30.0
  const MANA_REGEN_PER_TURN: float = 1.0
  const MANA_REGEN_SHELTER_MULTIPLIER: float = 3.0
  ```

- Add `get_max_mana()` function:
  ```gdscript
  func get_max_mana() -> float:
      var int_bonus = (owner.get_effective_attribute("INT") - 10) * 5
      return base_max_mana + int_bonus + level_bonus
  ```

- Add `consume_mana(amount: int) -> bool` function (similar to consume_stamina)

- Add `regenerate_mana(modifier: float = 1.0)` function

- Add mana initialization in `_init()` or setup function

### 1.2 Add Mana Level Scaling
**File:** `systems/survival_system.gd`

- Track player level for mana scaling
- Add `mana_per_level` constant (suggest: 5 mana per level)
- Update `get_max_mana()` to include level bonus

### 1.3 Add EventBus Signals
**File:** `autoload/event_bus.gd`

Add new signals:
```gdscript
signal mana_changed(old_value: float, new_value: float, max_value: float)
signal mana_depleted()
```

### 1.4 Integrate with Turn Processing
**File:** `autoload/turn_manager.gd`

- Call `regenerate_mana()` in `_process_player_survival()`
- Apply shelter multiplier when in shelter

### 1.5 Add Mana to HUD
**File:** `ui/hud.gd` and `ui/hud.tscn`

- Add mana bar (similar to health/stamina bars)
- Connect to `mana_changed` signal
- Display current/max mana
- Color: Blue (#4444FF)

### 1.6 Add Rest Dialog Option
**File:** `ui/rest_dialog.gd` (or wherever rest UI is)

- Add "Rest until mana restored" option
- Only show if player has mana (is a spellcaster)
- Calculate turns needed based on deficit and regen rate

### 1.7 Add Mana to Save/Load
**File:** `autoload/save_manager.gd`

- Include mana in player serialization
- Restore mana on load

## Testing Checklist

- [ ] Player starts with mana pool (30 + INT bonus)
- [ ] Mana displays in HUD with blue bar
- [ ] Mana regenerates 1/turn when waiting
- [ ] Mana regenerates 3/turn in shelter
- [ ] `consume_mana()` returns false when insufficient mana
- [ ] `mana_changed` signal fires on mana changes
- [ ] `mana_depleted` signal fires when mana hits 0
- [ ] Mana persists through save/load
- [ ] Max mana increases with INT (5 per point above 10)
- [ ] Max mana increases with level (5 per level)
- [ ] Rest dialog shows "Rest until mana restored" option

## Files Modified
- `systems/survival_system.gd`
- `autoload/event_bus.gd`
- `autoload/turn_manager.gd`
- `autoload/save_manager.gd`
- `ui/hud.gd`
- `ui/hud.tscn`
- `ui/rest_dialog.gd` (if exists)

## Files Created
- None

## Next Phase
Once mana system is working, proceed to **Phase 2: Spell Data & Manager**
