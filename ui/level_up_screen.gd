extends Control

## Level Up Screen - Allocate skill points and ability score increases
##
## Keyboard navigation with arrow keys, +/- to adjust points, C to commit

signal closed

@onready var panel: Panel = $Panel
@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var skills_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Skills
@onready var skills_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Skills/ScrollMargin/SkillsBox
@onready var abilities_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Abilities
@onready var abilities_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Abilities/ScrollMargin/AbilitiesBox
@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/MessageLabel

var player = null
var current_scroll_container: ScrollContainer = null

# Pending changes
var pending_skill_increases: Dictionary = {}  # skill_name -> count
var pending_ability_increases: Dictionary = {}  # ability_code -> count
var available_skill_points_remaining: int = 0
var available_ability_points_remaining: int = 0

# Navigation state
var navigable_items: Array = []  # Array of {type: "skill"/"ability", name: String, line_index: int}
var selected_index: int = 0

# Colors
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_LABEL = Color(0.85, 0.85, 0.7)
const COLOR_VALUE = Color(0.7, 0.9, 0.7)
const COLOR_PENDING = Color(1.0, 0.85, 0.3)
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)

## Open the level up screen
func open(p_player) -> void:
	player = p_player

	# Initialize pending changes
	pending_skill_increases.clear()
	pending_ability_increases.clear()
	available_skill_points_remaining = player.available_skill_points
	available_ability_points_remaining = player.available_ability_points

	# Clear any previous message
	_clear_message()

	# Build the UI
	_populate_skills_tab()
	_populate_abilities_tab()

	# Select the appropriate starting tab
	if available_skill_points_remaining > 0:
		tab_container.current_tab = 0  # Skills
	elif available_ability_points_remaining > 0:
		tab_container.current_tab = 1  # Abilities

	_on_tab_changed(tab_container.current_tab)

	# Reset selection
	selected_index = 0
	_update_selection_visual()

	show()

## Close the screen
func close() -> void:
	hide()
	closed.emit()

## Populate skills tab
func _populate_skills_tab() -> void:
	# Clear existing content - use immediate removal to avoid node name conflicts
	while skills_content.get_child_count() > 0:
		var child = skills_content.get_child(0)
		skills_content.remove_child(child)
		child.free()

	# Clear message when repopulating
	_clear_message()

	# Header
	var header = _create_section_header("== SKILL POINTS ==")
	skills_content.add_child(header)

	_add_spacer(skills_content)

	# Available points
	var points_label = Label.new()
	points_label.text = "Available Skill Points: %d" % available_skill_points_remaining
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if available_skill_points_remaining > 0:
		points_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.95))
	else:
		points_label.add_theme_color_override("font_color", COLOR_LABEL)
	points_label.add_theme_font_size_override("font_size", 14)
	skills_content.add_child(points_label)

	_add_spacer(skills_content)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Use ↑/↓ arrows to select, +/- to adjust, C to commit"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	instructions.add_theme_font_size_override("font_size", 12)
	skills_content.add_child(instructions)

	_add_spacer(skills_content)

	# Build navigable items list for skills
	navigable_items.clear()
	var skill_names = player.skills.keys()
	skill_names.sort()

	for skill_name in skill_names:
		_add_skill_line(skill_name, player.skills[skill_name])
		navigable_items.append({"type": "skill", "name": skill_name})

## Populate abilities tab
func _populate_abilities_tab() -> void:
	# Clear existing content - use immediate removal to avoid node name conflicts
	while abilities_content.get_child_count() > 0:
		var child = abilities_content.get_child(0)
		abilities_content.remove_child(child)
		child.free()

	# Clear message when repopulating
	_clear_message()

	# Header
	var header = _create_section_header("== ABILITY SCORES ==")
	abilities_content.add_child(header)

	_add_spacer(abilities_content)

	# Available points
	var points_label = Label.new()
	points_label.text = "Available Ability Points: %d" % available_ability_points_remaining
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if available_ability_points_remaining > 0:
		points_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.7))
	else:
		points_label.add_theme_color_override("font_color", COLOR_LABEL)
	points_label.add_theme_font_size_override("font_size", 14)
	abilities_content.add_child(points_label)

	_add_spacer(abilities_content)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Use ↑/↓ arrows to select, +/- to adjust, C to commit"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	instructions.add_theme_font_size_override("font_size", 12)
	abilities_content.add_child(instructions)

	_add_spacer(abilities_content)

	# Build navigable items list for abilities
	if tab_container.current_tab == 1:  # Only clear if on abilities tab
		navigable_items.clear()

	var abilities = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
	var ability_names = {
		"STR": "Strength",
		"DEX": "Dexterity",
		"CON": "Constitution",
		"INT": "Intelligence",
		"WIS": "Wisdom",
		"CHA": "Charisma"
	}

	for ability in abilities:
		_add_ability_line(ability, ability_names[ability], player.attributes[ability])
		if tab_container.current_tab == 1:
			navigable_items.append({"type": "ability", "name": ability})

## Add a skill line
func _add_skill_line(skill_name: String, current_level: int) -> void:
	var line = HBoxContainer.new()
	line.name = "Skill_" + skill_name  # For finding later

	# Selection marker (hidden by default)
	var marker = Label.new()
	marker.name = "Marker"
	marker.text = "  "
	marker.add_theme_color_override("font_color", COLOR_SELECTED)
	marker.add_theme_font_size_override("font_size", 14)
	line.add_child(marker)

	# Skill name
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = skill_name
	name_label.custom_minimum_size.x = 180
	name_label.add_theme_color_override("font_color", COLOR_LABEL)
	name_label.add_theme_font_size_override("font_size", 14)
	line.add_child(name_label)

	# Value with pending
	var pending_increases = pending_skill_increases.get(skill_name, 0)

	var value_label = Label.new()
	value_label.name = "Value"
	if pending_increases > 0:
		value_label.text = "%d (+%d) / %d" % [current_level, pending_increases, player.level]
		value_label.add_theme_color_override("font_color", COLOR_PENDING)
	else:
		value_label.text = "%d / %d" % [current_level, player.level]
		if current_level >= player.level:
			value_label.add_theme_color_override("font_color", COLOR_PENDING)
		else:
			value_label.add_theme_color_override("font_color", COLOR_VALUE)
	value_label.add_theme_font_size_override("font_size", 14)
	line.add_child(value_label)

	skills_content.add_child(line)

## Add an ability line
func _add_ability_line(ability_code: String, ability_name: String, current_value: int) -> void:
	var line = HBoxContainer.new()
	line.name = "Ability_" + ability_code  # For finding later

	# Selection marker (hidden by default)
	var marker = Label.new()
	marker.name = "Marker"
	marker.text = "  "
	marker.add_theme_color_override("font_color", COLOR_SELECTED)
	marker.add_theme_font_size_override("font_size", 14)
	line.add_child(marker)

	# Ability name
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = ability_name
	name_label.custom_minimum_size.x = 180
	name_label.add_theme_color_override("font_color", COLOR_LABEL)
	name_label.add_theme_font_size_override("font_size", 14)
	line.add_child(name_label)

	# Value with pending
	var pending_increases = pending_ability_increases.get(ability_code, 0)

	var value_label = Label.new()
	value_label.name = "Value"
	if pending_increases > 0:
		value_label.text = "%d (+%d)" % [current_value, pending_increases]
		value_label.add_theme_color_override("font_color", COLOR_PENDING)
	else:
		value_label.text = "%d" % current_value
		value_label.add_theme_color_override("font_color", COLOR_VALUE)
	value_label.add_theme_font_size_override("font_size", 14)
	line.add_child(value_label)

	abilities_content.add_child(line)

## Handle input
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				_navigate_up()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_navigate_down()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				# Switch between tabs
				tab_container.current_tab = (tab_container.current_tab + 1) % 2
				_on_tab_changed(tab_container.current_tab)
				get_viewport().set_input_as_handled()
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL, KEY_ENTER, KEY_KP_ENTER:
				_increment_selected()
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_decrement_selected()
				get_viewport().set_input_as_handled()
			KEY_C:
				_try_commit()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				# Cancel if no pending changes, otherwise warn
				if pending_skill_increases.is_empty() and pending_ability_increases.is_empty():
					close()
				else:
					_show_cancel_warning()
				get_viewport().set_input_as_handled()

## Navigate up
func _navigate_up() -> void:
	if navigable_items.is_empty():
		return
	selected_index = (selected_index - 1 + navigable_items.size()) % navigable_items.size()
	_update_selection_visual()
	_scroll_to_selected()

## Navigate down
func _navigate_down() -> void:
	if navigable_items.is_empty():
		return
	selected_index = (selected_index + 1) % navigable_items.size()
	_update_selection_visual()
	_scroll_to_selected()

## Increment selected item
func _increment_selected() -> void:
	if navigable_items.is_empty() or selected_index >= navigable_items.size():
		return

	var item = navigable_items[selected_index]
	if item.type == "skill":
		_increment_skill(item.name)
	elif item.type == "ability":
		_increment_ability(item.name)

## Decrement selected item
func _decrement_selected() -> void:
	if navigable_items.is_empty() or selected_index >= navigable_items.size():
		return

	var item = navigable_items[selected_index]
	if item.type == "skill":
		_decrement_skill(item.name)
	elif item.type == "ability":
		_decrement_ability(item.name)

## Increment skill
func _increment_skill(skill_name: String) -> void:
	if available_skill_points_remaining <= 0:
		return

	var current_level = player.skills.get(skill_name, 0)
	var pending_increases = pending_skill_increases.get(skill_name, 0)

	# Can't exceed player level
	if current_level + pending_increases >= player.level:
		return

	pending_skill_increases[skill_name] = pending_increases + 1
	available_skill_points_remaining -= 1

	_populate_skills_tab()
	_update_selection_visual()

## Decrement skill
func _decrement_skill(skill_name: String) -> void:
	var pending_increases = pending_skill_increases.get(skill_name, 0)
	if pending_increases <= 0:
		return

	pending_skill_increases[skill_name] = pending_increases - 1
	if pending_skill_increases[skill_name] <= 0:
		pending_skill_increases.erase(skill_name)

	available_skill_points_remaining += 1

	_populate_skills_tab()
	_update_selection_visual()

## Increment ability
func _increment_ability(ability_code: String) -> void:
	if available_ability_points_remaining <= 0:
		return

	var pending_increases = pending_ability_increases.get(ability_code, 0)

	pending_ability_increases[ability_code] = pending_increases + 1
	available_ability_points_remaining -= 1

	_populate_abilities_tab()
	_update_selection_visual()

## Decrement ability
func _decrement_ability(ability_code: String) -> void:
	var pending_increases = pending_ability_increases.get(ability_code, 0)
	if pending_increases <= 0:
		return

	pending_ability_increases[ability_code] = pending_increases - 1
	if pending_ability_increases[ability_code] <= 0:
		pending_ability_increases.erase(ability_code)

	available_ability_points_remaining += 1

	_populate_abilities_tab()
	_update_selection_visual()

## Update visual selection
func _update_selection_visual() -> void:
	if navigable_items.is_empty() or selected_index >= navigable_items.size():
		return

	var item = navigable_items[selected_index]
	var content_box = skills_content if item.type == "skill" else abilities_content

	# Reset all lines - clear markers and restore normal colors
	for child in content_box.get_children():
		if child is HBoxContainer:
			var marker = child.get_node_or_null("Marker")
			var name_node = child.get_node_or_null("Name")
			if marker:
				marker.text = "  "
			if name_node:
				name_node.add_theme_color_override("font_color", COLOR_LABEL)

	# Highlight selected line with arrow marker
	var line_name = ("Skill_" if item.type == "skill" else "Ability_") + item.name
	var selected_line = content_box.get_node_or_null(line_name)
	if selected_line:
		var marker = selected_line.get_node_or_null("Marker")
		var name_node = selected_line.get_node_or_null("Name")
		if marker:
			marker.text = "► "
		if name_node:
			name_node.add_theme_color_override("font_color", COLOR_SELECTED)

## Scroll to selected item
func _scroll_to_selected() -> void:
	if not current_scroll_container or navigable_items.is_empty():
		return

	if selected_index >= navigable_items.size():
		return

	var item = navigable_items[selected_index]
	var content_box = skills_content if item.type == "skill" else abilities_content
	var line_name = ("Skill_" if item.type == "skill" else "Ability_") + item.name
	var selected_line = content_box.get_node_or_null(line_name)

	if selected_line and current_scroll_container:
		# Get line's position relative to scroll container
		var line_pos = selected_line.global_position.y - content_box.global_position.y
		var scroll_center = current_scroll_container.size.y / 2

		# Center the selected line
		current_scroll_container.scroll_vertical = int(line_pos - scroll_center)

## Try to commit changes
func _try_commit() -> void:
	# Must spend ALL points
	if available_skill_points_remaining > 0 or available_ability_points_remaining > 0:
		_show_commit_error()
		return

	# Must have made changes
	if pending_skill_increases.is_empty() and pending_ability_increases.is_empty():
		close()
		return

	# Apply changes
	_commit_changes()

## Show error if trying to commit with unspent points
func _show_commit_error() -> void:
	var error_parts = []
	if available_skill_points_remaining > 0:
		error_parts.append("%d skill" % available_skill_points_remaining)
	if available_ability_points_remaining > 0:
		error_parts.append("%d ability" % available_ability_points_remaining)

	var error_msg = "Must spend all points! Remaining: " + ", ".join(error_parts)
	_show_message(error_msg, Color(1.0, 0.5, 0.5))

## Show warning when trying to cancel with pending changes
func _show_cancel_warning() -> void:
	_show_message("Unspent points! Press C to commit changes.", Color(1.0, 0.7, 0.3))

## Show message in the dialog
func _show_message(text: String, color: Color = Color.WHITE) -> void:
	if message_label:
		message_label.text = text
		message_label.add_theme_color_override("font_color", color)
		message_label.show()

## Clear message
func _clear_message() -> void:
	if message_label:
		message_label.text = ""
		message_label.hide()

## Actually commit the changes to the player
func _commit_changes() -> void:
	# Apply skill increases
	for skill_name in pending_skill_increases:
		var count = pending_skill_increases[skill_name]
		for i in range(count):
			if not player.spend_skill_point(skill_name):
				push_error("Failed to commit skill increase for %s" % skill_name)

	# Apply ability increases
	for ability_code in pending_ability_increases:
		var count = pending_ability_increases[ability_code]
		for i in range(count):
			if not player.increase_ability(ability_code):
				push_error("Failed to commit ability increase for %s" % ability_code)

	EventBus.message_logged.emit("Level up changes committed!", "system")
	close()

## Called when tab changes
func _on_tab_changed(tab_index: int) -> void:
	match tab_index:
		0:  # Skills
			current_scroll_container = skills_scroll
			_populate_skills_tab()
		1:  # Abilities
			current_scroll_container = abilities_scroll
			_populate_abilities_tab()

	selected_index = 0
	_update_selection_visual()

## Helper: Create section header
func _create_section_header(text: String) -> Label:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_SECTION)
	header.add_theme_font_size_override("font_size", 15)
	return header

## Helper: Add spacer
func _add_spacer(parent: Node) -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	parent.add_child(spacer)
