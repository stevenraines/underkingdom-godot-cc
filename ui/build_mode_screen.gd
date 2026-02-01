extends Control

## BuildModeScreen - UI for selecting and placing structures
##
## Shows available structures with build requirements and costs.

signal closed()
signal structure_selected(structure_id: String)

@onready var structure_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/StructuresPanel/StructureList
@onready var detail_panel: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ContentContainer/DetailsPanel/DetailScroll/DetailLabel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var structures_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/StructuresPanel/StructuresTitle
@onready var details_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/DetailsPanel/DetailsTitle

var player: Player = null
var selected_index: int = 0
var structure_rows: Array[Control] = []

# Available structures
const STRUCTURES = ["campfire", "lean_to", "chest"]

# Colors from UITheme autoload

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_B:
				_close()
				get_viewport().set_input_as_handled()
			KEY_UP:
				_navigate(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_navigate(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				_select_structure()
				get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3:
				var index = event.keycode - KEY_1
				if index >= 0 and index < STRUCTURES.size():
					selected_index = index
					_select_structure()
				get_viewport().set_input_as_handled()

func open(p_player: Player) -> void:
	player = p_player
	_refresh_display()
	show()
	get_tree().paused = true

func _close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()

func _navigate(direction: int) -> void:
	selected_index = clampi(selected_index + direction, 0, STRUCTURES.size() - 1)
	_update_selection()

func _select_structure() -> void:
	if selected_index >= 0 and selected_index < STRUCTURES.size():
		var structure_id = STRUCTURES[selected_index]

		# Check if player can afford it
		var can_afford_result = _get_missing_requirements(structure_id)
		if can_afford_result["can_afford"]:
			structure_selected.emit(structure_id)
			_close()
		else:
			# Update detail panel to show error
			_update_detail_panel()

func _get_missing_requirements(structure_id: String) -> Dictionary:
	"""
	Check what materials and tools the player is missing.
	Returns: {"can_afford": bool, "missing": String}
	"""
	if not StructureManager.structure_definitions.has(structure_id):
		return {"can_afford": false, "missing": "Unknown structure"}

	var data = StructureManager.structure_definitions[structure_id]
	var build_reqs = data.get("build_requirements", [])
	var missing_items: Array[String] = []

	# Check materials
	for req in build_reqs:
		var item_id = req.get("item", "")
		var count = req.get("count", 1)
		var has = player.inventory.get_item_count(item_id)
		if has < count:
			var needed = count - has
			missing_items.append("%s x%d" % [item_id, needed])

	# Check tool
	var build_tool = data.get("build_tool", "")
	if build_tool != "":
		var has_tool = false
		for item in player.inventory.items:
			if item.item_type == "tool" and item.subtype == build_tool:
				has_tool = true
				break
		if not has_tool:
			for slot in player.inventory.equipment:
				var equipped = player.inventory.equipment[slot]
				if equipped and equipped.item_type == "tool" and equipped.subtype == build_tool:
					has_tool = true
					break
		if not has_tool and player.inventory.get_item_count(build_tool) > 0:
			has_tool = true
		if not has_tool:
			missing_items.append("[Tool: %s]" % build_tool)

	if missing_items.is_empty():
		return {"can_afford": true, "missing": ""}
	else:
		return {"can_afford": false, "missing": ", ".join(missing_items)}

func _can_afford(structure_id: String) -> bool:
	var result = _get_missing_requirements(structure_id)
	return result["can_afford"]

func _refresh_display() -> void:
	# Clear existing rows
	for row in structure_rows:
		row.queue_free()
	structure_rows.clear()

	# Create row for each structure
	for i in range(STRUCTURES.size()):
		var structure_id = STRUCTURES[i]
		if not StructureManager.structure_definitions.has(structure_id):
			continue

		var data = StructureManager.structure_definitions[structure_id]
		var row = _create_structure_row(data)
		structure_list.add_child(row)
		structure_rows.append(row)

	_update_selection()

## Create a row for a structure
func _create_structure_row(data: Dictionary) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)

	var icon = Label.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(20, 0)
	icon.add_theme_font_size_override("font_size", 14)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.text = data.get("ascii_char", "?")
	var color_str = data.get("ascii_color", "#FFFFFF")
	icon.add_theme_color_override("font_color", Color(color_str))
	container.add_child(icon)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.text = data.get("name", "Unknown")
	name_label.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)
	container.add_child(name_label)

	return container

func _update_selection() -> void:
	# Reset all highlights
	for i in range(structure_rows.size()):
		var row = structure_rows[i]
		_set_row_highlight(row, i == selected_index)

	# Update detail panel
	_update_detail_panel()

## Set highlight state for a row
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

func _update_detail_panel() -> void:
	if selected_index < 0 or selected_index >= STRUCTURES.size():
		detail_panel.text = ""
		return

	var structure_id = STRUCTURES[selected_index]
	if not StructureManager.structure_definitions.has(structure_id):
		detail_panel.text = "[color=#ff8888]Unknown structure[/color]"
		return

	var data = StructureManager.structure_definitions[structure_id]
	var can_afford_result = _get_missing_requirements(structure_id)

	# Build the detail text
	var text = "[color=#%s][b]%s[/b][/color]\n" % [data.get("ascii_color", "#FFFFFF").trim_prefix("#"), data.get("name", "Unknown")]
	text += "[color=#888888]%s[/color]\n\n" % data.get("description", "No description available.")

	# Show what it does
	text += "[color=#9acc9a][b]Effects:[/b][/color]\n"
	var components = data.get("components", {})
	if components.has("fire"):
		var fire = components["fire"]
		text += "  [color=#ffaa66]⚬ Warmth:[/color] +%d°C within %d tiles\n" % [fire.get("temperature_bonus", 0), fire.get("heat_radius", 0)]
		text += "  [color=#ffdd88]⚬ Light:[/color] %d tiles radius\n" % fire.get("light_radius", 0)
		text += "  [color=#ff8844]⚬ Can cook food[/color]\n"
	if components.has("shelter"):
		var shelter = components["shelter"]
		text += "  [color=#aaddff]⚬ Shelter:[/color] %d tiles radius\n" % shelter.get("shelter_radius", 0)
		text += "  [color=#88ccff]⚬ Warmth:[/color] +%d°C\n" % shelter.get("temperature_bonus", 0)
		if shelter.get("blocks_rain", false):
			text += "  [color=#66aaff]⚬ Blocks rain[/color]\n"
	if components.has("container"):
		var container = components["container"]
		text += "  [color=#ddaa66]⚬ Storage:[/color] %.0f kg capacity\n" % container.get("max_weight", 0)

	text += "\n[color=#9acc9a][b]Requirements:[/b][/color]\n"

	# Materials
	var build_reqs = data.get("build_requirements", [])
	for req in build_reqs:
		var item_id = req.get("item", "")
		var count = req.get("count", 1)
		var has = player.inventory.get_item_count(item_id)
		var has_enough = has >= count
		var color = "#88ff88" if has_enough else "#ff8888"
		text += "  [color=%s]%s: %d/%d[/color]\n" % [color, item_id.capitalize(), has, count]

	# Tool
	var build_tool = data.get("build_tool", "")
	if build_tool != "":
		var has_tool = false
		for item in player.inventory.items:
			if item.item_type == "tool" and item.subtype == build_tool:
				has_tool = true
				break
		if not has_tool:
			for slot in player.inventory.equipment:
				var equipped = player.inventory.equipment[slot]
				if equipped and equipped.item_type == "tool" and equipped.subtype == build_tool:
					has_tool = true
					break
		var color = "#88ff88" if has_tool else "#ff8888"
		text += "  [color=%s]Tool: %s[/color]\n" % [color, build_tool.capitalize()]

	# Can afford?
	if can_afford_result["can_afford"]:
		text += "\n[color=#88ff88][Enter] Build this structure[/color]"
	else:
		text += "\n[color=#ff8888]Missing: %s[/color]" % can_afford_result["missing"]

	text += "\n[color=#cc9999][Esc] Cancel[/color]"

	detail_panel.text = text
