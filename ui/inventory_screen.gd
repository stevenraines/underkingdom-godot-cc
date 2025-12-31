extends Control

## InventoryScreen - UI for displaying and managing player inventory
##
## Shows equipped items, inventory contents, weight, and encumbrance.
## Allows equipping, using, and dropping items.

signal closed()

@onready var equipment_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/EquipmentPanel/EquipmentList
@onready var inventory_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/InventoryPanel/ScrollContainer/InventoryList
@onready var inventory_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/InventoryPanel/ScrollContainer
@onready var weight_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderPanel/WeightLabel
@onready var encumbrance_label: Label = $Panel/MarginContainer/VBoxContainer/HeaderPanel/EncumbranceLabel
@onready var tooltip_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TooltipPanel/TooltipMargin/TooltipLabel
@onready var equipment_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/EquipmentPanel/EquipmentTitle
@onready var inventory_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/InventoryPanel/InventoryTitle

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

# Colors
const COLOR_SELECTED = Color(0.2, 0.4, 0.3, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_EMPTY = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_EQUIPPED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.6, 1.0)
const COLOR_PANEL_ACTIVE = Color(0.8, 0.8, 0.5, 1.0)
const COLOR_PANEL_INACTIVE = Color(0.5, 0.5, 0.4, 1.0)

# Equipment slots in display order
const EQUIPMENT_SLOTS = ["head", "torso", "hands", "legs", "feet", "main_hand", "off_hand", "accessory_1", "accessory_2"]
const SLOT_DISPLAY_NAMES = {
	"head": "Head",
	"torso": "Torso", 
	"hands": "Hands",
	"legs": "Legs",
	"feet": "Feet",
	"main_hand": "Weapon",
	"off_hand": "Off-Hand",
	"accessory_1": "Ring 1",
	"accessory_2": "Ring 2"
}
const SLOT_ICONS = {
	"head": "○",
	"torso": "▣",
	"hands": "☐",
	"legs": "║",
	"feet": "⌐",
	"main_hand": "†",
	"off_hand": "◈",
	"accessory_1": "◇",
	"accessory_2": "◇"
}

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Handle slot selection mode separately
		if slot_selection_mode:
			_handle_slot_selection_input(event.keycode)
			get_viewport().set_input_as_handled()
			return
		
		match event.keycode:
			KEY_ESCAPE, KEY_I:
				_close()
				get_viewport().set_input_as_handled()
			KEY_UP:
				_navigate(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_navigate(1)
				get_viewport().set_input_as_handled()
			KEY_TAB:
				_toggle_focus()
				get_viewport().set_input_as_handled()
			KEY_E:
				_equip_selected()
				get_viewport().set_input_as_handled()
			KEY_U:
				_use_selected()
				get_viewport().set_input_as_handled()
			KEY_D:
				_drop_selected()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				_action_selected()
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
			container.get_node("Name").text = equipped_item.name
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
	
	# Add inventory items
	var items = player.inventory.get_all_items()
	if items.size() == 0:
		var label = Label.new()
		label.text = "  (Empty backpack)"
		label.add_theme_color_override("font_color", COLOR_EMPTY)
		label.add_theme_font_size_override("font_size", 13)
		inventory_list.add_child(label)
	else:
		for item in items:
			var container = _create_item_row()
			container.name = item.id
			
			container.get_node("Icon").text = item.ascii_char
			container.get_node("Icon").add_theme_color_override("font_color", item.get_color())
			
			var name_text = item.name
			if item.stack_size > 1:
				name_text = "%s (x%d)" % [item.name, item.stack_size]
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
	weight_label_item.custom_minimum_size = Vector2(50, 0)
	weight_label_item.add_theme_font_size_override("font_size", 12)
	weight_label_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	container.add_child(weight_label_item)
	
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
	if not tooltip_label:
		return
	
	if selected_item:
		tooltip_label.text = _format_item_tooltip(selected_item)
	elif selected_slot != "":
		var slot_name = SLOT_DISPLAY_NAMES.get(selected_slot, selected_slot)
		# Check if off_hand is blocked
		if selected_slot == "off_hand" and player and player.inventory and player.inventory.is_off_hand_blocked():
			tooltip_label.text = "[color=#ff8888]%s slot is BLOCKED[/color]\n\n[color=#888888]A two-handed weapon is equipped in main hand.[/color]\n\nUnequip the weapon to use this slot.\n\n[color=#666666][Tab] Switch panel | [ESC] Close[/color]"  % slot_name
		else:
			tooltip_label.text = "[color=#888888]Empty %s slot[/color]\n\nSelect an item to equip here.\n\n[color=#666666][E] Browse items | [Tab] Switch panel | [ESC] Close[/color]" % slot_name
	else:
		tooltip_label.text = "[color=#888888]Use [Tab] to switch between Equipment and Backpack[/color]\n\n[color=#666666][ESC] Close[/color]"

## Format item tooltip with BBCode
func _format_item_tooltip(item: Item) -> String:
	var tooltip = "[color=#%s][b]%s[/b][/color]\n" % [item.get_color().to_html(false), item.name]
	tooltip += "[color=#888888]%s[/color]\n\n" % item.description
	
	# Stats based on item type
	match item.item_type:
		"consumable":
			if item.effects.has("health") and item.effects["health"] > 0:
				tooltip += "[color=#88ff88]♥ Heals: %d HP[/color]\n" % item.effects["health"]
			if item.effects.has("hunger") and item.effects["hunger"] > 0:
				tooltip += "[color=#ffcc88]◆ Hunger: +%d%%[/color]\n" % item.effects["hunger"]
			if item.effects.has("thirst") and item.effects["thirst"] > 0:
				tooltip += "[color=#88ccff]◇ Thirst: +%d%%[/color]\n" % item.effects["thirst"]
		"weapon":
			tooltip += "[color=#ff8888]⚔ Damage: +%d[/color]\n" % item.damage_bonus
			if item.is_two_handed():
				tooltip += "[color=#cc88cc]◊ Two-Handed[/color]\n"
		"armor":
			tooltip += "[color=#8888ff]◈ Armor: %d[/color]\n" % item.armor_value
		"tool":
			if item.tool_type != "":
				tooltip += "[color=#cccccc]⚒ Tool: %s[/color]\n" % item.tool_type.capitalize()
			if item.is_two_handed():
				tooltip += "[color=#cc88cc]◊ Two-Handed[/color]\n"
	
	# Equip slot info for multi-slot items
	var slots = item.get_equip_slots()
	if slots.size() > 1:
		var slot_names = []
		for slot in slots:
			slot_names.append(SLOT_DISPLAY_NAMES.get(slot, slot))
		tooltip += "[color=#aaaaaa]Slots: %s[/color]\n" % ", ".join(slot_names)
	
	tooltip += "\n[color=#666666]Weight: %.1f kg  |  Value: %d gold[/color]" % [item.weight, item.value]
	
	# Dynamic action hints based on item flags and context
	var actions = []
	
	if is_equipment_focused and selected_slot != "":
		# Item is equipped - show unequip option
		actions.append("[E] Unequip")
	else:
		# Item is in inventory - show contextual options
		if item.is_consumable():
			actions.append("[U] Use")
		if item.is_equippable():
			actions.append("[E] Equip")
	
	actions.append("[D] Drop")
	actions.append("[Tab] Switch panel")
	actions.append("[ESC] Close")
	
	tooltip += "\n\n[color=#666666]%s[/color]" % " | ".join(actions)
	
	return tooltip

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
	# Check if off_hand is blocked
	if slot == "off_hand" and player.inventory.is_off_hand_blocked():
		# Show message in tooltip
		tooltip_label.text = "[color=#ff8888]Off-hand slot is blocked by two-handed weapon![/color]\n\nUnequip your main weapon first."
		return
	
	var items = player.inventory.get_items_for_slot(slot)
	if items.is_empty():
		tooltip_label.text = "[color=#888888]No items in backpack can be equipped here.[/color]"
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
	
	var tooltip = "[color=#99cc99][b]Select Slot for %s[/b][/color]\n\n" % item.name
	for i in range(slots.size()):
		var slot = slots[i]
		var slot_name = SLOT_DISPLAY_NAMES.get(slot, slot)
		var current = player.inventory.get_equipped(slot)
		var current_text = current.name if current else "Empty"
		var marker = "► " if i == _slot_picker_index else "  "
		# Highlight selected slot in yellow
		if i == _slot_picker_index:
			tooltip += "[color=#ffff99]%s[%d] %s: %s[/color]\n" % [marker, i + 1, slot_name, current_text]
		else:
			tooltip += "%s[%d] %s: %s\n" % [marker, i + 1, slot_name, current_text]
	
	tooltip += "\n[color=#666666]↑↓ Navigate | Enter to equip | 1-%d Quick select | ESC Cancel[/color]" % slots.size()
	tooltip_label.text = tooltip

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
	var tooltip = "[color=#99cc99][b]Select item to equip in %s:[/b][/color]\n\n" % slot_name
	
	for i in range(slot_selection_items.size()):
		var item = slot_selection_items[i]
		var marker = "► " if i == slot_selection_index else "  "
		# Highlight selected item in yellow
		if i == slot_selection_index:
			tooltip += "[color=#ffff99]%s%s[/color]\n" % [marker, item.name]
		else:
			tooltip += "%s[color=#%s]%s[/color]\n" % [marker, item.get_color().to_html(false), item.name]
	
	tooltip += "\n[color=#666666]↑↓ Navigate | Enter to equip | ESC to cancel[/color]"
	tooltip_label.text = tooltip

func _use_selected() -> void:
	if not player or not selected_item:
		return
	
	if selected_item.item_type == "consumable":
		player.use_item(selected_item)
		refresh()

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
		# Drop from inventory
		var ground_item = player.drop_item(selected_item)
		if ground_item:
			EntityManager.entities.append(ground_item)
	
	refresh()

func _action_selected() -> void:
	if not selected_item:
		return
	
	# Default action based on item type
	match selected_item.item_type:
		"consumable":
			_use_selected()
		"weapon", "armor", "tool":
			_equip_selected()
		_:
			pass  # No default action for materials
