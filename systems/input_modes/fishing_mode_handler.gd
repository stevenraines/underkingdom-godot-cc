class_name FishingModeHandler
extends RefCounted

## FishingModeHandler - Handles fishing direction selection and continuous fishing
##
## Extracted from InputHandler to reduce file size and improve maintainability.
## Manages state for awaiting direction input and continuous fishing mode.

const FishingSystemClass = preload("res://systems/fishing_system.gd")

signal mode_changed(active: bool)

# State
var awaiting_direction: bool = false
var active: bool = false
var direction: Vector2i = Vector2i.ZERO
var timer: float = 0.0

# References
var player: Player = null

# Constants
const FISHING_DELAY: float = 0.12  # Match move_delay from input_handler


func _init(p: Player = null) -> void:
	player = p


func set_player(p: Player) -> void:
	player = p


## Start fishing mode - wait for direction input
func start() -> Dictionary:
	if awaiting_direction or active:
		cancel()
		return {"action": "cancelled"}

	awaiting_direction = true
	return {"action": "awaiting_direction", "message": "Fish which direction? (Arrow keys or WASD)"}


## Cancel fishing mode
func cancel() -> void:
	var was_active = active

	if was_active and player:
		FishingSystemClass.cancel_session(player)

	active = false
	awaiting_direction = false
	direction = Vector2i.ZERO
	timer = 0.0

	if was_active:
		mode_changed.emit(false)


## Check if this handler should process the input
func wants_input() -> bool:
	return awaiting_direction or active


## Check if actively fishing
func is_active() -> bool:
	return active


## Handle key input for direction selection
## Returns Dictionary with result of handling
func handle_direction_input(keycode: int) -> Dictionary:
	if not awaiting_direction:
		return {"handled": false}

	var dir = _get_direction_from_key(keycode)

	if keycode == KEY_ESCAPE:
		awaiting_direction = false
		return {"handled": true, "action": "cancelled", "message": "Cancelled fishing"}

	if dir != Vector2i.ZERO:
		awaiting_direction = false
		return {"handled": true, "action": "direction_selected", "direction": dir}

	return {"handled": false}


## Handle key input while in active fishing mode
## Returns Dictionary with result of handling
func handle_active_input(keycode: int) -> Dictionary:
	if not active:
		return {"handled": false}

	var pressed_direction = _get_direction_from_key(keycode)

	if keycode == KEY_ESCAPE:
		cancel()
		return {"handled": true, "action": "cancelled", "message": "Stopped fishing"}

	if pressed_direction != Vector2i.ZERO:
		if pressed_direction == direction:
			# Same direction - request another fish attempt
			return {"handled": true, "action": "fish_requested", "direction": direction}
		else:
			# Different direction - exit fishing mode
			cancel()
			return {"handled": false}  # Let input_handler process movement

	return {"handled": false}


## Start continuous fishing in a direction
func start_continuous(dir: Vector2i, initial_delay: float) -> void:
	direction = dir
	active = true
	timer = initial_delay
	mode_changed.emit(true)


## Process continuous fishing (called from _process)
## Returns true if timer expired and fish attempt should be made
func process(delta: float) -> bool:
	if not active or direction == Vector2i.ZERO:
		return false

	timer -= delta
	if timer <= 0:
		timer = FISHING_DELAY
		return true

	return false


## Check if still holding the direction key
func is_holding_direction() -> bool:
	if not active:
		return false

	match direction:
		Vector2i.UP:
			return Input.is_action_pressed("ui_up")
		Vector2i.DOWN:
			return Input.is_action_pressed("ui_down")
		Vector2i.LEFT:
			return Input.is_action_pressed("ui_left")
		Vector2i.RIGHT:
			return Input.is_action_pressed("ui_right")

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
