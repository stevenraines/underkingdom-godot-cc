class_name BiomeGenerator

## BiomeGenerator - Generate biomes using elevation and moisture noise
##
## Uses dual Perlin noise layers to create varied, realistic biomes
## Based on Whittaker life zones and Red Blob Games polygon map generation

# Cached noise generators (reused across calls to avoid massive performance hit)
static var elevation_noise_cache: Dictionary = {}  # seed -> FastNoiseLite
static var moisture_noise_cache: Dictionary = {}   # seed -> FastNoiseLite

## Get or create cached elevation noise generator for a seed
static func _get_elevation_noise(seed_value: int) -> FastNoiseLite:
	if not elevation_noise_cache.has(seed_value):
		var config = BiomeManager.get_elevation_noise_config()
		var noise = FastNoiseLite.new()
		noise.seed = seed_value
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = config.get("frequency", 0.03)
		noise.fractal_octaves = config.get("octaves", 3)
		noise.fractal_lacunarity = config.get("lacunarity", 2.0)
		noise.fractal_gain = config.get("gain", 0.5)
		elevation_noise_cache[seed_value] = noise
	return elevation_noise_cache[seed_value]

## Get or create cached moisture noise generator for a seed
static func _get_moisture_noise(seed_value: int) -> FastNoiseLite:
	var config = BiomeManager.get_moisture_noise_config()
	var seed_offset = config.get("seed_offset", 1000)
	var moisture_seed = seed_value + seed_offset
	if not moisture_noise_cache.has(moisture_seed):
		var noise = FastNoiseLite.new()
		noise.seed = moisture_seed
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = config.get("frequency", 0.05)
		noise.fractal_octaves = config.get("octaves", 2)
		noise.fractal_lacunarity = config.get("lacunarity", 2.0)
		noise.fractal_gain = config.get("gain", 0.5)
		moisture_noise_cache[moisture_seed] = noise
	return moisture_noise_cache[moisture_seed]

## Cached coastline noise generator for irregular island shapes
static var coastline_noise_cache: Dictionary = {}  # seed -> FastNoiseLite

## Get or create cached coastline noise generator
static func _get_coastline_noise(seed_value: int) -> FastNoiseLite:
	if not coastline_noise_cache.has(seed_value):
		var config = BiomeManager.get_coastline_noise_config()
		var seed_offset = config.get("seed_offset", 5000)
		var noise = FastNoiseLite.new()
		noise.seed = seed_value + seed_offset
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = config.get("frequency", 0.008)
		noise.fractal_octaves = config.get("octaves", 4)
		noise.fractal_lacunarity = config.get("lacunarity", 2.0)
		noise.fractal_gain = config.get("gain", 0.5)
		coastline_noise_cache[seed_value] = noise
	return coastline_noise_cache[seed_value]

## Apply island falloff to create bounded landmass
## Based on Amit Patel's mapgen2: noise must exceed threshold that increases with distance
## This naturally creates a single connected landmass without outlying islands
## Formula: land where noise > (base_threshold + distance_weight * distance^exponent)
## Coastline noise is added to create irregular, organic coastlines
static func _apply_island_falloff(x: int, y: int, elevation: float, seed_value: int = 0) -> float:
	var island_settings = BiomeManager.get_island_settings()

	# Get island dimensions in tiles (chunks × chunk_size)
	var chunk_size = 32  # WorldChunk.CHUNK_SIZE
	var island_width = island_settings.get("width_chunks", 50) * chunk_size
	var island_height = island_settings.get("height_chunks", 50) * chunk_size

	# Get configurable shape parameters
	var land_threshold = island_settings.get("land_threshold", 0.3)
	var distance_weight = island_settings.get("distance_weight", 0.3)
	var distance_exponent = island_settings.get("distance_exponent", 2.0)  # Higher = more extreme at edges
	var coastline_amplitude = island_settings.get("coastline_amplitude", 0.3)  # How much noise affects coastline

	# Calculate center of island
	var center_x = island_width / 2.0
	var center_y = island_height / 2.0

	# Normalize coordinates to -1 to 1 range
	var nx = (float(x) - center_x) / (island_width / 2.0)
	var ny = (float(y) - center_y) / (island_height / 2.0)

	# Calculate base distance from center (0 at center, 1 at edges, >1 at corners)
	var distance = sqrt(nx * nx + ny * ny)

	# Add coastline noise to create irregular shape
	# This warps the distance value, creating bays and peninsulas
	var coastline_noise = _get_coastline_noise(seed_value)
	var noise_value = coastline_noise.get_noise_2d(float(x), float(y))
	# Noise affects distance more at the edges than at center
	var warped_distance = distance + noise_value * coastline_amplitude * distance

	# Apply exponent to make falloff more extreme at edges
	# Higher exponent = flatter in middle, steeper drop at edges
	var distance_factor = pow(warped_distance, distance_exponent)

	# Amit Patel's mapgen2 approach:
	# Point is land if: noise > (threshold + weight * distance^exponent)
	# This creates irregular coastlines but ensures connectivity because
	# the threshold increases with distance - points near center easily pass,
	# points at edges need very high noise values
	var required_threshold = land_threshold + distance_weight * distance_factor

	# If elevation (noise) exceeds the threshold, it's land
	# Scale the elevation based on how much it exceeds the threshold
	if elevation > required_threshold:
		# Normalize to 0-1 range above the threshold
		# Higher elevations = more inland = higher terrain
		var excess = elevation - required_threshold
		var max_excess = 1.0 - required_threshold
		if max_excess > 0:
			return excess / max_excess
		return 1.0
	else:
		# Below threshold = ocean
		# Create smooth transition near coastline
		var deficit = required_threshold - elevation
		var ocean_depth = deficit * 2.0  # Scale for visible ocean gradient
		return -ocean_depth  # Negative = ocean (will be clamped to ocean biome)


## Smoothstep helper for smooth interpolation
static func _smoothstep(x: float) -> float:
	x = clamp(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## Generate biome at world position
## Returns Dictionary with biome data loaded from JSON
static func get_biome_at(x: int, y: int, seed_value: int) -> Dictionary:
	# Get cached noise generators (massive performance improvement)
	var elevation_noise = _get_elevation_noise(seed_value)
	var moisture_noise = _get_moisture_noise(seed_value)

	# Get noise values and normalize from [-1, 1] to [0, 1]
	var elevation_raw = elevation_noise.get_noise_2d(float(x), float(y))
	var moisture_raw = moisture_noise.get_noise_2d(float(x), float(y))

	var elevation = (elevation_raw + 1.0) / 2.0
	var moisture = (moisture_raw + 1.0) / 2.0

	# Apply elevation curve to create more variation
	# This creates more ocean and more mountains, less "medium" elevation
	elevation = pow(elevation, 1.5)

	# Apply island falloff to create bounded landmass
	elevation = _apply_island_falloff(x, y, elevation, seed_value)

	# Lookup biome from elevation × moisture matrix (data-driven via BiomeManager)
	var biome_id = BiomeManager.get_biome_id_from_values(elevation, moisture)
	var biome_data = BiomeManager.get_biome(biome_id)

	# Return biome data as dictionary (compatible with existing code)
	# Convert color arrays to Color objects
	var floor_color_array = biome_data.get("color_floor", [0.4, 0.6, 0.3])
	var grass_color_array = biome_data.get("color_grass", [0.5, 0.7, 0.4])

	return {
		"biome_name": biome_data.get("id", "grassland"),
		"base_tile": biome_data.get("base_tile", "floor"),
		"grass_char": biome_data.get("grass_char", "\""),
		"tree_density": biome_data.get("tree_density", 0.05),
		"rock_density": biome_data.get("rock_density", 0.01),
		"color_floor": Color(floor_color_array[0], floor_color_array[1], floor_color_array[2]),
		"color_grass": Color(grass_color_array[0], grass_color_array[1], grass_color_array[2])
	}

## Get elevation value at position (for use in other systems)
static func get_elevation_at(x: int, y: int, seed_value: int) -> float:
	var noise = _get_elevation_noise(seed_value)
	var raw = noise.get_noise_2d(float(x), float(y))
	var normalized = (raw + 1.0) / 2.0
	var elevation = pow(normalized, 1.5)
	return _apply_island_falloff(x, y, elevation, seed_value)

## Get moisture value at position (for use in other systems)
static func get_moisture_at(x: int, y: int, seed_value: int) -> float:
	var noise = _get_moisture_noise(seed_value)
	var raw = noise.get_noise_2d(float(x), float(y))
	return (raw + 1.0) / 2.0

## Get blended biome data at position (smooths biome transitions)
## Samples nearby tiles and blends their densities for smoother transitions
static func get_blended_biome_data(x: int, y: int, seed_value: int) -> Dictionary:
	# Sample center biome
	var center_biome = get_biome_at(x, y, seed_value)

	# Sample 4 adjacent tiles for blending
	var blend_samples = [
		get_biome_at(x + 1, y, seed_value),
		get_biome_at(x - 1, y, seed_value),
		get_biome_at(x, y + 1, seed_value),
		get_biome_at(x, y - 1, seed_value)
	]

	# Calculate average densities (50% center, 50% average of neighbors)
	var total_tree_density = center_biome.tree_density * 0.5
	var total_rock_density = center_biome.rock_density * 0.5

	for sample in blend_samples:
		total_tree_density += sample.tree_density * 0.125  # 0.5 / 4 = 0.125
		total_rock_density += sample.rock_density * 0.125

	# Return blended data
	return {
		"biome": center_biome,
		"tree_density": total_tree_density,
		"rock_density": total_rock_density
	}
