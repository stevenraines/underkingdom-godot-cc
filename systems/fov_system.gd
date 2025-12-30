class_name FOVSystem

## FOVSystem - Field of View calculation
##
## Calculates visible tiles based on player position and perception range.
## Uses simple radial distance check for Phase 1 (shadowcasting in future).

## Calculate field of view from origin position
static func calculate_fov(origin: Vector2i, range: int, map: GameMap) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []

	# Adjust range based on time of day
	var adjusted_range = _adjust_range_for_time(range)

	# Simple circle-based FOV (will be replaced with shadowcasting later)
	for dy in range(-adjusted_range, adjusted_range + 1):
		for dx in range(-adjusted_range, adjusted_range + 1):
			var pos = origin + Vector2i(dx, dy)

			# Check if within range (circular)
			if Vector2(dx, dy).length() <= adjusted_range:
				# Check if position is in bounds
				if pos.x >= 0 and pos.x < map.width and pos.y >= 0 and pos.y < map.height:
					# Simple visibility (TODO: add line-of-sight check)
					visible.append(pos)

	return visible

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
