extends Node

## InputHandler - Convert keyboard input to player actions
##
## Handles input only on player's turn and advances the turn after actions.
## Supports continuous movement while holding WASD/arrow keys.

var player: Player = null

# Continuous movement settings
var move_delay: float = 0.12  # Time between moves when holding a key
var initial_delay: float = 0.2  # Longer delay before continuous movement starts
var move_timer: float = 0.0
var is_initial_press: bool = true
var blocked_direction: Vector2i = Vector2i.ZERO  # Stop continuous movement if blocked

func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)

func set_player(p: Player) -> void:
	player = p

func _process(delta: float) -> void:
	if not player or not TurnManager.is_player_turn:
		return

	# Check for held movement keys
	var direction = Vector2i.ZERO

	if Input.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	elif Input.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT

	if direction != Vector2i.ZERO:
		# Don't continue if we're blocked in this direction
		if direction == blocked_direction:
			return

		move_timer -= delta
		if move_timer <= 0.0:
			var action_taken = player.move(direction)
			if action_taken:
				TurnManager.advance_turn()
				blocked_direction = Vector2i.ZERO  # Clear block on successful move
			else:
				# Movement failed (obstacle/enemy) - stop continuous movement in this direction
				blocked_direction = direction
			# Use longer delay for initial press, shorter for continuous
			move_timer = initial_delay if is_initial_press else move_delay
			is_initial_press = false
	else:
		# Reset when no movement key is held
		move_timer = 0.0
		is_initial_press = true
		blocked_direction = Vector2i.ZERO  # Clear block when key released

func _unhandled_input(event: InputEvent) -> void:
	if not player or not TurnManager.is_player_turn:
		return

	# Stairs navigation - check for specific key presses
	if event is InputEventKey and event.pressed and not event.echo:
		var action_taken = false

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
