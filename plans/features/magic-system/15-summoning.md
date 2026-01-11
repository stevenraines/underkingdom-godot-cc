# Phase 15: Summoning

## Overview
Implement summoned creatures with AI behavior, player commands, and the 3-summon limit.

## Dependencies
- Phase 6: Damage Spells
- Phase 14: DoT & Concentration (for concentration tracking)
- Existing: Enemy AI system

## Implementation Steps

### 15.1 Create Summoned Creature Class
**File:** `entities/summoned_creature.gd` (new)

```gdscript
class_name SummonedCreature
extends Enemy

var summoner: Entity = null
var remaining_duration: int = -1  # -1 = permanent
var behavior_mode: String = "follow"  # follow, aggressive, defensive, stay

enum BehaviorMode { FOLLOW, AGGRESSIVE, DEFENSIVE, STAY }

func _init(p_summoner: Entity, duration: int = -1):
    summoner = p_summoner
    remaining_duration = duration
    is_summon = true
    faction = "player"  # Ally to player

func process_turn() -> void:
    match behavior_mode:
        "follow":
            _follow_summoner()
        "aggressive":
            _pursue_nearest_enemy()
        "defensive":
            _defend_summoner()
        "stay":
            _hold_position()

func _follow_summoner() -> void:
    # Stay adjacent to summoner, attack nearby threats
    var distance = _get_distance(position, summoner.position)
    if distance > 2:
        _move_toward(summoner.position)
    else:
        _attack_adjacent_enemy()

func _pursue_nearest_enemy() -> void:
    var nearest = _find_nearest_enemy()
    if nearest:
        if _is_adjacent(nearest):
            attack(nearest)
        else:
            _move_toward(nearest.position)

func _defend_summoner() -> void:
    # Only attack if summoner was attacked this turn
    if summoner.was_attacked_this_turn:
        var attacker = summoner.last_attacker
        if attacker and _is_adjacent(attacker):
            attack(attacker)

func _hold_position() -> void:
    # Attack adjacent enemies only
    _attack_adjacent_enemy()

func tick_duration() -> bool:
    if remaining_duration == -1:
        return true  # Permanent
    remaining_duration -= 1
    if remaining_duration <= 0:
        dismiss()
        return false
    return true

func dismiss() -> void:
    EventBus.message_logged.emit("%s vanishes!" % entity_name, Color.GRAY)
    EventBus.summon_dismissed.emit(self)
    queue_free()
```

### 15.2 Add Summon Tracking to Player
**File:** `entities/player.gd`

```gdscript
var active_summons: Array[SummonedCreature] = []
const MAX_SUMMONS = 3

func add_summon(summon: SummonedCreature) -> bool:
    # Enforce limit
    if active_summons.size() >= MAX_SUMMONS:
        # Dismiss oldest
        var oldest = active_summons[0]
        oldest.dismiss()
        active_summons.remove_at(0)

    active_summons.append(summon)
    EventBus.summon_created.emit(summon)
    return true

func remove_summon(summon: SummonedCreature) -> void:
    active_summons.erase(summon)

func set_summon_behavior(index: int, mode: String) -> void:
    if index >= 0 and index < active_summons.size():
        active_summons[index].behavior_mode = mode

func dismiss_summon(index: int) -> void:
    if index >= 0 and index < active_summons.size():
        active_summons[index].dismiss()

func dismiss_all_summons() -> void:
    for summon in active_summons.duplicate():
        summon.dismiss()
```

### 15.3 Implement Summon Spell Effect
**File:** `systems/magic_system.gd`

```gdscript
static func _apply_tile_spell(caster: Entity, spell: Spell, target_pos: Vector2i, result: Dictionary) -> Dictionary:
    if "summon" in spell.effects:
        var summon_data = spell.effects.summon
        var creature_id = summon_data.creature_id
        var duration = summon_data.base_duration + (caster.level * summon_data.get("duration_per_level", 10))

        # Create summoned creature
        var creature_template = EntityManager.get_enemy_data(creature_id)
        var summon = SummonedCreature.new(caster, duration)
        summon.initialize_from_template(creature_template)

        # Scale stats with caster level
        summon.max_health += caster.level * 5
        summon.current_health = summon.max_health
        summon.damage_bonus += caster.level * 2

        # Place on map
        summon.position = target_pos
        EntityManager.add_entity(summon)
        caster.add_summon(summon)

        result.message = "You summon a %s!" % summon.entity_name
        result.success = true

        # Concentration for spell summons
        if spell.concentration:
            caster.start_concentration(spell.id)

    return result
```

### 15.4 Create Summon Spell JSON Files
**File:** `data/spells/conjuration/summon_creature.json`

```json
{
  "id": "summon_creature",
  "name": "Summon Creature",
  "description": "Summon a creature to fight for you.",
  "school": "conjuration",
  "level": 5,
  "mana_cost": 25,
  "requirements": {"character_level": 5, "intelligence": 12},
  "targeting": {"mode": "tile", "range": 3},
  "concentration": true,
  "effects": {
    "summon": {
      "creature_id": "summoned_wolf",
      "base_duration": 50,
      "duration_per_level": 10
    }
  },
  "cast_message": "You call forth a creature from beyond!"
}
```

### 15.5 Create Summonable Creature Data
**File:** `data/enemies/summons/summoned_wolf.json`

```json
{
  "id": "summoned_wolf",
  "name": "Summoned Wolf",
  "description": "A spectral wolf bound to your service.",
  "ascii_char": "w",
  "ascii_color": "#88AAFF",
  "base_health": 20,
  "base_damage": 6,
  "attributes": {"STR": 12, "DEX": 14, "CON": 12, "INT": 4, "WIS": 10, "CHA": 6},
  "behavior": "summoned",
  "faction": "player"
}
```

### 15.6 Implement Raise Skeleton Spell
**File:** `data/spells/necromancy/raise_skeleton.json`

```json
{
  "id": "raise_skeleton",
  "name": "Raise Skeleton",
  "description": "Animate a corpse as an undead servant.",
  "school": "necromancy",
  "level": 6,
  "mana_cost": 30,
  "requirements": {"character_level": 6, "intelligence": 13},
  "targeting": {"mode": "tile", "range": 2, "requires_corpse": true},
  "concentration": false,
  "effects": {
    "summon": {
      "creature_id": "summoned_skeleton",
      "base_duration": 100,
      "duration_per_level": 20
    }
  },
  "cast_message": "Bones rise from the ground!"
}
```

### 15.7 Create Summon Command UI
**IMPORTANT:** Use the `ui-implementation` agent for creating this UI.

**File:** `ui/summon_command_menu.gd` (new)

- Press 'C' to open summon command menu (if has summons)
- List active summons with health and behavior
- Options: Follow (F), Aggressive (A), Defensive (D), Stay (S), Dismiss (X)
- Quick keys: Ctrl+F/A/D/S/X for selected summon

### 15.8 Add Summon Input Handling
**File:** `systems/input_handler.gd`

```gdscript
if Input.is_action_just_pressed("summon_menu"):
    if player.active_summons.size() > 0:
        EventBus.summon_menu_requested.emit()
    else:
        EventBus.message_logged.emit("You have no active summons.", Color.YELLOW)
```

### 15.9 Process Summon Turns
**File:** `autoload/entity_manager.gd`

```gdscript
func process_entity_turns() -> void:
    # Process player summons first
    for summon in EntityManager.player.active_summons:
        if summon.tick_duration():
            summon.process_turn()

    # Then enemies
    for enemy in enemies:
        if not enemy.is_summon:
            enemy.process_turn()
```

### 15.10 Handle Summon Death
**File:** `entities/summoned_creature.gd`

```gdscript
func die(killer: Entity = null) -> void:
    if summoner:
        summoner.remove_summon(self)
    super.die(killer)
```

### 15.11 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal summon_created(summon: SummonedCreature)
signal summon_dismissed(summon: SummonedCreature)
signal summon_died(summon: SummonedCreature)
signal summon_menu_requested()
signal summon_command_changed(summon: SummonedCreature, mode: String)
```

### 15.12 Display Summons in HUD
Show active summons with health bars and behavior indicators.

## Testing Checklist

- [ ] Summon Creature spell creates allied creature
- [ ] Summoned creature follows player by default
- [ ] Summon attacks enemies
- [ ] Summon command menu opens with 'C'
- [ ] Can change summon behavior (Follow/Aggressive/Defensive/Stay)
- [ ] Aggressive summon pursues enemies
- [ ] Defensive summon only attacks if player attacked
- [ ] Stay summon holds position
- [ ] Dismiss command removes summon
- [ ] Max 3 summons enforced (oldest dismissed)
- [ ] Summon duration counts down
- [ ] Summon vanishes when duration expires
- [ ] Summon stats scale with caster level
- [ ] Raise Skeleton requires corpse tile
- [ ] Summons persist through save/load (with remaining duration)
- [ ] Concentration spells end when summon dies

## Files Modified
- `entities/player.gd`
- `autoload/entity_manager.gd`
- `autoload/event_bus.gd`
- `systems/magic_system.gd`
- `systems/input_handler.gd`

## Files Created
- `entities/summoned_creature.gd`
- `data/spells/conjuration/summon_creature.json`
- `data/spells/necromancy/raise_skeleton.json`
- `data/enemies/summons/summoned_wolf.json`
- `data/enemies/summons/summoned_skeleton.json`
- `ui/summon_command_menu.gd`
- `ui/summon_command_menu.tscn`

## Next Phase
Once summoning works, proceed to **Phase 16: AOE & Terrain Spells**
