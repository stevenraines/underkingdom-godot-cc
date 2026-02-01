extends Control

signal confirmed()
signal cancelled()

@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var delete_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/DeleteButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/CancelButton

var buttons: Array[Button] = []
var selected_button_index: int = 0

# Colors from UITheme autoload

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	buttons = [delete_button, cancel_button]

	for b in buttons:
		b.focus_mode = Control.FOCUS_NONE

func open(message: String, positive_text: String = "Delete") -> void:
	message_label.text = message
	# Set the positive button label (e.g., "Delete" or "Overwrite")
	if positive_text and not positive_text.is_empty():
		delete_button.text = positive_text

	selected_button_index = 1 # default to cancel
	_update_button_colors()
	show()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		match event.keycode:
			KEY_LEFT:
				selected_button_index = clamp(selected_button_index - 1, 0, buttons.size() - 1)
				_update_button_colors()
				viewport.set_input_as_handled()
			KEY_RIGHT:
				selected_button_index = clamp(selected_button_index + 1, 0, buttons.size() - 1)
				_update_button_colors()
				viewport.set_input_as_handled()
			KEY_TAB:
				selected_button_index = (selected_button_index + 1) % buttons.size()
				_update_button_colors()
				viewport.set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				buttons[selected_button_index].emit_signal("pressed")
				viewport.set_input_as_handled()
			KEY_ESCAPE:
				_on_cancel_pressed()
				viewport.set_input_as_handled()

func _update_button_colors() -> void:
	for i in range(buttons.size()):
		if i == selected_button_index:
			buttons[i].modulate = UITheme.COLOR_SELECTED_GOLD
		else:
			buttons[i].modulate = UITheme.COLOR_NORMAL

func _on_delete_pressed() -> void:
	emit_signal("confirmed")
	hide()

func _on_cancel_pressed() -> void:
	emit_signal("cancelled")
	hide()
