class_name FarmingModeHandler
extends RefCounted

## FarmingModeHandler - Handles tilling and planting actions
##
## Extracted from InputHandler to reduce file size and improve maintainability.
## Manages state for tilling and planting direction selection, including seed cycling.

const FarmingSystemClass = preload("res://systems/farming_system.gd")

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
## Returns Dictionary with action taken
func start_till() -> Dictionary:
	if awaiting_direction:
		cancel()
		return {"action": "cancelled"}

	if not player:
		return {"action": "no_player"}

	# Check if player has a hoe equipped
	var tool_check = FarmingSystemClass.has_hoe_equipped(player)
	if not tool_check.has_tool:
		return {"action": "no_tool", "message": "Need a hoe equipped to till soil."}

	current_mode = Mode.TILL
	awaiting_direction = true
	return {"action": "awaiting_direction", "message": "Till which direction? (Arrow keys/WASD, ESC to cancel)"}


## Start planting mode
## Returns Dictionary with action taken
func start_plant() -> Dictionary:
	if not player:
		return {"action": "no_player"}

	# If already in plant mode, cycle to next seed
	if awaiting_direction and current_mode == Mode.PLANT and available_seeds.size() > 1:
		cycle_seed()
		return {"action": "cycled_seed", "seed": selected_seed, "index": current_seed_index, "total": available_seeds.size()}

	if awaiting_direction:
		cancel()
		return {"action": "cancelled"}

	# Get available seeds
	available_seeds = FarmingSystemClass.get_plantable_seeds(player)
	if available_seeds.is_empty():
		return {"action": "no_seeds", "message": "You have no seeds to plant."}

	# Start with the first seed type
	current_mode = Mode.PLANT
	current_seed_index = 0
	selected_seed = available_seeds[0]
	awaiting_direction = true

	return {
		"action": "awaiting_direction",
		"seed": selected_seed,
		"index": current_seed_index,
		"total": available_seeds.size()
	}


## Cycle to next available seed (Tab key)
func cycle_seed() -> void:
	if current_mode != Mode.PLANT or available_seeds.size() <= 1:
		return

	current_seed_index = (current_seed_index + 1) % available_seeds.size()
	selected_seed = available_seeds[current_seed_index]


## Get current seed info for display
func get_seed_info() -> Dictionary:
	if selected_seed == null:
		return {}

	var seed_count = 0
	if player and player.inventory:
		seed_count = player.inventory.get_item_count(selected_seed.id)

	return {
		"seed": selected_seed,
		"count": seed_count,
		"index": current_seed_index,
		"total": available_seeds.size()
	}


## Cancel current farming mode
func cancel() -> void:
	current_mode = Mode.NONE
	awaiting_direction = false
	selected_seed = null
	available_seeds.clear()
	current_seed_index = 0
	action_cancelled.emit()


## Check if this handler should process the input
func wants_input() -> bool:
	return awaiting_direction


## Get current mode
func get_mode() -> Mode:
	return current_mode


## Handle key input for direction selection
## Returns Dictionary with result of handling
func handle_input(keycode: int) -> Dictionary:
	if not awaiting_direction:
		return {"handled": false}

	# Cycle seeds with Tab/Shift+P in plant mode
	if current_mode == Mode.PLANT and (keycode == KEY_TAB or (keycode == KEY_P and Input.is_key_pressed(KEY_SHIFT))):
		cycle_seed()
		return {"handled": true, "action": "cycled_seed", "seed": selected_seed, "index": current_seed_index, "total": available_seeds.size()}

	# Direction input
	var dir = _get_direction_from_key(keycode)
	if dir != Vector2i.ZERO:
		var mode = current_mode
		var seed = selected_seed
		# Don't clear mode yet - let caller do the action first
		return {"handled": true, "action": "direction_selected", "direction": dir, "mode": mode, "seed": seed}

	# Cancel
	if keycode == KEY_ESCAPE:
		var was_mode = current_mode
		cancel()
		var mode_name = "tilling" if was_mode == Mode.TILL else "planting"
		return {"handled": true, "action": "cancelled", "message": "Cancelled %s" % mode_name}

	return {"handled": false}


## Clear mode after action is completed
func clear_mode() -> void:
	current_mode = Mode.NONE
	awaiting_direction = false
	selected_seed = null
	available_seeds.clear()
	current_seed_index = 0


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
