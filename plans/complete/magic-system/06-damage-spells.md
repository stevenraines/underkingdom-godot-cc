# Phase 6: Damage Spells

## Overview
Implement damage-dealing spells including damage calculation, scaling, and damage types.

## Dependencies
- Phase 5: Ranged Spell Targeting

## Implementation Steps

### 6.1 Implement Damage Effect Application
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_ranged_spell(caster: Entity, spell: Spell, target: Entity, result: Dictionary) -> Dictionary:
    # Apply damage effects
    if "damage" in spell.effects:
        var damage_data = spell.effects.damage
        var base_damage = damage_data.base
        var scaling = damage_data.get("scaling", 0)

        var final_damage = _calculate_scaled_value(base_damage, scaling, caster.level, spell.level)

        # Apply damage type resistances (Phase 22)
        # For now, apply full damage
        target.take_damage(final_damage, caster, "spell_" + spell.id)

        result.damage_dealt = final_damage
        result.message = "%s hits %s for %d %s damage!" % [
            spell.name,
            target.entity_name,
            final_damage,
            damage_data.type
        ]

    return result
```

### 6.2 Add Damage Type to Entity.take_damage()
**File:** `entities/entity.gd`

Extend take_damage to include damage type:
```gdscript
func take_damage(amount: int, source: Entity = null, method: String = "", damage_type: String = "physical") -> void:
    # Existing damage logic
    var final_amount = amount

    # Resistance/vulnerability checks (Phase 22)
    # final_amount = _apply_damage_resistance(final_amount, damage_type)

    current_health -= final_amount
    EventBus.entity_damaged.emit(self, final_amount, source, method, damage_type)

    if current_health <= 0:
        die(source)
```

### 6.3 Add Visual Feedback for Spell Hits
**File:** `rendering/ascii_renderer.gd`

Flash the target when hit by a spell:
```gdscript
func flash_entity(entity: Entity, color: Color, duration: float = 0.2):
    # Temporarily change entity color
    var original_color = entity.ascii_color
    entity.ascii_color = color
    _update_entity_visual(entity)

    # Timer to restore
    await get_tree().create_timer(duration).timeout
    entity.ascii_color = original_color
    _update_entity_visual(entity)
```

Color by damage type:
- Lightning: Yellow (#FFFF00)
- Fire: Orange (#FF6600)
- Ice: Cyan (#00FFFF)
- Poison: Green (#00FF00)
- Holy: White (#FFFFFF)
- Necrotic: Purple (#AA00AA)

### 6.4 Create All Evocation Damage Spells
**File:** `data/spells/evocation/`

Create JSON files for:
- `spark.json` (Level 1) - Already created
- `flame_bolt.json` (Level 2)
- `ice_shard.json` (Level 3)
- `lightning_bolt.json` (Level 5)
- `fireball.json` (Level 7) - AOE, implemented in Phase 17

**flame_bolt.json:**
```json
{
  "id": "flame_bolt",
  "name": "Flame Bolt",
  "description": "A bolt of fire streaks toward your target.",
  "school": "evocation",
  "level": 2,
  "mana_cost": 8,
  "requirements": {
    "character_level": 2,
    "intelligence": 9
  },
  "targeting": {
    "mode": "ranged",
    "range": 8,
    "requires_los": true
  },
  "effects": {
    "damage": {
      "type": "fire",
      "base": 12,
      "scaling": 4
    },
    "status_chance": 0.2,
    "status": "burning"
  },
  "cast_message": "You hurl a bolt of flame!",
  "ascii_char": "*",
  "ascii_color": "#FF6600"
}
```

**ice_shard.json:**
```json
{
  "id": "ice_shard",
  "name": "Ice Shard",
  "description": "A razor-sharp shard of ice impales your target.",
  "school": "evocation",
  "level": 3,
  "mana_cost": 12,
  "requirements": {
    "character_level": 3,
    "intelligence": 10
  },
  "targeting": {
    "mode": "ranged",
    "range": 7,
    "requires_los": true
  },
  "effects": {
    "damage": {
      "type": "ice",
      "base": 15,
      "scaling": 5
    },
    "status_chance": 0.3,
    "status": "slowed"
  },
  "cast_message": "You launch a shard of ice!",
  "ascii_char": "*",
  "ascii_color": "#00FFFF"
}
```

**lightning_bolt.json:**
```json
{
  "id": "lightning_bolt",
  "name": "Lightning Bolt",
  "description": "A devastating bolt of lightning strikes your foe.",
  "school": "evocation",
  "level": 5,
  "mana_cost": 25,
  "requirements": {
    "character_level": 5,
    "intelligence": 12
  },
  "targeting": {
    "mode": "ranged",
    "range": 10,
    "requires_los": true
  },
  "effects": {
    "damage": {
      "type": "lightning",
      "base": 30,
      "scaling": 7
    }
  },
  "cast_message": "Lightning arcs from your fingertips!",
  "ascii_char": "*",
  "ascii_color": "#FFFF00"
}
```

### 6.5 Create Necromancy Damage Spell
**File:** `data/spells/necromancy/drain_life.json`

```json
{
  "id": "drain_life",
  "name": "Drain Life",
  "description": "Siphon life force from your target to heal yourself.",
  "school": "necromancy",
  "level": 2,
  "mana_cost": 10,
  "requirements": {
    "character_level": 2,
    "intelligence": 9
  },
  "targeting": {
    "mode": "ranged",
    "range": 5,
    "requires_los": true
  },
  "effects": {
    "damage": {
      "type": "necrotic",
      "base": 10,
      "scaling": 3
    },
    "heal_percent": 0.5
  },
  "cast_message": "Dark energy flows from your target into you!",
  "ascii_char": "*",
  "ascii_color": "#AA00AA"
}
```

### 6.6 Implement Drain Life Healing
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_ranged_spell(...):
    # ... damage application ...

    # Handle life drain
    if "heal_percent" in spell.effects:
        var heal_amount = int(result.damage_dealt * spell.effects.heal_percent)
        caster.heal(heal_amount)
        result.message += " You recover %d health!" % heal_amount
```

### 6.7 Add Combat Log Messages
**File:** `autoload/event_bus.gd`

Ensure spell damage shows in combat log:
```gdscript
signal combat_message(message: String, color: Color)
```

Connect spell results to combat log display.

## Testing Checklist

- [ ] Spark deals lightning damage to target
- [ ] Flame Bolt deals fire damage
- [ ] Ice Shard deals ice damage
- [ ] Lightning Bolt deals high lightning damage
- [ ] Drain Life damages enemy and heals caster
- [ ] Damage scales with caster level (test at level 1 vs level 5)
- [ ] Scaling caps at 3x base damage
- [ ] Target flashes appropriate color when hit
- [ ] Combat log shows spell damage messages
- [ ] Enemies can be killed by spell damage
- [ ] Spell kills grant XP (if applicable)

## Files Modified
- `systems/magic_system.gd`
- `entities/entity.gd`
- `rendering/ascii_renderer.gd`
- `autoload/event_bus.gd`

## Files Created
- `data/spells/evocation/flame_bolt.json`
- `data/spells/evocation/ice_shard.json`
- `data/spells/evocation/lightning_bolt.json`
- `data/spells/necromancy/drain_life.json`

## Next Phase
Once damage spells work, proceed to **Phase 7: Buff & Debuff Spells**
