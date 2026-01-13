# Phase 24: Ritual System Core

## Overview
Implement the ritual casting system with multi-step channeling, component consumption, and interruption handling.

## Dependencies
- Phase 1: Mana System
- Phase 4: Basic Casting (spell failure patterns)
- Phase 11: Wands & Staves (for ritual foci)

## Implementation Steps

### 24.1 Create Ritual Data Structure
**File:** `systems/ritual.gd` (new)

```gdscript
class_name Ritual
extends RefCounted

var id: String
var name: String
var description: String
var school: String
var components: Array = []  # [{item_id, quantity}]
var channeling_turns: int
var effects: Dictionary
var requirements: Dictionary
var failure_effects: Dictionary
var discovery_location: String  # Where ritual can be found

func _init(data: Dictionary):
    id = data.get("id", "")
    name = data.get("name", "Unknown Ritual")
    description = data.get("description", "")
    school = data.get("school", "transmutation")
    components = data.get("components", [])
    channeling_turns = data.get("channeling_turns", 5)
    effects = data.get("effects", {})
    requirements = data.get("requirements", {})
    failure_effects = data.get("failure_effects", {})
    discovery_location = data.get("discovery_location", "")

func get_component_list() -> String:
    var parts = []
    for comp in components:
        parts.append("%dx %s" % [comp.quantity, ItemManager.get_item_name(comp.item_id)])
    return ", ".join(parts)
```

### 24.2 Create Ritual Manager
**File:** `autoload/ritual_manager.gd` (new)

```gdscript
extends Node

const RITUAL_DATA_PATH = "res://data/rituals"

var rituals: Dictionary = {}  # id -> Ritual

func _ready() -> void:
    _load_rituals()

func _load_rituals() -> void:
    _load_from_directory(RITUAL_DATA_PATH)

func _load_from_directory(path: String) -> void:
    var dir = DirAccess.open(path)
    if not dir:
        return

    dir.list_dir_begin()
    var file_name = dir.get_next()

    while file_name != "":
        var full_path = path + "/" + file_name
        if dir.current_is_dir() and not file_name.begins_with("."):
            _load_from_directory(full_path)
        elif file_name.ends_with(".json"):
            _load_ritual_file(full_path)
        file_name = dir.get_next()

    dir.list_dir_end()

func _load_ritual_file(path: String) -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return

    var json = JSON.new()
    var error = json.parse(file.get_as_text())
    if error == OK:
        var data = json.get_data()
        var ritual = Ritual.new(data)
        rituals[ritual.id] = ritual

func get_ritual(ritual_id: String) -> Ritual:
    return rituals.get(ritual_id)

func get_all_rituals() -> Array:
    return rituals.values()
```

### 24.3 Create Ritual System
**File:** `systems/ritual_system.gd` (new)

```gdscript
class_name RitualSystem
extends RefCounted

# Active ritual state
static var active_ritual: Ritual = null
static var ritual_caster: Entity = null
static var channeling_remaining: int = 0
static var consumed_components: Array = []

static func can_perform_ritual(caster: Entity, ritual: Ritual) -> Dictionary:
    var result = {can_perform = true, reason = ""}

    # Check INT requirement
    var min_int = ritual.requirements.get("intelligence", 8)
    if caster.get_effective_attribute("INT") < min_int:
        result.can_perform = false
        result.reason = "Requires %d Intelligence." % min_int
        return result

    # Check if already channeling
    if active_ritual != null:
        result.can_perform = false
        result.reason = "Already performing a ritual."
        return result

    # Check components
    for component in ritual.components:
        var item_id = component.item_id
        var quantity = component.quantity
        if not caster.inventory.has_item(item_id, quantity):
            result.can_perform = false
            var item_name = ItemManager.get_item_name(item_id)
            result.reason = "Missing component: %dx %s" % [quantity, item_name]
            return result

    # Check special requirements
    if ritual.requirements.get("near_altar", false):
        if not _is_near_altar(caster):
            result.can_perform = false
            result.reason = "Must be performed at an altar."
            return result

    if ritual.requirements.get("night_only", false):
        if TurnManager.time_of_day not in ["night", "midnight"]:
            result.can_perform = false
            result.reason = "Can only be performed at night."
            return result

    return result

static func begin_ritual(caster: Entity, ritual: Ritual) -> bool:
    var check = can_perform_ritual(caster, ritual)
    if not check.can_perform:
        EventBus.message_logged.emit(check.reason, Color.YELLOW)
        return false

    # Consume components
    consumed_components = []
    for component in ritual.components:
        var item = caster.inventory.remove_item(component.item_id, component.quantity)
        consumed_components.append(item)

    # Start channeling
    active_ritual = ritual
    ritual_caster = caster
    channeling_remaining = ritual.channeling_turns

    EventBus.ritual_started.emit(caster, ritual)
    EventBus.message_logged.emit(
        "You begin the %s ritual... (%d turns to complete)" % [ritual.name, channeling_remaining],
        Color.MAGENTA
    )

    return true

static func process_channeling_turn() -> void:
    if active_ritual == null:
        return

    channeling_remaining -= 1

    # Progress message
    if channeling_remaining > 0:
        EventBus.message_logged.emit(
            "Channeling %s... %d turns remaining" % [active_ritual.name, channeling_remaining],
            Color.MAGENTA
        )
    else:
        # Ritual complete
        _complete_ritual()

static func interrupt_ritual(reason: String = "interrupted") -> void:
    if active_ritual == null:
        return

    EventBus.message_logged.emit(
        "The %s ritual is %s!" % [active_ritual.name, reason],
        Color.RED
    )

    # Apply failure effects
    _apply_failure_effects()

    EventBus.ritual_interrupted.emit(ritual_caster, active_ritual, reason)

    # Clear state
    active_ritual = null
    ritual_caster = null
    channeling_remaining = 0
    consumed_components = []

static func _complete_ritual() -> void:
    EventBus.message_logged.emit(
        "The %s ritual is complete!" % active_ritual.name,
        Color.CYAN
    )

    # Apply ritual effects
    var result = _apply_ritual_effects(ritual_caster, active_ritual)

    EventBus.ritual_completed.emit(ritual_caster, active_ritual, result)

    # Clear state
    active_ritual = null
    ritual_caster = null
    channeling_remaining = 0
    consumed_components = []

static func _apply_failure_effects() -> void:
    if active_ritual.failure_effects.is_empty():
        return

    # Determine failure type (similar to spell failure)
    var roll = randi_range(1, 20)

    if roll <= 5:
        # Wild magic
        WildMagic.trigger_wild_magic(ritual_caster, null)
    elif roll <= 10:
        # Backfire - ritual effects target caster negatively
        EventBus.message_logged.emit("The ritual backfires!", Color.RED)
        _apply_backfire(ritual_caster, active_ritual)
    else:
        # Fizzle - components lost, nothing happens
        EventBus.message_logged.emit("The ritual fizzles. Components are lost.", Color.YELLOW)

static func _apply_backfire(caster: Entity, ritual: Ritual) -> void:
    # Apply negative version of ritual effects
    if "damage" in ritual.effects:
        caster.take_damage(ritual.effects.damage.base * 2, null, "ritual_backfire")
    if "summon" in ritual.effects:
        # Summon hostile creature instead
        var pos = MapManager.current_map.get_adjacent_walkable_position(caster.position)
        if pos:
            EntityManager.spawn_enemy(ritual.effects.summon.creature_id, pos)

static func _is_near_altar(entity: Entity) -> bool:
    # Check if entity is adjacent to an altar tile
    for offset in [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]:
        var pos = entity.position + offset
        var tile = MapManager.current_map.get_tile(pos)
        if tile and tile.tile_type == "altar":
            return true
    return false

static func is_channeling() -> bool:
    return active_ritual != null

static func get_channeling_progress() -> Dictionary:
    if active_ritual == null:
        return {}
    return {
        ritual = active_ritual,
        remaining = channeling_remaining,
        total = active_ritual.channeling_turns
    }
```

### 24.4 Hook Ritual Interruption to Combat
**File:** `systems/combat_system.gd`

```gdscript
static func apply_damage(target: Entity, damage: int, source: Entity, method: String) -> void:
    # ... existing damage code ...

    # Interrupt ritual if channeling
    if target == RitualSystem.ritual_caster and RitualSystem.is_channeling():
        RitualSystem.interrupt_ritual("disrupted by damage")
```

### 24.5 Create Ritual UI
**IMPORTANT:** Use the `ui-implementation` agent for this UI.

**File:** `ui/ritual_menu.gd` (new)

Features:
- List known rituals
- Show components required with inventory count
- Show channeling time
- Show special requirements (altar, night, etc.)
- "Begin Ritual" button (disabled if requirements not met)

### 24.6 Handle Ritual Input
**File:** `systems/input_handler.gd`

```gdscript
func _handle_input() -> void:
    # ... existing input handling ...

    # Check if channeling - restrict actions
    if RitualSystem.is_channeling():
        if Input.is_action_just_pressed("wait"):
            # Continue channeling (player chose to wait)
            RitualSystem.process_channeling_turn()
            TurnManager.advance_turn()
        elif Input.is_action_just_pressed("cancel"):
            # Voluntarily cancel ritual
            RitualSystem.interrupt_ritual("cancelled")
        else:
            # Any other action interrupts ritual
            EventBus.message_logged.emit(
                "Press 'R' to continue channeling or 'Escape' to cancel.",
                Color.YELLOW
            )
        return

    # Open ritual menu
    if Input.is_action_just_pressed("ritual_menu"):
        EventBus.ritual_menu_requested.emit()
```

### 24.7 Add Ritual Tracking to Player
**File:** `entities/player.gd`

```gdscript
var known_rituals: Array[String] = []

func learn_ritual(ritual_id: String) -> bool:
    if ritual_id in known_rituals:
        return false

    known_rituals.append(ritual_id)
    EventBus.ritual_learned.emit(self, ritual_id)
    return true

func knows_ritual(ritual_id: String) -> bool:
    return ritual_id in known_rituals
```

### 24.8 Create Ritual Tome Items
**File:** `data/items/books/ritual_tome_enchant.json`

```json
{
  "id": "ritual_tome_enchant",
  "name": "Tome of Enchantment",
  "description": "An ancient tome describing the Enchant Item ritual.",
  "category": "book",
  "subcategory": "ritual_tome",
  "flags": {"usable": true, "magical": true},
  "effects": {
    "teaches_ritual": "enchant_item"
  },
  "weight": 1.0,
  "value": 500,
  "ascii_char": "+",
  "ascii_color": "#FF88FF"
}
```

### 24.9 Add EventBus Signals
**File:** `autoload/event_bus.gd`

```gdscript
signal ritual_started(caster: Entity, ritual: Ritual)
signal ritual_completed(caster: Entity, ritual: Ritual, result: Dictionary)
signal ritual_interrupted(caster: Entity, ritual: Ritual, reason: String)
signal ritual_progress(caster: Entity, ritual: Ritual, turns_remaining: int)
signal ritual_learned(entity: Entity, ritual_id: String)
signal ritual_menu_requested()
```

### 24.10 Display Channeling in HUD
**File:** `ui/hud.gd`

```gdscript
func _on_ritual_progress(caster: Entity, ritual: Ritual, turns_remaining: int) -> void:
    channeling_label.visible = true
    channeling_label.text = "CHANNELING: %s (%d)" % [ritual.name, turns_remaining]

func _on_ritual_completed(caster: Entity, ritual: Ritual, result: Dictionary) -> void:
    channeling_label.visible = false

func _on_ritual_interrupted(caster: Entity, ritual: Ritual, reason: String) -> void:
    channeling_label.visible = false
```

### 24.11 Add Keybinding for Ritual Menu
**File:** Project Settings > Input Map

Add: `ritual_menu` - mapped to 'T' (for "Tome/Ritual")

## Testing Checklist

- [ ] Ritual menu opens with T key
- [ ] Known rituals listed in menu
- [ ] Cannot start ritual without components
- [ ] Components consumed on ritual start
- [ ] Channeling progress shows in HUD
- [ ] Wait (R) continues channeling
- [ ] Escape cancels ritual voluntarily
- [ ] Taking damage interrupts ritual
- [ ] Movement attempt shows warning during channeling
- [ ] Failure effects trigger on interruption
- [ ] Ritual tomes teach rituals when used
- [ ] Special requirements (altar, night) enforced
- [ ] Ritual state saved/loaded correctly

## Documentation Updates

- [ ] CLAUDE.md updated with ritual system
- [ ] Help screen updated with ritual keybindings
- [ ] `docs/systems/ritual-system.md` created
- [ ] `docs/data/rituals.md` created

## Files Modified
- `entities/player.gd`
- `systems/combat_system.gd`
- `systems/input_handler.gd`
- `autoload/event_bus.gd`
- `ui/hud.gd`

## Files Created
- `systems/ritual.gd`
- `systems/ritual_system.gd`
- `autoload/ritual_manager.gd`
- `ui/ritual_menu.gd`
- `ui/ritual_menu.tscn`
- `data/items/books/ritual_tome_enchant.json`
- (more ritual tomes in Phase 25)

## Next Phase
Once ritual core works, proceed to **Phase 25: Ritual Effects**
