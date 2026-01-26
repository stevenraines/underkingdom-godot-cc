class_name FOVSystem

## FOVSystem - Field of View calculation (REFACTORED)
##
## Now delegates to VisibilitySystem for unified LOS + lighting calculations.
## This wrapper exists for backwards compatibility with existing code.
##
## Visibility requires BOTH:
## 1. Line of sight (calculated via Bresenham with diagonal blocking)
## 2. Illumination (from light sources)
##
## Both are now calculated together in VisibilitySystem for performance.

const VisibilitySystemClass = preload("res://systems/visibility_system.gd")
const LightingSystemClass = preload("res://systems/lighting_system.gd")
const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")

# Cache variables (kept for potential future use, but VisibilitySystem handles caching)
static var cache_dirty: bool = true

## Combined FOV + Lighting visibility calculation
## NOW DELEGATES TO VisibilitySystem - this is a backwards-compatibility wrapper
## Returns tiles that are currently visible (in LOS AND illuminated)
static func calculate_visibility(origin: Vector2i, perception_range: int, light_radius: int, map: GameMap) -> Array[Vector2i]:
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
		return all_tiles

	# Get light sources from lighting system
	var light_sources = LightingSystemClass.get_all_light_sources()

	# Delegate to unified visibility system
	var result = VisibilitySystemClass.calculate_visibility(
		origin,
		perception_range,
		light_radius,
		map,
		light_sources
	)

	# Update fog of war with visible tiles
	var map_id = map.map_id if map else ""
	var chunk_based = map.chunk_based if map else false
	FogOfWarSystemClass.set_visible_tiles(result.visible_tiles)
	FogOfWarSystemClass.mark_many_explored(map_id, result.visible_tiles, chunk_based)

	# Return just the visible tiles array for backwards compatibility
	return result.visible_tiles

## Invalidate FOV cache (call when map changes or tiles are modified)
static func invalidate_cache() -> void:
	cache_dirty = true
	VisibilitySystemClass.invalidate_cache()

## Check if a map is in "daytime outdoors" mode (used by renderer)
static func is_daytime_outdoors(map) -> bool:
	if not map or not map.chunk_based:
		return false
	var time_of_day = TurnManager.time_of_day if TurnManager else "day"
	return time_of_day == "day"
