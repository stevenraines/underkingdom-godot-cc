extends Control

## Help Screen - Contextual help and keybindings
##
## Displays comprehensive help information organized by category.

signal closed

@onready var scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var content_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/ContentBox

# Colors matching inventory screen
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_KEY = Color(0.7, 0.9, 0.7)
const COLOR_DESC = Color(0.85, 0.85, 0.7)
const COLOR_TIP = Color(0.8, 0.8, 0.7)

func _ready() -> void:
	_build_help_content()
	hide()
	set_process_unhandled_input(false)

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
	_add_section_header("== MOVEMENT & ACTIONS ==")
	_add_keybind("Arrow Keys / WASD", "Move & attack enemies")
	_add_keybind(". (period)", "Wait one turn (bonus stamina)")
	_add_keybind("Shift + R", "Rest menu (rest multiple turns)")
	_add_keybind("> (Shift + .)", "Descend stairs")
	_add_keybind("< (Shift + ,)", "Ascend stairs")
	_add_keybind(", (comma)", "Manually pick up item")
	_add_keybind("X", "Open/close adjacent door")
	_add_keybind("Y", "Pick lock / re-lock door or chest")
	_add_keybind("O", "Toggle auto-open doors")
	_add_help_text("Walk into closed doors to open them (if auto-open is ON)")
	_add_help_text("Locked doors auto-try keys if you bump them")
	_add_spacer()

	# Traps & Hazards
	_add_section_header("== TRAPS & HAZARDS ==")
	_add_keybind("N", "Search for traps (range: 2 + traps skill)")
	_add_keybind("Shift + N", "Disarm visible trap")
	_add_help_text("Active search gives +5 bonus vs passive detection")
	_add_help_text("Detection uses WIS + traps skill vs trap difficulty")
	_add_help_text("Disarming uses DEX + traps skill")
	_add_help_text("Failed disarm may trigger the trap!")
	_add_spacer()

	# Inventory & Equipment
	_add_section_header("== INVENTORY & EQUIPMENT ==")
	_add_keybind("I", "Open inventory")
	_add_keybind("Tab (in inventory)", "Switch equipment/backpack")
	_add_keybind("E (in inventory)", "Equip/Unequip item")
	_add_keybind("U (in inventory)", "Use consumable")
	_add_keybind("D (in inventory)", "Drop item")
	_add_keybind("{ (in inventory)", "Inscribe text on item")
	_add_keybind("} (in inventory)", "Remove inscription from item")
	_add_keybind("1-0 (in inventory)", "Filter items by category")
	_add_keybind("G", "Toggle auto-pickup on/off")
	_add_keybind("Q", "Light/extinguish equipped torch")
	_add_help_text("Inscriptions appear in {curly braces} after item name")
	_add_help_text("Filters: 1=All 2=Weapons 3=Armor 4=Tools 5=Consumables")
	_add_help_text("         6=Materials 7=Ammo 8=Books 9=Seeds 0=Misc")
	_add_spacer()

	# Crafting & Building
	_add_section_header("== CRAFTING & BUILDING ==")
	_add_keybind("C", "Open crafting menu")
	_add_keybind("H", "Harvest resource (then direction)")
	_add_keybind("F", "Fish (when near water) / interact with feature")
	_add_keybind("B", "Open build mode")
	_add_keybind("E", "Interact with structure")
	_add_help_text("Fishing requires a rod (with bait) or net")
	_add_help_text("Must be adjacent to 8+ contiguous water tiles")
	_add_spacer()

	# Farming
	_add_section_header("== FARMING ==")
	_add_keybind("Shift + T", "Till soil (requires hoe)")
	_add_keybind("Shift + P", "Plant seeds (then direction)")
	_add_keybind("H", "Harvest mature crops")
	_add_help_text("Till grass/dirt to create farmland")
	_add_help_text("Plant seeds on tilled soil")
	_add_help_text("Crops grow over time and can be harvested when mature")
	_add_spacer()

	# NPCs & Shopping
	_add_section_header("== NPCs & SHOPPING ==")
	_add_keybind("T", "Talk to adjacent NPC")
	_add_keybind("Tab (in shop)", "Switch buy/sell mode")
	_add_keybind("1-0 (in shop)", "Filter items by category")
	_add_keybind("+/-", "Adjust quantity")
	_add_keybind("Enter", "Complete transaction")
	_add_help_text("Filters work independently for shop and player inventory")
	_add_spacer()

	# Menus & UI
	_add_section_header("== MENUS & UI ==")
	_add_keybind("P", "Character sheet")
	_add_keybind("M", "World map")
	_add_keybind("Shift+M / K", "Spellbook (view & cast spells)")
	_add_keybind("Z", "Fast travel to visited locations")
	_add_keybind("? or F1", "This help screen")
	_add_keybind("F12", "Debug commands (dev mode)")
	_add_keybind("ESC", "Pause menu / close UI")
	_add_keybind("1-3 (in menus)", "Quick-select save slots")
	_add_spacer()

	# Survival Tips
	_add_section_header("== SURVIVAL TIPS ==")
	_add_help_text("Hunger and thirst drain over time")
	_add_help_text("Temperature affects your stats")
	_add_help_text("Stamina is used for movement and combat")
	_add_help_text("Encumbrance slows you down")
	_add_help_text("Use Shift+R to rest until stamina is full")
	_add_help_text("Resting stops if any event occurs")
	_add_spacer()

	# Combat
	_add_section_header("== COMBAT ==")
	_add_keybind("Arrow/WASD", "Bump attack (melee)")
	_add_keybind("Tab", "Cycle through targets")
	_add_keybind("R", "Fire ranged weapon at target")
	_add_spacer()

	# Look Mode
	_add_section_header("== LOOK MODE ==")
	_add_keybind("L", "Enter look mode")
	_add_keybind("Tab (look mode)", "Cycle visible objects")
	_add_keybind("T (look mode)", "Target looked-at enemy")
	_add_keybind("ESC (look mode)", "Exit look mode")
	_add_spacer()

	# Combat Tips
	_add_section_header("== COMBAT TIPS ==")
	_add_help_text("Bump into enemies to attack them (melee)")
	_add_help_text("Use Tab to select targets, R to fire")
	_add_help_text("Ranged weapons require ammunition")
	_add_help_text("Thrown weapons are consumed but may be recovered")
	_add_help_text("Hit chance = Your Accuracy - Enemy Evasion")
	_add_help_text("Damage = Weapon + STR bonus - Armor")
	_add_help_text("Higher DEX improves accuracy and evasion")

## Add a section header
func _add_section_header(text: String) -> void:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_SECTION)
	header.add_theme_font_size_override("font_size", 15)
	content_container.add_child(header)

## Add a keybind line
func _add_keybind(key: String, description: String) -> void:
	var line = HBoxContainer.new()

	var key_label = Label.new()
	key_label.text = "[%s]" % key
	key_label.custom_minimum_size.x = 180
	key_label.add_theme_color_override("font_color", COLOR_KEY)
	key_label.add_theme_font_size_override("font_size", 14)
	line.add_child(key_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	desc_label.add_theme_font_size_override("font_size", 14)
	line.add_child(desc_label)

	content_container.add_child(line)

## Add help text (for tips, not keybinds)
func _add_help_text(text: String) -> void:
	var label = Label.new()
	label.text = "  • " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

		# Always consume keyboard input while help screen is open
		get_viewport().set_input_as_handled()
