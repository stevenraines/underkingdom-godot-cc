# Phase 25: Ritual Effects

## Overview
Implement the 6 ritual effects: Enchant Item, Scrying, Resurrection, Summon Demon, Bind Soul, Ward Area.

## Dependencies
- Phase 24: Ritual System Core
- Phase 12: Magic Rings (for enchantment targets)
- Phase 15: Summoning (for demon summoning)

## Implementation Steps

### 25.1 Create Enchant Item Ritual
**File:** `data/rituals/enchant_item.json`

```json
{
  "id": "enchant_item",
  "name": "Enchant Item",
  "description": "Imbue an item with permanent magical properties.",
  "school": "transmutation",
  "components": [
    {"item_id": "mana_crystal", "quantity": 5},
    {"item_id": "arcane_essence", "quantity": 2},
    {"item_id": "gold", "quantity": 100}
  ],
  "channeling_turns": 10,
  "requirements": {
    "intelligence": 14,
    "near_altar": true
  },
  "effects": {
    "enchant_item": {
      "enchantment_pool": ["sharpness", "protection", "mana_regen", "health_regen"]
    }
  },
  "failure_effects": {
    "destroy_item_chance": 0.3
  },
  "discovery_location": "ancient_library"
}
```

**File:** `systems/ritual_system.gd` (add to _apply_ritual_effects)

```gdscript
static func _apply_ritual_effects(caster: Entity, ritual: Ritual) -> Dictionary:
    var result = {success = false, message = ""}

    match ritual.id:
        "enchant_item":
            result = _apply_enchant_item(caster, ritual)
        "scrying":
            result = _apply_scrying(caster, ritual)
        "resurrection":
            result = _apply_resurrection(caster, ritual)
        "summon_demon":
            result = _apply_summon_demon(caster, ritual)
        "bind_soul":
            result = _apply_bind_soul(caster, ritual)
        "ward_area":
            result = _apply_ward_area(caster, ritual)

    return result

static func _apply_enchant_item(caster: Entity, ritual: Ritual) -> Dictionary:
    # Get target item from UI selection
    var target_item = _ritual_target_item
    if not target_item:
        return {success = false, message = "No item selected for enchantment."}

    # Check if item can be enchanted
    if target_item.has("enchantment"):
        return {success = false, message = "Item is already enchanted."}

    # Roll for enchantment
    var pool = ritual.effects.enchant_item.enchantment_pool
    var enchantment = pool[randi() % pool.size()]

    # Apply enchantment
    target_item.enchantment = enchantment
    target_item.is_magical = true

    match enchantment:
        "sharpness":
            target_item.damage_bonus = target_item.get("damage_bonus", 0) + 3
            target_item.display_name = target_item.base_name + " of Sharpness"
        "protection":
            target_item.armor_bonus = target_item.get("armor_bonus", 0) + 2
            target_item.display_name = target_item.base_name + " of Protection"
        "mana_regen":
            target_item.passive_effects = target_item.get("passive_effects", {})
            target_item.passive_effects["mana_regen"] = 1
            target_item.display_name = target_item.base_name + " of the Mage"
        "health_regen":
            target_item.passive_effects = target_item.get("passive_effects", {})
            target_item.passive_effects["health_regen"] = 1
            target_item.display_name = target_item.base_name + " of Vitality"

    return {
        success = true,
        message = "The %s glows with magical energy!" % target_item.display_name
    }
```

### 25.2 Create Scrying Ritual
**File:** `data/rituals/scrying.json`

```json
{
  "id": "scrying",
  "name": "Scrying",
  "description": "Peer through the veil to see distant locations.",
  "school": "divination",
  "components": [
    {"item_id": "crystal_ball", "quantity": 1, "consumed": false},
    {"item_id": "moonpetal", "quantity": 3}
  ],
  "channeling_turns": 5,
  "requirements": {
    "intelligence": 12
  },
  "effects": {
    "reveal_map": {
      "radius": 30,
      "reveals_enemies": true,
      "reveals_items": true
    }
  },
  "discovery_location": "mage_tower"
}
```

```gdscript
static func _apply_scrying(caster: Entity, ritual: Ritual) -> Dictionary:
    var radius = ritual.effects.reveal_map.radius
    var center = caster.position

    # Reveal map tiles
    for x in range(-radius, radius + 1):
        for y in range(-radius, radius + 1):
            var pos = center + Vector2i(x, y)
            if _get_distance(center, pos) <= radius:
                MapManager.current_map.reveal_tile(pos)

    # Mark enemies on map
    if ritual.effects.reveal_map.reveals_enemies:
        for enemy in EntityManager.get_enemies_in_range(center, radius):
            enemy.revealed_by_scrying = true

    # Mark items on map
    if ritual.effects.reveal_map.reveals_items:
        for item in EntityManager.get_ground_items_in_range(center, radius):
            item.revealed_by_scrying = true

    EventBus.map_revealed.emit(center, radius)

    return {
        success = true,
        message = "Visions flood your mind... you see the surrounding area clearly."
    }
```

### 25.3 Create Resurrection Ritual
**File:** `data/rituals/resurrection.json`

```json
{
  "id": "resurrection",
  "name": "Resurrection",
  "description": "Return a fallen ally to life.",
  "school": "necromancy",
  "components": [
    {"item_id": "phoenix_feather", "quantity": 1},
    {"item_id": "arcane_essence", "quantity": 5},
    {"item_id": "gold", "quantity": 500}
  ],
  "channeling_turns": 20,
  "requirements": {
    "intelligence": 16,
    "near_corpse": true
  },
  "effects": {
    "resurrect": {
      "health_percent": 25,
      "temporary_weakness": true
    }
  },
  "failure_effects": {
    "summon_hostile_undead": true
  },
  "discovery_location": "sacred_temple"
}
```

```gdscript
static func _apply_resurrection(caster: Entity, ritual: Ritual) -> Dictionary:
    # In a single-player roguelike, this might resurrect a companion or pet
    # Or it could be used for game mechanics like continuing after death

    var corpse = _find_nearby_corpse(caster.position)
    if not corpse:
        return {success = false, message = "No suitable corpse nearby."}

    # Create resurrected ally
    var ally = _create_resurrected_ally(corpse)
    ally.current_health = int(ally.max_health * ritual.effects.resurrect.health_percent / 100.0)

    if ritual.effects.resurrect.temporary_weakness:
        ally.add_magical_effect({
            id = "resurrection_weakness",
            type = "debuff",
            stat = "all",
            modifier = -2,
            remaining_duration = 100
        })

    # Remove corpse
    EntityManager.remove_corpse(corpse)

    return {
        success = true,
        message = "Life returns to the fallen!"
    }
```

### 25.4 Create Summon Demon Ritual
**File:** `data/rituals/summon_demon.json`

```json
{
  "id": "summon_demon",
  "name": "Summon Demon",
  "description": "Call forth a powerful demon to serve you.",
  "school": "conjuration",
  "components": [
    {"item_id": "demon_blood", "quantity": 1},
    {"item_id": "obsidian", "quantity": 5},
    {"item_id": "soul_gem", "quantity": 1}
  ],
  "channeling_turns": 15,
  "requirements": {
    "intelligence": 15,
    "night_only": true
  },
  "effects": {
    "summon": {
      "creature_id": "bound_demon",
      "duration": 200,
      "behavior": "aggressive"
    }
  },
  "failure_effects": {
    "summon_hostile_demon": true
  },
  "discovery_location": "dark_sanctum"
}
```

```gdscript
static func _apply_summon_demon(caster: Entity, ritual: Ritual) -> Dictionary:
    var summon_data = ritual.effects.summon
    var creature_id = summon_data.creature_id
    var duration = summon_data.duration

    # Find valid spawn position
    var pos = MapManager.current_map.get_adjacent_walkable_position(caster.position)
    if not pos:
        return {success = false, message = "No space to summon the demon."}

    # Create summoned demon
    var creature_template = EntityManager.get_enemy_data(creature_id)
    var demon = SummonedCreature.new(caster, duration)
    demon.initialize_from_template(creature_template)
    demon.behavior_mode = summon_data.behavior
    demon.position = pos

    EntityManager.add_entity(demon)
    caster.add_summon(demon)

    return {
        success = true,
        message = "A demon emerges from the shadows, bound to your will!"
    }
```

### 25.5 Create Bind Soul Ritual
**File:** `data/rituals/bind_soul.json`

```json
{
  "id": "bind_soul",
  "name": "Bind Soul",
  "description": "Trap a creature's soul in a gem for later use.",
  "school": "necromancy",
  "components": [
    {"item_id": "empty_soul_gem", "quantity": 1}
  ],
  "channeling_turns": 8,
  "requirements": {
    "intelligence": 13,
    "target_low_health": true
  },
  "effects": {
    "bind_soul": {
      "kills_target": true,
      "creates_item": "filled_soul_gem"
    }
  },
  "discovery_location": "necromancer_lair"
}
```

```gdscript
static func _apply_bind_soul(caster: Entity, ritual: Ritual) -> Dictionary:
    var target = _ritual_target_entity
    if not target:
        return {success = false, message = "No target for soul binding."}

    # Target must be low health
    if target.current_health > target.max_health * 0.25:
        return {success = false, message = "Target is too healthy. Weaken them first."}

    # Kill target and create soul gem
    target.die(caster)

    var soul_gem = ItemManager.create_item("filled_soul_gem")
    soul_gem.contained_soul = target.entity_name
    soul_gem.soul_power = target.level

    caster.inventory.add_item(soul_gem)

    return {
        success = true,
        message = "The %s's soul is trapped in the gem!" % target.entity_name
    }
```

### 25.6 Create Ward Area Ritual
**File:** `data/rituals/ward_area.json`

```json
{
  "id": "ward_area",
  "name": "Ward Area",
  "description": "Create a protective barrier around an area.",
  "school": "abjuration",
  "components": [
    {"item_id": "silver_dust", "quantity": 10},
    {"item_id": "holy_water", "quantity": 1},
    {"item_id": "mana_crystal", "quantity": 2}
  ],
  "channeling_turns": 12,
  "requirements": {
    "intelligence": 12
  },
  "effects": {
    "create_ward": {
      "radius": 5,
      "duration": 500,
      "effects": ["blocks_undead", "blocks_demons", "alarm_on_entry"]
    }
  },
  "discovery_location": "temple"
}
```

```gdscript
static func _apply_ward_area(caster: Entity, ritual: Ritual) -> Dictionary:
    var ward_data = ritual.effects.create_ward
    var radius = ward_data.radius
    var duration = ward_data.duration

    # Create ward entity
    var ward = WardEntity.new()
    ward.position = caster.position
    ward.radius = radius
    ward.remaining_duration = duration
    ward.effects = ward_data.effects
    ward.creator = caster

    EntityManager.add_ward(ward)

    # Visual: mark warded tiles
    for x in range(-radius, radius + 1):
        for y in range(-radius, radius + 1):
            var pos = caster.position + Vector2i(x, y)
            if _get_distance(caster.position, pos) <= radius:
                MapManager.current_map.add_ward_marker(pos, duration)

    return {
        success = true,
        message = "A protective ward shimmers into existence around you."
    }
```

### 25.7 Create Required Ritual Components
**File:** `data/items/materials/`

```json
// phoenix_feather.json
{
  "id": "phoenix_feather",
  "name": "Phoenix Feather",
  "description": "A brilliant feather radiating warmth and life.",
  "category": "material",
  "subcategory": "magical",
  "flags": {"magical": true, "rare": true},
  "weight": 0.05,
  "value": 250,
  "stack_max": 5,
  "ascii_char": "/",
  "ascii_color": "#FF6600"
}

// demon_blood.json
{
  "id": "demon_blood",
  "name": "Demon Blood",
  "description": "Dark ichor from a demonic creature.",
  "category": "material",
  "subcategory": "magical",
  "flags": {"magical": true, "rare": true},
  "weight": 0.3,
  "value": 150,
  "stack_max": 5,
  "ascii_char": "~",
  "ascii_color": "#880000"
}

// soul_gem.json (empty)
{
  "id": "empty_soul_gem",
  "name": "Empty Soul Gem",
  "description": "A crystalline container capable of holding souls.",
  "category": "material",
  "subcategory": "magical",
  "flags": {"magical": true},
  "weight": 0.2,
  "value": 100,
  "stack_max": 10,
  "ascii_char": "*",
  "ascii_color": "#888888"
}

// crystal_ball.json
{
  "id": "crystal_ball",
  "name": "Crystal Ball",
  "description": "A clear sphere used for divination.",
  "category": "tool",
  "subcategory": "magical",
  "flags": {"tool": true, "magical": true},
  "weight": 1.0,
  "value": 200,
  "ascii_char": "o",
  "ascii_color": "#AACCFF"
}

// silver_dust.json
{
  "id": "silver_dust",
  "name": "Silver Dust",
  "description": "Finely ground silver with purifying properties.",
  "category": "material",
  "subcategory": "magical",
  "weight": 0.1,
  "value": 15,
  "stack_max": 50,
  "ascii_char": ".",
  "ascii_color": "#CCCCCC"
}

// holy_water.json
{
  "id": "holy_water",
  "name": "Holy Water",
  "description": "Blessed water with protective properties.",
  "category": "material",
  "subcategory": "magical",
  "flags": {"magical": true},
  "weight": 0.3,
  "value": 30,
  "stack_max": 10,
  "ascii_char": "!",
  "ascii_color": "#AAFFFF"
}
```

### 25.8 Create Ritual Tome Items for Each Ritual
**File:** `data/items/books/`

```json
// ritual_tome_scrying.json
{
  "id": "ritual_tome_scrying",
  "name": "Tome of Far Sight",
  "description": "An ancient tome describing the Scrying ritual.",
  "effects": {"teaches_ritual": "scrying"},
  ...
}

// ritual_tome_resurrection.json
{
  "id": "ritual_tome_resurrection",
  "name": "Book of Life",
  "description": "A sacred text containing the Resurrection ritual.",
  "effects": {"teaches_ritual": "resurrection"},
  ...
}

// ritual_tome_summon_demon.json, etc.
```

### 25.9 Create Summoned Demon Data
**File:** `data/enemies/summons/bound_demon.json`

```json
{
  "id": "bound_demon",
  "name": "Bound Demon",
  "description": "A powerful demon bound to serve a summoner.",
  "ascii_char": "&",
  "ascii_color": "#FF0000",
  "base_health": 80,
  "base_damage": 15,
  "attributes": {"STR": 18, "DEX": 14, "CON": 16, "INT": 12, "WIS": 10, "CHA": 8},
  "creature_type": "demon",
  "elemental_resistances": {
    "fire": -50,
    "holy": 50
  },
  "behavior": "summoned",
  "abilities": ["fire_breath", "terrifying_presence"]
}
```

### 25.10 Add Ward Entity System
**File:** `entities/ward_entity.gd` (new)

```gdscript
class_name WardEntity
extends RefCounted

var position: Vector2i
var radius: int
var remaining_duration: int
var effects: Array = []
var creator: Entity

func process_turn() -> void:
    remaining_duration -= 1
    if remaining_duration <= 0:
        _expire()
        return

    # Check for creatures entering ward
    for entity in EntityManager.get_entities_in_range(position, radius):
        if entity == creator:
            continue

        if "blocks_undead" in effects and entity.creature_type == "undead":
            _repel_entity(entity)
            EventBus.message_logged.emit("The ward repels the undead!", Color.CYAN)

        if "blocks_demons" in effects and entity.creature_type == "demon":
            _repel_entity(entity)
            EventBus.message_logged.emit("The ward repels the demon!", Color.CYAN)

        if "alarm_on_entry" in effects and entity.faction == "enemy":
            EventBus.message_logged.emit("The ward alerts you to an intruder!", Color.YELLOW)

func _repel_entity(entity: Entity) -> void:
    # Push entity away from ward center
    var direction = (entity.position - position).sign()
    var new_pos = entity.position + direction
    if MapManager.current_map.is_walkable(new_pos):
        entity.position = new_pos

func _expire() -> void:
    EventBus.message_logged.emit("The protective ward fades.", Color.GRAY)
    EventBus.ward_expired.emit(self)
```

## Testing Checklist

- [ ] Enchant Item ritual applies random enchantment
- [ ] Enchanted items have updated names and bonuses
- [ ] Scrying reveals map in radius
- [ ] Scrying marks enemies and items
- [ ] Resurrection requires corpse nearby
- [ ] Resurrection creates ally with weakness
- [ ] Summon Demon creates powerful summon
- [ ] Demon requires night time
- [ ] Bind Soul requires low health target
- [ ] Bind Soul creates filled soul gem
- [ ] Ward Area creates protective zone
- [ ] Ward blocks undead and demons
- [ ] Ward triggers alarm on enemy entry
- [ ] All ritual tomes teach correct rituals
- [ ] Ritual components found in world
- [ ] Failed rituals have appropriate consequences

## Documentation Updates

- [ ] CLAUDE.md updated with all rituals
- [ ] Help screen updated with ritual list
- [ ] `docs/systems/ritual-system.md` updated with ritual effects
- [ ] `docs/data/rituals.md` updated with all ritual formats

## Files Modified
- `systems/ritual_system.gd`
- `autoload/entity_manager.gd`

## Files Created
- `data/rituals/enchant_item.json`
- `data/rituals/scrying.json`
- `data/rituals/resurrection.json`
- `data/rituals/summon_demon.json`
- `data/rituals/bind_soul.json`
- `data/rituals/ward_area.json`
- `data/items/materials/phoenix_feather.json`
- `data/items/materials/demon_blood.json`
- `data/items/materials/empty_soul_gem.json`
- `data/items/materials/crystal_ball.json`
- `data/items/materials/silver_dust.json`
- `data/items/materials/holy_water.json`
- `data/items/books/ritual_tome_*.json` (6 tomes)
- `data/enemies/summons/bound_demon.json`
- `entities/ward_entity.gd`

## Magic System Complete!
With Phase 25 complete, the magic system implementation is ready for testing and integration.
