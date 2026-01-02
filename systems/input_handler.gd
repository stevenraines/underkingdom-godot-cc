extends Node

## InputHandler - Convert keyboard input to player actions
##
## Handles input only on player's turn and advances the turn after actions.
## Supports continuous movement while holding WASD/arrow keys.

const TargetingSystemClass = preload("res://systems/targeting_system.gd")
const RangedCombatSystemClass = preload("res://systems/ranged_combat_system.gd")

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

# Harvest mode
var _awaiting_harvest_direction: bool = false  # Waiting for player to specify direction to harvest

# Ranged targeting mode
var targeting_system = null  # TargetingSystem instance

func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)
	targeting_system = TargetingSystemClass.new()

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

	# If in targeting mode, handle targeting input
	if targeting_system and targeting_system.is_active() and event is InputEventKey and event.pressed and not event.echo:
		_handle_targeting_input(event)
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
				ui_blocking_input = false
				var game = get_parent()
				if game and game.has_method("_add_message"):
					game._add_message("Cancelled harvest", Color(0.7, 0.7, 0.7))
				get_viewport().set_input_as_handled()
				return

		if direction != Vector2i.ZERO:
			_awaiting_harvest_direction = false
			ui_blocking_input = false
			get_viewport().set_input_as_handled()  # Consume input BEFORE processing

			# Reset movement timer to prevent immediate movement after harvest
			move_timer = initial_delay
			is_initial_press = true

			var action_taken = _try_harvest(direction)
			if action_taken:
				TurnManager.advance_turn()
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
			if tile and tile.tile_type == "stairs_up":
				# Save entity states before leaving this map
				EntityManager.save_entity_states_to_map(MapManager.current_map)
				# Check if we're going to overworld (floor 1 -> overworld) or to previous floor
				if MapManager.current_dungeon_floor == 1:
					# Returning to overworld - set position before transition
					var target_pos = GameManager.last_overworld_position if GameManager.last_overworld_position != Vector2i.ZERO else Vector2i(800, 800)
					player.position = target_pos
					MapManager.ascend_dungeon()
				else:
					# Going to previous dungeon floor - find stairs_down after transition
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
		elif event.keycode == KEY_COMMA:  # , - manual pickup
			_try_pickup_item()
			action_taken = true
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_T:  # T - talk/interact with NPC
			_try_interact_npc()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:  # M - toggle world map
			_toggle_world_map()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_H:  # H key - harvest (prompts for direction)
			_start_harvest_mode()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F:  # F key - interact with dungeon feature
			action_taken = _try_interact_feature()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_P:  # P key - character sheet
			_open_character_sheet()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F1 or (event.keycode == KEY_SLASH and event.shift_pressed) or event.unicode == 63:  # F1 or ? (Shift+/ or unicode 63) - help screen
			_open_help_screen()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:  # R key - ranged attack / fire
			_start_ranged_targeting()
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

## Try to pick up an item at the player's position
func _try_pickup_item() -> void:
	# Find ground items at player position
	var ground_items = EntityManager.get_ground_items_at(player.position)
	if ground_items.size() > 0:
		var ground_item = ground_items[0]  # Pick up first item
		if player.pickup_item(ground_item):
			EntityManager.remove_entity(ground_item)

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
func _start_harvest_mode() -> void:
	var game = get_parent()
	if game and game.has_method("_add_message"):
		game._add_message("Harvest which direction? (Arrow keys or WASD)", Color(1.0, 1.0, 0.6))

	# Set a flag to await direction input
	ui_blocking_input = true
	_awaiting_harvest_direction = true

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
func _try_harvest(direction: Vector2i) -> bool:
	var result = player.harvest_resource(direction)

	var game = get_parent()
	if game and game.has_method("_add_message"):
		var color = Color(0.6, 0.9, 0.6) if result.success else Color(0.9, 0.5, 0.5)
		game._add_message(result.message, color)

	# If successful, trigger a map re-render to show the resource is gone
	if result.success and game and game.has_method("_render_map"):
		game._render_map()
		game._render_all_entities()
		game._render_ground_items()
		# Re-render player (not in EntityManager.entities)
		if game.has_method("get_node") and game.get("renderer"):
			game.renderer.render_entity(player.position, "@", Color.YELLOW)

	return result.success


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
	ui_blocking_input = true

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
			# Confirm target and fire
			var result = targeting_system.confirm_target()
			_process_ranged_attack_result(result)
			ui_blocking_input = false
			get_viewport().set_input_as_handled()

		KEY_ESCAPE:
			# Cancel targeting
			targeting_system.cancel()
			ui_blocking_input = false
			if game and game.has_method("hide_targeting_ui"):
				game.hide_targeting_ui()
			if game and game.has_method("_add_message"):
				game._add_message("Targeting cancelled.", Color(0.7, 0.7, 0.7))
			get_viewport().set_input_as_handled()


## Update targeting display after cycling targets
func _update_targeting_display() -> void:
	var game = get_parent()
	if game and game.has_method("update_targeting_ui"):
		game.update_targeting_ui(targeting_system)
	elif game and game.has_method("_add_message"):
		game._add_message(targeting_system.get_status_text(), Color(0.8, 0.9, 1.0))


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
	if not result.hit and result.get("ammo_recovered", false):
		_spawn_recovered_ammo(result)

	# Hide targeting UI
	if game and game.has_method("hide_targeting_ui"):
		game.hide_targeting_ui()

	# Advance turn
	TurnManager.advance_turn()

	# Refresh rendering
	if game and game.has_method("_render_all_entities"):
		game._render_all_entities()
		game._render_ground_items()


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
		var ground_item = GroundItem.create(item, recovery_pos)
		EntityManager.add_entity(ground_item)

		var game = get_parent()
		if game and game.has_method("_add_message"):
			game._add_message("Your %s lands on the ground." % item.name, Color(0.7, 0.8, 0.7))
