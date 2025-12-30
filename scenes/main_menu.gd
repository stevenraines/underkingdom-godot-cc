extends Control

## MainMenu - Simple main menu scene
##
## Provides options to start a new game or quit.

func _ready() -> void:
	print("Main menu loaded")

func _on_start_button_pressed() -> void:
	print("Starting new game...")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_button_pressed() -> void:
	print("Quitting game...")
	get_tree().quit()
