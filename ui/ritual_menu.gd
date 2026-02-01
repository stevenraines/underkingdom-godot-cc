extends Control

## RitualMenu - UI for viewing and beginning rituals
##
## Shows all rituals the player has learned, their components and requirements,
## and allows beginning a ritual if requirements are met.

signal closed()
signal ritual_started(ritual_id: String)

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var info_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderPanel/InfoLabel
@onready var ritual_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/RitualListPanel/ScrollContainer/RitualList
@onready var ritual_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/RitualListPanel/ScrollContainer
@onready var ritual_list_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/RitualListPanel/RitualListTitle

# Detail panel elements
@onready var ritual_name_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/NameColumn/RitualName
@onready var ritual_desc_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/NameColumn/RitualDesc
@onready var stat_line_1: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine1
@onready var stat_line_2: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine2
@onready var stat_line_3: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine3
@onready var req_line_1: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/ReqColumn/ReqLine1
@onready var req_line_2: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/ReqColumn/ReqLine2
@onready var req_line_3: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/ReqColumn/ReqLine3
@onready var footer_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/FooterRow/FooterLabel

const RitualSystemClass = preload("res://systems/ritual_system.gd")

var player: Player = null
var rituals: Array = []
var selected_index: int = 0

# School abbreviations
const SCHOOL_ABBREVS = {
	"evocation": "Evo",
	"conjuration": "Con",
	"enchantment": "Ench",
	"transmutation": "Trans",
	"divination": "Div",
	"necromancy": "Nec",
	"abjuration": "Abj",
	"illusion": "Ill"
}

# School colors for visual distinction
const SCHOOL_COLORS = {
	"evocation": Color(1.0, 0.5, 0.3),
	"conjuration": Color(0.7, 0.3, 1.0),
	"enchantment": Color(1.0, 0.8, 0.3),
	"transmutation": Color(0.3, 0.8, 0.3),
	"divination": Color(0.3, 0.8, 1.0),
	"necromancy": Color(0.6, 0.6, 0.6),
	"abjuration": Color(0.3, 0.6, 1.0),
	"illusion": Color(0.9, 0.5, 0.9)
}

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Escape always closes
		if event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
			return

		# Shift+K toggles ritual menu (same key combo that opens it)
		if event.keycode == KEY_K and event.shift_pressed:
			_close()
			get_viewport().set_input_as_handled()
			return

		match event.keycode:
			KEY_UP:
				_navigate(-1)
			KEY_DOWN:
				_navigate(1)
			KEY_ENTER, KEY_SPACE, KEY_B:
				_begin_selected_ritual()

		# Always consume keyboard input while ritual menu is open
		get_viewport().set_input_as_handled()

func open(p: Player) -> void:
	player = p
	selected_index = 0

	# Get known rituals
	rituals = _get_known_rituals()

	refresh()
	show()

func _close() -> void:
	hide()
	closed.emit()

func refresh() -> void:
	if not player:
		return

	_update_info_display()
	_update_ritual_list()
	_update_selection()

func _get_known_rituals() -> Array:
	if not player:
		return []

	var known: Array = []
	for ritual_id in player.get_known_rituals():
		var ritual = RitualManager.get_ritual(ritual_id)
		if ritual:
			known.append(ritual)
	return known

func _update_info_display() -> void:
	if info_label:
		var known_count = rituals.size()
		info_label.text = "Known Rituals: %d" % known_count
		info_label.add_theme_color_override("font_color", UITheme.COLOR_RITUAL)

func _update_ritual_list() -> void:
	if not ritual_list:
		return

	# Clear existing
	for child in ritual_list.get_children():
		ritual_list.remove_child(child)
		child.free()

	# Update title with ritual count
	if ritual_list_title:
		ritual_list_title.text = "== KNOWN RITUALS (%d) ==" % rituals.size()

	# Reset scroll position to top
	if ritual_scroll:
		ritual_scroll.scroll_vertical = 0

	if rituals.is_empty():
		var label = Label.new()
		label.text = "  (No rituals learned)"
		label.add_theme_color_override("font_color", UITheme.COLOR_EMPTY)
		label.add_theme_font_size_override("font_size", 13)
		ritual_list.add_child(label)
	else:
		for ritual in rituals:
			var container = _create_ritual_row(ritual)
			ritual_list.add_child(container)

func _create_ritual_row(ritual) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	container.set_meta("ritual", ritual)

	# Icon
	var icon = Label.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(20, 0)
	icon.add_theme_font_size_override("font_size", 14)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.text = "*"
	icon.add_theme_color_override("font_color", ritual.get_school_color())
	container.add_child(icon)

	# Name
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.text = ritual.name
	name_label.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)
	container.add_child(name_label)

	# School abbreviation
	var school_label = Label.new()
	school_label.name = "School"
	school_label.custom_minimum_size = Vector2(40, 0)
	school_label.add_theme_font_size_override("font_size", 12)
	school_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	school_label.text = SCHOOL_ABBREVS.get(ritual.school, ritual.school.substr(0, 3).capitalize())
	var school_color = SCHOOL_COLORS.get(ritual.school, UITheme.COLOR_NORMAL)
	school_label.add_theme_color_override("font_color", school_color)
	container.add_child(school_label)

	# Channeling turns
	var info_label_row = Label.new()
	info_label_row.name = "Info"
	info_label_row.custom_minimum_size = Vector2(70, 0)
	info_label_row.add_theme_font_size_override("font_size", 12)
	info_label_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_label_row.text = "%d turns" % ritual.channeling_turns
	info_label_row.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(info_label_row)

	return container

func _update_selection() -> void:
	# Reset all highlights
	for i in range(ritual_list.get_child_count()):
		var child = ritual_list.get_child(i)
		_set_row_highlight(child, false)

	# Highlight selected if we have rituals
	if rituals.size() > 0 and selected_index >= 0 and selected_index < ritual_list.get_child_count():
		var selected_row = ritual_list.get_child(selected_index)
		if selected_row is HBoxContainer:
			_set_row_highlight(selected_row, true)
			_scroll_to_ritual(selected_row)

	_update_detail_panel()

func _set_row_highlight(row: Control, highlighted: bool) -> void:
	if row is HBoxContainer:
		var name_node = row.get_node_or_null("Name")
		if name_node and name_node is Label:
			if highlighted:
				name_node.text = "> " + name_node.text.trim_prefix("> ")
				name_node.add_theme_color_override("font_color", UITheme.COLOR_HIGHLIGHT)
			else:
				name_node.text = name_node.text.trim_prefix("> ")
				name_node.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)

func _scroll_to_ritual(ritual_row: Control) -> void:
	if not ritual_scroll or not ritual_row or not is_instance_valid(ritual_row):
		return

	_scroll_to_ritual_deferred.call_deferred(ritual_row)

func _scroll_to_ritual_deferred(ritual_row: Control) -> void:
	if not ritual_scroll or not ritual_row or not is_instance_valid(ritual_row):
		return

	var item_top = ritual_row.position.y
	var item_bottom = item_top + ritual_row.size.y

	var scroll_top = ritual_scroll.scroll_vertical
	var scroll_bottom = scroll_top + ritual_scroll.size.y

	if item_top < scroll_top:
		ritual_scroll.scroll_vertical = int(item_top)
	elif item_bottom > scroll_bottom:
		ritual_scroll.scroll_vertical = int(item_bottom - ritual_scroll.size.y)

func _update_detail_panel() -> void:
	if rituals.is_empty() or selected_index < 0 or selected_index >= rituals.size():
		_clear_detail_panel()
		return

	var ritual = rituals[selected_index]
	_populate_ritual_details(ritual)

func _clear_detail_panel() -> void:
	if ritual_name_label:
		ritual_name_label.text = "No ritual selected"
		ritual_name_label.add_theme_color_override("font_color", UITheme.COLOR_EMPTY)
	if ritual_desc_label:
		ritual_desc_label.text = "Learn rituals from ancient tomes"
	if stat_line_1:
		stat_line_1.text = ""
	if stat_line_2:
		stat_line_2.text = ""
	if stat_line_3:
		stat_line_3.text = ""
	if req_line_1:
		req_line_1.text = ""
	if req_line_2:
		req_line_2.text = ""
	if req_line_3:
		req_line_3.text = ""
	if footer_label:
		footer_label.text = "[Enter/B] Begin  [Esc/Shift+K] Close"

func _populate_ritual_details(ritual) -> void:
	# Name and description
	if ritual_name_label:
		ritual_name_label.text = ritual.name
		ritual_name_label.add_theme_color_override("font_color", ritual.get_school_color())

	if ritual_desc_label:
		ritual_desc_label.text = ritual.description

	# Stats column - ritual properties
	var stats: Array[String] = []

	# School
	var school_name = ritual.school.capitalize()
	stats.append("School: %s" % school_name)

	# Channeling time
	stats.append("Channeling: %d turns" % ritual.channeling_turns)

	# Components
	var components_str = ritual.get_component_list()
	if components_str.length() > 35:
		components_str = components_str.substr(0, 32) + "..."
	stats.append("Components: %s" % components_str)

	# Assign stats to lines
	if stat_line_1:
		stat_line_1.text = stats[0] if stats.size() > 0 else ""
		stat_line_1.add_theme_color_override("font_color", SCHOOL_COLORS.get(ritual.school, UITheme.COLOR_NORMAL))
	if stat_line_2:
		stat_line_2.text = stats[1] if stats.size() > 1 else ""
		stat_line_2.add_theme_color_override("font_color", UITheme.COLOR_RITUAL)
	if stat_line_3:
		stat_line_3.text = stats[2] if stats.size() > 2 else ""
		stat_line_3.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Requirements column - check if player meets them
	_update_requirements_display(ritual)

	# Footer
	if footer_label:
		footer_label.text = "[Enter/B] Begin  [Esc/Shift+K] Close"

func _update_requirements_display(ritual) -> void:
	if not player:
		return

	# INT requirement
	var required_int = ritual.get_min_intelligence()
	var player_int = player.get_effective_attribute("INT")
	var int_met = player_int >= required_int

	if req_line_1:
		req_line_1.text = "INT: %d required" % required_int
		req_line_1.add_theme_color_override("font_color", UITheme.COLOR_REQ_MET if int_met else UITheme.COLOR_REQ_NOT_MET)

	# Special requirements (altar, night)
	var special_reqs: Array[String] = []
	if ritual.requires_altar():
		special_reqs.append("Altar")
	if ritual.requires_night():
		special_reqs.append("Night")

	if req_line_2:
		if special_reqs.is_empty():
			req_line_2.text = "No special requirements"
			req_line_2.add_theme_color_override("font_color", UITheme.COLOR_REQ_MET)
		else:
			req_line_2.text = "Requires: %s" % ", ".join(special_reqs)
			req_line_2.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))

	# Can perform status
	if req_line_3:
		var can_perform = RitualSystemClass.can_perform_ritual(player, ritual)
		if can_perform.can_perform:
			req_line_3.text = "Can perform"
			req_line_3.add_theme_color_override("font_color", UITheme.COLOR_REQ_MET)
		else:
			req_line_3.text = can_perform.reason
			req_line_3.add_theme_color_override("font_color", UITheme.COLOR_REQ_NOT_MET)

func _navigate(direction: int) -> void:
	if rituals.is_empty():
		return

	selected_index = clampi(selected_index + direction, 0, rituals.size() - 1)
	_update_selection()


## Attempt to begin the currently selected ritual
func _begin_selected_ritual() -> void:
	if rituals.is_empty() or selected_index < 0 or selected_index >= rituals.size():
		return

	var ritual = rituals[selected_index]

	# Check if player can perform this ritual
	var can_perform = RitualSystemClass.can_perform_ritual(player, ritual)
	if not can_perform.can_perform:
		EventBus.message_logged.emit(can_perform.reason)
		return

	# Close the screen and begin the ritual
	var ritual_id = ritual.id
	_close()

	# Begin the ritual
	if RitualSystemClass.begin_ritual(player, ritual):
		ritual_started.emit(ritual_id)
