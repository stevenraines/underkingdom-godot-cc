class_name WorldGenerator

## WorldGenerator - Generate 100x100 overworld with temperate woodland biome
##
## Uses FastNoiseLite for terrain generation (Gaea optional for future).
## Creates a deterministic world based on seed.

const GameTile = preload("res://maps/game_tile.gd")

## Generate the overworld map
static func generate_overworld(seed_value: int) -> GameMap:
	var rng = SeededRandom.new(seed_value)
	var map = GameMap.new("overworld", 80, 40, seed_value)

	# Create noise generator for terrain
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05

	# Generate terrain based on noise
	for y in range(map.height):
		for x in range(map.width):
			var noise_val = noise.get_noise_2d(float(x), float(y))
			var tile_type = _biome_from_noise(noise_val, rng)
			map.set_tile(Vector2i(x, y), _create_tile(tile_type))

	# Place dungeon entrance at a random walkable location
	var entrance_pos = _find_valid_location(map, rng)
	map.set_tile(entrance_pos, _create_tile("stairs_down"))
	print("Dungeon entrance placed at: ", entrance_pos)

	# Place test harvestable resources near center for testing
	var center_x = map.width / 2
	var center_y = map.height / 2
	# Place a few rocks
	map.set_tile(Vector2i(center_x + 3, center_y + 2), _create_tile("rock"))
	map.set_tile(Vector2i(center_x - 4, center_y + 3), _create_tile("rock"))
	# Place water source
	map.set_tile(Vector2i(center_x + 2, center_y - 3), _create_tile("water"))
	map.set_tile(Vector2i(center_x + 3, center_y - 3), _create_tile("water"))

	# Spawn overworld enemies (wolves in woodland biome)
	_spawn_overworld_enemies(map, rng)

	# Generate town with shop NPC
	var TownGenerator = load("res://generation/town_generator.gd")
	TownGenerator.generate_town(map, seed_value)

	print("Overworld generated (20x20) with seed: ", seed_value)
	return map

## Map noise value to biome tile type (Temperate Woodland)
## Biome distribution: 60% floor, 30% trees, 5% water, 5% special
static func _biome_from_noise(noise_val: float, rng: SeededRandom) -> String:
	# Normalize noise from [-1, 1] to [0, 1]
	var normalized = (noise_val + 1.0) / 2.0

	# Use noise for terrain variation
	if normalized < 0.1:
		return "water"  # 10% water (ponds/streams)
	elif normalized < 0.4:
		return "tree"  # 30% trees
	else:
		# 60% walkable floor - add some variety
		var rand = rng.randf()
		if rand < 0.05:
			return "tree"  # Occasional extra tree
		else:
			return "floor"  # Grass/dirt

## Create a tile by type (helper function)
## Uses GameTile.create() to ensure all properties (including harvestable_resource_id) are set correctly
static func _create_tile(type: String) -> GameTile:
	return GameTile.create(type)

## Find a valid walkable location for dungeon entrance
static func _find_valid_location(map: GameMap, rng: SeededRandom) -> Vector2i:
	# Try random positions until we find a walkable one
	var max_attempts = 1000
	for attempt in range(max_attempts):
		var x = rng.randi_range(10, map.width - 10)
		var y = rng.randi_range(10, map.height - 10)
		var pos = Vector2i(x, y)

		if map.is_walkable(pos):
			return pos

	# Fallback to center if no valid location found
	push_warning("Could not find valid dungeon entrance location, using center")
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
