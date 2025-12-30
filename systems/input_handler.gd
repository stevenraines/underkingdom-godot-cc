extends Node

## InputHandler - Convert keyboard input to player actions
##
## Handles input only on player's turn and advances the turn after actions.

var player: Player = null

func _ready() -> void:
	set_process_unhandled_input(true)

func set_player(p: Player) -> void:
	player = p

func _unhandled_input(event: InputEvent) -> void:
	if not player or not TurnManager.is_player_turn:
		return

	var action_taken = false

	# Movement
	if event.is_action_pressed("ui_up"):
		action_taken = player.move(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		action_taken = player.move(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		action_taken = player.move(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		action_taken = player.move(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()

	# Stairs navigation - check for specific key presses
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PERIOD and event.shift_pressed:  # > key (Shift + .)
			# Descend stairs - only works on stairs_down tiles
			var tile = MapManager.current_map.get_tile(player.position) if MapManager.current_map else null
			if tile and tile.tile_type == "stairs_down":
				MapManager.descend_dungeon()
				player._find_and_move_to_stairs("stairs_up")
				action_taken = true
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_COMMA and event.shift_pressed:  # < key (Shift + ,)
			# Ascend stairs - only works on stairs_up tiles
			var tile = MapManager.current_map.get_tile(player.position) if MapManager.current_map else null
			if tile and tile.tile_type == "stairs_up":
				MapManager.ascend_dungeon()
				player._find_and_move_to_stairs("stairs_down")
				action_taken = true
				get_viewport().set_input_as_handled()

	# Advance turn if action was taken
	if action_taken:
		TurnManager.advance_turn()
