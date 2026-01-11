# Phase 21: Elemental System

## Overview
Implement elemental damage types with resistances, vulnerabilities, and environmental combos.

## Dependencies
- Phase 6: Damage Spells
- Phase 7: Buff/Debuff Spells

## Implementation Steps

### 21.1 Define Elemental Damage Types
**File:** `systems/elemental_system.gd` (new)

```gdscript
class_name ElementalSystem
extends RefCounted

enum Element { FIRE, ICE, LIGHTNING, POISON, NECROTIC, HOLY, PHYSICAL }

# Elemental interaction matrix
const ELEMENT_INTERACTIONS = {
    Element.FIRE: {
        "strong_vs": [Element.ICE],
        "weak_vs": [Element.FIRE],
        "neutral": [Element.LIGHTNING, Element.POISON, Element.NECROTIC, Element.HOLY]
    },
    Element.ICE: {
        "strong_vs": [Element.FIRE, Element.LIGHTNING],
        "weak_vs": [Element.ICE],
        "neutral": [Element.POISON, Element.NECROTIC, Element.HOLY]
    },
    Element.LIGHTNING: {
        "strong_vs": [],
        "weak_vs": [Element.LIGHTNING],
        "conductor": true  # Extra damage in water
    },
    Element.POISON: {
        "strong_vs": [],
        "weak_vs": [Element.POISON],
        "living_only": true  # No effect on undead/constructs
    },
    Element.NECROTIC: {
        "strong_vs": [],
        "weak_vs": [Element.NECROTIC, Element.HOLY],
        "heals_undead": true
    },
    Element.HOLY: {
        "strong_vs": [Element.NECROTIC],
        "weak_vs": [Element.HOLY],
        "bonus_vs_undead": true
    }
}

static func get_element_from_string(element_name: String) -> Element:
    match element_name.to_lower():
        "fire": return Element.FIRE
        "ice", "cold": return Element.ICE
        "lightning", "electric": return Element.LIGHTNING
        "poison": return Element.POISON
        "necrotic", "dark": return Element.NECROTIC
        "holy", "radiant": return Element.HOLY
        _: return Element.PHYSICAL
```

### 21.2 Add Resistances to Entity
**File:** `entities/entity.gd`

```gdscript
# Elemental resistances: -100 (immune) to 0 (normal) to +100 (vulnerable)
# Negative = resistance, Positive = vulnerability
var elemental_resistances: Dictionary = {
    "fire": 0,
    "ice": 0,
    "lightning": 0,
    "poison": 0,
    "necrotic": 0,
    "holy": 0
}

func get_elemental_resistance(element: String) -> int:
    var base = elemental_resistances.get(element, 0)

    # Add equipment bonuses
    for slot in equipment.values():
        if slot and slot.has("elemental_resistance"):
            if element in slot.elemental_resistance:
                base += slot.elemental_resistance[element]

    # Add buff/debuff modifiers
    for effect in active_effects:
        if effect.type == "elemental_resistance" and effect.element == element:
            base += effect.modifier

    # Clamp to valid range
    return clampi(base, -100, 100)

func apply_elemental_damage(base_damage: int, element: String, source: Entity = null) -> int:
    var resistance = get_elemental_resistance(element)

    # Convert resistance to damage modifier
    # -100 = immune (0%), 0 = normal (100%), +100 = double (200%)
    var modifier = 1.0 + (resistance / 100.0)
    var final_damage = int(base_damage * modifier)

    # Special rules
    if element == "poison" and creature_type in ["undead", "construct"]:
        final_damage = 0  # Immune

    if element == "necrotic" and creature_type == "undead":
        # Heals undead instead
        heal(final_damage)
        return 0

    if element == "holy" and creature_type == "undead":
        final_damage = int(final_damage * 1.5)  # 50% bonus

    take_damage(final_damage, source, element)
    return final_damage
```

### 21.3 Apply Elemental Damage in Spells
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_spell_damage(caster: Entity, target: Entity, spell: Spell, result: Dictionary) -> Dictionary:
    var base_damage = _calculate_spell_damage(caster, spell)
    var element = spell.effects.damage.get("type", "physical")

    var final_damage = target.apply_elemental_damage(base_damage, element, caster)

    # Generate appropriate message
    var resistance = target.get_elemental_resistance(element)
    if resistance <= -100:
        result.message = "%s is immune to %s!" % [target.entity_name, element]
    elif resistance <= -50:
        result.message = "%s resists the %s! (%d damage)" % [target.entity_name, element, final_damage]
    elif resistance >= 50:
        result.message = "%s is vulnerable to %s! (%d damage)" % [target.entity_name, element, final_damage]
    else:
        result.message = "%s takes %d %s damage!" % [target.entity_name, final_damage, element]

    return result
```

### 21.4 Set Creature Type Resistances
**File:** `data/enemies/` (various files)

Update enemy JSON files with elemental properties:

```json
{
  "id": "barrow_wight",
  "creature_type": "undead",
  "elemental_resistances": {
    "necrotic": -100,
    "poison": -100,
    "holy": 50,
    "fire": 25,
    "ice": -25
  }
}
```

```json
{
  "id": "fire_elemental",
  "creature_type": "elemental",
  "elemental_resistances": {
    "fire": -100,
    "ice": 100,
    "lightning": 0,
    "poison": -100
  }
}
```

### 21.5 Create Resistance Buff Spells
**File:** `data/spells/abjuration/resist_fire.json`

```json
{
  "id": "resist_fire",
  "name": "Resist Fire",
  "description": "Grant resistance to fire damage.",
  "school": "abjuration",
  "level": 2,
  "mana_cost": 10,
  "requirements": {"character_level": 2, "intelligence": 9},
  "targeting": {"mode": "self_or_ally", "range": 3},
  "effects": {
    "elemental_resistance": {
      "element": "fire",
      "modifier": -50,
      "duration": 50
    }
  },
  "cast_message": "A protective ward against fire surrounds the target."
}
```

**File:** `data/spells/abjuration/resist_elements.json`

```json
{
  "id": "resist_elements",
  "name": "Resist Elements",
  "description": "Grant resistance to all elemental damage.",
  "school": "abjuration",
  "level": 5,
  "mana_cost": 25,
  "requirements": {"character_level": 5, "intelligence": 12},
  "targeting": {"mode": "self"},
  "concentration": true,
  "effects": {
    "elemental_resistance_all": {
      "modifier": -25,
      "duration": 100
    }
  },
  "cast_message": "Elemental wards shimmer around you."
}
```

### 21.6 Implement Environmental Combos
**File:** `systems/elemental_system.gd`

```gdscript
static func check_environmental_combo(position: Vector2i, element: String) -> Dictionary:
    var tile = MapManager.current_map.get_tile(position)
    var combo_result = {triggered = false, effect = "", bonus_damage = 0}

    match element:
        "lightning":
            if tile.tile_type == "water" or tile.has_water:
                combo_result.triggered = true
                combo_result.effect = "conducted"
                combo_result.bonus_damage = 10
                combo_result.aoe_tiles = _get_connected_water_tiles(position)
        "fire":
            if tile.tile_type == "oil" or tile.has_oil:
                combo_result.triggered = true
                combo_result.effect = "ignited"
                combo_result.creates_fire = true
            elif tile.tile_type == "ice":
                combo_result.triggered = true
                combo_result.effect = "melted"
                combo_result.changes_tile_to = "water"
        "ice":
            if tile.tile_type == "water":
                combo_result.triggered = true
                combo_result.effect = "frozen"
                combo_result.changes_tile_to = "ice"
                combo_result.creates_hazard = "slippery"

    return combo_result

static func apply_environmental_combo(position: Vector2i, element: String, caster: Entity) -> void:
    var combo = check_environmental_combo(position, element)

    if not combo.triggered:
        return

    EventBus.message_logged.emit("The %s is %s!" % [element, combo.effect], Color.CYAN)

    if combo.get("bonus_damage", 0) > 0:
        # Apply bonus damage to entities in water
        for tile_pos in combo.get("aoe_tiles", [position]):
            var entity = EntityManager.get_entity_at(tile_pos)
            if entity:
                entity.take_damage(combo.bonus_damage, caster, "environmental")

    if combo.get("changes_tile_to"):
        MapManager.current_map.set_tile_type(position, combo.changes_tile_to)

    if combo.get("creates_fire"):
        MapManager.current_map.add_hazard(position, "fire", 10)

    if combo.get("creates_hazard"):
        MapManager.current_map.add_hazard(position, combo.creates_hazard, 20)
```

### 21.7 Add Resistance Display to Character Screen
**IMPORTANT:** Use the `ui-implementation` agent for this update.

Show elemental resistances in character info:
```
=== RESISTANCES ===
Fire:      -25% (resistant)
Ice:       +50% (vulnerable)
Lightning:   0% (normal)
Poison:      0% (normal)
```

### 21.8 Add Visual Feedback for Resistance
**File:** `rendering/ascii_renderer.gd`

```gdscript
func show_resistance_feedback(entity: Entity, element: String, resistance: int) -> void:
    var color = _get_element_color(element)

    if resistance <= -50:
        # Show shield icon for resistance
        show_floating_text(entity.position, "RESIST", color.darkened(0.3))
    elif resistance >= 50:
        # Show vulnerability indicator
        show_floating_text(entity.position, "WEAK!", color.lightened(0.3))

func _get_element_color(element: String) -> Color:
    match element:
        "fire": return Color.ORANGE_RED
        "ice": return Color.CYAN
        "lightning": return Color.YELLOW
        "poison": return Color.GREEN
        "necrotic": return Color.PURPLE
        "holy": return Color.GOLD
        _: return Color.WHITE
```

### 21.9 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal elemental_damage_applied(target: Entity, element: String, damage: int, resisted: bool)
signal environmental_combo_triggered(position: Vector2i, element: String, effect: String)
signal resistance_changed(entity: Entity, element: String, new_value: int)
```

## Testing Checklist

- [ ] Fire damage applies correctly
- [ ] Ice damage applies correctly
- [ ] Lightning damage applies correctly
- [ ] Poison damage applies correctly (not to undead)
- [ ] Necrotic damage heals undead
- [ ] Holy damage bonus vs undead
- [ ] Resistance reduces damage
- [ ] Vulnerability increases damage
- [ ] Immunity blocks all damage
- [ ] Resist Fire spell works
- [ ] Resist Elements spell works
- [ ] Lightning + water combo spreads damage
- [ ] Fire + ice combo melts ice
- [ ] Ice + water combo freezes water
- [ ] Resistance shown in character screen
- [ ] Visual feedback for resist/vulnerable

## Documentation Updates

- [ ] CLAUDE.md updated with elemental system info
- [ ] Help screen updated with element explanations
- [ ] `docs/systems/combat-system.md` updated with elemental damage
- [ ] `docs/data/enemies.md` updated with resistance format

## Files Modified
- `entities/entity.gd`
- `systems/magic_system.gd`
- `rendering/ascii_renderer.gd`
- `autoload/event_bus.gd`
- Various enemy JSON files

## Files Created
- `systems/elemental_system.gd`
- `data/spells/abjuration/resist_fire.json`
- `data/spells/abjuration/resist_ice.json`
- `data/spells/abjuration/resist_lightning.json`
- `data/spells/abjuration/resist_elements.json`

## Next Phase
Once elemental system works, proceed to **Phase 22: Mana Potions**
