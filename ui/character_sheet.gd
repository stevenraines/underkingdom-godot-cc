extends Control

## Character Sheet - Display player stats and attributes
##
## Shows comprehensive character information including attributes, derived stats,
## equipment bonuses, and survival status.

signal closed

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var stats_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Stats
@onready var stats_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Stats/ScrollMargin/ContentBox
@onready var skills_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Skills
@onready var skills_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Skills/ScrollMargin/ContentBox

var player = null  # Player instance
var current_scroll_container: ScrollContainer = null  # Track which tab is active for scrolling

# Colors matching inventory screen
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_LABEL = Color(0.85, 0.85, 0.7)
const COLOR_VALUE = Color(0.7, 0.9, 0.7)

func _ready() -> void:
	hide()
	set_process_unhandled_input(false)

	# Connect tab changed signal
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)

## Open the character sheet
func open(p_player) -> void:
	player = p_player
	_populate_content()
	_populate_skills_tab()

	# Set initial scroll container based on current tab
	_on_tab_changed(tab_container.current_tab if tab_container else 0)

	show()
	set_process_unhandled_input(true)

## Close the character sheet
func close() -> void:
	hide()
	set_process_unhandled_input(false)
	closed.emit()

## Populate the stats tab content dynamically
func _populate_content() -> void:
	# Clear existing content
	for child in stats_content.get_children():
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
	stats_content.add_child(section_header)

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

		stats_content.add_child(stat_line)

## Add the combat section
func _add_combat_section() -> void:
	var section_header = _create_section_header("== COMBAT ==")
	stats_content.add_child(section_header)

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
	stats_content.add_child(section_header)

	if not player.survival:
		_add_stat_line("Status", "No survival data", Color(0.7, 0.7, 0.7))
		return

	var s = player.survival

	# Hunger
	_add_stat_line("Hunger", "%d / 100" % int(s.hunger), _get_survival_color(s.hunger))

	# Thirst
	_add_stat_line("Thirst", "%d / 100" % int(s.thirst), _get_survival_color(s.thirst))

	# Temperature - show both outside temp and player's adjusted temp
	var env_temp = s.get_environmental_temperature()
	var player_temp = s.temperature
	var warmth_bonus = s.get_equipment_warmth()

	# Outside temperature line
	_add_stat_line("Outside Temp", "%.0f°F" % env_temp, _get_temp_color_f(env_temp))

	# Player temperature with warmth adjustment
	var temp_status = "Comfortable"
	if player_temp < s.TEMP_COOL:
		temp_status = "Cold"
	elif player_temp > s.TEMP_WARM:
		temp_status = "Hot"

	var warmth_text = ""
	if warmth_bonus != 0:
		warmth_text = " (%+.0f°F)" % warmth_bonus
	_add_stat_line("Your Temp", "%s (%.0f°F)%s" % [temp_status, player_temp, warmth_text], _get_temp_color_f(player_temp))

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
	stats_content.add_child(section_header)

	# Current date and time
	var date_str = CalendarManager.get_short_date_string()
	var time_str = TurnManager.get_time_of_day()
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
	stats_content.add_child(section_header)

	# Level
	_add_stat_line("Level", "%d" % player.level, Color(1.0, 0.85, 0.3))

	# Experience
	_add_stat_line("Experience", "%d / %d" % [player.experience, player.experience_to_next_level],
		Color(0.7, 0.85, 0.95))

	# Skill Points Available
	if player.available_skill_points > 0:
		_add_stat_line("Skill Points", "%d unspent" % player.available_skill_points,
			Color(0.95, 0.7, 0.95))  # Bright magenta for unspent points
	else:
		_add_stat_line("Skill Points", "0", Color(0.7, 0.7, 0.7))

	# Ability Points Available
	if player.available_ability_points > 0:
		_add_stat_line("Ability Points", "%d unspent" % player.available_ability_points,
			Color(0.95, 0.7, 0.7))  # Bright red for unspent points
	else:
		_add_stat_line("Ability Points", "0", Color(0.7, 0.7, 0.7))

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

	stats_content.add_child(line)

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
	stats_content.add_child(spacer)

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

## Called when tab changes
func _on_tab_changed(tab_index: int) -> void:
	# Update current scroll container based on active tab
	match tab_index:
		0:  # Stats tab
			current_scroll_container = stats_scroll
		1:  # Skills tab
			current_scroll_container = skills_scroll
		_:
			current_scroll_container = stats_scroll

## Handle input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var scroll_amount = 40  # Pixels to scroll per key press

		if current_scroll_container:
			if event.keycode == KEY_UP or event.keycode == KEY_W:
				current_scroll_container.scroll_vertical -= scroll_amount
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
				current_scroll_container.scroll_vertical += scroll_amount
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_PAGEUP:
				current_scroll_container.scroll_vertical -= scroll_amount * 5
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_PAGEDOWN:
				current_scroll_container.scroll_vertical += scroll_amount * 5
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_HOME:
				current_scroll_container.scroll_vertical = 0
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_END:
				current_scroll_container.scroll_vertical = int(current_scroll_container.get_v_scroll_bar().max_value)
				get_viewport().set_input_as_handled()

		if not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
			close()
			get_viewport().set_input_as_handled()

## =========================================================================
## SKILLS TAB
## =========================================================================

## Populate the skills tab
func _populate_skills_tab() -> void:
	# Clear existing content
	for child in skills_content.get_children():
		child.queue_free()

	# Wait a frame for nodes to be freed
	await get_tree().process_frame

	# Header
	var header = _create_section_header("== SKILLS ==")
	skills_content.add_child(header)

	_add_skills_spacer()

	# Show available points
	var points_text = "Available Skill Points: %d" % player.available_skill_points
	var points_label = Label.new()
	points_label.text = points_text
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if player.available_skill_points > 0:
		points_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.95))
	else:
		points_label.add_theme_color_override("font_color", COLOR_LABEL)
	points_label.add_theme_font_size_override("font_size", 14)
	skills_content.add_child(points_label)

	_add_skills_spacer()

	# List all skills (alphabetically sorted)
	var skill_names = player.skills.keys()
	skill_names.sort()

	for skill_name in skill_names:
		var skill_level = player.skills[skill_name]
		_add_skill_line(skill_name, skill_level)

	_add_skills_spacer()
	_add_skills_spacer()

	# Ability Score Increases
	var ability_header = _create_section_header("== ABILITY SCORE INCREASES ==")
	skills_content.add_child(ability_header)

	_add_skills_spacer()

	# Show available ability points
	var ability_points_text = "Available Ability Points: %d" % player.available_ability_points
	var ability_points_label = Label.new()
	ability_points_label.text = ability_points_text
	ability_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if player.available_ability_points > 0:
		ability_points_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.7))
	else:
		ability_points_label.add_theme_color_override("font_color", COLOR_LABEL)
	ability_points_label.add_theme_font_size_override("font_size", 14)
	skills_content.add_child(ability_points_label)

	_add_skills_spacer()

	if player.available_ability_points > 0:
		var hint_label = Label.new()
		hint_label.text = "Click a button to increase that ability score:"
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
		hint_label.add_theme_font_size_override("font_size", 13)
		skills_content.add_child(hint_label)

		_add_skills_spacer()

		# List all abilities with buttons
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
	else:
		var no_points_label = Label.new()
		no_points_label.text = "No ability points available. Gain them every 4 levels."
		no_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_points_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		no_points_label.add_theme_font_size_override("font_size", 12)
		skills_content.add_child(no_points_label)

## Add a skill line with +/- buttons
func _add_skill_line(skill_name: String, current_level: int) -> void:
	var line = HBoxContainer.new()

	# Skill name (left)
	var name_label = Label.new()
	name_label.text = "%s:" % skill_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", COLOR_LABEL)
	name_label.add_theme_font_size_override("font_size", 14)
	line.add_child(name_label)

	# Current level (center)
	var level_label = Label.new()
	level_label.text = "%d / %d" % [current_level, player.level]  # Current / Max (level cap)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.custom_minimum_size.x = 80
	if current_level >= player.level:
		level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # Gold if maxed
	else:
		level_label.add_theme_color_override("font_color", COLOR_VALUE)
	level_label.add_theme_font_size_override("font_size", 14)
	line.add_child(level_label)

	# + button (right)
	var plus_button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(30, 0)

	# Check if can increase
	var can_increase = player.available_skill_points > 0 and current_level < player.level
	plus_button.disabled = not can_increase

	if can_increase:
		plus_button.pressed.connect(func(): _on_skill_increase_pressed(skill_name))

	line.add_child(plus_button)

	skills_content.add_child(line)

## Add an ability score line with button
func _add_ability_line(ability_code: String, ability_name: String, current_value: int) -> void:
	var line = HBoxContainer.new()

	# Ability name (left)
	var name_label = Label.new()
	name_label.text = "%s:" % ability_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", COLOR_LABEL)
	name_label.add_theme_font_size_override("font_size", 14)
	line.add_child(name_label)

	# Current value (center)
	var value_label = Label.new()
	value_label.text = "%d" % current_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size.x = 80
	value_label.add_theme_color_override("font_color", COLOR_VALUE)
	value_label.add_theme_font_size_override("font_size", 14)
	line.add_child(value_label)

	# Increase button (right)
	var button = Button.new()
	button.text = "+ Increase"
	button.custom_minimum_size = Vector2(100, 0)
	button.pressed.connect(func(): _on_ability_increase_pressed(ability_code))
	line.add_child(button)

	skills_content.add_child(line)

## Called when skill increase button is pressed
func _on_skill_increase_pressed(skill_name: String) -> void:
	if player.spend_skill_point(skill_name):
		# Refresh the skills tab
		_populate_skills_tab()

## Called when ability increase button is pressed
func _on_ability_increase_pressed(ability_code: String) -> void:
	if player.increase_ability(ability_code):
		# Refresh both tabs (stats tab shows attributes, skills tab shows ability points)
		_populate_content()
		_populate_skills_tab()

## Add a spacer for skills tab
func _add_skills_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	skills_content.add_child(spacer)
