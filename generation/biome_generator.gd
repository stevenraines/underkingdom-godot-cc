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
		var noise = FastNoiseLite.new()
		noise.seed = seed_value
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.03  # Larger features
		noise.fractal_octaves = 3  # More detail
		noise.fractal_lacunarity = 2.0
		noise.fractal_gain = 0.5
		elevation_noise_cache[seed_value] = noise
	return elevation_noise_cache[seed_value]

## Get or create cached moisture noise generator for a seed
static func _get_moisture_noise(seed_value: int) -> FastNoiseLite:
	var moisture_seed = seed_value + 1000  # Different seed for variation
	if not moisture_noise_cache.has(moisture_seed):
		var noise = FastNoiseLite.new()
		noise.seed = moisture_seed
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.05  # Smaller features
		noise.fractal_octaves = 2
		noise.fractal_lacunarity = 2.0
		noise.fractal_gain = 0.5
		moisture_noise_cache[moisture_seed] = noise
	return moisture_noise_cache[moisture_seed]

## Apply island falloff to create bounded landmass
## Uses "Square Bump" distance + smooth reshaping for natural island shapes
## Based on Red Blob Games island generation techniques
static func _apply_island_falloff(x: int, y: int, elevation: float) -> float:
	var island_settings = BiomeManager.get_island_settings()

	# Get island dimensions in tiles (chunks × chunk_size)
	var chunk_size = 32  # WorldChunk.CHUNK_SIZE
	var island_width = island_settings.get("width_chunks", 50) * chunk_size
	var island_height = island_settings.get("height_chunks", 50) * chunk_size

	# Calculate center of island
	var center_x = island_width / 2.0
	var center_y = island_height / 2.0

	# Normalize coordinates to -1 to 1 range
	var nx = (float(x) - center_x) / (island_width / 2.0)
	var ny = (float(y) - center_y) / (island_height / 2.0)

	# Square Bump distance function (from Red Blob Games)
	# Creates more interesting shapes than simple Euclidean distance
	# d = 1 - (1-x²)(1-y²) - produces natural-looking coastlines
	var d = 1.0 - (1.0 - nx * nx) * (1.0 - ny * ny)

	# Clamp distance to valid range
	d = clamp(d, 0.0, 1.0)

	# Smooth reshaping function (quadratic Bezier-like)
	# Blends between original elevation and distance-based falloff
	# This preserves terrain variation in the middle while forcing ocean at edges
	# Formula: lerp(elevation, 1-d, smoothstep(d))
	var blend = _smoothstep(d)
	var target_elevation = 1.0 - d  # Higher in center, lower at edges

	# Mix original noise with distance-based elevation
	# More weight to noise in center, more weight to distance at edges
	var result = lerp(elevation, elevation * target_elevation, blend)

	# Apply additional falloff at very edges to ensure ocean
	if d > 0.7:
		var edge_falloff = (d - 0.7) / 0.3  # 0 to 1 in outer 30%
		result *= 1.0 - edge_falloff * edge_falloff

	return result


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
	elevation = _apply_island_falloff(x, y, elevation)

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
	return _apply_island_falloff(x, y, elevation)

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
