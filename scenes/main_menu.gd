extends Control

## MainMenu - Simple main menu scene
##
## Provides options to start a new game or quit.

var buttons: Array = []
var selected_index: int = 0
const SELECT_COLOR: Color = Color(0.6, 0.9, 0.6, 1)
const UNSELECT_COLOR: Color = Color(0.7, 0.7, 0.7, 1)

func _ready() -> void:
	print("Main menu loaded")
	# collect buttons in visual order
	var start = get_node("VBoxContainer/StartButton")
	var quit = get_node("VBoxContainer/QuitButton")
	buttons = [start, quit]

	for i in range(buttons.size()):
		var b = buttons[i]
		b.connect("mouse_entered", Callable(self, "_on_button_mouse_entered").bind(i))

	# default selection to first button (Start a new game)
	selected_index = 0
	update_selection()
	buttons[selected_index].grab_focus()

func _on_button_mouse_entered(idx: int) -> void:
	selected_index = idx
	update_selection()

func update_selection() -> void:
	for i in range(buttons.size()):
		if i == selected_index:
			buttons[i].add_theme_color_override("font_color", SELECT_COLOR)
		else:
			buttons[i].add_theme_color_override("font_color", UNSELECT_COLOR)

func _input(event) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			selected_index = (selected_index - 1) % buttons.size()
			update_selection()
			buttons[selected_index].grab_focus()
		elif event.keycode == KEY_DOWN:
			selected_index = (selected_index + 1) % buttons.size()
			update_selection()
			buttons[selected_index].grab_focus()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			# activate the selected button
			if selected_index >= 0 and selected_index < buttons.size():
				buttons[selected_index].emit_signal("pressed")

func _on_start_button_pressed() -> void:
	print("Starting new game...")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_button_pressed() -> void:
	print("Quitting game...")
	get_tree().quit()
