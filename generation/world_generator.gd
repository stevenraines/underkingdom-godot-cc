class_name WorldGenerator

## WorldGenerator - Generate 100x100 overworld island with temperate woodland biome
##
## Uses multiple layers of FastNoiseLite combined with radial island mask.
## Creates a single cohesive island with natural shorelines.

const _GameTile = preload("res://maps/game_tile.gd")

# Map dimensions per PRD
const MAP_WIDTH = 100
const MAP_HEIGHT = 100

# Island shape parameters
const ISLAND_RADIUS = 0.42  # Proportion of map size for base island radius
const SHORE_BLEND = 0.15    # Width of the shore transition zone

## Generate the overworld map
static func generate_overworld(seed_value: int) -> GameMap:
	print("[WorldGenerator] Generating overworld island with seed: %d" % seed_value)
	var rng = SeededRandom.new(seed_value)
	var map = GameMap.new("overworld", MAP_WIDTH, MAP_HEIGHT, seed_value)

	# Create multiple noise layers for varied terrain
	var terrain_noise = _create_terrain_noise(seed_value)
	var forest_noise = _create_forest_noise(seed_value)
	var shore_noise = _create_shore_noise(seed_value)

	# Generate island terrain
	for y in range(map.height):
		for x in range(map.width):
			var tile_type = _get_island_tile(x, y, terrain_noise, forest_noise, shore_noise)
			map.set_tile(Vector2i(x, y), _create_tile(tile_type))

	# Place dungeon entrance at a random walkable location (away from edges)
	var entrance_pos = _find_valid_location(map, rng, 20)
	map.set_tile(entrance_pos, _create_tile("stairs_down"))
	print("Dungeon entrance placed at: ", entrance_pos)

	# Place harvestable resources at random locations using seeded RNG
	_place_resources(map, rng)

	# Spawn overworld enemies (wolves in woodland biome)
	_spawn_overworld_enemies(map, rng)

	# Generate town with shop NPCs (find valid location first)
	var TownGenerator = load("res://generation/town_generator.gd")
	TownGenerator.generate_town(map, seed_value)

	print("Overworld island generated (%dx%d) with seed: %d" % [MAP_WIDTH, MAP_HEIGHT, seed_value])
	return map

## Create main terrain noise (elevation-like)
static func _create_terrain_noise(seed_value: int) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.025
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	return noise

## Create forest density noise (where trees cluster)
static func _create_forest_noise(seed_value: int) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value + 1000  # Offset seed for variety
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.06
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	return noise

## Create shore variation noise (makes coastline irregular)
static func _create_shore_noise(seed_value: int) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value + 3000
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	return noise

## Calculate island mask value (0 = deep water, 1 = island center)
static func _get_island_mask(x: int, y: int, shore_noise: FastNoiseLite) -> float:
	# Normalize coordinates to -1 to 1 range centered on map
	var nx = (float(x) / float(MAP_WIDTH) - 0.5) * 2.0
	var ny = (float(y) / float(MAP_HEIGHT) - 0.5) * 2.0

	# Calculate distance from center (0 at center, 1 at corners)
	var dist = sqrt(nx * nx + ny * ny)

	# Add noise variation to shoreline
	var shore_variation = shore_noise.get_noise_2d(float(x), float(y)) * 0.15

	# Create gradient: 1 at center, 0 at edge
	# ISLAND_RADIUS determines base island size
	var mask = 1.0 - (dist / (ISLAND_RADIUS * 2.0 + shore_variation))

	return clamp(mask, 0.0, 1.0)

## Determine tile type using island mask and noise
static func _get_island_tile(x: int, y: int, terrain: FastNoiseLite, forest: FastNoiseLite, shore_noise: FastNoiseLite) -> String:
	var island_mask = _get_island_mask(x, y, shore_noise)

	# Deep water outside island
	if island_mask < 0.1:
		return "water"

	# Shallow water / beach transition
	if island_mask < 0.2:
		# Some variation in shoreline
		var hash_val = _position_hash(x, y)
		if hash_val < 0.4:
			return "water"
		return "floor"  # Beach/sand

	# Island interior - use terrain noise for variation
	var terrain_val = (terrain.get_noise_2d(float(x), float(y)) + 1.0) / 2.0
	var forest_val = (forest.get_noise_2d(float(x), float(y)) + 1.0) / 2.0

	# Interior lakes (only in center of island, low terrain)
	if island_mask > 0.5 and terrain_val < 0.25:
		return "water"

	# Dense forest where forest noise is high
	if forest_val > 0.6:
		return "tree"

	# More trees toward island center
	if forest_val > 0.4 and island_mask > 0.4:
		return "tree"

	# Scattered trees
	if forest_val > 0.35:
		var hash_val = _position_hash(x, y)
		if hash_val < 0.2:
			return "tree"

	return "floor"

## Simple position-based hash for deterministic randomness
static func _position_hash(x: int, y: int) -> float:
	var hash_val = sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
	return hash_val - floor(hash_val)

## Place harvestable resources
static func _place_resources(map: GameMap, rng: SeededRandom) -> void:
	# Place rocks (more on larger map)
	var num_rocks = rng.randi_range(8, 15)
	for i in range(num_rocks):
		var rock_pos = _find_valid_location(map, rng, 5)
		if rock_pos != Vector2i(-1, -1):
			map.set_tile(rock_pos, _create_tile("rock"))

## Create a tile by type (helper function)
## Uses _GameTile.create() to ensure all properties (including harvestable_resource_id) are set correctly
static func _create_tile(type: String) -> _GameTile:
	return _GameTile.create(type)

## Find a valid walkable location with configurable margin from edges
static func _find_valid_location(map: GameMap, rng: SeededRandom, margin: int = 10) -> Vector2i:
	# Try random positions until we find a walkable one
	var max_attempts = 1000
	for attempt in range(max_attempts):
		var x = rng.randi_range(margin, map.width - margin)
		var y = rng.randi_range(margin, map.height - margin)
		var pos = Vector2i(x, y)

		if map.is_walkable(pos):
			return pos

	# Fallback to center if no valid location found
	push_warning("Could not find valid location, using center")
	return Vector2i(map.width / 2, map.height / 2)

## Spawn enemies on the overworld
static func _spawn_overworld_enemies(map: GameMap, rng: SeededRandom) -> void:
	# Calculate total map tiles
	var total_tiles = map.width * map.height

	# Get wolf enemy data to read spawn density
	var wolf_data = EntityManager.get_enemy_definition("woodland_wolf")
	if wolf_data.is_empty():
		push_warning("WorldGenerator: woodland_wolf enemy data not found")
		return

	# Calculate number of enemies based on overworld spawn density
	# spawn_density_overworld is tiles per enemy (e.g., 100 = 1 enemy per 100 tiles)
	# If 0, this enemy doesn't spawn in overworld
	var spawn_density = wolf_data.get("spawn_density_overworld", 0)
	if spawn_density == 0:
		return  # Don't spawn this enemy in overworld

	var num_enemies = int(total_tiles / spawn_density)

	# Add some randomness (±25%)
	var variance = int(num_enemies * 0.25)
	num_enemies = rng.randi_range(max(1, num_enemies - variance), num_enemies + variance)

	for i in range(num_enemies):
		var spawn_pos = _find_enemy_spawn_location(map, rng)
		if spawn_pos != Vector2i(-1, -1):
			# Store enemy spawn data in map metadata
			if not map.has_meta("enemy_spawns"):
				map.set_meta("enemy_spawns", [])

			var spawns = map.get_meta("enemy_spawns")
			spawns.append({"enemy_id": "woodland_wolf", "position": spawn_pos})
			map.set_meta("enemy_spawns", spawns)

## Find a valid enemy spawn location (walkable, not on dungeon entrance)
static func _find_enemy_spawn_location(map: GameMap, rng: SeededRandom) -> Vector2i:
	var max_attempts = 50

	for attempt in range(max_attempts):
		var x = rng.randi_range(0, map.width - 1)
		var y = rng.randi_range(0, map.height - 1)
		var pos = Vector2i(x, y)

		var tile = map.get_tile(pos)

		# Check if position is valid (walkable floor, not stairs)
		if tile and tile.walkable and tile.tile_type == "floor":
			return pos

	return Vector2i(-1, -1)  # Failed to find position
