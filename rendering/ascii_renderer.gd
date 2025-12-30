class_name ASCIIRenderer
extends RenderInterface

## ASCIIRenderer - ASCII-based renderer using TileMapLayer
##
## Renders the game world using ASCII characters.
## Uses two TileMapLayer nodes: one for terrain, one for entities.

const TILE_SIZE = 16

# Child nodes (set in scene or _ready)
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var entity_layer: TileMapLayer = $EntityLayer
@onready var camera: Camera2D = $Camera

# Tile ID mappings (char -> source_id)
var tile_map: Dictionary = {
	"@": 0,   # Player
	".": 1,   # Floor
	"#": 2,   # Wall
	"+": 3,   # Door
	">": 4,   # Stairs down
	"<": 5,   # Stairs up
	"T": 6,   # Tree
	"~": 7,   # Water
	"r": 8,   # Grave Rat
	"W": 9,   # Barrow Wight
	"w": 10,  # Woodland Wolf
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
	if camera:
		camera.zoom = Vector2(2.0, 2.0)

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

	# Add tiles for each character
	for i in range(11):  # We have 11 characters (8 terrain + 3 enemies)
		source.create_tile(Vector2i(i, 0))

	tileset.add_source(source, 0)
	return tileset

## Generate texture atlas with ASCII characters
func _generate_ascii_texture() -> ImageTexture:
	var chars = ["@", ".", "#", "+", ">", "<", "T", "~", "r", "W", "w"]
	var atlas_width = chars.size() * TILE_SIZE
	var atlas_height = TILE_SIZE

	var image = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Draw each character using a font
	for i in range(chars.size()):
		var char = chars[i]
		var color = tile_colors.get(char, Color.WHITE)
		_draw_char_to_image(image, char, i * TILE_SIZE, 0, color)

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

	var tile_id = tile_map.get(tile_type, 1)  # Default to floor
	terrain_layer.set_cell(position, 0, Vector2i(tile_id, 0))

## Render an entity
func render_entity(position: Vector2i, entity_type: String, color: Color = Color.WHITE) -> void:
	if not entity_layer:
		return

	var tile_id = tile_map.get(entity_type, 0)
	entity_layer.set_cell(position, 0, Vector2i(tile_id, 0))

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
