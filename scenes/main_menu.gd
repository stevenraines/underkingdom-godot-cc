extends Control

## MainMenu - Simple main menu scene
##
## Provides options to start a new game or quit.

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

var buttons: Array = []
var selected_index: int = 0
const SELECT_COLOR: Color = Color(0.6, 0.9, 0.6, 1)
const UNSELECT_COLOR: Color = Color(0.7, 0.7, 0.7, 1)

func _ready() -> void:
	print("Main menu loaded")
	# Load ASCII art from file into Title RichTextLabel
	var logo_path := "res://ui/underkingdom_logo.txt"
	if FileAccess.file_exists(logo_path):
		var f := FileAccess.open(logo_path, FileAccess.READ)
		if f:
			var txt := f.get_as_text()
			f.close()
			var title: RichTextLabel = $VBoxContainer/Title
			title.text = txt.strip_edges(false, true)
	

	# collect buttons in visual order using @onready references
	buttons = [start_button, load_button, quit_button]

	for i in range(buttons.size()):
		var b = buttons[i]
		if b:
			b.connect("mouse_entered", Callable(self, "_on_button_mouse_entered").bind(i))
			# Disable automatic focus navigation to prevent conflicts
			b.focus_mode = Control.FOCUS_NONE

	# default selection to first button (Start a new game)
	selected_index = 0
	update_selection()

	# Setup world name dialog
	var WorldNameDialogScene = load("res://ui/world_name_dialog.tscn")
	var world_name_dialog = WorldNameDialogScene.instantiate()
	add_child(world_name_dialog)
	world_name_dialog.world_name_entered.connect(_on_world_name_entered)
	world_name_dialog.cancelled.connect(_on_world_name_cancelled)

func _on_button_mouse_entered(idx: int) -> void:
	selected_index = idx
	update_selection()

func update_selection() -> void:
	for i in range(buttons.size()):
		if buttons[i]:  # Null check
			if i == selected_index:
				buttons[i].add_theme_color_override("font_color", SELECT_COLOR)
			else:
				buttons[i].add_theme_color_override("font_color", UNSELECT_COLOR)

func _input(event) -> void:
	# Don't process input if world name dialog is visible
	var dialog = get_node_or_null("WorldNameDialog")
	if dialog and dialog.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			selected_index -= 1
			if selected_index < 0:
				selected_index = buttons.size() - 1
			update_selection()
		elif event.keycode == KEY_DOWN:
			selected_index = (selected_index + 1) % buttons.size()
			update_selection()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			# activate the selected button
			if selected_index >= 0 and selected_index < buttons.size() and buttons[selected_index]:
				buttons[selected_index].emit_signal("pressed")

func _on_start_button_pressed() -> void:
	print("Opening world name dialog...")
	# Open the world name dialog
	var dialog = get_node("WorldNameDialog")
	if dialog:
		dialog.open()

func _on_world_name_entered(world_name: String) -> void:
	print("Starting new game with world name: '%s'..." % world_name)
	print("World name hash: %d" % world_name.hash())
	# Store the world name in GameManager before changing scene
	GameManager.start_new_game(world_name)
	print("After start_new_game - World seed: %d, World name: '%s'" % [GameManager.world_seed, GameManager.world_name])
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_world_name_cancelled() -> void:
	print("World name dialog cancelled")
	# Just return to main menu, nothing to do

func _on_load_button_pressed() -> void:
	print("Opening load game screen...")
	# Create and show the pause menu in load mode
	var PauseMenuScene = load("res://ui/pause_menu.tscn")
	var pause_menu = PauseMenuScene.instantiate()
	add_child(pause_menu)
	pause_menu.open(false)  # false = load mode

func _on_quit_button_pressed() -> void:
	print("Quitting game...")
	get_tree().quit()
