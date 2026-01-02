class_name GridTunnelsGenerator
extends BaseDungeonGenerator
## Grid-based tunnel generator for mining operations
##
## Creates structured mine tunnels with regular spacing, support beams,
## and ore veins. Suitable for abandoned mines and quarries.

## Generate a mine floor using grid tunnels
## @param dungeon_def: Dungeon definition from JSON
## @param floor_number: Current floor number (1-based)
## @param world_seed: World seed for deterministic generation
## @returns: Generated GameMap instance
func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
	var dungeon_id: String = dungeon_def.get("id", "unknown")
	var map_size: Dictionary = dungeon_def.get("map_size", {"width": 50, "height": 50})
	var width: int = map_size.get("width", 50)
	var height: int = map_size.get("height", 50)

	# Extract generation parameters from JSON
	var tunnel_spacing: int = _get_param(dungeon_def, "tunnel_spacing", 5)
	var _shaft_freq: float = _get_param(dungeon_def, "shaft_frequency", 0.2)
	var _support_density: float = _get_param(dungeon_def, "support_beam_density", 0.3)
	var _ore_vein_count: int = _get_param(dungeon_def, "ore_vein_count", 3)

	# Extract tile definitions
	var tiles: Dictionary = dungeon_def.get("tiles", {})
	var wall_tile: String = tiles.get("wall", "wall")
	var floor_tile: String = tiles.get("floor", "floor")

	# Create floor seed
	var floor_seed: int = _create_floor_seed(world_seed, dungeon_id, floor_number)
	var rng := SeededRandom.new(floor_seed)

	# Initialize map with walls
	var map := GameMap.new()
	map.map_id = "%s_floor_%d" % [dungeon_id, floor_number]
	map.width = width
	map.height = height
	map.tiles = {}
	map.entities = []
	map.metadata = {
		"dungeon_id": dungeon_id,
		"floor_number": floor_number,
		"generator_type": "grid_tunnels",
		"enemy_spawns": []
	}

	# Fill with walls (dictionary uses Vector2i keys)
	for y in range(height):
		for x in range(width):
			map.tiles[Vector2i(x, y)] = GameTile.create(wall_tile)

	# Generate mine tunnels
	_carve_horizontal_tunnels(map, tunnel_spacing, floor_tile)
	_carve_vertical_tunnels(map, tunnel_spacing, floor_tile)
	_add_collapsed_sections(map, rng, wall_tile)

	# Place stairs
	_add_stairs(map, floor_number)

	# Spawn enemies
	_spawn_enemies(map, dungeon_def, floor_number, rng)

	# Place features and hazards
	_place_features_and_hazards(map, dungeon_def, rng)

	return map


## Carve horizontal mine tunnels at regular intervals
func _carve_horizontal_tunnels(map: GameMap, spacing: int, floor_tile: String) -> void:
	var y: int = spacing
	while y < map.height - spacing:
		for x in range(1, map.width - 1):
			# Carve 3-wide tunnel
			map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)
			if y > 0:
				map.tiles[Vector2i(x, y - 1)] = GameTile.create(floor_tile)
			if y < map.height - 1:
				map.tiles[Vector2i(x, y + 1)] = GameTile.create(floor_tile)
		y += spacing


## Carve vertical mine tunnels at regular intervals
func _carve_vertical_tunnels(map: GameMap, spacing: int, floor_tile: String) -> void:
	var x: int = spacing
	while x < map.width - spacing:
		for y in range(1, map.height - 1):
			# Carve 3-wide tunnel
			map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)
			if x > 0:
				map.tiles[Vector2i(x - 1, y)] = GameTile.create(floor_tile)
			if x < map.width - 1:
				map.tiles[Vector2i(x + 1, y)] = GameTile.create(floor_tile)
		x += spacing


## Add collapsed sections for variety (fills some areas with walls)
func _add_collapsed_sections(map: GameMap, rng: SeededRandom, wall_tile: String) -> void:
	var collapse_count: int = rng.randi_range(2, 5)

	for _i in range(collapse_count):
		var cx: int = rng.randi_range(5, map.width - 6)
		var cy: int = rng.randi_range(5, map.height - 6)

		# Fill 3×3 area with walls (rubble)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x: int = cx + dx
				var y: int = cy + dy
				if x > 0 and x < map.width and y > 0 and y < map.height:
					map.tiles[Vector2i(x, y)] = GameTile.create(wall_tile)


## Place stairs in valid floor positions
func _add_stairs(map: GameMap, _floor_number: int) -> void:
	var floor_positions: Array[Vector2i] = []

	# Collect walkable positions
	for y in range(map.height):
		for x in range(map.width):
			var pos := Vector2i(x, y)
			if map.tiles[pos].walkable:
				floor_positions.append(pos)

	if floor_positions.size() < 2:
		return

	floor_positions.shuffle()

	# Always place stairs up (floor 1 leads to overworld, deeper floors to previous floor)
	var up_pos: Vector2i = floor_positions[0]
	map.tiles[up_pos] = GameTile.create("stairs_up")
	map.metadata["stairs_up"] = up_pos

	# Place stairs down
	var down_pos: Vector2i = floor_positions[floor_positions.size() - 1]
	map.tiles[down_pos] = GameTile.create("stairs_down")
	map.metadata["stairs_down"] = down_pos


## Spawn enemies from dungeon definition enemy pools
func _spawn_enemies(map: GameMap, dungeon_def: Dictionary, floor_number: int, rng: SeededRandom) -> void:
	var enemy_pools: Array = dungeon_def.get("enemy_pools", [])
	if enemy_pools.is_empty():
		return

	# Filter enemy pools valid for this floor
	var valid_pools: Array = []
	for pool in enemy_pools:
		var floor_range: Array = pool.get("floor_range", [1, 999])
		if floor_number >= floor_range[0] and floor_number <= floor_range[1]:
			valid_pools.append(pool)

	if valid_pools.is_empty():
		return

	# Calculate spawn count
	var difficulty: Dictionary = dungeon_def.get("difficulty_curve", {})
	var base_count: int = difficulty.get("enemy_count_base", 5)
	var per_floor: float = difficulty.get("enemy_count_per_floor", 1.0)
	var spawn_count: int = int(base_count + floor_number * per_floor)

	# Collect walkable positions
	var floor_positions: Array[Vector2i] = []
	for y in range(map.height):
		for x in range(map.width):
			var pos := Vector2i(x, y)
			if map.tiles[pos].walkable and map.tiles[pos].tile_type not in ["stairs_up", "stairs_down"]:
				floor_positions.append(pos)

	floor_positions.shuffle()
	var spawned: int = 0

	for pos in floor_positions:
		if spawned >= spawn_count:
			break

		# Pick weighted random enemy
		var total_weight: float = 0.0
		for pool in valid_pools:
			total_weight += pool.get("weight", 1.0)

		var roll: float = rng.randf() * total_weight
		var cumulative: float = 0.0
		var chosen_enemy_id: String = ""

		for pool in valid_pools:
			cumulative += pool.get("weight", 1.0)
			if roll <= cumulative:
				chosen_enemy_id = pool.get("enemy_id", "")
				break

		if chosen_enemy_id.is_empty():
			continue

		if not EntityManager.has_enemy_definition(chosen_enemy_id):
			continue

		# Calculate enemy level
		var level_multiplier: float = difficulty.get("enemy_level_multiplier", 1.0)
		var enemy_level: int = max(1, int(floor_number * level_multiplier))

		# Store spawn data
		map.metadata.enemy_spawns.append({
			"enemy_id": chosen_enemy_id,
			"position": pos,
			"level": enemy_level
		})

		spawned += 1
