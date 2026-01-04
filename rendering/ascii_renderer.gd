class_name ASCIIRenderer
extends RenderInterface

## ASCIIRenderer - ASCII-based renderer using TileMapLayer
##
## Renders the game world using ASCII characters.
## Uses two TileMapLayer nodes: one for terrain, one for entities.
## Supports fog of war: unexplored tiles are very dark gray,
## explored but not visible tiles are dark gray.

const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")

const TILE_WIDTH = 38
const TILE_HEIGHT = 64

# Fog of war colors
const FOG_UNEXPLORED_COLOR = Color(0.08, 0.08, 0.08)  # Very dark gray
const FOG_EXPLORED_COLOR = Color(0.18, 0.18, 0.18)    # Dark gray

# Child nodes (set in scene or _ready)
@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var entity_layer: TileMapLayer = $EntityLayer
@onready var camera: Camera2D = $Camera

# Dynamically created highlight layer for borders/cursors
var highlight_layer: TileMapLayer = null
var highlight_modulated_cells: Dictionary = {}

# Current highlight position and color
var current_highlight_position: Vector2i = Vector2i(-1, -1)
var current_highlight_color: Color = Color.CYAN

# Tile ID mappings (char -> index in tileset)
# Unicode tileset: 32 columns, 1295 characters (41 rows)
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
# IMPORTANT: This must match the exact order from generate_tilesets.py
func _build_unicode_map() -> void:
	var chars: Array = []

	# Basic Latin (ASCII 32-126) - 95 chars
	for i in range(0x0020, 0x007F):
		chars.append(char(i))

	# Latin-1 Supplement (160-255) - 96 chars
	for i in range(0x00A0, 0x0100):
		chars.append(char(i))

	# Greek and Coptic (0x0370-0x03FF) - includes Δ, Ω, α, β, γ, etc.
	for i in range(0x0370, 0x0400):
		chars.append(char(i))

	# Miscellaneous Technical (0x2300-0x23FF) - includes ⌂, ⌐, ⌠, etc.
	for i in range(0x2300, 0x2400):
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

	print("[ASCIIRenderer] Built unicode map with %d characters" % chars.size())

# Helper function to get tile index from character
func _char_to_index(character: String) -> int:
	if character.is_empty():
		return 0

	# Look up character in unicode map
	if character in unicode_char_map:
		return unicode_char_map[character]

	# Fallback for unmapped characters - use space
	push_warning("[ASCIIRenderer] Unmapped character '%s' (U+%04X), using space" % [character, character.unicode_at(0) if character.length() > 0 else 0])
	return 0  # Space character at index 0

# Default terrain colors (tiles should define their own colors)
var default_terrain_colors: Dictionary = {
	".": Color(0.31, 0.31, 0.31),      # Dark Gray - Floor (basic/tundra/beach)
	"#": Color(0.31, 0.31, 0.31),      # Dark Gray - Wall (muted to match floor)
	"░": Color(0.31, 0.31, 0.31),      # Dark Gray - Wall (CP437 light shade, muted)
	"/": Color(0.6, 0.4, 0.2),         # Brown - Open Door
	"+": Color(0.5, 0.35, 0.15),       # Darker Brown - Closed Door
	">": Color(0.0, 1.0, 1.0),         # Cyan - Stairs down
	"<": Color(0.0, 1.0, 1.0),         # Cyan - Stairs up
	"T": Color(0.0, 0.71, 0.0),        # Green - Tree

	# Biome grass characters
	"\"": Color(0.5, 0.7, 0.3),        # Green - Grassland/Woodland/Rainforest grass
	",": Color(0.4, 0.6, 0.4),         # Dark Green - Forest/Marsh grass
	"^": Color(0.6, 0.6, 0.5),         # Gray-Brown - Rocky Hills
	"*": Color(0.85, 0.85, 0.9),       # White - Snow
	"·": Color(0.5, 0.5, 0.5),         # Gray - Barren Rock
	"~": Color(0.2, 0.4, 1.0),         # Blue - Water (Swamp/Ocean)
	"≈": Color(0.1, 0.3, 0.8),         # Dark Blue - Deep Ocean
	"▲": Color(0.6, 0.6, 0.65),        # Light Gray - Mountains/Snow Mountains

	# Harvestable resources
	"◆": Color(0.6, 0.6, 0.6),         # Gray - Rock
	"◊": Color(0.7, 0.5, 0.3),         # Rusty Brown - Iron Ore
}

var visible_tiles: Array[Vector2i] = []

# Fog of war state
var fow_enabled: bool = true
var current_map_id: String = ""
var is_chunk_based: bool = false

# Dictionaries to track modulated cells for runtime coloring
var terrain_modulated_cells: Dictionary = {}
var entity_modulated_cells: Dictionary = {}

# Store original colors for fog of war dimming
var terrain_original_colors: Dictionary = {}
var entity_original_colors: Dictionary = {}

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

	# Create highlight layer dynamically (rendered on top of entities)
	_create_highlight_layer()

	# Set camera zoom for better visibility
	# With 64px tiles, use smaller zoom to fit more tiles on screen
	if camera:
		camera.zoom = Vector2(0.5, 0.45)


## Create highlight layer for borders/cursors
func _create_highlight_layer() -> void:
	# Load the highlight layer script
	var highlight_script = load("res://rendering/highlight_layer.gd")
	highlight_layer = TileMapLayer.new()
	highlight_layer.set_script(highlight_script)
	highlight_layer.name = "HighlightLayer"
	highlight_layer.set("renderer", self)
	highlight_layer.tile_set = _create_ascii_tileset()
	# Add as sibling after entity layer so it renders on top
	add_child(highlight_layer)
	# Move it to be after entity layer in the tree
	if entity_layer:
		highlight_layer.move_to_front()

## Create ASCII tileset from sprite sheet
func _create_ascii_tileset() -> TileSet:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE_WIDTH, TILE_HEIGHT)

	# Load the pre-generated Unicode sprite sheet (default)
	var texture_path = "res://rendering/tilesets/unicode_tileset.png"
	var texture = load(texture_path) as Texture2D

	if texture:
		print("[ASCIIRenderer] Loaded tileset texture: %s (%dx%d)" % [texture_path, texture.get_width(), texture.get_height()])
	else:
		push_error("Failed to load Unicode tileset: " + texture_path)
		# Fall back to generated texture
		texture = _generate_ascii_texture()

	# Create a source for our tiles
	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_WIDTH, TILE_HEIGHT)
	source.separation = Vector2i(0, 0)  # No spacing between tiles
	source.margins = Vector2i(0, 0)     # No margins around the atlas

	# Add tiles for all 1295 Unicode characters in 32-column grid
	# Characters laid out left-to-right, top-to-bottom (41 rows)
	var num_tiles = 1295
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

## Render an entire chunk (optimized batch rendering)
func render_chunk(chunk: WorldChunk) -> void:
	if not terrain_layer:
		return

	var bounds = chunk.get_world_bounds()
	var min_pos = bounds.min
	var max_pos = bounds.max

	# Render all tiles in chunk
	for world_y in range(min_pos.y, max_pos.y + 1):
		for world_x in range(min_pos.x, max_pos.x + 1):
			var world_pos = Vector2i(world_x, world_y)
			var local_pos = chunk.world_to_chunk_position(world_pos)
			var tile = chunk.get_tile(local_pos)

			# Get tile character
			var tile_char = tile.ascii_char

			# Render tile
			var tile_index = _char_to_index(tile_char)
			var col = tile_index % TILES_PER_ROW
			var row = tile_index / TILES_PER_ROW

			terrain_layer.set_cell(world_pos, 0, Vector2i(col, row))

			# Set color modulation
			# Use tile's color if set (from biome data), otherwise fall back to default
			var tile_color = tile.color if tile.color != Color.WHITE else default_terrain_colors.get(tile_char, Color.WHITE)
			terrain_modulated_cells[world_pos] = tile_color

	# Notify once after batch update
	terrain_layer.notify_runtime_tile_data_update()

## Render an entity
func render_entity(position: Vector2i, entity_type: String, color: Color = Color.WHITE) -> void:
	if not entity_layer:
		return

	# Hide ground tiles underneath entity (floor/grass characters)
	if terrain_layer and terrain_layer.get_cell_source_id(position) != -1:
		# Ground tile characters that should be hidden under entities
		var ground_chars = [".", "\"", ","]
		var current_atlas = terrain_layer.get_cell_atlas_coords(position)

		# Check if current tile is a ground tile
		var is_ground_tile = false
		for ground_char in ground_chars:
			var ground_index = _char_to_index(ground_char)
			var ground_col = ground_index % TILES_PER_ROW
			var ground_row = ground_index / TILES_PER_ROW
			if current_atlas == Vector2i(ground_col, ground_row):
				is_ground_tile = true
				break

		if is_ground_tile:
			# Store the ground tile data and hide it
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

## Update field of view and apply fog of war
func update_fov(new_visible_tiles: Array[Vector2i]) -> void:
	visible_tiles = new_visible_tiles

	if not fow_enabled:
		return

	# Apply fog of war to terrain tiles
	_apply_fog_of_war_to_terrain()

	# Apply fog of war to entity layer (hide entities not in visible tiles)
	_apply_fog_of_war_to_entities()

## Set map info for fog of war tracking
func set_map_info(map_id: String, chunk_based: bool) -> void:
	current_map_id = map_id
	is_chunk_based = chunk_based

## Enable or disable fog of war
func set_fow_enabled(enabled: bool) -> void:
	fow_enabled = enabled
	if not enabled:
		# Restore all original colors
		_restore_all_colors()

## Apply fog of war dimming to terrain tiles
func _apply_fog_of_war_to_terrain() -> void:
	if not terrain_layer:
		return

	# Collect all rendered terrain positions
	var all_positions: Array = terrain_modulated_cells.keys()

	for pos in all_positions:
		var tile_state = FogOfWarSystemClass.get_tile_state(current_map_id, pos, is_chunk_based)
		var original_color = terrain_original_colors.get(pos, terrain_modulated_cells.get(pos, Color.WHITE))

		# Store original color if not already stored
		if not terrain_original_colors.has(pos):
			terrain_original_colors[pos] = original_color

		match tile_state:
			"visible":
				# Full brightness
				terrain_modulated_cells[pos] = original_color
			"explored":
				# Dark gray tint (lerp toward fog color)
				terrain_modulated_cells[pos] = _apply_fog_tint(original_color, FOG_EXPLORED_COLOR, 0.7)
			"unexplored":
				# Very dark gray
				terrain_modulated_cells[pos] = FOG_UNEXPLORED_COLOR

	terrain_layer.notify_runtime_tile_data_update()

## Apply fog of war to entities (hide entities not in visible tiles)
func _apply_fog_of_war_to_entities() -> void:
	if not entity_layer:
		return

	# For entities, we need to hide those not in visible tiles
	var all_positions: Array = entity_modulated_cells.keys()

	for pos in all_positions:
		var pos_is_visible = visible_tiles.has(pos)
		var original_color = entity_original_colors.get(pos, entity_modulated_cells.get(pos, Color.WHITE))

		# Store original color if not already stored
		if not entity_original_colors.has(pos):
			entity_original_colors[pos] = original_color

		if pos_is_visible:
			# Show entity with original color
			entity_modulated_cells[pos] = original_color
		else:
			# Check if explored - show as dark silhouette for structures/items
			var tile_state = FogOfWarSystemClass.get_tile_state(current_map_id, pos, is_chunk_based)
			if tile_state == "explored":
				# Show as very dark version (for static objects like structures)
				entity_modulated_cells[pos] = _apply_fog_tint(original_color, FOG_EXPLORED_COLOR, 0.8)
			else:
				# Unexplored - hide completely (make invisible)
				entity_modulated_cells[pos] = Color(0, 0, 0, 0)

	entity_layer.notify_runtime_tile_data_update()

## Apply fog tint to a color
func _apply_fog_tint(original: Color, fog_color: Color, amount: float) -> Color:
	return original.lerp(fog_color, amount)

## Restore all colors to original (when disabling FOW)
func _restore_all_colors() -> void:
	for pos in terrain_original_colors:
		if terrain_modulated_cells.has(pos):
			terrain_modulated_cells[pos] = terrain_original_colors[pos]

	for pos in entity_original_colors:
		if entity_modulated_cells.has(pos):
			entity_modulated_cells[pos] = entity_original_colors[pos]

	if terrain_layer:
		terrain_layer.notify_runtime_tile_data_update()
	if entity_layer:
		entity_layer.notify_runtime_tile_data_update()

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
	if highlight_layer:
		highlight_layer.clear()
	# Clear color modulation dictionaries to prevent stale color data
	terrain_modulated_cells.clear()
	entity_modulated_cells.clear()
	highlight_modulated_cells.clear()
	hidden_floor_positions.clear()
	current_highlight_position = Vector2i(-1, -1)


## Render a highlight border around a position
## Uses box-drawing corner characters at the 4 diagonal positions to frame the target
func render_highlight_border(pos: Vector2i, color: Color = Color.CYAN) -> void:
	if not highlight_layer:
		return

	# Clear previous highlight
	clear_highlight()

	# Store current highlight center
	current_highlight_position = pos
	current_highlight_color = color

	# Render 4 corner characters at diagonal positions around the target
	# Box drawing corners: ┌ (0x250C), ┐ (0x2510), └ (0x2514), ┘ (0x2518)
	var corners = [
		{"offset": Vector2i(-1, -1), "char": "┘"},  # Top-left of target -> bottom-right corner
		{"offset": Vector2i(1, -1), "char": "└"},   # Top-right of target -> bottom-left corner
		{"offset": Vector2i(-1, 1), "char": "┐"},   # Bottom-left of target -> top-right corner
		{"offset": Vector2i(1, 1), "char": "┌"},    # Bottom-right of target -> top-left corner
	]

	for corner in corners:
		var corner_pos = pos + corner.offset
		var tile_index = _char_to_index(corner.char)
		var col = tile_index % TILES_PER_ROW
		var row = tile_index / TILES_PER_ROW

		highlight_layer.set_cell(corner_pos, 0, Vector2i(col, row))
		highlight_modulated_cells[corner_pos] = color

	highlight_layer.notify_runtime_tile_data_update()


## Clear the current highlight
func clear_highlight() -> void:
	if not highlight_layer:
		return

	if current_highlight_position.x >= 0:
		# Clear all 4 corner positions (diagonal)
		var offsets = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
		for offset in offsets:
			var corner_pos = current_highlight_position + offset
			highlight_layer.erase_cell(corner_pos)
			highlight_modulated_cells.erase(corner_pos)

		highlight_layer.notify_runtime_tile_data_update()

	current_highlight_position = Vector2i(-1, -1)


## Get current highlight position
func get_highlight_position() -> Vector2i:
	return current_highlight_position
