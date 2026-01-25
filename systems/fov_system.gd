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
static var cache_light_radius: int = -1  # OPTIMIZATION: Cache player's light radius

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
	# Use dictionary for O(1) deduplication, then convert to array at the end
	var visible_set: Dictionary = {}

	# Adjust range based on time of day
	var adjusted_range = _adjust_range_for_time(range)

	# Origin is always visible
	visible_set[origin] = true

	# Calculate FOV for all 8 cardinal and diagonal directions
	for direction in 8:
		_scan_quadrant(origin, adjusted_range, direction, map, visible_set)

	# Convert to array for return
	var visible: Array[Vector2i] = []
	for pos in visible_set:
		visible.append(pos)

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
static func _scan_quadrant(origin: Vector2i, max_range: int, direction: int, map: GameMap, visible_set: Dictionary) -> void:
	var first_row = Row.new(1, -1.0, 1.0)
	_scan(origin, max_range, first_row, direction, map, visible_set)

## Recursive scanning function
## visible_set is a Dictionary for O(1) lookups (Vector2i -> true)
static func _scan(origin: Vector2i, max_range: int, row: Row, direction: int, map: GameMap, visible_set: Dictionary) -> void:
	var prev_tile_blocked = false

	for col in row.tiles():
		var tile_pos = transform_tile(origin, col, row.depth, direction)

		# Check if within map bounds (skip for chunk-based infinite maps)
		if not map.chunk_based:
			if tile_pos.x < 0 or tile_pos.x >= map.width or tile_pos.y < 0 or tile_pos.y >= map.height:
				continue

		# Check if within range using squared distance (avoid sqrt)
		var delta = tile_pos - origin
		var dist_squared = delta.x * delta.x + delta.y * delta.y
		if dist_squared > max_range * max_range:
			continue

		# Check if tile blocks vision
		var blocks_vision = not map.is_transparent(tile_pos)

		# If in bounds and in range, tile is visible (O(1) dictionary insert)
		visible_set[tile_pos] = true

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
				_scan(origin, max_range, next_row, direction, map, visible_set)

		prev_tile_blocked = blocks_vision

	# Continue to next row if last tile wasn't blocking
	if not prev_tile_blocked and row.depth < max_range:
		_scan(origin, max_range, row.next(), direction, map, visible_set)

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

## Fast FOV for daytime overworld - simple fill with wall occlusion
## Much faster than recursive shadowcasting when full visibility is needed
static func calculate_daytime_fov(origin: Vector2i, fov_range: int, map: GameMap) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []
	var range_squared = fov_range * fov_range

	# Simple square iteration - much faster than recursive shadowcasting
	for dx in range(-fov_range, fov_range + 1):
		for dy in range(-fov_range, fov_range + 1):
			# Check if within circular range (squared distance)
			if dx * dx + dy * dy > range_squared:
				continue

			var pos = origin + Vector2i(dx, dy)

			# Check wall occlusion via simple raycast
			if _is_blocked_by_wall(origin, pos, map):
				continue

			visible.append(pos)

	return visible

## Check if a wall blocks line of sight between two points (Bresenham's line)
static func _is_blocked_by_wall(from: Vector2i, to: Vector2i, map: GameMap) -> bool:
	# Same position is never blocked
	if from == to:
		return false

	var dx = abs(to.x - from.x)
	var dy = abs(to.y - from.y)
	var x = from.x
	var y = from.y
	var sx = 1 if from.x < to.x else -1
	var sy = 1 if from.y < to.y else -1
	var err = dx - dy

	while true:
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

		# Check if we reached the target
		if x == to.x and y == to.y:
			return false

		# Check if this intermediate tile blocks vision
		var check_pos = Vector2i(x, y)
		if not map.is_transparent(check_pos):
			return true

	return false

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
	# Get map info for cache validation
	var map_id = map.map_id if map else ""
	var current_time = TurnManager.time_of_day

	# OPTIMIZATION: Check if cached visibility is still valid
	# This prevents recalculation when player hasn't moved and conditions haven't changed
	if (origin == cache_origin and perception_range == cache_range and
	    light_radius == cache_light_radius and current_time == cache_time and
	    map_id == cache_map_id and not cache_dirty and not cached_visible.is_empty()):
		return cached_visible

	# DEBUG: If map reveal is enabled, return all tiles in a large area
	if GameManager.debug_map_revealed and map:
		var all_tiles: Array[Vector2i] = []
		var reveal_range = 100  # Large range to reveal everything nearby
		for x in range(origin.x - reveal_range, origin.x + reveal_range + 1):
			for y in range(origin.y - reveal_range, origin.y + reveal_range + 1):
				var pos = Vector2i(x, y)
				var tile = map.get_tile(pos)
				if tile:
					all_tiles.append(pos)
		var debug_map_id = map.map_id if map else ""
		var debug_chunk_based = map.chunk_based if map else false
		FogOfWarSystemClass.set_visible_tiles(all_tiles)
		FogOfWarSystemClass.mark_many_explored(debug_map_id, all_tiles, debug_chunk_based)
		cached_fov = all_tiles
		cached_visible = all_tiles
		cache_light_radius = light_radius
		return all_tiles

	# Get map info for fog of war (map_id already declared above for cache check)
	var chunk_based = map.chunk_based if map else false

	# Dungeons (non-chunk-based maps) have no sunlight - always require light sources
	var is_underground = not chunk_based

	# Set underground state in lighting system so is_illuminated() works correctly
	LightingSystemClass.set_underground(is_underground)

	# Check sun light (0 in dungeons, varies by time on overworld)
	var sun_radius = LightingSystemClass.get_sun_light_radius(is_underground)

	# Calculate FOV based on lighting conditions
	var los_tiles: Array[Vector2i]

	# SUPER FAST PATH: Daytime overworld - skip FOV calculation entirely
	# During daytime outdoors, all exterior tiles are visible without LOS calculation
	# The renderer handles showing exterior tiles and hiding interior tiles
	if sun_radius >= 999:
		# Return minimal array (just player origin) - renderer handles the rest
		var minimal: Array[Vector2i] = [origin]
		FogOfWarSystemClass.set_visible_tiles(minimal)
		# Don't mark tiles explored here - renderer will do it per visible tile
		cached_fov = minimal
		cached_visible = minimal
		cache_light_radius = light_radius
		return minimal

	# SLOW PATH: Night/dungeons - use full recursive shadowcasting
	los_tiles = calculate_fov(origin, perception_range, map)

	# Night/twilight/dungeon - need to check illumination from light sources
	# Use dictionary for O(1) deduplication
	var visible_set: Dictionary = {}

	# Player's own tile is always visible
	visible_set[origin] = true

	# Calculate illuminated area from light sources (pass map for wall checks)
	LightingSystemClass.calculate_illuminated_area(origin, perception_range, map)

	for tile_pos in los_tiles:
		# Check if illuminated by any light source (torches, braziers, etc.)
		var is_lit = LightingSystemClass.is_illuminated(tile_pos)

		# Player's equipped light source illuminates tiles in their LOS
		if not is_lit and light_radius > 0:
			var dist = _chebyshev_distance(origin, tile_pos)
			if dist <= light_radius:
				is_lit = true

		if is_lit:
			visible_set[tile_pos] = true

	# Convert to array for return and fog of war
	var visible_tiles: Array[Vector2i] = []
	for pos in visible_set:
		visible_tiles.append(pos)

	# Update fog of war
	FogOfWarSystemClass.set_visible_tiles(visible_tiles)
	FogOfWarSystemClass.mark_many_explored(map_id, visible_tiles, chunk_based)

	# Update cache (including light_radius for better cache validation)
	cached_visible = visible_tiles
	cache_light_radius = light_radius
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
	# Overworld maps are chunk-based, dungeons are not
	if not map.chunk_based:
		return false  # Dungeons always require LOS and light sources
	# Check if daytime (passing false for is_underground since we're on overworld)
	var sun_radius = LightingSystemClass.get_sun_light_radius(false)
	return sun_radius >= 999  # Full daylight

## Check if a specific tile should be terrain-visible during daytime outdoors
## This is more efficient than generating a huge array of all visible tiles
## Returns true if: daytime outdoors AND tile is not an interior tile
static func is_terrain_visible_at(pos: Vector2i, map: GameMap) -> bool:
	if not is_daytime_outdoors(map):
		return false  # Not daytime outdoors, use normal LOS visibility

	# Check if this is an interior tile - interiors require LOS even during daytime
	var tile = map.get_tile(pos)
	if tile and tile.is_interior:
		return false

	return true  # Outdoor tile during daytime - visible without LOS
