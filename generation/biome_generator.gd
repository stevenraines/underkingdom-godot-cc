class_name BiomeGenerator

## BiomeGenerator - Generate biomes using elevation and moisture noise
##
## Uses dual Perlin noise layers to create varied, realistic biomes
## Based on Whittaker life zones and Red Blob Games polygon map generation

## Generate biome at world position
## Returns BiomeDefinition for the given coordinates
static func get_biome_at(x: int, y: int, seed_value: int) -> BiomeDefinition:
	# Create elevation noise (slower-changing, more octaves for detail)
	var elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = seed_value
	elevation_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	elevation_noise.frequency = 0.03  # Larger features
	elevation_noise.fractal_octaves = 3  # More detail
	elevation_noise.fractal_lacunarity = 2.0
	elevation_noise.fractal_gain = 0.5

	# Create moisture noise (faster-changing, fewer octaves)
	var moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = seed_value + 1000  # Different seed for variation
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = 0.05  # Smaller features
	moisture_noise.fractal_octaves = 2
	moisture_noise.fractal_lacunarity = 2.0
	moisture_noise.fractal_gain = 0.5

	# Get noise values and normalize from [-1, 1] to [0, 1]
	var elevation_raw = elevation_noise.get_noise_2d(float(x), float(y))
	var moisture_raw = moisture_noise.get_noise_2d(float(x), float(y))

	var elevation = (elevation_raw + 1.0) / 2.0
	var moisture = (moisture_raw + 1.0) / 2.0

	# Apply elevation curve to create more variation
	# This creates more ocean and more mountains, less "medium" elevation
	elevation = pow(elevation, 1.5)

	# Lookup biome from elevation × moisture matrix
	return BiomeDefinition.get_biome(elevation, moisture)

## Get elevation value at position (for use in other systems)
static func get_elevation_at(x: int, y: int, seed_value: int) -> float:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.03
	noise.fractal_octaves = 3

	var raw = noise.get_noise_2d(float(x), float(y))
	var normalized = (raw + 1.0) / 2.0
	return pow(normalized, 1.5)

## Get moisture value at position (for use in other systems)
static func get_moisture_at(x: int, y: int, seed_value: int) -> float:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value + 1000
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	noise.fractal_octaves = 2

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
