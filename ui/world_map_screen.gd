extends Control

## WorldMapScreen - Shows an overview map of the island
##
## Displays a scaled-down view of the world using colored pixels.
## Shows: town, player position, all dungeon entrances.

signal closed

const CELL_SIZE: int = 2  # Each pixel represents 2x2 tiles (more detail)
const MAP_DISPLAY_SIZE: int = 400  # Size of the map display in pixels

var map_image: Image
var map_texture: ImageTexture
var is_open: bool = false

@onready var map_rect: TextureRect = $Panel/VBoxContainer/MapContainer/MapRect
@onready var legend_container: VBoxContainer = $Panel/VBoxContainer/LegendContainer

func _ready() -> void:
	visible = false


func open() -> void:
	visible = true
	is_open = true
	_generate_map_image()
	_populate_legend()


func close() -> void:
	visible = false
	is_open = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			close()
			get_viewport().set_input_as_handled()


func _generate_map_image() -> void:
	if not MapManager.current_map:
		return

	# Create a new image for the map
	map_image = Image.create(MAP_DISPLAY_SIZE, MAP_DISPLAY_SIZE, false, Image.FORMAT_RGBA8)
	map_image.fill(Color(0.1, 0.1, 0.15, 1.0))  # Dark background

	# Get special feature positions
	var town_pos = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	var player_pos = EntityManager.player.position if EntityManager.player else Vector2i(-1, -1)
	var dungeon_entrances: Array = MapManager.current_map.get_meta("dungeon_entrances", [])

	# Calculate the center of our view (centered on player or town)
	var center_pos = player_pos if player_pos != Vector2i(-1, -1) else town_pos
	if center_pos == Vector2i(-1, -1):
		center_pos = Vector2i(MAP_DISPLAY_SIZE * CELL_SIZE / 2, MAP_DISPLAY_SIZE * CELL_SIZE / 2)

	# Calculate world bounds we're displaying
	var half_world_size = (MAP_DISPLAY_SIZE * CELL_SIZE) / 2
	var world_min = center_pos - Vector2i(half_world_size, half_world_size)

	# Draw biome colors
	for py in range(MAP_DISPLAY_SIZE):
		for px in range(MAP_DISPLAY_SIZE):
			var world_x = world_min.x + px * CELL_SIZE
			var world_y = world_min.y + py * CELL_SIZE

			# Get biome at this position
			var biome = BiomeGenerator.get_biome_at(world_x, world_y, GameManager.world_seed)
			var color = _get_biome_map_color(biome.biome_name)
			map_image.set_pixel(px, py, color)

	# Draw town (as a larger marker)
	if town_pos != Vector2i(-1, -1):
		var town_px = _world_to_map_pixel(town_pos, world_min)
		_draw_marker(town_px, Color(1.0, 0.9, 0.5), 3)  # Yellow marker for town

	# Draw dungeon entrances
	for entrance in dungeon_entrances:
		var entrance_pos = entrance.position
		var entrance_px = _world_to_map_pixel(entrance_pos, world_min)
		var color = Color.html(entrance.entrance_color)
		_draw_marker(entrance_px, color, 2)

	# Draw player (on top)
	if player_pos != Vector2i(-1, -1):
		var player_px = _world_to_map_pixel(player_pos, world_min)
		_draw_marker(player_px, Color.YELLOW, 2)
		# Add a white border around player
		_draw_marker_outline(player_px, Color.WHITE, 2)

	# Create texture from image
	map_texture = ImageTexture.create_from_image(map_image)
	map_rect.texture = map_texture


func _world_to_map_pixel(world_pos: Vector2i, world_min: Vector2i) -> Vector2i:
	var relative = world_pos - world_min
	return Vector2i(relative.x / CELL_SIZE, relative.y / CELL_SIZE)


func _draw_marker(center: Vector2i, color: Color, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var px = center.x + dx
			var py = center.y + dy
			if px >= 0 and px < MAP_DISPLAY_SIZE and py >= 0 and py < MAP_DISPLAY_SIZE:
				if dx * dx + dy * dy <= radius * radius:
					map_image.set_pixel(px, py, color)


func _draw_marker_outline(center: Vector2i, color: Color, radius: int) -> void:
	var outer_radius = radius + 1
	for dy in range(-outer_radius, outer_radius + 1):
		for dx in range(-outer_radius, outer_radius + 1):
			var dist_sq = dx * dx + dy * dy
			if dist_sq > radius * radius and dist_sq <= outer_radius * outer_radius:
				var px = center.x + dx
				var py = center.y + dy
				if px >= 0 and px < MAP_DISPLAY_SIZE and py >= 0 and py < MAP_DISPLAY_SIZE:
					map_image.set_pixel(px, py, color)


func _get_biome_map_color(biome_name: String) -> Color:
	match biome_name:
		"ocean", "deep_ocean":
			return Color(0.1, 0.2, 0.5)
		"beach":
			return Color(0.9, 0.85, 0.6)
		"grassland":
			return Color(0.4, 0.7, 0.3)
		"woodland":
			return Color(0.2, 0.5, 0.2)
		"forest":
			return Color(0.1, 0.4, 0.15)
		"rainforest":
			return Color(0.05, 0.35, 0.1)
		"swamp", "marsh":
			return Color(0.3, 0.4, 0.25)
		"mountains":
			return Color(0.5, 0.5, 0.5)
		"snow_mountains":
			return Color(0.85, 0.85, 0.9)
		"snow", "tundra":
			return Color(0.9, 0.95, 1.0)
		"rocky_hills":
			return Color(0.45, 0.4, 0.35)
		"barren_rock":
			return Color(0.35, 0.3, 0.25)
		_:
			return Color(0.3, 0.5, 0.3)


func _populate_legend() -> void:
	# Clear existing legend items
	for child in legend_container.get_children():
		child.queue_free()

	# Add legend items
	_add_legend_item(Color.YELLOW, "You (Player)")
	_add_legend_item(Color(1.0, 0.9, 0.5), "Town")

	# Add dungeon entrances to legend
	var dungeon_entrances: Array = MapManager.current_map.get_meta("dungeon_entrances", []) if MapManager.current_map else []
	for entrance in dungeon_entrances:
		var color = Color.html(entrance.entrance_color)
		_add_legend_item(color, entrance.name)


func _add_legend_item(color: Color, text: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(12, 12)
	color_rect.color = color
	hbox.add_child(color_rect)

	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(label)

	legend_container.add_child(hbox)
