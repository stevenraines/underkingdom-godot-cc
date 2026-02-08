# Refactor 11: Game UI Coordinator

**Risk Level**: High
**Estimated Changes**: 1 new file, 1 file partially reduced

---

## Goal

Extract UI coordination from `game.gd` (3,337 lines) into a dedicated `UICoordinator` class.

This is the first of three plans to decompose game.gd. Focus on:
- All `_setup_*_screen()` methods (20+ methods)
- All `_on_*_closed()` callbacks
- Screen lifecycle management
- UI state tracking

---

## Current State

### scenes/game.gd UI-Related Code

**Setup Methods (~400 lines):**
- `_setup_inventory_screen()`
- `_setup_character_sheet()`
- `_setup_crafting_screen()`
- `_setup_help_screen()`
- `_setup_shop_screen()`
- `_setup_container_screen()`
- `_setup_level_up_screen()`
- `_setup_spell_list_screen()`
- `_setup_ritual_screen()`
- `_setup_special_actions_screen()`
- `_setup_world_map_screen()`
- `_setup_debug_command_menu()`
- And more...

**Close Handlers (~200 lines):**
- `_on_inventory_closed()`
- `_on_character_sheet_closed()`
- `_on_crafting_closed()`
- And corresponding handlers for each screen...

**State Tracking:**
- `current_open_screen`
- Various `*_screen` node references

---

## Implementation

### Step 1: Create systems/ui_coordinator.gd

```gdscript
class_name UICoordinator
extends RefCounted

## UICoordinator - Manages UI screen lifecycle
##
## Handles opening, closing, and state management for all game UI screens.
## Extracted from game.gd to reduce file size and improve organization.

signal screen_opened(screen_name: String)
signal screen_closed(screen_name: String)

# Screen references (set by game.gd)
var screens: Dictionary = {}

# Currently open screen (if any)
var current_screen: String = ""

# Player reference
var player: Player = null

# Input handler reference (for blocking input during UI)
var input_handler = null


func _init() -> void:
	pass


## Register a screen with the coordinator
func register_screen(name: String, node: Control) -> void:
	screens[name] = node
	node.hide()

	# Connect closed signal if available
	if node.has_signal("closed"):
		node.closed.connect(_on_screen_closed.bind(name))


## Set player reference
func set_player(p: Player) -> void:
	player = p


## Set input handler reference
func set_input_handler(handler) -> void:
	input_handler = handler


## Check if any screen is open
func is_screen_open() -> bool:
	return current_screen != ""


## Get currently open screen name
func get_current_screen() -> String:
	return current_screen


## Close any open screen
func close_current_screen() -> void:
	if current_screen.is_empty():
		return

	var screen = screens.get(current_screen)
	if screen:
		screen.hide()

	var closed_screen = current_screen
	current_screen = ""

	_set_input_blocking(false)
	screen_closed.emit(closed_screen)


# =============================================================================
# SCREEN OPENERS
# =============================================================================

## Open inventory screen
func open_inventory() -> void:
	if not _can_open_screen("inventory"):
		return

	var screen = screens.get("inventory")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)

	_open_screen("inventory")


## Open character sheet
func open_character_sheet() -> void:
	if not _can_open_screen("character_sheet"):
		return

	var screen = screens.get("character_sheet")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)

	_open_screen("character_sheet")


## Open crafting screen
func open_crafting() -> void:
	if not _can_open_screen("crafting"):
		return

	var screen = screens.get("crafting")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)

	_open_screen("crafting")


## Open help screen
func open_help() -> void:
	if not _can_open_screen("help"):
		return
	_open_screen("help")


## Open spell list screen
func open_spell_list() -> void:
	if not _can_open_screen("spell_list"):
		return

	var screen = screens.get("spell_list")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)

	_open_screen("spell_list")


## Open ritual screen
func open_rituals() -> void:
	if not _can_open_screen("ritual"):
		return

	var screen = screens.get("ritual")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)

	_open_screen("ritual")


## Open special actions screen
func open_special_actions() -> void:
	if not _can_open_screen("special_actions"):
		return

	var screen = screens.get("special_actions")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)

	_open_screen("special_actions")


## Open world map screen
func open_world_map() -> void:
	if not _can_open_screen("world_map"):
		return

	var screen = screens.get("world_map")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)
	if screen.has_method("center_on_player"):
		screen.center_on_player()

	_open_screen("world_map")


## Open level up screen
func open_level_up() -> void:
	if not _can_open_screen("level_up"):
		return

	var screen = screens.get("level_up")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)

	_open_screen("level_up")


## Open shop screen with NPC
func open_shop(npc) -> void:
	if not _can_open_screen("shop"):
		return

	var screen = screens.get("shop")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)
	if screen.has_method("set_shop_npc"):
		screen.set_shop_npc(npc)

	_open_screen("shop")


## Open container screen
func open_container(container) -> void:
	if not _can_open_screen("container"):
		return

	var screen = screens.get("container")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)
	if screen.has_method("set_container"):
		screen.set_container(container)

	_open_screen("container")


## Open debug command menu
func open_debug_menu() -> void:
	if not _can_open_screen("debug_menu"):
		return

	var screen = screens.get("debug_menu")
	if screen == null:
		return

	if screen.has_method("set_player"):
		screen.set_player(player)

	_open_screen("debug_menu")


# =============================================================================
# INTERNAL HELPERS
# =============================================================================

## Check if a screen can be opened
func _can_open_screen(screen_name: String) -> bool:
	# Close current screen first if different
	if current_screen == screen_name:
		close_current_screen()
		return false

	if not current_screen.is_empty():
		close_current_screen()

	return screens.has(screen_name)


## Actually open a screen
func _open_screen(screen_name: String) -> void:
	var screen = screens.get(screen_name)
	if screen == null:
		return

	current_screen = screen_name
	screen.show()
	_set_input_blocking(true)
	screen_opened.emit(screen_name)


## Handle screen closed signal
func _on_screen_closed(screen_name: String) -> void:
	if current_screen == screen_name:
		current_screen = ""
		_set_input_blocking(false)
		screen_closed.emit(screen_name)


## Set input blocking state
func _set_input_blocking(blocking: bool) -> void:
	if input_handler and input_handler.has_method("set_ui_blocking"):
		input_handler.set_ui_blocking(blocking)


# =============================================================================
# SCREEN CONFIGURATION
# =============================================================================

## Get list of all registered screens
func get_registered_screens() -> Array[String]:
	var names: Array[String] = []
	for name in screens:
		names.append(name)
	return names


## Check if a screen is registered
func has_screen(name: String) -> bool:
	return name in screens


## Get screen node by name
func get_screen(name: String) -> Control:
	return screens.get(name)
```

---

### Step 2: Update scenes/game.gd

1. **Add UICoordinator instance**:
```gdscript
const UICoordinatorClass = preload("res://systems/ui_coordinator.gd")

var ui_coordinator: UICoordinator = null
```

2. **Initialize in `_ready()`**:
```gdscript
func _ready() -> void:
	# ... existing initialization ...

	# Initialize UI coordinator
	ui_coordinator = UICoordinatorClass.new()
	ui_coordinator.set_player(player)
	ui_coordinator.set_input_handler(input_handler)

	# Register screens
	_register_ui_screens()

	# Connect UI coordinator signals
	ui_coordinator.screen_opened.connect(_on_ui_screen_opened)
	ui_coordinator.screen_closed.connect(_on_ui_screen_closed)
```

3. **Add screen registration method**:
```gdscript
func _register_ui_screens() -> void:
	ui_coordinator.register_screen("inventory", $UI/InventoryScreen)
	ui_coordinator.register_screen("character_sheet", $UI/CharacterSheet)
	ui_coordinator.register_screen("crafting", $UI/CraftingScreen)
	ui_coordinator.register_screen("help", $UI/HelpScreen)
	ui_coordinator.register_screen("shop", $UI/ShopScreen)
	ui_coordinator.register_screen("container", $UI/ContainerScreen)
	ui_coordinator.register_screen("level_up", $UI/LevelUpScreen)
	ui_coordinator.register_screen("spell_list", $UI/SpellListScreen)
	ui_coordinator.register_screen("ritual", $UI/RitualScreen)
	ui_coordinator.register_screen("special_actions", $UI/SpecialActionsScreen)
	ui_coordinator.register_screen("world_map", $UI/WorldMapScreen)
	ui_coordinator.register_screen("debug_menu", $UI/DebugCommandMenu)
```

4. **Simplify key handlers** to use coordinator:
```gdscript
# Before:
func _on_inventory_key_pressed() -> void:
	if inventory_screen.visible:
		_close_inventory()
	else:
		_setup_inventory_screen()
		inventory_screen.show()
		input_handler.set_ui_blocking(true)

# After:
func _on_inventory_key_pressed() -> void:
	ui_coordinator.open_inventory()
```

5. **Add thin wrapper signals** (if needed by other systems):
```gdscript
func _on_ui_screen_opened(screen_name: String) -> void:
	# Any game-specific logic when screens open
	pass

func _on_ui_screen_closed(screen_name: String) -> void:
	# Any game-specific logic when screens close
	# E.g., refresh display, resume gameplay
	_request_full_render()
```

6. **Remove old `_setup_*_screen()` methods** - coordinator handles this.

7. **Remove old `_on_*_closed()` methods** - coordinator handles this.

---

## Files Summary

### New Files
- `systems/ui_coordinator.gd` (~300 lines)

### Modified Files
- `scenes/game.gd` - Reduced by ~600 lines

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Inventory (I key)
  - [ ] Opens correctly
  - [ ] Shows player items
  - [ ] Closes with Escape or I
- [ ] Character Sheet (C key)
  - [ ] Opens correctly
  - [ ] Shows player stats
  - [ ] Closes correctly
- [ ] Crafting (R key)
  - [ ] Opens correctly
  - [ ] Shows recipes
  - [ ] Closes correctly
- [ ] Help (? key)
  - [ ] Opens correctly
  - [ ] Shows keybindings
  - [ ] Closes correctly
- [ ] Spell List (Z key)
  - [ ] Opens correctly
  - [ ] Shows known spells
  - [ ] Closes correctly
- [ ] World Map (M key)
  - [ ] Opens correctly
  - [ ] Shows explored areas
  - [ ] Closes correctly
- [ ] Shop (interact with merchant)
  - [ ] Opens correctly
  - [ ] Shows items
  - [ ] Closes correctly
- [ ] Container (open chest)
  - [ ] Opens correctly
  - [ ] Shows contents
  - [ ] Closes correctly
- [ ] Debug Menu (F12)
  - [ ] Opens correctly
  - [ ] Commands work
  - [ ] Closes correctly
- [ ] Opening one screen closes another
- [ ] Input blocking works correctly
- [ ] Game rendering updates after closing screens
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- scenes/game.gd
rm systems/ui_coordinator.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
