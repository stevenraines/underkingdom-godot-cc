extends Control

## FastTravelScreen - UI for fast travel to visited locations
##
## Displays all visited towns and dungeons. Player can select a location
## and fast travel to it instantly.

signal closed

@onready var scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var content_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/ScrollMargin/ContentBox

# Colors matching character sheet
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1)
const COLOR_LABEL = Color(0.85, 0.85, 0.7)
const COLOR_SELECTED = Color(0.7, 0.9, 0.7)
const COLOR_UNSELECTED = Color(0.6, 0.6, 0.6)

var locations: Array = []  # Array of {id, data} dictionaries
var selected_index: int = 0

func _ready() -> void:
	hide()
	set_process_unhandled_input(false)

## Open the fast travel screen
func open() -> void:
	_populate_locations()
	_populate_content()
	show()
	set_process_unhandled_input(true)

## Close the fast travel screen
func close() -> void:
	hide()
	set_process_unhandled_input(false)
	closed.emit()

## Gather all visited locations from GameManager
func _populate_locations() -> void:
	locations.clear()
	selected_index = 0

	# Get towns
	var towns = GameManager.get_visited_locations_by_type("town")
	for town in towns:
		locations.append(town)

	# Get dungeons
	var dungeons = GameManager.get_visited_locations_by_type("dungeon")
	for dungeon in dungeons:
		locations.append(dungeon)

## Populate the content dynamically
func _populate_content() -> void:
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()

	# Wait a frame for nodes to be freed
	await get_tree().process_frame

	if locations.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No locations discovered yet."
		empty_label.add_theme_color_override("font_color", COLOR_UNSELECTED)
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_container.add_child(empty_label)
		return

	# Add towns section
	var towns = GameManager.get_visited_locations_by_type("town")
	if towns.size() > 0:
		_add_section_header("== TOWNS ==")
		for i in range(locations.size()):
			var loc = locations[i]
			if loc.data.type == "town":
				_add_location_line(i, loc.data.name)

	# Add spacer between sections
	if towns.size() > 0 and GameManager.get_visited_locations_by_type("dungeon").size() > 0:
		_add_spacer()

	# Add dungeons section
	var dungeons = GameManager.get_visited_locations_by_type("dungeon")
	if dungeons.size() > 0:
		_add_section_header("== DUNGEONS ==")
		for i in range(locations.size()):
			var loc = locations[i]
			if loc.data.type == "dungeon":
				_add_location_line(i, loc.data.name)

	# Update visual selection
	_update_selection_display()

## Add a section header
func _add_section_header(text: String) -> void:
	var header = Label.new()
	header.text = text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", COLOR_SECTION)
	header.add_theme_font_size_override("font_size", 15)
	content_container.add_child(header)

## Add a location line
func _add_location_line(index: int, location_name: String) -> void:
	var line = HBoxContainer.new()
	line.name = "Location_%d" % index

	# Selection indicator
	var indicator = Label.new()
	indicator.name = "Indicator"
	indicator.text = "  "  # Default: no selection
	indicator.custom_minimum_size.x = 24
	indicator.add_theme_font_size_override("font_size", 14)
	line.add_child(indicator)

	# Location name
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = location_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override("font_color", COLOR_LABEL)
	name_label.add_theme_font_size_override("font_size", 14)
	line.add_child(name_label)

	content_container.add_child(line)

## Add a spacer
func _add_spacer() -> void:
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 12
	content_container.add_child(spacer)

## Update the visual selection display
func _update_selection_display() -> void:
	for i in range(locations.size()):
		var line_node = content_container.get_node_or_null("Location_%d" % i)
		if line_node:
			var indicator = line_node.get_node_or_null("Indicator")
			var name_label = line_node.get_node_or_null("NameLabel")

			if i == selected_index:
				if indicator:
					indicator.text = "> "
					indicator.add_theme_color_override("font_color", COLOR_SELECTED)
				if name_label:
					name_label.add_theme_color_override("font_color", COLOR_SELECTED)
			else:
				if indicator:
					indicator.text = "  "
					indicator.add_theme_color_override("font_color", COLOR_LABEL)
				if name_label:
					name_label.add_theme_color_override("font_color", COLOR_LABEL)

## Move selection up
func _move_selection_up() -> void:
	if locations.size() == 0:
		return
	selected_index = (selected_index - 1 + locations.size()) % locations.size()
	_update_selection_display()

## Move selection down
func _move_selection_down() -> void:
	if locations.size() == 0:
		return
	selected_index = (selected_index + 1) % locations.size()
	_update_selection_display()

## Execute fast travel to selected location
func _travel_to_selected() -> void:
	if locations.size() == 0 or selected_index < 0 or selected_index >= locations.size():
		return

	var location = locations[selected_index]
	var location_data = location.data
	var target_pos = Vector2i(int(location_data.position.x), int(location_data.position.y))

	# Close screen first
	close()

	# Perform the travel
	_execute_fast_travel(target_pos, location_data.name)

## Execute the actual fast travel
func _execute_fast_travel(target_pos: Vector2i, location_name: String) -> void:
	var player = EntityManager.player
	if not player:
		return

	# If in dungeon, return to overworld first
	if MapManager.current_map.map_id != "overworld":
		MapManager.current_dungeon_floor = 0
		MapManager.current_dungeon_type = ""
		MapManager.transition_to_map("overworld")
		# Wait for map change to complete
		await EventBus.map_changed

	# Find a walkable tile near the target
	var final_pos = _find_walkable_near(target_pos)

	# Store old position for event
	var old_pos = player.position

	# Teleport player
	player.position = final_pos

	# Emit player moved event so rendering updates
	EventBus.player_moved.emit(old_pos, final_pos)

	# Log message
	EventBus.message_logged.emit("You fast travel to %s." % location_name)

## Find a walkable tile near the target position
func _find_walkable_near(target_pos: Vector2i) -> Vector2i:
	# First ensure the chunk is loaded
	if MapManager.current_map and MapManager.current_map.chunk_based:
		ChunkManager.update_active_chunks(target_pos)

	# Check the target position first
	if _is_walkable(target_pos):
		return target_pos

	# Search in expanding rings
	for radius in range(1, 10):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) == radius or abs(dy) == radius:  # Only check perimeter
					var check_pos = target_pos + Vector2i(dx, dy)
					if _is_walkable(check_pos):
						return check_pos

	# Fallback to target position
	return target_pos

## Check if a position is walkable
func _is_walkable(pos: Vector2i) -> bool:
	if MapManager.current_map.chunk_based:
		var tile = ChunkManager.get_tile(pos)
		return tile and tile.walkable
	else:
		return MapManager.current_map.is_walkable(pos)

## Handle input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var scroll_amount = 40

		if event.keycode == KEY_UP or event.keycode == KEY_W:
			_move_selection_up()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_move_selection_down()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_PAGEUP:
			scroll_container.scroll_vertical -= scroll_amount * 5
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_PAGEDOWN:
			scroll_container.scroll_vertical += scroll_amount * 5
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_travel_to_selected()
			get_viewport().set_input_as_handled()
		elif not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_F):
			close()
			get_viewport().set_input_as_handled()
