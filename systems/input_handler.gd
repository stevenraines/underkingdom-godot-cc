extends Node

## InputHandler - Convert keyboard input to player actions
##
## Handles input only on player's turn and advances the turn after actions.
## Supports continuous movement while holding WASD/arrow keys.

var player: Player = null
var ui_blocking_input: bool = false  # Set to true when a UI is open that should block game input

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
	
	# Don't process input if player is dead
	if not player.is_alive:
		return
	
	# Don't process movement input if UI is blocking
	if ui_blocking_input:
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
			var action_taken = _try_move_or_attack(direction)
			if action_taken:
				TurnManager.advance_turn()
				blocked_direction = Vector2i.ZERO  # Clear block on successful move/attack
			else:
				# Movement failed (obstacle) - stop continuous movement in this direction
				blocked_direction = direction
			# Use longer delay for initial press, shorter for continuous
			move_timer = initial_delay if is_initial_press else move_delay
			is_initial_press = false
	else:
		# Reset when no movement key is held
		move_timer = 0.0
		is_initial_press = true
		blocked_direction = Vector2i.ZERO  # Clear block when key released

## Try to move or attack in a direction
func _try_move_or_attack(direction: Vector2i) -> bool:
	var target_pos = player.position + direction
	
	# Check for enemy at target position
	var blocking_entity = EntityManager.get_blocking_entity_at(target_pos)
	
	if blocking_entity and blocking_entity is Enemy:
		# Attack the enemy (always consumes turn)
		player.attack(blocking_entity)
		return true
	else:
		# Try to move
		return player.move(direction)

func _unhandled_input(event: InputEvent) -> void:
	if not player or not TurnManager.is_player_turn:
		return

	# Stairs navigation and wait action - check for specific key presses
	if event is InputEventKey and event.pressed and not event.echo:
		var action_taken = false
		
		# Check for > key (descend) - check unicode for web compatibility
		var is_descend_key = (event.keycode == KEY_PERIOD and event.shift_pressed) or event.unicode == 62  # 62 = '>'
		# Check for < key (ascend) - check unicode for web compatibility  
		var is_ascend_key = (event.keycode == KEY_COMMA and event.shift_pressed) or event.unicode == 60  # 60 = '<'
		# Check for . key (wait) - not shifted
		var is_wait_key = (event.keycode == KEY_PERIOD and not event.shift_pressed) or (event.unicode == 46 and not event.shift_pressed)  # 46 = '.'

		if is_descend_key:
			# Descend stairs - only works on stairs_down tiles
			var tile = MapManager.current_map.get_tile(player.position) if MapManager.current_map else null
			if tile and tile.tile_type == "stairs_down":
				MapManager.descend_dungeon()
				player._find_and_move_to_stairs("stairs_up")
				action_taken = true
				get_viewport().set_input_as_handled()
		elif is_ascend_key:
			# Ascend stairs - only works on stairs_up tiles
			var tile = MapManager.current_map.get_tile(player.position) if MapManager.current_map else null
			if tile and tile.tile_type == "stairs_up":
				MapManager.ascend_dungeon()
				player._find_and_move_to_stairs("stairs_down")
				action_taken = true
				get_viewport().set_input_as_handled()
		elif is_wait_key:
			# Wait action - skip turn and get bonus stamina regen
			_do_wait_action()
			action_taken = true
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_I:  # I key - toggle inventory
			_toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_G:  # G key - toggle auto-pickup
			_toggle_auto_pickup()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_COMMA:  # , - manual pickup
			_try_pickup_item()
			action_taken = true
			get_viewport().set_input_as_handled()

		# Advance turn if action was taken
		if action_taken:
			TurnManager.advance_turn()

## Wait action - rest in place for bonus stamina regeneration
func _do_wait_action() -> void:
	if player.survival:
		# Bonus stamina regeneration for waiting (regen twice)
		player.regenerate_stamina()
		player.regenerate_stamina()

## Toggle inventory screen
func _toggle_inventory() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_inventory_screen"):
		game.toggle_inventory_screen()

## Toggle auto-pickup setting
func _toggle_auto_pickup() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_auto_pickup"):
		game.toggle_auto_pickup()

## Try to pick up an item at the player's position
func _try_pickup_item() -> void:
	# Find ground items at player position
	var ground_items = EntityManager.get_ground_items_at(player.position)
	if ground_items.size() > 0:
		var ground_item = ground_items[0]  # Pick up first item
		if player.pickup_item(ground_item):
			EntityManager.remove_entity(ground_item)
