# Phase 17: Mind Spells

## Overview
Implement Enchantment school spells that affect creature minds: Charm, Fear, Calm, Enrage.

## Dependencies
- Phase 7: Buff/Debuff Spells
- Phase 8: Saving Throws

## Implementation Steps

### 17.1 Add Mind-Affecting Immunity Check
**File:** `entities/entity.gd`

```gdscript
var creature_type: String = "humanoid"  # humanoid, animal, undead, construct
var min_int_for_mind_control: int = 3

func can_be_mind_controlled() -> bool:
    # Constructs are always immune
    if creature_type == "construct":
        return false

    # Undead have high resistance (handled in saves)
    # Low INT creatures are immune
    if get_effective_attribute("INT") < min_int_for_mind_control:
        return false

    return true

func get_mind_save_modifier() -> int:
    # Undead get bonus to resist
    if creature_type == "undead":
        return 5
    # Animals are more susceptible
    if creature_type == "animal":
        return -2
    return 0
```

### 17.2 Implement Charm Effect
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_charm(caster: Entity, target: Entity, spell: Spell, result: Dictionary) -> Dictionary:
    if not target.can_be_mind_controlled():
        result.success = false
        result.message = "%s is immune to mind control." % target.entity_name
        caster.survival.mana += spell.mana_cost  # Refund
        return result

    # Apply save with creature type modifier
    var dc = calculate_save_dc(caster, spell)
    var save_mod = target.get_mind_save_modifier()
    var save_succeeded = attempt_saving_throw(target, spell.save.type, dc - save_mod)

    if save_succeeded:
        result.message = "%s resists your charm!" % target.entity_name
        return result

    # Charm succeeds - change faction temporarily
    var duration = _calculate_duration(spell, caster)

    var effect = {
        id = "charm_effect",
        type = "charm",
        original_faction = target.faction,
        remaining_duration = duration,
        source = caster
    }

    target.faction = "player"
    target.add_magical_effect(effect)

    # Requires concentration
    caster.start_concentration(spell.id)

    result.message = "%s is now under your control!" % target.entity_name
    return result
```

### 17.3 Implement Fear Effect
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_fear(caster: Entity, target: Entity, spell: Spell, result: Dictionary) -> Dictionary:
    if not target.can_be_mind_controlled():
        result.success = false
        result.message = "%s is immune to fear." % target.entity_name
        return result

    # Save check
    var dc = calculate_save_dc(caster, spell)
    if attempt_saving_throw(target, "WIS", dc):
        result.message = "%s shakes off the fear!" % target.entity_name
        return result

    var duration = _calculate_duration(spell, caster)

    var effect = {
        id = "fear_effect",
        type = "fear",
        flee_from = caster.position,
        remaining_duration = duration
    }

    target.add_magical_effect(effect)
    target.ai_state = "fleeing"

    result.message = "%s flees in terror!" % target.entity_name
    return result
```

### 17.4 Implement Calm Effect
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_calm(caster: Entity, target: Entity, spell: Spell, result: Dictionary) -> Dictionary:
    if not target.can_be_mind_controlled():
        result.success = false
        result.message = "%s cannot be calmed." % target.entity_name
        return result

    # Save check
    var dc = calculate_save_dc(caster, spell)
    if attempt_saving_throw(target, "WIS", dc):
        result.message = "%s resists your attempt to calm it." % target.entity_name
        return result

    var duration = _calculate_duration(spell, caster)

    var effect = {
        id = "calm_effect",
        type = "calm",
        original_faction = target.faction,
        remaining_duration = duration
    }

    target.faction = "neutral"
    target.ai_state = "idle"
    target.add_magical_effect(effect)

    result.message = "%s becomes calm and non-hostile." % target.entity_name
    return result
```

### 17.5 Implement Enrage Effect
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_enrage(caster: Entity, target: Entity, spell: Spell, result: Dictionary) -> Dictionary:
    if not target.can_be_mind_controlled():
        result.success = false
        result.message = "%s is immune to this magic." % target.entity_name
        return result

    var duration = _calculate_duration(spell, caster)

    var effect = {
        id = "enrage_effect",
        type = "enrage",
        remaining_duration = duration
    }

    # Enraged creatures attack ANYTHING nearby, including allies
    target.ai_state = "berserk"
    target.faction = "hostile_to_all"
    target.add_magical_effect(effect)

    result.message = "%s flies into a rage!" % target.entity_name
    return result
```

### 17.6 Handle Effect Expiration
**File:** `entities/entity.gd`

```gdscript
func remove_magical_effect(effect_id: String) -> void:
    for i in range(active_effects.size() - 1, -1, -1):
        var effect = active_effects[i]
        if effect.id == effect_id:
            # Restore original state for mind effects
            match effect.type:
                "charm", "calm":
                    faction = effect.original_faction
                    ai_state = "normal"
                "fear":
                    ai_state = "normal"
                "enrage":
                    faction = effect.get("original_faction", "enemy")
                    ai_state = "normal"

            active_effects.remove_at(i)
            EventBus.effect_removed.emit(self, effect)
```

### 17.7 Update Enemy AI for Mind Effects
**File:** `entities/enemy.gd`

```gdscript
func process_turn() -> void:
    match ai_state:
        "fleeing":
            _flee_from_fear_source()
        "berserk":
            _attack_nearest_anything()
        "idle":
            pass  # Do nothing when calmed
        _:
            # Normal AI
            _normal_behavior()

func _flee_from_fear_source() -> void:
    var fear_effect = _get_effect_by_type("fear")
    if fear_effect:
        var flee_from = fear_effect.flee_from
        _move_away_from(flee_from)

func _attack_nearest_anything() -> void:
    var nearest = _find_nearest_entity()  # Any entity, not just enemies
    if nearest and _is_adjacent(nearest):
        attack(nearest)
    elif nearest:
        _move_toward(nearest.position)
```

### 17.8 Create Mind Spell JSON Files
**File:** `data/spells/enchantment/charm.json`

```json
{
  "id": "charm",
  "name": "Charm",
  "description": "Bend a creature's will to your own.",
  "school": "enchantment",
  "level": 6,
  "mana_cost": 30,
  "requirements": {"character_level": 6, "intelligence": 13},
  "targeting": {"mode": "ranged", "range": 6, "requires_los": true},
  "concentration": true,
  "effects": {"mind_effect": "charm"},
  "duration": {"base": 50, "scaling": 10},
  "save": {"type": "WIS", "on_success": "no_effect"},
  "cast_message": "You exert your will over the creature!"
}
```

**File:** `data/spells/enchantment/fear.json`

```json
{
  "id": "fear",
  "name": "Fear",
  "description": "Fill a creature with overwhelming terror.",
  "school": "enchantment",
  "level": 3,
  "mana_cost": 15,
  "requirements": {"character_level": 3, "intelligence": 10},
  "targeting": {"mode": "ranged", "range": 6, "requires_los": true},
  "effects": {"mind_effect": "fear"},
  "duration": {"base": 10, "scaling": 3},
  "save": {"type": "WIS", "on_success": "no_effect"},
  "cast_message": "Terror grips your target!"
}
```

**File:** `data/spells/enchantment/calm.json`

```json
{
  "id": "calm",
  "name": "Calm",
  "description": "Soothe a hostile creature into neutrality.",
  "school": "enchantment",
  "level": 2,
  "mana_cost": 10,
  "requirements": {"character_level": 2, "intelligence": 9},
  "targeting": {"mode": "ranged", "range": 6, "requires_los": true},
  "effects": {"mind_effect": "calm"},
  "duration": {"base": 20, "scaling": 5},
  "save": {"type": "WIS", "on_success": "no_effect"},
  "cast_message": "The creature's hostility fades."
}
```

**File:** `data/spells/enchantment/enrage.json`

```json
{
  "id": "enrage",
  "name": "Enrage",
  "description": "Drive a creature into a berserk fury.",
  "school": "enchantment",
  "level": 4,
  "mana_cost": 18,
  "requirements": {"character_level": 4, "intelligence": 11},
  "targeting": {"mode": "ranged", "range": 6, "requires_los": true},
  "effects": {"mind_effect": "enrage"},
  "duration": {"base": 15, "scaling": 4},
  "save": {"type": "WIS", "on_success": "no_effect"},
  "cast_message": "Rage consumes your target!"
}
```

### 17.9 Add Creature Types to Enemy Data
**File:** `data/enemies/` (various files)

Add `"creature_type"` field:
- Wolves, rats: `"animal"`
- Skeletons, wights: `"undead"`
- Golems: `"construct"`
- Bandits, mages: `"humanoid"`

## Testing Checklist

- [ ] Charm makes enemy fight for player
- [ ] Charmed enemy attacks other enemies
- [ ] Charm requires concentration
- [ ] Breaking concentration ends charm
- [ ] Fear makes enemy flee from caster
- [ ] Fleeing enemy moves away each turn
- [ ] Calm makes hostile enemy neutral
- [ ] Calmed enemy doesn't attack
- [ ] Enrage makes enemy attack everything
- [ ] Enraged enemy attacks its allies
- [ ] Constructs are immune to all mind spells
- [ ] Low INT creatures (< 3) are immune
- [ ] Undead get +5 to saves vs mind control
- [ ] Animals get -2 to saves vs mind control
- [ ] Effects expire after duration
- [ ] Original faction restored on expiration

## Documentation Updates

- [ ] CLAUDE.md updated with mind spell mechanics
- [ ] Help screen updated with mind spell info
- [ ] `docs/systems/magic-system.md` updated
- [ ] `docs/data/spells.md` updated with mind effect format

## Files Modified
- `entities/entity.gd`
- `entities/enemy.gd`
- `systems/magic_system.gd`

## Files Created
- `data/spells/enchantment/charm.json`
- `data/spells/enchantment/fear.json`
- `data/spells/enchantment/calm.json`
- `data/spells/enchantment/enrage.json`

## Next Phase
Once mind spells work, proceed to **Phase 18: Town Mage NPC**
