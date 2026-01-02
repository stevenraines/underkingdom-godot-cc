extends Control

## WorldMapScreen - Shows an overview map of the island
##
## Displays a scaled-down view of the world using colored pixels.
## Shows: town, player position, all dungeon entrances.

signal closed

# Fixed image size for performance - texture will be scaled to fit container
const MAP_IMAGE_SIZE: int = 400  # 400x400 pixels for the generated image

var map_image: Image
var map_texture: ImageTexture
var is_open: bool = false

# Island dimensions (will be read from config)
var island_width_tiles: int = 1600
var island_height_tiles: int = 1600

@onready var map_rect: TextureRect = $Panel/MarginContainer/VBoxContainer/ContentHBox/MapContainer/MapRect
@onready var map_container: AspectRatioContainer = $Panel/MarginContainer/VBoxContainer/ContentHBox/MapContainer
@onready var legend_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentHBox/SidebarPanel/SidebarMargin/SidebarVBox/LegendContainer

func _ready() -> void:
	visible = false
	# Get island dimensions from config
	var island_settings = BiomeManager.get_island_settings()
	var chunk_size = 32
	island_width_tiles = island_settings.get("width_chunks", 50) * chunk_size
	island_height_tiles = island_settings.get("height_chunks", 50) * chunk_size


func open() -> void:
	visible = true
	is_open = true
	# Wait a frame for layout to calculate container sizes
	await get_tree().process_frame
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

	# Create a fixed-size image (will be scaled by TextureRect)
	map_image = Image.create(MAP_IMAGE_SIZE, MAP_IMAGE_SIZE, false, Image.FORMAT_RGBA8)
	map_image.fill(Color(0.1, 0.2, 0.4, 1.0))  # Ocean blue background

	# Calculate how many world tiles each pixel represents
	var tiles_per_pixel: float = float(island_width_tiles) / float(MAP_IMAGE_SIZE)

	# Get special feature positions
	var town_pos = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	var player_pos = EntityManager.player.position if EntityManager.player else Vector2i(-1, -1)
	var dungeon_entrances: Array = MapManager.current_map.get_meta("dungeon_entrances", [])

	# Draw biome colors for entire island
	for py in range(MAP_IMAGE_SIZE):
		for px in range(MAP_IMAGE_SIZE):
			# Convert pixel to world coordinates
			var world_x = int(px * tiles_per_pixel)
			var world_y = int(py * tiles_per_pixel)

			# Get biome at this position
			var biome = BiomeGenerator.get_biome_at(world_x, world_y, GameManager.world_seed)
			var color = _get_biome_map_color(biome.biome_name)
			map_image.set_pixel(px, py, color)

	# Draw town (as a larger marker)
	if town_pos != Vector2i(-1, -1):
		var town_px = _world_to_map_pixel(town_pos, tiles_per_pixel)
		_draw_marker(town_px, Color(1.0, 0.9, 0.5), 4)  # Yellow marker for town

	# Draw dungeon entrances
	for entrance in dungeon_entrances:
		var entrance_pos = entrance.position
		var entrance_px = _world_to_map_pixel(entrance_pos, tiles_per_pixel)
		var color = Color.html(entrance.entrance_color)
		_draw_marker(entrance_px, color, 3)

	# Draw player (on top)
	if player_pos != Vector2i(-1, -1):
		var player_px = _world_to_map_pixel(player_pos, tiles_per_pixel)
		_draw_marker(player_px, Color.WHITE, 3)
		_draw_marker(player_px, Color.YELLOW, 2)

	# Create texture from image
	map_texture = ImageTexture.create_from_image(map_image)
	map_rect.texture = map_texture


func _world_to_map_pixel(world_pos: Vector2i, tiles_per_pixel: float) -> Vector2i:
	return Vector2i(int(world_pos.x / tiles_per_pixel), int(world_pos.y / tiles_per_pixel))


func _draw_marker(center: Vector2i, color: Color, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var px = center.x + dx
			var py = center.y + dy
			if px >= 0 and px < MAP_IMAGE_SIZE and py >= 0 and py < MAP_IMAGE_SIZE:
				if dx * dx + dy * dy <= radius * radius:
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
