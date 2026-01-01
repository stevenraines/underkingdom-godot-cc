extends Control

## Minimap Screen - Pop-up map showing the entire island in miniature
##
## Displays the full overworld map with terrain, player position,
## and points of interest marked.

signal closed

# UI elements - created programmatically
var panel: Panel
var map_texture_rect: TextureRect
var legend_container: VBoxContainer

# Colors matching game theme
const COLOR_TITLE = Color(0.6, 0.9, 0.6, 1)
const COLOR_LEGEND = Color(0.7, 0.7, 0.7, 1)
const COLOR_FOOTER = Color(0.7, 0.7, 0.7, 1)
const COLOR_BORDER = Color(0.4, 0.6, 0.4, 1)

# Terrain colors for minimap
const TERRAIN_COLORS = {
	"floor": Color(0.3, 0.5, 0.3, 1),       # Green grass
	"tree": Color(0.15, 0.35, 0.15, 1),     # Dark green trees
	"water": Color(0.2, 0.4, 0.7, 1),       # Blue water
	"wall": Color(0.4, 0.35, 0.3, 1),       # Brown walls
	"rock": Color(0.5, 0.5, 0.5, 1),        # Gray rocks
	"stairs_down": Color(0.9, 0.7, 0.2, 1), # Gold dungeon entrance
	"door": Color(0.6, 0.4, 0.2, 1),        # Brown door
}

const COLOR_PLAYER = Color(1.0, 1.0, 1.0, 1)        # White player marker
const COLOR_NPC = Color(1.0, 0.8, 0.2, 1)           # Yellow NPCs
const COLOR_TOWN = Color(0.8, 0.6, 0.4, 1)          # Tan town area
const COLOR_UNEXPLORED = Color(0.1, 0.1, 0.1, 1)   # Dark unexplored

# Map dimensions
var map_pixel_size = Vector2i(400, 400)  # Size of the rendered minimap

func _ready() -> void:
	_build_ui()
	hide()
	set_process_unhandled_input(false)

## Build the UI programmatically
func _build_ui() -> void:
	# Make this control fill the screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size

	# Dimmer background
	var dimmer = ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.8)
	add_child(dimmer)

	# Main panel - centered, sized for map + legend
	panel = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_top = -280
	panel.offset_right = 280
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
	title.text = "◆ ISLAND MAP ◆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Separator
	var sep1 = HSeparator.new()
	sep1.add_theme_constant_override("separation", 4)
	vbox.add_child(sep1)

	# HBox for map and legend
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	# Map container with border
	var map_container = PanelContainer.new()
	var map_style = StyleBoxFlat.new()
	map_style.bg_color = Color(0.05, 0.05, 0.08, 1)
	map_style.border_width_left = 1
	map_style.border_width_top = 1
	map_style.border_width_right = 1
	map_style.border_width_bottom = 1
	map_style.border_color = Color(0.3, 0.4, 0.3, 1)
	map_container.add_theme_stylebox_override("panel", map_style)
	hbox.add_child(map_container)

	# Texture rect for the map image
	map_texture_rect = TextureRect.new()
	map_texture_rect.custom_minimum_size = Vector2(map_pixel_size)
	map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_container.add_child(map_texture_rect)

	# Legend container
	legend_container = VBoxContainer.new()
	legend_container.custom_minimum_size.x = 100
	legend_container.add_theme_constant_override("separation", 4)
	hbox.add_child(legend_container)

	_build_legend()

	# Separator
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 4)
	vbox.add_child(sep2)

	# Footer
	var footer = Label.new()
	footer.text = "[M] [Esc] Close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", COLOR_FOOTER)
	footer.add_theme_font_size_override("font_size", 13)
	vbox.add_child(footer)

## Build the legend
func _build_legend() -> void:
	var legend_title = Label.new()
	legend_title.text = "Legend:"
	legend_title.add_theme_color_override("font_color", COLOR_TITLE)
	legend_title.add_theme_font_size_override("font_size", 14)
	legend_container.add_child(legend_title)

	_add_legend_item("@ You", COLOR_PLAYER)
	_add_legend_item("♦ Dungeon", TERRAIN_COLORS["stairs_down"])
	_add_legend_item("@ NPCs", COLOR_NPC)
	_add_legend_item("■ Town", COLOR_TOWN)
	_add_legend_item("♠ Forest", TERRAIN_COLORS["tree"])
	_add_legend_item("≈ Water", TERRAIN_COLORS["water"])
	_add_legend_item("● Rocks", TERRAIN_COLORS["rock"])

## Add a legend item
func _add_legend_item(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 12)
	legend_container.add_child(label)

## Open the minimap screen
func open() -> void:
	_render_map()
	show()
	set_process_unhandled_input(true)

## Close the minimap screen
func close() -> void:
	hide()
	set_process_unhandled_input(false)
	closed.emit()

## Handle input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			close()
			get_viewport().set_input_as_handled()

## Render the current map to an image
func _render_map() -> void:
	var current_map = MapManager.current_map
	if not current_map:
		return

	# Only show minimap for overworld
	if current_map.map_id != "overworld":
		_show_dungeon_message()
		return

	# Create image at map size, then scale
	var img = Image.create(current_map.width, current_map.height, false, Image.FORMAT_RGBA8)

	# Get player position
	var player_pos = Vector2i(-1, -1)
	for entity in EntityManager.entities:
		if entity is Player:
			player_pos = entity.position
			break

	# Get town bounds if available
	var town_rect = Rect2i()
	if current_map.has_meta("town_center"):
		var town_center = current_map.get_meta("town_center")
		town_rect = Rect2i(town_center, Vector2i(20, 15))  # Match town size

	# Render each tile
	for y in range(current_map.height):
		for x in range(current_map.width):
			var pos = Vector2i(x, y)
			var tile = current_map.get_tile(pos)
			var color = TERRAIN_COLORS.get(tile.tile_type, COLOR_UNEXPLORED)

			# Highlight town area
			if town_rect.has_point(pos):
				color = color.lerp(COLOR_TOWN, 0.3)

			img.set_pixel(x, y, color)

	# Mark NPCs
	for entity in EntityManager.entities:
		if entity.entity_type == "npc" and entity.position.x >= 0 and entity.position.y >= 0:
			if entity.position.x < current_map.width and entity.position.y < current_map.height:
				# Draw a 3x3 marker for visibility
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						var px = clampi(entity.position.x + dx, 0, current_map.width - 1)
						var py = clampi(entity.position.y + dy, 0, current_map.height - 1)
						img.set_pixel(px, py, COLOR_NPC)

	# Mark player position (larger marker)
	if player_pos.x >= 0 and player_pos.y >= 0:
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var px = clampi(player_pos.x + dx, 0, current_map.width - 1)
				var py = clampi(player_pos.y + dy, 0, current_map.height - 1)
				# Create a cross pattern for player
				if abs(dx) + abs(dy) <= 2:
					img.set_pixel(px, py, COLOR_PLAYER)

	# Create texture from image
	var texture = ImageTexture.create_from_image(img)
	map_texture_rect.texture = texture

## Show message when in dungeon
func _show_dungeon_message() -> void:
	# Create a simple "no map available" image
	var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_UNEXPLORED)

	var texture = ImageTexture.create_from_image(img)
	map_texture_rect.texture = texture
