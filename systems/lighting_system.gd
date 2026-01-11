class_name LightingSystem

## LightingSystem - Manages light sources and calculates illuminated areas
##
## Aggregates light from all sources: sun (time of day), player equipment,
## campfires, dungeon fixtures, and enemy-carried lights.
## Works with FOVSystem to determine what the player can actually see.

# Light source types
enum LightType {
	SUN,           # Ambient daylight
	TORCH,         # Carried torch (8 tile radius)
	LANTERN,       # Carried lantern (12 tile radius)
	CAMPFIRE,      # Structure fire (20 tile radius)
	BRAZIER,       # Fixed dungeon light (10 tile radius)
	GLOWING_MOSS,  # Natural dungeon light (3 tile radius)
	MAGICAL,       # Magical light source (10 tile radius)
	CANDLE,        # Weak light (2 tile radius)
}

# Light radius by type
const LIGHT_RADII: Dictionary = {
	LightType.SUN: 999,        # Infinite during day
	LightType.TORCH: 8,
	LightType.LANTERN: 12,
	LightType.CAMPFIRE: 20,
	LightType.BRAZIER: 10,
	LightType.GLOWING_MOSS: 3,
	LightType.MAGICAL: 10,
	LightType.CANDLE: 2,
}

# Cache for illuminated positions
static var illuminated_positions: Dictionary = {}  # Vector2i -> light_level (0.0-1.0)
static var light_sources: Array = []  # Array of {position: Vector2i, type: LightType, radius: int}
static var cache_dirty: bool = true
static var current_is_underground: bool = false  # Track if current map is underground (no sunlight)

## Set whether current map is underground (no sunlight)
static func set_underground(is_underground: bool) -> void:
	current_is_underground = is_underground

## Clear all light sources and mark cache dirty
static func clear_light_sources() -> void:
	light_sources.clear()
	cache_dirty = true

## Add a light source at position
static func add_light_source(position: Vector2i, type: LightType, custom_radius: int = -1) -> void:
	var radius = custom_radius if custom_radius > 0 else LIGHT_RADII.get(type, 5)
	light_sources.append({
		"position": position,
		"type": type,
		"radius": radius
	})
	cache_dirty = true

## Remove light source at position
static func remove_light_source(position: Vector2i) -> void:
	for i in range(light_sources.size() - 1, -1, -1):
		if light_sources[i].position == position:
			light_sources.remove_at(i)
	cache_dirty = true

## Get the effective sun light radius based on time of day and location
## Returns 0 in dungeons (no sun underground), 0 at night, full perception at day
## Pass is_underground=true for dungeons to disable sunlight
static func get_sun_light_radius(is_underground: bool = false) -> int:
	# No sunlight in dungeons/underground areas
	if is_underground:
		return 0

	var time = TurnManager.time_of_day
	match time:
		"day", "mid_day":
			return 999  # Sun illuminates everything in LOS
		"dawn", "dusk":
			return 15   # Reduced visibility at twilight
		"night", "midnight":
			return 0    # No sunlight at night
		_:
			return 999

## Check if a position is illuminated by any light source
## Returns light level 0.0 (dark) to 1.0 (bright)
static func get_light_level_at(position: Vector2i) -> float:
	# Check sun first (overworld during day) - use tracked underground state
	var sun_radius = get_sun_light_radius(current_is_underground)
	if sun_radius >= 999:
		return 1.0  # Full daylight

	# Check all light sources
	var max_light: float = 0.0

	for source in light_sources:
		var dist = _chebyshev_distance(position, source.position)
		if dist <= source.radius:
			# Light falls off with distance
			var falloff = 1.0 - (float(dist) / float(source.radius + 1))
			max_light = max(max_light, falloff)

	# Add partial sun light at dawn/dusk (only on surface)
	if not current_is_underground and sun_radius > 0 and sun_radius < 999:
		# Dawn/dusk provides ambient light that adds to other sources
		max_light = max(max_light, 0.3)

	return max_light

## Check if a position is illuminated (light level > 0)
static func is_illuminated(position: Vector2i) -> bool:
	return get_light_level_at(position) > 0.0

## Calculate all illuminated positions within a range of the player
## This is more efficient than checking every tile individually
static func calculate_illuminated_area(center: Vector2i, max_range: int) -> Dictionary:
	illuminated_positions.clear()

	# Check sun first
	var sun_radius = get_sun_light_radius()
	if sun_radius >= 999:
		# Daylight - everything is illuminated
		for dy in range(-max_range, max_range + 1):
			for dx in range(-max_range, max_range + 1):
				var pos = center + Vector2i(dx, dy)
				illuminated_positions[pos] = 1.0
		return illuminated_positions

	# Night or twilight - calculate from light sources
	for source in light_sources:
		var source_pos = source.position
		var radius = source.radius

		# Only process sources that could affect visible area
		var dist_to_center = _chebyshev_distance(source_pos, center)
		if dist_to_center > max_range + radius:
			continue

		# Add illuminated positions from this source
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var pos = source_pos + Vector2i(dx, dy)
				var dist = _chebyshev_distance(pos, source_pos)
				if dist <= radius:
					var falloff = 1.0 - (float(dist) / float(radius + 1))
					var current = illuminated_positions.get(pos, 0.0)
					illuminated_positions[pos] = max(current, falloff)

	# Add ambient twilight light at dawn/dusk
	if sun_radius > 0 and sun_radius < 999:
		for dy in range(-max_range, max_range + 1):
			for dx in range(-max_range, max_range + 1):
				var pos = center + Vector2i(dx, dy)
				var current = illuminated_positions.get(pos, 0.0)
				illuminated_positions[pos] = max(current, 0.3)

	return illuminated_positions

## Get light sources near a position (for rendering light effects)
static func get_nearby_light_sources(position: Vector2i, range: int) -> Array:
	var nearby: Array = []
	for source in light_sources:
		if _chebyshev_distance(position, source.position) <= range:
			nearby.append(source)
	return nearby

## Chebyshev distance (max of dx, dy) - used for light calculations
static func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

## Get player's light radius from equipped items
## Returns 0 if no light source equipped
static func get_player_light_radius(player: Entity) -> int:
	if not player or not player.has_method("get_equipped_item"):
		return 0

	# Check off-hand for light source first
	var off_hand = player.get_equipped_item("off_hand")
	if off_hand and off_hand.has("provides_light") and off_hand.provides_light:
		return off_hand.get("light_radius", 5)

	# Check main hand (torch can be wielded)
	var main_hand = player.get_equipped_item("main_hand")
	if main_hand and main_hand.has("provides_light") and main_hand.provides_light:
		return main_hand.get("light_radius", 5)

	# Check accessory slots for magical light sources
	for slot in ["accessory_1", "accessory_2"]:
		var accessory = player.get_equipped_item(slot)
		if accessory and accessory.has("provides_light") and accessory.provides_light:
			return accessory.get("light_radius", 3)

	return 0

## Check if an enemy should carry a light source
## Humanoid enemies with INT > 5 carry lights in darkness
static func enemy_should_carry_light(enemy: Entity) -> bool:
	if not enemy:
		return false

	# Only in darkness (night, or dungeons)
	var sun_radius = get_sun_light_radius()
	if sun_radius >= 999:
		return false  # Daytime, no need for lights

	# Check if humanoid with INT > 5
	var is_humanoid = enemy.is_humanoid if "is_humanoid" in enemy else false
	var intelligence = enemy.attributes.get("INT", 1) if "attributes" in enemy else 1

	return is_humanoid and intelligence > 5

## Get the light type an enemy would carry
static func get_enemy_light_type() -> LightType:
	# Enemies typically carry torches or candles
	return LightType.TORCH
