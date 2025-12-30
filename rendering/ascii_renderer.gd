class_name ASCIIRenderer
extends RenderInterface

## ASCIIRenderer - ASCII-based renderer using TileMapLayer
##
## Renders the game world using ASCII characters.
## Uses two TileMapLayer nodes: one for terrain, one for entities.

const TILE_SIZE = 64

# Child nodes (set in scene or _ready)
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var entity_layer: TileMapLayer = $EntityLayer
@onready var camera: Camera2D = $Camera

# Tile ID mappings (char -> index in tileset)
# Extended ASCII tileset: 16 columns, 256 characters (0-255)
# Characters indexed sequentially: col = index % 16, row = index / 16
const TILES_PER_ROW = 16

# Helper function to get tile index from character
# Extended ASCII: 0-255 map directly to indices 0-255
func _char_to_index(character: String) -> int:
	if character.is_empty():
		return 0
	return character.unicode_at(0)

# Default terrain colors (tiles should define their own colors)
var default_terrain_colors: Dictionary = {
	".": Color(0.31, 0.31, 0.31),      # Dark Gray - Floor
	"#": Color(0.78, 0.78, 0.78),      # Light Gray - Wall
	"+": Color(0.6, 0.4, 0.2),         # Brown - Door
	">": Color(0.0, 1.0, 1.0),         # Cyan - Stairs down
	"<": Color(0.0, 1.0, 1.0),         # Cyan - Stairs up
	"T": Color(0.0, 0.71, 0.0),        # Green - Tree
	"~": Color(0.2, 0.4, 1.0),         # Blue - Water
}

var visible_tiles: Array[Vector2i] = []

# Dictionaries to track modulated cells for runtime coloring
var terrain_modulated_cells: Dictionary = {}
var entity_modulated_cells: Dictionary = {}

func _ready() -> void:
	_setup_tilemap_layers()
	print("ASCIIRenderer initialized")

## Setup TileMapLayer nodes with tileset
func _setup_tilemap_layers() -> void:
	# Set renderer reference on layers for runtime tile data updates
	if terrain_layer:
		terrain_layer.set("renderer", self)
		if not terrain_layer.tile_set:
			terrain_layer.tile_set = _create_ascii_tileset()

	if entity_layer:
		entity_layer.set("renderer", self)
		if not entity_layer.tile_set:
			entity_layer.tile_set = _create_ascii_tileset()

	# Set camera zoom for better visibility
	# With 64px tiles, use smaller zoom to fit more tiles on screen
	if camera:
		camera.zoom = Vector2(0.5, 0.45)

## Create ASCII tileset from sprite sheet
func _create_ascii_tileset() -> TileSet:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Load the pre-generated CP437 sprite sheet (default)
	var texture_path = "res://rendering/tilesets/ascii_tileset.png"
	var texture = load(texture_path) as Texture2D

	if not texture:
		push_error("Failed to load CP437 tileset: " + texture_path)
		# Fall back to generated texture
		texture = _generate_ascii_texture()

	# Create a source for our tiles
	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Add tiles for all 256 CP437 characters in 16x16 grid
	# Characters 0-255 laid out left-to-right, top-to-bottom
	for i in range(256):
		var col = i % TILES_PER_ROW
		var row = i / TILES_PER_ROW
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

	# Draw each character in grid layout (all white for runtime coloring)
	for i in range(chars.size()):
		var c = chars[i]
		var col = i % tiles_per_row
		var row = i / tiles_per_row
		var x_offset = col * TILE_SIZE
		var y_offset = row * TILE_SIZE
		var color = Color.WHITE  # All white - colors applied at runtime
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

	# Get the tile index from the character directly
	var tile_index = _char_to_index(tile_type)

	# Convert linear index to grid coordinates (16 columns)
	var col = tile_index % TILES_PER_ROW
	var row = tile_index / TILES_PER_ROW

	terrain_layer.set_cell(position, 0, Vector2i(col, row))

	# Set color modulation for this tile
	var tile_color = default_terrain_colors.get(tile_type, Color.WHITE)
	terrain_modulated_cells[position] = tile_color
	terrain_layer.notify_runtime_tile_data_update()

## Render an entity
func render_entity(position: Vector2i, entity_type: String, color: Color = Color.WHITE) -> void:
	if not entity_layer:
		return

	# Get the tile index from the character directly
	var tile_index = _char_to_index(entity_type)

	# Convert linear index to grid coordinates (16 columns)
	var col = tile_index % TILES_PER_ROW
	var row = tile_index / TILES_PER_ROW

	entity_layer.set_cell(position, 0, Vector2i(col, row))

	# Set color modulation for this entity
	entity_modulated_cells[position] = color
	entity_layer.notify_runtime_tile_data_update()

## Clear entity at position
func clear_entity(position: Vector2i) -> void:
	if not entity_layer:
		return

	entity_layer.erase_cell(position)
	entity_modulated_cells.erase(position)
	entity_layer.notify_runtime_tile_data_update()

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
