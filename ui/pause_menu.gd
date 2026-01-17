extends Control

## PauseMenu - Pause game and access save/load functionality
##
## Allows saving to 3 slots, shows save slot information, and resume/quit options.

signal closed()
signal main_menu_requested()

@onready var slot1_button: Button = $Panel/MarginContainer/VBoxContainer/SlotsContainer/Slot1Button
@onready var slot2_button: Button = $Panel/MarginContainer/VBoxContainer/SlotsContainer/Slot2Button
@onready var slot3_button: Button = $Panel/MarginContainer/VBoxContainer/SlotsContainer/Slot3Button
@onready var resume_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/ResumeButton
@onready var main_menu_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonsContainer/MainMenuButton
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Title
@onready var confirm_dialog: Control = null

var slot_buttons: Array[Button] = []
var selected_index: int = 0
var mode: String = "save"  # "save" or "load"
var pending_action: String = ""
var pending_slot: int = -1

# Colors
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_EMPTY = Color(0.5, 0.5, 0.5, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	slot_buttons = [slot1_button, slot2_button, slot3_button]

	# Create or instance a styled confirm-delete dialog (matches new-world dialog)
	if not has_node("ConfirmDialog"):
		var dlg_scene = load("res://ui/confirm_delete_dialog.tscn")
		var dlg = dlg_scene.instantiate()
		dlg.name = "ConfirmDialog"
		add_child(dlg)
		confirm_dialog = dlg
		# Connect signals
		if not confirm_dialog.is_connected("confirmed", Callable(self, "_on_confirmed")):
			confirm_dialog.connect("confirmed", Callable(self, "_on_confirmed"))
		if not confirm_dialog.is_connected("cancelled", Callable(self, "_on_confirm_cancelled")):
			confirm_dialog.connect("cancelled", Callable(self, "_on_confirm_cancelled"))
	else:
		confirm_dialog = $ConfirmDialog
		if not confirm_dialog.is_connected("confirmed", Callable(self, "_on_confirmed")):
			confirm_dialog.connect("confirmed", Callable(self, "_on_confirmed"))

	# Connect button signals
	slot1_button.pressed.connect(_on_slot_pressed.bind(1))
	slot2_button.pressed.connect(_on_slot_pressed.bind(2))
	slot3_button.pressed.connect(_on_slot_pressed.bind(3))
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		match event.keycode:
			KEY_ESCAPE:
				_close()
				viewport.set_input_as_handled()
			KEY_Q:
				_on_main_menu_pressed()
				viewport.set_input_as_handled()
			KEY_UP:
				_navigate(-1)
				viewport.set_input_as_handled()
			KEY_DOWN:
				_navigate(1)
				viewport.set_input_as_handled()
			KEY_ENTER:
				_select_current()
				viewport.set_input_as_handled()
			# Accept multiple delete/backspace scancodes so physical DEL works too
			KEY_DELETE, KEY_BACKSPACE, KEY_D:
				print("[PauseMenu] DELETE or D key pressed")
				_delete_current_slot()
				viewport.set_input_as_handled()

func open(save_mode: bool = true) -> void:
	mode = "save" if save_mode else "load"
	selected_index = 0

	# Update UI based on mode
	if mode == "load":
		title_label.text = "◆ LOAD GAME ◆"
		resume_button.visible = false
		main_menu_button.text = "Back to Main Menu (Q)"
	else:
		title_label.text = "◆ GAME PAUSED ◆"
		resume_button.visible = true
		main_menu_button.text = "Main Menu (Q)"

	_refresh_slot_info()
	_update_button_colors()
	show()
	get_tree().paused = true

func _close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()

func _navigate(direction: int) -> void:
	# Total navigable items depends on mode
	# Load mode: 3 slots + 1 button (main menu) = 0-3
	# Save mode: 3 slots + 2 buttons (resume + main menu) = 0-4
	var max_index = 3 if mode == "load" else 4
	selected_index = clamp(selected_index + direction, 0, max_index)
	_update_button_colors()

func _update_button_colors() -> void:
	# Update slot buttons
	for i in range(slot_buttons.size()):
		var slot_num = i + 1
		var info = SaveManager.get_save_slot_info(slot_num)

		if i == selected_index:
			slot_buttons[i].modulate = COLOR_SELECTED
		elif not info.exists and mode == "load":
			# Empty slots in load mode should be dimmed
			slot_buttons[i].modulate = COLOR_EMPTY
		else:
			slot_buttons[i].modulate = COLOR_NORMAL

	# Update action buttons based on mode
	if mode == "load":
		# Load mode: only main menu button (index 3)
		if selected_index == 3:
			main_menu_button.modulate = COLOR_SELECTED
		else:
			main_menu_button.modulate = COLOR_NORMAL
	else:
		# Save mode: resume (index 3) and main menu (index 4)
		if selected_index == 3:
			resume_button.modulate = COLOR_SELECTED
			main_menu_button.modulate = COLOR_NORMAL
		elif selected_index == 4:
			resume_button.modulate = COLOR_NORMAL
			main_menu_button.modulate = COLOR_SELECTED
		else:
			resume_button.modulate = COLOR_NORMAL
			main_menu_button.modulate = COLOR_NORMAL

func _select_current() -> void:
	if selected_index >= 0 and selected_index <= 2:
		_on_slot_pressed(selected_index + 1)
	elif mode == "load":
		# Load mode: index 3 is main menu
		if selected_index == 3:
			_on_main_menu_pressed()
	else:
		# Save mode: index 3 is resume, index 4 is main menu
		if selected_index == 3:
			_on_resume_pressed()
		elif selected_index == 4:
			_on_main_menu_pressed()

func _refresh_slot_info() -> void:
	for i in range(1, 4):
		var info = SaveManager.get_save_slot_info(i)
		var button = slot_buttons[i - 1]

		if info.exists:
			var time_str = _format_timestamp(info.timestamp)
			var turns_str = "Turn: %d" % info.playtime_turns
			var world_display = info.world_name if not info.world_name.is_empty() else "Unknown World"
			button.text = "Slot %d: %s - %s (%s)" % [i, world_display, time_str, turns_str]
			button.modulate = COLOR_NORMAL
		else:
			button.text = "Slot %d: Empty" % i
			button.modulate = COLOR_EMPTY if mode == "load" else COLOR_NORMAL

func _format_timestamp(timestamp: String) -> String:
	if timestamp == "":
		return "Empty"

	# Parse ISO 8601 format: "2025-12-31T12:34:56"
	var parts = timestamp.split("T")
	if parts.size() < 2:
		return timestamp

	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")

	if date_parts.size() >= 3 and time_parts.size() >= 2:
		return "%s/%s %s:%s" % [date_parts[1], date_parts[2], time_parts[0], time_parts[1]]

	return timestamp

func _on_slot_pressed(slot: int) -> void:
	if mode == "save":
		_save_to_slot(slot)
	else:
		_load_from_slot(slot)

## Show a confirmation dialog for a pending action
func _show_confirm(message: String, action: String, slot: int, positive_text: String = "Delete") -> void:
	if not confirm_dialog:
		return
	# Use the styled dialog's open() method (accept custom positive label)
	if confirm_dialog.has_method("open"):
		confirm_dialog.open(message, positive_text)
	pending_action = action
	pending_slot = slot

## Called when the confirmation dialog is accepted
func _on_confirmed() -> void:
	if pending_action == "save_over":
		var slot = pending_slot
		var success = SaveManager.save_game(slot)
		if success:
			_refresh_slot_info()
			# Auto-close after successful save
			await get_tree().create_timer(0.5).timeout
			_close()
	elif pending_action == "delete":
		var slot = pending_slot
		SaveManager.delete_save(slot)
		_refresh_slot_info()
		_update_button_colors()
	# Clear pending
	pending_action = ""
	pending_slot = -1

func _on_confirm_cancelled() -> void:
	# Clear pending state when user cancels the confirm dialog
	pending_action = ""
	pending_slot = -1

func _save_to_slot(slot: int) -> void:
	var info = SaveManager.get_save_slot_info(slot)
	if info.exists:
		# Prompt for overwrite using the same display format as the slot list
		var time_str = _format_timestamp(info.timestamp)
		var turns_str = "Turn: %d" % info.playtime_turns
		var world_display = info.world_name if not info.world_name.is_empty() else (info.save_name if not info.save_name.is_empty() else "Slot %d" % slot)

		var confirm_text = "%s - %s (%s)" % [world_display, time_str, turns_str]

		_show_confirm("Overwrite save '%s'?\nThis cannot be undone." % confirm_text, "save_over", slot, "Overwrite")
		return

	var success = SaveManager.save_game(slot)
	if success:
		_refresh_slot_info()
		# Auto-close after successful save
		await get_tree().create_timer(0.5).timeout
		_close()

func _load_from_slot(slot: int) -> void:
	var info = SaveManager.get_save_slot_info(slot)
	if not info.exists:
		return  # Can't load empty slot

	# Set flag to prevent new game initialization
	GameManager.is_loading_save = true

	var success = SaveManager.load_game(slot)
	if success:
		_close()
		# Reload game scene
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_resume_pressed() -> void:
	_close()

func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _delete_current_slot() -> void:
	print("[PauseMenu] Delete slot requested, selected_index: %d" % selected_index)

	# Only allow deletion if a save slot is selected (0-2)
	if selected_index < 0 or selected_index > 2:
		print("[PauseMenu] Not a save slot, ignoring delete")
		return

	var slot = selected_index + 1
	var info = SaveManager.get_save_slot_info(slot)

	# Only delete if the slot has a save
	if not info.exists:
		print("[PauseMenu] Slot %d is empty, cannot delete" % slot)
		return

	# Ask for confirmation before deleting
	# Build a display string matching the slot list: "WorldName - MM/DD HH:MM (Turn: N)"
	var time_str = _format_timestamp(info.timestamp)
	var turns_str = "Turn: %d" % info.playtime_turns
	var world_display = info.world_name if not info.world_name.is_empty() else (info.save_name if not info.save_name.is_empty() else "Slot %d" % slot)

	var confirm_text = "%s - %s (%s)" % [world_display, time_str, turns_str]

	_show_confirm("Delete save '%s'?\nThis cannot be undone." % confirm_text, "delete", slot)

## SaveSlotInfo class to hold save slot data
class SaveSlotInfo:
	var slot_number: int = 0
	var exists: bool = false
	var save_name: String = ""
	var world_name: String = ""
	var timestamp: String = ""
	var playtime_turns: int = 0
