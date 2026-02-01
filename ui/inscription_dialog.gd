extends Control

## InscriptionDialog - Dialog for entering/editing item inscriptions
##
## Allows the player to inscribe text on an item or remove an existing inscription.

signal inscription_entered(text: String)
signal cancelled()

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $Panel/MarginContainer/VBoxContainer/DescriptionLabel
@onready var inscription_input: LineEdit = $Panel/MarginContainer/VBoxContainer/InscriptionInput
@onready var input_separator: HSeparator = $Panel/MarginContainer/VBoxContainer/HSeparator2
@onready var confirm_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/CancelButton

var selected_button_index: int = 0
var buttons: Array[Button] = []
var current_item: Item = null

# Colors from UITheme autoload

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	buttons = [confirm_button, cancel_button]

	# Disable focus mode on buttons
	for b in buttons:
		b.focus_mode = Control.FOCUS_NONE

	# Focus the text input when dialog opens
	inscription_input.focus_mode = Control.FOCUS_ALL

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		# Check if text input has focus
		if inscription_input.has_focus():
			match event.keycode:
				KEY_ENTER, KEY_KP_ENTER:
					_on_confirm_button_pressed()
					viewport.set_input_as_handled()
				KEY_ESCAPE:
					_on_cancel_button_pressed()
					viewport.set_input_as_handled()
				KEY_TAB:
					# Tab moves focus to buttons
					inscription_input.release_focus()
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

## Open dialog for inscribing an item
func open_inscribe(item: Item) -> void:
	current_item = item
	title_label.text = "Inscribe %s" % item.name
	description_label.text = "Enter text to inscribe on this item"
	inscription_input.placeholder_text = "(Enter inscription)"
	inscription_input.text = item.inscription if item.inscription != "" else ""
	inscription_input.visible = true
	input_separator.visible = true
	inscription_input.editable = true
	confirm_button.text = "Inscribe"

	show()
	selected_button_index = 0
	_update_button_colors()

	# Defer focus grab to ensure the dialog is fully shown
	await get_tree().process_frame
	inscription_input.grab_focus()
	inscription_input.select_all()

## Open dialog for uninscribing an item (just shows confirmation)
func open_uninscribe(item: Item) -> void:
	current_item = item
	title_label.text = "Remove Inscription?"
	description_label.text = "Remove inscription from %s?\nCurrent: {%s}" % [item.name, item.inscription]
	inscription_input.visible = false
	input_separator.visible = false
	confirm_button.text = "Remove"

	show()
	selected_button_index = 0
	_update_button_colors()

	await get_tree().process_frame
	# Don't focus input for uninscribe

func _update_button_colors() -> void:
	for i in range(buttons.size()):
		if i == selected_button_index:
			buttons[i].modulate = UITheme.COLOR_SELECTED_GOLD
		else:
			buttons[i].modulate = UITheme.COLOR_NORMAL

func _on_confirm_button_pressed() -> void:
	var text = inscription_input.text.strip_edges()
	inscription_entered.emit(text)
	_close()

func _on_cancel_button_pressed() -> void:
	cancelled.emit()
	_close()

func _close() -> void:
	current_item = null
	inscription_input.visible = true
	input_separator.visible = true
	inscription_input.editable = true
	hide()
