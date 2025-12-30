# Survival Systems Implementation Plan - Phase 1.9

**Scope**: Task 1.9 (Survival Systems) from PRD
**Branch**: `feature/survival-systems`
**Goal**: Functional survival mechanics with hunger, thirst, temperature, stamina, and fatigue

---

## Overview

Phase 1.9 implements the interconnected survival systems that add strategic resource management to the game. Players must manage their physical state while exploring, creating emergent gameplay through the interaction of multiple systems.

---

## Survival Systems Reference (from PRD)

### Hunger
- **Scale**: 0-100 (starts at 100)
- **Drain**: 1 point per 20 turns
- **Effects**:
  | Range | Effects |
  |-------|---------|
  | 75-100 | Normal |
  | 50-75 | Stamina regen -25% |
  | 25-50 | Stamina regen -50%, STR -1 |
  | 1-25 | Stamina regen -75%, STR -2, health drain 1/50 turns |
  | 0 | Health drain 1/10 turns, STR -3, DEX -2 |

### Thirst
- **Scale**: 0-100 (starts at 100)
- **Drain**: 1 point per 15 turns
- **Effects** (more severe than hunger):
  | Range | Effects |
  |-------|---------|
  | 75-100 | Normal |
  | 50-75 | Stamina max -20% |
  | 25-50 | Stamina max -40%, WIS -1, perception -2 |
  | 1-25 | Health drain 1/25 turns, WIS -2, confusion chance |
  | 0 | Health drain 1/5 turns, severe stat penalties |

### Temperature
- **Scale**: Numeric °C (comfortable range: 15-25°C)
- **Sources**: Time of day, biome, equipment, fires
- **Effects**:
  | Temperature | Effects |
  |-------------|---------|
  | <0°C (Freezing) | Health drain, severe penalties |
  | 0-10°C (Cold) | Stamina drain, DEX penalty |
  | 10-15°C (Cool) | Minor stamina drain |
  | 15-25°C (Comfortable) | Normal |
  | 25-30°C (Warm) | Minor thirst drain increase |
  | 30-40°C (Hot) | Thirst drain accelerated |
  | >40°C (Hyperthermia) | Health drain, confusion |

### Stamina
- **Scale**: 0 to Max (Max derived from CON: 50 + CON × 10)
- **Costs**:
  - Movement: 1
  - Attack: 3
  - Sprint (future): 5
  - Heavy attack (future): 6
- **Regeneration**: 1/turn when not acting (modified by survival states)

### Fatigue
- **Scale**: 0-100 (starts at 0)
- **Accumulation**:
  - +1 per 100 turns naturally
  - Increases when stamina hits 0
- **Effects**: Reduces max stamina by fatigue%
- **Recovery**: Reduced by sleeping (future feature)

---

## Implementation Components

### 1. Survival System (New Class)
**File**: `res://systems/survival_system.gd`
**Status**: ✅ Complete

**Purpose**: Centralized survival state management

**Key Properties:**
```gdscript
# Survival stats
var hunger: float = 100.0
var thirst: float = 100.0
var temperature: float = 20.0  # °C
var stamina: float = 100.0
var max_stamina: float = 100.0
var fatigue: float = 0.0

# Drain rates (turns between 1 point drain)
const HUNGER_DRAIN_RATE: int = 20
const THIRST_DRAIN_RATE: int = 15
const FATIGUE_RATE: int = 100

# Stamina costs
const STAMINA_COST_MOVE: int = 1
const STAMINA_COST_ATTACK: int = 3
```

**Key Methods:**
```gdscript
func process_turn(turn_number: int) -> void
func apply_survival_effects(entity: Entity) -> Dictionary
func consume_stamina(amount: int) -> bool
func regenerate_stamina() -> void
func get_hunger_state() -> String  # "normal", "hungry", "starving", etc.
func get_thirst_state() -> String
func get_temperature_state() -> String
```

---

### 2. Event Bus Survival Signals
**File**: `res://autoload/event_bus.gd`
**Status**: ✅ Complete

**New Signals:**
```gdscript
signal survival_stat_changed(stat_name: String, old_value: float, new_value: float)
signal survival_effect_applied(effect_name: String, severity: String)
signal survival_warning(message: String, severity: String)
signal stamina_depleted()
```

---

### 3. Entity Survival Integration
**File**: `res://entities/entity.gd` and `res://entities/player.gd`
**Status**: ✅ Complete

**New Properties for Entity:**
```gdscript
# Stat modifiers from survival effects
var stat_modifiers: Dictionary = {
    "STR": 0,
    "DEX": 0,
    "CON": 0,
    "INT": 0,
    "WIS": 0,
    "CHA": 0
}
```

**Player-specific:**
- Player holds SurvivalSystem instance
- Survival effects apply stat modifiers

---

### 4. Turn Manager Integration
**File**: `res://autoload/turn_manager.gd`
**Status**: ✅ Complete

**Updates:**
- Call `SurvivalSystem.process_turn()` each turn
- Track turns for periodic effects (health drain)

---

### 5. Combat/Movement Stamina Integration
**Files**: `res://entities/player.gd`, `res://systems/input_handler.gd`
**Status**: ✅ Complete

**Updates:**
- Movement costs 1 stamina
- Attacks cost 3 stamina
- Block action if insufficient stamina

---

### 6. Temperature System
**File**: `res://systems/survival_system.gd`
**Status**: ✅ Complete

**Temperature Sources:**
- Base biome temperature (woodland: 15°C)
- Time of day modifier:
  - Dawn: -3°C
  - Day: +0°C
  - Dusk: -2°C
  - Night: -8°C
- Dungeon modifier: Underground = stable 12°C
- Near fire: +10°C (future)

---

### 7. HUD Updates
**File**: `res://scenes/game.gd`
**Status**: ✅ Complete

**Display:**
- Hunger bar/percentage
- Thirst bar/percentage
- Temperature with color coding
- Stamina bar
- Fatigue indicator
- Active survival warnings

---

## Implementation Order

### Stage 1: Core System
1. ✅ Create `survival_system.gd` with stat tracking
2. ✅ Add survival signals to EventBus
3. ✅ Add stat_modifiers to Entity

### Stage 2: Drain & Effects
4. ✅ Implement turn-based drain
5. ✅ Implement survival effects (stat penalties)
6. ✅ Implement health drain at critical levels

### Stage 3: Stamina System
7. ✅ Add stamina costs to movement
8. ✅ Add stamina costs to combat
9. ✅ Implement stamina regeneration

### Stage 4: Temperature
10. ✅ Implement temperature calculation
11. ✅ Apply temperature effects

### Stage 5: UI & Polish
12. ✅ Update HUD with survival displays
13. ✅ Add survival warning messages
14. ⬜ Test all survival interactions

---

## Testing Checklist

### Hunger System
- [ ] Hunger drains over time (1 per 20 turns)
- [ ] Effects apply at correct thresholds
- [ ] Health drain occurs when starving
- [ ] STR penalty applied correctly

### Thirst System
- [ ] Thirst drains faster than hunger (1 per 15 turns)
- [ ] Max stamina reduced when thirsty
- [ ] Perception reduced at low thirst
- [ ] Health drain at critical thirst

### Temperature System
- [ ] Temperature calculated from time of day
- [ ] Dungeon has stable temperature
- [ ] Cold/hot effects apply correctly

### Stamina System
- [ ] Movement costs stamina
- [ ] Attacks cost stamina
- [ ] Stamina regenerates when not acting
- [ ] Fatigue reduces max stamina
- [ ] Cannot act without sufficient stamina

### Fatigue System
- [ ] Fatigue increases slowly over time
- [ ] Fatigue increases when stamina depleted
- [ ] Max stamina reduced by fatigue %

---

## Files to Create/Modify

### New Files
- `res://systems/survival_system.gd` - Core survival logic
- `res://plans/survival-systems-implementation.md` - This document

### Modified Files
- `res://autoload/event_bus.gd` - Survival signals
- `res://autoload/turn_manager.gd` - Process survival each turn
- `res://entities/entity.gd` - Stat modifiers
- `res://entities/player.gd` - Survival system integration
- `res://systems/input_handler.gd` - Stamina checks
- `res://scenes/game.gd` - HUD updates

---

## Success Criteria

Phase 1.9 is complete when:
1. ✅ Hunger drains over time with correct effects
2. ✅ Thirst drains faster with more severe effects
3. ✅ Temperature varies by time of day and location
4. ✅ Stamina costs apply to movement and combat
5. ✅ Stamina regenerates when idle
6. ✅ Fatigue accumulates and affects max stamina
7. ✅ Stat penalties apply from survival states
8. ✅ Health drain occurs at critical survival levels
9. ✅ HUD displays all survival information
10. ✅ Warning messages show for low survival stats

---

## Future Enhancements (Not in Phase 1.9)

- **Consumables**: Food and water items restore hunger/thirst
- **Sleeping**: Rest to reduce fatigue
- **Campfires**: Heat source for temperature
- **Equipment**: Clothing affects temperature resistance
- **Biome effects**: Different base temperatures
- **Weather**: Rain, snow affecting temperature

---

*Document Version: 1.0*
*Last Updated: December 30, 2025*
