extends Control

## RaceSelectionDialog - Dialog for selecting player race during character creation
##
## Displays available races with stat modifiers and traits.
## Emits signal when race is selected.

signal race_selected(race_id: String)
signal cancelled()

@onready var race_list: VBoxContainer = $Panel/MarginContainer/MainVBox/ContentHBox/RacePanel/RaceList
@onready var description_label: RichTextLabel = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/DescriptionLabel
@onready var stats_label: RichTextLabel = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/StatsLabel
@onready var traits_label: RichTextLabel = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/TraitsLabel
@onready var confirm_button: Button = $Panel/MarginContainer/MainVBox/ButtonsContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/MarginContainer/MainVBox/ButtonsContainer/CancelButton

var selected_race_index: int = 0
var race_buttons: Array[Button] = []
var race_ids: Array[String] = []

var selected_button_index: int = 0
var action_buttons: Array[Button] = []
var in_button_mode: bool = false

const DEFAULT_RACE := RaceManager.DEFAULT_RACE


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Setup action buttons
	action_buttons = [confirm_button, cancel_button]
	for b in action_buttons:
		b.focus_mode = Control.FOCUS_NONE


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		if in_button_mode:
			# Button navigation mode
			match event.keycode:
				KEY_LEFT:
					selected_button_index = 0
					_update_button_colors()
					viewport.set_input_as_handled()
				KEY_RIGHT:
					selected_button_index = 1
					_update_button_colors()
					viewport.set_input_as_handled()
				KEY_UP:
					# Go back to race list
					in_button_mode = false
					_update_button_colors()
					_update_race_selection()
					viewport.set_input_as_handled()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					action_buttons[selected_button_index].emit_signal("pressed")
					viewport.set_input_as_handled()
				KEY_ESCAPE:
					_on_cancel_pressed()
					viewport.set_input_as_handled()
		else:
			# Race list navigation mode
			match event.keycode:
				KEY_UP:
					_navigate_races(-1)
					viewport.set_input_as_handled()
				KEY_DOWN:
					_navigate_races(1)
					viewport.set_input_as_handled()
				KEY_TAB:
					# Tab moves to buttons
					in_button_mode = true
					selected_button_index = 0
					_update_button_colors()
					_update_race_selection()
					viewport.set_input_as_handled()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_on_confirm_pressed()
					viewport.set_input_as_handled()
				KEY_ESCAPE:
					_on_cancel_pressed()
					viewport.set_input_as_handled()


func open() -> void:
	_populate_race_list()
	selected_race_index = 0
	in_button_mode = false
	selected_button_index = 0
	_update_race_selection()
	_update_button_colors()
	show()


func _populate_race_list() -> void:
	# Clear existing buttons
	for child in race_list.get_children():
		child.queue_free()
	race_buttons.clear()
	race_ids.clear()

	# Get all races sorted by name, but put Human (default) first
	var races = RaceManager.get_all_races_sorted()
	var sorted_races: Array[Dictionary] = []
	var default_race_data: Dictionary = {}

	for race in races:
		if race.get("id", "") == DEFAULT_RACE:
			default_race_data = race
		else:
			sorted_races.append(race)

	# Insert default race at front
	if not default_race_data.is_empty():
		sorted_races.insert(0, default_race_data)

	for race in sorted_races:
		var race_id = race.get("id", "")
		race_ids.append(race_id)

		var button = Button.new()
		button.text = race.get("name", race_id.capitalize())
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(150, 30)

		# Connect mouse hover
		var idx = race_buttons.size()
		button.mouse_entered.connect(_on_race_hover.bind(idx))
		button.pressed.connect(_on_race_clicked.bind(idx))

		race_list.add_child(button)
		race_buttons.append(button)


func _navigate_races(direction: int) -> void:
	if race_buttons.is_empty():
		return

	selected_race_index += direction
	if selected_race_index < 0:
		selected_race_index = race_buttons.size() - 1
	elif selected_race_index >= race_buttons.size():
		selected_race_index = 0

	_update_race_selection()


func _update_race_selection() -> void:
	# Update race button colors and text
	for i in range(race_buttons.size()):
		var base_text = race_buttons[i].text.trim_prefix("► ")
		if i == selected_race_index and not in_button_mode:
			race_buttons[i].modulate = UITheme.COLOR_SELECTED_GOLD
			race_buttons[i].text = "► " + base_text
		else:
			race_buttons[i].modulate = UITheme.COLOR_NORMAL
			race_buttons[i].text = base_text

	# Update info panel
	if selected_race_index >= 0 and selected_race_index < race_ids.size():
		var race_id = race_ids[selected_race_index]
		_update_info_panel(race_id)


func _update_info_panel(race_id: String) -> void:
	var race = RaceManager.get_race(race_id)

	# Description
	description_label.text = race.get("description", "")

	# Stats
	var stat_text = "[b]Stat Modifiers:[/b] " + RaceManager.format_stat_modifiers(race_id)
	var bonus_points = RaceManager.get_bonus_stat_points(race_id)
	if bonus_points > 0:
		stat_text += "\n[b]Bonus Points:[/b] +%d to distribute" % bonus_points
	stats_label.text = stat_text

	# Traits
	var all_traits = RaceManager.get_traits(race_id)
	if all_traits.is_empty():
		traits_label.text = "[b]Traits:[/b] None"
	else:
		var trait_text = "[b]Traits:[/b]\n"
		for trait_data in all_traits:
			var trait_type = trait_data.get("type", "passive")
			var type_color = "[color=cyan]" if trait_type == "active" else "[color=gray]"
			trait_text += "  %s%s[/color]: %s\n" % [type_color, trait_data.get("name", "Unknown"), trait_data.get("description", "")]
		traits_label.text = trait_text.strip_edges()


func _update_button_colors() -> void:
	for i in range(action_buttons.size()):
		if in_button_mode and i == selected_button_index:
			action_buttons[i].modulate = UITheme.COLOR_SELECTED_GOLD
		else:
			action_buttons[i].modulate = UITheme.COLOR_NORMAL


func _on_race_hover(idx: int) -> void:
	if not in_button_mode:
		selected_race_index = idx
		_update_race_selection()


func _on_race_clicked(idx: int) -> void:
	selected_race_index = idx
	_update_race_selection()
	_on_confirm_pressed()


func _on_confirm_pressed() -> void:
	if selected_race_index >= 0 and selected_race_index < race_ids.size():
		var race_id = race_ids[selected_race_index]
		race_selected.emit(race_id)
		hide()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()
