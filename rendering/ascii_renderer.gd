class_name ASCIIRenderer
extends RenderInterface

## ASCIIRenderer - ASCII-based renderer using TileMapLayer
##
## Renders the game world using ASCII characters.
## Uses two TileMapLayer nodes: one for terrain, one for entities.

const TILE_WIDTH = 38
const TILE_HEIGHT = 64

# Child nodes (set in scene or _ready)
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var entity_layer: TileMapLayer = $EntityLayer
@onready var camera: Camera2D = $Camera

# Tile ID mappings (char -> index in tileset)
# Unicode tileset: 32 columns, 895 characters
# Characters indexed sequentially: col = index % 32, row = index / 32
const TILES_PER_ROW = 32

# Unicode character list (matches the order in unicode_tileset.png)
# This must match the exact order from generate_tilesets.py
var unicode_char_map: Dictionary = {}

func _ready() -> void:
	_setup_tilemap_layers()
	_build_unicode_map()
	print("ASCIIRenderer initialized")

# Build Unicode character index mapping
func _build_unicode_map() -> void:
	var chars: Array = []

	# Basic Latin (ASCII 32-126) - 95 chars
	for i in range(0x0020, 0x007F):
		chars.append(char(i))

	# Latin-1 Supplement (160-255) - 96 chars
	for i in range(0x00A0, 0x0100):
		chars.append(char(i))

	# Box Drawing (0x2500-0x257F) - 128 chars
	for i in range(0x2500, 0x2580):
		chars.append(char(i))

	# Block Elements (0x2580-0x259F) - 32 chars
	for i in range(0x2580, 0x25A0):
		chars.append(char(i))

	# Geometric Shapes (0x25A0-0x25FF) - 96 chars
	for i in range(0x25A0, 0x2600):
		chars.append(char(i))

	# Miscellaneous Symbols (0x2600-0x26FF) - 256 chars
	for i in range(0x2600, 0x2700):
		chars.append(char(i))

	# Dingbats (0x2700-0x27BF) - 192 chars
	for i in range(0x2700, 0x27C0):
		chars.append(char(i))

	# Build lookup dictionary
	for i in range(chars.size()):
		unicode_char_map[chars[i]] = i

# Helper function to get tile index from character
func _char_to_index(character: String) -> int:
	if character.is_empty():
		return 0

	# Look up character in unicode map
	if character in unicode_char_map:
		return unicode_char_map[character]

	# Fallback for unmapped characters - use space
	return 0  # Space character at index 0

# Default terrain colors (tiles should define their own colors)
var default_terrain_colors: Dictionary = {
	".": Color(0.31, 0.31, 0.31),      # Dark Gray - Floor
	"#": Color(0.78, 0.78, 0.78),      # Light Gray - Wall (legacy)
	"░": Color(0.78, 0.78, 0.78),      # Light Gray - Wall (CP437 light shade)
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

# Track hidden floor tiles (positions where entities are standing)
var hidden_floor_positions: Dictionary = {}

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
	tileset.tile_size = Vector2i(TILE_WIDTH, TILE_HEIGHT)

	# Load the pre-generated Unicode sprite sheet (default)
	var texture_path = "res://rendering/tilesets/unicode_tileset.png"
	var texture = load(texture_path) as Texture2D

	if not texture:
		push_error("Failed to load Unicode tileset: " + texture_path)
		# Fall back to generated texture
		texture = _generate_ascii_texture()

	# Create a source for our tiles
	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_WIDTH, TILE_HEIGHT)
	source.separation = Vector2i(0, 0)  # No spacing between tiles
	source.margins = Vector2i(0, 0)     # No margins around the atlas

	# Add tiles for all 895 Unicode characters in 32-column grid
	# Characters laid out left-to-right, top-to-bottom (28 rows)
	var num_tiles = 895
	for i in range(num_tiles):
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
	var atlas_width = tiles_per_row * TILE_WIDTH
	var atlas_height = num_rows * TILE_HEIGHT

	var image = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Draw each character in grid layout (all white for runtime coloring)
	for i in range(chars.size()):
		var c = chars[i]
		var col = i % tiles_per_row
		var row = i / tiles_per_row
		var x_offset = col * TILE_WIDTH
		var y_offset = row * TILE_HEIGHT
		var color = Color.WHITE  # All white - colors applied at runtime
		_draw_char_to_image(image, c, x_offset, y_offset, color)

	return ImageTexture.create_from_image(image)

## Draw a character to the image (using simple shapes for now)
func _draw_char_to_image(image: Image, char: String, x_offset: int, y_offset: int, color: Color) -> void:
	# Draw distinctive patterns for different characters
	match char:
		"@":  # Player - filled circle
			_draw_filled_circle(image, x_offset + TILE_WIDTH/2, y_offset + TILE_HEIGHT/2, 5, color)
		"#":  # Wall - solid square
			for y in range(TILE_HEIGHT):
				for x in range(TILE_WIDTH):
					image.set_pixel(x_offset + x, y_offset + y, color)
		"T":  # Tree - triangle
			_draw_triangle(image, x_offset, y_offset, color)
		"~":  # Water - wavy lines
			for i in range(3):
				var y = y_offset + 4 + i * 4
				for x in range(TILE_WIDTH):
					var wave = int(sin(x * 0.5) * 2)
					if y + wave >= 0 and y + wave < TILE_HEIGHT:
						image.set_pixel(x_offset + x, y + wave, color)
		"r", "W", "w":  # Enemies - filled circles with different sizes
			var radius = 4 if char == "W" else 3
			_draw_filled_circle(image, x_offset + TILE_WIDTH/2, y_offset + TILE_HEIGHT/2, radius, color)
		_:  # Default - smaller square
			for y in range(3, TILE_HEIGHT - 3):
				for x in range(3, TILE_WIDTH - 3):
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
	var cx = TILE_WIDTH / 2
	for y in range(TILE_HEIGHT):
		var width = (TILE_WIDTH - y) / 2
		for x in range(cx - width, cx + width + 1):
			if x >= 0 and x < TILE_WIDTH:
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

	# Hide floor tile underneath entity (don't render the period)
	if terrain_layer and terrain_layer.get_cell_source_id(position) != -1:
		# Check if this is a floor tile (period character)
		var floor_index = _char_to_index(".")
		var floor_col = floor_index % TILES_PER_ROW
		var floor_row = floor_index / TILES_PER_ROW
		var current_atlas = terrain_layer.get_cell_atlas_coords(position)
		if current_atlas == Vector2i(floor_col, floor_row):
			# Store the floor data and hide it
			hidden_floor_positions[position] = {
				"atlas": current_atlas,
				"color": terrain_modulated_cells.get(position, Color.WHITE)
			}
			terrain_layer.erase_cell(position)
			terrain_modulated_cells.erase(position)
			terrain_layer.notify_runtime_tile_data_update()

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

	# Restore hidden floor tile if there was one
	if position in hidden_floor_positions:
		var floor_data = hidden_floor_positions[position]
		terrain_layer.set_cell(position, 0, floor_data["atlas"])
		terrain_modulated_cells[position] = floor_data["color"]
		terrain_layer.notify_runtime_tile_data_update()
		hidden_floor_positions.erase(position)

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

	camera.position = Vector2(pos.x * TILE_WIDTH, pos.y * TILE_HEIGHT)

## Clear all rendering
func clear_all() -> void:
	if terrain_layer:
		terrain_layer.clear()
	if entity_layer:
		entity_layer.clear()
