extends Control

## Help Screen - Contextual help and keybindings
##
## Displays comprehensive help information organized by category.

signal closed

# UI elements - created programmatically
var panel: Panel
var content_container: VBoxContainer
var scroll_container: ScrollContainer

# Colors matching inventory screen
const COLOR_TITLE = Color(0.6, 0.9, 0.6, 1)
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_KEY = Color(0.7, 0.9, 0.7)
const COLOR_DESC = Color(0.85, 0.85, 0.7)
const COLOR_TIP = Color(0.8, 0.8, 0.7)
const COLOR_FOOTER = Color(0.7, 0.7, 0.7)
const COLOR_BORDER = Color(0.4, 0.6, 0.4, 1)

func _ready() -> void:
	_build_ui()
	_build_help_content()
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
	panel.offset_left = -340
	panel.offset_top = -280
	panel.offset_right = 340
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
	title.text = "◆ HELP & KEYBINDINGS ◆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if theme != null:
		title.theme = theme
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
	footer.text = "↑↓ Scroll  |  [?] [F1] [ESC] Close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if theme != null:
		footer.theme = theme
	footer.add_theme_color_override("font_color", COLOR_FOOTER)
	footer.add_theme_font_size_override("font_size", 13)
	vbox.add_child(footer)

## Open the help screen
func open() -> void:
	show()
	set_process_unhandled_input(true)

## Close the help screen
func close() -> void:
	hide()
	set_process_unhandled_input(false)
	closed.emit()

## Build all help content
func _build_help_content() -> void:
	# Movement & Actions
	_add_section_header("══ MOVEMENT & ACTIONS ══")
	_add_keybind("Arrow Keys / WASD", "Move & attack enemies")
	_add_keybind(". (period)", "Wait / rest (bonus stamina)")
	_add_keybind("> (Shift + .)", "Descend stairs")
	_add_keybind("< (Shift + ,)", "Ascend stairs")
	_add_keybind(", (comma)", "Manually pick up item")
	_add_spacer()

	# Inventory & Equipment
	_add_section_header("══ INVENTORY & EQUIPMENT ══")
	_add_keybind("I", "Open inventory")
	_add_keybind("Tab (in inventory)", "Switch equipment/backpack")
	_add_keybind("E (in inventory)", "Equip/Unequip item")
	_add_keybind("U (in inventory)", "Use consumable")
	_add_keybind("D (in inventory)", "Drop item")
	_add_keybind("G", "Toggle auto-pickup on/off")
	_add_spacer()

	# Crafting & Building
	_add_section_header("══ CRAFTING & BUILDING ══")
	_add_keybind("C", "Open crafting menu")
	_add_keybind("H", "Harvest resource (then direction)")
	_add_keybind("B", "Open build mode")
	_add_keybind("E", "Interact with structure")
	_add_spacer()

	# NPCs & Shopping
	_add_section_header("══ NPCs & SHOPPING ══")
	_add_keybind("T", "Talk to adjacent NPC")
	_add_keybind("Tab (in shop)", "Switch buy/sell mode")
	_add_keybind("+/-", "Adjust quantity")
	_add_keybind("Enter", "Complete transaction")
	_add_spacer()

	# Menus & UI
	_add_section_header("══ MENUS & UI ══")
	_add_keybind("P", "Character sheet")
	_add_keybind("? or F1", "This help screen")
	_add_keybind("ESC", "Pause menu / close UI")
	_add_keybind("1-3 (in menus)", "Quick-select save slots")
	_add_spacer()

	# Survival Tips
	_add_section_header("══ SURVIVAL TIPS ══")
	_add_help_text("Hunger and thirst drain over time")
	_add_help_text("Temperature affects your stats")
	_add_help_text("Stamina is used for movement and combat")
	_add_help_text("Encumbrance slows you down")
	_add_spacer()

	# Combat Tips
	_add_section_header("══ COMBAT TIPS ══")
	_add_help_text("Bump into enemies to attack them")
	_add_help_text("Hit chance = Your Accuracy - Enemy Evasion")
	_add_help_text("Damage = Weapon + STR bonus - Armor")
	_add_help_text("Higher DEX improves accuracy and evasion")

## Add a section header
func _add_section_header(text: String) -> void:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if theme != null:
		header.theme = theme
	header.add_theme_color_override("font_color", COLOR_SECTION)
	header.add_theme_font_size_override("font_size", 15)
	content_container.add_child(header)

## Add a keybind line
func _add_keybind(key: String, description: String) -> void:
	var line = HBoxContainer.new()

	var key_label = Label.new()
	key_label.text = "[%s]" % key
	key_label.custom_minimum_size.x = 180
	if theme != null:
		key_label.theme = theme
	key_label.add_theme_color_override("font_color", COLOR_KEY)
	key_label.add_theme_font_size_override("font_size", 14)
	line.add_child(key_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if theme != null:
		desc_label.theme = theme
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	desc_label.add_theme_font_size_override("font_size", 14)
	line.add_child(desc_label)

	content_container.add_child(line)

## Add help text (for tips, not keybinds)
func _add_help_text(text: String) -> void:
	var label = Label.new()
	label.text = "  • " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if theme != null:
		label.theme = theme
	label.add_theme_color_override("font_color", COLOR_TIP)
	label.add_theme_font_size_override("font_size", 14)
	content_container.add_child(label)

## Add a spacer
func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	content_container.add_child(spacer)

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
		elif not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_F1 or (event.keycode == KEY_SLASH and event.shift_pressed)):
			close()
			get_viewport().set_input_as_handled()
