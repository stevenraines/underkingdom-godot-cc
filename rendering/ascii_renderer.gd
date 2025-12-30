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
}

# Color mapping for tiles
var tile_colors: Dictionary = {
	"@": Color(1.0, 1.0, 0.0),      # Yellow - Player
	".": Color(0.5, 0.5, 0.5),      # Gray - Floor
	"#": Color(1.0, 1.0, 1.0),      # White - Wall
	"+": Color(0.6, 0.4, 0.2),      # Brown - Door
	">": Color(0.0, 1.0, 1.0),      # Cyan - Stairs down
	"<": Color(0.0, 1.0, 1.0),      # Cyan - Stairs up
	"T": Color(0.0, 0.8, 0.0),      # Green - Tree
	"~": Color(0.2, 0.4, 1.0),      # Blue - Water
}

var visible_tiles: Array[Vector2i] = []

func _ready() -> void:
	_setup_tilemap_layers()
	print("ASCIIRenderer initialized")

## Setup TileMapLayer nodes with tileset
func _setup_tilemap_layers() -> void:
	# Create tileset programmatically if not set
	if terrain_layer and not terrain_layer.tile_set:
		terrain_layer.tile_set = _create_ascii_tileset()
	if entity_layer and not entity_layer.tile_set:
		entity_layer.tile_set = _create_ascii_tileset()

	# Set camera zoom for better visibility
	if camera:
		camera.zoom = Vector2(2.0, 2.0)

## Create ASCII tileset programmatically
func _create_ascii_tileset() -> TileSet:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Create a source for our ASCII tiles
	var source = TileSetAtlasSource.new()
	source.texture = _generate_ascii_texture()
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# Add tiles for each character
	for i in range(8):  # We have 8 characters
		source.create_tile(Vector2i(i, 0))

	tileset.add_source(source, 0)
	return tileset

## Generate texture atlas with ASCII characters
func _generate_ascii_texture() -> ImageTexture:
	var chars = ["@", ".", "#", "+", ">", "<", "T", "~"]
	var atlas_width = chars.size() * TILE_SIZE
	var atlas_height = TILE_SIZE

	var image = Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Draw each character (simple box for now - will be replaced with actual font rendering)
	for i in range(chars.size()):
		var char = chars[i]
		var color = tile_colors.get(char, Color.WHITE)
		_draw_char_to_image(image, char, i * TILE_SIZE, 0, color)

	return ImageTexture.create_from_image(image)

## Draw a character to the image (simplified - draws colored box)
func _draw_char_to_image(image: Image, char: String, x_offset: int, y_offset: int, color: Color) -> void:
	# For now, draw a simple colored rectangle
	# In a full implementation, we'd render actual font characters
	for y in range(2, TILE_SIZE - 2):
		for x in range(2, TILE_SIZE - 2):
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
