extends Control

## Character Sheet - Display player stats and attributes
##
## Shows comprehensive character information including attributes, derived stats,
## equipment bonuses, and survival status.

signal closed

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var progression_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Progression
@onready var progression_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Progression/ScrollMargin/ContentBox
@onready var abilities_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Abilities
@onready var abilities_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Abilities/ScrollMargin/ContentBox
@onready var skills_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Skills
@onready var skills_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Skills/ScrollMargin/ContentBox
@onready var combat_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Combat
@onready var combat_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Combat/ScrollMargin/ContentBox
@onready var survival_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Survival
@onready var survival_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Survival/ScrollMargin/ContentBox
@onready var weather_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Weather
@onready var weather_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Weather/ScrollMargin/ContentBox

var player = null  # Player instance
var current_scroll_container: ScrollContainer = null  # Track which tab is active for scrolling
var current_content_box: VBoxContainer = null  # Track which content box to add to

# Colors matching inventory screen
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_LABEL = Color(0.85, 0.85, 0.7)
const COLOR_VALUE = Color(0.7, 0.9, 0.7)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect tab changed signal
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)

## Open the character sheet
func open(p_player) -> void:
	player = p_player

	# Populate all 6 tabs
	_populate_progression_tab()
	_populate_abilities_tab()
	_populate_skills_tab()
	_populate_combat_tab()
	_populate_survival_tab()
	_populate_weather_tab()

	# Set initial scroll container based on current tab
	_on_tab_changed(tab_container.current_tab if tab_container else 0)

	show()

## Close the character sheet
func close() -> void:
	hide()
	closed.emit()

## Populate the Progression tab
func _populate_progression_tab() -> void:
	# Clear existing children immediately (don't await - causes async issues)
	for child in progression_content.get_children():
		child.queue_free()
	current_content_box = progression_content
	_add_progression_section()

## Populate the Abilities tab
func _populate_abilities_tab() -> void:
	for child in abilities_content.get_children():
		child.queue_free()
	current_content_box = abilities_content
	_add_attributes_section()

## Populate the Skills tab
func _populate_skills_tab() -> void:
	for child in skills_content.get_children():
		child.queue_free()
	current_content_box = skills_content
	_add_skills_section()

## Populate the Combat tab
func _populate_combat_tab() -> void:
	for child in combat_content.get_children():
		child.queue_free()
	current_content_box = combat_content
	_add_combat_section()

## Populate the Survival tab
func _populate_survival_tab() -> void:
	for child in survival_content.get_children():
		child.queue_free()
	current_content_box = survival_content
	_add_survival_section()

## Populate the Weather tab
func _populate_weather_tab() -> void:
	for child in weather_content.get_children():
		child.queue_free()
	current_content_box = weather_content
	_add_weather_section()

## Add the attributes section (STR, DEX, CON, INT, WIS, CHA)
func _add_attributes_section() -> void:
	var section_header = _create_section_header("== ATTRIBUTES ==")
	abilities_content.add_child(section_header)

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

		abilities_content.add_child(stat_line)

## Add the skills section
func _add_skills_section() -> void:
	var section_header = _create_section_header("== SKILLS ==")
	skills_content.add_child(section_header)

	# Get skill names sorted alphabetically
	var skill_names = player.skills.keys()
	skill_names.sort()

	if skill_names.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No skills learned yet"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.add_theme_font_size_override("font_size", 14)
		skills_content.add_child(empty_label)
		return

	for skill_name in skill_names:
		var skill_level = player.skills[skill_name]

		var skill_line = HBoxContainer.new()

		# Skill name (left-aligned)
		var name_label = Label.new()
		name_label.text = "%s:" % skill_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_color_override("font_color", COLOR_LABEL)
		name_label.add_theme_font_size_override("font_size", 14)
		skill_line.add_child(name_label)

		# Value display (right-aligned) - just show current level
		var value_label = Label.new()
		value_label.text = "%d" % skill_level
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.custom_minimum_size.x = 80

		# Color based on skill level
		if skill_level > 0:
			value_label.add_theme_color_override("font_color", COLOR_VALUE)  # Green - has points
		else:
			value_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))  # Gray - no points

		value_label.add_theme_font_size_override("font_size", 14)
		skill_line.add_child(value_label)

		skills_content.add_child(skill_line)

## Add the combat section
func _add_combat_section() -> void:
	var section_header = _create_section_header("== COMBAT ==")
	combat_content.add_child(section_header)

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
	survival_content.add_child(section_header)

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
	weather_content.add_child(section_header)

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
	progression_content.add_child(section_header)

	# Character Name
	var char_name = GameManager.character_name if GameManager.character_name != "" else "Unknown"
	_add_stat_line("Name", char_name, Color(0.9, 0.9, 0.6))

	# Level
	_add_stat_line("Level", "%d" % player.level, Color(1.0, 0.85, 0.3))

	# Experience
	_add_stat_line("Experience", "%d / %d" % [player.experience, player.experience_to_next_level],
		Color(0.7, 0.85, 0.95))

	# Prominent level-up notice if points are available
	if player.available_skill_points > 0 or player.available_ability_points > 0:
		_add_spacer()

		# Add a prominent notice panel
		var notice_panel = PanelContainer.new()
		var notice_style = StyleBoxFlat.new()
		notice_style.bg_color = Color(0.2, 0.15, 0.3, 0.9)  # Dark purple background
		notice_style.border_width_left = 2
		notice_style.border_width_top = 2
		notice_style.border_width_right = 2
		notice_style.border_width_bottom = 2
		notice_style.border_color = Color(0.95, 0.7, 0.95, 1)  # Bright magenta border
		notice_style.corner_radius_top_left = 4
		notice_style.corner_radius_top_right = 4
		notice_style.corner_radius_bottom_left = 4
		notice_style.corner_radius_bottom_right = 4
		notice_panel.add_theme_stylebox_override("panel", notice_style)

		var notice_margin = MarginContainer.new()
		notice_margin.add_theme_constant_override("margin_left", 12)
		notice_margin.add_theme_constant_override("margin_top", 12)
		notice_margin.add_theme_constant_override("margin_right", 12)
		notice_margin.add_theme_constant_override("margin_bottom", 12)
		notice_panel.add_child(notice_margin)

		var notice_vbox = VBoxContainer.new()
		notice_vbox.add_theme_constant_override("separation", 8)
		notice_margin.add_child(notice_vbox)

		# Title label
		var title_label = Label.new()
		title_label.text = "⬆ LEVEL UP AVAILABLE ⬆"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		title_label.add_theme_font_size_override("font_size", 18)
		notice_vbox.add_child(title_label)

		# Points summary
		var summary_label = Label.new()
		var summary_parts = []
		if player.available_skill_points > 0:
			summary_parts.append("%d Skill Point%s" % [player.available_skill_points, "s" if player.available_skill_points > 1 else ""])
		if player.available_ability_points > 0:
			summary_parts.append("%d Ability Point%s" % [player.available_ability_points, "s" if player.available_ability_points > 1 else ""])
		summary_label.text = " + ".join(summary_parts) + " to spend"
		summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		summary_label.add_theme_font_size_override("font_size", 14)
		notice_vbox.add_child(summary_label)

		# Button to open level-up screen
		var level_up_button = Button.new()
		level_up_button.text = "Allocate Points [L]"
		level_up_button.custom_minimum_size = Vector2(200, 40)
		level_up_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		level_up_button.add_theme_font_size_override("font_size", 14)
		level_up_button.pressed.connect(_on_level_up_button_pressed)
		notice_vbox.add_child(level_up_button)

		progression_content.add_child(notice_panel)
		_add_spacer()
	else:
		# Skill Points Available
		_add_stat_line("Skill Points", "0", Color(0.7, 0.7, 0.7))

		# Ability Points Available
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

	current_content_box.add_child(line)

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
	current_content_box.add_child(spacer)

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

## Handle level-up button press
func _on_level_up_button_pressed() -> void:
	# Navigate up to find the game node and open level_up_screen
	var game = get_node("/root/Game")
	if game and game.level_up_screen and player:
		hide()  # Hide character sheet while level-up screen is open
		game.level_up_screen.open(player)
		game.input_handler.ui_blocking_input = true

## Called when tab changes
func _on_tab_changed(tab_index: int) -> void:
	# Update current scroll container based on active tab
	match tab_index:
		0:  # Progression tab
			current_scroll_container = progression_scroll
		1:  # Abilities tab
			current_scroll_container = abilities_scroll
		2:  # Skills tab
			current_scroll_container = skills_scroll
		3:  # Combat tab
			current_scroll_container = combat_scroll
		4:  # Survival tab
			current_scroll_container = survival_scroll
		5:  # Weather tab
			current_scroll_container = weather_scroll
		_:
			current_scroll_container = progression_scroll

## Handle input
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var scroll_amount = 40  # Pixels to scroll per key press

		match event.keycode:
			KEY_L:
				# L key - open level-up screen if points available
				if player and (player.available_skill_points > 0 or player.available_ability_points > 0):
					_on_level_up_button_pressed()
				get_viewport().set_input_as_handled()

			KEY_TAB:
				# Cycle through tabs
				if tab_container:
					var current_tab = tab_container.current_tab
					var tab_count = tab_container.get_tab_count()
					if event.shift_pressed:
						# Shift+Tab: Previous tab
						current_tab = (current_tab - 1 + tab_count) % tab_count
					else:
						# Tab: Next tab
						current_tab = (current_tab + 1) % tab_count
					tab_container.current_tab = current_tab
				get_viewport().set_input_as_handled()

			KEY_UP, KEY_W:
				if current_scroll_container:
					current_scroll_container.scroll_vertical -= scroll_amount
				get_viewport().set_input_as_handled()

			KEY_DOWN, KEY_S:
				if current_scroll_container:
					current_scroll_container.scroll_vertical += scroll_amount
				get_viewport().set_input_as_handled()

			KEY_PAGEUP:
				if current_scroll_container:
					current_scroll_container.scroll_vertical -= scroll_amount * 5
				get_viewport().set_input_as_handled()

			KEY_PAGEDOWN:
				if current_scroll_container:
					current_scroll_container.scroll_vertical += scroll_amount * 5
				get_viewport().set_input_as_handled()

			KEY_HOME:
				if current_scroll_container:
					current_scroll_container.scroll_vertical = 0
				get_viewport().set_input_as_handled()

			KEY_END:
				if current_scroll_container:
					current_scroll_container.scroll_vertical = int(current_scroll_container.get_v_scroll_bar().max_value)
				get_viewport().set_input_as_handled()

			KEY_ESCAPE, KEY_P:
				close()

		# Always consume keyboard input while character sheet is open
		get_viewport().set_input_as_handled()

