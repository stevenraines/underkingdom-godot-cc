# Phase 7: Buff & Debuff Spells

## Overview
Implement stat-modifying spells with duration tracking, including buffs (Shield, Stone Skin) and debuffs (Weakness, Curse).

## Dependencies
- Phase 6: Damage Spells
- Existing: Entity stat_modifiers system

## Implementation Steps

### 7.1 Create Active Effects Tracking
**File:** `entities/entity.gd`

Add active magical effects tracking:
```gdscript
var active_effects: Array[Dictionary] = []
# Each effect: {id, type, modifiers, remaining_duration, source_spell}

func add_magical_effect(effect: Dictionary) -> void:
    # Check if effect already exists (refresh duration)
    for existing in active_effects:
        if existing.id == effect.id:
            existing.remaining_duration = effect.remaining_duration
            _recalculate_modifiers()
            return

    active_effects.append(effect)
    _recalculate_modifiers()
    EventBus.effect_applied.emit(self, effect)

func remove_magical_effect(effect_id: String) -> void:
    for i in range(active_effects.size() - 1, -1, -1):
        if active_effects[i].id == effect_id:
            var effect = active_effects[i]
            active_effects.remove_at(i)
            EventBus.effect_removed.emit(self, effect)
    _recalculate_modifiers()

func _recalculate_modifiers() -> void:
    # Reset modifiers
    for stat in stat_modifiers:
        stat_modifiers[stat] = 0

    # Apply survival modifiers (hunger, etc.)
    if survival:
        var survival_mods = survival.get_stat_modifiers()
        for stat in survival_mods:
            stat_modifiers[stat] += survival_mods[stat]

    # Apply magical effect modifiers
    for effect in active_effects:
        if "modifiers" in effect:
            for stat in effect.modifiers:
                if stat in stat_modifiers:
                    stat_modifiers[stat] += effect.modifiers[stat]
```

### 7.2 Create Effect Duration Processing
**File:** `entities/entity.gd`

```gdscript
func process_effect_durations() -> void:
    var expired: Array[String] = []

    for effect in active_effects:
        effect.remaining_duration -= 1
        if effect.remaining_duration <= 0:
            expired.append(effect.id)

    for effect_id in expired:
        remove_magical_effect(effect_id)
        EventBus.message_logged.emit("The effect of %s has worn off." % effect_id, Color.GRAY)
```

### 7.3 Integrate Effect Processing with Turn System
**File:** `autoload/turn_manager.gd`

```gdscript
func advance_turn() -> void:
    # ... existing code ...

    # Process effect durations for player
    if EntityManager.player:
        EntityManager.player.process_effect_durations()

    # Process effect durations for all entities
    for entity in EntityManager.get_all_entities():
        entity.process_effect_durations()
```

### 7.4 Implement Buff Application in MagicSystem
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_self_spell(caster: Entity, spell: Spell, result: Dictionary) -> Dictionary:
    if "buff" in spell.effects:
        var buff_data = spell.effects.buff
        var duration = _calculate_scaled_value(
            buff_data.duration,
            buff_data.get("duration_scaling", 0),
            caster.level,
            spell.level
        )

        var effect = {
            id = spell.id + "_buff",
            type = "buff",
            source_spell = spell.id,
            remaining_duration = duration,
            modifiers = {}
        }

        # Build modifiers from buff data
        if "armor_bonus" in buff_data:
            effect.modifiers["armor"] = buff_data.armor_bonus
        if "str_bonus" in buff_data:
            effect.modifiers["STR"] = buff_data.str_bonus
        if "dex_bonus" in buff_data:
            effect.modifiers["DEX"] = buff_data.dex_bonus
        # ... other stats

        caster.add_magical_effect(effect)
        result.effects_applied.append(effect)
        result.message = spell.cast_message

    return result
```

### 7.5 Implement Debuff Application
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_ranged_spell(...):
    # ... damage code ...

    if "debuff" in spell.effects:
        var debuff_data = spell.effects.debuff
        var duration = _calculate_scaled_value(
            debuff_data.duration,
            debuff_data.get("duration_scaling", 0),
            caster.level,
            spell.level
        )

        var effect = {
            id = spell.id + "_debuff",
            type = "debuff",
            source_spell = spell.id,
            remaining_duration = duration,
            modifiers = {}
        }

        # Build negative modifiers
        if "str_penalty" in debuff_data:
            effect.modifiers["STR"] = -debuff_data.str_penalty
        if "dex_penalty" in debuff_data:
            effect.modifiers["DEX"] = -debuff_data.dex_penalty
        # ... other stats

        target.add_magical_effect(effect)
        result.effects_applied.append(effect)
```

### 7.6 Create Buff/Debuff Spell JSON Files

**File:** `data/spells/abjuration/shield.json` (update existing)
```json
{
  "id": "shield",
  "name": "Shield",
  "description": "A magical barrier provides temporary protection.",
  "school": "abjuration",
  "level": 1,
  "mana_cost": 5,
  "requirements": {"character_level": 1, "intelligence": 8},
  "targeting": {"mode": "self"},
  "effects": {
    "buff": {
      "armor_bonus": 3,
      "duration": 20,
      "duration_scaling": 5
    }
  },
  "cast_message": "A shimmering shield surrounds you!"
}
```

**File:** `data/spells/transmutation/stone_skin.json`
```json
{
  "id": "stone_skin",
  "name": "Stone Skin",
  "description": "Your skin hardens like stone.",
  "school": "transmutation",
  "level": 3,
  "mana_cost": 15,
  "requirements": {"character_level": 3, "intelligence": 10},
  "targeting": {"mode": "self"},
  "effects": {
    "buff": {
      "armor_bonus": 5,
      "duration": 30,
      "duration_scaling": 8
    }
  },
  "cast_message": "Your skin takes on a stony texture!"
}
```

**File:** `data/spells/necromancy/weakness.json`
```json
{
  "id": "weakness",
  "name": "Weakness",
  "description": "Sap the strength from your enemy.",
  "school": "necromancy",
  "level": 3,
  "mana_cost": 12,
  "requirements": {"character_level": 3, "intelligence": 10},
  "targeting": {"mode": "ranged", "range": 6, "requires_los": true},
  "effects": {
    "debuff": {
      "str_penalty": 3,
      "duration": 25,
      "duration_scaling": 5
    }
  },
  "save": {"type": "CON", "on_success": "half_duration"},
  "cast_message": "Dark energy saps your target's strength!"
}
```

**File:** `data/spells/necromancy/curse.json`
```json
{
  "id": "curse",
  "name": "Curse",
  "description": "Afflict your target with a debilitating curse.",
  "school": "necromancy",
  "level": 4,
  "mana_cost": 18,
  "requirements": {"character_level": 4, "intelligence": 11},
  "targeting": {"mode": "ranged", "range": 6, "requires_los": true},
  "effects": {
    "debuff": {
      "str_penalty": 2,
      "dex_penalty": 2,
      "con_penalty": 2,
      "duration": 40,
      "duration_scaling": 10
    }
  },
  "save": {"type": "WIS", "on_success": "no_effect"},
  "cast_message": "A terrible curse falls upon your enemy!"
}
```

### 7.7 Add Active Effects to HUD
**File:** `ui/hud.gd`

Display active buffs/debuffs with remaining duration:
```gdscript
func _update_active_effects():
    # Show icons/text for active effects
    # Green for buffs, red for debuffs
    # Show remaining duration
```

### 7.8 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal effect_applied(entity: Entity, effect: Dictionary)
signal effect_removed(entity: Entity, effect: Dictionary)
```

### 7.9 Add Effects to Save/Load
**File:** `autoload/save_manager.gd`

Include `active_effects` array in entity serialization.

## Testing Checklist

- [ ] Shield spell adds armor buff to player
- [ ] Buff shows in HUD with duration countdown
- [ ] Buff wears off after duration expires
- [ ] Stone Skin provides higher armor than Shield
- [ ] Weakness reduces enemy STR
- [ ] Curse reduces multiple stats
- [ ] Debuff duration scales with caster level
- [ ] Re-casting same buff refreshes duration
- [ ] Effects persist through save/load
- [ ] "Effect worn off" message displays
- [ ] Enemy with Weakness debuff deals less damage

## Files Modified
- `entities/entity.gd`
- `autoload/turn_manager.gd`
- `autoload/event_bus.gd`
- `autoload/save_manager.gd`
- `systems/magic_system.gd`
- `ui/hud.gd`

## Files Created
- `data/spells/transmutation/stone_skin.json`
- `data/spells/necromancy/weakness.json`
- `data/spells/necromancy/curse.json`

## Next Phase
Once buffs/debuffs work, proceed to **Phase 8: Saving Throws**
