class_name VisibilitySystem

## VisibilitySystem - Unified FOV and Lighting Visibility
##
## Single authoritative visibility calculation that combines:
## - Line-of-sight checks (Bresenham with diagonal blocking)
## - Light propagation from all sources
## - Time-of-day ambient lighting
##
## Replaces separate FOV shadowcasting + lighting + renderer LOS checks
## with a single calculation that all systems use.

# Visibility result structure
class VisibilityResult:
	var visible_tiles: Array[Vector2i] = []  # Tiles player can see
	var tile_data: Dictionary = {}  # pos -> {lit: bool, light_level: float, in_los: bool}

# Cache for visibility calculations
static var cached_result: VisibilityResult = null
static var cache_origin: Vector2i = Vector2i(-1, -1)
static var cache_perception_range: int = -1
static var cache_player_light_radius: int = -1
static var cache_light_sources_hash: int = 0
static var cache_time_of_day: String = ""
static var cache_map_id: String = ""
static var cache_dirty: bool = true

## Calculate visible tiles with integrated lighting
## This is the ONLY visibility calculation needed - all systems use this result
static func calculate_visibility(
	origin: Vector2i,
	perception_range: int,
	player_light_radius: int,
	map,
	light_sources: Array = []
) -> VisibilityResult:

	if not map:
		return VisibilityResult.new()

	var map_id = map.map_id if map else ""
	var current_time = TurnManager.time_of_day if TurnManager else "day"
	var lights_hash = _hash_light_sources(light_sources)

	# Check cache
	if (cache_origin == origin and
		cache_perception_range == perception_range and
		cache_player_light_radius == player_light_radius and
		cache_light_sources_hash == lights_hash and
		cache_time_of_day == current_time and
		cache_map_id == map_id and
		not cache_dirty and
		cached_result != null):
		return cached_result

	var result = VisibilityResult.new()

	# FAST PATH: Daytime outdoors - all exterior tiles visible without LOS
	var is_daytime_outdoors = _is_daytime_outdoors(map, current_time)
	if is_daytime_outdoors:
		result = _calculate_daytime_visibility(origin, perception_range, map)
	else:
		# STANDARD PATH: Night/dungeons - use LOS + lighting
		result = _calculate_los_and_lighting_visibility(
			origin,
			perception_range,
			player_light_radius,
			map,
			light_sources,
			current_time
		)

	# Update cache
	cached_result = result
	cache_origin = origin
	cache_perception_range = perception_range
	cache_player_light_radius = player_light_radius
	cache_light_sources_hash = lights_hash
	cache_time_of_day = current_time
	cache_map_id = map_id
	cache_dirty = false

	return result

## Invalidate cache (call when map changes or light sources change)
static func invalidate_cache() -> void:
	cache_dirty = true

## Check if it's daytime on overworld (fast path)
static func _is_daytime_outdoors(map, time_of_day: String) -> bool:
	if not map or map.chunk_based == false:  # Dungeons are not chunk-based
		return false
	return time_of_day == "day"

## Fast path: daytime overworld visibility
## During day, exterior tiles are visible without limit - renderer handles chunks
## Return minimal data - renderer will handle the rest
static func _calculate_daytime_visibility(origin: Vector2i, perception_range: int, map) -> VisibilityResult:
	var result = VisibilityResult.new()

	# During daytime, mark origin as visible (fog of war needs at least this)
	result.visible_tiles.append(origin)
	result.tile_data[origin] = {"lit": true, "light_level": 1.0, "in_los": true}

	# For interior tiles within perception range, check LOS
	# Exterior tiles don't need to be in the list - renderer allows all during day
	for dx in range(-perception_range, perception_range + 1):
		for dy in range(-perception_range, perception_range + 1):
			var pos = origin + Vector2i(dx, dy)
			if pos == origin:
				continue  # Already added

			var dist_sq = dx * dx + dy * dy
			if dist_sq > perception_range * perception_range:
				continue

			var tile = map.get_tile(pos)
			if not tile:
				continue

			# Only add interior tiles to the visible set (they need LOS check)
			# Exterior tiles are implicitly visible during day
			if tile.is_interior:
				if _has_line_of_sight(origin, pos, map):
					result.visible_tiles.append(pos)
					result.tile_data[pos] = {"lit": true, "light_level": 1.0, "in_los": true}

	return result

## Standard path: LOS-based visibility with lighting
static func _calculate_los_and_lighting_visibility(
	origin: Vector2i,
	perception_range: int,
	player_light_radius: int,
	map,
	light_sources: Array,
	time_of_day: String
) -> VisibilityResult:
	var result = VisibilityResult.new()

	# Determine ambient light level (twilight has some ambient light)
	var ambient_light = 0.0
	if time_of_day == "dusk" or time_of_day == "dawn":
		ambient_light = 0.3

	# Get all tiles in perception circle
	var tiles_in_range: Array[Vector2i] = []
	for dx in range(-perception_range, perception_range + 1):
		for dy in range(-perception_range, perception_range + 1):
			var pos = origin + Vector2i(dx, dy)
			var dist_sq = dx * dx + dy * dy
			if dist_sq <= perception_range * perception_range:
				tiles_in_range.append(pos)

	# Also include positions of all light sources that might be visible
	# (within player's light radius or close to perception range)
	var max_check_range = perception_range + player_light_radius
	for light_source in light_sources:
		var light_pos = light_source.position
		var dist = _chebyshev_distance(origin, light_pos)
		if dist <= max_check_range and not tiles_in_range.has(light_pos):
			tiles_in_range.append(light_pos)

	# For each tile in range, check LOS and calculate lighting
	for pos in tiles_in_range:
		# Player's own position is always visible
		if pos == origin:
			result.visible_tiles.append(pos)
			result.tile_data[pos] = {"lit": true, "light_level": 1.0, "in_los": true}
			continue

		# Check line of sight from player
		var has_los = _has_line_of_sight(origin, pos, map)

		if not has_los:
			# Can't see through walls
			continue

		# Calculate light level at this position
		var light_level = ambient_light

		# Add light from player's equipped light source
		if player_light_radius > 0:
			var dist = _chebyshev_distance(origin, pos)
			if dist <= player_light_radius:
				var falloff = 1.0 - (float(dist) / float(player_light_radius + 1))
				light_level = max(light_level, falloff)

		# Add light from map light sources (campfires, braziers, etc.)
		for light_source in light_sources:
			var light_pos = light_source.position
			var light_radius = light_source.radius

			# Check if light source can illuminate this tile
			var dist_to_light = _chebyshev_distance(light_pos, pos)
			if dist_to_light <= light_radius:
				# Check if light path is blocked by walls
				if _has_line_of_sight(light_pos, pos, map):
					var falloff = 1.0 - (float(dist_to_light) / float(light_radius + 1))
					light_level = max(light_level, falloff)

		# Tile is visible if it has any light
		if light_level > 0.0:
			result.visible_tiles.append(pos)
			result.tile_data[pos] = {"lit": true, "light_level": light_level, "in_los": has_los}

	return result

## Bresenham line-of-sight with diagonal blocking
## This is the ONLY LOS algorithm used - no shadowcasting, no redundant checks
static func _has_line_of_sight(from: Vector2i, to: Vector2i, map) -> bool:
	if not map:
		return false

	# Same position always has LOS
	if from == to:
		return true

	# Use Bresenham's line algorithm
	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var x = from.x
	var y = from.y
	var x_inc = 1 if to.x > from.x else -1
	var y_inc = 1 if to.y > from.y else -1
	var error = dx - dy

	dx *= 2
	dy *= 2

	var prev_x = x
	var prev_y = y

	# Check each tile along the line
	while true:
		# Don't check starting position, but do check ending position
		if Vector2i(x, y) != from:
			# Check if this tile blocks vision
			if not map.is_transparent(Vector2i(x, y)):
				return false

			# Check diagonal blocking: if we moved diagonally, both adjacent tiles must not be walls
			if x != prev_x and y != prev_y:
				var tile1_transparent = map.is_transparent(Vector2i(prev_x, y))
				var tile2_transparent = map.is_transparent(Vector2i(x, prev_y))
				# If both adjacent tiles are walls, diagonal is blocked
				if not tile1_transparent and not tile2_transparent:
					return false

		# Reached destination
		if x == to.x and y == to.y:
			break

		# Remember previous position
		prev_x = x
		prev_y = y

		# Step to next tile
		if error > 0:
			x += x_inc
			error -= dy
		else:
			y += y_inc
			error += dx

	return true

## Chebyshev distance (max of dx, dy) - used for circular ranges
static func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Hash light sources for cache validation
static func _hash_light_sources(light_sources: Array) -> int:
	var hash_value = 0
	for source in light_sources:
		var pos = source.position if "position" in source else Vector2i.ZERO
		var radius = source.radius if "radius" in source else 0
		hash_value = hash_value ^ (pos.x * 73856093) ^ (pos.y * 19349663) ^ (radius * 83492791)
	return hash_value
