extends Control

## Skill Allocation Screen - Distribute skill points during character creation
##
## Players get 2 + INT modifier points to distribute among skills
## Skills already have class bonuses applied

signal confirmed(distributed_points: Dictionary)  # {skill_id: points_added}
signal cancelled()

@onready var panel: Panel = $Panel
@onready var content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/Content
@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/MessageLabel
@onready var scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var points_label: Label = $Panel/MarginContainer/VBoxContainer/PointsLabel

var player = null  # Reference for reading INT and class skill bonuses
var total_skill_points: int = 0
var available_points: int = 0
var distributed_points: Dictionary = {}  # {skill_id: points_added}

# Navigation state
var navigable_items: Array = []  # Array of {name: skill_id}
var selected_index: int = 0

# Colors matching level-up screen
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_LABEL = Color(0.85, 0.85, 0.7)
const COLOR_VALUE = Color(0.7, 0.9, 0.7)
const COLOR_PENDING = Color(1.0, 0.85, 0.3)
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

## Open the skill allocation screen
func open(p_player) -> void:
	player = p_player
	_calculate_available_points()
	_populate_ui()
	_clear_message()

	# Reset selection
	selected_index = 0
	_update_selection_visual()

	show()

## Close the screen
func close() -> void:
	hide()

## Calculate available skill points based on INT
func _calculate_available_points() -> void:
	var int_score = player.get_effective_attribute("INT")
	var int_modifier = floor((int_score - 10) / 2.0)
	total_skill_points = 2 + int_modifier

	# Ensure at least 1 point (even with very low INT)
	if total_skill_points < 1:
		total_skill_points = 1

	available_points = total_skill_points

## Populate the UI
func _populate_ui() -> void:
	# Clear existing content
	while content.get_child_count() > 0:
		var child = content.get_child(0)
		content.remove_child(child)
		child.free()

	# Clear navigable items
	navigable_items.clear()

	# Update points label
	if points_label:
		points_label.text = "Available Skill Points: %d / %d" % [available_points, total_skill_points]
		if available_points > 0:
			points_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.95))
		else:
			points_label.add_theme_color_override("font_color", COLOR_LABEL)

	# Get all skills and sort them
	var all_skills = SkillManager.get_all_skills()

	# Separate weapon and action skills
	var weapon_skills = []
	var action_skills = []

	for skill in all_skills:
		if skill.category == "weapon":
			weapon_skills.append(skill)
		else:
			action_skills.append(skill)

	# Sort each category by name
	weapon_skills.sort_custom(func(a, b): return a.name < b.name)
	action_skills.sort_custom(func(a, b): return a.name < b.name)

	# Create two-column layout
	var columns_container = HBoxContainer.new()
	columns_container.add_theme_constant_override("separation", 40)
	content.add_child(columns_container)

	# Left column - Weapon Skills
	var weapon_column = VBoxContainer.new()
	weapon_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.add_child(weapon_column)

	if not weapon_skills.is_empty():
		var weapon_header = _create_section_header("Weapon Skills")
		weapon_column.add_child(weapon_header)

		for skill in weapon_skills:
			_add_skill_line_to_container(skill.id, skill.name, weapon_column)
			navigable_items.append({"name": skill.id, "column": "weapon"})

	# Right column - Action Skills
	var action_column = VBoxContainer.new()
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns_container.add_child(action_column)

	if not action_skills.is_empty():
		var action_header = _create_section_header("Action Skills")
		action_column.add_child(action_header)

		for skill in action_skills:
			_add_skill_line_to_container(skill.id, skill.name, action_column)
			navigable_items.append({"name": skill.id, "column": "action"})

## Add a skill line to a container
func _add_skill_line_to_container(skill_id: String, skill_display_name: String, container: VBoxContainer) -> void:
	var line = HBoxContainer.new()
	line.name = "Skill_" + skill_id  # For finding later

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
	name_label.text = skill_display_name
	name_label.custom_minimum_size.x = 140
	name_label.add_theme_color_override("font_color", COLOR_LABEL)
	name_label.add_theme_font_size_override("font_size", 14)
	line.add_child(name_label)

	# Current level (class bonus + distributed points)
	var class_bonus = player.class_skill_bonuses.get(skill_id, 0)
	var distributed = distributed_points.get(skill_id, 0)
	var total = class_bonus + distributed

	var value_label = Label.new()
	value_label.name = "Value"
	if distributed > 0:
		value_label.text = "%d (+%d)" % [total, distributed]
		value_label.add_theme_color_override("font_color", COLOR_PENDING)
	else:
		value_label.text = "%d" % total
		value_label.add_theme_color_override("font_color", COLOR_VALUE if total > 0 else COLOR_NORMAL)
	value_label.add_theme_font_size_override("font_size", 14)
	line.add_child(value_label)

	container.add_child(line)

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

## Switch to other column
func _switch_column() -> void:
	if navigable_items.is_empty() or selected_index >= navigable_items.size():
		return

	# Get current column
	var current_column = navigable_items[selected_index].column
	var target_column = "action" if current_column == "weapon" else "weapon"

	# Find first item in target column
	for i in range(navigable_items.size()):
		if navigable_items[i].column == target_column:
			selected_index = i
			_update_selection_visual()
			_scroll_to_selected()
			return

## Increment selected skill
func _increment_selected() -> void:
	if navigable_items.is_empty() or selected_index >= navigable_items.size():
		return

	if available_points <= 0:
		_show_error("No points remaining!")
		return

	var item = navigable_items[selected_index]
	var skill_id = item.name

	# Check max level
	var skill = SkillManager.get_skill(skill_id)
	if skill:
		var class_bonus = player.class_skill_bonuses.get(skill_id, 0)
		var current_distributed = distributed_points.get(skill_id, 0)
		var total = class_bonus + current_distributed + 1

		if total > skill.max_level:
			_show_error("Skill is at maximum level!")
			return

	# Add point
	distributed_points[skill_id] = distributed_points.get(skill_id, 0) + 1
	available_points -= 1

	_populate_ui()
	_update_selection_visual()
	_clear_message()

## Decrement selected skill
func _decrement_selected() -> void:
	if navigable_items.is_empty() or selected_index >= navigable_items.size():
		return

	var item = navigable_items[selected_index]
	var skill_id = item.name
	var current_distributed = distributed_points.get(skill_id, 0)

	if current_distributed <= 0:
		_show_error("No points to remove from this skill!")
		return

	# Remove point
	distributed_points[skill_id] = current_distributed - 1
	if distributed_points[skill_id] == 0:
		distributed_points.erase(skill_id)
	available_points += 1

	_populate_ui()
	_update_selection_visual()
	_clear_message()

## Update visual selection
func _update_selection_visual() -> void:
	if navigable_items.is_empty() or selected_index >= navigable_items.size():
		return

	# Reset all skill lines (recursively search through columns)
	_reset_all_skill_lines(content)

	# Highlight selected line with arrow marker
	var item = navigable_items[selected_index]
	var line_name = "Skill_" + item.name
	var selected_line = content.find_child(line_name, true, false)
	if selected_line:
		var marker = selected_line.get_node_or_null("Marker")
		var name_node = selected_line.get_node_or_null("Name")
		if marker:
			marker.text = "► "
		if name_node:
			name_node.add_theme_color_override("font_color", COLOR_SELECTED)

## Recursively reset all skill lines
func _reset_all_skill_lines(node: Node) -> void:
	for child in node.get_children():
		if child is HBoxContainer and child.name.begins_with("Skill_"):
			var marker = child.get_node_or_null("Marker")
			var name_node = child.get_node_or_null("Name")
			if marker:
				marker.text = "  "
			if name_node:
				name_node.add_theme_color_override("font_color", COLOR_LABEL)
		elif child.get_child_count() > 0:
			_reset_all_skill_lines(child)

## Scroll to selected item
func _scroll_to_selected() -> void:
	if not scroll_container or navigable_items.is_empty():
		return

	if selected_index >= navigable_items.size():
		return

	var item = navigable_items[selected_index]
	var line_name = "Skill_" + item.name
	var selected_line = content.find_child(line_name, true, false)

	if selected_line and scroll_container:
		# Get line's position relative to scroll container
		var line_pos = selected_line.global_position.y - content.global_position.y
		var scroll_height = scroll_container.size.y
		var target_scroll = line_pos - (scroll_height / 2) + (selected_line.size.y / 2)

		# Clamp to valid scroll range
		target_scroll = clamp(target_scroll, 0, scroll_container.get_v_scroll_bar().max_value)
		scroll_container.scroll_vertical = int(target_scroll)

## Try to confirm
func _try_commit() -> void:
	# Must spend all points
	if available_points > 0:
		_show_error("You must spend all skill points! (%d remaining)" % available_points)
		return

	confirmed.emit(distributed_points)
	close()

## Show error message
func _show_error(text: String) -> void:
	if message_label:
		message_label.text = text
		message_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		message_label.show()

## Clear message
func _clear_message() -> void:
	if message_label:
		message_label.text = ""
		message_label.hide()

## Helper: Create section header
func _create_section_header(text: String) -> Label:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_SECTION)
	header.add_theme_font_size_override("font_size", 15)
	return header

## Helper: Add spacer
func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	content.add_child(spacer)

## Handle input
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		match event.keycode:
			KEY_UP:
				_navigate_up()
				viewport.set_input_as_handled()

			KEY_DOWN:
				_navigate_down()
				viewport.set_input_as_handled()

			KEY_TAB:
				_switch_column()
				viewport.set_input_as_handled()

			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL, KEY_ENTER, KEY_KP_ENTER:
				_increment_selected()
				viewport.set_input_as_handled()

			KEY_MINUS, KEY_KP_SUBTRACT:
				_decrement_selected()
				viewport.set_input_as_handled()

			KEY_C:
				_try_commit()
				viewport.set_input_as_handled()

			KEY_ESCAPE:
				# Warn if points have been allocated
				if not distributed_points.is_empty():
					_show_error("Press ESC again to cancel (will lose allocated points)")
					# Allow second ESC to actually cancel
					await get_tree().create_timer(0.1).timeout
				else:
					cancelled.emit()
					close()
				viewport.set_input_as_handled()
