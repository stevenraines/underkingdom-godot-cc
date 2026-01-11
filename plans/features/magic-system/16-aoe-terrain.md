# Phase 16: AOE & Terrain Spells

## Overview
Implement area-of-effect spells and permanent terrain modification spells.

## Dependencies
- Phase 6: Damage Spells
- Phase 15: Summoning (for friendly fire rules)

## Implementation Steps

### 16.1 Implement AOE Targeting
**File:** `systems/targeting_system.gd`

```gdscript
func start_aoe_targeting(caster: Entity, spell: Spell) -> bool:
    targeting_spell = spell
    is_aoe_targeting = true
    attacker = caster
    aoe_radius = spell.targeting.aoe_radius

    # For AOE, we target a tile, not an entity
    current_target_pos = caster.position
    valid_positions = _get_valid_aoe_positions(caster, spell)

    is_targeting = true
    targeting_started.emit()
    return true

func _get_valid_aoe_positions(caster: Entity, spell: Spell) -> Array[Vector2i]:
    var positions: Array[Vector2i] = []
    var range = spell.targeting.range

    for x in range(-range, range + 1):
        for y in range(-range, range + 1):
            var pos = caster.position + Vector2i(x, y)
            if _get_distance(caster.position, pos) <= range:
                if spell.targeting.get("requires_los", true):
                    if RangedCombatSystem.has_line_of_sight(caster.position, pos):
                        positions.append(pos)
                else:
                    positions.append(pos)

    return positions

func move_aoe_cursor(direction: Vector2i) -> void:
    var new_pos = current_target_pos + direction
    if new_pos in valid_positions:
        current_target_pos = new_pos
        aoe_cursor_moved.emit(current_target_pos)
```

### 16.2 Get Entities in AOE
**File:** `systems/magic_system.gd`

```gdscript
static func get_entities_in_aoe(center: Vector2i, radius: int, shape: String = "circle") -> Array[Entity]:
    var entities: Array[Entity] = []

    for entity in EntityManager.get_all_entities():
        var distance = _get_distance(center, entity.position)

        match shape:
            "circle":
                if distance <= radius:
                    entities.append(entity)
            "cone":
                # Cone implementation for directional spells
                pass
            "line":
                # Line implementation for beam spells
                pass

    return entities
```

### 16.3 Apply AOE Damage with Friendly Fire
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_aoe_spell(caster: Entity, spell: Spell, target_pos: Vector2i, result: Dictionary) -> Dictionary:
    var radius = spell.targeting.aoe_radius
    var entities = get_entities_in_aoe(target_pos, radius)
    var damage = _calculate_spell_damage(caster, spell)

    result.targets_hit = 0

    for entity in entities:
        # Skip caster (self-protection)
        if entity == caster:
            continue

        # Friendly fire applies to summons!
        var is_friendly = entity in caster.active_summons if caster.has_method("active_summons") else false

        # Apply damage
        entity.take_damage(damage, caster, "spell_" + spell.id)
        result.targets_hit += 1

        if is_friendly:
            EventBus.message_logged.emit("Your %s is caught in the blast!" % entity.entity_name, Color.ORANGE)

    result.message = "%s hits %d targets for %d damage!" % [spell.name, result.targets_hit, damage]
    return result
```

### 16.4 Create Fireball Spell
**File:** `data/spells/evocation/fireball.json`

```json
{
  "id": "fireball",
  "name": "Fireball",
  "description": "A ball of fire explodes at the target location.",
  "school": "evocation",
  "level": 7,
  "mana_cost": 45,
  "requirements": {"character_level": 7, "intelligence": 14},
  "targeting": {
    "mode": "aoe",
    "range": 8,
    "aoe_radius": 3,
    "aoe_shape": "circle",
    "requires_los": true
  },
  "effects": {
    "damage": {
      "type": "fire",
      "base": 25,
      "scaling": 5
    }
  },
  "cast_message": "A ball of fire explodes!"
}
```

### 16.5 Render AOE Indicator
**File:** `rendering/ascii_renderer.gd`

```gdscript
func show_aoe_indicator(center: Vector2i, radius: int, color: Color):
    for x in range(-radius, radius + 1):
        for y in range(-radius, radius + 1):
            var pos = center + Vector2i(x, y)
            if _get_distance(center, pos) <= radius:
                _highlight_tile(pos, color.darkened(0.5))

    # Highlight center
    _highlight_tile(center, color)

func clear_aoe_indicator():
    # Remove all highlights
```

### 16.6 Implement Terrain Modification Spells
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_terrain_spell(caster: Entity, spell: Spell, target_pos: Vector2i, result: Dictionary) -> Dictionary:
    if "terrain_change" in spell.effects:
        var change = spell.effects.terrain_change
        var current_tile = MapManager.current_map.get_tile(target_pos)

        # Validate change
        if not _can_change_terrain(current_tile, change):
            result.success = false
            result.message = "This terrain cannot be changed."
            # Refund mana
            caster.survival.mana += spell.mana_cost
            return result

        # Apply change
        MapManager.current_map.set_tile_type(target_pos, change.to_type)
        EventBus.terrain_changed.emit(target_pos, change.to_type)

        result.message = spell.cast_message
        result.success = true

    return result

static func _can_change_terrain(tile: TileData, change: Dictionary) -> bool:
    match change.from_type:
        "wall":
            return tile.tile_type == "wall"
        "floor":
            return tile.walkable and tile.tile_type != "water"
        "any":
            return true
    return false
```

### 16.7 Create Terrain Spell JSON Files
**File:** `data/spells/transmutation/wall_to_mud.json`

```json
{
  "id": "wall_to_mud",
  "name": "Wall to Mud",
  "description": "Transform a wall into passable terrain.",
  "school": "transmutation",
  "level": 5,
  "mana_cost": 20,
  "requirements": {"character_level": 5, "intelligence": 12},
  "targeting": {"mode": "tile", "range": 5, "requires_los": true},
  "effects": {
    "terrain_change": {
      "from_type": "wall",
      "to_type": "mud",
      "permanent": true
    }
  },
  "cast_message": "The wall dissolves into mud!"
}
```

**File:** `data/spells/transmutation/create_wall.json`

```json
{
  "id": "create_wall",
  "name": "Create Wall",
  "description": "Raise a wall from the ground.",
  "school": "transmutation",
  "level": 6,
  "mana_cost": 25,
  "requirements": {"character_level": 6, "intelligence": 13},
  "targeting": {"mode": "tile", "range": 4, "requires_los": true, "requires_empty": true},
  "effects": {
    "terrain_change": {
      "from_type": "floor",
      "to_type": "wall",
      "permanent": true
    }
  },
  "cast_message": "A wall rises from the ground!"
}
```

**File:** `data/spells/conjuration/create_water.json`

```json
{
  "id": "create_water",
  "name": "Create Water",
  "description": "Create a pool of fresh water.",
  "school": "conjuration",
  "level": 2,
  "mana_cost": 8,
  "requirements": {"character_level": 2, "intelligence": 9},
  "targeting": {"mode": "tile", "range": 3},
  "effects": {
    "terrain_change": {
      "from_type": "floor",
      "to_type": "water",
      "permanent": true
    }
  },
  "cast_message": "Water springs forth from the ground!"
}
```

### 16.8 Add Terrain Types to Map
**File:** `maps/tile_data.gd`

Ensure these terrain types exist:
- `mud` - walkable, not transparent, slows movement
- `water` - depends on depth, provides water resource

### 16.9 Persist Terrain Changes
**File:** `autoload/save_manager.gd`

Track modified tiles:
```gdscript
var terrain_modifications: Dictionary = {}  # map_id -> {pos -> tile_type}

func save_terrain_modifications():
    # Save all permanent terrain changes

func load_terrain_modifications():
    # Restore terrain changes on map load
```

### 16.10 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal aoe_cursor_moved(position: Vector2i)
signal terrain_changed(position: Vector2i, new_type: String)
```

## Testing Checklist

- [ ] Fireball targets a tile, not an entity
- [ ] AOE indicator shows affected tiles
- [ ] Arrow keys move AOE cursor
- [ ] Fireball damages all enemies in radius
- [ ] Fireball damages player's summons (friendly fire)
- [ ] Fireball does NOT damage caster
- [ ] Wall to Mud converts wall to passable terrain
- [ ] Create Wall converts floor to wall
- [ ] Create Water creates water tile
- [ ] Terrain changes are permanent
- [ ] Terrain changes persist through save/load
- [ ] Cannot cast terrain spell on invalid tile
- [ ] Mana refunded if terrain spell fails

## Files Modified
- `systems/targeting_system.gd`
- `systems/magic_system.gd`
- `rendering/ascii_renderer.gd`
- `autoload/save_manager.gd`
- `autoload/event_bus.gd`
- `maps/tile_data.gd`

## Files Created
- `data/spells/evocation/fireball.json`
- `data/spells/transmutation/wall_to_mud.json`
- `data/spells/transmutation/create_wall.json`
- `data/spells/conjuration/create_water.json`

## Next Phase
Once AOE and terrain spells work, proceed to **Phase 17: Mind Spells**
