extends Control

## WorldNameDialog - Dialog for entering world name when starting a new game

signal world_name_entered(world_name: String)
signal cancelled()

@onready var name_input: LineEdit = $Panel/MarginContainer/VBoxContainer/NameInput
@onready var start_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/StartButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/CancelButton

var selected_button_index: int = 0
var buttons: Array[Button] = []

const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_START = Color(0.6, 0.9, 0.6, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	buttons = [start_button, cancel_button]

	# Disable focus mode on buttons
	for b in buttons:
		b.focus_mode = Control.FOCUS_NONE

	# Focus the text input when dialog opens
	name_input.focus_mode = Control.FOCUS_ALL

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		# Check if text input has focus
		if name_input.has_focus():
			match event.keycode:
				KEY_ENTER, KEY_KP_ENTER:
					_on_start_button_pressed()
					viewport.set_input_as_handled()
				KEY_ESCAPE:
					_on_cancel_button_pressed()
					viewport.set_input_as_handled()
				KEY_TAB:
					# Tab moves focus to buttons
					name_input.release_focus()
					selected_button_index = 0
					_update_button_colors()
					viewport.set_input_as_handled()
		else:
			# Button navigation
			match event.keycode:
				KEY_LEFT:
					selected_button_index = 0
					_update_button_colors()
					viewport.set_input_as_handled()
				KEY_RIGHT:
					selected_button_index = 1
					_update_button_colors()
					viewport.set_input_as_handled()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					buttons[selected_button_index].emit_signal("pressed")
					viewport.set_input_as_handled()
				KEY_ESCAPE:
					_on_cancel_button_pressed()
					viewport.set_input_as_handled()

func open() -> void:
	show()
	name_input.text = ""
	selected_button_index = 0
	_update_button_colors()

	# Defer focus grab to ensure the dialog is fully shown
	await get_tree().process_frame
	name_input.grab_focus()

func _update_button_colors() -> void:
	for i in range(buttons.size()):
		if i == selected_button_index:
			buttons[i].modulate = COLOR_SELECTED
		else:
			if i == 0:  # Start button
				buttons[i].modulate = COLOR_START
			else:
				buttons[i].modulate = COLOR_NORMAL

func _on_start_button_pressed() -> void:
	var world_name = name_input.text.strip_edges()

	# Allow empty name (will generate random name)
	world_name_entered.emit(world_name)
	hide()

func _on_cancel_button_pressed() -> void:
	cancelled.emit()
	hide()
