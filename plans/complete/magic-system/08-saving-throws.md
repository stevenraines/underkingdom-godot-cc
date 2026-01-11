# Phase 8: Saving Throws

## Overview
Implement the saving throw mechanic allowing targets to resist spell effects.

## Dependencies
- Phase 7: Buff & Debuff Spells

## Implementation Steps

### 8.1 Add Saving Throw Calculation
**File:** `systems/magic_system.gd`

```gdscript
static func calculate_save_dc(caster: Entity, spell: Spell) -> int:
    # DC = 10 + Spell Level + (Caster INT / 2)
    var caster_int = caster.get_effective_attribute("INT")
    return 10 + spell.level + (caster_int / 2)

static func attempt_saving_throw(target: Entity, save_type: String, dc: int) -> bool:
    # Roll = d20 + Target's attribute modifier
    var roll = randi_range(1, 20)
    var attribute_mod = 0

    match save_type:
        "STR": attribute_mod = (target.get_effective_attribute("STR") - 10) / 2
        "DEX": attribute_mod = (target.get_effective_attribute("DEX") - 10) / 2
        "CON": attribute_mod = (target.get_effective_attribute("CON") - 10) / 2
        "INT": attribute_mod = (target.get_effective_attribute("INT") - 10) / 2
        "WIS": attribute_mod = (target.get_effective_attribute("WIS") - 10) / 2
        "CHA": attribute_mod = (target.get_effective_attribute("CHA") - 10) / 2

    var total = roll + attribute_mod
    return total >= dc
```

### 8.2 Integrate Saving Throws into Spell Resolution
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_ranged_spell(caster: Entity, spell: Spell, target: Entity, result: Dictionary) -> Dictionary:
    var save_succeeded = false

    # Check if spell has a saving throw
    if "save" in spell:
        var save_data = spell.save
        var dc = calculate_save_dc(caster, spell)
        save_succeeded = attempt_saving_throw(target, save_data.type, dc)

        if save_succeeded:
            result.save_succeeded = true
            match save_data.on_success:
                "no_effect":
                    result.message = "%s resists the %s!" % [target.entity_name, spell.name]
                    return result
                "half_damage":
                    # Continue but halve damage
                    pass
                "half_duration":
                    # Continue but halve duration
                    pass

    # Apply damage (with potential halving)
    if "damage" in spell.effects:
        var damage = _calculate_spell_damage(caster, spell)
        if save_succeeded and spell.save.on_success == "half_damage":
            damage = damage / 2
        target.take_damage(damage, caster, "spell_" + spell.id)
        result.damage_dealt = damage

    # Apply debuffs (with potential duration halving)
    if "debuff" in spell.effects:
        if not (save_succeeded and spell.save.on_success == "no_effect"):
            var duration = _calculate_debuff_duration(caster, spell)
            if save_succeeded and spell.save.on_success == "half_duration":
                duration = duration / 2
            _apply_debuff(target, spell, duration)

    return result
```

### 8.3 Add Save Result to Combat Log
**File:** `systems/magic_system.gd`

Include save information in result messages:
```gdscript
if save_succeeded:
    match spell.save.on_success:
        "half_damage":
            result.message += " (%s partially resists!)" % target.entity_name
        "half_duration":
            result.message += " (%s shakes off some of the effect!)" % target.entity_name
```

### 8.4 Update Spell JSON with Save Data

Ensure debuff spells have save data:

**Already defined in Phase 7:**
- `weakness.json`: CON save, half_duration
- `curse.json`: WIS save, no_effect

**Add to mind spells (Phase 18):**
- charm: WIS save, no_effect
- fear: WIS save, no_effect

### 8.5 Add Enemy Attribute Modifiers
**File:** `entities/enemy.gd`

Ensure enemies have meaningful attributes for saves:
```gdscript
# Enemies should have attributes in their JSON definitions
# Example: A smart enemy has high INT for resisting mind control
# Example: A tough enemy has high CON for resisting poison
```

### 8.6 Display Save DC in Spell Info
**File:** `ui/spell_cast_menu.gd`

Show save DC when hovering over spell:
```
Weakness (Level 3)
Mana: 12 | Range: 6
Save: CON DC 15
Effect: -3 STR for 25 turns
```

## Testing Checklist

- [ ] Weakness spell can be resisted (CON save)
- [ ] Curse spell can be fully resisted (WIS save, no_effect)
- [ ] High CON enemy resists more often than low CON
- [ ] Save DC increases with caster level
- [ ] Save DC increases with caster INT
- [ ] "Partially resists" message for half_damage/half_duration
- [ ] "Resists" message for no_effect saves
- [ ] Halved damage/duration applied correctly
- [ ] Save DC displayed in spell tooltip

## Files Modified
- `systems/magic_system.gd`
- `ui/spell_cast_menu.gd`

## Files Created
- None

## Next Phase
Once saving throws work, proceed to **Phase 9: Spell Scaling**
