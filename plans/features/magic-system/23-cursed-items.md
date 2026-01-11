# Phase 23: Cursed Items

## Overview
Implement cursed scrolls and equipment with negative effects that cannot be unequipped without Remove Curse.

## Dependencies
- Phase 9: Scrolls
- Phase 12: Magic Rings (passive effects)
- Phase 13: Identification

## Implementation Steps

### 23.1 Add Curse Properties to Items
**File:** `items/item.gd`

```gdscript
var is_cursed: bool = false
var curse_type: String = ""  # binding, draining, unlucky, etc.
var curse_revealed: bool = false  # True once curse is discovered

func has_curse() -> bool:
    return is_cursed and curse_type != ""

func reveal_curse() -> void:
    if is_cursed:
        curse_revealed = true
        EventBus.curse_revealed.emit(self)
```

### 23.2 Implement Binding Curse (Cannot Unequip)
**File:** `systems/inventory_system.gd`

```gdscript
func unequip_item(slot: String, player: Entity) -> bool:
    var item = player.equipment.get(slot)
    if not item:
        return false

    # Check for binding curse
    if item.is_cursed and item.curse_type == "binding":
        if not item.curse_revealed:
            item.reveal_curse()
        EventBus.message_logged.emit(
            "The %s is cursed! It won't come off!" % item.display_name,
            Color.RED
        )
        return false

    # Normal unequip
    return _do_unequip(slot, player)
```

### 23.3 Create Cursed Scroll Effects
**File:** `systems/magic_system.gd`

```gdscript
const CURSED_SCROLL_EFFECTS = [
    {id = "curse_blindness", effect = "Temporary blindness", duration = 20},
    {id = "curse_weakness", effect = "STR reduced", modifier = -3, duration = 50},
    {id = "curse_confusion", effect = "Movement randomized", duration = 15},
    {id = "curse_mana_drain", effect = "Lose all mana"},
    {id = "curse_summon_enemy", effect = "Hostile creature appears"},
    {id = "curse_teleport", effect = "Teleport to random location"},
    {id = "curse_hunger", effect = "Extreme hunger", hunger_drain = 50},
    {id = "curse_aging", effect = "CON reduced permanently", modifier = -1}
]

static func use_cursed_scroll(player: Entity, scroll: Item) -> void:
    var effect = CURSED_SCROLL_EFFECTS[randi() % CURSED_SCROLL_EFFECTS.size()]

    EventBus.message_logged.emit(
        "The scroll crumbles to dust! A curse takes hold!",
        Color.DARK_RED
    )

    match effect.id:
        "curse_blindness":
            player.add_magical_effect({
                id = "curse_blindness",
                type = "debuff",
                stat = "vision_range",
                modifier = -10,
                remaining_duration = effect.duration
            })
            EventBus.message_logged.emit("You are blinded!", Color.RED)

        "curse_weakness":
            player.add_magical_effect({
                id = "curse_weakness",
                type = "debuff",
                stat = "STR",
                modifier = effect.modifier,
                remaining_duration = effect.duration
            })
            EventBus.message_logged.emit("Your strength fades!", Color.RED)

        "curse_confusion":
            player.add_magical_effect({
                id = "curse_confusion",
                type = "confusion",
                remaining_duration = effect.duration
            })
            EventBus.message_logged.emit("Your mind reels in confusion!", Color.RED)

        "curse_mana_drain":
            player.survival.mana = 0
            EventBus.message_logged.emit("Your magical energy is drained!", Color.RED)

        "curse_summon_enemy":
            var pos = MapManager.current_map.get_adjacent_walkable_position(player.position)
            if pos:
                EntityManager.spawn_enemy("barrow_wight", pos)
            EventBus.message_logged.emit("Something emerges from the shadows!", Color.RED)

        "curse_teleport":
            var positions = MapManager.current_map.get_walkable_positions_in_range(player.position, 20)
            if positions.size() > 0:
                player.position = positions[randi() % positions.size()]
            EventBus.message_logged.emit("You are teleported away!", Color.RED)

        "curse_hunger":
            player.survival.hunger = maxi(player.survival.hunger - effect.hunger_drain, 0)
            EventBus.message_logged.emit("Terrible hunger gnaws at you!", Color.RED)

        "curse_aging":
            player.base_attributes["CON"] -= 1
            player.recalculate_derived_stats()
            EventBus.message_logged.emit("You feel your life force drain away...", Color.DARK_RED)
```

### 23.4 Create Cursed Scroll Items
**File:** `data/items/scrolls/cursed_scroll.json`

```json
{
  "id": "cursed_scroll",
  "name": "Scroll",
  "description": "A scroll with strange markings.",
  "category": "scroll",
  "flags": {"consumable": true, "magical": true, "cursed": true, "unidentified": true},
  "unidentified_pool": "scroll",
  "effects": {
    "cursed_effect": true
  },
  "weight": 0.1,
  "value": 0,
  "ascii_char": "?",
  "ascii_color": "#884444"
}
```

### 23.5 Create Cursed Equipment
**File:** `data/items/armor/cursed_ring_weakness.json`

```json
{
  "id": "cursed_ring_weakness",
  "name": "Ring of Strength",
  "true_name": "Cursed Ring of Weakness",
  "description": "A golden ring that glows faintly.",
  "true_description": "A cursed ring that saps your strength.",
  "category": "accessory",
  "slot": "ring",
  "flags": {"equippable": true, "magical": true, "cursed": true, "unidentified": true},
  "unidentified_pool": "ring",
  "curse_type": "binding",
  "passive_effects": {
    "stat_modifier": {"STR": -3}
  },
  "fake_passive_effects": {
    "stat_modifier": {"STR": 3}
  },
  "weight": 0.1,
  "value": 0,
  "ascii_char": "=",
  "ascii_color": "#AA8800"
}
```

**File:** `data/items/armor/cursed_amulet_draining.json`

```json
{
  "id": "cursed_amulet_draining",
  "name": "Amulet of Vitality",
  "true_name": "Cursed Amulet of Draining",
  "description": "An amulet that pulses with energy.",
  "true_description": "A cursed amulet that drains your health.",
  "category": "accessory",
  "slot": "neck",
  "flags": {"equippable": true, "magical": true, "cursed": true, "unidentified": true},
  "unidentified_pool": "amulet",
  "curse_type": "binding",
  "passive_effects": {
    "health_drain_per_turn": 1
  },
  "fake_passive_effects": {
    "stat_modifier": {"CON": 2}
  },
  "weight": 0.2,
  "value": 0,
  "ascii_char": "\"",
  "ascii_color": "#660066"
}
```

### 23.6 Implement Remove Curse Spell
**File:** `data/spells/abjuration/remove_curse.json`

```json
{
  "id": "remove_curse",
  "name": "Remove Curse",
  "description": "Lift a curse from an item or creature.",
  "school": "abjuration",
  "level": 4,
  "mana_cost": 20,
  "requirements": {"character_level": 4, "intelligence": 11},
  "targeting": {"mode": "self_or_item"},
  "effects": {
    "remove_curse": true
  },
  "cast_message": "The curse dissipates!"
}
```

**File:** `systems/magic_system.gd`

```gdscript
static func _apply_remove_curse(caster: Entity, target, result: Dictionary) -> Dictionary:
    if target is Item:
        if target.is_cursed:
            target.is_cursed = false
            target.curse_type = ""
            # Restore true name if it was hidden
            if target.true_name:
                target.display_name = target.true_name
            result.message = "The curse is lifted from the %s!" % target.display_name
            result.success = true
        else:
            result.message = "That item is not cursed."
            result.success = false
    elif target is Entity:
        # Remove curse debuffs
        var curses_removed = 0
        for effect in target.active_effects.duplicate():
            if effect.id.begins_with("curse_"):
                target.remove_magical_effect(effect.id)
                curses_removed += 1

        if curses_removed > 0:
            result.message = "The curses are lifted!"
            result.success = true
        else:
            result.message = "No curses to remove."
            result.success = false

    return result
```

### 23.7 Curse Reveal on Equip
**File:** `systems/inventory_system.gd`

```gdscript
func equip_item(item: Item, player: Entity) -> bool:
    # ... normal equip logic ...

    # After equipping, check for curse
    if item.is_cursed and not item.curse_revealed:
        # Curse reveals itself
        item.reveal_curse()

        # Apply curse effects
        match item.curse_type:
            "binding":
                EventBus.message_logged.emit(
                    "The %s feels wrong... you can't remove it!" % item.display_name,
                    Color.RED
                )
            "draining":
                EventBus.message_logged.emit(
                    "The %s begins to drain your life force!" % item.display_name,
                    Color.RED
                )

        # Update name to true name
        if item.true_name:
            item.display_name = item.true_name

    return true
```

### 23.8 Add Remove Curse Service to Town Mage
**File:** `data/npcs/town/eldric_mage.json`

```json
{
  "services": ["shop", "teach_spell", "identify", "remove_curse"],
  "remove_curse_price": 100
}
```

### 23.9 Process Draining Curse Effects
**File:** `autoload/turn_manager.gd`

```gdscript
func _process_curse_effects() -> void:
    var player = EntityManager.player

    for slot in player.equipment:
        var item = player.equipment[slot]
        if item and item.is_cursed and item.curse_revealed:
            if "health_drain_per_turn" in item.passive_effects:
                var drain = item.passive_effects.health_drain_per_turn
                player.take_damage(drain, null, "curse")
            if "mana_drain_per_turn" in item.passive_effects:
                var drain = item.passive_effects.mana_drain_per_turn
                player.survival.mana = maxi(player.survival.mana - drain, 0)
```

### 23.10 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal curse_revealed(item: Item)
signal curse_removed(item: Item)
signal cursed_scroll_used(player: Entity, effect: String)
```

## Testing Checklist

- [ ] Cursed scrolls trigger random curse effects
- [ ] Blindness curse reduces vision
- [ ] Weakness curse reduces STR
- [ ] Confusion curse randomizes movement
- [ ] Mana drain curse empties mana
- [ ] Enemy summon curse spawns hostile
- [ ] Binding cursed ring cannot be unequipped
- [ ] Binding curse revealed on equip attempt to remove
- [ ] Draining amulet damages each turn
- [ ] Remove Curse spell lifts curses
- [ ] Town mage offers Remove Curse service
- [ ] Cursed items show true name after reveal
- [ ] Identification shows curse status
- [ ] High INT may detect curses before use

## Documentation Updates

- [ ] CLAUDE.md updated with curse mechanics
- [ ] Help screen updated with curse warnings
- [ ] `docs/systems/magic-system.md` updated with curse system
- [ ] `docs/data/items.md` updated with curse format

## Files Modified
- `items/item.gd`
- `systems/inventory_system.gd`
- `systems/magic_system.gd`
- `autoload/turn_manager.gd`
- `autoload/event_bus.gd`
- `data/npcs/town/eldric_mage.json`

## Files Created
- `data/items/scrolls/cursed_scroll.json`
- `data/items/armor/cursed_ring_weakness.json`
- `data/items/armor/cursed_amulet_draining.json`
- `data/spells/abjuration/remove_curse.json`

## Next Phase
Once cursed items work, proceed to **Phase 24: Ritual System Core**
