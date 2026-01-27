extends Control
class_name DebugCommandMenu

## DebugCommandMenu - Developer tools for testing and debugging
##
## Provides commands for spawning items, creatures, hazards, features,
## and modifying player state during gameplay.
## Uses tabbed interface with Items, Spawning, Player, and World tabs.

const NumberInputClass = preload("res://ui/components/number_input.gd")

signal closed()
signal action_completed()  # Emitted when a debug action is executed (to trigger render refresh)

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var items_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Items
@onready var items_tab: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Items/ItemsList
@onready var spawning_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Spawning
@onready var spawning_tab: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Spawning/SpawningList
@onready var player_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Player
@onready var player_tab: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Player/PlayerList
@onready var world_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/World
@onready var world_tab: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/World/WorldList
@onready var direction_prompt: Label = $Panel/MarginContainer/VBoxContainer/DirectionPrompt
@onready var distance_input = $Panel/MarginContainer/VBoxContainer/DistanceInput
@onready var header: Label = $Panel/MarginContainer/VBoxContainer/Header
@onready var info_panel: VBoxContainer = $Panel/MarginContainer/VBoxContainer/InfoPanel
@onready var info_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/InfoPanel/InfoLabel
@onready var filter_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/FilterContainer
@onready var filter_label: Label = $Panel/MarginContainer/VBoxContainer/FilterContainer/FilterLabel
@onready var filter_display: Label = $Panel/MarginContainer/VBoxContainer/FilterContainer/FilterDisplay

# Menu state
enum MenuState { TABS, SUBMENU, DIRECTION_SELECT, DISTANCE_SELECT, AMOUNT_SELECT, CUSTOM_INPUT, STAT_SELECT, SKILL_SELECT }
var current_state: MenuState = MenuState.TABS
var selected_index: int = 0
var menu_stack: Array = []  # For nested menus

# Current submenu data
var submenu_items: Array = []
var submenu_items_unfiltered: Array = []  # Original list before filtering
var submenu_title: String = ""
var pending_command: String = ""
var pending_item_id: String = ""
var pending_direction: Vector2i = Vector2i.ZERO
var pending_item_name: String = ""
var filter_text: String = ""  # Text filter for submenus

# Custom input data
var custom_input_label: String = ""
var custom_input_min: int = 1
var custom_input_max: int = 999
var custom_input_default: int = 1

# Stat/skill editing
var editing_stat_key: String = ""  # The stat or skill being edited

# Coordinate input for teleportation
var pending_coord_x: int = 0
var pending_coord_y: int = 0
var coord_input_stage: String = ""  # "x" or "y"

# Player reference (set when menu opens)
var player: Player = null

# Colors
const COLOR_CATEGORY = Color(0.9, 0.5, 0.3, 1)
const COLOR_COMMAND = Color(0.8, 0.8, 0.8, 1)
const COLOR_SELECTED = Color(0.9, 0.9, 0.5, 1)
const COLOR_DISABLED = Color(0.5, 0.5, 0.5, 1)

# Tab definitions - commands organized by tab
var tab_commands: Dictionary = {
	0: [  # Items tab
		{"text": "Give Item", "action": "give_item"},
		{"text": "Spawn Item on Ground", "action": "spawn_item"},
	],
	1: [  # Spawning tab
		{"text": "Spawn Creature", "action": "spawn_creature"},
		{"text": "Spawn Hazard", "action": "spawn_hazard"},
		{"text": "Spawn Feature", "action": "spawn_feature"},
		{"text": "Spawn Structure", "action": "spawn_structure"},
		{"text": "Spawn Resource", "action": "spawn_resource"},
	],
	2: [  # Player tab
		{"text": "Give Gold", "action": "give_gold"},
		{"text": "Set Level", "action": "set_level"},
		{"text": "Set Abilities", "action": "set_abilities"},
		{"text": "Set Skills", "action": "set_skills"},
		{"text": "Max All Stats", "action": "max_stats"},
		{"text": "Learn Spell", "action": "learn_spell"},
		{"text": "Learn Recipe", "action": "learn_recipe"},
		{"text": "Learn Ritual", "action": "learn_ritual"},
		{"text": "Toggle God Mode", "action": "toggle_god_mode"},
	],
	3: [  # World tab
		{"text": "Teleport to Town", "action": "teleport_town"},
		{"text": "Teleport to Coordinates", "action": "teleport_coords"},
		{"text": "Set Date/Time", "action": "set_datetime"},
		{"text": "Convert Tile", "action": "convert_tile"},
		{"text": "Reveal Map", "action": "reveal_map"},
		{"text": "Performance Diagnostics", "action": "perf_diagnostics"},
		{"text": "Toggle Performance Overlay", "action": "toggle_perf_overlay"},
	],
}

# Track selection per tab
var tab_selection: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0}

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect NumberInput signals
	distance_input.value_submitted.connect(_on_distance_submitted)
	distance_input.cancelled.connect(_on_distance_cancelled)
	# Connect tab changed signal
	tab_container.tab_changed.connect(_on_tab_changed)

func _on_tab_changed(_tab: int) -> void:
	selected_index = tab_selection.get(tab_container.current_tab, 0)
	_build_current_tab()

func _on_distance_submitted(_value: int) -> void:
	if current_state == MenuState.DISTANCE_SELECT:
		_execute_spawn_with_distance()
	elif current_state == MenuState.CUSTOM_INPUT:
		_execute_custom_input()

func _on_distance_cancelled() -> void:
	distance_input.visible = false
	distance_input.deactivate()
	if current_state == MenuState.DISTANCE_SELECT:
		direction_prompt.visible = true
		current_state = MenuState.DIRECTION_SELECT
	elif current_state == MenuState.CUSTOM_INPUT:
		_go_back()

func _execute_custom_input() -> void:
	var value = distance_input.get_value()
	distance_input.visible = false
	distance_input.deactivate()

	match pending_command:
		"give_gold":
			_do_give_gold(value)
			_go_back()
			_go_back()  # Back to tabs
		"set_level":
			_do_set_level(value)
			_go_back()
			_go_back()  # Back to tabs
		"set_ability":
			if player and editing_stat_key != "":
				player.attributes[editing_stat_key] = value
				_show_message("Set %s to %d" % [editing_stat_key, value])
			# Refresh abilities list
			_show_abilities_submenu()
			menu_stack.pop_back()  # Remove duplicate stack entry
		"set_skill":
			if player and editing_stat_key != "":
				player.skills[editing_stat_key] = value
				var skill_def = SkillManager.get_skill(editing_stat_key)
				var skill_name = skill_def.name if skill_def else editing_stat_key
				_show_message("Set %s to %d" % [skill_name, value])
			# Refresh skills list
			_show_skills_submenu()
			menu_stack.pop_back()  # Remove duplicate stack entry
		"teleport_x":
			pending_coord_x = value
			pending_command = "teleport_y"
			coord_input_stage = "y"
			var default_y = player.position.y if player else 50
			_show_custom_input("Enter Y coordinate:", 0, 999, default_y)
			menu_stack.pop_back()  # Remove duplicate from showing another input
		"teleport_y":
			pending_coord_y = value
			_do_teleport_coords(pending_coord_x, pending_coord_y)
			_go_back()
			_go_back()  # Back to tabs
		"set_year_value":
			CalendarManager.current_year = value
			_show_message("Year set to %d" % value)
			_go_back()
			_go_back()
		"set_day_value":
			CalendarManager.current_day = clampi(value, 1, 28)
			_show_message("Day set to %d" % CalendarManager.current_day)
			_go_back()
			_go_back()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		# Handle DISTANCE_SELECT and CUSTOM_INPUT states manually since LineEdit doesn't work while paused
		if current_state == MenuState.DISTANCE_SELECT or current_state == MenuState.CUSTOM_INPUT:
			_handle_distance_input(event, viewport)
			return

		match current_state:
			MenuState.TABS:
				_handle_tabs_input(event, viewport)
			MenuState.SUBMENU, MenuState.AMOUNT_SELECT:
				_handle_submenu_input(event, viewport)
			MenuState.DIRECTION_SELECT:
				_handle_direction_input(event, viewport)
			MenuState.STAT_SELECT, MenuState.SKILL_SELECT:
				_handle_stat_skill_input(event, viewport)

func _handle_distance_input(event: InputEventKey, viewport: Viewport) -> void:
	# Use the NumberInput component's input handler
	if distance_input.handle_input(event):
		viewport.set_input_as_handled()

func _handle_tabs_input(event: InputEventKey, viewport: Viewport) -> void:
	match event.keycode:
		KEY_ESCAPE:
			close()
			viewport.set_input_as_handled()
		KEY_TAB:
			# Switch tabs (SHIFT+TAB = previous, TAB = next)
			if event.shift_pressed:
				var prev_tab = (tab_container.current_tab - 1 + tab_container.get_tab_count()) % tab_container.get_tab_count()
				tab_container.current_tab = prev_tab
			else:
				var next_tab = (tab_container.current_tab + 1) % tab_container.get_tab_count()
				tab_container.current_tab = next_tab
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

func _handle_submenu_input(event: InputEventKey, viewport: Viewport) -> void:
	match event.keycode:
		KEY_ESCAPE:
			_go_back()
			viewport.set_input_as_handled()
		KEY_BACKSPACE:
			# In submenu with filter text, remove last character
			if filter_text.length() > 0:
				filter_text = filter_text.substr(0, filter_text.length() - 1)
				_apply_filter()
				viewport.set_input_as_handled()
			else:
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
		_:
			# Handle letter keys for filtering in submenu mode
			if current_state == MenuState.SUBMENU:
				var char_typed = _get_char_from_keycode(event)
				if char_typed != "":
					filter_text += char_typed
					_apply_filter()
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
		# Store direction and transition to distance input
		pending_direction = direction
		_show_distance_input()
		viewport.set_input_as_handled()

func _handle_stat_skill_input(event: InputEventKey, viewport: Viewport) -> void:
	match event.keycode:
		KEY_ESCAPE:
			_go_back()
			viewport.set_input_as_handled()
		KEY_BACKSPACE:
			_go_back()
			viewport.set_input_as_handled()
		KEY_UP:
			_navigate(-1)
			viewport.set_input_as_handled()
		KEY_DOWN:
			_navigate(1)
			viewport.set_input_as_handled()
		KEY_ENTER:
			_execute_stat_skill_selection()
			viewport.set_input_as_handled()

func _show_distance_input() -> void:
	current_state = MenuState.DISTANCE_SELECT
	direction_prompt.visible = false
	distance_input.visible = true

	# Set default distance: 1 for items, 3 for creatures
	var default_distance = 1
	if pending_command == "spawn_creature":
		default_distance = 3

	distance_input.default_value = default_distance
	distance_input.activate(default_distance)

	# Update header to show direction
	var dir_name = _get_direction_name(pending_direction)
	header.text = "Spawn %s %s - Enter distance:" % [pending_item_name, dir_name]

func _get_direction_name(dir: Vector2i) -> String:
	match dir:
		Vector2i.LEFT:
			return "←"
		Vector2i.RIGHT:
			return "→"
		Vector2i.UP:
			return "↑"
		Vector2i.DOWN:
			return "↓"
	return ""

func _execute_spawn_with_distance() -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	var distance = distance_input.get_value()
	var target_pos = player.position + (pending_direction * distance)

	match pending_command:
		"spawn":
			_do_spawn_item(pending_item_id, target_pos)
		"spawn_creature":
			_do_spawn_creature(pending_item_id, target_pos)
		"spawn_hazard":
			_do_spawn_hazard(pending_item_id, target_pos)
		"spawn_feature":
			_do_spawn_feature(pending_item_id, target_pos)
		"spawn_structure":
			_do_spawn_structure(pending_item_id, target_pos)
		"spawn_resource":
			_do_spawn_resource(pending_item_id, target_pos)
		"convert_tile":
			_do_convert_tile(pending_item_id, target_pos)

	distance_input.visible = false
	distance_input.deactivate()
	close()
	action_completed.emit()

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

	current_state = MenuState.TABS
	selected_index = tab_selection.get(tab_container.current_tab, 0)
	menu_stack.clear()
	pending_direction = Vector2i.ZERO
	pending_item_name = ""
	filter_text = ""
	submenu_items_unfiltered.clear()
	direction_prompt.visible = false
	distance_input.visible = false
	info_panel.visible = false
	if filter_container:
		filter_container.visible = false
	header.text = "~ DEBUG COMMANDS ~"
	_build_current_tab()
	show()
	get_tree().paused = true

func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()

func _go_back() -> void:
	# Handle custom input going back
	if current_state == MenuState.CUSTOM_INPUT:
		distance_input.visible = false
		distance_input.deactivate()
		# Restore label for distance input
		distance_input.set_label("Distance (tiles): ")
		distance_input.min_value = 1
		distance_input.max_value = 999
		# Go back to previous state
		if menu_stack.size() > 0:
			var prev_state = menu_stack.pop_back()
			current_state = prev_state.state
			selected_index = prev_state.index
			if current_state == MenuState.TABS:
				_build_current_tab()
			elif current_state == MenuState.STAT_SELECT:
				_show_abilities_submenu()
				menu_stack.pop_back()  # Remove duplicate
			elif current_state == MenuState.SKILL_SELECT:
				_show_skills_submenu()
				menu_stack.pop_back()  # Remove duplicate
			else:
				_build_submenu(prev_state.title, prev_state.items)
		else:
			current_state = MenuState.TABS
			_build_current_tab()
		header.text = "~ DEBUG COMMANDS ~"
		return

	# Handle distance select going back to direction select
	if current_state == MenuState.DISTANCE_SELECT:
		distance_input.visible = false
		distance_input.deactivate()
		direction_prompt.visible = true
		current_state = MenuState.DIRECTION_SELECT
		header.text = "Spawn: %s - Choose direction" % pending_item_name
		return

	# Handle direction select going back to submenu
	if current_state == MenuState.DIRECTION_SELECT:
		direction_prompt.visible = false
		current_state = MenuState.SUBMENU
		_build_submenu(submenu_title, submenu_items_unfiltered)
		return

	if menu_stack.size() > 0:
		var prev_state = menu_stack.pop_back()
		current_state = prev_state.state
		selected_index = prev_state.index
		if current_state == MenuState.TABS:
			_build_current_tab()
		else:
			_build_submenu(prev_state.title, prev_state.items)
	else:
		current_state = MenuState.TABS
		_build_current_tab()

	direction_prompt.visible = false
	distance_input.visible = false
	info_panel.visible = false
	if filter_container:
		filter_container.visible = false
	header.text = "~ DEBUG COMMANDS ~"

func _navigate(direction: int) -> void:
	var items = _get_current_items()
	var new_index = selected_index + direction

	# Clamp to valid range
	if new_index >= 0 and new_index < items.size():
		selected_index = new_index
		# Save selection for current tab
		if current_state == MenuState.TABS:
			tab_selection[tab_container.current_tab] = selected_index
		_update_selection()

func _get_current_items() -> Array:
	if current_state == MenuState.TABS:
		return tab_commands.get(tab_container.current_tab, [])
	else:
		return submenu_items

func _execute_selected() -> void:
	var items = _get_current_items()
	if selected_index < 0 or selected_index >= items.size():
		return

	var item = items[selected_index]

	if current_state == MenuState.TABS:
		_execute_tab_command(item.action)
	elif current_state == MenuState.SUBMENU:
		_execute_submenu_selection(item)
	elif current_state == MenuState.AMOUNT_SELECT:
		_execute_amount_selection(item)

func _execute_tab_command(action: String) -> void:
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
		"spawn_structure":
			_show_structure_submenu()
		"spawn_resource":
			_show_resource_submenu()
		"give_gold":
			_show_gold_submenu()
		"set_level":
			_show_level_submenu()
		"set_abilities":
			_show_abilities_submenu()
		"set_skills":
			_show_skills_submenu()
		"max_stats":
			_do_max_stats()
		"learn_spell":
			_show_spell_submenu()
		"learn_recipe":
			_show_recipe_submenu()
		"learn_ritual":
			_show_ritual_submenu()
		"toggle_god_mode":
			_do_toggle_god_mode()
		"teleport_town":
			_do_teleport_town()
		"teleport_coords":
			_show_teleport_coords_input()
		"set_datetime":
			_show_datetime_submenu()
		"convert_tile":
			_show_tile_submenu()
		"reveal_map":
			_do_reveal_map()
		"perf_diagnostics":
			_show_performance_diagnostics()
		"toggle_perf_overlay":
			EventBus.debug_toggle_perf_overlay.emit()
			_go_back()
			closed.emit()

# ============================================================================
# Submenu builders
# ============================================================================

func _show_item_submenu(mode: String) -> void:
	pending_command = mode
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []

	# Add legacy items from ItemManager
	var all_item_ids = ItemManager.get_all_item_ids()
	for item_id in all_item_ids:
		var item_data = ItemManager.get_item_data(item_id)
		var display_name = item_data.get("name", item_id) if item_data else item_id
		items.append({"type": "command", "text": display_name, "id": item_id, "name": display_name})

	# Add templated items from VariantManager
	var templated_items = VariantManager.get_all_templated_item_ids()
	for templated_item in templated_items:
		var item_id = templated_item.get("id", "")
		var display_name = templated_item.get("display_name", item_id)
		# Mark templated items with category in display
		var template_id = templated_item.get("template_id", "")
		var text = "%s [%s]" % [display_name, template_id]
		items.append({"type": "command", "text": text, "id": item_id, "name": display_name})

	# Sort alphabetically by name
	items.sort_custom(func(a, b): return a.name < b.name)

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Item", items)

func _show_creature_submenu() -> void:
	pending_command = "spawn_creature"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	var all_enemy_ids = EntityManager.get_all_enemy_ids()

	# Build items with CR and creature type data for sorting
	for enemy_id in all_enemy_ids:
		var enemy_data = EntityManager.get_enemy_definition(enemy_id)
		if not enemy_data:
			continue
		var display_name = enemy_data.get("name", enemy_id)
		var cr = enemy_data.get("cr", 0)  # CR stored as "cr" in JSON
		var creature_type = enemy_data.get("creature_type", "humanoid")
		var type_abbrev = CreatureTypeManager.get_type_abbreviation(creature_type)
		# Show CR and creature type in the display text
		var cr_str = _format_cr(cr)
		var text = "%s (CR %s) [%s]" % [display_name, cr_str, type_abbrev]
		items.append({
			"type": "command",
			"text": text,
			"id": enemy_id,
			"cr": cr,
			"name": display_name,
			"creature_type": creature_type
		})

	# Sort by CR ascending, then by creature type, then by name alphabetically
	items.sort_custom(func(a, b):
		if a.cr != b.cr:
			return a.cr < b.cr
		if a.creature_type != b.creature_type:
			return a.creature_type < b.creature_type
		return a.name < b.name
	)

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
		var difficulty = hazard_def.get("detection_difficulty", 0)
		var text = "%s (DC %d)" % [display_name, difficulty] if difficulty > 0 else display_name
		items.append({"type": "command", "text": text, "id": hazard_id, "difficulty": difficulty, "name": display_name})

	# Sort by difficulty first, then alphabetically by name
	items.sort_custom(func(a, b):
		if a.difficulty != b.difficulty:
			return a.difficulty < b.difficulty
		return a.name < b.name
	)

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
		items.append({"type": "command", "text": display_name, "id": feature_id, "name": display_name})

	# Sort alphabetically by name
	items.sort_custom(func(a, b): return a.name < b.name)

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
		{"type": "command", "text": "Custom Amount...", "amount": -1},
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
	items.append({"type": "command", "text": "Custom Level...", "amount": -1})

	current_state = MenuState.AMOUNT_SELECT
	selected_index = 0
	_build_submenu("Select Level", items)

func _show_abilities_submenu() -> void:
	pending_command = "set_ability"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	if not player:
		_show_message("Error: No player reference")
		return

	var items: Array = []
	var ability_names = {"STR": "Strength", "DEX": "Dexterity", "CON": "Constitution",
						 "INT": "Intelligence", "WIS": "Wisdom", "CHA": "Charisma"}

	for key in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		var current_val = player.attributes.get(key, 10)
		items.append({
			"type": "command",
			"text": "%s (%s): %d" % [ability_names[key], key, current_val],
			"key": key,
			"value": current_val
		})

	current_state = MenuState.STAT_SELECT
	selected_index = 0
	_build_submenu("Set Abilities", items)

func _show_skills_submenu() -> void:
	pending_command = "set_skill"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	if not player:
		_show_message("Error: No player reference")
		return

	var items: Array = []
	var skill_ids = SkillManager.get_all_skill_ids()
	skill_ids.sort()

	for skill_id in skill_ids:
		var skill_def = SkillManager.get_skill(skill_id)
		var skill_name = skill_def.name if skill_def else skill_id
		var current_val = player.skills.get(skill_id, 0)
		items.append({
			"type": "command",
			"text": "%s: %d" % [skill_name, current_val],
			"key": skill_id,
			"value": current_val
		})

	current_state = MenuState.SKILL_SELECT
	selected_index = 0
	_build_submenu("Set Skills", items)

func _show_spell_submenu() -> void:
	pending_command = "learn_spell"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	if not player:
		_show_message("Error: No player reference")
		return

	var items: Array = []
	var all_spell_ids = SpellManager.get_all_spell_ids()

	# Build items with level/school data for sorting
	for spell_id in all_spell_ids:
		var spell = SpellManager.get_spell(spell_id)
		if not spell:
			continue
		var known = spell_id in player.known_spells
		var level_str = "Cantrip" if spell.level == 0 else "L%d" % spell.level
		var status_str = " [KNOWN]" if known else ""
		var text = "%s (%s %s)%s" % [spell.name, spell.school.capitalize(), level_str, status_str]
		items.append({
			"type": "command",
			"text": text,
			"id": spell_id,
			"level": spell.level,
			"school": spell.school,
			"name": spell.name,
			"known": known
		})

	# Sort by level, then by school, then by name
	items.sort_custom(func(a, b):
		if a.level != b.level:
			return a.level < b.level
		if a.school != b.school:
			return a.school < b.school
		return a.name < b.name
	)

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Learn Spell", items)

func _show_recipe_submenu() -> void:
	pending_command = "learn_recipe"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	if not player:
		_show_message("Error: No player reference")
		return

	var items: Array = []
	var all_recipe_ids = RecipeManager.get_all_recipe_ids()

	for recipe_id in all_recipe_ids:
		var recipe = RecipeManager.get_recipe(recipe_id)
		if not recipe:
			continue
		var known = recipe_id in player.known_recipes
		var display_name = recipe.get_display_name()
		var difficulty = recipe.difficulty if recipe.difficulty else 1
		var status_str = " [KNOWN]" if known else ""
		var text = "%s (Diff %d)%s" % [display_name, difficulty, status_str]
		items.append({
			"type": "command",
			"text": text,
			"id": recipe_id,
			"name": display_name,
			"difficulty": difficulty,
			"known": known
		})

	# Sort by difficulty first, then alphabetically by name
	items.sort_custom(func(a, b):
		if a.difficulty != b.difficulty:
			return a.difficulty < b.difficulty
		return a.name < b.name
	)

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Learn Recipe", items)

func _show_ritual_submenu() -> void:
	pending_command = "learn_ritual"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	if not player:
		_show_message("Error: No player reference")
		return

	var items: Array = []
	var all_rituals = RitualManager.get_all_rituals()

	for ritual in all_rituals:
		var known = ritual.id in player.known_rituals
		var rarity_str = ritual.rarity.capitalize() if ritual.rarity else "Common"
		var status_str = " [KNOWN]" if known else ""
		var text = "%s (%s %s)%s" % [ritual.name, ritual.school.capitalize(), rarity_str, status_str]
		items.append({
			"type": "command",
			"text": text,
			"id": ritual.id,
			"name": ritual.name,
			"school": ritual.school,
			"rarity": ritual.rarity,
			"known": known
		})

	# Sort by rarity (common < uncommon < rare < very_rare), then school, then name
	var rarity_order = {"common": 0, "uncommon": 1, "rare": 2, "very_rare": 3}
	items.sort_custom(func(a, b):
		var rarity_a = rarity_order.get(a.rarity, 0)
		var rarity_b = rarity_order.get(b.rarity, 0)
		if rarity_a != rarity_b:
			return rarity_a < rarity_b
		if a.school != b.school:
			return a.school < b.school
		return a.name < b.name
	)

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Learn Ritual", items)

func _show_structure_submenu() -> void:
	pending_command = "spawn_structure"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	for structure_id in StructureManager.structure_definitions:
		var structure_def = StructureManager.structure_definitions[structure_id]
		var display_name = structure_def.get("name", structure_id)
		items.append({"type": "command", "text": display_name, "id": structure_id, "name": display_name})

	# Sort alphabetically by name
	items.sort_custom(func(a, b): return a.name < b.name)

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Structure", items)

func _show_resource_submenu() -> void:
	pending_command = "spawn_resource"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	# Get resource definitions from HarvestSystem
	var resource_defs = HarvestSystem._resource_definitions
	for resource_id in resource_defs:
		var resource = resource_defs[resource_id]
		var display_name = resource.name if resource else resource_id
		items.append({"type": "command", "text": display_name, "id": resource_id, "name": display_name})

	# Sort alphabetically by name
	items.sort_custom(func(a, b): return a.name < b.name)

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Resource", items)

func _show_tile_submenu() -> void:
	pending_command = "convert_tile"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = []
	var tile_types = TileTypeManager.get_all_tile_types()

	for tile_id in tile_types:
		var tile_def = TileTypeManager.get_tile_definition(tile_id)
		var display_name = tile_def.get("display_name", tile_id.replace("_", " ").capitalize())
		var ascii_char = tile_def.get("ascii_char", "?")
		var text = "%s [%s]" % [display_name, ascii_char]
		items.append({"type": "command", "text": text, "id": tile_id, "name": display_name})

	# Sort alphabetically by name
	items.sort_custom(func(a, b): return a.name < b.name)

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Tile Type", items)

func _show_teleport_coords_input() -> void:
	pending_command = "teleport_x"
	coord_input_stage = "x"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	# Get current player position as default
	var default_x = player.position.x if player else 50
	_show_custom_input("Enter X coordinate:", 0, 999, default_x)

func _show_datetime_submenu() -> void:
	pending_command = "set_datetime"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var items: Array = [
		{"type": "command", "text": "Set Year", "action": "set_year"},
		{"type": "command", "text": "Set Season", "action": "set_season"},
		{"type": "command", "text": "Set Day", "action": "set_day"},
		{"type": "command", "text": "Set Time of Day", "action": "set_time"},
		{"type": "command", "text": "Set Weather", "action": "set_weather"},
	]

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Set Date/Time", items)

func _show_season_submenu() -> void:
	pending_command = "select_season"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var seasons = CalendarManager.calendar_data.get("seasons", [])
	var items: Array = []
	for i in range(seasons.size()):
		var season = seasons[i]
		var current = " [CURRENT]" if i == CalendarManager.current_season_index else ""
		items.append({
			"type": "command",
			"text": "%s%s" % [season.get("name", "Unknown"), current],
			"index": i
		})

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Season", items)

func _show_time_submenu() -> void:
	pending_command = "select_time"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	var time_periods = CalendarManager.get_time_periods()
	var current_time = TurnManager.get_time_of_day()
	var items: Array = []

	for period in time_periods:
		var period_id = period.get("id", "unknown")
		var current = " [CURRENT]" if period_id == current_time else ""
		items.append({
			"type": "command",
			"text": "%s%s" % [period_id.capitalize(), current],
			"id": period_id,
			"start": period.get("start", 0)
		})

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Time of Day", items)

func _show_weather_submenu() -> void:
	pending_command = "select_weather"
	menu_stack.append({"state": current_state, "index": selected_index, "title": "", "items": []})

	# Get weather types from WeatherManager definitions
	var items: Array = []
	var current_weather_id = WeatherManager.current_weather_id if WeatherManager else "clear"

	for weather_id in WeatherManager.weather_definitions:
		var weather_def = WeatherManager.weather_definitions[weather_id]
		var display_name = weather_def.get("name", weather_id.replace("_", " ").capitalize())
		var current = " [CURRENT]" if weather_id == current_weather_id else ""
		items.append({
			"type": "command",
			"text": "%s%s" % [display_name, current],
			"id": weather_id
		})

	# Sort alphabetically
	items.sort_custom(func(a, b): return a.text < b.text)

	current_state = MenuState.SUBMENU
	selected_index = 0
	_build_submenu("Select Weather", items)

# ============================================================================
# Submenu execution
# ============================================================================

func _execute_submenu_selection(item: Dictionary) -> void:
	pending_item_id = item.get("id", "")
	pending_item_name = item.get("text", pending_item_id)

	match pending_command:
		"give":
			_do_give_item(pending_item_id)
			_go_back()
		"spawn", "spawn_creature", "spawn_hazard", "spawn_feature", "spawn_structure", "spawn_resource", "convert_tile":
			# Need direction, then distance
			current_state = MenuState.DIRECTION_SELECT
			direction_prompt.visible = true
			var action_verb = "Convert to" if pending_command == "convert_tile" else "Spawn"
			header.text = "%s: %s - Choose direction" % [action_verb, pending_item_name]
		"learn_spell":
			_do_learn_spell(pending_item_id)
			# Refresh the submenu to show updated [KNOWN] status
			_show_spell_submenu()
			menu_stack.pop_back()  # Remove duplicate stack entry
		"learn_recipe":
			_do_learn_recipe(pending_item_id)
			# Refresh the submenu to show updated [KNOWN] status
			_show_recipe_submenu()
			menu_stack.pop_back()  # Remove duplicate stack entry
		"learn_ritual":
			_do_learn_ritual(pending_item_id)
			# Refresh the submenu to show updated [KNOWN] status
			_show_ritual_submenu()
			menu_stack.pop_back()  # Remove duplicate stack entry
		"set_datetime":
			# Handle datetime submenu actions
			var action = item.get("action", "")
			match action:
				"set_year":
					pending_command = "set_year_value"
					_show_custom_input("Enter year:", 1, 9999, CalendarManager.current_year)
				"set_season":
					_show_season_submenu()
				"set_day":
					pending_command = "set_day_value"
					_show_custom_input("Enter day (1-28):", 1, 28, CalendarManager.current_day)
				"set_time":
					_show_time_submenu()
				"set_weather":
					_show_weather_submenu()
		"select_season":
			var season_index = item.get("index", 0)
			CalendarManager.current_season_index = season_index
			CalendarManager.current_month_index = 0  # Reset to first month of season
			_show_message("Season set to %s" % item.text.replace(" [CURRENT]", ""))
			_go_back()
			_go_back()  # Back to datetime submenu, then to tabs
		"select_time":
			var start_turn = item.get("start", 0)
			# Set current_turn to the start of the selected time period
			var turns_per_day = CalendarManager.get_turns_per_day()
			var current_day_turn = TurnManager.current_turn % turns_per_day
			TurnManager.current_turn = TurnManager.current_turn - current_day_turn + start_turn
			TurnManager.time_of_day = item.get("id", "dawn")
			EventBus.time_of_day_changed.emit(TurnManager.time_of_day)
			_show_message("Time set to %s" % item.text.replace(" [CURRENT]", ""))
			_go_back()
			_go_back()
		"select_weather":
			var weather_id = item.get("id", "clear")
			if WeatherManager:
				var old_weather = WeatherManager.current_weather_id
				WeatherManager.current_weather_id = weather_id
				EventBus.weather_changed.emit(old_weather, weather_id, "Debug: Weather changed")
			_show_message("Weather set to %s" % item.text.replace(" [CURRENT]", ""))
			_go_back()
			_go_back()

func _execute_amount_selection(item: Dictionary) -> void:
	var amount = item.get("amount", 0)

	# Handle custom input option
	if amount == -1:
		match pending_command:
			"give_gold":
				_show_custom_input("Enter gold amount:", 1, 999999, 1000)
			"set_level":
				_show_custom_input("Enter level:", 1, 100, 10)
		return

	match pending_command:
		"give_gold":
			_do_give_gold(amount)
		"set_level":
			_do_set_level(amount)

	_go_back()

func _execute_stat_skill_selection() -> void:
	var items = _get_current_items()
	if selected_index < 0 or selected_index >= items.size():
		return

	var item = items[selected_index]
	editing_stat_key = item.get("key", "")
	var current_value = item.get("value", 0)

	match current_state:
		MenuState.STAT_SELECT:
			_show_custom_input("Set %s:" % editing_stat_key, 1, 30, current_value)
		MenuState.SKILL_SELECT:
			_show_custom_input("Set skill level:", 0, 50, current_value)

func _show_custom_input(label: String, min_val: int, max_val: int, default_val: int) -> void:
	custom_input_label = label
	custom_input_min = min_val
	custom_input_max = max_val
	custom_input_default = default_val

	current_state = MenuState.CUSTOM_INPUT
	direction_prompt.visible = false
	distance_input.visible = true

	distance_input.min_value = min_val
	distance_input.max_value = max_val
	distance_input.set_label(label)
	distance_input.activate(default_val)

	header.text = "~ %s ~" % label.to_upper().trim_suffix(":")

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

	# Create hazard data matching HazardManager's expected format
	var hazard_data: Dictionary = {
		"hazard_id": hazard_id,
		"position": pos,
		"definition": hazard_def,
		"config": {},  # Empty config for debug-spawned hazards
		"triggered": false,
		"detected": true,  # Make it visible for debug
		"disarmed": false,
		"damage": hazard_def.get("base_damage", 10)
	}
	HazardManager.active_hazards[pos] = hazard_data
	_show_message("Spawned hazard: %s at %v" % [hazard_def.get("name", hazard_id), pos])

func _do_spawn_feature(feature_id: String, pos: Vector2i) -> void:
	var feature_def = FeatureManager.feature_definitions.get(feature_id, {})
	if feature_def.is_empty():
		return

	# Create feature data structure matching FeatureManager's expected format
	FeatureManager.active_features[pos] = {
		"feature_id": feature_id,
		"position": pos,
		"definition": feature_def,
		"config": {},  # Empty config for debug-spawned features
		"interacted": false,
		"state": {}  # Required state dictionary
	}
	_show_message("Spawned feature: %s at %v" % [feature_def.get("name", feature_id), pos])

func _do_spawn_structure(structure_id: String, pos: Vector2i) -> void:
	var structure = StructureManager.create_structure(structure_id, pos)
	if structure:
		var map_id = MapManager.current_map.map_id if MapManager.current_map else "overworld"
		StructureManager.place_structure(map_id, structure)
		_show_message("Spawned structure: %s at %v" % [structure.structure_name, pos])
	else:
		_show_message("Error: Could not create structure '%s'" % structure_id)

func _do_spawn_resource(resource_id: String, pos: Vector2i) -> void:
	# Resources are represented as tiles with harvestable_resource_id
	# Create a tile of that resource type
	var tile = GameTile.create(resource_id)
	if tile:
		MapManager.current_map.set_tile(pos, tile)
		var resource = HarvestSystem.get_resource(resource_id)
		var resource_name = resource.name if resource else resource_id
		_show_message("Spawned resource: %s at %v" % [resource_name, pos])
	else:
		_show_message("Error: Could not create resource tile '%s'" % resource_id)

func _do_convert_tile(tile_id: String, pos: Vector2i) -> void:
	var tile = GameTile.create(tile_id)
	if tile:
		MapManager.current_map.set_tile(pos, tile)
		var tile_def = TileTypeManager.get_tile_definition(tile_id)
		var display_name = tile_def.get("display_name", tile_id) if tile_def else tile_id
		_show_message("Converted tile at %v to %s" % [pos, display_name])
		# Invalidate FOV cache since transparency may have changed
		FOVSystem.invalidate_cache()
	else:
		_show_message("Error: Could not create tile '%s'" % tile_id)

func _do_learn_ritual(ritual_id: String) -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	if ritual_id in player.known_rituals:
		_show_message("Already know this ritual!")
		return

	var ritual = RitualManager.get_ritual(ritual_id)
	if ritual:
		player.learn_ritual(ritual_id)
		_show_message("Learned: %s" % ritual.name)
	else:
		_show_message("Error: Ritual not found")

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
		player.survival.fatigue = 0.0
		player.survival.stamina = player.survival.get_max_stamina()
		player.survival.mana = player.survival.get_max_mana()
	_show_message("All stats maxed!")

func _do_learn_spell(spell_id: String) -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	if spell_id in player.known_spells:
		_show_message("Already know this spell!")
		return

	var spell = SpellManager.get_spell(spell_id)
	if spell:
		player.known_spells.append(spell_id)
		_show_message("Learned: %s" % spell.name)
	else:
		_show_message("Error: Spell not found")

func _do_learn_recipe(recipe_id: String) -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	if recipe_id in player.known_recipes:
		_show_message("Already know this recipe!")
		return

	var recipe = RecipeManager.get_recipe(recipe_id)
	if recipe:
		player.known_recipes.append(recipe_id)
		_show_message("Learned: %s" % recipe.get_display_name())
	else:
		_show_message("Error: Recipe not found")

func _do_toggle_god_mode() -> void:
	GameManager.debug_god_mode = not GameManager.debug_god_mode
	var status = "ENABLED" if GameManager.debug_god_mode else "DISABLED"
	_show_message("God Mode: %s" % status)
	# Refresh the tab to show updated status
	_build_current_tab()

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

func _do_teleport_coords(x: int, y: int) -> void:
	if not player:
		_show_message("Error: No player reference")
		return

	var target_pos = Vector2i(x, y)
	var old_pos = player.position
	player.position = target_pos
	EventBus.player_moved.emit(old_pos, target_pos)
	_show_message("Teleported to (%d, %d)" % [x, y])
	action_completed.emit()

func _do_reveal_map() -> void:
	GameManager.debug_map_revealed = not GameManager.debug_map_revealed
	var status = "ENABLED" if GameManager.debug_map_revealed else "DISABLED"
	_show_message("Map Reveal: %s" % status)
	# Refresh the tab to show updated status
	_build_current_tab()

func _show_performance_diagnostics() -> void:
	if not player or not MapManager.current_map:
		return

	var diagnostics: Array[String] = []
	diagnostics.append("=== PERFORMANCE DIAGNOSTICS ===")
	diagnostics.append("")

	# Turn information
	diagnostics.append("[TURN INFO]")
	diagnostics.append("Current Turn: %d" % TurnManager.current_turn)
	diagnostics.append("Time of Day: %s" % TurnManager.time_of_day)
	diagnostics.append("")

	# Entity counts
	diagnostics.append("[ENTITIES]")
	diagnostics.append("Total Entities: %d" % EntityManager.entities.size())
	var alive_count = 0
	var dead_count = 0
	var enemies = 0
	var npcs = 0
	var summons = 0
	var crops = 0
	var ground_items = 0
	for entity in EntityManager.entities:
		if entity is GroundItem:
			ground_items += 1
		elif entity.is_alive:
			alive_count += 1
			if entity is Enemy:
				enemies += 1
			elif "is_summon" in entity and entity.is_summon:
				summons += 1
			elif entity.has_method("is_crop") and entity.is_crop():
				crops += 1
			elif entity.has_method("is_npc"):
				npcs += 1
		else:
			dead_count += 1
	diagnostics.append("  Alive: %d" % alive_count)
	diagnostics.append("  Dead (not cleaned): %d" % dead_count)
	diagnostics.append("  Enemies: %d" % enemies)
	diagnostics.append("  NPCs: %d" % npcs)
	diagnostics.append("  Summons: %d" % summons)
	diagnostics.append("  Crops: %d" % crops)
	diagnostics.append("  Ground Items: %d" % ground_items)
	diagnostics.append("")

	# Structures
	diagnostics.append("[STRUCTURES]")
	if StructureManager and StructureManager.has_method("get_structures_on_map"):
		var structures = StructureManager.get_structures_on_map(MapManager.current_map.map_id)
		diagnostics.append("Structures on Map: %d" % structures.size())
	else:
		diagnostics.append("StructureManager not available")
	diagnostics.append("")

	# Light sources
	diagnostics.append("[LIGHTING]")
	diagnostics.append("Registered Light Sources: %d" % LightingSystem.registered_sources.size())
	diagnostics.append("Active Light Sources: %d" % LightingSystem.light_sources.size())
	diagnostics.append("Illuminated Positions: %d" % LightingSystem.illuminated_positions.size())
	diagnostics.append("")

	# Features and hazards
	diagnostics.append("[FEATURES & HAZARDS]")
	diagnostics.append("Active Features: %d" % FeatureManager.active_features.size())
	diagnostics.append("Active Hazards: %d" % HazardManager.active_hazards.size())
	diagnostics.append("")

	# Farming
	diagnostics.append("[FARMING]")
	diagnostics.append("Active Crops: %d" % FarmingSystem._active_crops.size())
	diagnostics.append("Tilled Soil: %d" % FarmingSystem._tilled_soil.size())
	diagnostics.append("")

	# Harvest system
	diagnostics.append("[HARVEST]")
	diagnostics.append("Renewable Resources: %d" % HarvestSystem._renewable_resources.size())
	diagnostics.append("Harvest Progress Tracking: %d" % HarvestSystem._harvest_progress.size())
	diagnostics.append("")

	# Map info
	diagnostics.append("[MAP]")
	diagnostics.append("Map ID: %s" % MapManager.current_map.map_id)
	diagnostics.append("Chunk Based: %s" % MapManager.current_map.chunk_based)
	if MapManager.current_map.chunk_based:
		diagnostics.append("Active Chunks: %d" % ChunkManager.active_chunks.size())
		diagnostics.append("Cached Chunks: %d" % ChunkManager.chunk_cache.size())
		diagnostics.append("Visited Chunks: %d" % ChunkManager.visited_chunks.size())
		diagnostics.append("Max Cache Size: %d" % ChunkManager.max_cache_size)
	else:
		diagnostics.append("Map Size: %dx%d" % [MapManager.current_map.width, MapManager.current_map.height])
	diagnostics.append("")

	# Visibility/FOV
	diagnostics.append("[VISIBILITY]")
	diagnostics.append("FOV Explored Tiles: %d" % FogOfWarSystem.explored_tiles.size())
	diagnostics.append("FOV Currently Visible: %d" % FogOfWarSystem.currently_visible.size())
	diagnostics.append("")

	# Player info
	diagnostics.append("[PLAYER]")
	diagnostics.append("Position: %v" % player.position)
	diagnostics.append("Level: %d" % player.level)
	diagnostics.append("HP: %d/%d" % [player.current_health, player.max_health])
	if player.survival:
		diagnostics.append("Hunger: %.1f" % player.survival.hunger)
		diagnostics.append("Thirst: %.1f" % player.survival.thirst)
		diagnostics.append("Fatigue: %.1f" % player.survival.fatigue)
		diagnostics.append("Stamina: %.1f/%.1f" % [player.survival.stamina, player.survival.get_max_stamina()])
	diagnostics.append("")

	diagnostics.append("=== END DIAGNOSTICS ===")

	# Print to console
	print("\n" + "\n".join(diagnostics) + "\n")

	# Also show in message log
	EventBus.message_logged.emit("Performance diagnostics printed to console")

	_go_back()
	closed.emit()

# ============================================================================
# UI building
# ============================================================================

func _build_current_tab() -> void:
	header.text = "~ DEBUG COMMANDS ~"
	filter_text = ""
	submenu_items_unfiltered.clear()
	if filter_container:
		filter_container.visible = false

	# Clear all tabs
	for child in items_tab.get_children():
		child.queue_free()
	for child in spawning_tab.get_children():
		child.queue_free()
	for child in player_tab.get_children():
		child.queue_free()
	for child in world_tab.get_children():
		child.queue_free()

	# Populate current tab
	var current_tab_container = _get_tab_container(tab_container.current_tab)
	var commands = tab_commands.get(tab_container.current_tab, [])

	for i in range(commands.size()):
		var cmd = commands[i]
		var display_text = _get_command_display_text(cmd)
		var label = Label.new()
		if i == selected_index:
			label.text = "> %s" % display_text
			label.add_theme_color_override("font_color", COLOR_SELECTED)
		else:
			label.text = "  %s" % display_text
			label.add_theme_color_override("font_color", COLOR_COMMAND)
		label.add_theme_font_size_override("font_size", 14)
		current_tab_container.add_child(label)

## Get display text for a command, with dynamic state for toggle commands
func _get_command_display_text(cmd: Dictionary) -> String:
	var action = cmd.get("action", "")
	match action:
		"toggle_god_mode":
			var status = "[ON]" if GameManager.debug_god_mode else "[OFF]"
			return "Toggle God Mode %s" % status
		"reveal_map":
			var status = "[ON]" if GameManager.debug_map_revealed else "[OFF]"
			return "Reveal Map %s" % status
		_:
			return cmd.text

func _get_tab_container(tab_index: int) -> VBoxContainer:
	match tab_index:
		0: return items_tab
		1: return spawning_tab
		2: return player_tab
		3: return world_tab
	return items_tab

func _get_tab_scroll(tab_index: int) -> ScrollContainer:
	match tab_index:
		0: return items_scroll
		1: return spawning_scroll
		2: return player_scroll
		3: return world_scroll
	return items_scroll

func _build_submenu(title: String, items: Array) -> void:
	submenu_title = title
	submenu_items_unfiltered = items.duplicate()
	submenu_items = items.duplicate()
	filter_text = ""  # Reset filter when entering submenu
	header.text = "~ %s ~" % title.to_upper()

	# Clear current tab and use it for submenu
	var current_tab_container = _get_tab_container(tab_container.current_tab)
	for child in current_tab_container.get_children():
		child.queue_free()

	_update_filter_display()

	for i in range(items.size()):
		var item = items[i]
		_add_menu_item(current_tab_container, item, i == selected_index)

	# Show info panel for first selected item
	_update_info_panel()

func _add_menu_item(container: VBoxContainer, item: Dictionary, is_selected: bool) -> void:
	var label = Label.new()
	if is_selected:
		label.text = "> %s" % item.text
		label.add_theme_color_override("font_color", COLOR_SELECTED)
	else:
		label.text = "  %s" % item.text
		label.add_theme_color_override("font_color", COLOR_COMMAND)
	label.add_theme_font_size_override("font_size", 14)
	container.add_child(label)

func _update_selection() -> void:
	var items = _get_current_items()
	var current_tab_container = _get_tab_container(tab_container.current_tab)
	var current_scroll = _get_tab_scroll(tab_container.current_tab)
	var children = current_tab_container.get_children()

	for i in range(min(items.size(), children.size())):
		var item = items[i]
		var label = children[i] as Label
		if not label:
			continue

		if i == selected_index:
			label.text = "> %s" % item.text
			label.add_theme_color_override("font_color", COLOR_SELECTED)
			# Auto-scroll to keep selected item visible
			if current_scroll:
				current_scroll.ensure_control_visible(label)
		else:
			label.text = "  %s" % item.text
			label.add_theme_color_override("font_color", COLOR_COMMAND)

	# Update info panel for submenu selections
	if current_state == MenuState.SUBMENU:
		_update_info_panel()

# ============================================================================
# Info Panel
# ============================================================================

func _update_info_panel() -> void:
	# Only show info panel in submenu state
	if current_state != MenuState.SUBMENU:
		info_panel.visible = false
		return

	var items = _get_current_items()
	if selected_index < 0 or selected_index >= items.size():
		info_panel.visible = false
		return

	var item = items[selected_index]
	var item_id = item.get("id", "")
	if item_id.is_empty():
		info_panel.visible = false
		return

	# Generate info based on pending command type
	var info_text = ""
	match pending_command:
		"give", "spawn":
			info_text = _get_item_info(item_id)
		"spawn_creature":
			info_text = _get_creature_info(item_id)
		"spawn_hazard":
			info_text = _get_hazard_info(item_id)
		"spawn_feature":
			info_text = _get_feature_info(item_id)
		"spawn_structure":
			info_text = _get_structure_info(item_id)
		"spawn_resource":
			info_text = _get_resource_info(item_id)
		"convert_tile":
			info_text = _get_tile_info(item_id)
		"learn_spell":
			info_text = _get_spell_info(item_id)
		"learn_recipe":
			info_text = _get_recipe_info(item_id)
		"learn_ritual":
			info_text = _get_ritual_info(item_id)

	if info_text.is_empty():
		info_panel.visible = false
	else:
		info_label.text = info_text
		info_panel.visible = true


func _get_item_info(item_id: String) -> String:
	var data = ItemManager.get_item_data(item_id)
	if not data:
		return ""

	var lines: Array[String] = []
	var item_name = data.get("name", item_id)
	var item_type = data.get("type", "item").capitalize()
	var desc = data.get("description", "")
	var ascii_char = data.get("ascii_char", "?")
	var color_hex = _get_color_hex(data)

	lines.append("[color=#%s]%s[/color] [b]%s[/b] [color=gray](%s)[/color]" % [color_hex, ascii_char, item_name, item_type])
	if desc:
		lines.append("[i]%s[/i]" % desc)

	# Stats based on type
	var stats: Array[String] = []
	if data.has("damage_bonus") and data.damage_bonus > 0:
		stats.append("⚔ Damage: +%d" % data.damage_bonus)
	if data.has("armor_value") and data.armor_value > 0:
		stats.append("◈ Armor: %d" % data.armor_value)
	if data.has("warmth") and data.warmth != 0:
		stats.append("☀ Warmth: %+.0f°F" % data.warmth)
	if data.has("weight"):
		stats.append("⚖ Weight: %.1f kg" % data.weight)
	if data.has("value"):
		stats.append("● Value: %d gold" % data.value)

	if stats.size() > 0:
		lines.append("[color=white]%s[/color]" % "  ".join(stats))

	return "\n".join(lines)


func _get_creature_info(enemy_id: String) -> String:
	var data = EntityManager.get_enemy_definition(enemy_id)
	if not data:
		return ""

	var lines: Array[String] = []
	var enemy_name = data.get("name", enemy_id)
	var cr = data.get("cr", 0)  # CR stored as "cr" in JSON
	var enemy_stats = data.get("stats", {})
	var hp = enemy_stats.get("health", data.get("health", 10))
	var desc = data.get("description", "")
	var ascii_char = data.get("ascii_char", "?")
	var color_hex = _get_color_hex(data)
	var creature_type = data.get("creature_type", "humanoid")
	var element_subtype = data.get("element_subtype", "")

	var cr_str = _format_cr(cr)
	lines.append("[color=#%s]%s[/color] [b]%s[/b] [color=gray](CR %s)[/color]" % [color_hex, ascii_char, enemy_name, cr_str])

	# Show creature type
	var type_display = CreatureTypeManager.get_type_display_name(creature_type)
	if element_subtype != "":
		type_display = CreatureTypeManager.get_subtype_display_name(creature_type, element_subtype)
	var type_color = CreatureTypeManager.get_type_color(creature_type)
	lines.append("[color=%s]Type: %s[/color]" % [type_color, type_display])

	if desc:
		lines.append("[i]%s[/i]" % desc)

	var stats: Array[String] = []
	stats.append("♥ HP: %d" % hp)

	if data.has("base_damage"):
		stats.append("⚔ Damage: %d" % data.base_damage)
	elif data.has("attack_damage"):
		stats.append("⚔ Damage: %d" % data.attack_damage)
	if data.has("armor"):
		stats.append("◈ Armor: %d" % data.armor)

	# Show behavior type
	var behavior = data.get("behavior", "wander")
	stats.append("AI: %s" % behavior.capitalize())

	if stats.size() > 0:
		lines.append("[color=white]%s[/color]" % "  ".join(stats))

	# Show resistances (merged from type + creature)
	var creature_resistances = data.get("elemental_resistances", {})
	var merged_resistances = CreatureTypeManager.get_merged_resistances(creature_type, element_subtype, creature_resistances)
	var res_parts: Array[String] = []
	for element in merged_resistances:
		var value = merged_resistances[element]
		if value <= -100:
			res_parts.append("[color=#00ff00]%s: Immune[/color]" % element.capitalize())
		elif value < 0:
			res_parts.append("[color=#88ff88]%s: %d%%[/color]" % [element.capitalize(), value])
		elif value > 0:
			res_parts.append("[color=#ff8888]%s: +%d%%[/color]" % [element.capitalize(), value])
	if res_parts.size() > 0:
		lines.append("Resistances: %s" % ", ".join(res_parts))

	# Show abilities if any
	if data.has("abilities") and data.abilities.size() > 0:
		lines.append("[color=yellow]Abilities: %s[/color]" % ", ".join(data.abilities))

	return "\n".join(lines)


func _get_hazard_info(hazard_id: String) -> String:
	var data = HazardManager.hazard_definitions.get(hazard_id, {})
	if data.is_empty():
		return ""

	var lines: Array[String] = []
	var hazard_name = data.get("name", hazard_id)
	var desc = data.get("description", "")
	var ascii_char = data.get("ascii_char", "^")
	var color_hex = _get_color_hex(data)
	if color_hex == "ffffff":  # Default to red for hazards
		color_hex = "ff0000"

	lines.append("[color=#%s]%s[/color] [b]%s[/b]" % [color_hex, ascii_char, hazard_name])
	if desc:
		lines.append("[i]%s[/i]" % desc)

	var stats: Array[String] = []
	if data.has("base_damage"):
		stats.append("⚔ Damage: %d" % data.base_damage)
	if data.has("damage_type"):
		stats.append("Type: %s" % data.damage_type.capitalize())
	if data.has("trigger_type"):
		stats.append("Trigger: %s" % data.trigger_type.capitalize())
	if data.get("can_disarm", false):
		stats.append("[color=green]Can be disarmed[/color]")

	if stats.size() > 0:
		lines.append("[color=white]%s[/color]" % "  ".join(stats))

	return "\n".join(lines)


func _get_feature_info(feature_id: String) -> String:
	var data = FeatureManager.feature_definitions.get(feature_id, {})
	if data.is_empty():
		return ""

	var lines: Array[String] = []
	var feature_name = data.get("name", feature_id)
	var desc = data.get("description", "")
	var ascii_char = data.get("ascii_char", "?")
	var color_hex = _get_color_hex(data)
	if color_hex == "ffffff":  # Default to yellow for features
		color_hex = "ffff00"

	lines.append("[color=#%s]%s[/color] [b]%s[/b]" % [color_hex, ascii_char, feature_name])
	if desc:
		lines.append("[i]%s[/i]" % desc)

	var stats: Array[String] = []
	if data.has("interaction"):
		stats.append("Action: %s" % data.interaction.capitalize())
	if data.get("has_loot", false):
		stats.append("[color=yellow]Contains loot[/color]")

	if stats.size() > 0:
		lines.append("[color=white]%s[/color]" % "  ".join(stats))

	return "\n".join(lines)


func _get_spell_info(spell_id: String) -> String:
	var spell = SpellManager.get_spell(spell_id)
	if not spell:
		return ""

	var lines: Array[String] = []

	# Header with colored ASCII char
	var color_hex = spell.ascii_color.trim_prefix("#") if spell.ascii_color.begins_with("#") else spell.ascii_color
	var level_str = "Cantrip" if spell.level == 0 else "Level %d" % spell.level
	lines.append("[color=#%s]%s[/color] [b]%s[/b] [color=gray](%s %s)[/color]" % [
		color_hex, spell.ascii_char, spell.name, spell.school.capitalize(), level_str
	])

	# Description
	if spell.description:
		lines.append("[i]%s[/i]" % spell.description)

	# Stats
	var stats: Array[String] = []
	stats.append("✦ Mana: %d" % spell.mana_cost)

	# Targeting info
	var target_mode = spell.targeting.get("mode", "self")
	var range_val = spell.targeting.get("range", 0)
	if target_mode == "self":
		stats.append("Target: Self")
	elif target_mode == "touch":
		stats.append("Target: Touch")
	elif range_val > 0:
		stats.append("Range: %d tiles" % range_val)

	# AOE
	var aoe_radius = spell.targeting.get("aoe_radius", 0)
	if aoe_radius > 0:
		stats.append("AOE: %d radius" % aoe_radius)

	if stats.size() > 0:
		lines.append("[color=white]%s[/color]" % "  ".join(stats))

	# Requirements
	var req_parts: Array[String] = []
	var req_level = spell.requirements.get("character_level", 1)
	var req_int = spell.requirements.get("intelligence", 8)
	if req_level > 1:
		req_parts.append("Level %d" % req_level)
	if req_int > 8:
		req_parts.append("INT %d" % req_int)
	if req_parts.size() > 0:
		lines.append("[color=yellow]Requires: %s[/color]" % ", ".join(req_parts))

	# Duration/Concentration
	var duration_type = spell.duration.get("type", "instant")
	if duration_type != "instant":
		var dur_str = duration_type.capitalize()
		if spell.duration.get("base", 0) > 0:
			dur_str = "%d turns" % spell.duration.base
		if spell.concentration:
			dur_str += " (Concentration)"
		lines.append("[color=cyan]Duration: %s[/color]" % dur_str)

	return "\n".join(lines)


func _get_recipe_info(recipe_id: String) -> String:
	var recipe = RecipeManager.get_recipe(recipe_id)
	if not recipe:
		return ""

	var lines: Array[String] = []

	# Header - get result item info for display
	var result_data = ItemManager.get_item_data(recipe.result_item_id)
	var result_name = recipe.get_display_name()
	var ascii_char = "?"
	var color_hex = "ffffff"
	if result_data:
		ascii_char = result_data.get("ascii_char", "?")
		var color = result_data.get("color", Color.WHITE)
		color_hex = color.to_html(false) if color is Color else "ffffff"

	var count_str = " x%d" % recipe.result_count if recipe.result_count > 1 else ""
	lines.append("[color=#%s]%s[/color] [b]%s%s[/b]" % [color_hex, ascii_char, result_name, count_str])

	# Discovery hint as description
	if recipe.discovery_hint:
		lines.append("[i]%s[/i]" % recipe.discovery_hint)

	# Ingredients
	var ingredient_list = recipe.get_ingredient_list()
	lines.append("[color=white]Ingredients: %s[/color]" % ingredient_list)

	# Requirements
	var req_parts: Array[String] = []
	if recipe.tool_required:
		req_parts.append("Tool: %s" % recipe.tool_required.capitalize())
	if recipe.fire_required:
		req_parts.append("Fire source")
	if recipe.workstation_required:
		req_parts.append("%s" % recipe.workstation_required.capitalize())
	if req_parts.size() > 0:
		lines.append("[color=yellow]Requires: %s[/color]" % ", ".join(req_parts))

	# Difficulty
	var difficulty_names = ["Trivial", "Easy", "Medium", "Hard", "Expert"]
	var diff_idx = clampi(recipe.difficulty - 1, 0, difficulty_names.size() - 1)
	lines.append("[color=gray]Difficulty: %s (%d)[/color]" % [difficulty_names[diff_idx], recipe.difficulty])

	return "\n".join(lines)


func _get_structure_info(structure_id: String) -> String:
	var data = StructureManager.structure_definitions.get(structure_id, {})
	if data.is_empty():
		return ""

	var lines: Array[String] = []
	var structure_name = data.get("name", structure_id)
	var desc = data.get("description", "")
	var ascii_char = data.get("ascii_char", "#")
	var color_hex = _get_color_hex(data)

	lines.append("[color=#%s]%s[/color] [b]%s[/b]" % [color_hex, ascii_char, structure_name])
	if desc:
		lines.append("[i]%s[/i]" % desc)

	var stats: Array[String] = []
	if data.get("is_fire_source", false):
		stats.append("[color=orange]Fire source[/color]")
	if data.get("is_light_source", false):
		stats.append("[color=yellow]Light source[/color]")
	if data.get("is_shelter", false):
		stats.append("[color=cyan]Provides shelter[/color]")
	if data.has("warmth") and data.warmth != 0:
		stats.append("☀ Warmth: %+.0f°F" % data.warmth)

	if stats.size() > 0:
		lines.append("[color=white]%s[/color]" % "  ".join(stats))

	return "\n".join(lines)


func _get_resource_info(resource_id: String) -> String:
	var resource = HarvestSystem.get_resource(resource_id)
	if not resource:
		return ""

	var lines: Array[String] = []
	var resource_name = resource.name
	var tile_def = TileTypeManager.get_tile_definition(resource_id)
	var ascii_char = tile_def.get("ascii_char", "*") if tile_def else "*"
	var color_hex = tile_def.get("ascii_color", "#00ff00").trim_prefix("#") if tile_def else "00ff00"

	lines.append("[color=#%s]%s[/color] [b]%s[/b]" % [color_hex, ascii_char, resource_name])

	# Tools required
	if not resource.required_tools.is_empty():
		var tool_names: Array[String] = []
		for tool_req in resource.required_tools:
			var item_data = ItemManager.get_item_data(tool_req.tool_id)
			var tool_name = item_data.get("name", tool_req.tool_id) if item_data else tool_req.tool_id
			tool_names.append(tool_name)
		lines.append("[color=yellow]Tools: %s[/color]" % ", ".join(tool_names))

	# Yields
	if not resource.yields.is_empty():
		var yield_names: Array[String] = []
		for yield_data in resource.yields:
			var item_id = yield_data.get("item_id", "")
			var item_data = ItemManager.get_item_data(item_id)
			var yield_name = item_data.get("name", item_id) if item_data else item_id
			yield_names.append(yield_name)
		lines.append("[color=white]Yields: %s[/color]" % ", ".join(yield_names))

	# Behavior
	var behavior_names = ["Permanent", "Renewable", "Infinite"]
	if resource.harvest_behavior >= 0 and resource.harvest_behavior < behavior_names.size():
		lines.append("[color=gray]Type: %s[/color]" % behavior_names[resource.harvest_behavior])

	return "\n".join(lines)


func _get_tile_info(tile_id: String) -> String:
	var tile_def = TileTypeManager.get_tile_definition(tile_id)
	if tile_def.is_empty():
		return ""

	var lines: Array[String] = []
	var display_name = tile_def.get("display_name", tile_id.replace("_", " ").capitalize())
	var ascii_char = tile_def.get("ascii_char", "?")
	var color_hex = tile_def.get("ascii_color", "#ffffff").trim_prefix("#") if tile_def.has("ascii_color") else "ffffff"

	lines.append("[color=#%s]%s[/color] [b]%s[/b]" % [color_hex, ascii_char, display_name])

	var stats: Array[String] = []
	if tile_def.get("walkable", true):
		stats.append("[color=green]Walkable[/color]")
	else:
		stats.append("[color=red]Blocking[/color]")
	if tile_def.get("transparent", true):
		stats.append("[color=cyan]Transparent[/color]")
	else:
		stats.append("[color=gray]Opaque[/color]")
	if tile_def.get("is_fire_source", false):
		stats.append("[color=orange]Fire source[/color]")

	if stats.size() > 0:
		lines.append("%s" % "  ".join(stats))

	# Harvestable resource
	var harvestable = tile_def.get("harvestable_resource_id", "")
	if harvestable:
		var resource = HarvestSystem.get_resource(harvestable)
		var resource_name = resource.name if resource else harvestable
		lines.append("[color=yellow]Harvestable: %s[/color]" % resource_name)

	return "\n".join(lines)


func _get_ritual_info(ritual_id: String) -> String:
	var ritual = RitualManager.get_ritual(ritual_id)
	if not ritual:
		return ""

	var lines: Array[String] = []

	# Header with colored ASCII char
	var color_hex = ritual.ascii_color.trim_prefix("#") if ritual.ascii_color.begins_with("#") else ritual.ascii_color
	var rarity_str = ritual.rarity.capitalize() if ritual.rarity else "Common"
	lines.append("[color=#%s]%s[/color] [b]%s[/b] [color=gray](%s %s)[/color]" % [
		color_hex, ritual.ascii_char, ritual.name, ritual.school.capitalize(), rarity_str
	])

	# Description
	if ritual.description:
		lines.append("[i]%s[/i]" % ritual.description)

	# Stats
	var stats: Array[String] = []
	stats.append("⏱ Channeling: %d turns" % ritual.channeling_turns)

	if stats.size() > 0:
		lines.append("[color=white]%s[/color]" % "  ".join(stats))

	# Components
	if not ritual.components.is_empty():
		var component_list = ritual.get_component_list()
		lines.append("[color=yellow]Components: %s[/color]" % ", ".join(component_list))

	# Requirements
	var req_int = ritual.requirements.get("intelligence", 8)
	if req_int > 8:
		lines.append("[color=cyan]Requires: INT %d[/color]" % req_int)

	return "\n".join(lines)

# ============================================================================
# Helpers
# ============================================================================

func _get_color_hex(data: Dictionary) -> String:
	"""Extract color as hex string from data dictionary.
	Handles both 'ascii_color' (string like '#708090') and 'color' (Color object)."""
	# First check for ascii_color as hex string
	if data.has("ascii_color"):
		var ascii_color = data.get("ascii_color")
		if ascii_color is String:
			return ascii_color.trim_prefix("#")
	# Fall back to color property
	if data.has("color"):
		var color = data.get("color")
		if color is Color:
			return color.to_html(false)
		elif color is String:
			return color.trim_prefix("#")
	# Default to white
	return "ffffff"

func _format_cr(cr_value) -> String:
	"""Format CR value as fraction for values < 1, otherwise as integer."""
	var val: float = 0.0
	if cr_value is float:
		val = cr_value
	elif cr_value is int:
		val = float(cr_value)
	elif cr_value is String and cr_value.is_valid_float():
		val = float(cr_value)

	if val < 1.0:
		# Common D&D-style CR fractions
		if val <= 0.125:
			return "1/8"
		elif val <= 0.25:
			return "1/4"
		elif val <= 0.5:
			return "1/2"
		else:
			return str(val)
	else:
		return str(int(val))

func _show_message(text: String) -> void:
	EventBus.message_logged.emit("[DEBUG] %s" % text, Color(0.9, 0.5, 0.3))

func _get_char_from_keycode(event: InputEventKey) -> String:
	"""Convert keycode to character for filter typing."""
	# Use unicode if available (handles shift properly)
	if event.unicode > 0 and event.unicode < 128:
		var typed_char = char(event.unicode)
		# Only allow alphanumeric and space
		if typed_char.is_valid_identifier() or typed_char == " " or typed_char == "-" or typed_char == "_":
			return typed_char.to_lower()
	return ""

func _apply_filter() -> void:
	"""Apply current filter text to submenu items."""
	if submenu_items_unfiltered.is_empty():
		return

	# Update filter display
	_update_filter_display()

	if filter_text.is_empty():
		submenu_items = submenu_items_unfiltered.duplicate()
	else:
		submenu_items = []
		var filter_lower = filter_text.to_lower()
		for item in submenu_items_unfiltered:
			var text = item.get("text", "").to_lower()
			if text.contains(filter_lower):
				submenu_items.append(item)

	# Reset selection and rebuild display
	selected_index = 0
	_rebuild_submenu_display()

func _update_filter_display() -> void:
	"""Update the filter text display."""
	if filter_container:
		filter_container.visible = (current_state == MenuState.SUBMENU)
	if filter_display:
		if filter_text.is_empty():
			filter_display.text = "(type to filter)"
			filter_display.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			filter_display.text = filter_text
			filter_display.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))

func _rebuild_submenu_display() -> void:
	"""Rebuild the submenu command list with current filtered items."""
	var current_tab_container = _get_tab_container(tab_container.current_tab)

	# Clear current tab
	for child in current_tab_container.get_children():
		child.queue_free()

	if submenu_items.is_empty():
		var label = Label.new()
		label.text = "  (no matches)"
		label.add_theme_color_override("font_color", COLOR_DISABLED)
		label.add_theme_font_size_override("font_size", 14)
		current_tab_container.add_child(label)
	else:
		for i in range(submenu_items.size()):
			var item = submenu_items[i]
			_add_menu_item(current_tab_container, item, i == selected_index)

	_update_info_panel()
