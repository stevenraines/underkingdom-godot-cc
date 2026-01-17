extends Control
class_name DebugCommandMenu

## DebugCommandMenu - Developer tools for testing and debugging
##
## Provides commands for spawning items, creatures, hazards, features,
## and modifying player state during gameplay.

signal closed()

@onready var command_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/CommandList
@onready var direction_prompt: Label = $Panel/MarginContainer/VBoxContainer/DirectionPrompt
@onready var header: Label = $Panel/MarginContainer/VBoxContainer/Header

# Menu state
enum MenuState { MAIN, SUBMENU, DIRECTION_SELECT, AMOUNT_SELECT }
var current_state: MenuState = MenuState.MAIN
var selected_index: int = 0
var menu_stack: Array = []  # For nested menus

# Current submenu data
var submenu_items: Array = []
var submenu_title: String = ""
var pending_command: String = ""
var pending_item_id: String = ""

# Player reference (set when menu opens)
var player: Player = null

# Colors
const COLOR_CATEGORY = Color(0.9, 0.5, 0.3, 1)
const COLOR_COMMAND = Color(0.8, 0.8, 0.8, 1)
const COLOR_SELECTED = Color(0.9, 0.9, 0.5, 1)
const COLOR_DISABLED = Color(0.5, 0.5, 0.5, 1)

# Main menu structure
var main_menu: Array = [
	{"type": "category", "text": "[ITEMS]"},
	{"type": "command", "text": "Give Item", "action": "give_item"},
	{"type": "command", "text": "Spawn Item on Ground", "action": "spawn_item"},
	{"type": "category", "text": "[SPAWNING]"},
	{"type": "command", "text": "Spawn Creature", "action": "spawn_creature"},
	{"type": "command", "text": "Spawn Hazard", "action": "spawn_hazard"},
	{"type": "command", "text": "Spawn Feature", "action": "spawn_feature"},
	{"type": "category", "text": "[PLAYER]"},
	{"type": "command", "text": "Give Gold", "action": "give_gold"},
	{"type": "command", "text": "Set Level", "action": "set_level"},
	{"type": "command", "text": "Max Stats", "action": "max_stats"},
	{"type": "command", "text": "Learn All Spells", "action": "learn_spells"},
	{"type": "command", "text": "Learn All Recipes", "action": "learn_recipes"},
	{"type": "command", "text": "Toggle God Mode", "action": "toggle_god_mode"},
	{"type": "category", "text": "[WORLD]"},
	{"type": "command", "text": "Teleport to Town", "action": "teleport_town"},
	{"type": "command", "text": "Reveal Map", "action": "reveal_map"},
]

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		match current_state:
			MenuState.MAIN, MenuState.SUBMENU, MenuState.AMOUNT_SELECT:
				_handle_menu_input(event, viewport)
			MenuState.DIRECTION_SELECT:
				_handle_direction_input(event, viewport)

func _handle_menu_input(event: InputEventKey, viewport: Viewport) -> void:
	match event.keycode:
		KEY_ESCAPE:
			if current_state == MenuState.MAIN:
				close()
			else:
				_go_back()
			viewport.set_input_as_handled()
		KEY_BACKSPACE:
			if current_state != MenuState.MAIN:
				_go_back()
			viewport.set_input_as_handled()
		KEY_UP:
			_navigate(-1)
			viewport.set_input_as_handled()
		KEY_DOWN:
			_navigate(1)
			viewport.set_input_as_handled()
		KEY_ENTER:
			_execute_selected()
			viewport.set_input_as_handled()

func _handle_direction_input(event: InputEventKey, viewport: Viewport) -> void:
	var direction: Vector2i = Vector2i.ZERO

	match event.keycode:
		KEY_ESCAPE, KEY_BACKSPACE:
			_go_back()
			viewport.set_input_as_handled()
			return
		KEY_LEFT, KEY_A:
			direction = Vector2i.LEFT
		KEY_RIGHT, KEY_D:
			direction = Vector2i.RIGHT
		KEY_UP, KEY_W:
			direction = Vector2i.UP
		KEY_DOWN, KEY_S:
			direction = Vector2i.DOWN

	if direction != Vector2i.ZERO:
		_execute_with_direction(direction)
		viewport.set_input_as_handled()

func open(p: Player = null) -> void:
	# Get player reference - try passed parameter, then traverse tree
	if p:
		player = p
	else:
		# Try to get player from game scene (parent of HUD, which is our parent)
		var hud = get_parent()
		if hud:
			var game = hud.get_parent()
			if game and "player" in game:
				player = game.player

	current_state = MenuState.MAIN
	selected_index = 0
	menu_stack.clear()
	_build_main_menu()
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()

func _go_back() -> void:
	if menu_stack.size() > 0:
		var prev_state = menu_stack.pop_back()
		current_state = prev_state.state
		selected_index = prev_state.index
		if current_state == MenuState.MAIN:
			_build_main_menu()
		else:
			_build_submenu(prev_state.title, prev_state.items)
	else:
		current_state = MenuState.MAIN
		_build_main_menu()

	direction_prompt.visible = false
	header.text = "~ DEBUG COMMANDS ~"

func _navigate(direction: int) -> void:
	var items = _get_current_items()
	var new_index = selected_index + direction

	# Skip category headers
	while new_index >= 0 and new_index < items.size():
		if items[new_index].type != "category":
			break
		new_index += direction

	if new_index >= 0 and new_index < items.size():
		selected_index = new_index
		_update_selection()

func _get_current_items() -> Array:
	if current_state == MenuState.MAIN:
		return main_menu
	else:
		return submenu_items

func _execute_selected() -> void:
	var items = _get_current_items()
	if selected_index < 0 or selected_index >= items.size():
		return

	var item = items[selected_index]
	if item.type == "category":
		return

	if current_state == MenuState.MAIN:
		_execute_main_command(item.action)
	elif current_state == MenuState.SUBMENU:
		_execute_submenu_selection(item)
	elif current_state == MenuState.AMOUNT_SELECT:
		_execute_amount_selection(item)

func _execute_main_command(action: String) -> void:
	match action:
		"give_item":
			_show_item_submenu("give")
		"spawn_item":
			_show_item_submenu("spawn")
		"spawn_creature":
			_show_creature_submenu()
		"spawn_hazard":
			_show_hazard_submenu()
		"spawn_feature":
			_show_feature_submenu()
		"give_gold":
			_show_gold_submenu()
		"set_level":
			_show_level_submenu()
		"max_stats":
			_do_max_stats()
		"learn_spells":
			_do_learn_all_spells()
		"learn_recipes":
			_do_learn_all_recipes()
		"toggle_god_mode":
			_do_toggle_god_mode()
		"teleport_town":
			_do_teleport_town()
		"reveal_map":
			_do_reveal_map()

# ============================================================================
# Submenu builders
# ============================================================================

func _show_item_submenu(mode: String) -> void:
	pending_command = mode
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	var all_item_ids = ItemManager.get_all_item_ids()
	all_item_ids.sort()

	for item_id in all_item_ids:
		var item_data = ItemManager.get_item_data(item_id)
		var display_name = item_data.get("name", item_id) if item_data else item_id
		items.append({"type": "command", "text": display_name, "id": item_id})

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Item", items)

func _show_creature_submenu() -> void:
	pending_command = "spawn_creature"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	var all_enemy_ids = EntityManager.get_all_enemy_ids()
	all_enemy_ids.sort()

	for enemy_id in all_enemy_ids:
		var enemy_data = EntityManager.get_enemy_definition(enemy_id)
		var display_name = enemy_data.get("name", enemy_id) if enemy_data else enemy_id
		items.append({"type": "command", "text": display_name, "id": enemy_id})

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Creature", items)

func _show_hazard_submenu() -> void:
	pending_command = "spawn_hazard"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	for hazard_id in HazardManager.hazard_definitions:
		var hazard_def = HazardManager.hazard_definitions[hazard_id]
		var display_name = hazard_def.get("name", hazard_id)
		items.append({"type": "command", "text": display_name, "id": hazard_id})

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Hazard", items)

func _show_feature_submenu() -> void:
	pending_command = "spawn_feature"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	for feature_id in FeatureManager.feature_definitions:
		var feature_def = FeatureManager.feature_definitions[feature_id]
		var display_name = feature_def.get("name", feature_id)
		items.append({"type": "command", "text": display_name, "id": feature_id})

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Feature", items)

func _show_gold_submenu() -> void:
	pending_command = "give_gold"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = [
		{"type": "command", "text": "100 Gold", "amount": 100},
		{"type": "command", "text": "500 Gold", "amount": 500},
		{"type": "command", "text": "1,000 Gold", "amount": 1000},
		{"type": "command", "text": "5,000 Gold", "amount": 5000},
		{"type": "command", "text": "10,000 Gold", "amount": 10000},
	]

	current_state = MenuState.AMOUNT_SELECT
	selected_index = 0
	_build_submenu("Select Amount", items)

func _show_level_submenu() -> void:
	pending_command = "set_level"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	for level in [1, 5, 10, 15, 20, 25, 30, 40, 50]:
		items.append({"type": "command", "text": "Level %d" % level, "amount": level})

	current_state = MenuState.AMOUNT_SELECT
	selected_index = 0
	_build_submenu("Select Level", items)

# ============================================================================
# Submenu execution
# ============================================================================

func _execute_submenu_selection(item: Dictionary) -> void:
	pending_item_id = item.get("id", "")

	match pending_command:
		"give":
			_do_give_item(pending_item_id)
			_go_back()
		"spawn":
			# Need direction
			current_state = MenuState.DIRECTION_SELECT
			direction_prompt.visible = true
			header.text = "Spawn: %s" % item.text
		"spawn_creature", "spawn_hazard", "spawn_feature":
			# Need direction
			current_state = MenuState.DIRECTION_SELECT
			direction_prompt.visible = true
			header.text = "Spawn: %s" % item.text

func _execute_amount_selection(item: Dictionary) -> void:
	var amount = item.get("amount", 0)

	match pending_command:
		"give_gold":
			_do_give_gold(amount)
		"set_level":
			_do_set_level(amount)

	_go_back()

func _execute_with_direction(direction: Vector2i) -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	var target_pos = player.position + direction

	match pending_command:
		"spawn":
			_do_spawn_item(pending_item_id, target_pos)
		"spawn_creature":
			_do_spawn_creature(pending_item_id, target_pos)
		"spawn_hazard":
			_do_spawn_hazard(pending_item_id, target_pos)
		"spawn_feature":
			_do_spawn_feature(pending_item_id, target_pos)

	direction_prompt.visible = false
	_go_back()

# ============================================================================
# Command implementations
# ============================================================================

func _do_give_item(item_id: String) -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	var item = ItemManager.create_item(item_id)
	if item:
		if player.inventory.add_item(item):
			_show_message("Added: %s" % item.name)
		else:
			_show_message("Inventory full!")
	else:
		_show_message("Error: Could not create item '%s'" % item_id)

func _do_spawn_item(item_id: String, pos: Vector2i) -> void:
	var item = ItemManager.create_item(item_id)
	if item:
		EntityManager.spawn_ground_item(item, pos)
		_show_message("Spawned: %s at %v" % [item.name, pos])

func _do_spawn_creature(enemy_id: String, pos: Vector2i) -> void:
	var enemy = EntityManager.spawn_enemy(enemy_id, pos)
	if enemy:
		_show_message("Spawned: %s at %v" % [enemy.name, pos])

func _do_spawn_hazard(hazard_id: String, pos: Vector2i) -> void:
	var hazard_def = HazardManager.hazard_definitions.get(hazard_id, {})
	if hazard_def.is_empty():
		return

	HazardManager.active_hazards[pos] = {
		"id": hazard_id,
		"definition": hazard_def,
		"detected": true,  # Make it visible for debug
		"disarmed": false
	}
	_show_message("Spawned hazard: %s at %v" % [hazard_def.get("name", hazard_id), pos])

func _do_spawn_feature(feature_id: String, pos: Vector2i) -> void:
	var feature_def = FeatureManager.feature_definitions.get(feature_id, {})
	if feature_def.is_empty():
		return

	FeatureManager.active_features[pos] = {
		"id": feature_id,
		"definition": feature_def,
		"interacted": false,
		"looted": false
	}
	_show_message("Spawned feature: %s at %v" % [feature_def.get("name", feature_id), pos])

func _do_give_gold(amount: int) -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	player.gold += amount
	_show_message("Added %d gold (Total: %d)" % [amount, player.gold])

func _do_set_level(level: int) -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	player.level = level
	_show_message("Level set to %d" % level)

func _do_max_stats() -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	player.current_health = player.max_health
	if player.survival:
		player.survival.hunger = 100.0
		player.survival.thirst = 100.0
		player.survival.stamina = player.survival.max_stamina
		player.survival.fatigue = 0.0
		player.survival.mana = player.survival.max_mana
	_show_message("All stats maxed!")

func _do_learn_all_spells() -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	var count = 0
	for spell_id in SpellManager.spells:
		if spell_id not in player.known_spells:
			player.known_spells.append(spell_id)
			count += 1

	_show_message("Learned %d spells!" % count)

func _do_learn_all_recipes() -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	var count = 0
	for recipe_id in RecipeManager.all_recipes:
		if recipe_id not in player.known_recipes:
			player.known_recipes.append(recipe_id)
			count += 1

	_show_message("Learned %d recipes!" % count)

func _do_toggle_god_mode() -> void:
	GameManager.debug_god_mode = not GameManager.debug_god_mode
	var status = "ENABLED" if GameManager.debug_god_mode else "DISABLED"
	_show_message("God Mode: %s" % status)

func _do_teleport_town() -> void:
	if not player or not MapManager.current_map:
		_show_message("Error: No player or map")
		return

	if MapManager.current_map.has_meta("town_center"):
		var town_center = MapManager.current_map.get_meta("town_center")
		player.position = town_center + Vector2i(0, 12)  # Just outside town
		EventBus.player_moved.emit(player.position, player.position)
		_show_message("Teleported to town!")
	else:
		_show_message("No town found on this map")

func _do_reveal_map() -> void:
	GameManager.debug_map_revealed = not GameManager.debug_map_revealed
	var status = "ENABLED" if GameManager.debug_map_revealed else "DISABLED"
	_show_message("Map Reveal: %s" % status)

# ============================================================================
# UI building
# ============================================================================

func _build_main_menu() -> void:
	header.text = "~ DEBUG COMMANDS ~"
	_clear_command_list()

	for i in range(main_menu.size()):
		var item = main_menu[i]
		_add_menu_item(item, i == selected_index)

	# Skip to first command if on a category
	if main_menu[selected_index].type == "category":
		_navigate(1)

func _build_submenu(title: String, items: Array) -> void:
	submenu_title = title
	submenu_items = items
	header.text = "~ %s ~" % title.to_upper()
	_clear_command_list()

	for i in range(items.size()):
		var item = items[i]
		_add_menu_item(item, i == selected_index)

func _clear_command_list() -> void:
	for child in command_list.get_children():
		child.queue_free()

func _add_menu_item(item: Dictionary, is_selected: bool) -> void:
	var label = Label.new()
	label.text = "  %s" % item.text if item.type == "command" else item.text

	if item.type == "category":
		label.add_theme_color_override("font_color", COLOR_CATEGORY)
		label.add_theme_font_size_override("font_size", 14)
	elif is_selected:
		label.text = "> %s" % item.text
		label.add_theme_color_override("font_color", COLOR_SELECTED)
		label.add_theme_font_size_override("font_size", 14)
	else:
		label.add_theme_color_override("font_color", COLOR_COMMAND)
		label.add_theme_font_size_override("font_size", 14)

	command_list.add_child(label)

func _update_selection() -> void:
	var items = _get_current_items()
	var children = command_list.get_children()

	for i in range(min(items.size(), children.size())):
		var item = items[i]
		var label = children[i] as Label
		if not label:
			continue

		if item.type == "category":
			label.text = item.text
			label.add_theme_color_override("font_color", COLOR_CATEGORY)
		elif i == selected_index:
			label.text = "> %s" % item.text
			label.add_theme_color_override("font_color", COLOR_SELECTED)
		else:
			label.text = "  %s" % item.text
			label.add_theme_color_override("font_color", COLOR_COMMAND)

# ============================================================================
# Helpers
# ============================================================================

func _show_message(text: String) -> void:
	EventBus.message_logged.emit("[DEBUG] %s" % text, Color(0.9, 0.5, 0.3))
