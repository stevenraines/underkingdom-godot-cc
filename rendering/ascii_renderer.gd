class_name ASCIIRenderer
extends RenderInterface

## ASCIIRenderer - ASCII-based renderer using TileMapLayer
##
## Renders the game world using ASCII characters.
## Uses two TileMapLayer nodes: one for terrain, one for entities.

const TILE_SIZE = 48

# Child nodes (set in scene or _ready)
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var entity_layer: TileMapLayer = $EntityLayer
@onready var camera: Camera2D = $Camera

# Tile ID mappings (char -> atlas coordinates)
# ASCII characters 32-126 are laid out in a 16-column grid
# To get tile coordinates from char: col = (char_code - 32) % 16, row = (char_code - 32) / 16
var tile_map: Dictionary = {
	"@": 32,   # Player (ASCII 64)
	".": 14,   # Floor (ASCII 46)
	"#": 3,    # Wall (ASCII 35)
	"+": 11,   # Door (ASCII 43)
	">": 30,   # Stairs down (ASCII 62)
	"<": 28,   # Stairs up (ASCII 60)
	"T": 52,   # Tree (ASCII 84)
	"~": 62,   # Water (ASCII 126)
	"r": 82,   # Grave Rat (ASCII 114)
	"W": 55,   # Barrow Wight (ASCII 87)
	"w": 87,   # Woodland Wolf (ASCII 119)
}

# Color mapping for tiles
var tile_colors: Dictionary = {
	"@": Color(1.0, 1.0, 0.0),          # Yellow - Player
	".": Color(0.31, 0.31, 0.31),      # Dark Gray - Floor (80/255)
	"#": Color(0.78, 0.78, 0.78),      # Light Gray - Wall (200/255)
	"+": Color(0.6, 0.4, 0.2),         # Brown - Door
	">": Color(0.0, 1.0, 1.0),         # Cyan - Stairs down
	"<": Color(0.0, 1.0, 1.0),         # Cyan - Stairs up
	"T": Color(0.0, 0.71, 0.0),        # Green - Tree (180/255)
	"~": Color(0.2, 0.4, 1.0),         # Blue - Water
	"r": Color(0.55, 0.27, 0.07),      # Brown - Grave Rat
	"W": Color(0.27, 1.0, 0.27),       # Green - Barrow Wight
	"w": Color(0.63, 0.63, 0.63),      # Gray - Woodland Wolf
}

var visible_tiles: Array[Vector2i] = []

func _ready() -> void:
	_setup_tilemap_layers()
	print("ASCIIRenderer initialized")

## Setup TileMapLayer nodes with tileset
func _setup_tilemap_layers() -> void:
	# Create tileset if not set
	if terrain_layer and not terrain_layer.tile_set:
		terrain_layer.tile_set = _create_ascii_tileset()
	if entity_layer and not entity_layer.tile_set:
		entity_layer.tile_set = _create_ascii_tileset()

	# Set camera zoom for better visibility
	# With 48px tiles (3x larger than original 16px), use higher zoom to make them appear larger
	if camera:
		camera.zoom = Vector2(1.5, 1.5)

## Create ASCII tileset from sprite sheet
func _create_ascii_tileset() -> TileSet:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Load the pre-generated sprite sheet
	var texture_path = "res://rendering/tilesets/ascii_tileset.png"
	var texture = load(texture_path) as Texture2D

	if not texture:
		push_error("Failed to load ASCII tileset: " + texture_path)
		# Fall back to generated texture
		texture = _generate_ascii_texture()

	# Create a source for our ASCII tiles
	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Add tiles for all ASCII characters (95 characters in 16x6 grid)
	# Characters 32-126 laid out left-to-right, top-to-bottom
	for i in range(95):
		var col = i % 16
		var row = i / 16
		source.create_tile(Vector2i(col, row))

	tileset.add_source(source, 0)
	return tileset

## Generate texture atlas with ASCII characters (fallback if PNG fails to load)
func _generate_ascii_texture() -> ImageTexture:
	# Generate all printable ASCII characters in 16x6 grid
	var chars = []
	for i in range(32, 127):  # ASCII 32-126 (95 characters)
		chars.append(char(i))

	var tiles_per_row = 16
	var num_rows = 6
	var atlas_width = tiles_per_row * TILE_SIZE
	var atlas_height = num_rows * TILE_SIZE

	var image = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Draw each character in grid layout
	for i in range(chars.size()):
		var c = chars[i]
		var col = i % tiles_per_row
		var row = i / tiles_per_row
		var x_offset = col * TILE_SIZE
		var y_offset = row * TILE_SIZE
		var color = tile_colors.get(c, Color(0.78, 0.78, 0.78))  # Default light gray
		_draw_char_to_image(image, c, x_offset, y_offset, color)

	return ImageTexture.create_from_image(image)

## Draw a character to the image (using simple shapes for now)
func _draw_char_to_image(image: Image, char: String, x_offset: int, y_offset: int, color: Color) -> void:
	# Draw distinctive patterns for different characters
	match char:
		"@":  # Player - filled circle
			_draw_filled_circle(image, x_offset + TILE_SIZE/2, y_offset + TILE_SIZE/2, 5, color)
		"#":  # Wall - solid square
			for y in range(TILE_SIZE):
				for x in range(TILE_SIZE):
					image.set_pixel(x_offset + x, y_offset + y, color)
		"T":  # Tree - triangle
			_draw_triangle(image, x_offset, y_offset, color)
		"~":  # Water - wavy lines
			for i in range(3):
				var y = y_offset + 4 + i * 4
				for x in range(TILE_SIZE):
					var wave = int(sin(x * 0.5) * 2)
					if y + wave >= 0 and y + wave < TILE_SIZE:
						image.set_pixel(x_offset + x, y + wave, color)
		"r", "W", "w":  # Enemies - filled circles with different sizes
			var radius = 4 if char == "W" else 3
			_draw_filled_circle(image, x_offset + TILE_SIZE/2, y_offset + TILE_SIZE/2, radius, color)
		_:  # Default - smaller square
			for y in range(3, TILE_SIZE - 3):
				for x in range(3, TILE_SIZE - 3):
					image.set_pixel(x_offset + x, y_offset + y, color)

## Draw a filled circle
func _draw_filled_circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y <= radius * radius:
				var px = cx + x
				var py = cy + y
				if px >= 0 and px < image.get_width() and py >= 0 and py < image.get_height():
					image.set_pixel(px, py, color)

## Draw a triangle (tree)
func _draw_triangle(image: Image, x_offset: int, y_offset: int, color: Color) -> void:
	var cx = TILE_SIZE / 2
	for y in range(TILE_SIZE):
		var width = (TILE_SIZE - y) / 2
		for x in range(cx - width, cx + width + 1):
			if x >= 0 and x < TILE_SIZE:
				image.set_pixel(x_offset + x, y_offset + y, color)

## Render a tile
func render_tile(position: Vector2i, tile_type: String, variant: int = 0) -> void:
	if not terrain_layer:
		return

	# Get the tile index from tile_map, or calculate from ASCII code
	var tile_index = tile_map.get(tile_type, 14)  # Default to floor (ASCII 46, index 14)

	# Convert linear index to grid coordinates (16 columns)
	var col = tile_index % 16
	var row = tile_index / 16

	terrain_layer.set_cell(position, 0, Vector2i(col, row))

## Render an entity
func render_entity(position: Vector2i, entity_type: String, color: Color = Color.WHITE) -> void:
	if not entity_layer:
		return

	# Get the tile index from tile_map, or calculate from ASCII code
	var tile_index = tile_map.get(entity_type, 32)  # Default to @ (player, ASCII 64, index 32)

	# Convert linear index to grid coordinates (16 columns)
	var col = tile_index % 16
	var row = tile_index / 16

	entity_layer.set_cell(position, 0, Vector2i(col, row))

## Clear entity at position
func clear_entity(position: Vector2i) -> void:
	if not entity_layer:
		return

	entity_layer.erase_cell(position)

## Update field of view
func update_fov(new_visible_tiles: Array[Vector2i]) -> void:
	visible_tiles = new_visible_tiles

	# TODO: Implement FOV dimming using shader or CanvasModulate
	# For now, FOV is tracked but all tiles remain visible
	# This is acceptable for Phase 1 core loop testing

## Center camera on position
func center_camera(pos: Vector2i) -> void:
	if not camera:
		return

	camera.position = Vector2(pos) * TILE_SIZE

## Clear all rendering
func clear_all() -> void:
	if terrain_layer:
		terrain_layer.clear()
	if entity_layer:
		entity_layer.clear()
