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

## Spawn enemies on the overworld based on biome and town distance
static func _spawn_overworld_enemies(map: GameMap, rng: SeededRandom) -> void:
	# Calculate total map tiles
	var total_tiles = map.width * map.height

	# Get town positions for distance checking
	var town_positions: Array[Vector2i] = []
	var towns = TownManager.get_placed_towns()
	for town in towns:
		var pos = town.get("position", Vector2i(-1, -1))
		if pos is Array:
			pos = Vector2i(pos[0], pos[1])
		if pos != Vector2i(-1, -1):
			town_positions.append(pos)

	# Calculate base enemy count (roughly 1 enemy per 150 tiles)
	var base_enemy_count = int(total_tiles / 150.0)
	var variance = int(base_enemy_count * 0.25)
	var num_enemies = rng.randi_range(max(1, base_enemy_count - variance), base_enemy_count + variance)

	var spawned_count = 0
	var max_attempts = num_enemies * 10

	for _attempt in range(max_attempts):
		if spawned_count >= num_enemies:
			break

		var spawn_pos = _find_enemy_spawn_location(map, rng)
		if spawn_pos == Vector2i(-1, -1):
			continue

		# Get biome at spawn position
		var biome = BiomeGenerator.get_biome_at(spawn_pos.x, spawn_pos.y, map.seed)
		var biome_id = biome.get("id", "grassland")

		# Get valid enemies for this biome
		var weighted_enemies = EntityManager.get_weighted_enemies_for_biome(biome_id)
		if weighted_enemies.is_empty():
			continue

		# Calculate distance to nearest town
		var min_town_dist = _get_min_town_distance(spawn_pos, town_positions)

		# Filter enemies by min_distance_from_town
		var valid_enemies: Array = []
		for enemy_data in weighted_enemies:
			var min_dist_required = enemy_data.get("min_distance_from_town", 0)
			if min_town_dist >= min_dist_required:
				valid_enemies.append(enemy_data)

		if valid_enemies.is_empty():
			continue

		# Pick weighted random enemy from valid list
		var chosen_enemy_id = _pick_weighted_enemy(valid_enemies, rng)
		if chosen_enemy_id.is_empty():
			continue

		# Store enemy spawn data in map metadata
		if not map.has_meta("enemy_spawns"):
			map.set_meta("enemy_spawns", [])

		var spawns = map.get_meta("enemy_spawns")
		spawns.append({"enemy_id": chosen_enemy_id, "position": spawn_pos})
		map.set_meta("enemy_spawns", spawns)
		spawned_count += 1

	print("[WorldGenerator] Spawned %d overworld enemies" % spawned_count)

## Calculate minimum distance from a position to any town
static func _get_min_town_distance(pos: Vector2i, town_positions: Array[Vector2i]) -> float:
	if town_positions.is_empty():
		return 999.0

	var min_dist = 999.0
	for town_pos in town_positions:
		var dist = (pos - town_pos).length()
		if dist < min_dist:
			min_dist = dist
	return min_dist

## Pick a random enemy from weighted list
static func _pick_weighted_enemy(weighted_enemies: Array, rng: SeededRandom) -> String:
	var total_weight = 0.0
	for enemy_data in weighted_enemies:
		total_weight += enemy_data.get("weight", 1.0)

	var roll = rng.randf() * total_weight
	var cumulative = 0.0

	for enemy_data in weighted_enemies:
		cumulative += enemy_data.get("weight", 1.0)
		if roll <= cumulative:
			return enemy_data.get("enemy_id", "")

	return ""

## Find a valid enemy spawn location (walkable, not on dungeon entrance)
static func _find_enemy_spawn_location(map: GameMap, rng: SeededRandom) -> Vector2i:
	var max_attempts = 50

	for _attempt in range(max_attempts):
		var x = rng.randi_range(0, map.width - 1)
		var y = rng.randi_range(0, map.height - 1)
		var pos = Vector2i(x, y)

		var tile = map.get_tile(pos)

		# Check if position is valid (walkable floor, not stairs)
		if tile and tile.walkable and tile.tile_type == "floor":
			return pos

	return Vector2i(-1, -1)  # Failed to find position
