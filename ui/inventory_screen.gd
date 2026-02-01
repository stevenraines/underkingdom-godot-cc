extends Control

## InventoryScreen - UI for displaying and managing player inventory
##
## Shows equipped items, inventory contents, weight, and encumbrance.
## Allows equipping, using, dropping, and inscribing items.

signal closed()

# Preloads
const InscriptionDialogScene = preload("res://ui/inscription_dialog.tscn")
const GroundItemClass = preload("res://entities/ground_item.gd")

@onready var equipment_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/EquipmentPanel/EquipmentScrollContainer/EquipmentList
@onready var equipment_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/EquipmentPanel/EquipmentScrollContainer
@onready var inventory_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/InventoryPanel/ScrollContainer/InventoryList
@onready var inventory_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/InventoryPanel/ScrollContainer
@onready var weight_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderPanel/WeightLabel
@onready var warmth_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderPanel/WarmthLabel
@onready var encumbrance_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderPanel/EncumbranceLabel
@onready var equipment_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/EquipmentPanel/EquipmentTitle
@onready var inventory_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/InventoryPanel/InventoryTitle

# New tooltip UI elements (3-column layout)
@onready var item_name_label: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/TooltipColumns/NameColumn/ItemName
@onready var item_desc_label: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/TooltipColumns/NameColumn/ItemDesc
@onready var stat_line_1: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/TooltipColumns/StatsColumn/StatLine1
@onready var stat_line_2: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/TooltipColumns/StatsColumn/StatLine2
@onready var stat_line_3: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/TooltipColumns/StatsColumn/StatLine3
@onready var weight_line: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/TooltipColumns/ValueColumn/WeightLine
@onready var value_line: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/TooltipColumns/ValueColumn/ValueLine
@onready var action_e: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/ActionsRow/ActionE
@onready var action_u: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/ActionsRow/ActionU
@onready var action_d: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/ActionsRow/ActionD
@onready var action_inscribe: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/ActionsRow/ActionInscribe
@onready var action_uninscribe: Label = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipVBox/ActionsRow/ActionUninscribe

# Filter bar UI elements
@onready var filter_all: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow1/FilterAll
@onready var filter_weapons: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow1/FilterWeapons
@onready var filter_armor: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow1/FilterArmor
@onready var filter_tools: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow1/FilterTools
@onready var filter_consumables: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow1/FilterConsumables
@onready var filter_materials: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow2/FilterMaterials
@onready var filter_ammo: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow2/FilterAmmo
@onready var filter_books: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow2/FilterBooks
@onready var filter_seeds: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow2/FilterSeeds
@onready var filter_misc: Label = $Panel/MarginContainer/VBoxContainer/FilterBarContainer/FilterRow2/FilterMisc

var player: Player = null
var selected_item: Item = null
var selected_slot: String = ""
var is_equipment_focused: bool = false
var equipment_index: int = 0
var inventory_index: int = 0

# Slot selection mode (when pressing E on empty slot or multi-slot item)
var slot_selection_mode: bool = false
var slot_selection_items: Array[Item] = []
var slot_selection_index: int = 0
var pending_equip_slot: String = ""  # The slot we're trying to equip to

# Inscription dialog
var inscription_dialog = null
var inscription_dialog_active: bool = false

# Filter state
var current_filter: Inventory.FilterType = Inventory.FilterType.ALL
var filter_bar_focused: bool = false

# Colors
const COLOR_SELECTED = Color(0.2, 0.4, 0.3, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_EMPTY = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_EQUIPPED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.6, 1.0)
const COLOR_PANEL_ACTIVE = Color(0.8, 0.8, 0.5, 1.0)
const COLOR_PANEL_INACTIVE = Color(0.5, 0.5, 0.4, 1.0)

# Equipment slots in display order
const EQUIPMENT_SLOTS = ["head", "neck", "torso", "back", "hands", "legs", "feet", "main_hand", "off_hand", "accessory_1", "accessory_2"]
const SLOT_DISPLAY_NAMES = {
	"head": "Head",
	"neck": "Neck",
	"torso": "Torso",
	"back": "Back",
	"hands": "Hands",
	"legs": "Legs",
	"feet": "Feet",
	"main_hand": "Weapon",
	"off_hand": "Off-Hand",
	"accessory_1": "Ring (L)",
	"accessory_2": "Ring (R)"
}
const SLOT_ICONS = {
	"head": "○",
	"neck": "◎",
	"torso": "▣",
	"back": ")",
	"hands": "☐",
	"legs": "║",
	"feet": "⌐",
	"main_hand": "†",
	"off_hand": "◈",
	"accessory_1": "◇",
	"accessory_2": "◇"
}

# Filter configuration
const FILTER_LABELS = {
	Inventory.FilterType.ALL: "All",
	Inventory.FilterType.WEAPONS: "Weapons",
	Inventory.FilterType.ARMOR: "Armor",
	Inventory.FilterType.TOOLS: "Tools",
	Inventory.FilterType.CONSUMABLES: "Consumables",
	Inventory.FilterType.MATERIALS: "Materials",
	Inventory.FilterType.AMMUNITION: "Ammo",
	Inventory.FilterType.BOOKS: "Books",
	Inventory.FilterType.SEEDS: "Seeds",
	Inventory.FilterType.MISC: "Misc"
}

const FILTER_HOTKEYS = {
	KEY_1: Inventory.FilterType.ALL,
	KEY_2: Inventory.FilterType.WEAPONS,
	KEY_3: Inventory.FilterType.ARMOR,
	KEY_4: Inventory.FilterType.TOOLS,
	KEY_5: Inventory.FilterType.CONSUMABLES,
	KEY_6: Inventory.FilterType.MATERIALS,
	KEY_7: Inventory.FilterType.AMMUNITION,
	KEY_8: Inventory.FilterType.BOOKS,
	KEY_9: Inventory.FilterType.SEEDS,
	KEY_0: Inventory.FilterType.MISC
}

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Don't process input if inscription dialog is active
	if inscription_dialog_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Handle slot selection mode separately
		if slot_selection_mode:
			_handle_slot_selection_input(event.keycode)
			get_viewport().set_input_as_handled()
			return

		# Handle filter hotkeys (number keys 1-0)
		if FILTER_HOTKEYS.has(event.keycode):
			_set_filter(FILTER_HOTKEYS[event.keycode])
			get_viewport().set_input_as_handled()
			return

		# Check for { key (inscribe) - Shift+[ or unicode 123
		var is_inscribe_key = (event.keycode == KEY_BRACKETLEFT and event.shift_pressed) or event.unicode == 123
		# Check for } key (uninscribe) - Shift+] or unicode 125
		var is_uninscribe_key = (event.keycode == KEY_BRACKETRIGHT and event.shift_pressed) or event.unicode == 125

		if is_inscribe_key:
			_inscribe_selected()
			get_viewport().set_input_as_handled()
			return
		elif is_uninscribe_key:
			_uninscribe_selected()
			get_viewport().set_input_as_handled()
			return

		match event.keycode:
			KEY_ESCAPE, KEY_I:
				_close()
			KEY_UP:
				_navigate(-1)
			KEY_DOWN:
				_navigate(1)
			KEY_TAB:
				_toggle_focus()
			KEY_E:
				_equip_selected()
			KEY_U:
				_use_selected()
			KEY_D:
				_drop_selected()
			KEY_ENTER, KEY_SPACE:
				_action_selected()

		# Always consume keyboard input while inventory screen is open
		# This prevents input from leaking through to the game in the background
		get_viewport().set_input_as_handled()

func open(p: Player) -> void:
	player = p
	refresh()
	show()
	is_equipment_focused = false
	equipment_index = 0
	inventory_index = 0
	_update_selection()

func _close() -> void:
	hide()
	closed.emit()

func refresh() -> void:
	if not player or not player.inventory:
		return

	_update_weight_display()
	_update_filter_bar()
	_update_equipment_display()
	_update_inventory_display()
	_update_selection()

func _update_weight_display() -> void:
	if not player or not player.inventory:
		return

	var inv = player.inventory
	var current_weight = inv.get_total_weight()
	var max_weight = inv.max_weight

	weight_label.text = "Weight: %.1f / %.1f kg" % [current_weight, max_weight]

	# Update warmth display
	var total_warmth = inv.get_total_warmth()
	if warmth_label:
		warmth_label.text = "Warmth: %+.0f°F" % total_warmth
		if total_warmth > 0:
			warmth_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))  # Warm orange
		elif total_warmth < 0:
			warmth_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))  # Cool blue
		else:
			warmth_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Neutral gray

	var penalty = inv.get_encumbrance_penalty()
	match penalty.state:
		"normal":
			encumbrance_label.text = "Status: Normal"
			encumbrance_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		"encumbered":
			encumbrance_label.text = "Status: Encumbered (+50% stamina cost)"
			encumbrance_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
		"overburdened":
			encumbrance_label.text = "Status: Overburdened (2x move cost)"
			encumbrance_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		"immobile":
			encumbrance_label.text = "Status: CANNOT MOVE"
			encumbrance_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

func _update_equipment_display() -> void:
	if not equipment_list or not player or not player.inventory:
		return
	
	# Clear existing (use free() instead of queue_free() for immediate removal)
	for child in equipment_list.get_children():
		equipment_list.remove_child(child)
		child.free()
	
	# Add equipment slots
	for slot in EQUIPMENT_SLOTS:
		var container = _create_item_row()
		container.name = slot
		
		var equipped_item = player.inventory.get_equipped(slot)
		var slot_name = SLOT_DISPLAY_NAMES.get(slot, slot)
		var slot_icon = SLOT_ICONS.get(slot, "•")
		
		if equipped_item:
			container.get_node("Icon").text = equipped_item.ascii_char
			container.get_node("Icon").add_theme_color_override("font_color", equipped_item.get_color())
			container.get_node("Name").text = equipped_item.get_display_name()
			container.get_node("Name").add_theme_color_override("font_color", COLOR_EQUIPPED)
			container.get_node("Weight").text = "%.1fkg" % equipped_item.weight
			container.get_node("Weight").add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		else:
			container.get_node("Icon").text = slot_icon
			container.get_node("Icon").add_theme_color_override("font_color", COLOR_EMPTY)
			container.get_node("Name").text = "<%s>" % slot_name
			container.get_node("Name").add_theme_color_override("font_color", COLOR_EMPTY)
			container.get_node("Weight").text = ""
		
		container.set_meta("slot", slot)
		equipment_list.add_child(container)

func _update_inventory_display() -> void:
	if not inventory_list or not player or not player.inventory:
		return

	# Clear existing (use free() instead of queue_free() for immediate removal)
	for child in inventory_list.get_children():
		inventory_list.remove_child(child)
		child.free()

	# Get filtered and sorted items
	var items = player.inventory.get_items_by_filter(current_filter)

	# Update title with filter info
	_update_inventory_title(items.size())

	# Reset scroll position to top
	if inventory_scroll:
		inventory_scroll.scroll_vertical = 0

	if items.size() == 0:
		var label = Label.new()
		if current_filter == Inventory.FilterType.ALL:
			label.text = "  (Empty backpack)"
		else:
			var filter_name = FILTER_LABELS.get(current_filter, "items")
			label.text = "  (No %s)" % filter_name.to_lower()
		label.add_theme_color_override("font_color", COLOR_EMPTY)
		label.add_theme_font_size_override("font_size", 13)
		inventory_list.add_child(label)
	else:
		for item in items:
			var container = _create_item_row()
			container.name = item.id
			
			container.get_node("Icon").text = item.ascii_char
			container.get_node("Icon").add_theme_color_override("font_color", item.get_color())

			var name_text = item.get_display_name()
			if item.stack_size > 1:
				name_text = "%s (x%d)" % [item.get_display_name(), item.stack_size]
			container.get_node("Name").text = name_text
			container.get_node("Name").add_theme_color_override("font_color", item.get_color())
			
			container.get_node("Weight").text = "%.1fkg" % item.get_total_weight()
			container.get_node("Weight").add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			
			container.set_meta("item", item)
			inventory_list.add_child(container)

## Create a row container for displaying items
func _create_item_row() -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	var icon = Label.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(20, 0)
	icon.add_theme_font_size_override("font_size", 14)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(icon)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	container.add_child(name_label)

	var weight_label_item = Label.new()
	weight_label_item.name = "Weight"
	weight_label_item.custom_minimum_size = Vector2(60, 0)  # Increased width to account for scrollbar
	weight_label_item.add_theme_font_size_override("font_size", 12)
	weight_label_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(weight_label_item)

	# Add spacer to keep weight clear of scrollbar
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(12, 0)  # Width of scrollbar
	container.add_child(spacer)

	return container

func _update_selection() -> void:
	selected_item = null
	selected_slot = ""
	
	# Update panel title colors to show which is active
	if equipment_title:
		equipment_title.add_theme_color_override("font_color", COLOR_PANEL_ACTIVE if is_equipment_focused else COLOR_PANEL_INACTIVE)
	if inventory_title:
		inventory_title.add_theme_color_override("font_color", COLOR_PANEL_ACTIVE if not is_equipment_focused else COLOR_PANEL_INACTIVE)
	
	# Reset all highlights in equipment list
	for i in range(equipment_list.get_child_count()):
		var child = equipment_list.get_child(i)
		_set_row_highlight(child, false)
	
	# Reset all highlights in inventory list  
	for i in range(inventory_list.get_child_count()):
		var child = inventory_list.get_child(i)
		_set_row_highlight(child, false)
	
	# Highlight selected
	if is_equipment_focused:
		var children = equipment_list.get_children()
		if equipment_index >= 0 and equipment_index < children.size():
			var selected_row = children[equipment_index]
			_set_row_highlight(selected_row, true)
			selected_slot = EQUIPMENT_SLOTS[equipment_index]
			selected_item = player.inventory.get_equipped(selected_slot) if player and player.inventory else null
			# Scroll to keep selected equipment slot visible
			if equipment_scroll:
				equipment_scroll.ensure_control_visible(selected_row)
	else:
		var children = inventory_list.get_children()
		if inventory_index >= 0 and inventory_index < children.size():
			var selected_row = children[inventory_index]
			_set_row_highlight(selected_row, true)
			selected_item = selected_row.get_meta("item") if selected_row.has_meta("item") else null
			# Scroll to keep selected item visible
			_scroll_to_item(selected_row)

	_update_tooltip()

## Scroll to ensure the selected item is visible in the inventory scroll container
func _scroll_to_item(item_row: Control) -> void:
	if not inventory_scroll or not item_row or not is_instance_valid(item_row):
		return

	# Use call_deferred to ensure layout is updated, and re-check validity
	_scroll_to_item_deferred.call_deferred(item_row)

## Deferred scroll helper to avoid freed object errors
func _scroll_to_item_deferred(item_row: Control) -> void:
	# Double-check the item is still valid after deferring
	if not inventory_scroll or not item_row or not is_instance_valid(item_row):
		return

	# Get the item's position relative to the scroll container
	var item_top = item_row.position.y
	var item_bottom = item_top + item_row.size.y

	# Get the visible area of the scroll container
	var scroll_top = inventory_scroll.scroll_vertical
	var scroll_bottom = scroll_top + inventory_scroll.size.y

	# Check if item is above visible area
	if item_top < scroll_top:
		inventory_scroll.scroll_vertical = int(item_top)
	# Check if item is below visible area
	elif item_bottom > scroll_bottom:
		inventory_scroll.scroll_vertical = int(item_bottom - inventory_scroll.size.y)

## Set highlight state for a row
func _set_row_highlight(row: Control, highlighted: bool) -> void:
	if row is HBoxContainer:
		var name_node = row.get_node_or_null("Name")
		if name_node and name_node is Label:
			if highlighted:
				name_node.text = "► " + name_node.text.trim_prefix("► ")
				name_node.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
			else:
				name_node.text = name_node.text.trim_prefix("► ")
				# Restore original color from item metadata or use default
				if row.has_meta("item"):
					var item = row.get_meta("item")
					name_node.add_theme_color_override("font_color", item.get_color())
				elif row.has_meta("slot"):
					# Equipment slot - check if it has an equipped item
					var slot = row.get_meta("slot")
					var equipped = player.inventory.get_equipped(slot) if player and player.inventory else null
					if equipped:
						name_node.add_theme_color_override("font_color", COLOR_EQUIPPED)
					else:
						name_node.add_theme_color_override("font_color", COLOR_EMPTY)
	elif row is Label:
		if highlighted:
			row.text = "► " + row.text.trim_prefix("► ")
			row.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		else:
			row.text = row.text.trim_prefix("► ")
			row.add_theme_color_override("font_color", COLOR_EMPTY)

func _update_tooltip() -> void:
	if not item_name_label:
		return

	if selected_item:
		_populate_item_tooltip(selected_item)
	elif selected_slot != "":
		var slot_name = SLOT_DISPLAY_NAMES.get(selected_slot, selected_slot)
		# Check if off_hand is blocked
		if selected_slot == "off_hand" and player and player.inventory and player.inventory.is_off_hand_blocked():
			item_name_label.text = "%s slot is BLOCKED" % slot_name
			item_name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
			item_desc_label.text = "A two-handed weapon is equipped"
			stat_line_1.text = "Unequip weapon to use"
			stat_line_2.text = ""
			stat_line_3.text = ""
		else:
			item_name_label.text = "Empty %s slot" % slot_name
			item_name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			item_desc_label.text = "Select an item to equip"
			stat_line_1.text = "[E] Browse items"
			stat_line_2.text = ""
			stat_line_3.text = ""
		weight_line.text = ""
		value_line.text = ""
		_update_action_visibility(null)
	else:
		item_name_label.text = "No item selected"
		item_name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_desc_label.text = "Use [Tab] to switch panels"
		stat_line_1.text = ""
		stat_line_2.text = ""
		stat_line_3.text = ""
		weight_line.text = ""
		value_line.text = ""
		_update_action_visibility(null)

## Populate the tooltip UI with item data
func _populate_item_tooltip(item: Item) -> void:
	# Name column - show inscription if present
	item_name_label.text = item.get_display_name()
	item_name_label.add_theme_color_override("font_color", item.get_color())
	item_desc_label.text = item.description

	# Stats column - build stat lines based on item type
	var stats: Array[String] = []

	match item.item_type:
		"consumable":
			if item.effects.has("health") and item.effects["health"] > 0:
				stats.append("♥ Heals: %d HP" % item.effects["health"])
			if item.effects.has("hunger") and item.effects["hunger"] > 0:
				stats.append("◆ Hunger: +%d%%" % item.effects["hunger"])
			if item.effects.has("thirst") and item.effects["thirst"] > 0:
				stats.append("◇ Thirst: +%d%%" % item.effects["thirst"])
		"weapon", "tool":
			# Check if this is a spell-casting item (wand, rod, staff with spell)
			if item.casts_spell != "" and item.max_charges > 0:
				# Spell-casting item - show spell and charges (or Unknown if unidentified)
				if item.is_identified():
					var spell = SpellManager.get_spell(item.casts_spell)
					if spell:
						stats.append("✦ Casts: %s" % spell.name)
						var spell_dmg = spell.get_damage().get("base", 0)
						if spell_dmg > 0:
							stats.append("⚔ Spell Damage: %d" % spell_dmg)
					stats.append("⚡ Charges: %d/%d" % [item.charges, item.max_charges])
				else:
					stats.append("✦ Casts: Unknown")
					stats.append("⚔ Spell Damage: Unknown")
					stats.append("⚡ Charges: Unknown")
			# Check if this is a casting focus (staff)
			elif item.flags.get("casting_focus", false):
				var bonuses = item.get_casting_bonuses()
				if item.is_identified() and not bonuses.is_empty():
					if bonuses.has("success_modifier"):
						stats.append("✦ Cast Success: +%d%%" % bonuses.success_modifier)
					if bonuses.has("school_affinity"):
						var school_bonus = bonuses.get("school_damage_bonus", 0)
						stats.append("◈ %s: +%d dmg" % [bonuses.school_affinity.capitalize(), school_bonus])
					if bonuses.has("mana_cost_modifier"):
						stats.append("◇ Mana Cost: %d%%" % bonuses.mana_cost_modifier)
				elif not item.is_identified():
					stats.append("✦ Bonuses: Unknown")
				# Show damage for melee use
				if item.damage_min > 0 and item.damage_max > 0:
					stats.append("⚔ Melee: %d-%d" % [item.damage_min, item.damage_max])
			else:
				# Regular weapon/tool - show damage
				if item.damage_min > 0 and item.damage_max > 0:
					if item.damage_bonus > 0:
						stats.append("⚔ Damage: %d-%d +%d" % [item.damage_min, item.damage_max, item.damage_bonus])
					else:
						stats.append("⚔ Damage: %d-%d" % [item.damage_min, item.damage_max])
				elif item.damage_bonus > 0:
					stats.append("⚔ Damage: +%d" % item.damage_bonus)
				# Tool type
				if item.tool_type != "":
					stats.append("⚒ Tool: %s" % item.tool_type.capitalize())
				# Equip slots (shows multi-slot or two-handed)
				var slots = item.get_equip_slots()
				if slots.size() > 1:
					var slot_names = []
					for slot in slots:
						slot_names.append(SLOT_DISPLAY_NAMES.get(slot, slot))
					stats.append("Slots: %s" % ", ".join(slot_names))
				elif item.is_two_handed():
					stats.append("◊ Two-Handed")
		"armor":
			if item.armor_value > 0:
				stats.append("◈ Armor: %d" % item.armor_value)
			if item.warmth != 0.0:
				stats.append("☀ Warmth: %+.0f°F" % item.warmth)

	# Assign stats to the 3 stat lines
	stat_line_1.text = stats[0] if stats.size() > 0 else ""
	stat_line_2.text = stats[1] if stats.size() > 1 else ""
	stat_line_3.text = stats[2] if stats.size() > 2 else ""

	# Set stat colors based on type
	var stat_color = Color(0.7, 0.9, 0.7)
	match item.item_type:
		"consumable":
			stat_color = Color(0.5, 0.9, 0.5)
		"weapon", "tool":
			stat_color = Color(1.0, 0.7, 0.5)  # Warm orange for combat items
		"armor":
			stat_color = Color(0.5, 0.5, 1.0)

	stat_line_1.add_theme_color_override("font_color", stat_color)
	stat_line_2.add_theme_color_override("font_color", stat_color)
	stat_line_3.add_theme_color_override("font_color", stat_color)

	# Apply warmth-specific coloring (orange for positive, blue for negative)
	if item.item_type == "armor" and item.warmth != 0.0:
		var warmth_color = Color(1.0, 0.7, 0.4) if item.warmth > 0 else Color(0.5, 0.7, 1.0)
		# Find which stat line has the warmth text and recolor it
		if stat_line_1.text.contains("Warmth"):
			stat_line_1.add_theme_color_override("font_color", warmth_color)
		elif stat_line_2.text.contains("Warmth"):
			stat_line_2.add_theme_color_override("font_color", warmth_color)
		elif stat_line_3.text.contains("Warmth"):
			stat_line_3.add_theme_color_override("font_color", warmth_color)

	# Value column
	weight_line.text = "%.1f kg" % item.weight
	value_line.text = "%d gold" % item.value

	# Update action visibility
	_update_action_visibility(item)

## Update which action labels are visible based on item
func _update_action_visibility(item: Item) -> void:
	if not item:
		action_e.visible = false
		action_u.visible = false
		action_d.visible = false
		action_inscribe.visible = false
		action_uninscribe.visible = false
		return

	# Show/hide actions based on item properties and context
	if is_equipment_focused and selected_slot != "":
		# Item is equipped - show unequip
		action_e.text = "[E] Unequip"
		action_e.visible = true
	else:
		# Item is in inventory
		action_e.text = "[E] Equip"
		action_e.visible = item.is_equippable()

	action_u.visible = item.is_usable()
	action_d.visible = true

	# Inscription actions - always show inscribe, only show uninscribe if item has inscription
	action_inscribe.visible = true
	action_uninscribe.visible = item.has_inscription()

func _navigate(direction: int) -> void:
	if is_equipment_focused:
		equipment_index = clampi(equipment_index + direction, 0, EQUIPMENT_SLOTS.size() - 1)
	else:
		var item_count = player.inventory.get_all_items().size() if player and player.inventory else 0
		inventory_index = clampi(inventory_index + direction, 0, max(0, item_count - 1))
	
	_update_selection()

func _toggle_focus() -> void:
	is_equipment_focused = not is_equipment_focused
	_update_selection()

func _equip_selected() -> void:
	if not player or not player.inventory:
		return
	
	if is_equipment_focused:
		# On equipment side
		if selected_item:
			# Unequip the item
			player.inventory.unequip_slot(selected_slot)
		elif selected_slot != "":
			# Empty slot - show items that can be equipped here
			_show_items_for_slot(selected_slot)
			return
	else:
		# On inventory side - equip selected item
		if not selected_item:
			return
		
		# Store the item reference before any operations
		var item_to_process = selected_item
		
		# Check if item is equippable
		if not item_to_process.is_equippable():
			return
		
		# Check if it's in inventory
		if not player.inventory.contains_item(item_to_process):
			return
		
		# If item can go in multiple slots, show slot picker
		var slots = item_to_process.get_equip_slots()
		if slots.size() > 1:
			_show_slot_picker(item_to_process)
			return
		
		# Clear selection state to prevent double-operations
		selected_item = null
		
		# Equip to default slot
		player.inventory.equip_item(item_to_process)
	
	refresh()

## Show items that can be equipped to a specific slot
func _show_items_for_slot(slot: String) -> void:
	# Reset slot picker state (in case we were previously in slot picker mode)
	_pending_slot_picker_item = null
	_slot_picker_index = 0

	# Check if off_hand is blocked
	if slot == "off_hand" and player.inventory.is_off_hand_blocked():
		# Show message in tooltip
		item_name_label.text = "Off-hand slot is blocked!"
		item_name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		item_desc_label.text = "Unequip your main weapon first"
		stat_line_1.text = ""
		stat_line_2.text = ""
		stat_line_3.text = ""
		weight_line.text = ""
		value_line.text = ""
		_update_action_visibility(null)
		return

	var items = player.inventory.get_items_for_slot(slot)
	if items.is_empty():
		item_name_label.text = "No items available"
		item_name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_desc_label.text = "No items can be equipped here"
		stat_line_1.text = ""
		stat_line_2.text = ""
		stat_line_3.text = ""
		weight_line.text = ""
		value_line.text = ""
		_update_action_visibility(null)
		return
	
	slot_selection_mode = true
	slot_selection_items = items
	slot_selection_index = 0
	pending_equip_slot = slot
	_update_slot_selection_display()

## Show slot picker for items with multiple equip slots
func _show_slot_picker(item: Item) -> void:
	# Build a list showing slot options
	slot_selection_mode = true
	slot_selection_items.clear()
	slot_selection_index = 0
	pending_equip_slot = ""
	_slot_picker_index = 0  # Reset to first slot
	
	# Store the item we're equipping
	_pending_slot_picker_item = item
	
	# Update the display
	_update_slot_picker_display()

## Update the slot picker display with current selection
func _update_slot_picker_display() -> void:
	if not _pending_slot_picker_item:
		return

	var item = _pending_slot_picker_item
	var slots = item.get_equip_slots()

	# Show slot picker in tooltip area
	item_name_label.text = "Select Slot for %s" % item.name
	item_name_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))

	# Build slot list for description
	var slot_lines: Array[String] = []
	for i in range(slots.size()):
		var slot = slots[i]
		var slot_name = SLOT_DISPLAY_NAMES.get(slot, slot)
		var current = player.inventory.get_equipped(slot)
		var current_text = current.name if current else "Empty"
		var marker = "► " if i == _slot_picker_index else "  "
		slot_lines.append("%s[%d] %s: %s" % [marker, i + 1, slot_name, current_text])

	item_desc_label.text = "\n".join(slot_lines)
	stat_line_1.text = "↑↓ Navigate"
	stat_line_2.text = "Enter to equip"
	stat_line_3.text = "ESC Cancel"
	weight_line.text = ""
	value_line.text = ""
	_update_action_visibility(null)

var _pending_slot_picker_item: Item = null
var _slot_picker_index: int = 0  # Track selected slot in slot picker

## Handle slot picker key input  
func _handle_slot_selection_input(keycode: int) -> void:
	# If we have a pending slot picker item, handle navigation and selection
	if _pending_slot_picker_item:
		var slots = _pending_slot_picker_item.get_equip_slots()
		match keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var index = keycode - KEY_1
				if index < slots.size():
					var slot = slots[index]
					player.inventory.equip_item(_pending_slot_picker_item, slot)
					_cancel_slot_selection()
				return
			KEY_UP:
				_slot_picker_index = max(0, _slot_picker_index - 1)
				_update_slot_picker_display()
				return
			KEY_DOWN:
				_slot_picker_index = min(slots.size() - 1, _slot_picker_index + 1)
				_update_slot_picker_display()
				return
			KEY_ENTER, KEY_SPACE, KEY_E:
				if _slot_picker_index < slots.size():
					var slot = slots[_slot_picker_index]
					player.inventory.equip_item(_pending_slot_picker_item, slot)
					_cancel_slot_selection()
				return
			KEY_ESCAPE:
				_cancel_slot_selection()
				return
		return
	
	# Normal item selection mode (for empty slot)
	match keycode:
		KEY_ESCAPE:
			_cancel_slot_selection()
		KEY_UP:
			slot_selection_index = max(0, slot_selection_index - 1)
			_update_slot_selection_display()
		KEY_DOWN:
			slot_selection_index = min(slot_selection_items.size() - 1, slot_selection_index + 1)
			_update_slot_selection_display()
		KEY_ENTER, KEY_SPACE, KEY_E:
			_confirm_slot_selection()

func _cancel_slot_selection() -> void:
	slot_selection_mode = false
	slot_selection_items.clear()
	pending_equip_slot = ""
	_pending_slot_picker_item = null
	_slot_picker_index = 0
	refresh()

func _confirm_slot_selection() -> void:
	if slot_selection_items.is_empty() or pending_equip_slot == "":
		_cancel_slot_selection()
		return
	
	var item = slot_selection_items[slot_selection_index]
	player.inventory.equip_item(item, pending_equip_slot)
	_cancel_slot_selection()

func _update_slot_selection_display() -> void:
	if slot_selection_items.is_empty():
		return

	var slot_name = SLOT_DISPLAY_NAMES.get(pending_equip_slot, pending_equip_slot)

	# Show item picker in tooltip area
	item_name_label.text = "Select item for %s" % slot_name
	item_name_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))

	# Build item list for description - show selected item with yellow highlight
	var item_lines: Array[String] = []
	for i in range(slot_selection_items.size()):
		var item = slot_selection_items[i]
		var marker = "► " if i == slot_selection_index else "  "
		item_lines.append("%s%s" % [marker, item.name])

	item_desc_label.text = "\n".join(item_lines)
	# Highlight the description in yellow when there's only one item (common case)
	# or when showing the list
	item_desc_label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)

	stat_line_1.text = "↑↓ Navigate"
	stat_line_2.text = "Enter to equip"
	stat_line_3.text = "ESC Cancel"
	weight_line.text = ""
	value_line.text = ""
	_update_action_visibility(null)

func _use_selected() -> void:
	if not player or not selected_item:
		return

	if selected_item.is_usable():
		var result = player.use_item(selected_item)
		if result.has("message") and result.message != "":
			EventBus.message_logged.emit(result.message)
		refresh()
	else:
		EventBus.message_logged.emit("You can't use that.")

func _drop_selected() -> void:
	if not player or not selected_item:
		return

	if is_equipment_focused and selected_slot != "":
		# Unequip then drop
		var item = player.inventory.unequip_slot(selected_slot)
		if item:
			var ground_item = player.drop_item(item)
			if ground_item:
				EntityManager.entities.append(ground_item)
	else:
		# Drop from inventory - only drop 1 item from stack
		if selected_item.stack_size > 1:
			# Split the stack: create a copy with stack_size = 1
			var item_to_drop = selected_item.duplicate_item()
			item_to_drop.stack_size = 1

			# Reduce original stack
			selected_item.remove_from_stack(1)

			# Drop the single item
			var drop_pos = player._find_drop_position()
			var ground_item = GroundItemClass.create(item_to_drop, drop_pos)
			EntityManager.entities.append(ground_item)
			EventBus.item_dropped.emit(item_to_drop, drop_pos)
		else:
			# Drop the entire item (stack of 1)
			var ground_item = player.drop_item(selected_item)
			if ground_item:
				EntityManager.entities.append(ground_item)

	refresh()

func _action_selected() -> void:
	if not selected_item:
		return

	# Default action based on item type
	match selected_item.item_type:
		"consumable", "book":
			_use_selected()
		"weapon", "armor", "tool":
			_equip_selected()
		_:
			# Check for usable flags (like readable)
			if selected_item.is_usable():
				_use_selected()


## Inscribe the selected item - open inscription dialog
func _inscribe_selected() -> void:
	if not player or not selected_item:
		return

	# Create inscription dialog if it doesn't exist
	if not inscription_dialog:
		inscription_dialog = InscriptionDialogScene.instantiate()
		add_child(inscription_dialog)
		inscription_dialog.inscription_entered.connect(_on_inscription_entered)
		inscription_dialog.cancelled.connect(_on_inscription_cancelled)

	inscription_dialog_active = true
	inscription_dialog.open_inscribe(selected_item)


## Uninscribe the selected item - remove inscription
func _uninscribe_selected() -> void:
	if not player or not selected_item:
		return

	# Only uninscribe if item has an inscription
	if not selected_item.has_inscription():
		return

	# Create inscription dialog if it doesn't exist
	if not inscription_dialog:
		inscription_dialog = InscriptionDialogScene.instantiate()
		add_child(inscription_dialog)
		inscription_dialog.inscription_entered.connect(_on_inscription_entered)
		inscription_dialog.cancelled.connect(_on_inscription_cancelled)

	inscription_dialog_active = true
	inscription_dialog.open_uninscribe(selected_item)


## Handle inscription dialog completion
func _on_inscription_entered(text: String) -> void:
	inscription_dialog_active = false

	if not selected_item:
		return

	if text == "":
		# Empty text means uninscribe
		selected_item.uninscribe()
		EventBus.message_logged.emit("Removed inscription from %s." % selected_item.name)
	else:
		# Set the inscription
		selected_item.inscribe(text)
		EventBus.message_logged.emit("Inscribed %s with {%s}." % [selected_item.name, text])

	refresh()


## Handle inscription dialog cancellation
func _on_inscription_cancelled() -> void:
	inscription_dialog_active = false


## Filter Management Functions

## Set the active filter and refresh display
func _set_filter(filter: Inventory.FilterType) -> void:
	if current_filter != filter:
		current_filter = filter
		inventory_index = 0  # Reset selection to top
		refresh()

## Update filter bar visual state
func _update_filter_bar() -> void:
	if not filter_all:
		return

	# Map filter labels to their filter types
	var filter_labels_map = {
		Inventory.FilterType.ALL: filter_all,
		Inventory.FilterType.WEAPONS: filter_weapons,
		Inventory.FilterType.ARMOR: filter_armor,
		Inventory.FilterType.TOOLS: filter_tools,
		Inventory.FilterType.CONSUMABLES: filter_consumables,
		Inventory.FilterType.MATERIALS: filter_materials,
		Inventory.FilterType.AMMUNITION: filter_ammo,
		Inventory.FilterType.BOOKS: filter_books,
		Inventory.FilterType.SEEDS: filter_seeds,
		Inventory.FilterType.MISC: filter_misc
	}

	# Update colors for all filter labels
	for filter_type in filter_labels_map:
		var label = filter_labels_map[filter_type]
		if filter_type == current_filter:
			label.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		else:
			label.add_theme_color_override("font_color", COLOR_NORMAL)

## Update inventory title with filter info
func _update_inventory_title(item_count: int) -> void:
	if not inventory_title:
		return

	if current_filter == Inventory.FilterType.ALL:
		inventory_title.text = "══ BACKPACK (%d items) ══" % item_count
	else:
		var filter_name = FILTER_LABELS.get(current_filter, "items")
		inventory_title.text = "══ BACKPACK (%d %s) ══" % [item_count, filter_name.to_lower()]
