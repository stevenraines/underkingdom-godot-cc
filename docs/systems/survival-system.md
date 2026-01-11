# Survival System

**Source File**: `systems/survival_system.gd`
**Type**: Game System (Instance per Entity)

## Overview

The Survival System manages all survival mechanics in Underkingdom including hunger, thirst, temperature, stamina, and fatigue. These interconnected systems create emergent gameplay where players must balance exploration with resource management. Neglecting survival needs leads to stat penalties and eventually death.

## Key Concepts

- **Survival Stats**: Hunger, Thirst, Temperature, Stamina, Fatigue, Mana
- **Drain Rates**: Stats decrease over time at different rates
- **Thresholds**: Different severity levels trigger different effects
- **Stat Penalties**: Low survival stats reduce character attributes
- **Health Drain**: Critical survival states cause ongoing health damage
- **Mana Pool**: Resource for magic system, regenerates over time

## Survival Stats Overview

| Stat | Range | Starting Value | Drain Direction |
|------|-------|----------------|-----------------|
| Hunger | 0-100 | 100 (full) | Decreases over time |
| Thirst | 0-100 | 100 (full) | Decreases over time (faster) |
| Temperature | Variable | 68°F | Environment-based |
| Stamina | 0-Max | Max | Consumed by actions |
| Fatigue | 0-100 | 0 (rested) | Increases over time |
| Mana | 0-Max | Max | Consumed by spells |

## Hunger System

Hunger represents how well-fed the character is.

### Drain Rate
```
1 point lost every 20 turns
```

At 1000 turns per day, hunger drains 50 points per day.

### Hunger Thresholds and Effects

| Hunger | State | Effects |
|--------|-------|---------|
| 76-100 | Satisfied | No penalties |
| 51-75 | Peckish | -25% stamina regen |
| 26-50 | Hungry | -1 STR, -50% stamina regen |
| 1-25 | Famished | -2 STR, -75% stamina regen, 1 damage/50 turns |
| 0 | Starving | -3 STR, -2 DEX, 1 damage/10 turns |

### Restoring Hunger

Eating food restores hunger based on the item's `effects.hunger` property:
- Cooked Meat: +35 hunger
- Ration: +25 hunger
- Raw Meat: +15 hunger (risk of illness)
- Cave Mushroom: +5 hunger

## Thirst System

Thirst represents hydration level. Thirst drains faster than hunger and has more severe effects.

### Drain Rate
```
1 point lost every 15 turns
Base drain increased to 2 points when temperature > 86°F (hot)
```

At 1000 turns per day, thirst drains ~67 points per day normally.

### Thirst Thresholds and Effects

| Thirst | State | Effects |
|--------|-------|---------|
| 76-100 | Hydrated | No penalties |
| 51-75 | Dry | -20% max stamina |
| 26-50 | Thirsty | -1 WIS, -40% max stamina, -2 perception |
| 1-25 | Parched | -2 WIS, -40% max stamina, 1 damage/25 turns |
| 0 | Dehydrated | -2 STR, -2 DEX, -3 WIS, -50% max stamina, 1 damage/5 turns |

### Restoring Thirst

Drinking water restores thirst based on the item's `effects.thirst` property:
- Waterskin (full): +50 thirst
- Fresh Water: +40 thirst

## Temperature System

Temperature represents body heat, affected by environment, time of day, and structures.

### Base Temperatures

| Location | Base Temp |
|----------|-----------|
| Overworld (Woodland) | 64°F |
| Dungeons | 54°F |

### Time of Day Modifiers (Overworld Only)

| Time | Modifier |
|------|----------|
| Dawn (turns 0-150) | -5°F |
| Day (turns 150-700) | +0°F |
| Dusk (turns 700-850) | -4°F |
| Night (turns 850-1000) | -14°F |

### Structure Bonuses

- **Campfire (lit)**: +15°F within radius
- **Lean-to Shelter**: +5°F when sheltered

### Temperature Thresholds and Effects

| Temperature | State | Effects |
|-------------|-------|---------|
| > 104°F | Overheating | -2 INT, -2 WIS, 1 damage/10 turns |
| 86-104°F | Hot | -1 INT, double thirst drain |
| 77-86°F | Warm | No penalties |
| 59-77°F | Comfortable | No penalties |
| 50-59°F | Cool | -25% stamina regen |
| 32-50°F | Cold | -1 DEX, -50% stamina regen |
| < 32°F | Freezing | -3 DEX, -75% stamina regen, 1 damage/10 turns |

### Temperature Calculation

```
Final Temperature = Base Temp + Time Modifier + Structure Bonus
```

**Example: Night in woodland near campfire:**
- Base: 64°F
- Night modifier: -14°F
- Campfire bonus: +15°F
- Final: 64 - 14 + 15 = **65°F (Comfortable)**

## Stamina System

Stamina is consumed by actions and regenerates when resting.

### Maximum Stamina

```
Base Max Stamina = 50 + (CON × 10)
Effective Max = Base Max × (1 - Fatigue/100) × Thirst Modifier
```

| CON | Base Max Stamina |
|-----|------------------|
| 8   | 130 |
| 10  | 150 |
| 12  | 170 |
| 14  | 190 |

### Stamina Costs

| Action | Cost |
|--------|------|
| Move (walk) | 1 |
| Attack (melee) | 3 |
| Sprint | 5 |
| Heavy Attack | 6 |

### Stamina Regeneration

```
Base Regen: 1 stamina per turn (when not acting)
Modified by: Hunger state, Temperature state
```

### Running Out of Stamina

When stamina reaches 0:
- `stamina_depleted` signal emitted
- Fatigue increases by 1
- Actions requiring stamina fail
- Attempting actions without stamina increases fatigue by 2

## Fatigue System

Fatigue represents long-term exhaustion that reduces maximum stamina.

### Accumulation Rate
```
1 fatigue gained every 100 turns
Additional fatigue from stamina depletion
```

### Fatigue Effects

```
Effective Max Stamina = Base Max × (1 - Fatigue%)
```

| Fatigue | State | Max Stamina Reduction |
|---------|-------|----------------------|
| 0-24 | Rested | 0-24% |
| 25-49 | Slightly Tired | 25-49% |
| 50-74 | Tired | 50-74% |
| 75-89 | Very Tired | 75-89% |
| 90-100 | Exhausted | 90-100% |

**Example: 60 fatigue with 150 base stamina:**
- Effective Max: 150 × (1 - 0.60) = **60 stamina**

### Recovering from Fatigue

Fatigue can be reduced through two methods:

**1. Resting:**
- Press `Z` to open rest menu and rest for multiple turns
- Reduces 1 fatigue per 10 rest turns
- Example: Resting for 100 turns reduces 10 fatigue

**2. Consuming Items:**
- **Restorative Tonic**: -25 fatigue, +20 stamina (craftable)
- **Energizing Tea**: -15 fatigue, +10 thirst (craftable)

```gdscript
rest(amount) -> fatigue = max(0, fatigue - amount)
```

## Mana System

Mana is the magical energy pool used for casting spells. It regenerates over time, with faster regeneration when in shelter.

### Maximum Mana

```
Base Max Mana = 30
Max Mana = Base Max + (INT - 10) × 5 + (Level - 1) × 5
```

| INT | Level 1 Max Mana | Level 5 Max Mana |
|-----|------------------|------------------|
| 8   | 20 | 40 |
| 10  | 30 | 50 |
| 12  | 40 | 60 |
| 14  | 50 | 70 |

**Note**: INT below 10 reduces max mana (but never below 0).

### Mana Costs

Mana costs vary by spell level. See [Magic System](./magic-system.md) for spell costs.

| Spell Level | Typical Cost |
|-------------|--------------|
| Cantrip (0) | 0-2 |
| Level 1 | 5-10 |
| Level 2 | 10-15 |
| Level 3 | 15-20 |

### Mana Regeneration

```
Base Regen: 1 mana per turn
Shelter Bonus: 3× regeneration rate when in shelter
```

**Example: Regenerating from empty (0) to max (50) at level 5, INT 12:**
- Outside shelter: 50 turns
- Inside shelter: ~17 turns

### Restoring Mana

Mana can be restored through:

**1. Natural Regeneration**: 1 mana per turn (3× in shelter)

**2. Resting**: Press `Z` and select "Until mana restored"

**3. Mana Potions**: Consumable items that restore mana instantly
- **Minor Mana Potion**: +20 mana
- **Mana Potion**: +40 mana
- **Greater Mana Potion**: +80 mana

### Running Out of Mana

When mana reaches 0:
- `mana_depleted` signal emitted
- Spells requiring mana cannot be cast
- Cantrips (0 cost) can still be used

## Health Drain

Critical survival states cause periodic health damage.

### Health Drain Intervals

Multiple critical states stack to the fastest interval:

| Condition | Damage | Interval |
|-----------|--------|----------|
| Starving (hunger = 0) | 1 | Every 10 turns |
| Famished (hunger ≤ 25) | 1 | Every 50 turns |
| Dehydrated (thirst = 0) | 1 | Every 5 turns |
| Parched (thirst ≤ 25) | 1 | Every 25 turns |
| Freezing (temp < 32°F) | 1 | Every 10 turns |
| Overheating (temp > 104°F) | 1 | Every 10 turns |

**Stacking**: If multiple conditions apply, the fastest interval is used.

## Stat Modifiers Summary

Survival states modify base attributes:

| Condition | STR | DEX | CON | INT | WIS | CHA |
|-----------|-----|-----|-----|-----|-----|-----|
| Starving | -3 | -2 | - | - | - | - |
| Famished | -2 | - | - | - | - | - |
| Hungry | -1 | - | - | - | - | - |
| Dehydrated | -2 | -2 | - | - | -3 | - |
| Parched | - | - | - | - | -2 | - |
| Thirsty | - | - | - | - | -1 | - |
| Freezing | - | -3 | - | - | - | - |
| Cold | - | -1 | - | - | - | - |
| Overheating | - | - | - | -2 | -2 | - |
| Hot | - | - | - | -1 | - | - |

## Warning Messages

The system generates warnings displayed to the player:

### Hunger Warnings
- "You are starving to death!" (hunger = 0)
- "You are starving!" (hunger ≤ 25)
- "You are very hungry." (hunger ≤ 50)

### Thirst Warnings
- "You are dying of thirst!" (thirst = 0)
- "You are severely dehydrated!" (thirst ≤ 25)
- "You are very thirsty." (thirst ≤ 50)

### Temperature Warnings
- "You are freezing!" (temp < 32°F)
- "You are cold." (temp < 50°F)
- "You are overheating!" (temp > 104°F)
- "You are hot." (temp > 86°F)

### Fatigue/Stamina Warnings
- "You are exhausted!" (fatigue ≥ 90)
- "You are very tired." (fatigue ≥ 75)
- "You are tired." (fatigue ≥ 50)
- "You have no stamina!" (stamina = 0)
- "You are low on stamina." (stamina ≤ 25% of max)

## Signals Emitted

| Signal | Parameters | Description |
|--------|------------|-------------|
| `survival_stat_changed` | stat_name, old_value, new_value | When any survival stat changes |
| `survival_warning` | message | When warning threshold crossed |
| `stamina_depleted` | (none) | When stamina hits 0 or action blocked |
| `mana_changed` | old_value, new_value, max_value | When mana changes |
| `mana_depleted` | (none) | When mana hits 0 |

## Constants Reference

```gdscript
# Drain rates (turns between 1 point drain)
HUNGER_DRAIN_RATE = 20
THIRST_DRAIN_RATE = 15
FATIGUE_GAIN_RATE = 100

# Stamina costs
STAMINA_COST_MOVE = 1
STAMINA_COST_ATTACK = 3
STAMINA_COST_SPRINT = 5
STAMINA_COST_HEAVY_ATTACK = 6

# Temperature thresholds (°F)
TEMP_FREEZING = 32.0
TEMP_COLD = 50.0
TEMP_COOL = 59.0
TEMP_WARM = 77.0
TEMP_HOT = 86.0
TEMP_HYPERTHERMIA = 104.0

# Base temperatures (°F)
TEMP_WOODLAND_BASE = 64.0
TEMP_DUNGEON_BASE = 54.0

# Time of day modifiers (°F)
TEMP_MOD_DAWN = -5.0
TEMP_MOD_DAY = 0.0
TEMP_MOD_DUSK = -4.0
TEMP_MOD_NIGHT = -14.0

# Mana system
MANA_REGEN_PER_TURN = 1.0
MANA_REGEN_SHELTER_MULTIPLIER = 3.0
MANA_PER_LEVEL = 5.0
MANA_PER_INT = 5.0
BASE_MAX_MANA = 30.0
```

## Integration with Other Systems

- **TurnManager**: Calls `process_turn()` each turn to apply drain/effects
- **InventorySystem**: Consumables use `eat()` and `drink()` methods
- **StructureManager**: Fire and shelter components affect temperature
- **CombatSystem**: Reads stamina costs for attacks
- **Player Entity**: Owns SurvivalSystem instance, applies stat modifiers

## Data Dependencies

- **Consumables** (`data/items/consumables/`): `effects.hunger`, `effects.thirst` properties
- **Structures** (`data/structures/`): Fire and shelter component configurations

## Related Documentation

- [Inventory System](./inventory-system.md) - Item consumption
- [Combat System](./combat-system.md) - Stamina costs
- [Fire Component](./fire-component.md) - Temperature bonuses
- [Shelter Component](./shelter-component.md) - Weather protection
- [Items Data](../data/items.md) - Consumable effects
