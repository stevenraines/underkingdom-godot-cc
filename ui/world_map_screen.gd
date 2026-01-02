extends Control

## WorldMapScreen - Shows map views at three zoom levels
##
## Three map levels:
## - Area: Shows currently loaded chunks (most detailed)
## - Region: Shows ~1/4 of the world centered on player
## - World: Shows the entire island overview

signal closed

enum MapLevel { AREA, REGION, WORLD }

# Fixed image size for performance - texture will be scaled to fit container
const MAP_IMAGE_SIZE: int = 400  # 400x400 pixels for the generated image
const CHUNK_SIZE: int = 32  # Tiles per chunk

var map_image: Image
var map_texture: ImageTexture
var is_open: bool = false

# Current map level
var current_level: MapLevel = MapLevel.AREA
static var last_viewed_level: MapLevel = MapLevel.AREA  # Persists between opens
static var has_opened_before: bool = false

# Cached base images (without player marker) - static so they persist
static var cached_world_base_image: Image = null
static var cached_world_seed: int = -1  # Track which seed the cache was built for

# Island dimensions (will be read from config)
var island_width_tiles: int = 1600
var island_height_tiles: int = 1600

@onready var map_rect: TextureRect = $Panel/MarginContainer/VBoxContainer/ContentHBox/MapContainer/MapRect
@onready var map_container: AspectRatioContainer = $Panel/MarginContainer/VBoxContainer/ContentHBox/MapContainer
@onready var legend_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentHBox/SidebarPanel/SidebarMargin/SidebarVBox/LegendContainer
@onready var header_label: Label = $Panel/MarginContainer/VBoxContainer/Header
@onready var footer_label: Label = $Panel/MarginContainer/VBoxContainer/Footer

func _ready() -> void:
	visible = false
	# Get island dimensions from config
	var island_settings = BiomeManager.get_island_settings()
	island_width_tiles = island_settings.get("width_chunks", 50) * CHUNK_SIZE
	island_height_tiles = island_settings.get("height_chunks", 50) * CHUNK_SIZE


func open() -> void:
	visible = true
	is_open = true

	# Set initial level based on history
	if has_opened_before:
		current_level = last_viewed_level
	else:
		current_level = MapLevel.AREA
		has_opened_before = true

	# Wait a frame for layout to calculate container sizes
	await get_tree().process_frame
	_refresh_map()


func close() -> void:
	visible = false
	is_open = false
	last_viewed_level = current_level  # Remember for next open
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			# M cycles through map levels instead of closing
			_cycle_map_level()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_TAB:
			# Tab also cycles through map levels
			_cycle_map_level()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_1:
			_set_map_level(MapLevel.AREA)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			_set_map_level(MapLevel.REGION)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_3:
			_set_map_level(MapLevel.WORLD)
			get_viewport().set_input_as_handled()


func _cycle_map_level() -> void:
	var next_level = (current_level + 1) % 3
	_set_map_level(next_level as MapLevel)


func _set_map_level(level: MapLevel) -> void:
	if level == current_level:
		return
	current_level = level
	_refresh_map()


func _refresh_map() -> void:
	_update_header()
	_update_footer()

	match current_level:
		MapLevel.AREA:
			_generate_area_map()
		MapLevel.REGION:
			_generate_region_map()
		MapLevel.WORLD:
			_generate_world_map()

	_populate_legend()


func _update_header() -> void:
	if not header_label:
		return

	match current_level:
		MapLevel.AREA:
			header_label.text = "AREA MAP"
		MapLevel.REGION:
			header_label.text = "REGION MAP"
		MapLevel.WORLD:
			header_label.text = "WORLD MAP"


func _update_footer() -> void:
	if not footer_label:
		return

	var level_name = ""
	match current_level:
		MapLevel.AREA:
			level_name = "Area"
		MapLevel.REGION:
			level_name = "Region"
		MapLevel.WORLD:
			level_name = "World"

	footer_label.text = "[M/Tab] Cycle View  |  [1] Area  [2] Region  [3] World  |  [ESC] Close  |  Current: %s" % level_name


func _generate_area_map() -> void:
	## Renders the currently loaded chunks around the player - fills the available space
	if not MapManager.current_map:
		return

	map_image = Image.create(MAP_IMAGE_SIZE, MAP_IMAGE_SIZE, false, Image.FORMAT_RGBA8)
	map_image.fill(Color(0.05, 0.05, 0.08, 1.0))  # Dark background for unexplored

	var player_pos = EntityManager.player.position if EntityManager.player else Vector2i(0, 0)
	var active_chunks = ChunkManager.get_active_chunk_coords()

	if active_chunks.is_empty():
		_finalize_map_texture()
		return

	# Calculate bounds of loaded chunks
	var min_chunk = active_chunks[0]
	var max_chunk = active_chunks[0]
	for chunk_coords in active_chunks:
		min_chunk.x = mini(min_chunk.x, chunk_coords.x)
		min_chunk.y = mini(min_chunk.y, chunk_coords.y)
		max_chunk.x = maxi(max_chunk.x, chunk_coords.x)
		max_chunk.y = maxi(max_chunk.y, chunk_coords.y)

	# World tile bounds
	var min_tile = min_chunk * CHUNK_SIZE
	var max_tile = (max_chunk + Vector2i(1, 1)) * CHUNK_SIZE
	var tile_width = max_tile.x - min_tile.x
	var tile_height = max_tile.y - min_tile.y

	# Scale to fill the image - use the dimension that needs more scaling
	var scale_x = float(MAP_IMAGE_SIZE) / float(tile_width)
	var scale_y = float(MAP_IMAGE_SIZE) / float(tile_height)
	var map_scale = minf(scale_x, scale_y)  # Use min to fit both dimensions

	# Calculate the actual image dimensions needed
	var img_width = int(tile_width * map_scale)
	var img_height = int(tile_height * map_scale)

	# Calculate offset to center the map in the image
	@warning_ignore("integer_division")
	var offset_x = (MAP_IMAGE_SIZE - img_width) / 2
	@warning_ignore("integer_division")
	var offset_y = (MAP_IMAGE_SIZE - img_height) / 2

	# Calculate pixel size for each tile (may be > 1 when zoomed in)
	var pixel_per_tile = int(ceilf(map_scale))

	# Draw tiles from loaded chunks
	for chunk_coords in active_chunks:
		var chunk = ChunkManager.get_chunk(chunk_coords)
		if not chunk or not chunk.is_loaded:
			continue

		var chunk_world_min = chunk_coords * CHUNK_SIZE

		for local_y in range(CHUNK_SIZE):
			for local_x in range(CHUNK_SIZE):
				var world_x = chunk_world_min.x + local_x
				var world_y = chunk_world_min.y + local_y

				# Convert to pixel coordinates with scaling
				var px = offset_x + int((world_x - min_tile.x) * map_scale)
				var py = offset_y + int((world_y - min_tile.y) * map_scale)

				var tile = chunk.get_tile(Vector2i(local_x, local_y))
				var color = _get_tile_color(tile)

				# Fill a rectangle for each tile (handles scales > 1)
				for dy in range(pixel_per_tile):
					for dx in range(pixel_per_tile):
						var fx = px + dx
						var fy = py + dy
						if fx >= 0 and fx < MAP_IMAGE_SIZE and fy >= 0 and fy < MAP_IMAGE_SIZE:
							map_image.set_pixel(fx, fy, color)

	# Get special feature positions
	var town_pos = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	var dungeon_entrances: Array = MapManager.current_map.get_meta("dungeon_entrances", [])

	# Draw town if in loaded area
	if town_pos != Vector2i(-1, -1):
		if town_pos.x >= min_tile.x and town_pos.x < max_tile.x and town_pos.y >= min_tile.y and town_pos.y < max_tile.y:
			var town_px = Vector2i(
				offset_x + int((town_pos.x - min_tile.x) * map_scale),
				offset_y + int((town_pos.y - min_tile.y) * map_scale)
			)
			_draw_marker(town_px, Color.BLACK, 7)  # Outline
			_draw_marker(town_px, Color(1.0, 0.9, 0.5), 5)  # Town marker

	# Draw dungeon entrances if in loaded area
	for entrance in dungeon_entrances:
		var entrance_pos: Vector2i = entrance.position
		if entrance_pos.x >= min_tile.x and entrance_pos.x < max_tile.x and entrance_pos.y >= min_tile.y and entrance_pos.y < max_tile.y:
			var entrance_px = Vector2i(
				offset_x + int((entrance_pos.x - min_tile.x) * map_scale),
				offset_y + int((entrance_pos.y - min_tile.y) * map_scale)
			)
			var color = Color.html(entrance.entrance_color)
			_draw_marker(entrance_px, Color.BLACK, 6)  # Outline
			_draw_marker(entrance_px, color, 4)  # Dungeon marker

	# Draw player marker (on top)
	var player_px = Vector2i(
		offset_x + int((player_pos.x - min_tile.x) * map_scale),
		offset_y + int((player_pos.y - min_tile.y) * map_scale)
	)
	_draw_marker(player_px, Color.BLACK, 5)  # Outline
	_draw_marker(player_px, Color.WHITE, 4)
	_draw_marker(player_px, Color.YELLOW, 3)

	_finalize_map_texture()


func _generate_region_map() -> void:
	## Renders approximately 1/4 of the world linear dimension, centered on the player
	## Uses cached world base image for performance
	if not MapManager.current_map:
		return

	# Ensure world base image is cached
	_ensure_world_base_cached()

	if not cached_world_base_image:
		return

	@warning_ignore("integer_division")
	var player_pos = EntityManager.player.position if EntityManager.player else Vector2i(island_width_tiles / 2, island_height_tiles / 2)

	# Region size is 1/4 of the world linear dimension
	@warning_ignore("integer_division")
	var region_width = island_width_tiles / 4
	@warning_ignore("integer_division")
	var region_height = island_height_tiles / 4

	# Calculate view bounds centered on player in world coordinates
	@warning_ignore("integer_division")
	var view_min_x = player_pos.x - region_width / 2
	@warning_ignore("integer_division")
	var view_min_y = player_pos.y - region_height / 2

	# Clamp to island bounds
	view_min_x = clampi(view_min_x, 0, island_width_tiles - region_width)
	view_min_y = clampi(view_min_y, 0, island_height_tiles - region_height)

	# Convert world coords to cached image coords
	var world_to_cache = float(MAP_IMAGE_SIZE) / float(island_width_tiles)
	var cache_x = int(view_min_x * world_to_cache)
	var cache_y = int(view_min_y * world_to_cache)
	var cache_region_size = int(region_width * world_to_cache)

	# Clamp to valid cache region
	cache_x = clampi(cache_x, 0, MAP_IMAGE_SIZE - cache_region_size)
	cache_y = clampi(cache_y, 0, MAP_IMAGE_SIZE - cache_region_size)

	# Extract region from cached image and scale up to fill
	var region_image = cached_world_base_image.get_region(Rect2i(cache_x, cache_y, cache_region_size, cache_region_size))
	region_image.resize(MAP_IMAGE_SIZE, MAP_IMAGE_SIZE, Image.INTERPOLATE_NEAREST)

	# Copy to our map image
	map_image = region_image

	# Get special features
	var town_pos = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	var dungeon_entrances: Array = MapManager.current_map.get_meta("dungeon_entrances", [])

	# Calculate scale for markers (world to pixel)
	var tiles_per_pixel = float(region_width) / float(MAP_IMAGE_SIZE)

	# Draw town if in view
	var view_max_x = view_min_x + region_width
	var view_max_y = view_min_y + region_height
	if town_pos != Vector2i(-1, -1):
		if town_pos.x >= view_min_x and town_pos.x < view_max_x and town_pos.y >= view_min_y and town_pos.y < view_max_y:
			var town_px = Vector2i(
				int((town_pos.x - view_min_x) / tiles_per_pixel),
				int((town_pos.y - view_min_y) / tiles_per_pixel)
			)
			_draw_marker(town_px, Color.BLACK, 7)  # Outline
			_draw_marker(town_px, Color(1.0, 0.9, 0.5), 5)  # Town marker

	# Draw dungeon entrances if in view
	for entrance in dungeon_entrances:
		var entrance_pos: Vector2i = entrance.position
		if entrance_pos.x >= view_min_x and entrance_pos.x < view_max_x and entrance_pos.y >= view_min_y and entrance_pos.y < view_max_y:
			var entrance_px = Vector2i(
				int((entrance_pos.x - view_min_x) / tiles_per_pixel),
				int((entrance_pos.y - view_min_y) / tiles_per_pixel)
			)
			var color = Color.html(entrance.entrance_color)
			_draw_marker(entrance_px, Color.BLACK, 6)  # Outline
			_draw_marker(entrance_px, color, 4)  # Dungeon marker

	# Draw player (on top)
	var player_px = Vector2i(
		int((player_pos.x - view_min_x) / tiles_per_pixel),
		int((player_pos.y - view_min_y) / tiles_per_pixel)
	)
	_draw_marker(player_px, Color.BLACK, 5)  # Outline
	_draw_marker(player_px, Color.WHITE, 4)
	_draw_marker(player_px, Color.YELLOW, 3)

	_finalize_map_texture()


func _generate_world_map() -> void:
	## Renders the entire island using cached base image for performance
	if not MapManager.current_map:
		return

	# Ensure world base image is cached
	_ensure_world_base_cached()

	if not cached_world_base_image:
		return

	# Copy cached base image
	map_image = cached_world_base_image.duplicate()

	# Calculate how many world tiles each pixel represents
	var tiles_per_pixel: float = float(island_width_tiles) / float(MAP_IMAGE_SIZE)

	# Get special feature positions
	var town_pos = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	var player_pos = EntityManager.player.position if EntityManager.player else Vector2i(-1, -1)
	var dungeon_entrances: Array = MapManager.current_map.get_meta("dungeon_entrances", [])

	# Draw town (as a larger marker with outline)
	if town_pos != Vector2i(-1, -1):
		var town_px = _world_to_map_pixel(town_pos, tiles_per_pixel)
		_draw_marker(town_px, Color.BLACK, 7)  # Outline
		_draw_marker(town_px, Color(1.0, 0.9, 0.5), 5)  # Town marker

	# Draw dungeon entrances with outlines
	for entrance in dungeon_entrances:
		var entrance_pos = entrance.position
		var entrance_px = _world_to_map_pixel(entrance_pos, tiles_per_pixel)
		var color = Color.html(entrance.entrance_color)
		_draw_marker(entrance_px, Color.BLACK, 6)  # Outline
		_draw_marker(entrance_px, color, 4)  # Dungeon marker

	# Draw player (on top with outline)
	if player_pos != Vector2i(-1, -1):
		var player_px = _world_to_map_pixel(player_pos, tiles_per_pixel)
		_draw_marker(player_px, Color.BLACK, 5)  # Outline
		_draw_marker(player_px, Color.WHITE, 4)
		_draw_marker(player_px, Color.YELLOW, 3)

	_finalize_map_texture()


func _ensure_world_base_cached() -> void:
	## Generate and cache the world base image if not already cached or seed changed
	if cached_world_base_image != null and cached_world_seed == GameManager.world_seed:
		return  # Already cached for this world

	# Generate fresh world base image
	cached_world_base_image = Image.create(MAP_IMAGE_SIZE, MAP_IMAGE_SIZE, false, Image.FORMAT_RGBA8)
	cached_world_base_image.fill(Color(0.1, 0.2, 0.4, 1.0))  # Ocean blue background

	var tiles_per_pixel: float = float(island_width_tiles) / float(MAP_IMAGE_SIZE)

	# Draw biome colors for entire island
	for py in range(MAP_IMAGE_SIZE):
		for px in range(MAP_IMAGE_SIZE):
			var world_x = int(px * tiles_per_pixel)
			var world_y = int(py * tiles_per_pixel)

			var biome = BiomeGenerator.get_biome_at(world_x, world_y, GameManager.world_seed)
			var color = _get_biome_map_color(biome.biome_name)
			cached_world_base_image.set_pixel(px, py, color)

	cached_world_seed = GameManager.world_seed


func _finalize_map_texture() -> void:
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


func _get_tile_color(tile) -> Color:
	## Get color for a specific tile (used in Area view)
	if not tile:
		return Color(0.1, 0.1, 0.15)

	match tile.ascii_char:
		".":
			return Color(0.25, 0.25, 0.22)  # Floor/dirt
		"T":
			return Color(0.15, 0.35, 0.15)  # Tree
		"~":
			return Color(0.2, 0.4, 0.8)  # Water
		"#", "░":
			return Color(0.3, 0.3, 0.32)  # Wall
		"\"", ",":
			return Color(0.35, 0.5, 0.3)  # Grass
		"^":
			return Color(0.45, 0.42, 0.38)  # Rocky
		"*":
			return Color(0.75, 0.78, 0.82)  # Snow
		"·":
			return Color(0.4, 0.38, 0.35)  # Barren
		"≈":
			return Color(0.1, 0.25, 0.6)  # Deep water
		"▲":
			return Color(0.5, 0.5, 0.55)  # Mountain
		"◆":
			return Color(0.5, 0.5, 0.5)  # Rock
		"◊":
			return Color(0.55, 0.45, 0.35)  # Iron ore
		">", "<":
			return Color(0.0, 0.8, 0.8)  # Stairs
		"+":
			return Color(0.5, 0.35, 0.2)  # Door
		_:
			# Use tile color if set, otherwise default
			if tile.color != Color.WHITE:
				return tile.color
			return Color(0.3, 0.3, 0.3)


func _get_biome_map_color(biome_name: String) -> Color:
	# Muted colors so markers stand out better
	match biome_name:
		"ocean", "deep_ocean":
			return Color(0.12, 0.18, 0.32)
		"beach":
			return Color(0.55, 0.52, 0.42)
		"grassland":
			return Color(0.32, 0.45, 0.28)
		"woodland":
			return Color(0.22, 0.35, 0.22)
		"forest":
			return Color(0.15, 0.28, 0.15)
		"rainforest":
			return Color(0.12, 0.25, 0.12)
		"swamp", "marsh":
			return Color(0.25, 0.30, 0.22)
		"mountains":
			return Color(0.38, 0.38, 0.40)
		"snow_mountains":
			return Color(0.55, 0.55, 0.60)
		"snow", "tundra":
			return Color(0.60, 0.62, 0.65)
		"rocky_hills":
			return Color(0.35, 0.32, 0.28)
		"barren_rock":
			return Color(0.28, 0.25, 0.22)
		_:
			return Color(0.28, 0.38, 0.28)


func _populate_legend() -> void:
	# Clear existing legend items
	for child in legend_container.get_children():
		child.queue_free()

	var player_pos = EntityManager.player.position if EntityManager.player else Vector2i(-1, -1)

	# Add view-specific legend items
	match current_level:
		MapLevel.AREA:
			_add_legend_header("Loaded Area")
			if player_pos != Vector2i(-1, -1):
				_add_legend_item(Color.YELLOW, "You (%d,%d)" % [player_pos.x, player_pos.y])
			_add_town_and_dungeons_to_legend()
			_add_legend_item(Color(0.5, 0.7, 0.3), "Grass")
			_add_legend_item(Color(0.1, 0.4, 0.15), "Trees")
			_add_legend_item(Color(0.3, 0.5, 0.9), "Water")

		MapLevel.REGION:
			_add_legend_header("Region View")
			if player_pos != Vector2i(-1, -1):
				_add_legend_item(Color.YELLOW, "You (%d,%d)" % [player_pos.x, player_pos.y])
			_add_town_and_dungeons_to_legend()

		MapLevel.WORLD:
			_add_legend_header("World Overview")
			if player_pos != Vector2i(-1, -1):
				_add_legend_item(Color.YELLOW, "You (%d,%d)" % [player_pos.x, player_pos.y])
			_add_town_and_dungeons_to_legend()


func _add_legend_header(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	legend_container.add_child(label)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	legend_container.add_child(sep)


func _add_town_and_dungeons_to_legend() -> void:
	var town_pos = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1)) if MapManager.current_map else Vector2i(-1, -1)
	if town_pos != Vector2i(-1, -1):
		_add_legend_item(Color(1.0, 0.9, 0.5), "Town (%d,%d)" % [town_pos.x, town_pos.y])
	else:
		_add_legend_item(Color(1.0, 0.9, 0.5), "Town")

	# Add dungeon entrances to legend with coordinates
	var dungeon_entrances: Array = MapManager.current_map.get_meta("dungeon_entrances", []) if MapManager.current_map else []
	for entrance in dungeon_entrances:
		var color = Color.html(entrance.entrance_color)
		var pos: Vector2i = entrance.position
		var label_text = "%s (%d,%d)" % [entrance.name, pos.x, pos.y]
		_add_legend_item(color, label_text)


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
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(label)

	legend_container.add_child(hbox)
