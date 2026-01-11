# Phase 4: Basic Spell Casting

## Overview
Implement the core spell casting mechanic for self-targeting spells, including mana consumption and success/failure rolls.

## Dependencies
- Phase 1: Mana System
- Phase 2: Spell Data & Manager
- Phase 3: Spellbook & Learning

## Implementation Steps

### 4.1 Create MagicSystem Static Class
**File:** `systems/magic_system.gd` (new)

```gdscript
class_name MagicSystem
extends RefCounted

const MIN_INT_FOR_MAGIC = 8
const MIN_FAILURE_CHANCE = 2
const MAX_FAILURE_CHANCE = 25

static func attempt_spell(caster: Entity, spell: Spell, targets: Array = []) -> Dictionary:
    var result = {
        success = false,
        damage_dealt = 0,
        effects_applied = [],
        failure_type = "",  # "fizzle", "backfire", "wild_magic"
        message = ""
    }

    # Validate requirements
    var can_cast = SpellManager.can_cast(caster, spell)
    if not can_cast.can_cast:
        result.message = can_cast.reason
        return result

    # Consume mana
    caster.survival.consume_mana(spell.mana_cost)

    # Roll for failure
    var failure_chance = calculate_failure_chance(caster, spell)
    var roll = randf() * 100

    if roll < failure_chance:
        result = _handle_spell_failure(caster, spell)
        EventBus.spell_cast.emit(caster, spell, targets, result)
        return result

    # Spell succeeds - apply effects based on targeting mode
    result.success = true
    result = _apply_spell_effects(caster, spell, targets, result)

    EventBus.spell_cast.emit(caster, spell, targets, result)
    return result

static func calculate_failure_chance(caster: Entity, spell: Spell) -> float:
    var level_diff = spell.level - caster.level
    var base_chance: float

    match level_diff:
        var d when d >= 0: base_chance = MAX_FAILURE_CHANCE
        -1: base_chance = 15.0
        -2: base_chance = 10.0
        -3: base_chance = 5.0
        _: base_chance = MIN_FAILURE_CHANCE

    # INT bonus: -2% per INT above requirement
    var int_above_req = caster.get_effective_attribute("INT") - spell.requirements.intelligence
    base_chance -= int_above_req * 2.0

    return clampf(base_chance, MIN_FAILURE_CHANCE, MAX_FAILURE_CHANCE)
```

### 4.2 Implement Spell Failure Handling
**File:** `systems/magic_system.gd`

```gdscript
enum FailureType { FIZZLE, BACKFIRE, WILD_MAGIC }

static func _handle_spell_failure(caster: Entity, spell: Spell) -> Dictionary:
    var failure_roll = randi() % 3
    var result = {success = false, damage_dealt = 0, effects_applied = [], message = ""}

    match failure_roll:
        FailureType.FIZZLE:
            result.failure_type = "fizzle"
            result.message = "The spell fizzles and dissipates harmlessly."

        FailureType.BACKFIRE:
            result.failure_type = "backfire"
            var backfire_damage = spell.mana_cost / 2
            caster.take_damage(backfire_damage, caster, "spell_backfire")
            result.damage_dealt = backfire_damage
            result.message = "The spell backfires! You take %d damage." % backfire_damage

        FailureType.WILD_MAGIC:
            result.failure_type = "wild_magic"
            result.message = "Wild magic surges through you!"
            # Wild magic effects implemented in Phase 21

    return result
```

### 4.3 Implement Self-Targeting Spell Effects
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_spell_effects(caster: Entity, spell: Spell, targets: Array, result: Dictionary) -> Dictionary:
    match spell.targeting.mode:
        "self":
            result = _apply_self_spell(caster, spell, result)
        "ranged":
            if targets.size() > 0:
                result = _apply_ranged_spell(caster, spell, targets[0], result)
        # Other modes in later phases

    return result

static func _apply_self_spell(caster: Entity, spell: Spell, result: Dictionary) -> Dictionary:
    # Apply buff effects
    if "buff" in spell.effects:
        var buff = spell.effects.buff
        var duration = _calculate_scaled_value(
            buff.duration,
            buff.get("duration_scaling", 0),
            caster.level,
            spell.level
        )
        # Apply buff (detailed in Phase 7)
        result.effects_applied.append({type = "buff", duration = duration})
        result.message = spell.cast_message

    # Apply healing effects
    if "heal" in spell.effects:
        var heal_amount = _calculate_scaled_value(
            spell.effects.heal.base,
            spell.effects.heal.get("scaling", 0),
            caster.level,
            spell.level
        )
        caster.heal(heal_amount)
        result.message = "You are healed for %d health!" % heal_amount

    return result
```

### 4.4 Add Spell Scaling Calculation
**File:** `systems/magic_system.gd`

```gdscript
static func _calculate_scaled_value(base: int, scaling: int, caster_level: int, spell_level: int) -> int:
    var level_diff = max(0, caster_level - spell_level)
    var scaled = base + (scaling * level_diff)
    # Cap at 3x base value
    return mini(scaled, base * 3)
```

### 4.5 Add Casting Input Handler
**File:** `systems/input_handler.gd`

Add spell casting keybind:
```gdscript
# Press 'C' to open cast spell menu
if Input.is_action_just_pressed("cast_spell"):
    _open_spell_casting_menu()

func _open_spell_casting_menu():
    if not player.has_spellbook():
        EventBus.message_logged.emit("You need a spellbook to cast spells.", Color.RED)
        return
    if player.known_spells.is_empty():
        EventBus.message_logged.emit("You don't know any spells.", Color.YELLOW)
        return
    # Open spell selection UI
    EventBus.spell_menu_requested.emit()
```

### 4.6 Create Spell Casting UI
**IMPORTANT:** Use the `ui-implementation` agent for creating this UI.

**File:** `ui/spell_cast_menu.gd` and `ui/spell_cast_menu.tscn` (new)

- Show list of known spells player can cast
- Display mana cost, failure chance for each
- Gray out spells with insufficient mana
- Select spell to cast
- For self-targeting spells: cast immediately
- For ranged spells: enter targeting mode (Phase 5)

### 4.7 Add Input Action
**File:** `project.godot`

Add input action `cast_spell` mapped to 'C' key.

### 4.8 Add EventBus Signal for Spell Menu
**File:** `autoload/event_bus.gd`

```gdscript
signal spell_menu_requested()
signal spell_selected(spell: Spell)
```

## Testing Checklist

- [ ] Press 'C' opens spell casting menu
- [ ] Menu shows known spells with mana cost
- [ ] Selecting Shield spell casts it immediately (self-target)
- [ ] Mana is consumed on cast
- [ ] Shield spell applies armor buff
- [ ] Failure chance displayed matches formula
- [ ] Spells can fail (test with high-level spell or low INT)
- [ ] Fizzle failure: mana spent, no effect
- [ ] Backfire failure: mana spent, caster takes damage
- [ ] `spell_cast` signal fires with correct data
- [ ] Cast message displayed in log
- [ ] Cannot cast without spellbook
- [ ] Cannot cast spell with insufficient mana

## Files Modified
- `systems/input_handler.gd`
- `autoload/event_bus.gd`
- `project.godot`

## Files Created
- `systems/magic_system.gd`
- `ui/spell_cast_menu.gd`
- `ui/spell_cast_menu.tscn`

## Next Phase
Once basic casting works for self-targeting spells, proceed to **Phase 5: Ranged Spell Targeting**
