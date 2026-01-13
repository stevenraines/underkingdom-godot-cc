# Phase 19: Enemy Spellcasters

## Overview
Implement enemy spellcasting AI with 5 enemy mage types that can cast spells at the player.

## Dependencies
- Phase 6: Damage Spells
- Phase 7: Buff/Debuff Spells
- Phase 8: Saving Throws
- Existing: Enemy AI system

## Implementation Steps

### 19.1 Add Spellcasting Properties to Enemy
**File:** `entities/enemy.gd`

```gdscript
# Spellcasting properties
var known_spells: Array[String] = []
var current_mana: int = 0
var max_mana: int = 0
var spell_cooldowns: Dictionary = {}  # spell_id -> turns until ready

func _init_spellcasting() -> void:
    if "spellcaster" in enemy_data:
        var spell_data = enemy_data.spellcaster
        max_mana = spell_data.get("max_mana", 0)
        current_mana = max_mana
        known_spells = spell_data.get("spells", [])
        # Initialize cooldowns
        for spell_id in known_spells:
            spell_cooldowns[spell_id] = 0

func can_cast_spell(spell_id: String) -> bool:
    if spell_id not in known_spells:
        return false
    if spell_cooldowns.get(spell_id, 0) > 0:
        return false
    var spell = SpellManager.get_spell(spell_id)
    if not spell:
        return false
    return current_mana >= spell.mana_cost

func cast_spell_at(spell_id: String, target: Entity) -> bool:
    if not can_cast_spell(spell_id):
        return false

    var spell = SpellManager.get_spell(spell_id)
    current_mana -= spell.mana_cost

    # Set cooldown
    spell_cooldowns[spell_id] = spell.get("cooldown", 3)

    # Use MagicSystem to apply effect
    var result = MagicSystem.attempt_spell(self, spell, target)

    EventBus.enemy_spell_cast.emit(self, spell, target)
    return result.success

func tick_spell_cooldowns() -> void:
    for spell_id in spell_cooldowns:
        if spell_cooldowns[spell_id] > 0:
            spell_cooldowns[spell_id] -= 1
```

### 19.2 Implement Spellcaster AI Behavior
**File:** `entities/enemy.gd`

```gdscript
func _process_spellcaster_turn() -> void:
    tick_spell_cooldowns()

    var player = EntityManager.player
    var distance = _get_distance(position, player.position)
    var has_los = RangedCombatSystem.has_line_of_sight(position, player.position)

    # Try to cast an appropriate spell
    if has_los:
        var spell_to_cast = _choose_spell(player, distance)
        if spell_to_cast:
            cast_spell_at(spell_to_cast, player)
            return

    # If can't cast, use fallback behavior
    match ai_behavior:
        "spellcaster_aggressive":
            # Move toward player to get in range
            if distance > 6:
                _move_toward(player.position)
            else:
                # Melee if adjacent
                if _is_adjacent(player):
                    attack(player)
        "spellcaster_defensive":
            # Keep distance, flee if too close
            if distance < 4:
                _move_away_from(player.position)
            elif distance > 8:
                _move_toward(player.position)

func _choose_spell(target: Entity, distance: int) -> String:
    # Priority: Debuff if target not debuffed > Damage > Buff self

    # Check for debuff opportunities
    for spell_id in known_spells:
        var spell = SpellManager.get_spell(spell_id)
        if spell.effects.has("debuff") and can_cast_spell(spell_id):
            if distance <= spell.targeting.range:
                if not _target_has_effect(target, spell.effects.debuff.id):
                    return spell_id

    # Cast damage spell if in range
    for spell_id in known_spells:
        var spell = SpellManager.get_spell(spell_id)
        if spell.effects.has("damage") and can_cast_spell(spell_id):
            if distance <= spell.targeting.range:
                return spell_id

    # Cast self-buff if available
    for spell_id in known_spells:
        var spell = SpellManager.get_spell(spell_id)
        if spell.effects.has("buff") and spell.targeting.mode == "self":
            if can_cast_spell(spell_id) and not _has_effect(spell.effects.buff.id):
                return spell_id

    return ""
```

### 19.3 Create Enemy Mage Data Files
**File:** `data/enemies/dungeon/barrow_witch.json`

```json
{
  "id": "barrow_witch",
  "name": "Barrow Witch",
  "description": "An undead sorceress haunting the barrows.",
  "ascii_char": "W",
  "ascii_color": "#AA00AA",
  "base_health": 25,
  "base_damage": 4,
  "attributes": {"STR": 8, "DEX": 10, "CON": 10, "INT": 14, "WIS": 12, "CHA": 8},
  "ai_behavior": "spellcaster_defensive",
  "aggro_range": 8,
  "creature_type": "undead",
  "spellcaster": {
    "max_mana": 40,
    "spells": ["curse", "drain_life", "fear"]
  },
  "loot_table": "barrow_witch_loot",
  "xp_value": 50
}
```

**File:** `data/enemies/dungeon/skeleton_mage.json`

```json
{
  "id": "skeleton_mage",
  "name": "Skeleton Mage",
  "description": "An animated skeleton wielding dark magic.",
  "ascii_char": "s",
  "ascii_color": "#8866FF",
  "base_health": 15,
  "base_damage": 3,
  "attributes": {"STR": 6, "DEX": 12, "CON": 8, "INT": 12, "WIS": 10, "CHA": 6},
  "ai_behavior": "spellcaster_aggressive",
  "aggro_range": 7,
  "creature_type": "undead",
  "spellcaster": {
    "max_mana": 25,
    "spells": ["spark", "weakness"]
  },
  "loot_table": "skeleton_mage_loot",
  "xp_value": 30
}
```

**File:** `data/enemies/overworld/hedge_wizard.json`

```json
{
  "id": "hedge_wizard",
  "name": "Hedge Wizard",
  "description": "A rogue mage who preys on travelers.",
  "ascii_char": "@",
  "ascii_color": "#6666FF",
  "base_health": 30,
  "base_damage": 5,
  "attributes": {"STR": 9, "DEX": 11, "CON": 10, "INT": 13, "WIS": 11, "CHA": 10},
  "ai_behavior": "spellcaster_aggressive",
  "aggro_range": 8,
  "creature_type": "humanoid",
  "spellcaster": {
    "max_mana": 35,
    "spells": ["flame_bolt", "shield", "spark"]
  },
  "loot_table": "hedge_wizard_loot",
  "xp_value": 40
}
```

**File:** `data/enemies/dungeon/necromancer.json`

```json
{
  "id": "necromancer",
  "name": "Necromancer",
  "description": "A dark mage who commands the dead.",
  "ascii_char": "N",
  "ascii_color": "#440044",
  "base_health": 40,
  "base_damage": 6,
  "attributes": {"STR": 8, "DEX": 10, "CON": 12, "INT": 16, "WIS": 14, "CHA": 10},
  "ai_behavior": "spellcaster_defensive",
  "aggro_range": 10,
  "creature_type": "humanoid",
  "spellcaster": {
    "max_mana": 60,
    "spells": ["drain_life", "poison", "raise_skeleton", "fear"]
  },
  "loot_table": "necromancer_loot",
  "xp_value": 80
}
```

**File:** `data/enemies/dungeon/elemental_mage.json`

```json
{
  "id": "elemental_mage",
  "name": "Elemental Mage",
  "description": "A mage who has mastered elemental forces.",
  "ascii_char": "M",
  "ascii_color": "#FF6600",
  "base_health": 35,
  "base_damage": 5,
  "attributes": {"STR": 8, "DEX": 12, "CON": 11, "INT": 15, "WIS": 12, "CHA": 11},
  "ai_behavior": "spellcaster_aggressive",
  "aggro_range": 9,
  "creature_type": "humanoid",
  "spellcaster": {
    "max_mana": 50,
    "spells": ["flame_bolt", "ice_shard", "lightning_bolt", "shield"]
  },
  "loot_table": "elemental_mage_loot",
  "xp_value": 70
}
```

### 19.4 Add Spell Cooldown to Spell Data
**File:** `data/spells/` (various files)

Add `"cooldown": N` property to spell JSON files:
- Spark: cooldown 1
- Flame Bolt: cooldown 2
- Lightning Bolt: cooldown 3
- Fear: cooldown 4
- etc.

### 19.5 Create Spellcaster Loot Tables
**File:** `data/loot_tables/enemies/`

```json
{
  "id": "skeleton_mage_loot",
  "entries": [
    {"item_id": "gold", "min": 5, "max": 15, "chance": 1.0},
    {"item_id": "scroll_spark", "chance": 0.3},
    {"item_id": "mana_potion_minor", "chance": 0.2}
  ]
}
```

```json
{
  "id": "necromancer_loot",
  "entries": [
    {"item_id": "gold", "min": 20, "max": 50, "chance": 1.0},
    {"item_id": "scroll_drain_life", "chance": 0.4},
    {"item_id": "scroll_raise_skeleton", "chance": 0.2},
    {"item_id": "wand_fear", "chance": 0.1},
    {"item_id": "mana_potion", "chance": 0.3},
    {"item_id": "spell_tome_poison", "chance": 0.05}
  ]
}
```

### 19.6 Visual Feedback for Enemy Casting
**File:** `rendering/ascii_renderer.gd`

```gdscript
func _on_enemy_spell_cast(enemy: Enemy, spell: Spell, target: Entity) -> void:
    # Flash enemy with spell school color
    var color = _get_school_color(spell.school)
    flash_entity(enemy, color, 0.2)

    # Show casting message
    EventBus.message_logged.emit(
        "%s casts %s!" % [enemy.entity_name, spell.name],
        color
    )

func _get_school_color(school: String) -> Color:
    match school:
        "evocation": return Color.ORANGE
        "necromancy": return Color.PURPLE
        "enchantment": return Color.PINK
        "conjuration": return Color.CYAN
        "abjuration": return Color.BLUE
        "transmutation": return Color.GREEN
        "divination": return Color.YELLOW
        "illusion": return Color.GRAY
    return Color.WHITE
```

### 19.7 Mana Regeneration for Enemies
**File:** `entities/enemy.gd`

```gdscript
var mana_regen_rate: int = 1  # Mana per 5 turns

func process_turn() -> void:
    # Mana regen
    if current_turn % 5 == 0 and current_mana < max_mana:
        current_mana = mini(current_mana + mana_regen_rate, max_mana)

    # ... rest of turn processing
```

### 19.8 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal enemy_spell_cast(enemy: Enemy, spell: Spell, target: Entity)
signal enemy_spell_failed(enemy: Enemy, spell: Spell, reason: String)
```

### 19.9 Spawn Spellcasters in Dungeons
**File:** `generation/dungeon_generators/burial_barrow.gd`

Add enemy spellcasters to spawn tables based on floor depth:
- Floors 1-5: Skeleton Mage (rare)
- Floors 5-15: Barrow Witch, Skeleton Mage
- Floors 10-25: Necromancer (rare)
- Floors 15+: Elemental Mage

## Testing Checklist

- [ ] Enemy mages spawn in dungeons
- [ ] Enemy mages cast spells at player when in range
- [ ] Enemy spells deal damage/apply effects
- [ ] Player can make saving throws vs enemy spells
- [ ] Enemy mages respect spell cooldowns
- [ ] Enemy mages use mana and run out
- [ ] Spellcaster AI chooses appropriate spells
- [ ] Defensive casters keep distance
- [ ] Aggressive casters close to melee range
- [ ] Enemy casting shows visual feedback
- [ ] Message log shows enemy spell casts
- [ ] Necromancers can summon skeletons
- [ ] Enemy mages drop appropriate loot

## Documentation Updates

- [ ] CLAUDE.md updated with enemy spellcaster info
- [ ] `docs/systems/combat-system.md` updated with enemy magic
- [ ] `docs/data/enemies.md` updated with spellcaster format
- [ ] Help screen updated with enemy mage warnings

## Files Modified
- `entities/enemy.gd`
- `rendering/ascii_renderer.gd`
- `autoload/event_bus.gd`
- `generation/dungeon_generators/burial_barrow.gd`

## Files Created
- `data/enemies/dungeon/barrow_witch.json`
- `data/enemies/dungeon/skeleton_mage.json`
- `data/enemies/overworld/hedge_wizard.json`
- `data/enemies/dungeon/necromancer.json`
- `data/enemies/dungeon/elemental_mage.json`
- `data/loot_tables/enemies/skeleton_mage_loot.json`
- `data/loot_tables/enemies/necromancer_loot.json`
- (additional loot tables)

## Next Phase
Once enemy spellcasters work, proceed to **Phase 20: Cantrips & Wild Magic**
