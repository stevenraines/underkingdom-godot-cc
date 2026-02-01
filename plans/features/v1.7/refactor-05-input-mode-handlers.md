# Refactor 05: Input Mode Handlers

**Risk Level**: Low
**Estimated Changes**: 4 new files, 1 file significantly reduced

---

## Goal

Extract 7 input mode handlers from `input_handler.gd` (2,569 lines) into separate classes:
- HarvestModeHandler
- FishingModeHandler
- FarmingModeHandler (tilling + planting)
- LookModeHandler

The existing `TargetingSystem` already follows this pattern and remains unchanged.

---

## Current State

### input_handler.gd Mode State Variables (lines 35-77)
```gdscript
# Harvest mode
var _awaiting_harvest_direction: bool = false
var _harvesting_active: bool = false
var _harvest_direction: Vector2i = Vector2i.ZERO
var _harvest_timer: float = 0.0

# Fishing mode
var _awaiting_fishing_direction: bool = false
var _fishing_active: bool = false
var _fishing_direction: Vector2i = Vector2i.ZERO
var _fishing_timer: float = 0.0

# Farming modes
var _awaiting_till_direction: bool = false
var _awaiting_plant_direction: bool = false
var _selected_seed_for_planting: Item = null
var _available_seeds: Array = []
var _current_seed_index: int = 0

# Trap disarm mode
var _awaiting_disarm_trap_direction: bool = false

# Look mode
var look_mode_active: bool = false
var look_objects: Array = []
var look_index: int = 0
var current_look_object = null
```

Each mode has:
- State variables
- Direction key handling
- Cancel (Escape) handling
- Continuous action processing (some modes)
- Start/stop functions

---

## Implementation

### Step 1: Create systems/input_modes/ Directory

```bash
mkdir -p systems/input_modes
```

---

### Step 2: Create systems/input_modes/harvest_mode_handler.gd

```gdscript
class_name HarvestModeHandler
extends RefCounted

## HarvestModeHandler - Handles harvest direction selection and continuous harvesting
##
## Extracted from InputHandler to reduce file size and improve maintainability.

const HarvestSystemClass = preload("res://systems/harvest_system.gd")

signal harvest_completed()
signal harvest_cancelled()

# State
var awaiting_direction: bool = false
var active: bool = false
var direction: Vector2i = Vector2i.ZERO
var timer: float = 0.0

# References
var player: Player = null

# Constants
const HARVEST_DELAY: float = 0.3


func _init(p: Player = null) -> void:
	player = p


func set_player(p: Player) -> void:
	player = p


## Start harvest mode - waits for direction input
func start() -> void:
	if awaiting_direction or active:
		# Already in harvest mode - cancel it
		cancel()
		return

	awaiting_direction = true
	EventBus.message_logged.emit("Harvest in which direction? (WASD/Arrows, Escape to cancel)")


## Cancel harvest mode
func cancel() -> void:
	if active:
		active = false
		direction = Vector2i.ZERO
		timer = 0.0
		EventBus.message_logged.emit("Stopped harvesting.")

	if awaiting_direction:
		awaiting_direction = false
		EventBus.message_logged.emit("Harvest cancelled.")

	harvest_cancelled.emit()


## Check if this handler should process the input
func wants_input() -> bool:
	return awaiting_direction or active


## Handle input event, returns true if consumed
func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	# Handle direction selection
	if awaiting_direction:
		var dir = _get_direction_from_key(event.keycode)
		if dir != Vector2i.ZERO:
			return _try_start_harvest(dir)
		elif event.keycode == KEY_ESCAPE:
			cancel()
			return true

	# Handle active harvesting cancellation
	if active:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_H:
			cancel()
			return true

	return false


## Process continuous harvesting (called from _process)
func process(delta: float) -> bool:
	if not active or direction == Vector2i.ZERO:
		return false

	timer -= delta
	if timer <= 0:
		timer = HARVEST_DELAY
		return _perform_harvest_action()

	return false


## Check if actively harvesting
func is_active() -> bool:
	return active


## Get direction from keycode
func _get_direction_from_key(keycode: int) -> Vector2i:
	match keycode:
		KEY_W, KEY_UP, KEY_KP_8:
			return Vector2i(0, -1)
		KEY_S, KEY_DOWN, KEY_KP_2:
			return Vector2i(0, 1)
		KEY_A, KEY_LEFT, KEY_KP_4:
			return Vector2i(-1, 0)
		KEY_D, KEY_RIGHT, KEY_KP_6:
			return Vector2i(1, 0)
		KEY_KP_7:
			return Vector2i(-1, -1)
		KEY_KP_9:
			return Vector2i(1, -1)
		KEY_KP_1:
			return Vector2i(-1, 1)
		KEY_KP_3:
			return Vector2i(1, 1)
	return Vector2i.ZERO


## Try to start harvesting in the given direction
func _try_start_harvest(dir: Vector2i) -> bool:
	if player == null:
		return false

	var target_pos = player.position + dir
	var resource = HarvestSystemClass.get_resource_at(target_pos)

	if resource == null:
		EventBus.message_logged.emit("Nothing to harvest there.")
		awaiting_direction = false
		return true

	# Start harvesting
	awaiting_direction = false
	direction = dir
	active = true
	timer = 0.0  # Immediate first harvest

	EventBus.message_logged.emit("Harvesting %s... (Escape or H to stop)" % resource.name)
	return true


## Perform one harvest action
func _perform_harvest_action() -> bool:
	if player == null:
		cancel()
		return false

	var target_pos = player.position + direction
	var result = HarvestSystemClass.try_harvest(player, target_pos)

	if not result.success:
		# Resource depleted or removed
		cancel()
		harvest_completed.emit()
		return false

	# Advance turn for harvest action
	TurnManager.advance_turn()
	return true
```

---

### Step 3: Create systems/input_modes/fishing_mode_handler.gd

```gdscript
class_name FishingModeHandler
extends RefCounted

## FishingModeHandler - Handles fishing direction selection and continuous fishing
##
## Extracted from InputHandler to reduce file size and improve maintainability.

const FishingSystemClass = preload("res://systems/fishing_system.gd")

signal fishing_completed()
signal fishing_cancelled()

# State
var awaiting_direction: bool = false
var active: bool = false
var direction: Vector2i = Vector2i.ZERO
var timer: float = 0.0

# References
var player: Player = null

# Constants
const FISHING_DELAY: float = 0.5


func _init(p: Player = null) -> void:
	player = p


func set_player(p: Player) -> void:
	player = p


## Start fishing mode - waits for direction input
func start() -> void:
	if awaiting_direction or active:
		cancel()
		return

	awaiting_direction = true
	EventBus.message_logged.emit("Fish in which direction? (WASD/Arrows, Escape to cancel)")


## Cancel fishing mode
func cancel() -> void:
	if active:
		active = false
		direction = Vector2i.ZERO
		timer = 0.0
		EventBus.message_logged.emit("Stopped fishing.")

	if awaiting_direction:
		awaiting_direction = false
		EventBus.message_logged.emit("Fishing cancelled.")

	fishing_cancelled.emit()


## Check if this handler should process the input
func wants_input() -> bool:
	return awaiting_direction or active


## Handle input event, returns true if consumed
func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	if awaiting_direction:
		var dir = _get_direction_from_key(event.keycode)
		if dir != Vector2i.ZERO:
			return _try_start_fishing(dir)
		elif event.keycode == KEY_ESCAPE:
			cancel()
			return true

	if active:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_F:
			cancel()
			return true

	return false


## Process continuous fishing (called from _process)
func process(delta: float) -> bool:
	if not active or direction == Vector2i.ZERO:
		return false

	timer -= delta
	if timer <= 0:
		timer = FISHING_DELAY
		return _perform_fishing_action()

	return false


## Check if actively fishing
func is_active() -> bool:
	return active


func _get_direction_from_key(keycode: int) -> Vector2i:
	match keycode:
		KEY_W, KEY_UP, KEY_KP_8:
			return Vector2i(0, -1)
		KEY_S, KEY_DOWN, KEY_KP_2:
			return Vector2i(0, 1)
		KEY_A, KEY_LEFT, KEY_KP_4:
			return Vector2i(-1, 0)
		KEY_D, KEY_RIGHT, KEY_KP_6:
			return Vector2i(1, 0)
	return Vector2i.ZERO


func _try_start_fishing(dir: Vector2i) -> bool:
	if player == null:
		return false

	var target_pos = player.position + dir

	# Check for water tile
	if not FishingSystemClass.can_fish_at(player, target_pos):
		EventBus.message_logged.emit("Can't fish there.")
		awaiting_direction = false
		return true

	awaiting_direction = false
	direction = dir
	active = true
	timer = 0.0

	EventBus.message_logged.emit("Fishing... (Escape or F to stop)")
	return true


func _perform_fishing_action() -> bool:
	if player == null:
		cancel()
		return false

	var target_pos = player.position + direction
	var result = FishingSystemClass.try_fish(player, target_pos)

	# Fishing always advances turn
	TurnManager.advance_turn()

	# Continue fishing unless explicitly cancelled
	return true
```

---

### Step 4: Create systems/input_modes/farming_mode_handler.gd

```gdscript
class_name FarmingModeHandler
extends RefCounted

## FarmingModeHandler - Handles tilling and planting actions
##
## Extracted from InputHandler to reduce file size and improve maintainability.

const FarmingSystemClass = preload("res://systems/farming_system.gd")

signal action_completed()
signal action_cancelled()

enum Mode { NONE, TILL, PLANT }

# State
var current_mode: Mode = Mode.NONE
var awaiting_direction: bool = false
var selected_seed: Item = null
var available_seeds: Array = []
var current_seed_index: int = 0

# References
var player: Player = null


func _init(p: Player = null) -> void:
	player = p


func set_player(p: Player) -> void:
	player = p


## Start tilling mode
func start_till() -> void:
	if awaiting_direction:
		cancel()
		return

	current_mode = Mode.TILL
	awaiting_direction = true
	EventBus.message_logged.emit("Till in which direction? (WASD/Arrows, Escape to cancel)")


## Start planting mode
func start_plant() -> void:
	if player == null:
		return

	if awaiting_direction:
		cancel()
		return

	# Find available seeds
	available_seeds = _get_plantable_seeds()
	if available_seeds.is_empty():
		EventBus.message_logged.emit("You have no seeds to plant.")
		return

	current_mode = Mode.PLANT
	awaiting_direction = true
	current_seed_index = 0
	selected_seed = available_seeds[0]

	EventBus.message_logged.emit("Plant %s in which direction? (WASD/Arrows, Tab to cycle seeds, Escape to cancel)" % selected_seed.display_name)


## Cycle to next available seed (Tab key)
func cycle_seed() -> void:
	if current_mode != Mode.PLANT or available_seeds.size() <= 1:
		return

	current_seed_index = (current_seed_index + 1) % available_seeds.size()
	selected_seed = available_seeds[current_seed_index]
	EventBus.message_logged.emit("Selected: %s" % selected_seed.display_name)


## Cancel current farming mode
func cancel() -> void:
	if awaiting_direction:
		match current_mode:
			Mode.TILL:
				EventBus.message_logged.emit("Tilling cancelled.")
			Mode.PLANT:
				EventBus.message_logged.emit("Planting cancelled.")

	current_mode = Mode.NONE
	awaiting_direction = false
	selected_seed = null
	available_seeds.clear()
	current_seed_index = 0
	action_cancelled.emit()


## Check if this handler should process the input
func wants_input() -> bool:
	return awaiting_direction


## Handle input event, returns true if consumed
func handle_input(event: InputEvent) -> bool:
	if not awaiting_direction:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	# Cycle seeds with Tab in plant mode
	if current_mode == Mode.PLANT and event.keycode == KEY_TAB:
		cycle_seed()
		return true

	# Direction input
	var dir = _get_direction_from_key(event.keycode)
	if dir != Vector2i.ZERO:
		match current_mode:
			Mode.TILL:
				return _try_till(dir)
			Mode.PLANT:
				return _try_plant(dir)

	# Cancel
	if event.keycode == KEY_ESCAPE:
		cancel()
		return true

	return false


func _get_direction_from_key(keycode: int) -> Vector2i:
	match keycode:
		KEY_W, KEY_UP, KEY_KP_8:
			return Vector2i(0, -1)
		KEY_S, KEY_DOWN, KEY_KP_2:
			return Vector2i(0, 1)
		KEY_A, KEY_LEFT, KEY_KP_4:
			return Vector2i(-1, 0)
		KEY_D, KEY_RIGHT, KEY_KP_6:
			return Vector2i(1, 0)
	return Vector2i.ZERO


func _try_till(dir: Vector2i) -> bool:
	if player == null:
		return false

	var target_pos = player.position + dir
	var result = FarmingSystemClass.try_till(player, target_pos)

	awaiting_direction = false
	current_mode = Mode.NONE

	if result.success:
		TurnManager.advance_turn()

	action_completed.emit()
	return true


func _try_plant(dir: Vector2i) -> bool:
	if player == null or selected_seed == null:
		return false

	var target_pos = player.position + dir
	var result = FarmingSystemClass.try_plant(player, target_pos, selected_seed)

	awaiting_direction = false
	current_mode = Mode.NONE
	selected_seed = null
	available_seeds.clear()

	if result.success:
		TurnManager.advance_turn()

	action_completed.emit()
	return true


func _get_plantable_seeds() -> Array:
	if player == null or player.inventory == null:
		return []

	var seeds: Array = []
	for item in player.inventory.items:
		if item.item_type == "seed":
			seeds.append(item)
	return seeds
```

---

### Step 5: Create systems/input_modes/look_mode_handler.gd

```gdscript
class_name LookModeHandler
extends RefCounted

## LookModeHandler - Handles look/examine mode for inspecting visible objects
##
## Extracted from InputHandler to reduce file size and improve maintainability.

const FOVSystemClass = preload("res://systems/fov_system.gd")

signal object_changed(obj)
signal mode_exited()

# State
var active: bool = false
var objects: Array = []
var current_index: int = 0
var current_object = null

# References
var player: Player = null


func _init(p: Player = null) -> void:
	player = p


func set_player(p: Player) -> void:
	player = p


## Start look mode - gather all visible objects
func start() -> void:
	if player == null:
		return

	if active:
		stop()
		return

	# Gather visible objects
	objects = _gather_visible_objects()

	if objects.is_empty():
		EventBus.message_logged.emit("Nothing visible to examine.")
		return

	active = true
	current_index = 0
	_select_object(0)

	EventBus.message_logged.emit("Look mode: Tab/Shift+Tab to cycle, Escape to exit")


## Stop look mode
func stop() -> void:
	active = false
	objects.clear()
	current_index = 0
	current_object = null
	mode_exited.emit()


## Check if look mode is active
func is_active() -> bool:
	return active


## Check if this handler should process the input
func wants_input() -> bool:
	return active


## Handle input event, returns true if consumed
func handle_input(event: InputEvent) -> bool:
	if not active:
		return false

	if not event is InputEventKey or not event.pressed or event.echo:
		return false

	match event.keycode:
		KEY_TAB:
			if event.shift_pressed:
				_cycle_previous()
			else:
				_cycle_next()
			return true
		KEY_ESCAPE, KEY_L:
			stop()
			return true

	return false


## Get the currently looked-at object
func get_current_object():
	return current_object


## Cycle to next object
func _cycle_next() -> void:
	if objects.is_empty():
		return
	current_index = (current_index + 1) % objects.size()
	_select_object(current_index)


## Cycle to previous object
func _cycle_previous() -> void:
	if objects.is_empty():
		return
	current_index = (current_index - 1 + objects.size()) % objects.size()
	_select_object(current_index)


## Select object at index and emit signal
func _select_object(index: int) -> void:
	if index < 0 or index >= objects.size():
		return

	current_object = objects[index]
	object_changed.emit(current_object)

	# Display description
	var desc = _get_object_description(current_object)
	EventBus.message_logged.emit("[%d/%d] %s" % [index + 1, objects.size(), desc])


## Get description for an object
func _get_object_description(obj) -> String:
	if obj == null:
		return "Nothing"

	# Entity (enemy, NPC)
	if obj is Entity:
		if obj.has_method("get_display_name"):
			return obj.get_display_name()
		return obj.display_name if "display_name" in obj else "Entity"

	# Item (ground item)
	if obj is Item:
		return obj.display_name if obj.display_name else "Item"

	# Feature
	if obj is Dictionary and "feature_id" in obj:
		return obj.get("name", "Feature")

	# Ground item wrapper
	if "item" in obj:
		return obj.item.display_name if obj.item else "Item"

	return str(obj)


## Gather all visible objects in FOV
func _gather_visible_objects() -> Array:
	var result: Array = []

	if player == null:
		return result

	var current_map = MapManager.current_map
	if current_map == null:
		return result

	# Get visible tiles from FOV
	var visible_positions = FOVSystemClass.get_visible_positions()

	# Add entities
	for entity in EntityManager.entities:
		if entity != player and entity.position in visible_positions:
			result.append(entity)

	# Add ground items
	for pos in visible_positions:
		var items_at_pos = current_map.get_items_at(pos)
		for item in items_at_pos:
			result.append({"position": pos, "item": item})

	# Add features
	for pos in visible_positions:
		var feature = FeatureManager.get_feature_at(pos)
		if feature:
			result.append(feature)

	# Sort by distance to player
	result.sort_custom(func(a, b):
		var pos_a = _get_object_position(a)
		var pos_b = _get_object_position(b)
		var dist_a = player.position.distance_squared_to(pos_a)
		var dist_b = player.position.distance_squared_to(pos_b)
		return dist_a < dist_b
	)

	return result


## Get position of an object
func _get_object_position(obj) -> Vector2i:
	if obj is Entity:
		return obj.position
	if obj is Dictionary:
		if "position" in obj:
			return obj.position
	return Vector2i.ZERO
```

---

### Step 6: Update systems/input_handler.gd

1. **Add preloads** at top of file:
```gdscript
const HarvestModeHandlerClass = preload("res://systems/input_modes/harvest_mode_handler.gd")
const FishingModeHandlerClass = preload("res://systems/input_modes/fishing_mode_handler.gd")
const FarmingModeHandlerClass = preload("res://systems/input_modes/farming_mode_handler.gd")
const LookModeHandlerClass = preload("res://systems/input_modes/look_mode_handler.gd")
```

2. **Replace state variables** (lines 35-77) with handler instances:
```gdscript
# Mode handlers
var harvest_handler: HarvestModeHandler = null
var fishing_handler: FishingModeHandler = null
var farming_handler: FarmingModeHandler = null
var look_handler: LookModeHandler = null
```

3. **Initialize handlers** in `_ready()`:
```gdscript
func _ready() -> void:
	# ... existing code ...
	harvest_handler = HarvestModeHandlerClass.new()
	fishing_handler = FishingModeHandlerClass.new()
	farming_handler = FarmingModeHandlerClass.new()
	look_handler = LookModeHandlerClass.new()

	# Connect handler signals
	look_handler.object_changed.connect(_on_look_object_changed)
```

4. **Update `set_player()`**:
```gdscript
func set_player(p: Player) -> void:
	player = p
	harvest_handler.set_player(p)
	fishing_handler.set_player(p)
	farming_handler.set_player(p)
	look_handler.set_player(p)
```

5. **Simplify `_unhandled_input()`** - delegate to handlers:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	# ... existing checks ...

	# Check mode handlers first
	if look_handler.wants_input():
		if look_handler.handle_input(event):
			get_viewport().set_input_as_handled()
			return

	if harvest_handler.wants_input():
		if harvest_handler.handle_input(event):
			get_viewport().set_input_as_handled()
			return

	if fishing_handler.wants_input():
		if fishing_handler.handle_input(event):
			get_viewport().set_input_as_handled()
			return

	if farming_handler.wants_input():
		if farming_handler.handle_input(event):
			get_viewport().set_input_as_handled()
			return

	# ... rest of existing input handling ...
```

6. **Simplify `_process()`** - delegate continuous processing:
```gdscript
func _process(delta: float) -> void:
	# ... existing checks ...

	# Process continuous modes
	if harvest_handler.is_active():
		if harvest_handler.process(delta):
			return

	if fishing_handler.is_active():
		if fishing_handler.process(delta):
			return

	# ... rest of existing processing ...
```

7. **Remove old mode-specific methods** and replace with handler calls:
```gdscript
# Before:
func start_harvest_mode() -> void:
	# ... 20+ lines of code ...

# After:
func start_harvest_mode() -> void:
	harvest_handler.start()
```

---

## Files Summary

### New Files
- `systems/input_modes/harvest_mode_handler.gd` (~150 lines)
- `systems/input_modes/fishing_mode_handler.gd` (~140 lines)
- `systems/input_modes/farming_mode_handler.gd` (~180 lines)
- `systems/input_modes/look_mode_handler.gd` (~200 lines)

### Modified Files
- `systems/input_handler.gd` - Reduced from 2,569 to ~800 lines

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Harvest mode (H key)
  - [ ] Direction prompt appears
  - [ ] WASD selects direction
  - [ ] Continuous harvesting works
  - [ ] Escape cancels
- [ ] Fishing mode (F key near water)
  - [ ] Direction prompt appears
  - [ ] Continuous fishing works
  - [ ] Escape cancels
- [ ] Tilling mode (Shift+T)
  - [ ] Direction prompt appears
  - [ ] Tilled ground created
- [ ] Planting mode (Shift+P with seeds)
  - [ ] Direction prompt appears
  - [ ] Tab cycles seeds
  - [ ] Plant is created
- [ ] Look mode (L key)
  - [ ] Objects listed
  - [ ] Tab cycles through objects
  - [ ] Descriptions shown
  - [ ] Escape exits
- [ ] All modes cancel properly with Escape
- [ ] Turn advances correctly for each action
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
rm -rf systems/input_modes/
git checkout HEAD -- systems/input_handler.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
