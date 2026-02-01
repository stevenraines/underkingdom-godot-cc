extends Control

## SpellListScreen - UI for viewing known spells in the player's spellbook
##
## Shows all spells the player has learned, organized as a list with details.
## Requires a spellbook item in inventory to access.

signal closed()
signal spell_cast_requested(spell_id: String)

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var mana_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderPanel/ManaLabel
@onready var spell_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/SpellListPanel/ScrollContainer/SpellList
@onready var spell_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/SpellListPanel/ScrollContainer
@onready var spell_list_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/SpellListPanel/SpellListTitle

# Detail panel elements
@onready var spell_name_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/NameColumn/SpellName
@onready var spell_desc_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/NameColumn/SpellDesc
@onready var stat_line_1: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine1
@onready var stat_line_2: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine2
@onready var stat_line_3: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine3
@onready var req_line_1: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/ReqColumn/ReqLine1
@onready var req_line_2: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/ReqColumn/ReqLine2
@onready var req_line_3: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/ReqColumn/ReqLine3
@onready var footer_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/FooterRow/FooterLabel

var player: Player = null
var spells: Array = []
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
	"evocation": Color(1.0, 0.5, 0.3),    # Orange-red (fire/energy)
	"conjuration": Color(0.7, 0.3, 1.0),   # Purple (summoning)
	"enchantment": Color(1.0, 0.8, 0.3),   # Gold (mind magic)
	"transmutation": Color(0.3, 0.8, 0.3), # Green (change)
	"divination": Color(0.3, 0.8, 1.0),    # Cyan (knowledge)
	"necromancy": Color(0.6, 0.6, 0.6),    # Gray (death)
	"abjuration": Color(0.3, 0.6, 1.0),    # Blue (protection)
	"illusion": Color(0.9, 0.5, 0.9)       # Pink (deception)
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

		# Shift+M toggles spellbook (same key combo that opens it)
		if event.keycode == KEY_M and event.shift_pressed:
			_close()
			get_viewport().set_input_as_handled()
			return

		match event.keycode:
			KEY_UP:
				_navigate(-1)
			KEY_DOWN:
				_navigate(1)
			KEY_ENTER, KEY_SPACE, KEY_C:
				_cast_selected_spell()

		# Always consume keyboard input while spell list is open
		get_viewport().set_input_as_handled()

func open(p: Player) -> void:
	player = p
	selected_index = 0

	if not player:
		_show_no_spellbook_message()
		show()
		return

	# Check if player's class can cast any magic
	var magic_types = player.get_magic_types()
	if magic_types.is_empty():
		_show_no_magic_ability_message()
		show()
		return

	# Check if player has required focus items
	var has_arcane_focus = player.has_spellbook()
	var has_divine_focus = player.has_holy_symbol()
	var can_cast_arcane = "arcane" in magic_types and has_arcane_focus
	var can_cast_divine = "divine" in magic_types and has_divine_focus

	if not can_cast_arcane and not can_cast_divine:
		_show_missing_focus_message(magic_types, has_arcane_focus, has_divine_focus)
		show()
		return

	# Get known spells
	spells = player.get_known_spells()

	# Update title based on class
	_update_magic_title()

	refresh()
	show()

func _close() -> void:
	hide()
	closed.emit()

func refresh() -> void:
	if not player:
		return

	_update_mana_display()
	_update_spell_list()
	_update_selection()

func _show_no_spellbook_message() -> void:
	# Clear spell list
	for child in spell_list.get_children():
		spell_list.remove_child(child)
		child.free()

	# Add no spellbook message
	var label = Label.new()
	label.text = "You need a spellbook to access your spells"
	label.add_theme_color_override("font_color", UITheme.COLOR_REQ_NOT_MET)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_list.add_child(label)

	# Update header
	if mana_label:
		mana_label.text = "No Spellbook"
		mana_label.add_theme_color_override("font_color", UITheme.COLOR_REQ_NOT_MET)

	if spell_list_title:
		spell_list_title.text = "══ SPELLBOOK ══"

	# Clear details
	_clear_detail_panel()
	spells = []


func _show_no_magic_ability_message() -> void:
	# Clear spell list
	for child in spell_list.get_children():
		spell_list.remove_child(child)
		child.free()

	# Add message for non-caster class
	var label = Label.new()
	label.text = "Your class cannot cast magic"
	label.add_theme_color_override("font_color", UITheme.COLOR_REQ_NOT_MET)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spell_list.add_child(label)

	# Update header
	if mana_label:
		mana_label.text = "No Magic"
		mana_label.add_theme_color_override("font_color", UITheme.COLOR_REQ_NOT_MET)

	if spell_list_title:
		spell_list_title.text = "══ MAGIC ══"

	# Clear details
	_clear_detail_panel()
	spells = []


func _show_missing_focus_message(magic_types: Array, has_arcane: bool, has_divine: bool) -> void:
	# Clear spell list
	for child in spell_list.get_children():
		spell_list.remove_child(child)
		child.free()

	# Build message based on what's missing
	var missing: Array[String] = []
	if "arcane" in magic_types and not has_arcane:
		missing.append("a spellbook (for arcane magic)")
	if "divine" in magic_types and not has_divine:
		missing.append("a Token of Faith (for divine magic)")

	var label = Label.new()
	if missing.size() == 1:
		label.text = "You need %s" % missing[0]
	else:
		label.text = "You need %s" % " and ".join(missing)
	label.add_theme_color_override("font_color", UITheme.COLOR_REQ_NOT_MET)
	label.add_theme_font_size_override("font_size", 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	spell_list.add_child(label)

	# Update header
	if mana_label:
		mana_label.text = "Missing Focus"
		mana_label.add_theme_color_override("font_color", UITheme.COLOR_REQ_NOT_MET)

	if spell_list_title:
		spell_list_title.text = "══ MAGIC ══"

	# Clear details
	_clear_detail_panel()
	spells = []


func _update_magic_title() -> void:
	if not player or not spell_list_title:
		return

	# Get menu title from ClassManager
	var title = ClassManager.get_magic_menu_title(player.class_id)
	if title.is_empty():
		title = "SPELLBOOK"

	spell_list_title.text = "══ %s ══" % title.to_upper()

func _update_mana_display() -> void:
	if not player or not player.survival:
		return

	var current_mana = int(player.survival.mana)
	var max_mana = int(player.survival.get_max_mana())

	if mana_label:
		mana_label.text = "Mana: %d / %d" % [current_mana, max_mana]
		mana_label.add_theme_color_override("font_color", UITheme.COLOR_MANA)

func _update_spell_list() -> void:
	if not spell_list:
		return

	# Clear existing (use free() instead of queue_free() for immediate removal)
	for child in spell_list.get_children():
		spell_list.remove_child(child)
		child.free()

	# Update title with spell count (uses class-specific title)
	_update_magic_title()
	if spell_list_title and spells.size() > 0:
		# Append spell count to the title
		var base_title = spell_list_title.text.replace("══ ", "").replace(" ══", "")
		spell_list_title.text = "══ %s (%d) ══" % [base_title, spells.size()]

	# Reset scroll position to top
	if spell_scroll:
		spell_scroll.scroll_vertical = 0

	if spells.is_empty():
		var label = Label.new()
		label.text = "  (No spells learned)"
		label.add_theme_color_override("font_color", UITheme.COLOR_EMPTY)
		label.add_theme_font_size_override("font_size", 13)
		spell_list.add_child(label)
	else:
		for spell in spells:
			var container = _create_spell_row(spell)
			spell_list.add_child(container)

func _create_spell_row(spell) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	container.set_meta("spell", spell)

	# Icon
	var icon = Label.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(20, 0)
	icon.add_theme_font_size_override("font_size", 14)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.text = spell.ascii_char if spell.ascii_char else "*"
	icon.add_theme_color_override("font_color", spell.get_color())
	container.add_child(icon)

	# Name
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.text = spell.name
	name_label.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)
	container.add_child(name_label)

	# School abbreviation
	var school_label = Label.new()
	school_label.name = "School"
	school_label.custom_minimum_size = Vector2(40, 0)
	school_label.add_theme_font_size_override("font_size", 12)
	school_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	school_label.text = SCHOOL_ABBREVS.get(spell.school, spell.school.substr(0, 3).capitalize())
	var school_color = SCHOOL_COLORS.get(spell.school, UITheme.COLOR_NORMAL)
	school_label.add_theme_color_override("font_color", school_color)
	container.add_child(school_label)

	# Level and mana cost
	var info_label = Label.new()
	info_label.name = "Info"
	info_label.custom_minimum_size = Vector2(70, 0)
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var level_text = "Cantrip" if spell.level == 0 else "Lv%d" % spell.level
	info_label.text = "%s %dMP" % [level_text, spell.mana_cost]
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	container.add_child(info_label)

	return container

func _update_selection() -> void:
	# Reset all highlights
	for i in range(spell_list.get_child_count()):
		var child = spell_list.get_child(i)
		_set_row_highlight(child, false)

	# Highlight selected if we have spells
	if spells.size() > 0 and selected_index >= 0 and selected_index < spell_list.get_child_count():
		var selected_row = spell_list.get_child(selected_index)
		if selected_row is HBoxContainer:
			_set_row_highlight(selected_row, true)
			# Scroll to keep selected spell visible
			_scroll_to_spell(selected_row)

	_update_detail_panel()

func _set_row_highlight(row: Control, highlighted: bool) -> void:
	if row is HBoxContainer:
		var name_node = row.get_node_or_null("Name")
		if name_node and name_node is Label:
			if highlighted:
				name_node.text = "► " + name_node.text.trim_prefix("► ")
				name_node.add_theme_color_override("font_color", UITheme.COLOR_HIGHLIGHT)
			else:
				name_node.text = name_node.text.trim_prefix("► ")
				name_node.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)

func _scroll_to_spell(spell_row: Control) -> void:
	if not spell_scroll or not spell_row or not is_instance_valid(spell_row):
		return

	_scroll_to_spell_deferred.call_deferred(spell_row)

func _scroll_to_spell_deferred(spell_row: Control) -> void:
	if not spell_scroll or not spell_row or not is_instance_valid(spell_row):
		return

	var item_top = spell_row.position.y
	var item_bottom = item_top + spell_row.size.y

	var scroll_top = spell_scroll.scroll_vertical
	var scroll_bottom = scroll_top + spell_scroll.size.y

	if item_top < scroll_top:
		spell_scroll.scroll_vertical = int(item_top)
	elif item_bottom > scroll_bottom:
		spell_scroll.scroll_vertical = int(item_bottom - spell_scroll.size.y)

func _update_detail_panel() -> void:
	if spells.is_empty() or selected_index < 0 or selected_index >= spells.size():
		_clear_detail_panel()
		return

	var spell = spells[selected_index]
	_populate_spell_details(spell)

func _clear_detail_panel() -> void:
	if spell_name_label:
		spell_name_label.text = "No spell selected"
		spell_name_label.add_theme_color_override("font_color", UITheme.COLOR_EMPTY)
	if spell_desc_label:
		spell_desc_label.text = "Learn spells from tomes or scrolls"
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
		footer_label.text = "[Enter/C] Cast  [Esc/Shift+M] Close"

func _populate_spell_details(spell) -> void:
	# Name and description
	if spell_name_label:
		spell_name_label.text = spell.name
		spell_name_label.add_theme_color_override("font_color", spell.get_color())

	if spell_desc_label:
		spell_desc_label.text = spell.description

	# Stats column - spell properties
	var stats: Array[String] = []
	var stat_colors: Array[Color] = []

	# School and level
	var school_name = spell.school.capitalize()
	var level_text = "Cantrip" if spell.level == 0 else "Level %d" % spell.level
	stats.append("%s - %s" % [school_name, level_text])
	stat_colors.append(SCHOOL_COLORS.get(spell.school, UITheme.COLOR_NORMAL))

	# Mana cost
	stats.append("Mana Cost: %d" % spell.mana_cost)
	stat_colors.append(UITheme.COLOR_MANA)

	# Effect info based on spell type
	if spell.is_damage_spell():
		var damage = SpellManager.calculate_spell_damage(spell, player)
		var damage_info = spell.get_damage()
		var damage_type = damage_info.get("type", "magical").capitalize()
		stats.append("Damage: %d %s" % [damage, damage_type])
		stat_colors.append(Color(1.0, 0.5, 0.4))  # Red-orange for damage
	elif spell.is_heal_spell():
		var healing = SpellManager.calculate_spell_healing(spell, player)
		stats.append("Healing: %d HP" % healing)
		stat_colors.append(Color(0.4, 1.0, 0.5))  # Green for healing
	else:
		# Targeting for utility spells
		var targeting_mode = spell.get_targeting_mode()
		var range_val = spell.get_range()
		var target_text = targeting_mode.capitalize()
		if range_val > 0:
			target_text += " (Range: %d)" % range_val
		stats.append("Target: %s" % target_text)
		stat_colors.append(Color(0.7, 0.7, 0.7))

	# Assign stats to lines
	if stat_line_1:
		stat_line_1.text = stats[0] if stats.size() > 0 else ""
		stat_line_1.add_theme_color_override("font_color", stat_colors[0] if stat_colors.size() > 0 else UITheme.COLOR_NORMAL)
	if stat_line_2:
		stat_line_2.text = stats[1] if stats.size() > 1 else ""
		stat_line_2.add_theme_color_override("font_color", stat_colors[1] if stat_colors.size() > 1 else UITheme.COLOR_MANA)
	if stat_line_3:
		stat_line_3.text = stats[2] if stats.size() > 2 else ""
		stat_line_3.add_theme_color_override("font_color", stat_colors[2] if stat_colors.size() > 2 else Color(0.7, 0.7, 0.7))

	# Requirements column - check if player meets them
	_update_requirements_display(spell)

	# Footer
	if footer_label:
		footer_label.text = "[Enter/C] Cast  [Esc/Shift+M] Close"

func _update_requirements_display(spell) -> void:
	if not player:
		return

	# INT requirement
	var required_int = spell.get_min_intelligence()
	var player_int = player.get_effective_attribute("INT")
	var int_met = player_int >= required_int

	if req_line_1:
		req_line_1.text = "INT: %d required" % required_int
		req_line_1.add_theme_color_override("font_color", UITheme.COLOR_REQ_MET if int_met else UITheme.COLOR_REQ_NOT_MET)

	# Level requirement
	var required_level = spell.get_min_level()
	var player_level = player.level if "level" in player else 1
	var level_met = player_level >= required_level

	if req_line_2:
		req_line_2.text = "Level: %d required" % required_level
		req_line_2.add_theme_color_override("font_color", UITheme.COLOR_REQ_MET if level_met else UITheme.COLOR_REQ_NOT_MET)

	# Castable status
	if req_line_3:
		var can_cast_result = SpellManager.can_cast(player, spell)
		if can_cast_result.can_cast:
			req_line_3.text = "Can cast"
			req_line_3.add_theme_color_override("font_color", UITheme.COLOR_REQ_MET)
		else:
			req_line_3.text = can_cast_result.reason
			req_line_3.add_theme_color_override("font_color", UITheme.COLOR_REQ_NOT_MET)

func _navigate(direction: int) -> void:
	if spells.is_empty():
		return

	selected_index = clampi(selected_index + direction, 0, spells.size() - 1)
	_update_selection()


## Attempt to cast the currently selected spell
func _cast_selected_spell() -> void:
	if spells.is_empty() or selected_index < 0 or selected_index >= spells.size():
		return

	var spell = spells[selected_index]

	# Check if player can cast this spell
	var can_cast_result = SpellManager.can_cast(player, spell)
	if not can_cast_result.can_cast:
		EventBus.message_logged.emit(can_cast_result.reason)
		return

	# Close the screen and emit signal to trigger casting
	var spell_id = spell.id
	_close()
	spell_cast_requested.emit(spell_id)
