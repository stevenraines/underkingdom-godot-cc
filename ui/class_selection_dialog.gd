extends Control

## ClassSelectionDialog - Dialog for selecting player class during character creation
##
## Displays available classes with stat modifiers, skill bonuses, and feats.
## Emits signal when class is selected.

signal class_selected(class_id: String)
signal cancelled()

@onready var class_list: VBoxContainer = $Panel/MarginContainer/MainVBox/ContentHBox/ClassPanel/ClassList
@onready var description_label: RichTextLabel = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/DescriptionLabel
@onready var stats_label: RichTextLabel = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/StatsLabel
@onready var skills_label: RichTextLabel = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/SkillsLabel
@onready var feats_label: RichTextLabel = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/FeatsLabel
@onready var restrictions_label: RichTextLabel = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/RestrictionsLabel
@onready var confirm_button: Button = $Panel/MarginContainer/MainVBox/ButtonsContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/MarginContainer/MainVBox/ButtonsContainer/CancelButton

var selected_class_index: int = 0
var class_buttons: Array[Button] = []
var class_ids: Array[String] = []

var selected_button_index: int = 0
var action_buttons: Array[Button] = []
var in_button_mode: bool = false

const DEFAULT_CLASS := ClassManager.DEFAULT_CLASS


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
					# Go back to class list
					in_button_mode = false
					_update_button_colors()
					_update_class_selection()
					viewport.set_input_as_handled()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					action_buttons[selected_button_index].emit_signal("pressed")
					viewport.set_input_as_handled()
				KEY_ESCAPE:
					_on_cancel_pressed()
					viewport.set_input_as_handled()
		else:
			# Class list navigation mode
			match event.keycode:
				KEY_UP:
					_navigate_classes(-1)
					viewport.set_input_as_handled()
				KEY_DOWN:
					_navigate_classes(1)
					viewport.set_input_as_handled()
				KEY_TAB:
					# Tab moves to buttons
					in_button_mode = true
					selected_button_index = 0
					_update_button_colors()
					_update_class_selection()
					viewport.set_input_as_handled()
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_on_confirm_pressed()
					viewport.set_input_as_handled()
				KEY_ESCAPE:
					_on_cancel_pressed()
					viewport.set_input_as_handled()


func open() -> void:
	_populate_class_list()
	selected_class_index = 0
	in_button_mode = false
	selected_button_index = 0
	_update_class_selection()
	_update_button_colors()
	show()


func _populate_class_list() -> void:
	# Clear existing buttons
	for child in class_list.get_children():
		child.queue_free()
	class_buttons.clear()
	class_ids.clear()

	# Get all classes sorted by name, but put Adventurer (default) first
	var classes = ClassManager.get_all_classes_sorted()
	var sorted_classes: Array[Dictionary] = []
	var default_class_data: Dictionary = {}

	for cls in classes:
		if cls.get("id", "") == DEFAULT_CLASS:
			default_class_data = cls
		else:
			sorted_classes.append(cls)

	# Insert default class at front
	if not default_class_data.is_empty():
		sorted_classes.insert(0, default_class_data)

	for cls in sorted_classes:
		var class_id = cls.get("id", "")
		class_ids.append(class_id)

		var button = Button.new()
		button.text = cls.get("name", class_id.capitalize())
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(150, 30)

		# Connect mouse hover
		var idx = class_buttons.size()
		button.mouse_entered.connect(_on_class_hover.bind(idx))
		button.pressed.connect(_on_class_clicked.bind(idx))

		class_list.add_child(button)
		class_buttons.append(button)


func _navigate_classes(direction: int) -> void:
	if class_buttons.is_empty():
		return

	selected_class_index += direction
	if selected_class_index < 0:
		selected_class_index = class_buttons.size() - 1
	elif selected_class_index >= class_buttons.size():
		selected_class_index = 0

	_update_class_selection()


func _update_class_selection() -> void:
	# Update class button colors and text
	for i in range(class_buttons.size()):
		var base_text = class_buttons[i].text.trim_prefix("► ")
		if i == selected_class_index and not in_button_mode:
			class_buttons[i].modulate = UITheme.COLOR_SELECTED_GOLD
			class_buttons[i].text = "► " + base_text
		else:
			class_buttons[i].modulate = UITheme.COLOR_NORMAL
			class_buttons[i].text = base_text

	# Update info panel
	if selected_class_index >= 0 and selected_class_index < class_ids.size():
		var class_id = class_ids[selected_class_index]
		_update_info_panel(class_id)


func _update_info_panel(class_id: String) -> void:
	var cls = ClassManager.get_class_def(class_id)

	# Description
	description_label.text = cls.get("description", "")

	# Stat Modifiers
	stats_label.text = "[b]Stat Modifiers:[/b] " + ClassManager.format_stat_modifiers(class_id)

	# Skill Bonuses
	skills_label.text = "[b]Skill Bonuses:[/b] " + ClassManager.format_skill_bonuses(class_id)

	# Feats
	var feats = ClassManager.get_feats(class_id)
	if feats.is_empty():
		feats_label.text = "[b]Feats:[/b] None"
	else:
		var feat_text = "[b]Feats:[/b]\n"
		for feat in feats:
			var feat_type = feat.get("type", "passive")
			# ◇ for passive, ◆ for active
			var symbol = "◆" if feat_type == "active" else "◇"
			var type_color = "[color=yellow]" if feat_type == "active" else "[color=gray]"
			var uses_text = ""
			if feat_type == "active":
				var uses = feat.get("uses_per_day", 1)
				uses_text = " [%d/day]" % uses
			feat_text += "  %s%s %s%s[/color]: %s\n" % [
				type_color,
				symbol,
				feat.get("name", "Unknown"),
				uses_text,
				feat.get("description", "")
			]
		feats_label.text = feat_text.strip_edges()

	# Restrictions
	var restrictions_text = ClassManager.format_restrictions(class_id)
	if restrictions_text == "No restrictions":
		restrictions_label.text = "[b]Restrictions:[/b] [color=green]None - free to use any equipment and cast spells[/color]"
	else:
		restrictions_label.text = "[b]Restrictions:[/b] [color=orange]%s[/color]" % restrictions_text


func _update_button_colors() -> void:
	for i in range(action_buttons.size()):
		if in_button_mode and i == selected_button_index:
			action_buttons[i].modulate = UITheme.COLOR_SELECTED_GOLD
		else:
			action_buttons[i].modulate = UITheme.COLOR_NORMAL


func _on_class_hover(idx: int) -> void:
	if not in_button_mode:
		selected_class_index = idx
		_update_class_selection()


func _on_class_clicked(idx: int) -> void:
	selected_class_index = idx
	_update_class_selection()
	_on_confirm_pressed()


func _on_confirm_pressed() -> void:
	if selected_class_index >= 0 and selected_class_index < class_ids.size():
		var class_id = class_ids[selected_class_index]
		class_selected.emit(class_id)
		hide()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()
