extends Node

## InputHandler - Convert keyboard input to player actions
##
## Handles input only on player's turn and advances the turn after actions.
## Supports continuous movement while holding WASD/arrow keys.

const TargetingSystemClass = preload("res://systems/targeting_system.gd")
const RangedCombatSystemClass = preload("res://systems/ranged_combat_system.gd")
const FishingSystemClass = preload("res://systems/fishing_system.gd")
const FarmingSystemClass = preload("res://systems/farming_system.gd")
const CropEntityClass = preload("res://entities/crop_entity.gd")
const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")
const HarvestSystemClass = preload("res://systems/harvest_system.gd")
const RitualSystemClass = preload("res://systems/ritual_system.gd")

var player: Player = null
var ui_blocking_input: bool = false  # Set to true when a UI is open that should block game input

# Continuous movement settings
var move_delay: float = 0.12  # Time between moves when holding a key
var initial_delay: float = 0.2  # Longer delay before continuous movement starts
var move_timer: float = 0.0
var is_initial_press: bool = true
var blocked_direction: Vector2i = Vector2i.ZERO  # Stop continuous movement if blocked
# Wait (rest) continuous input
var wait_timer: float = 0.0
var is_initial_wait_press: bool = true

# Sprint mode - allows double movement before enemies act
var sprint_mode: bool = false  # Whether sprint is toggled on
var sprint_moves_remaining: int = 0  # Moves left in current sprint (2 per turn when sprinting)
const SPRINT_STAMINA_MULTIPLIER: int = 4  # Stamina cost multiplier when sprinting

# Harvest mode
var _awaiting_harvest_direction: bool = false
var _harvesting_active: bool = false
var _harvest_direction: Vector2i = Vector2i.ZERO
var _harvest_timer: float = 0.0
var _skip_movement_this_frame: bool = false

# Fishing mode
var _awaiting_fishing_direction: bool = false
var _fishing_active: bool = false
var _fishing_direction: Vector2i = Vector2i.ZERO
var _fishing_timer: float = 0.0

# Farming modes
var _awaiting_till_direction: bool = false
var _awaiting_plant_direction: bool = false
var _selected_seed_for_planting: Item = null
var _available_seeds: Array = []
var _current_seed_index: int = 0

# Trap disarm mode
var _awaiting_disarm_trap_direction: bool = false

# Ranged targeting mode
var targeting_system = null  # TargetingSystem instance

# Scroll targeting - track pending scroll for consumption after cast
var pending_scroll: Item = null  # Scroll being used for spell casting

# Wand targeting - track pending wand for charge consumption after cast
var pending_wand: Item = null  # Wand being used for spell casting

# Persistent target tracking (separate from active targeting mode)
var current_target: Entity = null  # Currently selected target for ranged attacks

signal target_changed(target: Entity)  # Emitted when target selection changes

# Look mode - examine visible objects
var look_mode_active: bool = false
var look_objects: Array = []  # Array of visible objects (entities, items, features)
var look_index: int = 0
var current_look_object = null  # Currently looked-at object

signal look_object_changed(obj)  # Emitted when look selection changes

func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(false)  # Start disabled for performance - enabled when player's turn starts
	targeting_system = TargetingSystemClass.new()

	# Connect to scroll and wand targeting signals
	EventBus.scroll_targeting_started.connect(_on_scroll_targeting_started)
	EventBus.wand_targeting_started.connect(_on_wand_targeting_started)
	# Connect to turn signals for performance optimization
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	TurnManager.player_turn_ended.connect(_on_player_turn_ended)

func set_player(p: Player) -> void:
	player = p


## Set UI blocking state and control _process() for performance
func set_ui_blocking(blocking: bool) -> void:
	ui_blocking_input = blocking
	if blocking:
		# UI is open - stop processing input
		set_process(false)
	elif player and player.is_alive and TurnManager.is_player_turn:
		# UI closed, player's turn, and player alive - resume processing
		set_process(true)


func _process(delta: float) -> void:
	if not player or not TurnManager.is_player_turn:
		return

	# Don't process input if player is dead
	if not player.is_alive:
		return

	# Don't process movement input if UI is blocking
	if ui_blocking_input:
		return

	# Skip movement this frame (e.g., after harvest completion to prevent moving into harvested space)
	if _skip_movement_this_frame:
		_skip_movement_this_frame = false
		return

	# If in look mode and player presses movement, exit look mode first
	if look_mode_active:
		var move_dir = Vector2i.ZERO
		if Input.is_action_pressed("ui_up"):
			move_dir = Vector2i.UP
		elif Input.is_action_pressed("ui_down"):
			move_dir = Vector2i.DOWN
		elif Input.is_action_pressed("ui_left"):
			move_dir = Vector2i.LEFT
		elif Input.is_action_pressed("ui_right"):
			move_dir = Vector2i.RIGHT

		if move_dir != Vector2i.ZERO:
			# Exit look mode when player tries to move
			_exit_look_mode()
			var game = get_parent()
			if game and game.has_method("_add_message"):
				game._add_message("Exited look mode.", Color(0.7, 0.7, 0.7))
		return  # Don't process movement this frame after exiting look mode

	# If in targeting mode, don't process movement
	if targeting_system and targeting_system.is_active():
		return

	# Continuous harvesting mode - keep harvesting while holding the direction key
	if _harvesting_active and _harvest_direction != Vector2i.ZERO:
		var still_holding = false
		match _harvest_direction:
			Vector2i.UP:
				still_holding = Input.is_action_pressed("ui_up")
			Vector2i.DOWN:
				still_holding = Input.is_action_pressed("ui_down")
			Vector2i.LEFT:
				still_holding = Input.is_action_pressed("ui_left")
			Vector2i.RIGHT:
				still_holding = Input.is_action_pressed("ui_right")

		if still_holding:
			_harvest_timer -= delta
			if _harvest_timer <= 0.0:
				var harvest_result = _try_harvest(_harvest_direction)
				if harvest_result.success:
					TurnManager.advance_turn()
					# Exit harvest mode if resource is depleted
					if harvest_result.harvest_complete:
						_exit_harvesting_mode()
					else:
						_harvest_timer = move_delay  # Use same timing as continuous movement
				else:
					# Harvest failed (no resource, wrong tool, etc.) - exit harvest mode
					_exit_harvesting_mode()
			return  # Don't process other input while harvesting
		# Note: Don't exit harvest mode when key is released - allow re-pressing
		# Harvest mode will be exited by pressing a different key or ESC

	# Continuous fishing mode - keep fishing while holding the direction key
	if _fishing_active and _fishing_direction != Vector2i.ZERO:
		var still_holding_fish = false
		match _fishing_direction:
			Vector2i.UP:
				still_holding_fish = Input.is_action_pressed("ui_up")
			Vector2i.DOWN:
				still_holding_fish = Input.is_action_pressed("ui_down")
			Vector2i.LEFT:
				still_holding_fish = Input.is_action_pressed("ui_left")
			Vector2i.RIGHT:
				still_holding_fish = Input.is_action_pressed("ui_right")

		if still_holding_fish:
			_fishing_timer -= delta
			if _fishing_timer <= 0.0:
				var fish_result = _try_fish(_fishing_direction)
				if fish_result.success:
					TurnManager.advance_turn()
					# Exit fish mode if session ended
					if fish_result.session_ended:
						_exit_fishing_mode()
					else:
						_fishing_timer = move_delay  # Use same timing as continuous movement
				else:
					# Fish failed - exit fish mode
					_exit_fishing_mode()
			return  # Don't process other input while fishing
		# Note: Don't exit fish mode when key is released - allow re-pressing
		# Fish mode will be exited by pressing a different key or ESC

	# Continuous wait key handling (period key '.')
	# If player holds the '.' key, repeatedly perform wait action with same timing as movement
	var is_wait_pressed = Input.is_key_pressed(KEY_PERIOD) and not Input.is_key_pressed(KEY_SHIFT)
	if is_wait_pressed:
		wait_timer -= delta
		if wait_timer <= 0.0:
			_do_wait_action()
			TurnManager.advance_turn()
			# Use longer delay for initial press, shorter for continuous
			wait_timer = initial_delay if is_initial_wait_press else move_delay
			is_initial_wait_press = false
		# When waiting, skip movement processing this frame
		return
	else:
		# Reset wait state when not pressed
		wait_timer = 0.0
		is_initial_wait_press = true

	# Check for held movement keys
	# Skip movement if Shift is held (Shift+key combos are handled in _unhandled_input)
	var direction = Vector2i.ZERO
	var shift_held = Input.is_key_pressed(KEY_SHIFT)

	if not shift_held:
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
			var result = _try_move_or_attack(direction)
			if result.action_taken:
				if result.advance_turn:
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
## Returns Dictionary with {action_taken: bool, advance_turn: bool}
func _try_move_or_attack(direction: Vector2i) -> Dictionary:
	var target_pos = player.position + direction

	# Check for blocking entity at target position
	var blocking_entity = EntityManager.get_blocking_entity_at(target_pos)

	if blocking_entity and blocking_entity is Enemy:
		# Attack the enemy - this interrupts sprint
		_disable_sprint()
		player.attack(blocking_entity)
		return {"action_taken": true, "advance_turn": true}
	elif blocking_entity and blocking_entity is NPC:
		# Check if NPC is inside their shop (both player and NPC on interior tiles)
		var npc_tile = MapManager.current_map.get_tile(target_pos) if MapManager.current_map else null
		var player_tile = MapManager.current_map.get_tile(player.position) if MapManager.current_map else null

		if npc_tile and npc_tile.is_interior and player_tile and player_tile.is_interior:
			# Both inside building - trigger NPC interaction (interrupts sprint)
			_disable_sprint()
			blocking_entity.interact(player)
			return {"action_taken": true, "advance_turn": true}
		else:
			# Outside shop - show blocked message
			EventBus.message_logged.emit("Your path is blocked by %s." % blocking_entity.name)
			return {"action_taken": false, "advance_turn": false}
	else:
		# Try to move - handle sprint mode
		var moved = _try_move_with_sprint(direction)
		if moved.success:
			return {"action_taken": true, "advance_turn": moved.advance_turn}

		# Movement failed - check if blocked by harvestable resource with appropriate tool
		# Auto-harvest interrupts sprint
		if _try_auto_harvest_on_bump(target_pos, direction):
			_disable_sprint()
			return {"action_taken": true, "advance_turn": true}

		return {"action_taken": false, "advance_turn": false}

## Try to move, handling sprint mode stamina and turn logic
## Returns {success: bool, advance_turn: bool}
func _try_move_with_sprint(direction: Vector2i) -> Dictionary:
	# Calculate stamina cost - 4x when sprinting
	var stamina_cost = player.survival.STAMINA_COST_MOVE if player.survival else 1
	if sprint_mode:
		stamina_cost *= SPRINT_STAMINA_MULTIPLIER

	# Consume extra stamina before moving if sprinting
	if sprint_mode and player.survival:
		# Consume the extra stamina (3x more, since move() consumes 1x)
		var extra_cost = stamina_cost - player.survival.STAMINA_COST_MOVE
		if extra_cost > 0:
			player.survival.consume_stamina(extra_cost)

	# Try the actual move
	var moved = player.move(direction)
	if not moved:
		return {"success": false, "advance_turn": false}

	# Movement succeeded
	if sprint_mode:
		sprint_moves_remaining -= 1
		# Only advance turn after both sprint moves (or if counter reaches 0)
		if sprint_moves_remaining <= 0:
			sprint_moves_remaining = 2  # Reset for next turn
			return {"success": true, "advance_turn": true}
		else:
			# First sprint move - don't advance turn yet
			return {"success": true, "advance_turn": false}
	else:
		# Normal movement - always advance turn
		return {"success": true, "advance_turn": true}

func _unhandled_input(event: InputEvent) -> void:
	if not player or not TurnManager.is_player_turn:
		return

	# If in targeting mode, handle targeting input
	if targeting_system and targeting_system.is_active() and event is InputEventKey and event.pressed and not event.echo:
		_handle_targeting_input(event)
		return

	# If in look mode, handle look input
	if look_mode_active and event is InputEventKey and event.pressed and not event.echo:
		_handle_look_input(event)
		return

	# If awaiting disarm trap direction, handle directional input
	if _awaiting_disarm_trap_direction and event is InputEventKey and event.pressed and not event.echo:
		var direction = Vector2i.ZERO

		match event.keycode:
			KEY_UP, KEY_W:
				direction = Vector2i.UP
			KEY_DOWN, KEY_S:
				direction = Vector2i.DOWN
			KEY_LEFT, KEY_A:
				direction = Vector2i.LEFT
			KEY_RIGHT, KEY_D:
				direction = Vector2i.RIGHT
			KEY_ESCAPE:
				_awaiting_disarm_trap_direction = false
				set_ui_blocking(false)
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("Cancelled disarm", Color(0.7, 0.7, 0.7))
				get_viewport().set_input_as_handled()
				return

		if direction != Vector2i.ZERO:
			_awaiting_disarm_trap_direction = false
			set_ui_blocking(false)
			get_viewport().set_input_as_handled()
			var target_pos = player.position + direction
			if HazardManager.has_visible_hazard(target_pos):
				_try_disarm_trap_at(target_pos)
			else:
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("There's no visible trap in that direction.", Color(0.7, 0.7, 0.7))
			return

	# If awaiting harvest direction, handle directional input
	if _awaiting_harvest_direction and event is InputEventKey and event.pressed and not event.echo:
		var direction = Vector2i.ZERO

		match event.keycode:
			KEY_UP, KEY_W:
				direction = Vector2i.UP
			KEY_DOWN, KEY_S:
				direction = Vector2i.DOWN
			KEY_LEFT, KEY_A:
				direction = Vector2i.LEFT
			KEY_RIGHT, KEY_D:
				direction = Vector2i.RIGHT
			KEY_ESCAPE:
				# Cancel harvest
				_awaiting_harvest_direction = false
				set_ui_blocking(false)
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("Cancelled harvest", Color(0.7, 0.7, 0.7))
				get_viewport().set_input_as_handled()
				return

		if direction != Vector2i.ZERO:
			_awaiting_harvest_direction = false
			set_ui_blocking(false)
			get_viewport().set_input_as_handled()  # Consume input BEFORE processing

			# Reset movement timer to prevent immediate movement after harvest
			move_timer = initial_delay
			is_initial_press = true

			var harvest_result = _try_harvest(direction)
			if harvest_result.success:
				TurnManager.advance_turn()
				# Only enter continuous harvesting mode if harvest is still in progress
				if not harvest_result.harvest_complete:
					_harvesting_active = true
					_harvest_direction = direction
					_harvest_timer = initial_delay  # Use initial delay before next harvest
					EventBus.harvesting_mode_changed.emit(true)
			return

	# If in continuous harvesting mode, handle direction key presses and ESC
	if _harvesting_active and event is InputEventKey and event.pressed and not event.echo:
		var pressed_direction = Vector2i.ZERO
		match event.keycode:
			KEY_UP, KEY_W:
				pressed_direction = Vector2i.UP
			KEY_DOWN, KEY_S:
				pressed_direction = Vector2i.DOWN
			KEY_LEFT, KEY_A:
				pressed_direction = Vector2i.LEFT
			KEY_RIGHT, KEY_D:
				pressed_direction = Vector2i.RIGHT
			KEY_ESCAPE:
				# Cancel harvesting mode
				_exit_harvesting_mode()
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("Stopped harvesting", Color(0.7, 0.7, 0.7))
				get_viewport().set_input_as_handled()
				return

		if pressed_direction != Vector2i.ZERO:
			if pressed_direction == _harvest_direction:
				# Same direction - perform another harvest
				var harvest_result = _try_harvest(_harvest_direction)
				if harvest_result.success:
					TurnManager.advance_turn()
					# Exit harvest mode if resource is depleted
					if harvest_result.harvest_complete:
						_exit_harvesting_mode()
					else:
						_harvest_timer = initial_delay  # Reset timer for next auto-harvest
				else:
					# Harvest failed - exit harvest mode
					_exit_harvesting_mode()
				get_viewport().set_input_as_handled()
				return
			else:
				# Different direction pressed - exit harvest mode and process normally
				_exit_harvesting_mode()
				# Don't return - let normal input processing handle the movement

	# If awaiting fishing direction, handle directional input
	if _awaiting_fishing_direction and event is InputEventKey and event.pressed and not event.echo:
		var direction = Vector2i.ZERO

		match event.keycode:
			KEY_UP, KEY_W:
				direction = Vector2i.UP
			KEY_DOWN, KEY_S:
				direction = Vector2i.DOWN
			KEY_LEFT, KEY_A:
				direction = Vector2i.LEFT
			KEY_RIGHT, KEY_D:
				direction = Vector2i.RIGHT
			KEY_ESCAPE:
				# Cancel fishing
				_awaiting_fishing_direction = false
				set_ui_blocking(false)
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("Cancelled fishing", Color(0.7, 0.7, 0.7))
				get_viewport().set_input_as_handled()
				return

		if direction != Vector2i.ZERO:
			_awaiting_fishing_direction = false
			set_ui_blocking(false)
			get_viewport().set_input_as_handled()  # Consume input BEFORE processing

			# Reset movement timer to prevent immediate movement after fishing
			move_timer = initial_delay
			is_initial_press = true

			var fish_result = _try_fish(direction)
			if fish_result.success:
				TurnManager.advance_turn()
				# Only enter continuous fishing mode if session is still active
				if not fish_result.session_ended:
					_fishing_active = true
					_fishing_direction = direction
					_fishing_timer = initial_delay  # Use initial delay before next fish attempt
			return

	# If in continuous fishing mode, handle direction key presses and ESC
	if _fishing_active and event is InputEventKey and event.pressed and not event.echo:
		var pressed_direction = Vector2i.ZERO
		match event.keycode:
			KEY_UP, KEY_W:
				pressed_direction = Vector2i.UP
			KEY_DOWN, KEY_S:
				pressed_direction = Vector2i.DOWN
			KEY_LEFT, KEY_A:
				pressed_direction = Vector2i.LEFT
			KEY_RIGHT, KEY_D:
				pressed_direction = Vector2i.RIGHT
			KEY_ESCAPE:
				# Cancel fishing mode
				_exit_fishing_mode()
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("Stopped fishing", Color(0.7, 0.7, 0.7))
				get_viewport().set_input_as_handled()
				return

		if pressed_direction != Vector2i.ZERO:
			if pressed_direction == _fishing_direction:
				# Same direction - perform another fish attempt
				var fish_result = _try_fish(_fishing_direction)
				if fish_result.success:
					TurnManager.advance_turn()
					# Exit fish mode if session ended
					if fish_result.session_ended:
						_exit_fishing_mode()
					else:
						_fishing_timer = initial_delay  # Reset timer for next auto-fish
				else:
					# Fish failed - exit fish mode
					_exit_fishing_mode()
				get_viewport().set_input_as_handled()
				return
			else:
				# Different direction pressed - exit fish mode and process normally
				_exit_fishing_mode()
				# Don't return - let normal input processing handle the movement

	# If awaiting till direction, handle directional input
	if _awaiting_till_direction and event is InputEventKey and event.pressed and not event.echo:
		var direction = Vector2i.ZERO

		match event.keycode:
			KEY_UP, KEY_W:
				direction = Vector2i.UP
			KEY_DOWN, KEY_S:
				direction = Vector2i.DOWN
			KEY_LEFT, KEY_A:
				direction = Vector2i.LEFT
			KEY_RIGHT, KEY_D:
				direction = Vector2i.RIGHT
			KEY_ESCAPE:
				# Cancel till
				_exit_till_mode()
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("Cancelled tilling", Color(0.7, 0.7, 0.7))
				get_viewport().set_input_as_handled()
				return

		if direction != Vector2i.ZERO:
			_exit_till_mode()
			get_viewport().set_input_as_handled()

			# Reset movement timer to prevent immediate movement after tilling
			move_timer = initial_delay
			is_initial_press = true

			var success = _try_till(direction)
			if success:
				TurnManager.advance_turn()
			return

	# If awaiting plant direction, handle directional input
	if _awaiting_plant_direction and event is InputEventKey and event.pressed and not event.echo:
		var direction = Vector2i.ZERO

		match event.keycode:
			KEY_UP, KEY_W:
				direction = Vector2i.UP
			KEY_DOWN, KEY_S:
				direction = Vector2i.DOWN
			KEY_LEFT, KEY_A:
				direction = Vector2i.LEFT
			KEY_RIGHT, KEY_D:
				direction = Vector2i.RIGHT
			KEY_ESCAPE:
				# Cancel plant
				_exit_plant_mode()
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("Cancelled planting", Color(0.7, 0.7, 0.7))
				get_viewport().set_input_as_handled()
				return

		if direction != Vector2i.ZERO:
			get_viewport().set_input_as_handled()

			# Reset movement timer to prevent immediate movement after planting
			move_timer = initial_delay
			is_initial_press = true

			# Try to plant BEFORE exiting plant mode (which clears the selected seed)
			var success = _try_plant(direction)
			_exit_plant_mode()
			if success:
				TurnManager.advance_turn()
			return

	# Stairs navigation - check for specific key presses
	# Note: Wait action (. key) is handled in _process() for proper timing with held keys
	if event is InputEventKey and event.pressed and not event.echo:
		var action_taken = false

		# Check for > key (descend) - check unicode for web compatibility
		var is_descend_key = (event.keycode == KEY_PERIOD and event.shift_pressed) or event.unicode == 62  # 62 = '>'
		# Check for < key (ascend) - check unicode for web compatibility
		var is_ascend_key = (event.keycode == KEY_COMMA and event.shift_pressed) or event.unicode == 60  # 60 = '<'

		if is_descend_key:
			# Descend stairs - works on stairs_down tiles AND dungeon_entrance tiles
			var tile = MapManager.current_map.get_tile(player.position) if MapManager.current_map else null
			if tile:
				if tile.tile_type == "dungeon_entrance":
					# Enter a dungeon from overworld entrance
					var dungeon_type = tile.get_meta("dungeon_type", "burial_barrow")
					var dungeon_name = tile.get_meta("dungeon_name", "Unknown Dungeon")
					# Save overworld position before entering
					if MapManager.current_map.chunk_based:
						GameManager.last_overworld_position = player.position
					# Save entity states before leaving this map
					EntityManager.save_entity_states_to_map(MapManager.current_map)
					print("[InputHandler] Entering %s (%s)" % [dungeon_name, dungeon_type])
					MapManager.enter_dungeon(dungeon_type)
					player._find_and_move_to_stairs("stairs_up")
					action_taken = true
					get_viewport().set_input_as_handled()
				elif tile.tile_type == "stairs_down":
					# Descend to next floor within a dungeon
					# Save entity states before leaving this map
					EntityManager.save_entity_states_to_map(MapManager.current_map)
					MapManager.descend_dungeon()
					player._find_and_move_to_stairs("stairs_up")
					action_taken = true
					get_viewport().set_input_as_handled()
		elif is_ascend_key:
			# Ascend stairs - only works on stairs_up tiles
			var tile = MapManager.current_map.get_tile(player.position) if MapManager.current_map else null
			print("[InputHandler] Ascend key pressed. Player pos: %s, Tile type: %s" % [player.position, tile.tile_type if tile else "null"])
			if tile and tile.tile_type == "stairs_up":
				print("[InputHandler] On stairs_up tile, current floor: %d" % MapManager.current_dungeon_floor)
				# Save entity states before leaving this map
				EntityManager.save_entity_states_to_map(MapManager.current_map)
				# Check if we're going to overworld (floor 1 -> overworld) or to previous floor
				if MapManager.current_dungeon_floor == 1:
					# Returning to overworld - set position before transition
					var target_pos = GameManager.last_overworld_position if GameManager.last_overworld_position != Vector2i.ZERO else Vector2i(800, 800)
					print("[InputHandler] Returning to overworld at position: %s" % target_pos)
					player.position = target_pos
					MapManager.ascend_dungeon()
				else:
					# Going to previous dungeon floor - find stairs_down after transition
					MapManager.ascend_dungeon()
					player._find_and_move_to_stairs("stairs_down")
				action_taken = true
				get_viewport().set_input_as_handled()
			else:
				print("[InputHandler] Not on stairs_up tile - cannot ascend")
		elif event.keycode == KEY_I:  # I key - toggle inventory
			_toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:  # C key - open crafting
			_open_crafting()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B:  # B key - toggle build mode
			_toggle_build_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E:  # E key - interact with structure
			_interact_with_structure()
			action_taken = true
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_G:  # G key - toggle auto-pickup
			_toggle_auto_pickup()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_O:  # O key - toggle auto-open doors
			_toggle_auto_open_doors()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_S and event.shift_pressed:  # Shift+S - toggle sprint mode
			_toggle_sprint()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_COMMA:  # , - manual pickup
			_try_pickup_item()
			action_taken = true
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_T and event.shift_pressed:  # Shift+T - till soil
			_start_till_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_T and not event.shift_pressed:  # T - talk/interact with NPC
			_try_interact_npc()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M and event.shift_pressed:  # Shift+M - toggle spellbook
			_toggle_spell_list()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_K and event.shift_pressed:  # Shift+K - ritual menu
			_toggle_ritual_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_K and not event.shift_pressed:  # K - open spell casting (alias for spellbook)
			_toggle_spell_list()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_A:  # A - toggle special actions (class feats + racial traits)
			_toggle_special_actions()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M and not event.shift_pressed:  # M - toggle world map
			_toggle_world_map()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_H:  # H key - harvest (prompts for direction)
			_start_harvest_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:  # F key - fish or interact with dungeon feature
			# Check if adjacent to water for fishing
			if FishingSystemClass.is_adjacent_to_water(player):
				_start_fishing_mode()
			else:
				action_taken = _try_interact_feature()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P and event.shift_pressed:  # Shift+P - plant seeds
			_start_plant_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P and not event.shift_pressed:  # P key - character sheet
			_open_character_sheet()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1 or (event.keycode == KEY_SLASH and event.shift_pressed) or event.unicode == 63:  # F1 or ? (Shift+/ or unicode 63) - help screen
			_open_help_screen()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F12:  # F12 - debug command menu
			_toggle_debug_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:  # Tab key - cycle targets
			_cycle_target()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and event.shift_pressed:  # Shift+R - open rest menu
			_open_rest_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and not event.shift_pressed:  # R key - ranged attack / fire at current target
			_fire_at_target()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_L:  # L key - enter look mode
			_start_look_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:  # Z key - fast travel
			_toggle_fast_travel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_U:  # U key - clear/untarget current target
			_untarget()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_X:  # X key - toggle door (open/close)
			action_taken = _try_toggle_door()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_N and event.shift_pressed:  # Shift+N - disarm trap
			_start_disarm_trap_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_N and not event.shift_pressed:  # N key - search for traps
			_start_detect_trap_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:  # Y key - pick/lock a lock
			action_taken = _try_lockpick()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:  # Q key - toggle light source (light/extinguish)
			_try_toggle_light()
			get_viewport().set_input_as_handled()

		# Advance turn if action was taken
		if action_taken:
			TurnManager.advance_turn()

## Try to toggle an adjacent door (open if closed, close if open)
func _try_toggle_door() -> bool:
	if not player:
		return false
	return player.try_toggle_adjacent_door()

## Try to pick/lock an adjacent door or container
func _try_lockpick() -> bool:
	const LockSystemClass = preload("res://systems/lock_system.gd")
	var game = get_parent()

	if not player:
		return false

	# Check adjacent doors first
	var directions = [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(1, 0)
	]

	for dir in directions:
		var pos = player.position + dir
		var tile = MapManager.current_map.get_tile(pos) if MapManager.current_map else null

		if tile and tile.tile_type == "door":
			if tile.is_locked:
				# Try to pick the lock
				var result = LockSystemClass.try_pick_lock(tile.lock_level, player)
				if result.success:
					tile.unlock()
					EventBus.lock_picked.emit(pos, true)
					# Also open the door
					tile.open_door()
					_emit_fov_invalidate()
					EventBus.tile_changed.emit(pos)
				else:
					EventBus.lock_picked.emit(pos, false)
					if result.lockpick_broken:
						EventBus.lockpick_broken.emit(pos)
				if game and game.has_method("_add_message"):
					var color = Color.GREEN if result.success else Color.ORANGE_RED
					game._add_message(result.message, color)
				return true
			elif not tile.is_open:
				# Try to lock an unlocked closed door
				var result = LockSystemClass.try_lock_with_pick(tile.lock_level, player)
				if result.success:
					tile.lock()
				if game and game.has_method("_add_message"):
					var color = Color.GREEN if result.success else Color.ORANGE_RED
					game._add_message(result.message, color)
				return true

	# Check for features at player position or adjacent
	for dir in [Vector2i.ZERO] + directions:
		var pos = player.position + dir
		if FeatureManager.has_interactable_feature(pos):
			if FeatureManager.is_feature_locked(pos):
				# Try to pick a locked feature
				var result = FeatureManager.try_pick_feature_lock(pos, player)
				if game and game.has_method("_add_message"):
					var color = Color.GREEN if result.success else Color.ORANGE_RED
					game._add_message(result.message, color)
				return true
			else:
				# Try to re-lock an unlocked feature
				var result = FeatureManager.try_lock_feature(pos, player)
				if result.success or result.get("lockpick_broken", false):
					if game and game.has_method("_add_message"):
						var color = Color.GREEN if result.success else Color.ORANGE_RED
						game._add_message(result.message, color)
					return true

	if game and game.has_method("_add_message"):
		game._add_message("Nothing to pick here.", Color.GRAY)
	return false

## Emit FOV invalidation
func _emit_fov_invalidate() -> void:
	const FOVSystemClass = preload("res://systems/fov_system.gd")
	FOVSystemClass.invalidate_cache()

## Toggle an equipped light source (light if unlit, extinguish if lit)
func _try_toggle_light() -> void:
	var game = get_parent()
	if not player or not player.inventory:
		return

	# Check equipped slots for burnable light sources
	for slot in ["main_hand", "off_hand"]:
		var item = player.inventory.get_equipped(slot)
		if item and item.provides_light and item.burns_per_turn > 0:
			if item.is_lit:
				# Extinguish it
				item.is_lit = false
				if game and game.has_method("_add_message"):
					game._add_message("You extinguish the %s." % item.name, Color(0.6, 0.6, 0.6))
			else:
				# Light it
				item.is_lit = true
				if game and game.has_method("_add_message"):
					game._add_message("You light the %s." % item.name, Color(1.0, 0.8, 0.4))
			# Update visibility and HUD
			if game and game.render_orchestrator:
				game.render_orchestrator.update_visibility()
			if game and game.has_method("_update_hud"):
				game._update_hud()
			return

	# No light source found
	if game and game.has_method("_add_message"):
		game._add_message("You have no light source to light or extinguish.", Color.GRAY)

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

## Open crafting screen
func _open_crafting() -> void:
	var game = get_parent()
	if game and game.has_method("open_crafting_screen"):
		game.open_crafting_screen()

## Toggle build mode
func _toggle_build_mode() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_build_mode"):
		game.toggle_build_mode()

## Toggle world map screen
func _toggle_world_map() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_world_map"):
		game.toggle_world_map()

## Toggle spell list screen
func _toggle_spell_list() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_spell_list"):
		game.toggle_spell_list()

## Toggle ritual menu screen
func _toggle_ritual_menu() -> void:
	var game = get_parent()

	# Check if player is currently channeling a ritual
	if RitualSystemClass.is_channeling():
		if game and game.has_method("_add_message"):
			var progress = RitualSystemClass.get_channeling_progress()
			var ritual = progress.get("ritual")
			var remaining = progress.get("remaining", 0)
			game._add_message("Currently channeling %s... %d turns remaining. Wait or move to interrupt." % [ritual.name if ritual else "ritual", remaining], Color.MAGENTA)
		return

	# Check if player has the INT requirement for rituals (minimum 8)
	if player and player.get_effective_attribute("INT") < 8:
		if game and game.has_method("_add_message"):
			game._add_message("You lack the intelligence to perform rituals. (Requires 8 INT)", Color(0.9, 0.6, 0.4))
		return

	# Emit the ritual menu requested signal
	EventBus.ritual_menu_requested.emit()

## Toggle special actions screen
func _toggle_special_actions() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_special_actions"):
		game.toggle_special_actions()

## Interact with structure at player position
func _interact_with_structure() -> void:
	# Find structures at player position
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_at(player.position, map_id)

	if structures.size() > 0:
		var structure = structures[0]
		var result = structure.interact(player)

		if result.success:
			var game = get_parent()
			if not game:
				return

			match result.action:
				"open_container":
					if game.has_method("open_container_screen"):
						game.open_container_screen(structure)
				"toggle_fire":
					if game.has_method("_add_message"):
						game._add_message(result.message, Color(0.9, 0.7, 0.4))
					EventBus.fire_toggled.emit(structure, structure.is_active)

## Toggle auto-pickup setting
func _toggle_auto_pickup() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_auto_pickup"):
		game.toggle_auto_pickup()

## Toggle auto-open doors setting
func _toggle_auto_open_doors() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_auto_open_doors"):
		game.toggle_auto_open_doors()

## Toggle sprint mode on/off
func _toggle_sprint() -> void:
	sprint_mode = not sprint_mode
	var game = get_parent()

	if sprint_mode:
		# Start sprinting - set up for double moves
		sprint_moves_remaining = 2
		if game and game.has_method("_add_message"):
			game._add_message("Sprint mode ON - move twice per turn (4x stamina)", Color(0.9, 0.8, 0.3))
	else:
		# Stop sprinting
		sprint_moves_remaining = 0
		if game and game.has_method("_add_message"):
			game._add_message("Sprint mode OFF", Color(0.7, 0.7, 0.7))

	EventBus.sprint_mode_changed.emit(sprint_mode)

## Check if currently sprinting (for status bar)
func is_sprinting() -> bool:
	return sprint_mode

## Disable sprint mode (called when non-move action is taken)
func _disable_sprint() -> void:
	if sprint_mode:
		sprint_mode = false
		sprint_moves_remaining = 0
		var game = get_parent()
		if game and game.has_method("_add_message"):
			game._add_message("Sprint interrupted", Color(0.7, 0.7, 0.7))
		EventBus.sprint_mode_changed.emit(false)

## Try to pick up an item at the player's position
func _try_pickup_item() -> void:
	# Find ground items at player position
	var ground_items = EntityManager.get_ground_items_at(player.position)
	if ground_items.size() > 0:
		var ground_item = ground_items[0]  # Pick up first item
		if player.pickup_item(ground_item):
			EntityManager.remove_entity(ground_item)
		else:
			# Pickup failed - provide feedback
			var game = get_parent()
			if game and game.has_method("_add_message") and ground_item and ground_item.item:
				game._add_message("Cannot pick up %s (inventory full or too heavy)" % ground_item.item.name, Color(0.9, 0.6, 0.4))
	else:
		# No items at position
		var game = get_parent()
		if game and game.has_method("_add_message"):
			game._add_message("No items here to pick up.", Color(0.7, 0.7, 0.7))

## Try to interact with an adjacent NPC
func _try_interact_npc() -> void:
	# Check all 8 adjacent positions for NPCs
	var adjacent_positions = [
		player.position + Vector2i(-1, -1), player.position + Vector2i(0, -1), player.position + Vector2i(1, -1),
		player.position + Vector2i(-1, 0),                                       player.position + Vector2i(1, 0),
		player.position + Vector2i(-1, 1),  player.position + Vector2i(0, 1),  player.position + Vector2i(1, 1)
	]

	# Find NPCs in adjacent positions
	var nearby_npcs = []
	for pos in adjacent_positions:
		var entity = EntityManager.get_blocking_entity_at(pos)
		if entity and entity is NPC:
			nearby_npcs.append(entity)

	# Interact with the first NPC found
	if nearby_npcs.size() > 0:
		nearby_npcs[0].interact(player)
	else:
		EventBus.emit_signal("message_logged", "There's nobody here to talk to.")

## Start harvest mode - player will be prompted for direction
## If standing on a harvestable feature (flora), gather it directly
func _start_harvest_mode() -> void:
	var game = get_parent()

	# First check if there's a harvestable feature at the player's position
	if FeatureManager.has_interactable_feature(player.position):
		var feature = FeatureManager.get_feature_at(player.position)
		var feature_def = feature.get("definition", {})
		if feature_def.get("harvestable", false):
			# Gather the feature directly
			var result = player.interact_with_feature()
			if result.get("success", false):
				TurnManager.advance_turn()
				if game and game.render_orchestrator:
					game.render_orchestrator.render_all_entities()
				if game and game.render_orchestrator:
					game.render_orchestrator.update_visibility()
			return

	# No feature at position, prompt for harvest direction (for trees, rocks, etc.)
	if game and game.has_method("_add_message"):
		game._add_message("Harvest which direction? (Arrow keys or WASD)", Color(1.0, 1.0, 0.6))

	# Set a flag to await direction input
	set_ui_blocking(true)
	_awaiting_harvest_direction = true

## Exit continuous harvesting mode
func _exit_harvesting_mode() -> void:
	if _harvesting_active:
		_harvesting_active = false
		_harvest_direction = Vector2i.ZERO
		_harvest_timer = 0.0
		_skip_movement_this_frame = true  # Prevent moving into harvested space
		# Reset movement timer to prevent immediate movement when key is held
		move_timer = initial_delay
		is_initial_press = true
		EventBus.harvesting_mode_changed.emit(false)

## Check if currently in harvesting mode (for status bar)
func is_harvesting() -> bool:
	return _harvesting_active

## Try to auto-harvest when player bumps into a harvestable tile
## Returns true if harvesting was started, false otherwise
func _try_auto_harvest_on_bump(target_pos: Vector2i, direction: Vector2i) -> bool:
	if not MapManager.current_map:
		return false

	var tile = MapManager.current_map.get_tile(target_pos)
	if not tile or tile.harvestable_resource_id.is_empty():
		return false

	# Get the resource definition
	var resource = HarvestSystemClass.get_resource(tile.harvestable_resource_id)
	if not resource:
		return false

	# Check if player has the required tool
	var tool_check = HarvestSystemClass.has_required_tool(player, resource)
	if not tool_check.has_tool:
		return false

	# Player has the right tool - start harvesting automatically
	var game = get_parent()
	if game and game.has_method("_add_message"):
		game._add_message("Auto-harvesting %s..." % resource.name, Color(0.6, 0.8, 0.6))

	var harvest_result = _try_harvest(direction)
	if harvest_result.success:
		TurnManager.advance_turn()
		# Enter continuous harvesting mode if harvest is still in progress
		if not harvest_result.harvest_complete:
			_harvesting_active = true
			_harvest_direction = direction
			_harvest_timer = initial_delay
			EventBus.harvesting_mode_changed.emit(true)
		return true

	return false

## Search for traps in all directions around player
## Range is 2 + traps skill
func _start_detect_trap_mode() -> void:
	var game = get_parent()

	# Calculate detection range: base 2 + traps skill
	var traps_skill = player.skills.get("traps", 0)
	var detection_range = 2 + traps_skill

	# Calculate D&D-style modifiers
	var wis = player.get_effective_attribute("WIS") if player.has_method("get_effective_attribute") else player.attributes.get("WIS", 10)
	var wis_modifier: int = int((wis - 10) / 2.0)  # D&D-style: (ability - 10) / 2
	var active_search_bonus: int = 5  # Bonus for actively searching vs passive detection

	# Add racial trap detection bonus (e.g., Elf Keen Senses)
	if "trap_detection_bonus" in player:
		active_search_bonus += player.trap_detection_bonus

	# Search all tiles within range
	var detected_traps: Array[String] = []
	var detected_positions: Array[Vector2i] = []
	var sensed_count: int = 0

	for dx in range(-detection_range, detection_range + 1):
		for dy in range(-detection_range, detection_range + 1):
			# Skip player's own tile
			if dx == 0 and dy == 0:
				continue

			# Check if within circular range (Chebyshev distance)
			if max(abs(dx), abs(dy)) > detection_range:
				continue

			var target_pos = player.position + Vector2i(dx, dy)
			var result = HazardManager.try_active_detect_hazard(target_pos, wis_modifier, traps_skill, active_search_bonus)

			if result.detected:
				detected_traps.append(result.hazard_name)
				detected_positions.append(target_pos)
			elif result.hazard_name != "":
				# Found a trap but failed the check
				sensed_count += 1

	# Report results
	if game and game.has_method("_add_message"):
		if detected_traps.size() > 0:
			var trap_list = ", ".join(detected_traps)
			game._add_message("You discover: %s!" % trap_list, Color(0.6, 1.0, 0.6))
			# Render only the newly detected hazards (not all hazards on map)
			if game.render_orchestrator:
				for trap_pos in detected_positions:
					game.render_orchestrator.render_hazard_at(trap_pos)
		elif sensed_count > 0:
			game._add_message("You sense something nearby, but can't pinpoint it...", Color(1.0, 0.8, 0.5))
		else:
			game._add_message("You find nothing suspicious nearby.", Color(0.7, 0.7, 0.7))

	# This action costs a turn
	TurnManager.advance_turn()

## Start disarm trap mode - check current position or prompt for direction
func _start_disarm_trap_mode() -> void:
	var game = get_parent()

	# First check if there's a visible trap at player's current position
	var current_pos = player.position
	if HazardManager.has_visible_hazard(current_pos):
		_try_disarm_trap_at(current_pos)
		return

	# Check adjacent positions for visible traps
	var adjacent_traps: Array[Vector2i] = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var check_pos = current_pos + dir
		if HazardManager.has_visible_hazard(check_pos):
			adjacent_traps.append(check_pos)

	if adjacent_traps.size() == 1:
		# Only one adjacent trap - disarm it directly
		_try_disarm_trap_at(adjacent_traps[0])
		return
	elif adjacent_traps.size() > 1:
		# Multiple adjacent traps - prompt for direction
		if game and game.has_method("_add_message"):
			game._add_message("Disarm trap in which direction? (Arrow keys or WASD)", Color(1.0, 0.6, 0.6))
		set_ui_blocking(true)
		_awaiting_disarm_trap_direction = true
		return

	# No visible traps nearby
	if game and game.has_method("_add_message"):
		game._add_message("There are no visible traps nearby to disarm.", Color(0.7, 0.7, 0.7))

## Try to disarm a trap at the given position
func _try_disarm_trap_at(pos: Vector2i) -> void:
	var game = get_parent()

	var result = HazardManager.try_disarm_hazard_with_player(pos, player)

	if game and game.has_method("_add_message"):
		var color = Color(0.6, 1.0, 0.6) if result.success else Color(1.0, 0.5, 0.5)
		game._add_message(result.message, color)

	# Refresh hazard rendering to show grey disarmed trap (only at this position)
	if result.success and game.render_orchestrator:
		game.render_orchestrator.render_hazard_at(pos)

	# If disarm failed and triggered the trap, apply damage
	if result.get("triggered", false):
		var hazard_result = HazardManager.check_hazard_trigger(pos, player)
		if hazard_result.get("triggered", false):
			player._apply_hazard_damage(hazard_result)

	# This action costs a turn
	TurnManager.advance_turn()

## Start fishing mode - player will be prompted for direction
func _start_fishing_mode() -> void:
	var game = get_parent()
	if game and game.has_method("_add_message"):
		game._add_message("Fish which direction? (Arrow keys or WASD)", Color(0.6, 0.8, 1.0))

	# Set a flag to await direction input
	set_ui_blocking(true)
	_awaiting_fishing_direction = true

## Exit continuous fishing mode
func _exit_fishing_mode() -> void:
	if _fishing_active:
		_fishing_active = false
		_fishing_direction = Vector2i.ZERO
		_fishing_timer = 0.0
		_skip_movement_this_frame = true
		# Reset movement timer to prevent immediate movement when key is held
		move_timer = initial_delay
		is_initial_press = true
		FishingSystemClass.cancel_session(player)

## Check if currently in fishing mode (for status bar)
func is_fishing() -> bool:
	return _fishing_active

## Try to fish in a direction
## Returns: {success: bool, session_ended: bool}
func _try_fish(direction: Vector2i) -> Dictionary:
	var result = FishingSystemClass.fish(player, direction)

	var game = get_parent()
	if game and game.has_method("_add_message"):
		var color = Color(0.6, 0.9, 0.6) if result.success else Color(0.9, 0.5, 0.5)
		if result.get("bait_lost", false):
			color = Color(0.9, 0.7, 0.4)  # Orange for bait loss
		game._add_message(result.message, color)

	return {"success": result.success, "session_ended": result.get("session_ended", false)}

## Open character sheet
func _open_character_sheet() -> void:
	print("[InputHandler] Opening character sheet")
	var game = get_parent()
	if game and game.has_method("open_character_sheet"):
		game.open_character_sheet()
	else:
		print("[InputHandler] ERROR: game or open_character_sheet method not found")

## Open help screen
func _open_help_screen() -> void:
	print("[InputHandler] Opening help screen")
	var game = get_parent()
	if game and game.has_method("open_help_screen"):
		game.open_help_screen()
	else:
		print("[InputHandler] ERROR: game or open_help_screen method not found")

## Toggle debug command menu (F12)
func _toggle_debug_menu() -> void:
	print("[InputHandler] Toggling debug menu")
	var game = get_parent()
	if game and game.has_method("toggle_debug_menu"):
		game.toggle_debug_menu()
	else:
		print("[InputHandler] ERROR: game or toggle_debug_menu method not found")

## Toggle fast travel screen
func _toggle_fast_travel() -> void:
	var game = get_parent()
	if game and game.has_method("toggle_fast_travel"):
		game.toggle_fast_travel()

## Open rest menu
func _open_rest_menu() -> void:
	var game = get_parent()
	if game and game.has_method("open_rest_menu"):
		game.open_rest_menu()

## Start till mode - prompts for direction to till
func _start_till_mode() -> void:
	var game = get_parent()

	# Check if player has a hoe equipped
	var tool_check = FarmingSystemClass.has_hoe_equipped(player)
	if not tool_check.has_tool:
		if game and game.has_method("_add_message"):
			game._add_message("Need a hoe equipped to till soil.", Color(0.9, 0.6, 0.4))
		return

	_awaiting_till_direction = true
	set_ui_blocking(true)
	if game and game.has_method("_add_message"):
		game._add_message("Till which direction? (Arrow keys/WASD, ESC to cancel)", Color(0.8, 0.9, 1.0))

## Exit till mode
func _exit_till_mode() -> void:
	_awaiting_till_direction = false
	set_ui_blocking(false)

## Try to till soil in the given direction
func _try_till(direction: Vector2i) -> bool:
	var target_pos = player.position + direction
	var result = FarmingSystemClass.till_soil(player, target_pos)

	var game = get_parent()
	if game and game.has_method("_add_message"):
		var color = Color(0.6, 0.9, 0.6) if result.success else Color(0.9, 0.5, 0.5)
		game._add_message(result.message, color)

	# Re-render map if successful
	if result.success and game:
		if game.render_orchestrator:
			game.render_orchestrator.render_map()
		if game.render_orchestrator:
			game.render_orchestrator.render_all_entities()
		if game.render_orchestrator:
			game.render_orchestrator.update_visibility()
		# Re-render player (must be after visibility update)
		if game.renderer:
			game.renderer.render_entity(player.position, "@", Color.YELLOW)

	return result.success

## Start plant mode - prompts for seed selection and direction
## If already in plant mode, cycles to the next seed type
func _start_plant_mode() -> void:
	var game = get_parent()

	# If already in plant mode, cycle to next seed
	if _awaiting_plant_direction and _available_seeds.size() > 1:
		_cycle_seed_selection()
		return

	# Get available seeds
	_available_seeds = FarmingSystemClass.get_plantable_seeds(player)
	if _available_seeds.is_empty():
		if game and game.has_method("_add_message"):
			game._add_message("You have no seeds to plant.", Color(0.9, 0.6, 0.4))
		return

	# Start with the first seed type
	_current_seed_index = 0
	_selected_seed_for_planting = _available_seeds[0]
	_awaiting_plant_direction = true
	set_ui_blocking(true)

	_show_plant_mode_message()

## Cycle to the next seed type in the list
func _cycle_seed_selection() -> void:
	if _available_seeds.is_empty():
		return

	_current_seed_index = (_current_seed_index + 1) % _available_seeds.size()
	_selected_seed_for_planting = _available_seeds[_current_seed_index]

	_show_plant_mode_message()

## Show the plant mode message with current seed and cycling hint
func _show_plant_mode_message() -> void:
	var game = get_parent()
	if not game or not game.has_method("_add_message"):
		return

	var seed_count = player.inventory.get_item_count(_selected_seed_for_planting.id) if player and player.inventory else 0
	var cycle_hint = ""
	if _available_seeds.size() > 1:
		cycle_hint = " [Shift+P to cycle seeds, %d/%d]" % [_current_seed_index + 1, _available_seeds.size()]

	game._add_message("Plant %s (x%d) in which direction? (Arrow keys/WASD, ESC to cancel)%s" % [_selected_seed_for_planting.name, seed_count, cycle_hint], Color(0.8, 0.9, 1.0))

## Exit plant mode
func _exit_plant_mode() -> void:
	_awaiting_plant_direction = false
	_selected_seed_for_planting = null
	_available_seeds.clear()
	_current_seed_index = 0
	set_ui_blocking(false)

## Try to plant a seed in the given direction
func _try_plant(direction: Vector2i) -> bool:
	if not _selected_seed_for_planting:
		return false

	var target_pos = player.position + direction
	var result = FarmingSystemClass.plant_seed(player, target_pos, _selected_seed_for_planting)

	var game = get_parent()
	if game and game.has_method("_add_message"):
		var color = Color(0.6, 0.9, 0.6) if result.success else Color(0.9, 0.5, 0.5)
		game._add_message(result.message, color)

	# Re-render map if successful
	if result.success and game:
		if game.render_orchestrator:
			game.render_orchestrator.render_map()
		if game.render_orchestrator:
			game.render_orchestrator.render_all_entities()
		if game.render_orchestrator:
			game.render_orchestrator.update_visibility()
		# Re-render player (must be after visibility update)
		if game.renderer:
			game.renderer.render_entity(player.position, "@", Color.YELLOW)

	return result.success

## Try to interact with a dungeon feature at player position
func _try_interact_feature() -> bool:
	var result = player.interact_with_feature()

	var game = get_parent()
	if game and game.has_method("_add_message"):
		var message = result.get("message", "")
		if message:
			var color = Color(0.6, 0.9, 0.6) if result.get("success", false) else Color(0.7, 0.7, 0.7)
			game._add_message(message, color)

	return result.get("success", false)


## Try to harvest a resource in the given direction
## Returns a Dictionary with keys: success (bool), harvest_complete (bool)
## - success: true if harvest action was performed
## - harvest_complete: true if resource is now depleted (no more harvesting possible)
func _try_harvest(direction: Vector2i) -> Dictionary:
	var result = player.harvest_resource(direction)

	var game = get_parent()
	if game and game.has_method("_add_message"):
		var color = Color(0.6, 0.9, 0.6) if result.success else Color(0.9, 0.5, 0.5)
		# If there's a progress message (for multi-turn harvests completing), show it first
		var progress_msg = result.get("progress_message", "")
		if progress_msg != "":
			game._add_message(progress_msg, color)
		# Show the main message (progress or harvest completion)
		game._add_message(result.message, color)

	# Update visibility to apply fog of war after harvest
	# This ensures the harvested position is properly updated
	if result.success and game and game.render_orchestrator:
		game.render_orchestrator.update_visibility()

	# Determine if harvest is complete (resource depleted)
	# Harvest is complete when: success=true AND in_progress is not true
	var harvest_complete = result.success and not result.get("in_progress", false)

	return {"success": result.success, "harvest_complete": harvest_complete}


## Start ranged targeting mode
func _start_ranged_targeting() -> void:
	var game = get_parent()

	# Check if player has a ranged weapon equipped
	var weapon = _get_equipped_ranged_weapon()
	if not weapon:
		if game and game.has_method("_add_message"):
			game._add_message("No ranged weapon equipped.", Color(0.9, 0.6, 0.4))
		return

	# For ranged weapons (not thrown), check for ammo
	var ammo: Item = null
	if weapon.is_ranged_weapon() and weapon.ammunition_type != "":
		ammo = _get_ammunition_for_weapon(weapon)
		if not ammo:
			if game and game.has_method("_add_message"):
				game._add_message("No %s ammunition." % weapon.ammunition_type, Color(0.9, 0.6, 0.4))
			return

	# Start targeting
	var has_targets = targeting_system.start_targeting(player, weapon, ammo)
	if not has_targets:
		if game and game.has_method("_add_message"):
			game._add_message("No valid targets in range.", Color(0.7, 0.7, 0.7))
		return

	# Block other input while targeting
	set_ui_blocking(true)

	# Show targeting UI
	if game and game.has_method("show_targeting_ui"):
		game.show_targeting_ui(targeting_system)
	elif game and game.has_method("_add_message"):
		game._add_message(targeting_system.get_status_text(), Color(0.8, 0.9, 1.0))
		game._add_message(targeting_system.get_help_text(), Color(0.7, 0.7, 0.7))


## Handle input while in targeting mode
func _handle_targeting_input(event: InputEventKey) -> void:
	var game = get_parent()

	match event.keycode:
		KEY_TAB, KEY_RIGHT, KEY_D:
			# Cycle to next target
			targeting_system.cycle_next()
			_update_targeting_display()
			get_viewport().set_input_as_handled()

		KEY_LEFT, KEY_A:
			# Cycle to previous target
			targeting_system.cycle_previous()
			_update_targeting_display()
			get_viewport().set_input_as_handled()

		KEY_ENTER, KEY_SPACE, KEY_R, KEY_F:
			# Check if we're in spell targeting mode
			if targeting_system.is_spell_targeting:
				# Spell targeting - cast spell on current target
				var result = targeting_system.confirm_spell_target()
				_process_spell_result(result, game)
				# Consume scroll if this was scroll-based targeting
				if pending_scroll and result.success:
					player.inventory.remove_item(pending_scroll)
					pending_scroll = null
				# Consume wand charge if this was wand-based targeting
				if pending_wand and result.success:
					pending_wand.charges -= 1
					EventBus.wand_used.emit(pending_wand, targeting_system.current_spell, pending_wand.charges)
					pending_wand = null
			else:
				# Normal ranged weapon targeting
				var result = targeting_system.confirm_target()
				_process_ranged_attack_result(result)
			set_ui_blocking(false)
			get_viewport().set_input_as_handled()

		KEY_ESCAPE:
			# Cancel targeting
			var was_spell_targeting = targeting_system.is_spell_targeting
			targeting_system.cancel()
			# Clear pending scroll/wand without consuming
			pending_scroll = null
			pending_wand = null
			if game and game.has_method("hide_targeting_ui"):
				game.hide_targeting_ui()
			if game and game.has_method("_add_message"):
				if was_spell_targeting:
					game._add_message("Spell cancelled.", Color(0.7, 0.7, 0.7))
				else:
					game._add_message("Targeting cancelled.", Color(0.7, 0.7, 0.7))
			set_ui_blocking(false)
			get_viewport().set_input_as_handled()


## Update targeting display after cycling targets
func _update_targeting_display() -> void:
	var game = get_parent()
	if game and game.has_method("update_targeting_ui"):
		game.update_targeting_ui(targeting_system)
	elif game and game.has_method("_add_message"):
		game._add_message(targeting_system.get_status_text(), Color(0.8, 0.9, 1.0))

	# Update visual highlight to show current target
	var current = targeting_system.get_current_target()
	if current and game and game.has_method("update_target_highlight"):
		game.update_target_highlight(current)


## Process the result of a ranged attack
func _process_ranged_attack_result(result: Dictionary) -> void:
	var game = get_parent()

	if result.has("error"):
		if game and game.has_method("_add_message"):
			game._add_message(result.error, Color(0.9, 0.5, 0.5))
		return

	# Consume ammunition
	if result.get("is_ranged", false) and not result.get("is_thrown", false):
		_consume_ammunition(targeting_system.ammo)
	elif result.get("is_thrown", false):
		_consume_thrown_weapon(targeting_system.weapon)

	# Display combat message
	var message = RangedCombatSystemClass.get_ranged_attack_message(result, true)
	var color = Color(0.6, 0.9, 0.6) if result.hit else Color(0.7, 0.7, 0.7)
	if game and game.has_method("_add_message"):
		game._add_message(message, color)

	# Handle ammo recovery on miss
	if not result.hit:
		if result.get("ammo_recovered", false):
			_spawn_recovered_ammo(result)
		else:
			# Ammo was not recovered - show break message
			var ammo_name = result.get("ammo_name", "")
			if ammo_name.is_empty() and result.get("is_thrown", false):
				ammo_name = result.get("weapon_name", "projectile")
			if not ammo_name.is_empty() and game and game.has_method("_add_message"):
				game._add_message("The %s broke." % ammo_name, Color(0.6, 0.5, 0.4))

	# Hide targeting UI
	if game and game.has_method("hide_targeting_ui"):
		game.hide_targeting_ui()

	# Advance turn
	TurnManager.advance_turn()

	# Refresh rendering, then apply FOW (order matters - render first, then FOW hides non-visible)
	if game and game.render_orchestrator:
		game.render_orchestrator.render_all_entities()
		game.render_orchestrator.render_ground_items()
	if game and game.render_orchestrator:
		game.render_orchestrator.update_visibility()


## Process the result of a spell cast
func _process_spell_result(result: Dictionary, game) -> void:
	if result.success:
		if game and game.has_method("_add_message"):
			game._add_message(result.message, Color(0.5, 0.8, 1.0))
		TurnManager.advance_turn()
	elif result.failed:
		if game and game.has_method("_add_message"):
			game._add_message(result.message, Color(1.0, 0.8, 0.3))
		TurnManager.advance_turn()  # Still costs a turn
	else:
		if game and game.has_method("_add_message"):
			game._add_message(result.get("message", "Spell failed."), Color(1.0, 0.5, 0.5))

	# Hide targeting UI
	if game and game.has_method("hide_targeting_ui"):
		game.hide_targeting_ui()

	# Update HUD to show mana change
	if game and game.has_method("_update_hud"):
		game._update_hud()

	# Refresh rendering, then apply FOW (order matters - render first, then FOW hides non-visible)
	if game and game.render_orchestrator:
		game.render_orchestrator.render_all_entities()
		game.render_orchestrator.render_ground_items()
	if game and game.render_orchestrator:
		game.render_orchestrator.update_visibility()


## Get the equipped ranged or thrown weapon
func _get_equipped_ranged_weapon() -> Item:
	if not player or not player.inventory:
		return null

	# Check main hand first
	var main_hand = player.inventory.equipment.get("main_hand")
	if main_hand and main_hand.can_attack_at_range():
		return main_hand

	# Check off hand
	var off_hand = player.inventory.equipment.get("off_hand")
	if off_hand and off_hand.can_attack_at_range():
		return off_hand

	return null


## Get ammunition matching the weapon's ammunition_type
func _get_ammunition_for_weapon(weapon: Item) -> Item:
	if not player or not player.inventory or weapon.ammunition_type == "":
		return null

	# Search inventory for matching ammo
	for item in player.inventory.items:
		if item.is_ammunition() and item.ammunition_type == weapon.ammunition_type:
			return item

	return null


## Consume one ammunition from inventory
func _consume_ammunition(ammo: Item) -> void:
	if not ammo or not player or not player.inventory:
		return

	ammo.remove_from_stack(1)
	if ammo.is_empty():
		player.inventory.remove_item(ammo)


## Consume thrown weapon from inventory
func _consume_thrown_weapon(weapon: Item) -> void:
	if not weapon or not player or not player.inventory:
		return

	# For thrown weapons, remove one from stack or remove entirely
	weapon.remove_from_stack(1)
	if weapon.is_empty():
		player.inventory.remove_item(weapon)


## Spawn recovered ammo/thrown weapon on the ground
func _spawn_recovered_ammo(result: Dictionary) -> void:
	var recovery_pos = result.get("recovery_position", Vector2i.ZERO)
	if recovery_pos == Vector2i.ZERO:
		return

	var item_id = ""
	if result.get("is_thrown", false):
		item_id = targeting_system.weapon.id if targeting_system.weapon else ""
	else:
		item_id = targeting_system.ammo.id if targeting_system.ammo else ""

	if item_id == "":
		return

	# Create ground item
	var item = ItemManager.create_item(item_id, 1)
	if item:
		EntityManager.spawn_ground_item(item, recovery_pos)

		var game = get_parent()
		if game and game.has_method("_add_message"):
			game._add_message("Your %s lands on the ground." % item.name, Color(0.7, 0.8, 0.7))


## Cycle through valid targets (Tab key)
func _cycle_target() -> void:
	var game = get_parent()

	# Check if player can perform any ranged action (ranged weapon, spells, or magic items)
	var has_ranged_weapon = _get_equipped_ranged_weapon() != null
	var can_cast_spells = player and player.has_spellbook() and not player.get_known_spells().is_empty()
	var has_ranged_magic_item = _has_ranged_magic_item()

	if not has_ranged_weapon and not can_cast_spells and not has_ranged_magic_item:
		if game and game.has_method("_add_message"):
			game._add_message("No ranged attack capability.", Color(0.9, 0.6, 0.4))
		return

	# Get all valid targets in perception range
	var valid_targets = _get_valid_targets_in_range()

	if valid_targets.is_empty():
		if game and game.has_method("_add_message"):
			game._add_message("No targets in range.", Color(0.7, 0.7, 0.7))
		_set_current_target(null)
		return

	# Find current target index
	var current_index = -1
	if current_target and is_instance_valid(current_target):
		for i in range(valid_targets.size()):
			if valid_targets[i] == current_target:
				current_index = i
				break

	# Cycle to next target
	var next_index = (current_index + 1) % valid_targets.size()
	_set_current_target(valid_targets[next_index])

	# Show target info
	if current_target and game and game.has_method("_add_message"):
		var distance = RangedCombatSystemClass.get_tile_distance(player.position, current_target.position)
		game._add_message("Target: %s (Distance: %d)" % [current_target.name, distance], Color(0.8, 0.9, 1.0))


## Fire at the current target (R key)
func _fire_at_target() -> void:
	var game = get_parent()

	# Check if we have a valid target
	if not current_target or not is_instance_valid(current_target) or not current_target.is_alive:
		# No target selected, show message
		if game and game.has_method("_add_message"):
			game._add_message("No target selected. Press Tab to select a target.", Color(0.9, 0.6, 0.4))
		_set_current_target(null)
		return

	# Check if player has a ranged weapon equipped
	var weapon = _get_equipped_ranged_weapon()
	if not weapon:
		if game and game.has_method("_add_message"):
			game._add_message("No ranged weapon equipped.", Color(0.9, 0.6, 0.4))
		return

	# Handle charged spell items (wands) differently
	if weapon.is_charged_ranged_item():
		_fire_charged_item_at_target(weapon, game)
		return

	# For ranged weapons (not thrown), check for ammo
	var ammo: Item = null
	if weapon.is_ranged_weapon() and weapon.ammunition_type != "":
		ammo = _get_ammunition_for_weapon(weapon)
		if not ammo:
			if game and game.has_method("_add_message"):
				game._add_message("No %s ammunition." % weapon.ammunition_type, Color(0.9, 0.6, 0.4))
			return

	# Check if target is in range and has line of sight
	var str_stat = player.attributes.get("STR", 10)
	var effective_range = weapon.get_effective_range(str_stat)
	var distance = RangedCombatSystemClass.get_tile_distance(player.position, current_target.position)

	if distance > effective_range:
		if game and game.has_method("_add_message"):
			game._add_message("Target is out of range.", Color(0.9, 0.6, 0.4))
		return

	if distance < 1:
		if game and game.has_method("_add_message"):
			game._add_message("Target is too close. Use melee attack.", Color(0.9, 0.6, 0.4))
		return

	if not RangedCombatSystemClass.has_line_of_sight(player.position, current_target.position):
		if game and game.has_method("_add_message"):
			game._add_message("No line of sight to target.", Color(0.9, 0.6, 0.4))
		return

	# Execute the ranged attack
	var result = RangedCombatSystemClass.attempt_ranged_attack(player, current_target, weapon, ammo)

	# Consume ammunition
	if result.get("is_ranged", false) and not result.get("is_thrown", false):
		_consume_ammunition(ammo)
	elif result.get("is_thrown", false):
		_consume_thrown_weapon(weapon)

	# Display combat message
	var message = RangedCombatSystemClass.get_ranged_attack_message(result, true)
	var color = Color(0.6, 0.9, 0.6) if result.hit else Color(0.7, 0.7, 0.7)
	if game and game.has_method("_add_message"):
		game._add_message(message, color)

	# Handle ammo recovery on miss
	if not result.hit:
		if result.get("ammo_recovered", false):
			var recovery_pos = result.get("recovery_position", Vector2i.ZERO)
			if recovery_pos != Vector2i.ZERO:
				var item_id = ammo.id if ammo else weapon.id
				var item = ItemManager.create_item(item_id, 1)
				if item:
					EntityManager.spawn_ground_item(item, recovery_pos)
					if game and game.has_method("_add_message"):
						game._add_message("Your %s lands on the ground." % item.name, Color(0.7, 0.8, 0.7))
		else:
			# Ammo was not recovered - show break message
			var ammo_name = result.get("ammo_name", "")
			if ammo_name.is_empty() and result.get("is_thrown", false):
				ammo_name = result.get("weapon_name", "projectile")
			if not ammo_name.is_empty() and game and game.has_method("_add_message"):
				game._add_message("The %s broke." % ammo_name, Color(0.6, 0.5, 0.4))

	# Clear target if it died
	if result.defender_died:
		_set_current_target(null)

	# Advance turn
	TurnManager.advance_turn()

	# Refresh rendering
	if game and game.render_orchestrator:
		game.render_orchestrator.render_all_entities()
		game.render_orchestrator.render_ground_items()
	if game and game.render_orchestrator:
		game.render_orchestrator.update_visibility()


## Get all valid targets within perception range
func _get_valid_targets_in_range() -> Array[Entity]:
	var targets: Array[Entity] = []

	if not player:
		return targets

	# Get current map for visibility check
	var current_map = MapManager.current_map

	for entity in EntityManager.entities:
		if entity == player:
			continue
		if not entity is Enemy:
			continue
		if not entity.is_alive:
			continue

		# Check if within perception range
		var distance = RangedCombatSystemClass.get_tile_distance(player.position, entity.position)
		if distance > player.perception_range:
			continue
		if distance < 1:
			continue  # Can't target adjacent (melee range)

		# Check if entity is visible (handles daytime outdoors mode)
		if not FogOfWarSystemClass.is_position_visible(entity.position, current_map, player.position):
			continue

		targets.append(entity)

	# Sort by distance (closest first)
	targets.sort_custom(func(a, b):
		return RangedCombatSystemClass.get_distance(player.position, a.position) < RangedCombatSystemClass.get_distance(player.position, b.position)
	)

	return targets


## Check if player has any ranged magic items (scrolls with ranged spells, wands)
func _has_ranged_magic_item() -> bool:
	if not player or not player.inventory:
		return false

	# Check for wands
	for item in player.inventory.items:
		if item.subtype == "wand" and item.charges > 0:
			return true
		# Check for scrolls with ranged spells
		if item.subtype == "scroll" and item.spell_id != "":
			var spell = SpellManager.get_spell(item.spell_id)
			if spell and spell.get_targeting_mode() in ["ranged", "touch"]:
				return true

	return false


## Fire a charged spell item (wand) at the current target
func _fire_charged_item_at_target(weapon: Item, game) -> void:
	# Get the spell from the wand
	var spell = SpellManager.get_spell(weapon.casts_spell)
	if spell == null:
		if game and game.has_method("_add_message"):
			game._add_message("The %s contains corrupted magic." % weapon.name, Color(0.9, 0.5, 0.5))
		return

	# Check range
	var effective_range = spell.get_range()
	var distance = RangedCombatSystemClass.get_tile_distance(player.position, current_target.position)

	if distance > effective_range:
		if game and game.has_method("_add_message"):
			game._add_message("Target is out of range.", Color(0.9, 0.6, 0.4))
		return

	if distance < 1:
		if game and game.has_method("_add_message"):
			game._add_message("Target is too close. Use melee attack.", Color(0.9, 0.6, 0.4))
		return

	# Check line of sight
	if not RangedCombatSystemClass.has_line_of_sight(player.position, current_target.position):
		if game and game.has_method("_add_message"):
			game._add_message("No line of sight to target.", Color(0.9, 0.6, 0.4))
		return

	# Cast the spell using the SpellCastingSystem (from_item=true bypasses class restrictions)
	const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")
	var result = SpellCastingSystemClass.cast_spell(player, spell, current_target, true)

	# Consume a charge on successful cast
	if result.success or not result.get("failed", true):
		weapon.charges -= 1
		EventBus.wand_used.emit(weapon, spell, weapon.charges)

		# Identify the wand on successful use
		if weapon.unidentified:
			var id_manager = Engine.get_main_loop().root.get_node_or_null("IdentificationManager")
			if id_manager and not id_manager.is_identified(weapon.id):
				id_manager.identify_item(weapon.id)
				weapon.unidentified = false
				if game and game.has_method("_add_message"):
					game._add_message("It was a %s!" % weapon.name, Color(0.9, 0.9, 0.5))

	# Display result message
	if result.has("message") and result.message != "":
		var color = Color(0.6, 0.9, 0.6) if result.success else Color(0.9, 0.6, 0.4)
		if game and game.has_method("_add_message"):
			game._add_message(result.message, color)

	# Show remaining charges
	if weapon.charges > 0:
		if game and game.has_method("_add_message"):
			game._add_message("%s: %d charges remaining." % [weapon.name, weapon.charges], Color(0.7, 0.7, 0.9))
	else:
		if game and game.has_method("_add_message"):
			game._add_message("The %s is depleted." % weapon.name, Color(0.9, 0.7, 0.4))

	# Clear target if it died
	if current_target and (not is_instance_valid(current_target) or not current_target.is_alive):
		_set_current_target(null)

	# Advance turn
	TurnManager.advance_turn()


## Set the current target and emit signal
func _set_current_target(target: Entity) -> void:
	var old_target = current_target
	current_target = target

	# Only emit if target actually changed
	if old_target != current_target:
		target_changed.emit(current_target)

		# Update rendering to show/hide target highlight
		var game = get_parent()
		if game and game.has_method("update_target_highlight"):
			game.update_target_highlight(current_target)


## Get the current target (for external access)
func get_current_target() -> Entity:
	# Validate target is still valid
	if current_target and (not is_instance_valid(current_target) or not current_target.is_alive):
		_set_current_target(null)
	return current_target


## Clear the current target
func clear_target() -> void:
	_set_current_target(null)


## Untarget the current target (with user feedback)
func _untarget() -> void:
	var game = get_parent()
	if current_target:
		var target_name = current_target.name
		_set_current_target(null)
		if game and game.has_method("_add_message"):
			game._add_message("Untargeted: %s" % target_name, Color(0.7, 0.7, 0.7))
	else:
		if game and game.has_method("_add_message"):
			game._add_message("No target to clear.", Color(0.7, 0.7, 0.7))


## Start look mode to examine visible objects
func _start_look_mode() -> void:
	var game = get_parent()

	# Gather all visible objects
	look_objects = _get_visible_objects()

	if look_objects.is_empty():
		if game and game.has_method("_add_message"):
			game._add_message("Nothing visible to examine.", Color(0.7, 0.7, 0.7))
		return

	look_mode_active = true
	look_index = 0
	_set_look_object(look_objects[0])

	if game and game.has_method("_add_message"):
		game._add_message("Look mode: [Tab] cycle, [Enter] target enemy, [Esc] exit", Color(0.7, 0.9, 1.0))


## Handle input while in look mode
func _handle_look_input(event: InputEventKey) -> void:
	var game = get_parent()

	match event.keycode:
		KEY_TAB, KEY_RIGHT, KEY_D:
			# Cycle to next object
			if look_objects.size() > 0:
				look_index = (look_index + 1) % look_objects.size()
				_set_look_object(look_objects[look_index])
			get_viewport().set_input_as_handled()

		KEY_LEFT, KEY_A:
			# Cycle to previous object
			if look_objects.size() > 0:
				look_index = (look_index - 1 + look_objects.size()) % look_objects.size()
				_set_look_object(look_objects[look_index])
			get_viewport().set_input_as_handled()

		KEY_ENTER, KEY_KP_ENTER:
			# Target the looked-at object if it's an enemy
			# current_look_object could be an Entity or a Dictionary (for features/hazards)
			var can_target = false
			if current_look_object and current_look_object is Entity:
				if current_look_object is Enemy and current_look_object.is_alive:
					can_target = true

			if can_target:
				var target_name = current_look_object.name
				_set_current_target(current_look_object)
				_exit_look_mode()
				if game and game.has_method("_add_message"):
					game._add_message("Targeted: %s" % target_name, Color(0.8, 0.9, 1.0))
			else:
				if game and game.has_method("_add_message"):
					game._add_message("Can only target enemies.", Color(0.9, 0.6, 0.4))
			get_viewport().set_input_as_handled()

		KEY_ESCAPE:
			# Exit look mode
			_exit_look_mode()
			if game and game.has_method("_add_message"):
				game._add_message("Exited look mode.", Color(0.7, 0.7, 0.7))
			get_viewport().set_input_as_handled()


## Get all visible objects (enemies, items, features, etc.)
func _get_visible_objects() -> Array:
	var objects: Array = []

	if not player:
		return objects

	# Get current map for visibility check
	var current_map = MapManager.current_map

	# Add visible entities (enemies, NPCs, ground items)
	for entity in EntityManager.entities:
		if entity == player:
			continue
		if not entity.is_alive:
			continue

		var distance = RangedCombatSystemClass.get_tile_distance(player.position, entity.position)
		if distance > player.perception_range:
			continue

		# Check if entity is currently visible (handles daytime outdoors mode)
		if not FogOfWarSystemClass.is_position_visible(entity.position, current_map, player.position):
			continue

		# Handle different entity types
		if entity is GroundItem:
			objects.append({
				"object": entity,
				"position": entity.position,
				"type": "item",
				"name": entity.item.name if entity.item else "Unknown Item",
				"description": _get_item_description(entity)
			})
		elif entity is CropEntityClass:
			objects.append({
				"object": entity,
				"position": entity.position,
				"type": "crop",
				"name": entity.name,
				"description": entity.get_tooltip()
			})
		elif entity is Enemy:
			objects.append({
				"object": entity,
				"position": entity.position,
				"type": "enemy",
				"name": entity.name,
				"description": _get_entity_description(entity)
			})
		elif entity is NPC:
			objects.append({
				"object": entity,
				"position": entity.position,
				"type": "npc",
				"name": entity.name,
				"description": "An NPC you can talk to."
			})
		else:
			# Other entity types
			objects.append({
				"object": entity,
				"position": entity.position,
				"type": "entity",
				"name": entity.name,
				"description": ""
			})

	# Add visible features
	for pos in FeatureManager.active_features:
		var distance = RangedCombatSystemClass.get_tile_distance(player.position, pos)
		if distance <= player.perception_range:
			# Check if feature is currently visible (in FOV and illuminated)
			if not FogOfWarSystemClass.is_visible(pos):
				continue
			var feature = FeatureManager.active_features[pos]
			var definition = feature.get("definition", {})
			objects.append({
				"object": feature,
				"position": pos,
				"type": "feature",
				"name": definition.get("name", "Unknown Feature"),
				"description": _get_feature_description(feature)
			})

	# Add visible hazards (only detected ones)
	for pos in HazardManager.active_hazards:
		if HazardManager.has_visible_hazard(pos):
			var distance = RangedCombatSystemClass.get_tile_distance(player.position, pos)
			if distance <= player.perception_range:
				# Check if hazard is currently visible (in FOV and illuminated)
				if not FogOfWarSystemClass.is_visible(pos):
					continue
				var hazard = HazardManager.active_hazards[pos]
				var definition = hazard.get("definition", {})
				objects.append({
					"object": hazard,
					"position": pos,
					"type": "hazard",
					"name": definition.get("name", "Unknown Hazard"),
					"description": _get_hazard_description(hazard)
				})

	# Add visible harvestable resources (herbs, flowers, mushrooms, etc.)
	var map = MapManager.current_map
	if map:
		# Scan nearby positions for harvestable resources
		for dx in range(-player.perception_range, player.perception_range + 1):
			for dy in range(-player.perception_range, player.perception_range + 1):
				var pos = player.position + Vector2i(dx, dy)
				var distance = RangedCombatSystemClass.get_tile_distance(player.position, pos)
				if distance > player.perception_range:
					continue
				if not FogOfWarSystemClass.is_visible(pos):
					continue

				# Check if this tile has a harvestable resource
				var tile = map.get_tile(pos)
				if tile and tile.harvestable_resource_id != "":
					# Skip trees and rocks (they're already handled as terrain features)
					if tile.harvestable_resource_id in ["tree", "rock"]:
						continue
					var resource = HarvestSystemClass.get_resource(tile.harvestable_resource_id)
					if resource:
						objects.append({
							"object": null,
							"position": pos,
							"type": "resource",
							"name": resource.name,
							"description": _get_resource_description(resource)
						})

	# Add visible tilled soil (without crops)
	if map:
		var map_id = map.map_id
		# Scan nearby positions for tilled soil
		for dx in range(-player.perception_range, player.perception_range + 1):
			for dy in range(-player.perception_range, player.perception_range + 1):
				var pos = player.position + Vector2i(dx, dy)
				var distance = RangedCombatSystemClass.get_tile_distance(player.position, pos)
				if distance > player.perception_range:
					continue
				if not FogOfWarSystemClass.is_visible(pos):
					continue

				# Check if this position has tilled soil (no crop)
				var soil_info: Dictionary = FarmingSystemClass.get_tilled_soil_info(map_id, pos)
				if not soil_info.is_empty():
					var description = "Tilled soil ready for planting"
					if soil_info.turns_until_decay > 0:
						description += " (%d turns until it returns to %s)" % [soil_info.turns_until_decay, soil_info.original_tile]
					objects.append({
						"object": null,
						"position": pos,
						"type": "terrain",
						"name": "Tilled Soil",
						"description": description
					})

	# Add visible structures (forge, anvil, campfire, etc.)
	var current_map_id = map.map_id if map else ""
	if current_map_id != "":
		var structures = StructureManager.get_structures_on_map(current_map_id)
		for structure in structures:
			var distance = RangedCombatSystemClass.get_tile_distance(player.position, structure.position)
			if distance > player.perception_range:
				continue
			if not FogOfWarSystemClass.is_visible(structure.position):
				continue
			objects.append({
				"object": structure,
				"position": structure.position,
				"type": "structure",
				"name": structure.name,
				"description": _get_structure_description(structure)
			})

	# Sort by distance (closest first)
	objects.sort_custom(func(a, b):
		var dist_a = RangedCombatSystemClass.get_tile_distance(player.position, a.position)
		var dist_b = RangedCombatSystemClass.get_tile_distance(player.position, b.position)
		return dist_a < dist_b
	)

	return objects


## Set the current look object and update display
func _set_look_object(obj_data: Dictionary) -> void:
	var game = get_parent()

	current_look_object = obj_data.get("object")
	var position = obj_data.get("position", Vector2i.ZERO)
	var obj_name = obj_data.get("name", "Unknown")
	var obj_type = obj_data.get("type", "unknown")
	var description = obj_data.get("description", "")
	var distance = RangedCombatSystemClass.get_tile_distance(player.position, position)

	# Show description message
	if game and game.has_method("_add_message"):
		var type_label = obj_type.capitalize()
		var index_text = "(%d/%d)" % [look_index + 1, look_objects.size()]
		game._add_message("%s %s: %s (Dist: %d)" % [index_text, type_label, obj_name, distance], Color(0.9, 0.9, 0.7))
		if description != "":
			game._add_message("  %s" % description, Color(0.7, 0.8, 0.7))

	# Emit signal and update highlight
	look_object_changed.emit(current_look_object)

	if game and game.has_method("update_look_highlight"):
		game.update_look_highlight(position)


## Exit look mode
func _exit_look_mode() -> void:
	look_mode_active = false
	look_objects.clear()
	look_index = 0
	current_look_object = null

	var game = get_parent()

	# If there's a current target, restore the target highlight
	# Otherwise, clear the highlight
	if current_target and is_instance_valid(current_target) and current_target.is_alive:
		if game and game.has_method("update_target_highlight"):
			game.update_target_highlight(current_target)
	else:
		if game and game.has_method("update_look_highlight"):
			game.update_look_highlight(Vector2i(-1, -1))  # Invalid position clears highlight


## Get description for an entity
func _get_entity_description(entity: Entity) -> String:
	if entity is Enemy:
		var hp_percent = int((float(entity.current_health) / float(entity.max_health)) * 100)
		var is_undead = entity.creature_type == "undead"
		var health_state = "healthy"
		if hp_percent <= 25:
			health_state = "near destruction" if is_undead else "near death"
		elif hp_percent <= 50:
			health_state = "wounded"
		elif hp_percent <= 75:
			health_state = "injured"
		return "HP: %d%% (%s)" % [hp_percent, health_state]
	return ""


## Get description for a ground item
func _get_item_description(ground_item: GroundItem) -> String:
	if ground_item.item:
		var item = ground_item.item
		var desc_parts = []
		if item.stack_size > 1:
			desc_parts.append("x%d" % item.stack_size)
		if item.weight > 0:
			desc_parts.append("%.1f kg" % item.weight)
		return ", ".join(desc_parts) if desc_parts.size() > 0 else ""
	return ""


## Get description for a feature
func _get_feature_description(feature: Dictionary) -> String:
	var definition = feature.get("definition", {})
	var state_val = feature.get("state", "")
	var state = str(state_val) if state_val != null else ""
	var desc_val = definition.get("description", "")
	var desc = str(desc_val) if desc_val != null else ""
	if state == "opened" or state == "looted":
		desc += " (already opened)"
	elif state == "used":
		desc += " (already used)"
	return desc


## Get description for a hazard
func _get_hazard_description(hazard: Dictionary) -> String:
	var definition = hazard.get("definition", {})
	var desc = definition.get("description", "A dangerous hazard.")
	desc = str(desc) if desc != null else "A dangerous hazard."
	if hazard.get("disarmed", false):
		desc += " (disarmed)"
	return desc


## Get description for a harvestable resource
func _get_resource_description(resource: HarvestSystemClass.HarvestableResource) -> String:
	if resource.required_tools.size() > 0:
		var tool_names: Array[String] = []
		for tool_req in resource.required_tools:
			tool_names.append(tool_req.tool_id)
		return "Requires: %s" % ", ".join(tool_names)
	else:
		return "Can be harvested by hand."


## Get description for a structure
func _get_structure_description(structure) -> String:
	var parts: Array[String] = []

	# Check for workstation component
	if structure.has_component("workstation"):
		var ws = structure.get_component("workstation")
		if ws.required_tool != "":
			parts.append("Workstation (requires %s)" % ws.required_tool)
		else:
			parts.append("Workstation")

	# Check for fire component
	if structure.has_component("fire"):
		var fire = structure.get_component("fire")
		parts.append("Provides heat (radius %d)" % fire.heat_radius)

	# Check for shelter component
	if structure.has_component("shelter"):
		parts.append("Provides shelter from weather")

	# Check for container component
	if structure.has_component("container"):
		var container = structure.get_component("container")
		parts.append("Storage (%d slots)" % container.max_slots)

	if parts.is_empty():
		return "A placed structure."

	return ". ".join(parts) + "."


## Check if look mode is active
func is_look_mode_active() -> bool:
	return look_mode_active


## Get current look position (for highlighting)
func get_look_position() -> Vector2i:
	if look_mode_active and look_objects.size() > look_index:
		return look_objects[look_index].get("position", Vector2i(-1, -1))
	return Vector2i(-1, -1)


## Handle scroll targeting signal
## Called when a scroll with a ranged spell is used
func _on_scroll_targeting_started(scroll, spell) -> void:
	if not player:
		return

	var game = get_parent()

	# Store the scroll for consumption after cast
	pending_scroll = scroll

	# Start spell targeting for the scroll's spell
	if targeting_system.start_spell_targeting(player, spell):
		set_ui_blocking(true)
		if game and game.has_method("_add_message"):
			game._add_message(targeting_system.get_status_text(), Color(0.5, 0.8, 1.0))
			game._add_message(targeting_system.get_help_text(), Color(0.7, 0.7, 0.7))
	else:
		# No valid targets - don't consume scroll
		pending_scroll = null
		if game and game.has_method("_add_message"):
			game._add_message("No valid targets in range.", Color(1.0, 0.8, 0.3))


## Handle wand targeting signal
## Called when a wand with a ranged spell is used
func _on_wand_targeting_started(wand, spell) -> void:
	if not player:
		return

	var game = get_parent()

	# Store the wand for charge consumption after cast
	pending_wand = wand

	# Start spell targeting for the wand's spell
	if targeting_system.start_spell_targeting(player, spell):
		set_ui_blocking(true)
		if game and game.has_method("_add_message"):
			game._add_message(targeting_system.get_status_text(), Color(0.5, 0.8, 1.0))
			game._add_message(targeting_system.get_help_text(), Color(0.7, 0.7, 0.7))
	else:
		# No valid targets - don't consume charge
		pending_wand = null
		if game and game.has_method("_add_message"):
			game._add_message("No valid targets in range.", Color(1.0, 0.8, 0.3))


## Handle player turn started signal
## Enables _process() for input handling during player's turn
func _on_player_turn_started() -> void:
	if player and player.is_alive and not ui_blocking_input:
		set_process(true)


## Handle player turn ended signal
## Disables _process() to save CPU during enemy turns
func _on_player_turn_ended() -> void:
	set_process(false)
