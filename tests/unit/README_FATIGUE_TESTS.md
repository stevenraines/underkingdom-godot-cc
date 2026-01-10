# Fatigue Recovery System Tests

## Overview

This test suite (`test_fatigue_recovery.gd`) validates the fatigue reduction mechanics implemented to fix the max stamina reduction issue.

## What It Tests

### 1. Fatigue Accumulation (Baseline)
- ✅ Fatigue accumulates at 1 point per 100 turns
- ✅ Fatigue reduces max stamina by fatigue%
- ✅ Max stamina has minimum floor of 10

### 2. Fatigue Recovery via rest()
- ✅ `rest()` method reduces fatigue correctly
- ✅ Fatigue cannot go below 0
- ✅ Resting fully restores max stamina when fatigue reaches 0

### 3. Consumable Items
- ✅ Restorative Tonic item exists with correct effects
- ✅ Energizing Tea item exists with correct effects
- ✅ Items reduce fatigue when consumed
- ✅ Multiple consumables stack correctly

### 4. Max Stamina Recovery
- ✅ Max stamina increases as fatigue decreases
- ✅ Partial fatigue recovery increases max stamina proportionally
- ✅ Current stamina is clamped when max decreases

### 5. Balance Validation
- ✅ Recovery rate (1 per 10 rest turns) is 10x faster than accumulation
- ✅ Full recovery from 100 fatigue takes 1000 rest turns

### 6. Recipe Validation
- ✅ Restorative Tonic recipe exists and is valid
- ✅ Energizing Tea recipe exists and is valid

## Running the Tests

### Using GUT (Godot Unit Testing)

1. **Install GUT** (if not already installed):
   - Download from: https://github.com/bitwes/Gut
   - Or install via Asset Library in Godot Editor

2. **Run all tests**:
   ```bash
   # From command line
   godot4 --headless -s addons/gut/gut_cmdln.gd -gtest=tests/unit/test_fatigue_recovery.gd
   ```

3. **Run from Godot Editor**:
   - Open the project in Godot
   - Navigate to: `Project > Tools > Gut`
   - Select `test_fatigue_recovery.gd`
   - Click "Run"

4. **Run specific test**:
   ```bash
   godot4 --headless -s addons/gut/gut_cmdln.gd \
     -gtest=tests/unit/test_fatigue_recovery.gd \
     -gunit_test_name=test_rest_reduces_fatigue
   ```

## Test Coverage

### Total Tests: 21

| Category | Tests | Description |
|----------|-------|-------------|
| Baseline Behavior | 3 | Fatigue accumulation and max stamina reduction |
| rest() Method | 3 | Direct fatigue reduction via rest() |
| Consumable Items | 4 | Item definitions and effects |
| Max Stamina Recovery | 3 | Stamina restoration when fatigue decreases |
| Balance & Rates | 2 | Recovery vs accumulation rates |
| Edge Cases | 2 | Zero fatigue, multiple consumables |
| Recipe Validation | 2 | Recipe existence and validity |
| Integration | 2 | Stamina clamping, full recovery |

## Expected Results

All 21 tests should **PASS** with the implemented changes:

```
Totals:       21 pass  0 fail  0 pending
```

## Key Assertions

### Fatigue Reduction Formulas

**Accumulation:**
```
fatigue += 1 every 100 active turns
```

**Recovery (Resting):**
```
fatigue -= 1 every 10 rest turns
```

**Recovery (Items):**
```
Restorative Tonic: -25 fatigue
Energizing Tea:    -15 fatigue
```

### Max Stamina Calculation

```gdscript
base_max_stamina = 50 + (CON × 10)
effective_max_stamina = base_max_stamina × (1 - fatigue/100)
# Minimum: 10
```

**Example with CON 10:**
- Base: 150
- 0% fatigue: 150 max stamina
- 25% fatigue: 112.5 max stamina
- 50% fatigue: 75 max stamina
- 100% fatigue: 10 max stamina (floor)

## Troubleshooting

### Test Fails: Item Not Found

If tests fail with "Item definition should exist":
1. Verify files exist:
   - `data/items/consumables/restorative_tonic.json`
   - `data/items/consumables/energizing_tea.json`
2. Check JSON syntax is valid
3. Restart Godot to reload ItemManager

### Test Fails: Recipe Not Found

If tests fail with "Recipe should exist":
1. Verify files exist:
   - `data/recipes/consumables/restorative_tonic.json`
   - `data/recipes/consumables/energizing_tea.json`
2. Check JSON syntax is valid
3. Restart Godot to reload RecipeManager

### Test Fails: Max Stamina Calculation

If max stamina calculations are off:
1. Verify `get_max_stamina()` uses the formula: `base × (1 - fatigue/100)`
2. Check minimum floor is applied: `max(10.0, calculated_value)`
3. Ensure `base_max_stamina` is calculated correctly in `_init()`

## Integration Testing

After unit tests pass, manually verify in-game:

1. **Rest 100 turns** → Check fatigue decreased by 10
2. **Consume Restorative Tonic** → Fatigue -25, Stamina +20
3. **Consume Energizing Tea** → Fatigue -15, Thirst +10
4. **Open Character Sheet** → Max stamina increases as fatigue decreases

## Related Files

- Implementation: `scenes/game.gd:2141-2147` (resting system)
- System: `systems/survival_system.gd:484-488` (rest method)
- Items: `data/items/consumables/restorative_tonic.json`
- Items: `data/items/consumables/energizing_tea.json`
- Recipes: `data/recipes/consumables/restorative_tonic.json`
- Recipes: `data/recipes/consumables/energizing_tea.json`
- Docs: `docs/systems/survival-system.md` (updated)
