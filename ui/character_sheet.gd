extends Control

## Character Sheet - Display player stats and attributes
##
## Shows comprehensive character information including attributes, derived stats,
## equipment bonuses, and survival status.

signal closed

@onready var scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var content_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/ScrollMargin/ContentBox

var player = null  # Player instance

# Colors matching inventory screen
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_LABEL = Color(0.85, 0.85, 0.7)
const COLOR_VALUE = Color(0.7, 0.9, 0.7)

func _ready() -> void:
	hide()
	set_process_unhandled_input(false)

## Open the character sheet
func open(p_player) -> void:
	player = p_player
	_populate_content()
	show()
	set_process_unhandled_input(true)

## Close the character sheet
func close() -> void:
	hide()
	set_process_unhandled_input(false)
	closed.emit()

## Populate the content dynamically
func _populate_content() -> void:
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()

	# Wait a frame for nodes to be freed
	await get_tree().process_frame

	# Add sections
	_add_attributes_section()
	_add_spacer()
	_add_combat_section()
	_add_spacer()
	_add_survival_section()
	_add_spacer()
	_add_weather_section()
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
		name_label.add_theme_color_override("font_color", COLOR_LABEL)
		name_label.add_theme_font_size_override("font_size", 14)
		stat_line.add_child(name_label)

		# Value display (right-aligned)
		var value_label = Label.new()
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
	var section_header = _create_section_header("== COMBAT ==")
	content_container.add_child(section_header)

	# Health
	_add_stat_line("Health", "%d / %d" % [player.current_health, player.max_health],
		_get_health_color(float(player.current_health) / float(player.max_health)))

	# Stamina
	if player.survival:
		var current_stamina = int(player.survival.stamina)
		var max_stamina = int(player.survival.get_max_stamina())
		_add_stat_line("Stamina", "%d / %d" % [current_stamina, max_stamina],
			_get_stamina_color(float(current_stamina) / float(max_stamina)))

	# Weapon damage
	var weapon_damage = "Unarmed (%d)" % player.base_damage
	if player.inventory:
		var weapon = player.inventory.get_equipped("main_hand")
		if weapon and weapon.damage_bonus > 0:
			weapon_damage = "%s (+%d)" % [weapon.name, weapon.damage_bonus]
	_add_stat_line("Weapon", weapon_damage, Color(0.9, 0.7, 0.7))

	# Armor
	var total_armor = player.get_total_armor()
	_add_stat_line("Armor", "%d" % total_armor, Color(0.7, 0.7, 0.9))

	# Accuracy (based on DEX and weapon)
	var accuracy = 70 + player.get_effective_attribute("DEX")
	_add_stat_line("Accuracy", "%d%%" % accuracy, Color(0.8, 0.9, 0.8))

	# Evasion (based on DEX)
	var evasion = 10 + player.get_effective_attribute("DEX")
	_add_stat_line("Evasion", "%d%%" % evasion, Color(0.8, 0.9, 0.8))

## Add the survival section
func _add_survival_section() -> void:
	var section_header = _create_section_header("== SURVIVAL ==")
	content_container.add_child(section_header)

	if not player.survival:
		_add_stat_line("Status", "No survival data", Color(0.7, 0.7, 0.7))
		return

	var s = player.survival

	# Hunger
	_add_stat_line("Hunger", "%d / 100" % int(s.hunger), _get_survival_color(s.hunger))

	# Thirst
	_add_stat_line("Thirst", "%d / 100" % int(s.thirst), _get_survival_color(s.thirst))

	# Temperature (survival system uses Fahrenheit)
	var temp_status = "Comfortable"
	if s.temperature < s.TEMP_COOL:
		temp_status = "Cold"
	elif s.temperature > s.TEMP_WARM:
		temp_status = "Hot"
	_add_stat_line("Temperature", "%s (%.0f°F)" % [temp_status, s.temperature], _get_temp_color_f(s.temperature))

	# Encumbrance
	if player.inventory:
		var weight = player.inventory.get_total_weight()
		var max_weight = player.inventory.max_weight
		var percent = (weight / max_weight) * 100.0
		_add_stat_line("Carry Weight", "%.1f / %.1f kg (%.0f%%)" % [weight, max_weight, percent],
			_get_encumbrance_color(percent))

## Add the weather section
func _add_weather_section() -> void:
	var section_header = _create_section_header("== WEATHER ==")
	content_container.add_child(section_header)

	# Current date and time
	var date_str = CalendarManager.get_short_date_string()
	var time_str = CalendarManager.get_time_of_day_name()
	_add_stat_line("Date", date_str, Color(0.8, 0.8, 0.6))
	_add_stat_line("Time", time_str.capitalize(), _get_time_color(time_str))

	# Current weather
	var weather = WeatherManager.get_current_weather()
	if weather.is_empty():
		_add_stat_line("Weather", "Unknown", Color(0.7, 0.7, 0.7))
	else:
		var weather_name = weather.get("name", "Unknown")
		var weather_char = weather.get("ascii_char", "?")
		var weather_color_hex = weather.get("color", "#FFFFFF")
		var weather_color = Color.from_string(weather_color_hex, Color.WHITE)

		# Weather name with icon
		_add_stat_line("Weather", "%s %s" % [weather_char, weather_name], weather_color)

		# Temperature modifier
		var temp_mod = weather.get("temp_modifier", 0)
		if temp_mod != 0:
			var mod_text = "%+d°F" % temp_mod
			var mod_color = Color(0.4, 0.8, 1.0) if temp_mod < 0 else Color(1.0, 0.6, 0.4)
			_add_stat_line("Weather Effect", mod_text, mod_color)

		# Visibility modifier
		var vis_mod = weather.get("visibility_modifier", 0)
		if vis_mod != 0:
			_add_stat_line("Visibility", "%+d tiles" % vis_mod, Color(0.7, 0.7, 0.9))

		# Shelter warning
		if weather.get("shelter_required", false):
			_add_stat_line("Warning", "Seek shelter!", Color(1.0, 0.4, 0.4))

	# Season
	var season = CalendarManager.get_season_name()
	_add_stat_line("Season", season.capitalize(), _get_season_color(season))

## Helper: Get color for time of day
func _get_time_color(time_of_day: String) -> Color:
	match time_of_day:
		"dawn":
			return Color(1.0, 0.8, 0.5)  # Orange
		"day", "mid_day":
			return Color(1.0, 1.0, 0.7)  # Yellow
		"dusk":
			return Color(0.9, 0.6, 0.5)  # Reddish
		"night", "midnight":
			return Color(0.5, 0.5, 0.8)  # Blue
		_:
			return Color(0.8, 0.8, 0.8)

## Helper: Get color for season
func _get_season_color(season: String) -> Color:
	match season:
		"spring":
			return Color(0.5, 1.0, 0.5)  # Green
		"summer":
			return Color(1.0, 0.9, 0.3)  # Yellow
		"autumn":
			return Color(1.0, 0.6, 0.3)  # Orange
		"winter":
			return Color(0.7, 0.9, 1.0)  # Light blue
		_:
			return Color(0.8, 0.8, 0.8)

## Add the progression section
func _add_progression_section() -> void:
	var section_header = _create_section_header("== PROGRESSION ==")
	content_container.add_child(section_header)

	# Experience
	_add_stat_line("Experience", "%d / %d" % [player.experience, player.experience_to_next_level],
		Color(0.7, 0.85, 0.95))

	# Gold
	_add_stat_line("Gold", "%d" % player.gold, Color(1.0, 0.85, 0.3))

	# Known Recipes
	_add_stat_line("Recipes Known", "%d" % player.known_recipes.size(), Color(0.8, 0.8, 0.6))

## Helper: Add a stat line with label and value
func _add_stat_line(label_text: String, value_text: String, value_color: Color) -> void:
	var line = HBoxContainer.new()

	var label = Label.new()
	label.text = "%s:" % label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", COLOR_LABEL)
	label.add_theme_font_size_override("font_size", 14)
	line.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.custom_minimum_size.x = 180
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_font_size_override("font_size", 14)
	line.add_child(value)

	content_container.add_child(line)

## Helper: Create a section header
func _create_section_header(text: String) -> Label:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_SECTION)
	header.add_theme_font_size_override("font_size", 15)
	return header

## Helper: Add a spacer
func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	content_container.add_child(spacer)

## Color helpers
func _get_health_color(ratio: float) -> Color:
	if ratio > 0.7:
		return Color(0.5, 1.0, 0.5)  # Green
	elif ratio > 0.3:
		return Color(1.0, 0.85, 0.3)  # Yellow
	else:
		return Color(1.0, 0.4, 0.4)  # Red

func _get_stamina_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.4, 0.8, 1.0)  # Blue
	elif ratio > 0.2:
		return Color(0.8, 0.8, 0.4)  # Yellow
	else:
		return Color(0.8, 0.4, 0.4)  # Red

func _get_survival_color(value: float) -> Color:
	if value > 70:
		return Color(0.5, 1.0, 0.5)  # Green
	elif value > 30:
		return Color(1.0, 0.85, 0.3)  # Yellow
	else:
		return Color(1.0, 0.4, 0.4)  # Red

func _get_temp_color_f(temp: float) -> Color:
	# Fahrenheit thresholds from SurvivalSystem
	# TEMP_COOL = 59, TEMP_WARM = 77, TEMP_COLD = 50, TEMP_HOT = 86
	if temp >= 59.0 and temp <= 77.0:
		return Color(0.5, 1.0, 0.5)  # Green - comfortable
	elif temp < 50.0 or temp > 86.0:
		return Color(1.0, 0.4, 0.4)  # Red - dangerous
	else:
		return Color(1.0, 0.85, 0.3)  # Yellow - warning

func _get_encumbrance_color(percent: float) -> Color:
	if percent <= 75:
		return Color(0.5, 1.0, 0.5)  # Green
	elif percent <= 100:
		return Color(1.0, 0.85, 0.3)  # Yellow
	else:
		return Color(1.0, 0.4, 0.4)  # Red

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
