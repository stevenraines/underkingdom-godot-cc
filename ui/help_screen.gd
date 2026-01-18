extends Control

## Help Screen - Contextual help and keybindings
##
## Displays comprehensive help information organized by tabs.

signal closed

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer

# Tab content containers
@onready var movement_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Movement/ContentBox
@onready var combat_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Combat/ContentBox
@onready var traps_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Traps/ContentBox
@onready var inventory_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Inventory/ContentBox
@onready var crafting_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Crafting/ContentBox
@onready var farming_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Farming/ContentBox
@onready var npcs_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/NPCs/ContentBox
@onready var survival_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Survival/ContentBox
@onready var abilities_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Abilities/ContentBox
@onready var magic_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Magic/ContentBox
@onready var ui_content: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/UI/ContentBox

# Active content container for adding help text
var current_container: VBoxContainer

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

## Build all help content organized by tabs
func _build_help_content() -> void:
	# Movement tab
	current_container = movement_content
	_add_section_header("MOVEMENT & ACTIONS")
	_add_keybind("Arrow Keys / WASD", "Move & attack enemies")
	_add_keybind("Shift + S", "Toggle sprint (move 2x, 4x stamina)")
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

	_add_section_header("LOOK MODE")
	_add_keybind("L", "Enter look mode")
	_add_keybind("Tab (look mode)", "Cycle visible objects")
	_add_keybind("T (look mode)", "Target looked-at enemy")
	_add_keybind("ESC (look mode)", "Exit look mode")

	# Combat tab
	current_container = combat_content
	_add_section_header("COMBAT BASICS")
	_add_keybind("Arrow/WASD", "Bump attack (melee)")
	_add_keybind("Tab", "Cycle through targets")
	_add_keybind("U", "Clear current target")
	_add_keybind("R", "Fire ranged weapon at target")
	_add_spacer()

	_add_section_header("COMBAT TIPS")
	_add_help_text("Bump into enemies to attack them (melee)")
	_add_help_text("Use Tab to select targets, R to fire")
	_add_help_text("Ranged weapons require ammunition")
	_add_help_text("Thrown weapons are consumed but may be recovered")
	_add_help_text("Hit chance = Your Accuracy - Enemy Evasion")
	_add_help_text("Damage = Weapon + STR bonus - Armor")
	_add_help_text("Higher DEX improves accuracy and evasion")

	# Traps tab
	current_container = traps_content
	_add_section_header("TRAPS & HAZARDS")
	_add_keybind("N", "Search for traps (range: 2 + traps skill)")
	_add_keybind("Shift + N", "Disarm visible trap")
	_add_spacer()

	_add_section_header("TRAP MECHANICS")
	_add_help_text("Active search gives +5 bonus vs passive detection")
	_add_help_text("Detection uses WIS + traps skill vs trap difficulty")
	_add_help_text("Disarming uses DEX + traps skill")
	_add_help_text("Failed disarm may trigger the trap!")

	# Inventory tab
	current_container = inventory_content
	_add_section_header("INVENTORY & EQUIPMENT")
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

	# Crafting tab
	current_container = crafting_content
	_add_section_header("CRAFTING & BUILDING")
	_add_keybind("C", "Open crafting menu")
	_add_keybind("H", "Harvest resource (then direction)")
	_add_keybind("F", "Fish (when near water) / interact with feature")
	_add_keybind("B", "Open build mode")
	_add_keybind("E", "Interact with structure")
	_add_help_text("Fishing requires a rod (with bait) or net")
	_add_help_text("Must be adjacent to 8+ contiguous water tiles")

	# Farming tab
	current_container = farming_content
	_add_section_header("FARMING")
	_add_keybind("Shift + T", "Till soil (requires hoe)")
	_add_keybind("Shift + P", "Plant seeds (then direction)")
	_add_keybind("H", "Harvest mature crops")
	_add_spacer()

	_add_section_header("FARMING TIPS")
	_add_help_text("Till grass/dirt to create farmland")
	_add_help_text("Plant seeds on tilled soil")
	_add_help_text("Crops grow over time and can be harvested when mature")

	# NPCs tab
	current_container = npcs_content
	_add_section_header("NPCs & SHOPPING")
	_add_keybind("T", "Talk to adjacent NPC")
	_add_keybind("Tab (in shop)", "Switch buy/sell mode")
	_add_keybind("1-0 (in shop)", "Filter items by category")
	_add_keybind("+/-", "Adjust quantity")
	_add_keybind("Enter", "Complete transaction")
	_add_help_text("Filters work independently for shop and player inventory")

	# Survival tab
	current_container = survival_content
	_add_section_header("SURVIVAL TIPS")
	_add_help_text("Hunger and thirst drain over time")
	_add_help_text("Temperature affects your stats")
	_add_help_text("Stamina is used for movement and combat")
	_add_help_text("Encumbrance slows you down")
	_add_help_text("Use Shift+R to rest until stamina is full")
	_add_help_text("Resting stops if any event occurs")

	# Abilities tab
	current_container = abilities_content
	_add_section_header("CLASS FEATS & RACIAL TRAITS")
	_add_keybind("A", "Open Special Actions menu")
	_add_spacer()

	_add_section_header("ABILITY TYPES")
	_add_help_text("Use active class feats and racial abilities")
	_add_help_text("Most have limited daily uses (recharge at dawn)")
	_add_help_text("Some must be activated before use (Lucky)")
	_add_help_text("Some traits activate automatically (Relentless)")
	_add_help_text("Passive bonuses apply constantly (no activation needed)")

	# Magic tab
	current_container = magic_content
	_add_section_header("MAGIC & RITUALS")
	_add_keybind("Shift+M or K", "Open spellbook")
	_add_keybind("Shift+K", "Open ritual menu")
	_add_spacer()

	_add_section_header("MAGIC SYSTEM")
	_add_help_text("Spells require mana and INT to cast")
	_add_help_text("Rituals require components and channeling time")
	_add_help_text("Both require minimum 8 INT to use")
	_add_help_text("Spells are instant-cast, rituals take multiple turns")
	_add_help_text("Scrolls and wands allow spell use without knowing them")

	# UI tab
	current_container = ui_content
	_add_section_header("MENUS & UI")
	_add_keybind("P", "Character sheet")
	_add_keybind("M", "World map")
	_add_keybind("A", "Special Actions (class feats & racial traits)")
	_add_keybind("Z", "Fast travel to visited locations")
	_add_keybind("? or F1", "This help screen")
	_add_keybind("F12", "Debug commands (dev mode)")
	_add_keybind("ESC", "Pause menu / close UI")
	_add_keybind("1-3 (in menus)", "Quick-select save slots")

## Add a section header
func _add_section_header(text: String) -> void:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_SECTION)
	header.add_theme_font_size_override("font_size", 15)
	current_container.add_child(header)

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

	current_container.add_child(line)

## Add help text (for tips, not keybinds)
func _add_help_text(text: String) -> void:
	var label = Label.new()
	label.text = "  • " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", COLOR_TIP)
	label.add_theme_font_size_override("font_size", 14)
	current_container.add_child(label)

## Add a spacer
func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	current_container.add_child(spacer)

## Handle input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Get current tab's scroll container
		var current_tab_index = tab_container.current_tab
		var current_scroll = tab_container.get_child(current_tab_index) as ScrollContainer

		if current_scroll:
			var scroll_amount = 40  # Pixels to scroll per key press

			if event.keycode == KEY_UP or event.keycode == KEY_W:
				current_scroll.scroll_vertical -= scroll_amount
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
				current_scroll.scroll_vertical += scroll_amount
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_PAGEUP:
				current_scroll.scroll_vertical -= scroll_amount * 5
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_PAGEDOWN:
				current_scroll.scroll_vertical += scroll_amount * 5
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_HOME:
				current_scroll.scroll_vertical = 0
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_END:
				current_scroll.scroll_vertical = int(current_scroll.get_v_scroll_bar().max_value)
				get_viewport().set_input_as_handled()

		# Tab navigation (LEFT/RIGHT arrows or TAB/SHIFT+TAB)
		if (event.keycode == KEY_LEFT and not event.shift_pressed) or (event.keycode == KEY_TAB and event.shift_pressed):
			var new_tab = (tab_container.current_tab - 1) % tab_container.get_tab_count()
			tab_container.current_tab = new_tab
			get_viewport().set_input_as_handled()
		elif (event.keycode == KEY_RIGHT and not event.shift_pressed) or (event.keycode == KEY_TAB and not event.shift_pressed):
			var new_tab = (tab_container.current_tab + 1) % tab_container.get_tab_count()
			tab_container.current_tab = new_tab
			get_viewport().set_input_as_handled()
		elif not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_F1 or (event.keycode == KEY_SLASH and event.shift_pressed)):
			close()

		# Always consume keyboard input while help screen is open
		get_viewport().set_input_as_handled()
