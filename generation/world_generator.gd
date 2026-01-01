class_name WorldGenerator

## WorldGenerator - Generate 100x100 overworld with temperate woodland biome
##
## Uses multiple layers of FastNoiseLite for terrain generation.
## Creates a deterministic world based on seed with distinct terrain regions.

const _GameTile = preload("res://maps/game_tile.gd")

# Map dimensions per PRD
const MAP_WIDTH = 100
const MAP_HEIGHT = 100

## Generate the overworld map
static func generate_overworld(seed_value: int) -> GameMap:
	print("[WorldGenerator] Generating overworld with seed: %d" % seed_value)
	var rng = SeededRandom.new(seed_value)
	var map = GameMap.new("overworld", MAP_WIDTH, MAP_HEIGHT, seed_value)

	# Create multiple noise layers for varied terrain
	var terrain_noise = _create_terrain_noise(seed_value)
	var forest_noise = _create_forest_noise(seed_value)
	var water_noise = _create_water_noise(seed_value)

	# Generate terrain based on layered noise
	for y in range(map.height):
		for x in range(map.width):
			var tile_type = _get_tile_from_noise(x, y, terrain_noise, forest_noise, water_noise, rng)
			map.set_tile(Vector2i(x, y), _create_tile(tile_type))

	# Create island border (water around edges for island feel)
	_create_island_border(map)

	# Place dungeon entrance at a random walkable location (away from edges)
	var entrance_pos = _find_valid_location(map, rng, 15)
	map.set_tile(entrance_pos, _create_tile("stairs_down"))
	print("Dungeon entrance placed at: ", entrance_pos)

	# Place harvestable resources at random locations using seeded RNG
	_place_resources(map, rng)

	# Spawn overworld enemies (wolves in woodland biome)
	_spawn_overworld_enemies(map, rng)

	# Generate town with shop NPCs
	var TownGenerator = load("res://generation/town_generator.gd")
	TownGenerator.generate_town(map, seed_value)

	print("Overworld generated (%dx%d) with seed: %d" % [MAP_WIDTH, MAP_HEIGHT, seed_value])
	return map

## Create main terrain noise (elevation-like)
static func _create_terrain_noise(seed_value: int) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	return noise

## Create forest density noise (where trees cluster)
static func _create_forest_noise(seed_value: int) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value + 1000  # Offset seed for variety
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.08
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	return noise

## Create water body noise (lakes and rivers)
static func _create_water_noise(seed_value: int) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed_value + 2000  # Different offset
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.04
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	return noise

## Determine tile type from combined noise layers
static func _get_tile_from_noise(x: int, y: int, terrain: FastNoiseLite, forest: FastNoiseLite, water: FastNoiseLite, _rng: SeededRandom) -> String:
	var terrain_val = (terrain.get_noise_2d(float(x), float(y)) + 1.0) / 2.0
	var forest_val = (forest.get_noise_2d(float(x), float(y)) + 1.0) / 2.0
	var water_val = water.get_noise_2d(float(x), float(y))

	# Water bodies form in cellular noise low points
	if water_val < -0.4:
		return "water"

	# Dense forest where forest noise is high
	if forest_val > 0.65:
		return "tree"

	# Medium forest density based on terrain
	if terrain_val < 0.35 and forest_val > 0.4:
		return "tree"

	# Scattered trees in clearings
	if forest_val > 0.5:
		# Use position-based randomness for determinism
		var hash_val = _position_hash(x, y)
		if hash_val < 0.15:
			return "tree"

	return "floor"

## Create water border around map edges for island effect
static func _create_island_border(map: GameMap) -> void:
	var border_size = 3

	for x in range(map.width):
		for y in range(map.height):
			var dist_to_edge = min(x, y, map.width - 1 - x, map.height - 1 - y)

			if dist_to_edge < border_size:
				# Fade probability: closer to edge = more likely water
				var water_chance = 1.0 - (float(dist_to_edge) / float(border_size))
				var hash_val = _position_hash(x, y)

				if hash_val < water_chance:
					map.set_tile(Vector2i(x, y), _create_tile("water"))

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
