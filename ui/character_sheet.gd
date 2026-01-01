extends Control

## Character Sheet - Display player stats and attributes
##
## Shows comprehensive character information including attributes, derived stats,
## equipment bonuses, and survival status.

signal closed

var player = null  # Player instance

# UI elements - created programmatically
var panel: Panel
var content_container: VBoxContainer
var scroll_container: ScrollContainer

# Colors matching inventory screen
const COLOR_TITLE = Color(0.6, 0.9, 0.6, 1)
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_LABEL = Color(0.85, 0.85, 0.7)
const COLOR_VALUE = Color(0.7, 0.9, 0.7)
const COLOR_FOOTER = Color(0.7, 0.7, 0.7)
const COLOR_BORDER = Color(0.4, 0.6, 0.4, 1)

func _ready() -> void:
	_build_ui()
	hide()
	set_process_unhandled_input(false)

## Build the UI programmatically
func _build_ui() -> void:
	# Make this control fill the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Explicitly set size to viewport for CanvasLayer parenting
	var viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size

	# Dimmer background
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.7)
	add_child(dimmer)

	# Main panel - centered in viewport
	panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_top = -280
	panel.offset_right = 300
	panel.offset_bottom = 280
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Margin container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	# VBox for layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "◆ CHARACTER SHEET ◆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Separator
	var sep1 = HSeparator.new()
	sep1.add_theme_constant_override("separation", 4)
	vbox.add_child(sep1)

	# Scroll container for content
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll_container)

	# Content container
	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 2)
	scroll_container.add_child(content_container)

	# Separator
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 4)
	vbox.add_child(sep2)

	# Footer
	var footer = Label.new()
	footer.text = "↑↓ Scroll  |  [P] [ESC] Close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", COLOR_FOOTER)
	footer.add_theme_font_size_override("font_size", 13)
	vbox.add_child(footer)

## Open the character sheet for a player
func open(p) -> void:  # p is Player instance
	player = p
	refresh()
	show()
	set_process_unhandled_input(true)

## Close the character sheet
func close() -> void:
	hide()
	set_process_unhandled_input(false)
	closed.emit()

## Refresh all displayed stats
func refresh() -> void:
	if not player:
		return
	_update_display()

## Update the entire display
func _update_display() -> void:
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()

	# Build sections
	_add_attributes_section()
	_add_spacer()
	_add_combat_section()
	_add_spacer()
	_add_survival_section()
	_add_spacer()
	_add_progression_section()

## Add the attributes section (STR, DEX, CON, INT, WIS, CHA)
func _add_attributes_section() -> void:
	var section_header = _create_section_header("== ATTRIBUTES ==")
	content_container.add_child(section_header)

	var attributes = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
	var attribute_names = {
		"STR": "Strength",
		"DEX": "Dexterity",
		"CON": "Constitution",
		"INT": "Intelligence",
		"WIS": "Wisdom",
		"CHA": "Charisma"
	}

	for attr in attributes:
		var base_value = player.attributes.get(attr, 10)
		var modifier = player.stat_modifiers.get(attr, 0)
		var effective = player.get_effective_attribute(attr)

		var stat_line = HBoxContainer.new()

		# Attribute name (left-aligned)
		var name_label = Label.new()
		name_label.text = "%s:" % attribute_names[attr]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if theme != null:
			name_label.theme = theme
		name_label.add_theme_color_override("font_color", COLOR_LABEL)
		name_label.add_theme_font_size_override("font_size", 14)
		stat_line.add_child(name_label)

		# Value display (right-aligned)
		var value_label = Label.new()
		if theme != null:
			value_label.theme = theme
		if modifier != 0:
			var modifier_text = "+%d" % modifier if modifier > 0 else "%d" % modifier
			value_label.text = "%d %s = %d" % [base_value, modifier_text, effective]
			value_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4) if modifier > 0 else Color(1.0, 0.5, 0.5))
		else:
			value_label.text = "%d" % effective
			value_label.add_theme_color_override("font_color", COLOR_VALUE)

		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size.x = 120
		value_label.add_theme_font_size_override("font_size", 14)
		stat_line.add_child(value_label)

		content_container.add_child(stat_line)

## Add the combat section
func _add_combat_section() -> void:
	var section_header = _create_section_header("══ COMBAT ══")
	content_container.add_child(section_header)

	# Health
	_add_stat_line("Health", "%d / %d" % [player.current_health, player.max_health],
		_get_health_color(float(player.current_health) / float(player.max_health)))

	# Stamina
	if player.survival:
		var max_stam = player.survival.get_max_stamina()
		_add_stat_line("Stamina", "%d / %d" % [int(player.survival.stamina), int(max_stam)],
			_get_stamina_color(player.survival.stamina / max_stam))

	# Damage
	var weapon_damage = player.get_weapon_damage()
	var equipped_weapon = player.inventory.get_equipped("main_hand") if player.inventory else null
	if equipped_weapon:
		_add_stat_line("Damage", "%d (base: %d + weapon: %d)" % [weapon_damage, player.base_damage, weapon_damage - player.base_damage],
			Color(0.9, 0.7, 0.5))
	else:
		_add_stat_line("Damage", "%d (unarmed)" % weapon_damage, Color(0.7, 0.7, 0.7))

	# Armor
	var total_armor = player.get_total_armor()
	if total_armor > 0:
		_add_stat_line("Armor", "%d" % total_armor, Color(0.7, 0.8, 0.9))
	else:
		_add_stat_line("Armor", "0 (no armor)", Color(0.7, 0.7, 0.7))

	# Accuracy (based on DEX)
	var accuracy = 50 + (player.get_effective_attribute("DEX") * 2)
	_add_stat_line("Accuracy", "%d%%" % accuracy, Color(0.8, 0.9, 0.8))

	# Evasion (based on DEX)
	var evasion = 10 + player.get_effective_attribute("DEX")
	_add_stat_line("Evasion", "%d%%" % evasion, Color(0.8, 0.9, 0.8))

## Add the survival section
func _add_survival_section() -> void:
	var section_header = _create_section_header("══ SURVIVAL ══")
	content_container.add_child(section_header)

	if not player.survival:
		_add_stat_line("Status", "No survival data", Color(0.7, 0.7, 0.7))
		return

	var s = player.survival

	# Hunger
	_add_stat_line("Hunger", "%d%% (%s)" % [int(s.hunger), s.get_hunger_state().capitalize()],
		_get_survival_stat_color(s.hunger))

	# Thirst
	_add_stat_line("Thirst", "%d%% (%s)" % [int(s.thirst), s.get_thirst_state().capitalize()],
		_get_survival_stat_color(s.thirst))

	# Temperature
	var temp_state = s.get_temperature_state()
	_add_stat_line("Temperature", "%.0f°F (%s)" % [s.temperature, temp_state.capitalize()],
		_get_temperature_color(s.temperature))

	# Fatigue
	_add_stat_line("Fatigue", "%d%% (%s)" % [int(s.fatigue), s.get_fatigue_state().capitalize()],
		_get_fatigue_color(s.fatigue))

	# Encumbrance
	if player.inventory:
		var weight = player.inventory.get_total_weight()
		var max_weight = player.inventory.max_weight
		var percent = (weight / max_weight) * 100.0
		_add_stat_line("Carry Weight", "%.1f / %.1f kg (%.0f%%)" % [weight, max_weight, percent],
			_get_encumbrance_color(percent))

## Add the progression section
func _add_progression_section() -> void:
	var section_header = _create_section_header("══ PROGRESSION ══")
	content_container.add_child(section_header)

	# Experience
	_add_stat_line("Experience", "%d / %d" % [player.experience, player.experience_to_next_level],
		Color(0.7, 0.85, 0.95))

	# Gold
	_add_stat_line("Gold", "%d" % player.gold, Color(1.0, 0.85, 0.3))

	# Known recipes
	_add_stat_line("Recipes Known", "%d" % player.known_recipes.size(), Color(0.8, 0.9, 0.7))

	# Perception range
	_add_stat_line("Perception", "%d tiles" % player.perception_range, Color(0.8, 0.8, 0.9))

## Helper: Add a stat line with label and value
func _add_stat_line(label_text: String, value_text: String, value_color: Color) -> void:
	var line = HBoxContainer.new()

	var label = Label.new()
	label.text = "%s:" % label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if theme != null:
		label.theme = theme
	label.add_theme_color_override("font_color", COLOR_LABEL)
	label.add_theme_font_size_override("font_size", 14)
	line.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 180
	if theme != null:
		value.theme = theme
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_font_size_override("font_size", 14)
	line.add_child(value)

	content_container.add_child(line)

## Helper: Create a section header
func _create_section_header(text: String) -> Label:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Set theme first, then override specific properties
	if has_theme():
		header.theme = theme
	header.add_theme_color_override("font_color", COLOR_SECTION)
	header.add_theme_font_size_override("font_size", 15)
	return header

## Helper: Add a spacer
func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	content_container.add_child(spacer)

## Get color for health percentage
func _get_health_color(percent: float) -> Color:
	if percent > 0.75:
		return Color(0.6, 0.9, 0.6)
	elif percent > 0.5:
		return Color(0.9, 0.9, 0.4)
	elif percent > 0.25:
		return Color(1.0, 0.7, 0.3)
	else:
		return Color(1.0, 0.4, 0.4)

## Get color for stamina percentage
func _get_stamina_color(percent: float) -> Color:
	if percent > 0.6:
		return Color(0.6, 0.85, 0.9)
	elif percent > 0.3:
		return Color(0.9, 0.85, 0.5)
	else:
		return Color(1.0, 0.6, 0.4)

## Get color for survival stats (hunger/thirst)
func _get_survival_stat_color(value: float) -> Color:
	if value > 75:
		return Color(0.6, 0.9, 0.6)
	elif value > 50:
		return Color(0.9, 0.9, 0.5)
	elif value > 25:
		return Color(1.0, 0.7, 0.4)
	else:
		return Color(1.0, 0.4, 0.4)

## Get color for temperature (in Fahrenheit)
func _get_temperature_color(temp: float) -> Color:
	if temp >= 59 and temp <= 77:  # 15-25°C comfortable
		return Color(0.6, 0.9, 0.6)
	elif temp >= 50 and temp <= 86:  # 10-30°C okay
		return Color(0.9, 0.9, 0.5)
	else:
		return Color(1.0, 0.5, 0.5)

## Get color for fatigue
func _get_fatigue_color(fatigue: float) -> Color:
	if fatigue < 25:
		return Color(0.6, 0.9, 0.6)
	elif fatigue < 50:
		return Color(0.9, 0.9, 0.5)
	elif fatigue < 75:
		return Color(1.0, 0.7, 0.4)
	else:
		return Color(1.0, 0.4, 0.4)

## Get color for encumbrance percentage
func _get_encumbrance_color(percent: float) -> Color:
	if percent < 75:
		return Color(0.6, 0.9, 0.6)
	elif percent < 100:
		return Color(0.9, 0.9, 0.5)
	elif percent < 125:
		return Color(1.0, 0.6, 0.3)
	else:
		return Color(1.0, 0.3, 0.3)

## Handle input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var scroll_amount = 40  # Pixels to scroll per key press

		if event.keycode == KEY_UP or event.keycode == KEY_W:
			scroll_container.scroll_vertical -= scroll_amount
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			scroll_container.scroll_vertical += scroll_amount
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_PAGEUP:
			scroll_container.scroll_vertical -= scroll_amount * 5
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_PAGEDOWN:
			scroll_container.scroll_vertical += scroll_amount * 5
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_HOME:
			scroll_container.scroll_vertical = 0
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_END:
			scroll_container.scroll_vertical = int(scroll_container.get_v_scroll_bar().max_value)
			get_viewport().set_input_as_handled()
		elif not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
			close()
			get_viewport().set_input_as_handled()
