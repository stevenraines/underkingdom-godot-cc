# Phase 14: DoT Effects & Concentration

## Overview
Implement damage-over-time effects (poison, burning, bleeding) and the concentration mechanic for maintained spells.

## Dependencies
- Phase 7: Buff/Debuff Spells (active effects tracking)
- Phase 8: Saving Throws

## Implementation Steps

### 14.1 Create DoT Effect Structure
**File:** `entities/entity.gd`

Extend active effects to support DoT:
```gdscript
# DoT effect structure:
# {
#   id: "poison_from_spell",
#   type: "dot",
#   dot_type: "poison",  # poison, burning, bleeding, necrotic
#   damage_per_turn: 3,
#   remaining_duration: 10,
#   source: caster_reference
# }

func process_dot_effects() -> int:
    var total_damage = 0

    for effect in active_effects:
        if effect.type == "dot":
            total_damage += effect.damage_per_turn
            # Visual feedback
            EventBus.dot_damage_tick.emit(self, effect.dot_type, effect.damage_per_turn)

    if total_damage > 0:
        take_damage(total_damage, null, "dot")

    return total_damage
```

### 14.2 Implement Poison Spell
**File:** `data/spells/necromancy/poison.json`

```json
{
  "id": "poison",
  "name": "Poison",
  "description": "Infect your target with a virulent poison.",
  "school": "necromancy",
  "level": 1,
  "mana_cost": 5,
  "requirements": {"character_level": 1, "intelligence": 8},
  "targeting": {"mode": "ranged", "range": 6, "requires_los": true},
  "effects": {
    "dot": {
      "type": "poison",
      "damage_per_turn": 3,
      "duration": 10,
      "damage_scaling": 1,
      "duration_scaling": 2
    }
  },
  "save": {"type": "CON", "on_success": "half_duration"},
  "cast_message": "Poison seeps into your target!"
}
```

### 14.3 Apply DoT in MagicSystem
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_ranged_spell(...):
    # ... existing code ...

    if "dot" in spell.effects:
        var dot_data = spell.effects.dot
        var duration = _calculate_scaled_value(
            dot_data.duration,
            dot_data.get("duration_scaling", 0),
            caster.level,
            spell.level
        )
        var damage = _calculate_scaled_value(
            dot_data.damage_per_turn,
            dot_data.get("damage_scaling", 0),
            caster.level,
            spell.level
        )

        # Apply save for duration reduction
        if save_succeeded and spell.save.on_success == "half_duration":
            duration = duration / 2

        var effect = {
            id = spell.id + "_dot",
            type = "dot",
            dot_type = dot_data.type,
            damage_per_turn = damage,
            remaining_duration = duration,
            source = caster
        }

        target.add_magical_effect(effect)
        result.message = "%s is poisoned!" % target.entity_name
```

### 14.4 Process DoT in Turn System
**File:** `autoload/turn_manager.gd`

```gdscript
func advance_turn() -> void:
    # ... existing code ...

    # Process DoT effects for all entities
    for entity in EntityManager.get_all_entities():
        entity.process_dot_effects()
        entity.process_effect_durations()
```

### 14.5 Add DoT Visual Feedback
**File:** `rendering/ascii_renderer.gd`

```gdscript
func _on_dot_damage_tick(entity: Entity, dot_type: String, damage: int):
    var color = _get_dot_color(dot_type)
    flash_entity(entity, color, 0.1)

func _get_dot_color(dot_type: String) -> Color:
    match dot_type:
        "poison": return Color.GREEN
        "burning": return Color.ORANGE
        "bleeding": return Color.RED
        "necrotic": return Color.PURPLE
    return Color.WHITE
```

### 14.6 Add DoT Curing Items
**File:** `data/items/consumables/`

**antidote.json:**
```json
{
  "id": "antidote",
  "name": "Antidote",
  "description": "Cures poison.",
  "category": "consumable",
  "flags": {"consumable": true},
  "effects": {"cure_dot": "poison"},
  "weight": 0.2,
  "value": 25,
  "ascii_char": "!",
  "ascii_color": "#00FF00"
}
```

### 14.7 Implement Concentration Mechanic
**File:** `entities/player.gd`

```gdscript
var concentration_spell: String = ""  # ID of current concentration spell

func start_concentration(spell_id: String) -> void:
    # End previous concentration
    if concentration_spell != "":
        end_concentration()

    concentration_spell = spell_id
    EventBus.concentration_started.emit(spell_id)

func end_concentration() -> void:
    if concentration_spell != "":
        # Remove the concentration effect
        remove_magical_effect(concentration_spell + "_effect")
        EventBus.concentration_ended.emit(concentration_spell)
        concentration_spell = ""

func check_concentration(damage_taken: int) -> bool:
    if concentration_spell == "":
        return true

    # Concentration check: d20 + CON/2 vs DC 10 + damage/2
    var roll = randi_range(1, 20)
    var con_mod = (get_effective_attribute("CON") - 10) / 2
    var total = roll + con_mod
    var dc = 10 + (damage_taken / 2)

    if total < dc:
        end_concentration()
        EventBus.message_logged.emit("Your concentration is broken!", Color.RED)
        return false

    return true
```

### 14.8 Hook Concentration Check to Damage
**File:** `entities/entity.gd`

```gdscript
func take_damage(amount: int, source: Entity = null, method: String = "") -> void:
    # ... existing damage code ...

    # Check concentration if player
    if self == EntityManager.player:
        check_concentration(amount)
```

### 14.9 Mark Concentration Spells
Update spell JSON files to include `"concentration": true`:

**File:** `data/spells/enchantment/charm.json`
```json
{
  "id": "charm",
  "concentration": true,
  ...
}
```

### 14.10 Apply Concentration on Cast
**File:** `systems/magic_system.gd`

```gdscript
static func attempt_spell(...):
    # ... after successful cast ...

    if spell.concentration:
        caster.start_concentration(spell.id)
```

### 14.11 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal dot_damage_tick(entity: Entity, dot_type: String, damage: int)
signal concentration_started(spell_id: String)
signal concentration_ended(spell_id: String)
signal concentration_check(damage: int, success: bool)
```

### 14.12 Display Concentration in HUD
**IMPORTANT:** Use the `ui-implementation` agent for UI updates.

**File:** `ui/hud.gd`

Show "[CONCENTRATING: Charm]" indicator when maintaining a spell.

## Testing Checklist

- [ ] Poison spell applies DoT effect
- [ ] DoT deals damage each turn
- [ ] DoT duration counts down and expires
- [ ] Poison shows green flash on tick
- [ ] Antidote cures poison DoT
- [ ] DoT scaling increases damage with level
- [ ] Concentration spell shows in HUD
- [ ] Taking damage triggers concentration check
- [ ] Failed concentration check ends spell
- [ ] Casting new concentration spell ends previous
- [ ] Only one concentration spell active at a time
- [ ] Concentration effects persist through save/load

## Files Modified
- `entities/entity.gd`
- `entities/player.gd`
- `autoload/turn_manager.gd`
- `autoload/event_bus.gd`
- `systems/magic_system.gd`
- `rendering/ascii_renderer.gd`
- `ui/hud.gd`

## Files Created
- `data/spells/necromancy/poison.json`
- `data/items/consumables/antidote.json`

## Next Phase
Once DoT and concentration work, proceed to **Phase 15: Summoning**
