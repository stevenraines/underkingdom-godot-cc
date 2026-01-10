# Fatigue Recovery Test Validation

## Test File Status

✅ **File created**: `tests/unit/test_fatigue_recovery.gd` (399 lines)
✅ **Test count**: 20 test functions
✅ **Test runner**: `run_fatigue_tests.sh` (executable script)
✅ **Documentation**: `README_FATIGUE_TESTS.md`

## All Test Functions

1. `test_fatigue_accumulates_over_time` - Baseline: 1 fatigue per 100 turns
2. `test_fatigue_reduces_max_stamina` - 50 fatigue = 50% max stamina reduction
3. `test_fatigue_100_reduces_to_minimum` - 100 fatigue = 10 min stamina
4. `test_rest_reduces_fatigue` - rest() method works correctly
5. `test_rest_cannot_go_below_zero` - Fatigue floors at 0
6. `test_rest_fully_restores_max_stamina` - Full recovery possible
7. `test_restorative_tonic_item_exists` - Item JSON validates
8. `test_energizing_tea_item_exists` - Item JSON validates
9. `test_restorative_tonic_reduces_fatigue` - -25 fatigue effect
10. `test_energizing_tea_reduces_fatigue` - -15 fatigue effect
11. `test_max_stamina_increases_with_fatigue_decrease` - Recovery verified
12. `test_partial_fatigue_recovery_increases_max_stamina` - Proportional recovery
13. `test_stamina_clamped_when_max_decreases` - Clamping works
14. `test_rest_rate_calculation` - 1 fatigue per 10 rest turns
15. `test_full_recovery_time` - 1000 turns for full recovery
16. `test_recovery_rate_faster_than_accumulation` - 10x faster
17. `test_zero_fatigue_stays_zero` - Edge case
18. `test_multiple_consumables_stack` - Items stack correctly
19. `test_restorative_tonic_recipe_exists` - Recipe JSON validates
20. `test_energizing_tea_recipe_exists` - Recipe JSON validates

## Running Tests

### Option 1: Command Line (Recommended)

```bash
# Make script executable
chmod +x run_fatigue_tests.sh

# Run tests
./run_fatigue_tests.sh
```

### Option 2: Direct GUT Command

```bash
godot4 --headless --script addons/gut/gut_cmdln.gd \
  -gtest=tests/unit/test_fatigue_recovery.gd \
  -gexit
```

### Option 3: Godot Editor

1. Open project in Godot
2. Click **Scene > Run Test Scene** (or press F6)
3. In GUT panel, select `test_fatigue_recovery.gd`
4. Click **Run**

### Option 4: Run All Unit Tests

```bash
godot4 --headless --script addons/gut/gut_cmdln.gd \
  -gdir=tests/unit \
  -gexit
```

## Expected Output

```
===========================================
  Gut
    v9.x.x
===========================================

-- test_fatigue_recovery.gd --
  * test_fatigue_accumulates_over_time                     [pass]
  * test_fatigue_reduces_max_stamina                       [pass]
  * test_fatigue_100_reduces_to_minimum                    [pass]
  * test_rest_reduces_fatigue                              [pass]
  * test_rest_cannot_go_below_zero                         [pass]
  * test_rest_fully_restores_max_stamina                   [pass]
  * test_restorative_tonic_item_exists                     [pass]
  * test_energizing_tea_item_exists                        [pass]
  * test_restorative_tonic_reduces_fatigue                 [pass]
  * test_energizing_tea_reduces_fatigue                    [pass]
  * test_max_stamina_increases_with_fatigue_decrease       [pass]
  * test_partial_fatigue_recovery_increases_max_stamina    [pass]
  * test_stamina_clamped_when_max_decreases                [pass]
  * test_rest_rate_calculation                             [pass]
  * test_full_recovery_time                                [pass]
  * test_recovery_rate_faster_than_accumulation            [pass]
  * test_zero_fatigue_stays_zero                           [pass]
  * test_multiple_consumables_stack                        [pass]
  * test_restorative_tonic_recipe_exists                   [pass]
  * test_energizing_tea_recipe_exists                      [pass]

===========================================
Totals:       20 pass  0 fail  0 pending
===========================================
```

## Verifying Files Exist

Before running tests, verify these files were created:

```bash
# Check items
ls -l data/items/consumables/restorative_tonic.json
ls -l data/items/consumables/energizing_tea.json

# Check recipes
ls -l data/recipes/consumables/restorative_tonic.json
ls -l data/recipes/consumables/energizing_tea.json

# Check test file
ls -l tests/unit/test_fatigue_recovery.gd

# Check implementation
grep -n "rest(1.0)" scenes/game.gd
```

## Manual Verification (In-Game)

After tests pass, verify in-game:

1. **Start a new game**
2. **Wait/move for 100 turns** (press `.` to wait)
   - Open character sheet (`C`)
   - Check fatigue increased by 1
   - Check max stamina decreased slightly

3. **Rest for 100 turns** (press `Z`, select option 1 or 2)
   - Open character sheet
   - Check fatigue decreased by 10
   - Check max stamina increased

4. **Craft Energizing Tea** (if ingredients available)
   - Recipe: 1 healing herb + 1 fresh water (requires fire)
   - Consume it (`I` to open inventory)
   - Check fatigue decreased by 15

5. **Craft Restorative Tonic** (if ingredients available)
   - Recipe: 2 healing herbs + 1 cave mushroom + 1 fresh water
   - Consume it
   - Check fatigue decreased by 25

## Troubleshooting

### Tests Fail: "Identifier 'GutTest' not declared"

**Solution**: GUT is not installed or not in project
```bash
# Check if GUT exists
ls addons/gut/

# If missing, install GUT from Asset Library
```

### Tests Fail: "Cannot preload"

**Solution**: File paths are incorrect
```bash
# Verify paths exist
ls -l systems/survival_system.gd
ls -l items/item.gd
```

### Tests Fail: "Item definition should exist"

**Solution**: Item JSON files missing
```bash
# Verify items were created
ls -l data/items/consumables/restorative_tonic.json
ls -l data/items/consumables/energizing_tea.json
```

### Tests Fail: Max Stamina Calculations Wrong

**Solution**: Check implementation in `scenes/game.gd`
```bash
# Should see this around line 2146
grep -A2 "rest_turns_elapsed % 10" scenes/game.gd
```

Expected output:
```gdscript
if rest_turns_elapsed % 10 == 0:
    player.survival.rest(1.0)
```

## Files Modified/Created

### Modified Files
- ✅ `scenes/game.gd` (lines 2141-2147) - Added fatigue reduction during rest
- ✅ `docs/systems/survival-system.md` - Updated documentation

### Created Files
- ✅ `data/items/consumables/restorative_tonic.json`
- ✅ `data/items/consumables/energizing_tea.json`
- ✅ `data/recipes/consumables/restorative_tonic.json`
- ✅ `data/recipes/consumables/energizing_tea.json`
- ✅ `tests/unit/test_fatigue_recovery.gd`
- ✅ `tests/unit/test_fatigue_recovery.gd.uid`
- ✅ `tests/unit/README_FATIGUE_TESTS.md`
- ✅ `run_fatigue_tests.sh`
- ✅ `tests/unit/TEST_VALIDATION.md` (this file)

## Quick Health Check

Run this to verify all components:

```bash
# Count test functions
grep -c "^func test_" tests/unit/test_fatigue_recovery.gd
# Expected: 20

# Verify implementation
grep -n "survival.rest(1.0)" scenes/game.gd
# Expected: Line ~2147

# Verify items
cat data/items/consumables/restorative_tonic.json | grep fatigue
# Expected: "fatigue": 25

cat data/items/consumables/energizing_tea.json | grep fatigue
# Expected: "fatigue": 15
```

## Test Execution Log

Record your test runs here:

```
Date: __________
Result: [ ] PASS  [ ] FAIL
Notes: ___________________________________
         ___________________________________
```

---

**Status**: ✅ All test infrastructure ready
**Next Step**: Run `./run_fatigue_tests.sh` or open in Godot Editor
