extends Control

## BuildModeScreen - UI for selecting and placing structures
##
## Shows available structures with build requirements and costs.

signal closed()
signal structure_selected(structure_id: String)

@onready var structure_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/StructureList
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var help_label: Label = $Panel/MarginContainer/VBoxContainer/HelpLabel

var player: Player = null
var selected_index: int = 0
var structure_buttons: Array[Button] = []

# Available structures
const STRUCTURES = ["campfire", "lean_to", "chest"]

# Colors
const COLOR_AFFORDABLE = Color(0.7, 0.9, 0.7, 1.0)
const COLOR_EXPENSIVE = Color(0.9, 0.5, 0.5, 1.0)
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)

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
	selected_index = (selected_index + direction) % STRUCTURES.size()
	if selected_index < 0:
		selected_index = STRUCTURES.size() - 1
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
			# Show what's missing
			var structure_name = StructureManager.structure_definitions[structure_id].get("name", structure_id)
			help_label.text = "Cannot build %s! Missing: %s" % [structure_name, can_afford_result["missing"]]
			help_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))

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
	# Clear existing buttons
	for button in structure_buttons:
		button.queue_free()
	structure_buttons.clear()

	# Create button for each structure
	for i in range(STRUCTURES.size()):
		var structure_id = STRUCTURES[i]
		if not StructureManager.structure_definitions.has(structure_id):
			continue

		var data = StructureManager.structure_definitions[structure_id]
		var button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Build button text
		var text = "[%d] %s" % [i + 1, data.get("name", structure_id)]

		# Add requirements
		var build_reqs = data.get("build_requirements", [])
		var req_text = ""
		for req in build_reqs:
			var item_id = req.get("item", "")
			var count = req.get("count", 1)
			var has = player.inventory.get_item_count(item_id)
			req_text += "  %s x%d (%d)" % [item_id, count, has]

		var build_tool = data.get("build_tool", "")
		if build_tool != "":
			req_text += "  [Tool: %s]" % build_tool

		text += "\n" + req_text

		button.text = text

		# Color based on affordability
		var affordable = _can_afford(structure_id)
		if affordable:
			button.modulate = COLOR_AFFORDABLE
		else:
			button.modulate = COLOR_EXPENSIVE

		button.pressed.connect(func(): _on_button_pressed(i))

		structure_list.add_child(button)
		structure_buttons.append(button)

	_update_selection()

func _update_selection() -> void:
	for i in range(structure_buttons.size()):
		if i == selected_index:
			structure_buttons[i].modulate = COLOR_SELECTED
		else:
			var structure_id = STRUCTURES[i]
			if _can_afford(structure_id):
				structure_buttons[i].modulate = COLOR_AFFORDABLE
			else:
				structure_buttons[i].modulate = COLOR_EXPENSIVE

func _on_button_pressed(index: int) -> void:
	selected_index = index
	_select_structure()
