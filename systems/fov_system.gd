class_name FOVSystem

## FOVSystem - Field of View calculation using recursive shadowcasting
##
## Implements symmetric shadowcasting algorithm for accurate line-of-sight.
## Based on: https://www.albertford.com/shadowcasting/
## Reference: https://www.roguebasin.com/index.php/FOV_using_recursive_shadowcasting
## Includes caching to avoid unnecessary recalculations
##
## Visibility requires BOTH:
## 1. Line of sight (calculated via shadowcasting)
## 2. Illumination (from LightingSystem)

const LightingSystemClass = preload("res://systems/lighting_system.gd")
const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")

# FOV cache variables
static var cached_fov: Array[Vector2i] = []
static var cached_visible: Array[Vector2i] = []  # FOV filtered by lighting
static var cache_origin: Vector2i = Vector2i(-999, -999)
static var cache_range: int = -1
static var cache_time: String = ""
static var cache_map_id: String = ""
static var cache_dirty: bool = true
static var cache_light_sources_hash: int = 0

## Row structure for shadowcasting algorithm
class Row:
	var depth: int
	var start_slope: float
	var end_slope: float

	func _init(d: int, start: float, end: float):
		depth = d
		start_slope = start
		end_slope = end

	func tiles() -> Array:
		var result = []
		var min_col = round_ties_up(start_slope * depth)
		var max_col = round_ties_down(end_slope * depth)
		for col in range(min_col, max_col + 1):
			result.append(col)
		return result

	func next() -> Row:
		return Row.new(depth + 1, start_slope, end_slope)

	## Rounding functions for slope calculations
	static func round_ties_up(n: float) -> int:
		return floori(n + 0.5)

	static func round_ties_down(n: float) -> int:
		return ceili(n - 0.5)

## Calculate field of view from origin position using shadowcasting (with caching)
static func calculate_fov(origin: Vector2i, range: int, map: GameMap) -> Array[Vector2i]:
	var current_time = TurnManager.time_of_day
	var current_map_id = map.map_id if map else ""

	# Check if cache is valid
	if origin == cache_origin and range == cache_range and current_time == cache_time and current_map_id == cache_map_id and not cache_dirty:
		# Cache hit - return cached result
		return cached_fov

	# Cache miss - recalculate
	var visible: Array[Vector2i] = []

	# Adjust range based on time of day
	var adjusted_range = _adjust_range_for_time(range)

	# Origin is always visible
	visible.append(origin)

	# Calculate FOV for all 8 cardinal and diagonal directions
	for direction in 8:
		_scan_quadrant(origin, adjusted_range, direction, map, visible)

	# Update cache
	cached_fov = visible
	cache_origin = origin
	cache_range = range
	cache_time = current_time
	cache_map_id = current_map_id
	cache_dirty = false

	return visible

## Invalidate FOV cache (call when map changes or tiles are modified)
static func invalidate_cache() -> void:
	cache_dirty = true

## Scan a single quadrant using recursive shadowcasting
static func _scan_quadrant(origin: Vector2i, max_range: int, direction: int, map: GameMap, visible: Array[Vector2i]) -> void:
	var first_row = Row.new(1, -1.0, 1.0)
	_scan(origin, max_range, first_row, direction, map, visible)

## Recursive scanning function
static func _scan(origin: Vector2i, max_range: int, row: Row, direction: int, map: GameMap, visible: Array[Vector2i]) -> void:
	var prev_tile_blocked = false

	for col in row.tiles():
		var tile_pos = transform_tile(origin, col, row.depth, direction)

		# Check if within map bounds (skip for chunk-based infinite maps)
		if not map.chunk_based:
			if tile_pos.x < 0 or tile_pos.x >= map.width or tile_pos.y < 0 or tile_pos.y >= map.height:
				continue

		# Check if within range
		var distance = (tile_pos - origin).length()
		if distance > max_range:
			continue

		# Check if tile blocks vision
		var blocks_vision = not map.is_transparent(tile_pos)

		# If in bounds and in range, tile is visible
		if not visible.has(tile_pos):
			visible.append(tile_pos)

		# Handle shadow propagation
		if prev_tile_blocked:
			# Previous tile blocked vision
			if blocks_vision:
				# Current tile also blocks, continue in shadow
				pass
			else:
				# Current tile is transparent, update start slope
				row.start_slope = _slope(col)
		else:
			# Previous tile was transparent
			if blocks_vision and row.depth < max_range:
				# Current tile blocks, create shadow
				var next_row = row.next()
				next_row.end_slope = _slope(col)
				_scan(origin, max_range, next_row, direction, map, visible)

		prev_tile_blocked = blocks_vision

	# Continue to next row if last tile wasn't blocking
	if not prev_tile_blocked and row.depth < max_range:
		_scan(origin, max_range, row.next(), direction, map, visible)

## Calculate slope for shadowcasting
static func _slope(col: int) -> float:
	return (2.0 * float(col) - 1.0) / 2.0

## Transform tile coordinates based on quadrant direction
static func transform_tile(origin: Vector2i, col: int, depth: int, direction: int) -> Vector2i:
	match direction:
		0:  # North
			return Vector2i(origin.x + col, origin.y - depth)
		1:  # North-East
			return Vector2i(origin.x + depth, origin.y - col)
		2:  # East
			return Vector2i(origin.x + depth, origin.y + col)
		3:  # South-East
			return Vector2i(origin.x + col, origin.y + depth)
		4:  # South
			return Vector2i(origin.x - col, origin.y + depth)
		5:  # South-West
			return Vector2i(origin.x - depth, origin.y + col)
		6:  # West
			return Vector2i(origin.x - depth, origin.y - col)
		7:  # North-West
			return Vector2i(origin.x - col, origin.y - depth)
		_:
			return origin

## Adjust perception range based on time of day
static func _adjust_range_for_time(base_range: int) -> int:
	var time = TurnManager.time_of_day

	match time:
		"night":
			return int(base_range * 0.5)  # 50% reduction at night
		"dawn", "dusk":
			return int(base_range * 0.75)  # 25% reduction at dawn/dusk
		_:  # "day"
			return base_range

## Calculate visible tiles (FOV + lighting) and update fog of war
## This is the main function to call from game.gd
## Returns tiles that are currently visible (in LOS AND illuminated)
static func calculate_visibility(origin: Vector2i, perception_range: int, light_radius: int, map: GameMap) -> Array[Vector2i]:
	# First, calculate raw FOV (line of sight)
	var los_tiles = calculate_fov(origin, perception_range, map)

	# Get map info for fog of war
	var map_id = map.map_id if map else ""
	var chunk_based = map.chunk_based if map else false

	# During day, all LOS tiles are visible
	var sun_radius = LightingSystemClass.get_sun_light_radius()
	if sun_radius >= 999:
		# Full daylight - all tiles in LOS are visible
		FogOfWarSystemClass.set_visible_tiles(los_tiles)
		FogOfWarSystemClass.mark_many_explored(map_id, los_tiles, chunk_based)
		cached_visible = los_tiles
		return los_tiles

	# Night/twilight - need to check illumination
	var visible_tiles: Array[Vector2i] = []

	# Player's own tile is always visible
	visible_tiles.append(origin)

	# Calculate illuminated area
	LightingSystemClass.calculate_illuminated_area(origin, perception_range)

	for tile_pos in los_tiles:
		# Check if illuminated by any light source
		var is_lit = LightingSystemClass.is_illuminated(tile_pos)

		# Player's light source illuminates tiles in their LOS
		if not is_lit and light_radius > 0:
			var dist = _chebyshev_distance(origin, tile_pos)
			if dist <= light_radius:
				is_lit = true

		if is_lit:
			if not visible_tiles.has(tile_pos):
				visible_tiles.append(tile_pos)

	# Update fog of war
	FogOfWarSystemClass.set_visible_tiles(visible_tiles)
	FogOfWarSystemClass.mark_many_explored(map_id, visible_tiles, chunk_based)

	cached_visible = visible_tiles
	return visible_tiles

## Get the last calculated visible tiles
static func get_cached_visible() -> Array[Vector2i]:
	return cached_visible

## Chebyshev distance (max of dx, dy)
static func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Check if current conditions allow terrain-only visibility (daytime outdoors)
## When true, terrain is visible within perception range without LOS,
## but entities still require LOS to be seen
static func is_daytime_outdoors(map: GameMap) -> bool:
	if not map:
		return false
	# Overworld maps are chunk-based
	if not map.chunk_based:
		return false  # Dungeons always require LOS
	# Check if daytime
	var sun_radius = LightingSystemClass.get_sun_light_radius()
	return sun_radius >= 999  # Full daylight

## Get terrain visible tiles (all tiles within perception range during daytime outdoors)
## During daytime outdoors, terrain is visible without LOS checks
## Returns empty array if not daytime outdoors (fall back to normal visibility)
static func get_terrain_visible_tiles(origin: Vector2i, perception_range: int, map: GameMap) -> Array[Vector2i]:
	if not is_daytime_outdoors(map):
		return []  # Empty means use normal LOS-based visibility

	# During daytime outdoors, all terrain within perception range is visible
	var terrain_tiles: Array[Vector2i] = []
	var adjusted_range = _adjust_range_for_time(perception_range)

	for dx in range(-adjusted_range, adjusted_range + 1):
		for dy in range(-adjusted_range, adjusted_range + 1):
			var pos = origin + Vector2i(dx, dy)
			# Use chebyshev distance (square FOV) for consistent visibility
			if _chebyshev_distance(origin, pos) <= adjusted_range:
				terrain_tiles.append(pos)

	return terrain_tiles
