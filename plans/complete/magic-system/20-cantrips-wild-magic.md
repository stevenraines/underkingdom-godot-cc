# Phase 20: Cantrips & Wild Magic

## Overview
Implement level 0 cantrips (free spells) and the wild magic table for spell failures.

## Dependencies
- Phase 4: Basic Casting
- Phase 6: Damage Spells

## Implementation Steps

### 20.1 Define Cantrip Properties
**File:** `systems/magic_system.gd`

```gdscript
static func is_cantrip(spell: Spell) -> bool:
    return spell.level == 0

static func attempt_spell(caster: Entity, spell: Spell, target = null) -> Dictionary:
    var result = {success = false, message = ""}

    # Cantrips have special rules
    if is_cantrip(spell):
        # No mana cost
        # No level requirement
        # No failure chance
        # Can be cast unlimited times
        return _apply_spell_effect(caster, spell, target, result)

    # ... existing spell logic for non-cantrips ...
```

### 20.2 Create Cantrip Spell Files
**File:** `data/spells/evocation/spark.json` (update to level 0)

```json
{
  "id": "spark",
  "name": "Spark",
  "description": "A tiny arc of electricity. Harmless but useful.",
  "school": "evocation",
  "level": 0,
  "mana_cost": 0,
  "requirements": {"intelligence": 8},
  "targeting": {"mode": "ranged", "range": 3, "requires_los": true},
  "effects": {
    "damage": {
      "type": "lightning",
      "base": 2,
      "scaling": 0
    }
  },
  "cast_message": "A spark arcs from your fingers!"
}
```

**File:** `data/spells/divination/detect_magic.json`

```json
{
  "id": "detect_magic",
  "name": "Detect Magic",
  "description": "Sense magical auras nearby.",
  "school": "divination",
  "level": 0,
  "mana_cost": 0,
  "requirements": {"intelligence": 8},
  "targeting": {"mode": "self"},
  "effects": {
    "reveal_magic": {
      "range": 10,
      "duration": 20
    }
  },
  "cast_message": "Your senses attune to magical energies."
}
```

**File:** `data/spells/abjuration/mage_hand.json`

```json
{
  "id": "mage_hand",
  "name": "Mage Hand",
  "description": "Manipulate small objects at a distance.",
  "school": "abjuration",
  "level": 0,
  "mana_cost": 0,
  "requirements": {"intelligence": 8},
  "targeting": {"mode": "tile", "range": 5},
  "effects": {
    "telekinesis": {
      "max_weight": 2.0,
      "actions": ["pickup", "drop", "pull_lever"]
    }
  },
  "cast_message": "A spectral hand appears."
}
```

**File:** `data/spells/illusion/minor_illusion.json`

```json
{
  "id": "minor_illusion",
  "name": "Minor Illusion",
  "description": "Create a small illusory distraction.",
  "school": "illusion",
  "level": 0,
  "mana_cost": 0,
  "requirements": {"intelligence": 8},
  "targeting": {"mode": "tile", "range": 6},
  "effects": {
    "create_illusion": {
      "duration": 10,
      "attracts_enemies": true
    }
  },
  "cast_message": "An illusion shimmers into existence."
}
```

**File:** `data/spells/conjuration/create_light.json`

```json
{
  "id": "create_light",
  "name": "Light",
  "description": "Create a floating ball of light.",
  "school": "conjuration",
  "level": 0,
  "mana_cost": 0,
  "requirements": {"intelligence": 8},
  "targeting": {"mode": "tile", "range": 5},
  "effects": {
    "create_light": {
      "radius": 6,
      "duration": 100
    }
  },
  "cast_message": "A ball of light appears!"
}
```

### 20.3 Implement Cantrip Effects

**Detect Magic Effect:**
```gdscript
static func _apply_detect_magic(caster: Entity, spell: Spell, result: Dictionary) -> Dictionary:
    var range = spell.effects.reveal_magic.range
    var duration = spell.effects.reveal_magic.duration

    # Find all magical items/entities in range
    var magical_entities = []
    for entity in EntityManager.get_all_entities():
        if entity.has_magical_aura() and _get_distance(caster.position, entity.position) <= range:
            magical_entities.append(entity)

    # Highlight magical items
    for item in caster.get_visible_ground_items():
        if item.is_magical() and _get_distance(caster.position, item.position) <= range:
            item.reveal_magic_aura(duration)

    result.message = "You sense %d magical auras nearby." % magical_entities.size()
    result.success = true
    return result
```

**Minor Illusion Effect:**
```gdscript
static func _apply_minor_illusion(caster: Entity, spell: Spell, target_pos: Vector2i, result: Dictionary) -> Dictionary:
    var duration = spell.effects.create_illusion.duration

    # Create illusion entity
    var illusion = IllusionEntity.new()
    illusion.position = target_pos
    illusion.duration = duration
    illusion.attracts_enemies = spell.effects.create_illusion.attracts_enemies

    EntityManager.add_entity(illusion)

    result.message = "An illusion appears!"
    result.success = true
    return result
```

### 20.4 Implement Wild Magic System
**File:** `systems/wild_magic.gd` (new)

```gdscript
class_name WildMagic
extends RefCounted

const WILD_MAGIC_TABLE = [
    {id = "mana_surge", weight = 5, effect = "Caster gains 20 mana"},
    {id = "mana_drain", weight = 5, effect = "Caster loses all mana"},
    {id = "random_teleport", weight = 5, effect = "Caster teleports randomly"},
    {id = "target_teleport", weight = 3, effect = "Target teleports randomly"},
    {id = "heal_all", weight = 3, effect = "All nearby creatures healed 10 HP"},
    {id = "damage_all", weight = 3, effect = "All nearby creatures take 10 damage"},
    {id = "summon_creature", weight = 3, effect = "Random creature summoned"},
    {id = "polymorph_caster", weight = 2, effect = "Caster polymorphed into animal"},
    {id = "time_slow", weight = 3, effect = "Time slows (extra turn)"},
    {id = "time_skip", weight = 3, effect = "Lose next turn"},
    {id = "invisibility", weight = 3, effect = "Caster becomes invisible"},
    {id = "light_burst", weight = 4, effect = "Blinding flash in area"},
    {id = "gravity_flip", weight = 2, effect = "Items in area float up"},
    {id = "spell_echo", weight = 3, effect = "Spell casts twice"},
    {id = "spell_reflect", weight = 2, effect = "Spell affects caster instead"},
    {id = "random_buff", weight = 4, effect = "Random buff applied"},
    {id = "random_debuff", weight = 4, effect = "Random debuff applied"},
    {id = "gold_rain", weight = 2, effect = "Gold coins appear nearby"},
    {id = "fire_burst", weight = 3, effect = "Fire erupts at target"},
    {id = "nothing", weight = 5, effect = "Nothing happens"}
]

static func trigger_wild_magic(caster: Entity, original_spell: Spell) -> Dictionary:
    var effect = _select_random_effect()

    EventBus.wild_magic_triggered.emit(caster, effect)
    EventBus.message_logged.emit("Wild magic surges! " + effect.effect, Color.MAGENTA)

    return _apply_wild_effect(caster, effect, original_spell)

static func _select_random_effect() -> Dictionary:
    var total_weight = 0
    for entry in WILD_MAGIC_TABLE:
        total_weight += entry.weight

    var roll = randf() * total_weight
    var current = 0

    for entry in WILD_MAGIC_TABLE:
        current += entry.weight
        if roll <= current:
            return entry

    return WILD_MAGIC_TABLE[-1]  # Fallback

static func _apply_wild_effect(caster: Entity, effect: Dictionary, original_spell: Spell) -> Dictionary:
    var result = {success = true, message = effect.effect}

    match effect.id:
        "mana_surge":
            caster.survival.mana = mini(caster.survival.mana + 20, caster.survival.max_mana)
        "mana_drain":
            caster.survival.mana = 0
        "random_teleport":
            _teleport_randomly(caster)
        "heal_all":
            _heal_all_nearby(caster, 10)
        "damage_all":
            _damage_all_nearby(caster, 10)
        "summon_creature":
            _summon_random_creature(caster)
        "time_slow":
            caster.extra_turns += 1
        "time_skip":
            caster.skip_next_turn = true
        "invisibility":
            caster.add_magical_effect({
                id = "wild_invisibility",
                type = "buff",
                stat = "stealth",
                modifier = 100,
                remaining_duration = 20
            })
        "spell_echo":
            # Cast original spell again
            MagicSystem.attempt_spell(caster, original_spell, null)
        "spell_reflect":
            # Target becomes caster
            MagicSystem.attempt_spell(caster, original_spell, caster)
        "gold_rain":
            _spawn_gold_nearby(caster, randi_range(5, 20))
        "fire_burst":
            _create_fire_burst(caster.position, 3)
        "nothing":
            pass

    return result

static func _teleport_randomly(entity: Entity) -> void:
    var valid_positions = MapManager.current_map.get_walkable_positions_in_range(entity.position, 10)
    if valid_positions.size() > 0:
        var new_pos = valid_positions[randi() % valid_positions.size()]
        entity.position = new_pos
        EventBus.entity_moved.emit(entity, new_pos)

static func _heal_all_nearby(caster: Entity, amount: int) -> void:
    for entity in EntityManager.get_entities_in_range(caster.position, 5):
        entity.heal(amount)

static func _damage_all_nearby(caster: Entity, amount: int) -> void:
    for entity in EntityManager.get_entities_in_range(caster.position, 5):
        entity.take_damage(amount, caster, "wild_magic")

static func _summon_random_creature(caster: Entity) -> void:
    var creatures = ["summoned_wolf", "grave_rat", "woodland_wolf"]
    var creature_id = creatures[randi() % creatures.size()]
    var pos = MapManager.current_map.get_adjacent_walkable_position(caster.position)
    if pos:
        EntityManager.spawn_enemy(creature_id, pos)
```

### 20.5 Integrate Wild Magic into Spell Failure
**File:** `systems/magic_system.gd`

```gdscript
enum SpellFailureType { FIZZLE, BACKFIRE, WILD_MAGIC }

static func _handle_spell_failure(caster: Entity, spell: Spell, failure_roll: int) -> Dictionary:
    var failure_type = _determine_failure_type(failure_roll)

    match failure_type:
        SpellFailureType.FIZZLE:
            # Spell fails, mana spent
            return {success = false, message = "The spell fizzles."}

        SpellFailureType.BACKFIRE:
            # Spell affects caster negatively
            var backfire_result = _apply_backfire(caster, spell)
            return {success = false, message = "The spell backfires! " + backfire_result.message}

        SpellFailureType.WILD_MAGIC:
            # Random wild magic effect
            return WildMagic.trigger_wild_magic(caster, spell)

    return {success = false, message = "The spell fails."}

static func _determine_failure_type(failure_roll: int) -> SpellFailureType:
    # Lower rolls = worse failures
    if failure_roll <= 5:
        return SpellFailureType.WILD_MAGIC
    elif failure_roll <= 10:
        return SpellFailureType.BACKFIRE
    else:
        return SpellFailureType.FIZZLE
```

### 20.6 Add Wild Magic Visual Effects
**File:** `rendering/ascii_renderer.gd`

```gdscript
func _on_wild_magic_triggered(caster: Entity, effect: Dictionary) -> void:
    # Flash screen with wild magic color
    flash_screen(Color.MAGENTA, 0.3)

    # Special effects based on wild magic type
    match effect.id:
        "fire_burst":
            _show_fire_effect(caster.position, 3)
        "light_burst":
            _show_flash_effect(caster.position, 5)
        "gold_rain":
            _show_sparkle_effect(caster.position)
```

### 20.7 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal wild_magic_triggered(caster: Entity, effect: Dictionary)
signal cantrip_cast(caster: Entity, spell: Spell)
signal illusion_created(position: Vector2i, duration: int)
signal magic_detected(caster: Entity, magical_items: Array)
```

### 20.8 Display Cantrips Separately in Spell Menu
**IMPORTANT:** Use the `ui-implementation` agent for this update.

Update spell list UI to show:
- Cantrips section (Level 0, unlimited use)
- Regular Spells section (Level 1+, mana cost)

## Testing Checklist

- [ ] Cantrips cost 0 mana
- [ ] Cantrips have no failure chance
- [ ] Cantrips can be cast unlimited times
- [ ] Spark deals 2 lightning damage
- [ ] Light creates illuminated area
- [ ] Detect Magic reveals magical items/entities
- [ ] Minor Illusion attracts enemies
- [ ] Mage Hand can pick up light items
- [ ] Wild magic triggers on low failure rolls
- [ ] All 20 wild magic effects work correctly
- [ ] Wild magic visual feedback displays
- [ ] Cantrips shown separately in spell menu
- [ ] Wild magic doesn't trigger for cantrips

## Documentation Updates

- [ ] CLAUDE.md updated with cantrip and wild magic info
- [ ] Help screen updated with cantrip explanation
- [ ] `docs/systems/magic-system.md` updated with wild magic table
- [ ] `docs/data/spells.md` updated with cantrip format

## Files Modified
- `systems/magic_system.gd`
- `rendering/ascii_renderer.gd`
- `autoload/event_bus.gd`
- Spell menu UI files

## Files Created
- `systems/wild_magic.gd`
- `data/spells/evocation/spark.json` (updated)
- `data/spells/divination/detect_magic.json`
- `data/spells/abjuration/mage_hand.json`
- `data/spells/illusion/minor_illusion.json`
- `data/spells/conjuration/create_light.json`

## Next Phase
Once cantrips and wild magic work, proceed to **Phase 21: Elemental System**
