extends Control
class_name Minimap

## Minimap - Shows explored chunks in the overworld
##
## Displays a small map showing which chunks the player has visited.
## Only active for chunk-based maps (overworld).

const CHUNK_PIXEL_SIZE = 3  # Each chunk = 3×3 pixels on minimap
const MINIMAP_SIZE = Vector2(150, 150)  # Total minimap size in pixels
const MAX_CHUNKS_SHOWN = 25  # Show 25×25 chunk area centered on player

var minimap_texture: ImageTexture
var minimap_image: Image

# Colors
var VISITED_COLOR = Color(0.3, 0.6, 0.3, 0.8)  # Green for visited chunks
var CURRENT_COLOR = Color(1.0, 1.0, 0.0, 1.0)  # Yellow for current chunk
var UNEXPLORED_COLOR = Color(0.1, 0.1, 0.1, 0.5)  # Dark for unexplored

@onready var texture_rect: TextureRect = $TextureRect

func _ready() -> void:
	# Create minimap image
	minimap_image = Image.create(
		int(MINIMAP_SIZE.x),
		int(MINIMAP_SIZE.y),
		false,
		Image.FORMAT_RGBA8
	)

	minimap_texture = ImageTexture.create_from_image(minimap_image)
	if texture_rect:
		texture_rect.texture = minimap_texture

	# Connect signals
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.chunk_loaded.connect(_on_chunk_loaded)
	EventBus.map_changed.connect(_on_map_changed)

	# Initial update
	_update_minimap()

## Update minimap display
func _update_minimap() -> void:
	if not MapManager.current_map:
		visible = false
		return

	if not MapManager.current_map.chunk_based:
		visible = false
		return

	visible = true

	# Get player chunk position
	var player = EntityManager.player
	if not player:
		return

	var player_chunk = ChunkManager.world_to_chunk(player.position)

	# Clear image
	minimap_image.fill(Color(0, 0, 0, 0))

	# Get visited chunks
	var visited = ChunkManager.get_visited_chunks()

	# Calculate viewport bounds (chunks to show)
	var half_chunks = MAX_CHUNKS_SHOWN / 2
	var min_chunk = player_chunk - Vector2i(half_chunks, half_chunks)
	var max_chunk = player_chunk + Vector2i(half_chunks, half_chunks)

	# Render chunks
	for chunk_coords in visited:
		# Check if chunk is within viewport
		if chunk_coords.x < min_chunk.x or chunk_coords.x > max_chunk.x:
			continue
		if chunk_coords.y < min_chunk.y or chunk_coords.y > max_chunk.y:
			continue

		# Calculate pixel position on minimap
		var relative_pos = chunk_coords - min_chunk
		var pixel_x = relative_pos.x * CHUNK_PIXEL_SIZE
		var pixel_y = relative_pos.y * CHUNK_PIXEL_SIZE

		# Determine color
		var color = VISITED_COLOR
		if chunk_coords == player_chunk:
			color = CURRENT_COLOR

		# Draw chunk as small rectangle
		_draw_chunk_rect(pixel_x, pixel_y, color)

	# Update texture (Godot 4 API)
	minimap_texture = ImageTexture.create_from_image(minimap_image)
	if texture_rect:
		texture_rect.texture = minimap_texture

## Draw a chunk rectangle on the minimap
func _draw_chunk_rect(x: int, y: int, color: Color) -> void:
	for dy in range(CHUNK_PIXEL_SIZE):
		for dx in range(CHUNK_PIXEL_SIZE):
			var px = x + dx
			var py = y + dy
			if px >= 0 and px < MINIMAP_SIZE.x and py >= 0 and py < MINIMAP_SIZE.y:
				minimap_image.set_pixel(px, py, color)

## Called when player moves
func _on_player_moved(_old_pos: Vector2i, new_pos: Vector2i) -> void:
	if not MapManager.current_map or not MapManager.current_map.chunk_based:
		return

	# Only update if player crossed chunk boundary
	var old_chunk = ChunkManager.world_to_chunk(_old_pos)
	var new_chunk = ChunkManager.world_to_chunk(new_pos)

	if old_chunk != new_chunk:
		_update_minimap()

## Called when a new chunk loads
func _on_chunk_loaded(_chunk_coords: Vector2i) -> void:
	_update_minimap()

## Called when map changes
func _on_map_changed(_map_id: String) -> void:
	_update_minimap()
