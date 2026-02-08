extends Control

## SpellItemSelectionDialog - Dialog for selecting items as targets for spells
##
## Used when casting spells like Identify, Remove Curse, etc. that target items.
## Filters items based on the spell's requirements and shows only valid targets.

signal item_selected(item: Item)
signal cancelled()

@onready var title_label: Label = $Panel/MarginContainer/MainVBox/TitleLabel
@onready var item_list: VBoxContainer = $Panel/MarginContainer/MainVBox/ContentHBox/ItemPanel/ScrollContainer/ItemList
@onready var item_scroll: ScrollContainer = $Panel/MarginContainer/MainVBox/ContentHBox/ItemPanel/ScrollContainer
@onready var description_label: Label = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/DescriptionLabel
@onready var stats_label: Label = $Panel/MarginContainer/MainVBox/ContentHBox/InfoPanel/InfoVBox/StatsLabel
@onready var instruction_label: Label = $Panel/MarginContainer/MainVBox/InstructionLabel

var player: Player = null
var spell = null
var targeting_mode: String = ""
var filtered_items: Array[Item] = []
var selected_index: int = 0

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				_navigate(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_navigate(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE, KEY_E:
				_confirm_selection()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_cancel()
				get_viewport().set_input_as_handled()

## Open the dialog for a specific spell and player
func open(p: Player, target_spell, mode: String) -> void:
	player = p
	spell = target_spell
	targeting_mode = mode

	# Set title based on spell
	var spell_name = spell.name if spell and "name" in spell else "spell"
	title_label.text = "Select Item for %s" % spell_name
	title_label.add_theme_color_override("font_color", UITheme.COLOR_SECTION)

	# Filter items based on spell
	filtered_items = _filter_items_for_spell()

	# Populate the list
	selected_index = 0
	_populate_item_list()
	_update_selection()

	show()

## Filter items based on the spell being cast
func _filter_items_for_spell() -> Array[Item]:
	var valid_items: Array[Item] = []

	if not player or not player.inventory:
		return valid_items

	var all_items: Array[Item] = []

	# Get items based on targeting mode
	match targeting_mode:
		"inventory":
			all_items = player.inventory.get_all_items()
		"equipped_item":
			# Get all equipped items
			var equipment = player.inventory.equipment
			for slot in equipment:
				var item = equipment[slot]
				if item:
					all_items.append(item)

	# Filter based on spell
	if not spell or not "id" in spell:
		return all_items

	match spell.id:
		"identify":
			# Identify spell targets unidentified items or items with hidden curses
			for item in all_items:
				# Show magical items (potions, scrolls, rings, wands, enchanted equipment)
				var is_magical = item.flags.get("magical", false)
				var is_unidentified = item.unidentified
				var has_hidden_curse = item.is_cursed and not item.curse_revealed

				if is_magical or is_unidentified or has_hidden_curse:
					valid_items.append(item)
		"remove_curse":
			# Remove Curse targets equipped cursed items
			for item in all_items:
				if item.is_cursed:
					valid_items.append(item)
		_:
			# Default: show all items
			valid_items = all_items

	return valid_items

## Populate the item list display
func _populate_item_list() -> void:
	# Clear existing
	for child in item_list.get_children():
		item_list.remove_child(child)
		child.queue_free()

	if filtered_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "  No valid items found"
		empty_label.add_theme_color_override("font_color", UITheme.COLOR_EMPTY)
		empty_label.add_theme_font_size_override("font_size", 13)
		item_list.add_child(empty_label)

		# Update instruction
		instruction_label.text = "No valid targets. Press ESC to cancel."
		instruction_label.add_theme_color_override("font_color", UITheme.COLOR_ERROR)
		return

	# Add items
	for item in filtered_items:
		var row = _create_item_row(item)
		item_list.add_child(row)

	# Update instruction
	instruction_label.text = "↑↓ Navigate  |  Enter/E to select  |  ESC to cancel"
	instruction_label.add_theme_color_override("font_color", UITheme.COLOR_LABEL)

## Create a row for displaying an item
func _create_item_row(item: Item) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	var icon = Label.new()
	icon.name = "Icon"
	icon.text = item.ascii_char
	icon.custom_minimum_size = Vector2(20, 0)
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", item.get_color())
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(icon)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = item.get_display_name()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", item.get_color())
	container.add_child(name_label)

	# Show unidentified indicator
	if item.unidentified:
		var unid_label = Label.new()
		unid_label.text = "(?)"
		unid_label.add_theme_font_size_override("font_size", 12)
		unid_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
		container.add_child(unid_label)

	# Show cursed indicator (if revealed)
	if item.is_cursed and item.curse_revealed:
		var curse_label = Label.new()
		curse_label.text = "[CURSED]"
		curse_label.add_theme_font_size_override("font_size", 12)
		curse_label.add_theme_color_override("font_color", UITheme.COLOR_ERROR)
		container.add_child(curse_label)

	return container

## Navigate the item list
func _navigate(direction: int) -> void:
	if filtered_items.is_empty():
		return

	selected_index = clampi(selected_index + direction, 0, filtered_items.size() - 1)
	_update_selection()

## Update the selection highlight and info panel
func _update_selection() -> void:
	# Update highlights
	var children = item_list.get_children()
	for i in range(children.size()):
		var child = children[i]
		if child is HBoxContainer:
			var name_node = child.get_node_or_null("Name")
			if name_node and name_node is Label:
				if i == selected_index:
					name_node.text = "► " + name_node.text.trim_prefix("► ")
					name_node.add_theme_color_override("font_color", UITheme.COLOR_HIGHLIGHT)
				else:
					name_node.text = name_node.text.trim_prefix("► ")
					# Restore original color
					if i < filtered_items.size():
						var item = filtered_items[i]
						name_node.add_theme_color_override("font_color", item.get_color())

	# Scroll to selected item
	if selected_index < children.size():
		var selected_row = children[selected_index]
		item_scroll.ensure_control_visible(selected_row)

	# Update info panel
	_update_info_panel()

## Update the info panel with selected item details
func _update_info_panel() -> void:
	if filtered_items.is_empty() or selected_index >= filtered_items.size():
		description_label.text = "No item selected"
		description_label.add_theme_color_override("font_color", UITheme.COLOR_EMPTY)
		stats_label.text = ""
		return

	var item = filtered_items[selected_index]

	# Description
	var desc = item.description
	if item.is_cursed and item.curse_revealed:
		desc += "\n\n[!] CURSED - Cannot be unequipped!"
	description_label.text = desc
	description_label.add_theme_color_override("font_color", UITheme.COLOR_LABEL)

	# Stats
	var stats: Array[String] = []

	match item.item_type:
		"consumable":
			if item.effects.has("health") and item.effects["health"] > 0:
				stats.append("♥ Heals: %d HP" % item.effects["health"])
			if item.casts_spell != "":
				var scroll_spell = SpellManager.get_spell(item.casts_spell)
				if scroll_spell:
					stats.append("✦ Casts: %s" % scroll_spell.name)
		"weapon", "tool":
			if item.damage_min > 0 and item.damage_max > 0:
				stats.append("⚔ Damage: %d-%d" % [item.damage_min, item.damage_max])
			if item.casts_spell != "" and item.max_charges > 0:
				var wand_spell = SpellManager.get_spell(item.casts_spell)
				if wand_spell:
					stats.append("✦ Casts: %s" % wand_spell.name)
				stats.append("⚡ Charges: %d/%d" % [item.charges, item.max_charges])
		"armor":
			if item.armor_value > 0:
				stats.append("◈ Armor: %d" % item.armor_value)

	stats.append("Weight: %.1f kg" % item.weight)
	stats.append("Value: %d gold" % item.value)

	stats_label.text = "\n".join(stats)
	stats_label.add_theme_color_override("font_color", UITheme.COLOR_VALUE)

## Confirm the selection
func _confirm_selection() -> void:
	if filtered_items.is_empty() or selected_index >= filtered_items.size():
		return

	var selected_item = filtered_items[selected_index]
	hide()
	item_selected.emit(selected_item)

## Cancel the dialog
func _cancel() -> void:
	hide()
	cancelled.emit()
