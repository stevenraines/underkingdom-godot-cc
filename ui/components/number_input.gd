extends HBoxContainer
class_name NumberInput

## NumberInput - A keyboard-controlled number input that works while game is paused
##
## Use this component instead of LineEdit for number entry in paused menus.
## Handles number keys (0-9), backspace, and emits signals for Enter/Escape.

signal value_submitted(value: int)
signal cancelled()

@export var min_value: int = 1
@export var max_value: int = 999
@export var default_value: int = 1
@export var max_digits: int = 3
@export var label_text: String = "Value: "

@onready var label: Label = $Label
@onready var value_display: Label = $ValueDisplay

var current_value: String = ""
var is_active: bool = false
var user_has_typed: bool = false  # Track if user has started typing (to replace default on first keystroke)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	label.text = label_text
	# Initialize with default value
	current_value = str(default_value)
	_update_display()

func activate(initial_value: int = -1) -> void:
	"""Activate the input and start accepting keyboard input."""
	if initial_value >= 0:
		current_value = str(initial_value)
	else:
		current_value = str(default_value)
	is_active = true
	user_has_typed = false  # Reset so first keystroke replaces the default
	_update_display()

func deactivate() -> void:
	"""Deactivate the input."""
	is_active = false

func get_value() -> int:
	"""Get the current numeric value."""
	var val = int(current_value) if current_value.length() > 0 else min_value
	return clampi(val, min_value, max_value)

func set_label(text: String) -> void:
	"""Set the label text."""
	label_text = text
	if label:
		label.text = text

func handle_input(event: InputEventKey) -> bool:
	"""
	Process keyboard input. Returns true if input was handled.
	Call this from your menu's _input function when this component is active.
	"""
	if not is_active:
		return false

	match event.keycode:
		KEY_ESCAPE:
			cancelled.emit()
			return true
		KEY_ENTER:
			value_submitted.emit(get_value())
			return true
		KEY_BACKSPACE:
			_handle_backspace()
			return true
		KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			_handle_digit(event.keycode - KEY_0)
			return true
		KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9:
			_handle_digit(event.keycode - KEY_KP_0)
			return true

	return false

func _handle_digit(digit: int) -> void:
	var digit_str = str(digit)

	# First keystroke replaces the entire default value
	if not user_has_typed:
		current_value = digit_str
		user_has_typed = true
	elif current_value.length() < max_digits:
		current_value = current_value + digit_str

	# Clamp to max_value
	if int(current_value) > max_value:
		current_value = str(max_value)

	_update_display()

func _handle_backspace() -> void:
	user_has_typed = true  # User is actively editing
	if current_value.length() > 1:
		current_value = current_value.substr(0, current_value.length() - 1)
	elif current_value.length() == 1:
		# Allow clearing to empty - will show as empty, next digit starts fresh
		current_value = ""
	# If already empty, stay empty
	_update_display()

func _update_display() -> void:
	if value_display:
		# Show underscore when empty to indicate input is ready
		value_display.text = current_value if current_value.length() > 0 else "_"
