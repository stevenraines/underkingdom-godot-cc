extends Control

signal confirmed()
signal cancelled()

@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var delete_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/DeleteButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/CancelButton

var buttons: Array[Button] = []
var selected_button_index: int = 0

const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	buttons = [delete_button, cancel_button]

	for b in buttons:
		b.focus_mode = Control.FOCUS_NONE

func open(message: String) -> void:
	message_label.text = message
	selected_button_index = 1 # default to cancel
	_update_button_colors()
	show()

func _update_button_colors() -> void:
	for i in range(buttons.size()):
		if i == selected_button_index:
			buttons[i].modulate = COLOR_SELECTED
		else:
			buttons[i].modulate = COLOR_NORMAL

func _on_delete_pressed() -> void:
	emit_signal("confirmed")
	hide()

func _on_cancel_pressed() -> void:
	emit_signal("cancelled")
	hide()
