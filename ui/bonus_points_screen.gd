extends Control

## Bonus Points Screen - Distribute racial bonus ability points during character creation
##
## If the selected race grants bonus stat points (e.g., Human Versatile +2),
## this screen lets the player distribute them across abilities before starting.

signal confirmed(bonus_distributions: Dictionary)  # {STR: 1, WIS: 1}
signal cancelled()

@onready var panel: Panel = $Panel
@onready var content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/Content
@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/MessageLabel
@onready var points_label: Label = $Panel/MarginContainer/VBoxContainer/PointsLabel

var player = null  # Temporary player with race/class applied
var assigned_abilities: Dictionary = {}  # The rolled ability scores {STR: 15, DEX: 12, ...}
var total_bonus_points: int = 0
var available_points: int = 0
var distributed_points: Dictionary = {}  # {ability_code: points_added}

# Navigation state
var navigable_items: Array = []  # Array of ability codes
var selected_index: int = 0

const ABILITY_NAMES = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
const ABILITY_FULL_NAMES = {
	"STR": "Strength",
	"DEX": "Dexterity",
	"CON": "Constitution",
	"INT": "Intelligence",
	"WIS": "Wisdom",
	"CHA": "Charisma"
}

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

## Open the bonus points screen
func open(p_player, p_assigned_abilities: Dictionary, bonus_points: int) -> void:
	player = p_player
	assigned_abilities = p_assigned_abilities
	total_bonus_points = bonus_points
	available_points = bonus_points
	distributed_points.clear()

	_populate_ui()
	_update_points_label()
	_clear_message()

	# Reset selection
	selected_index = 0
	_update_selection_visual()

	show()

## Close the screen
func close() -> void:
	hide()

## Populate the UI
func _populate_ui() -> void:
	# Clear existing content
	while content.get_child_count() > 0:
		var child = content.get_child(0)
		content.remove_child(child)
		child.free()

	navigable_items.clear()

	# Instructions
	var instructions = Label.new()
	instructions.text = "Your race grants %d bonus ability point%s. Distribute them among your abilities." % [total_bonus_points, "s" if total_bonus_points != 1 else ""]
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instructions)

	_add_spacer()

	# Ability lines
	for ability in ABILITY_NAMES:
		_add_ability_line(ability)
		navigable_items.append(ability)

	_update_selection_visual()

## Add an ability line
func _add_ability_line(ability_code: String) -> void:
	var line = HBoxContainer.new()
	line.name = "Ability_" + ability_code

	# Selection indicator
	var indicator = Label.new()
	indicator.name = "Indicator"
	indicator.text = "  "
	indicator.custom_minimum_size.x = 20
	indicator.add_theme_color_override("font_color", UITheme.COLOR_SELECTED_GOLD)
	indicator.add_theme_font_size_override("font_size", 14)
	line.add_child(indicator)

	# Ability name
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = "%s (%s):" % [ability_code, ABILITY_FULL_NAMES[ability_code]]
	name_label.custom_minimum_size.x = 200
	name_label.add_theme_color_override("font_color", UITheme.COLOR_LABEL)
	name_label.add_theme_font_size_override("font_size", 14)
	line.add_child(name_label)

	# Value display
	var base_value = assigned_abilities.get(ability_code, 10)
	var bonus = distributed_points.get(ability_code, 0)

	var value_label = Label.new()
	value_label.name = "Value"
	if bonus > 0:
		value_label.text = "%d (+%d) = %d" % [base_value, bonus, base_value + bonus]
		value_label.add_theme_color_override("font_color", UITheme.COLOR_POSITIVE)
	else:
		value_label.text = "%d" % base_value
		value_label.add_theme_color_override("font_color", UITheme.COLOR_VALUE)
	value_label.add_theme_font_size_override("font_size", 14)
	line.add_child(value_label)

	content.add_child(line)

## Update the points remaining label
func _update_points_label() -> void:
	if points_label:
		points_label.text = "Bonus Points Remaining: %d / %d" % [available_points, total_bonus_points]
		if available_points > 0:
			points_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.7))
		else:
			points_label.add_theme_color_override("font_color", UITheme.COLOR_LABEL)

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
				_navigate(-1)
				viewport.set_input_as_handled()
			KEY_DOWN:
				_navigate(1)
				viewport.set_input_as_handled()
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL, KEY_ENTER, KEY_KP_ENTER:
				_increment_selected()
				viewport.set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_decrement_selected()
				viewport.set_input_as_handled()
			KEY_C:
				_try_confirm()
				viewport.set_input_as_handled()
			KEY_ESCAPE:
				cancelled.emit()
				close()
				viewport.set_input_as_handled()

## Navigate ability selection
func _navigate(delta: int) -> void:
	if navigable_items.is_empty():
		return
	selected_index = (selected_index + delta + navigable_items.size()) % navigable_items.size()
	_update_selection_visual()

## Increment selected ability
func _increment_selected() -> void:
	if available_points <= 0:
		return

	var ability_code = navigable_items[selected_index]
	distributed_points[ability_code] = distributed_points.get(ability_code, 0) + 1
	available_points -= 1

	_populate_ui()
	_update_points_label()
	_update_selection_visual()
	_clear_message()

## Decrement selected ability
func _decrement_selected() -> void:
	var ability_code = navigable_items[selected_index]
	var current = distributed_points.get(ability_code, 0)
	if current <= 0:
		return

	distributed_points[ability_code] = current - 1
	if distributed_points[ability_code] <= 0:
		distributed_points.erase(ability_code)
	available_points += 1

	_populate_ui()
	_update_points_label()
	_update_selection_visual()
	_clear_message()

## Update visual indicator for selected ability
func _update_selection_visual() -> void:
	for i in range(navigable_items.size()):
		var ability_code = navigable_items[i]
		var line = content.get_node_or_null("Ability_" + ability_code)
		if not line:
			continue
		var indicator = line.get_node_or_null("Indicator")
		var name_node = line.get_node_or_null("Name")
		if i == selected_index:
			if indicator:
				indicator.text = ">"
			if name_node:
				name_node.add_theme_color_override("font_color", UITheme.COLOR_SELECTED_GOLD)
		else:
			if indicator:
				indicator.text = "  "
			if name_node:
				name_node.add_theme_color_override("font_color", UITheme.COLOR_LABEL)

## Try to confirm
func _try_confirm() -> void:
	if available_points > 0:
		_show_message("You must distribute all %d bonus point%s!" % [total_bonus_points, "s" if total_bonus_points != 1 else ""], UITheme.COLOR_ERROR)
		return

	confirmed.emit(distributed_points)
	close()

## Show message
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

## Helper: Add spacer
func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	content.add_child(spacer)
