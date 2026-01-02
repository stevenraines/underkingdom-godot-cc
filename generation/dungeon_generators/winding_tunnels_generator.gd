class_name WindingTunnelsGenerator
extends BaseDungeonGenerator
## Winding tunnels generator for sewer systems
##
## Creates realistic sewer networks with main trunk lines and branching tunnels.
## Suitable for urban sewers, underground waterways, and drainage systems.

## Generate a sewer floor with winding tunnels
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
	var tunnel_width: int = _get_param(dungeon_def, "tunnel_width", 3)
	var branching: float = _get_param(dungeon_def, "branching_factor", 0.4)

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
	map.tiles = []
	map.entities = []
	map.metadata = {
		"dungeon_id": dungeon_id,
		"floor_number": floor_number,
		"generator_type": "winding_tunnels",
		"enemy_spawns": []
	}

	# Fill with walls
	for y in range(height):
		var row: Array[GameTile] = []
		for x in range(width):
			row.append(GameTile.create(wall_tile))
		map.tiles.append(row)

	# Generate sewer system
	var main_path: Array = _generate_main_trunk(map, tunnel_width, floor_tile, rng)
	_add_branching_tunnels(map, main_path, branching, tunnel_width, floor_tile, rng)
	_add_alcoves(map, rng, floor_tile)

	# Place stairs
	_add_stairs(map, main_path, rng, floor_number)

	# Spawn enemies
	_spawn_enemies(map, dungeon_def, floor_number, rng)

	return map


## Generate main trunk line (central sewer line)
func _generate_main_trunk(map: GameMap, width: int, floor_tile: String, rng: SeededRandom) -> Array:
	var path: Array = []
	var half_width: int = width / 2

	# Create winding path from top to bottom
	var x: int = map.width / 2
	var y: int = 2

	while y < map.height - 2:
		# Carve tunnel segment
		for dy in range(width):
			for dx in range(-half_width, half_width + 1):
				var tx: int = x + dx
				var ty: int = y + dy

				if tx > 0 and tx < map.width - 1 and ty > 0 and ty < map.height - 1:
					map.tiles[ty][tx] = GameTile.create(floor_tile)
					path.append(Vector2i(tx, ty))

		# Random horizontal drift
		if rng.randf() < 0.3:
			x += rng.randi_range(-2, 2)
			x = clampi(x, width + 1, map.width - width - 1)

		y += width

	return path


## Add branching side tunnels
func _add_branching_tunnels(map: GameMap, main_path: Array, branching: float, width: int, floor_tile: String, rng: SeededRandom) -> void:
	var half_width: int = width / 2

	# Create side tunnels branching from main path
	for i in range(0, main_path.size(), 10):
		if rng.randf() < branching:
			var start_pos: Vector2i = main_path[i]

			# Choose random direction (left or right)
			var direction := Vector2i(
				rng.randi_range(-1, 1),
				0
			)

			if direction == Vector2i.ZERO:
				continue

			# Carve branch tunnel
			var length: int = rng.randi_range(5, 15)
			var current: Vector2i = start_pos

			for step in range(length):
				# Carve tunnel at current position
				for dy in range(-half_width, half_width + 1):
					for dx in range(-half_width, half_width + 1):
						var x: int = current.x + dx
						var y: int = current.y + dy

						if x > 0 and x < map.width - 1 and y > 0 and y < map.height - 1:
							map.tiles[y][x] = GameTile.create(floor_tile)

				current += direction * 2

				# Occasionally change direction
				if rng.randf() < 0.2:
					direction = Vector2i(
						rng.randi_range(-1, 1),
						rng.randi_range(-1, 1)
					)
					if direction == Vector2i.ZERO:
						direction = Vector2i(1, 0)


## Add small alcoves and side chambers
func _add_alcoves(map: GameMap, rng: SeededRandom, floor_tile: String) -> void:
	var alcove_count: int = rng.randi_range(3, 6)

	for i in range(alcove_count):
		var alcove_x: int = rng.randi_range(5, map.width - 6)
		var alcove_y: int = rng.randi_range(5, map.height - 6)
		var alcove_size: int = rng.randi_range(2, 4)

		# Only create alcove if adjacent to tunnel
		var adjacent_to_tunnel: bool = false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var check_x: int = alcove_x + dx
				var check_y: int = alcove_y + dy
				if check_x >= 0 and check_x < map.width and check_y >= 0 and check_y < map.height:
					if map.tiles[check_y][check_x].walkable:
						adjacent_to_tunnel = true
						break

		if adjacent_to_tunnel:
			# Carve small alcove
			for y in range(alcove_y, alcove_y + alcove_size):
				for x in range(alcove_x, alcove_x + alcove_size):
					if x >= 0 and x < map.width and y >= 0 and y < map.height:
						map.tiles[y][x] = GameTile.create(floor_tile)


## Place stairs along main path
func _add_stairs(map: GameMap, main_path: Array, rng: SeededRandom, floor_number: int) -> void:
	if main_path.is_empty():
		return

	# Place stairs up near start of path
	if floor_number > 1 and main_path.size() > 0:
		var up_idx: int = mini(10, main_path.size() - 1)
		var up_pos: Vector2i = main_path[up_idx]
		map.tiles[up_pos.y][up_pos.x] = GameTile.create("stairs_up")
		map.metadata["stairs_up"] = up_pos

	# Place stairs down near end of path
	if main_path.size() > 0:
		var down_idx: int = maxi(main_path.size() - 10, 0)
		var down_pos: Vector2i = main_path[down_idx]
		map.tiles[down_pos.y][down_pos.x] = GameTile.create("stairs_down")
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
			if map.tiles[y][x].walkable and map.tiles[y][x].tile_type not in ["stairs_up", "stairs_down"]:
				floor_positions.append(Vector2i(x, y))

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
