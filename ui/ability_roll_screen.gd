extends Control

## Ability Roll Screen - Roll and assign ability scores during character creation
##
## Players roll 4d6 drop lowest six times, then assign the values to abilities

signal confirmed(assigned_abilities: Dictionary)  # {STR: 15, DEX: 12, ...}
signal cancelled()

@onready var panel: Panel = $Panel
@onready var content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/Content
@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/MessageLabel

var player = null  # Reference for preview calculations
var rolled_values: Array[int] = []  # 6 rolled numbers
var assigned_values: Dictionary = {}  # {"STR": 15, "DEX": 12, ...}
var available_rolls: Array[int] = []  # Remaining unassigned rolls
var selected_ability_index: int = 0  # Which ability (0-5) is selected

const ABILITY_NAMES = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const ABILITY_FULL_NAMES = {
	"STR": "Strength",
	"DEX": "Dexterity",
	"CON": "Constitution",
	"INT": "Intelligence",
	"WIS": "Wisdom",
	"CHA": "Charisma"
}

# Colors from UITheme autoload

# UI element tracking
var ability_lines: Array = []  # Array of HBoxContainer nodes for each ability
var roll_labels: Array = []  # Array of Label nodes for rolled values

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

## Open the ability roll screen
func open(p_player) -> void:
	player = p_player
	_roll_all_abilities()
	_auto_assign_by_class()
	_populate_ui()
	_clear_message()
	show()

## Close the screen
func close() -> void:
	hide()

## Roll all 6 ability scores using 4d6 drop lowest
func _roll_all_abilities() -> void:
	rolled_values.clear()
	assigned_values.clear()

	for i in range(6):
		rolled_values.append(_roll_4d6_drop_lowest())

	# Sort high to low for display
	rolled_values.sort()
	rolled_values.reverse()

	# Copy to available pool
	available_rolls = rolled_values.duplicate()

## Roll 4d6 and drop the lowest die
func _roll_4d6_drop_lowest() -> int:
	var rolls = [
		randi_range(1, 6),
		randi_range(1, 6),
		randi_range(1, 6),
		randi_range(1, 6)
	]
	rolls.sort()
	# Drop lowest (index 0), sum the rest
	return rolls[1] + rolls[2] + rolls[3]

## Auto-assign rolled values to abilities based on class priority
## Highest rolled value goes to the class's most important ability, etc.
func _auto_assign_by_class() -> void:
	assigned_values.clear()
	available_rolls = rolled_values.duplicate()

	# Get class priority order from ClassManager
	var class_id = GameManager.player_class
	var priority = ClassManager.get_priority_abilities(class_id)

	# Sort available rolls high to low
	var sorted_rolls = rolled_values.duplicate()
	sorted_rolls.sort()
	sorted_rolls.reverse()

	# Assign highest values to highest-priority abilities
	for i in range(priority.size()):
		if i < sorted_rolls.size():
			assigned_values[priority[i]] = sorted_rolls[i]
			available_rolls.erase(sorted_rolls[i])


## Populate the UI
func _populate_ui() -> void:
	# Clear existing content
	while content.get_child_count() > 0:
		var child = content.get_child(0)
		content.remove_child(child)
		child.free()

	ability_lines.clear()
	roll_labels.clear()

	# Header
	var header = _create_section_header("ABILITY SCORE GENERATION")
	content.add_child(header)

	_add_spacer()

	# Instructions
	var instructions = Label.new()
	instructions.text = "Scores auto-assigned by class. Use 1-6 to reassign, A to auto-assign, R to re-roll."
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instructions)

	_add_spacer()

	# Rolled values display
	var rolls_header = _create_section_header("Rolled Values")
	content.add_child(rolls_header)

	var rolls_line = HBoxContainer.new()
	rolls_line.alignment = BoxContainer.ALIGNMENT_CENTER
	rolls_line.add_theme_constant_override("separation", 12)

	# Count available occurrences of each value (for handling duplicates)
	var available_counts = {}
	for value in available_rolls:
		available_counts[value] = available_counts.get(value, 0) + 1

	for i in range(rolled_values.size()):
		var roll_value = rolled_values[i]
		var roll_label = Label.new()
		roll_label.text = "[%d] %d" % [i + 1, roll_value]
		roll_label.add_theme_font_size_override("font_size", 16)

		# Highlight if still available (accounting for duplicates)
		if available_counts.get(roll_value, 0) > 0:
			roll_label.add_theme_color_override("font_color", UITheme.COLOR_VALUE)
			available_counts[roll_value] -= 1  # Consume one occurrence
		else:
			roll_label.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)

		rolls_line.add_child(roll_label)
		roll_labels.append(roll_label)

	content.add_child(rolls_line)

	_add_spacer()

	# Assignment section
	var assign_header = _create_section_header("Assign to Abilities")
	content.add_child(assign_header)

	_add_spacer()

	# Ability lines
	for i in range(ABILITY_NAMES.size()):
		_add_ability_line(i)

	# Update selection visual
	_update_selection_visual()

## Add an ability assignment line
func _add_ability_line(ability_index: int) -> void:
	var ability_name = ABILITY_NAMES[ability_index]
	var full_name = ABILITY_FULL_NAMES[ability_name]

	var line = HBoxContainer.new()

	# Selection indicator
	var indicator = Label.new()
	indicator.text = "  "  # Will be set to "►" for selected
	indicator.custom_minimum_size.x = 20
	indicator.add_theme_font_size_override("font_size", 14)
	line.add_child(indicator)

	# Ability name
	var name_label = Label.new()
	name_label.text = "%s (%s):" % [ability_name, full_name]
	name_label.custom_minimum_size.x = 200
	name_label.add_theme_color_override("font_color", UITheme.COLOR_LABEL)
	name_label.add_theme_font_size_override("font_size", 14)
	line.add_child(name_label)

	# Assigned value
	var value_label = Label.new()
	if assigned_values.has(ability_name):
		var assigned = assigned_values[ability_name]
		var final_value = _calculate_final_value(ability_name, assigned)
		var racial_mod = player.racial_stat_modifiers.get(ability_name, 0)
		var class_mod = player.class_stat_modifiers.get(ability_name, 0)
		var total_mod = racial_mod + class_mod

		if total_mod != 0:
			var mod_text = "%+d" % total_mod if total_mod > 0 else "%d" % total_mod
			value_label.text = "%d → Final: %d (%s)" % [assigned, final_value, mod_text]
			value_label.add_theme_color_override("font_color", UITheme.COLOR_VALUE)
		else:
			value_label.text = "%d → Final: %d" % [assigned, final_value]
			value_label.add_theme_color_override("font_color", UITheme.COLOR_VALUE)
	else:
		value_label.text = "[Unassigned]"
		value_label.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)

	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.add_theme_font_size_override("font_size", 14)
	line.add_child(value_label)

	content.add_child(line)
	ability_lines.append(line)

## Calculate final value with racial/class modifiers
func _calculate_final_value(ability: String, roll_value: int) -> int:
	var racial_mod = player.racial_stat_modifiers.get(ability, 0)
	var class_mod = player.class_stat_modifiers.get(ability, 0)
	return roll_value + racial_mod + class_mod

## Assign a rolled value to the selected ability
func _assign_value_to_selected_ability(roll_index: int) -> void:
	if roll_index < 0 or roll_index >= rolled_values.size():
		_show_error("Invalid roll selection!")
		return

	# Get the value from the original rolled_values array (not available_rolls)
	var roll_value = rolled_values[roll_index]
	var ability_name = ABILITY_NAMES[selected_ability_index]

	# Check if we're trying to assign the same value to the same ability (unassign it)
	if assigned_values.has(ability_name) and assigned_values[ability_name] == roll_value:
		# Unassign: return value to available pool
		available_rolls.append(roll_value)
		available_rolls.sort()
		available_rolls.reverse()
		assigned_values.erase(ability_name)
		_populate_ui()
		_clear_message()
		return

	# Check if this value is still available
	if roll_value not in available_rolls:
		_show_error("That value has already been assigned!")
		return

	# If ability already has a different value, return it to available pool
	if assigned_values.has(ability_name):
		var old_value = assigned_values[ability_name]
		available_rolls.append(old_value)
		available_rolls.sort()
		available_rolls.reverse()

	# Assign new value
	assigned_values[ability_name] = roll_value
	available_rolls.erase(roll_value)

	# Refresh UI
	_populate_ui()
	_clear_message()

	# Auto-advance to next unassigned ability
	_navigate_to_next_unassigned()

## Navigate ability selection
func _navigate(delta: int) -> void:
	selected_ability_index = (selected_ability_index + delta) % ABILITY_NAMES.size()
	if selected_ability_index < 0:
		selected_ability_index = ABILITY_NAMES.size() - 1
	_update_selection_visual()

## Navigate to next unassigned ability
func _navigate_to_next_unassigned() -> void:
	# Find the next unassigned ability starting from current position
	var start_index = selected_ability_index
	for i in range(ABILITY_NAMES.size()):
		var check_index = (start_index + i + 1) % ABILITY_NAMES.size()
		var ability_name = ABILITY_NAMES[check_index]
		if not assigned_values.has(ability_name):
			selected_ability_index = check_index
			_update_selection_visual()
			return
	# If all abilities are assigned, stay on current selection

## Unassign the currently selected ability
func _unassign_selected() -> void:
	var ability_name = ABILITY_NAMES[selected_ability_index]

	if not assigned_values.has(ability_name):
		_show_error("This ability has no value assigned!")
		return

	# Return value to available pool
	var old_value = assigned_values[ability_name]
	available_rolls.append(old_value)
	available_rolls.sort()
	available_rolls.reverse()
	assigned_values.erase(ability_name)

	_populate_ui()
	_clear_message()

## Update visual indicator for selected ability
func _update_selection_visual() -> void:
	for i in range(ability_lines.size()):
		if i < ability_lines.size():
			var line = ability_lines[i]
			var indicator = line.get_child(0) as Label
			if i == selected_ability_index:
				indicator.text = "►"
				indicator.add_theme_color_override("font_color", UITheme.COLOR_SELECTED_GOLD)
			else:
				indicator.text = "  "

## Check if all abilities are assigned
func _can_confirm() -> bool:
	return assigned_values.size() == 6

## Try to confirm and proceed
func _try_confirm() -> void:
	if not _can_confirm():
		_show_error("You must assign all 6 rolled values to abilities!")
		return

	confirmed.emit(assigned_values)
	close()

## Show error message
func _show_error(text: String) -> void:
	if message_label:
		message_label.text = text
		message_label.add_theme_color_override("font_color", UITheme.COLOR_ERROR)
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
	header.add_theme_color_override("font_color", UITheme.COLOR_SECTION)
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
			KEY_UP, KEY_W:
				_navigate(-1)
				viewport.set_input_as_handled()

			KEY_DOWN, KEY_S:
				_navigate(1)
				viewport.set_input_as_handled()

			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				var index = event.keycode - KEY_1
				_assign_value_to_selected_ability(index)
				viewport.set_input_as_handled()

			KEY_MINUS, KEY_KP_SUBTRACT, KEY_BACKSPACE, KEY_DELETE:
				_unassign_selected()
				viewport.set_input_as_handled()

			KEY_R:
				_roll_all_abilities()
				_auto_assign_by_class()
				_populate_ui()
				_clear_message()
				viewport.set_input_as_handled()

			KEY_A:
				_auto_assign_by_class()
				_populate_ui()
				_clear_message()
				viewport.set_input_as_handled()

			KEY_C:
				_try_confirm()
				# Don't set input as handled - might trigger scene change that removes us from tree

			KEY_ESCAPE:
				cancelled.emit()
				close()
				viewport.set_input_as_handled()
