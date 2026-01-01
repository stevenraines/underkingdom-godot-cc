class_name WorldGenerator

## WorldGenerator - Generate overworld with biome-based terrain
##
## IMPORTANT: This generator is NOT used for the chunk-based overworld system.
## For chunk-based overworld:
##   - MapManager creates an empty shell map
##   - WorldChunk.generate() handles terrain generation on-demand
##   - SpecialFeaturePlacer handles dungeon/town placement
##
## This generator is kept for potential future static (non-chunk) maps.
## Uses dual-noise (elevation + moisture) for realistic biome generation.
## Creates a deterministic world based on seed.

const _GameTile = preload("res://maps/game_tile.gd")

## Generate the overworld map (STATIC VERSION - not used for chunk-based overworld)
## Only kept for potential future non-chunk static maps
static func generate_overworld(seed_value: int) -> GameMap:
	print("[WorldGenerator] Generating overworld with seed: %d" % seed_value)
	var rng = SeededRandom.new(seed_value)
	var map = GameMap.new("overworld", 80, 40, seed_value)

	# Generate terrain using biome system
	print("[WorldGenerator] Generating biome-based terrain...")
	for y in range(map.height):
		for x in range(map.width):
			# Get biome at this position
			var biome = BiomeGenerator.get_biome_at(x, y, seed_value)

			# Create base tile from biome
			var tile = _create_tile(biome.base_tile)

			# Override floor character and color for visual variety
			if biome.base_tile == "floor":
				tile.ascii_char = biome.grass_char

			map.set_tile(Vector2i(x, y), tile)

	# NOTE: Resource spawning removed for chunk-based maps
	# Resources are now spawned on-demand in WorldChunk.generate() for chunk-based overworld
	# This prevents duplicate spawning and improves performance
	# If this generator is ever used for static (non-chunk) maps, uncomment below:
	# ResourceSpawner.spawn_resources(map, seed_value)

	# Place dungeon entrance at a random walkable location
	var entrance_pos = _find_valid_location(map, rng)
	map.set_tile(entrance_pos, _create_tile("stairs_down"))
	print("Dungeon entrance placed at: ", entrance_pos)

	# Place a couple of water sources for harvesting
	for i in range(2):
		var water_pos = _find_valid_location(map, rng)
		map.set_tile(water_pos, _create_tile("water"))

	# Spawn overworld enemies (wolves in woodland biome)
	_spawn_overworld_enemies(map, rng)

	# Generate town with shop NPC
	var TownGenerator = load("res://generation/town_generator.gd")
	TownGenerator.generate_town(map, seed_value)

	print("Overworld generated (%dx%d) with biome system, seed: %d" % [map.width, map.height, seed_value])
	return map

## Create a tile by type (helper function)
## Uses _GameTile.create() to ensure all properties (including harvestable_resource_id) are set correctly
static func _create_tile(type: String) -> _GameTile:
	return _GameTile.create(type)

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
