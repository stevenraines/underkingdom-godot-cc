class_name CellularAutomataGenerator
extends BaseDungeonGenerator
## Cellular automata generator for organic cave systems
##
## Creates natural-looking caves through iterative cellular automata rules.
## Suitable for natural caves, caverns, and organic underground spaces.

## Generate a cave floor using cellular automata
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
	var fill_prob: float = _get_param(dungeon_def, "fill_probability", 0.45)
	var birth_limit: int = _get_param(dungeon_def, "birth_limit", 4)
	var death_limit: int = _get_param(dungeon_def, "death_limit", 3)
	var iterations: int = _get_param(dungeon_def, "iteration_count", 5)
	var smoothing: int = _get_param(dungeon_def, "smoothing_passes", 2)

	# Extract tile definitions
	var tiles: Dictionary = dungeon_def.get("tiles", {})
	var wall_tile: String = tiles.get("wall", "wall")
	var floor_tile: String = tiles.get("floor", "floor")

	# Create floor seed
	var floor_seed: int = _create_floor_seed(world_seed, dungeon_id, floor_number)
	var rng := SeededRandom.new(floor_seed)

	# Initialize map
	var map := GameMap.new()
	map.map_id = "%s_floor_%d" % [dungeon_id, floor_number]
	map.width = width
	map.height = height
	map.tiles = {}
	map.entities = []
	map.metadata = {
		"dungeon_id": dungeon_id,
		"floor_number": floor_number,
		"generator_type": "cellular_automata",
		"enemy_spawns": []
	}

	# Initialize tiles (dictionary uses Vector2i keys)
	for y in range(height):
		for x in range(width):
			map.tiles[Vector2i(x, y)] = GameTile.create(wall_tile)

	# Generate cave using cellular automata
	_initialize_random_cells(map, rng, fill_prob, wall_tile, floor_tile)
	_run_cellular_automata(map, iterations, birth_limit, death_limit, wall_tile, floor_tile)
	_smooth_caves(map, smoothing, wall_tile, floor_tile)
	_ensure_connectivity(map, floor_tile)

	# Place stairs
	_add_stairs(map, floor_number)

	# Spawn enemies
	_spawn_enemies(map, dungeon_def, floor_number, rng)

	# Place features and hazards
	_place_features_and_hazards(map, dungeon_def, rng)

	return map


## Initialize map with random walls and floors
func _initialize_random_cells(map: GameMap, rng: SeededRandom, fill_prob: float, wall_tile: String, floor_tile: String) -> void:
	for y in range(map.height):
		for x in range(map.width):
			var pos := Vector2i(x, y)
			# Edges are always walls
			if x == 0 or x == map.width - 1 or y == 0 or y == map.height - 1:
				map.tiles[pos] = GameTile.create(wall_tile)
			else:
				var is_wall: bool = rng.randf() < fill_prob
				map.tiles[pos] = GameTile.create(wall_tile if is_wall else floor_tile)


## Run cellular automata iterations
## birth_limit: A floor cell becomes a wall if it has >= this many wall neighbors
## death_limit: A wall cell becomes a floor if it has < this many wall neighbors
func _run_cellular_automata(map: GameMap, iterations: int, birth_limit: int, death_limit: int, wall_tile: String, floor_tile: String) -> void:
	for _i in range(iterations):
		var changes: Array = []

		for y in range(1, map.height - 1):
			for x in range(1, map.width - 1):
				var wall_count: int = _count_adjacent_walls(map, x, y)
				var current_is_wall: bool = not map.tiles[Vector2i(x, y)].walkable

				var should_be_wall: bool = false
				if current_is_wall:
					# Wall stays wall if it has enough wall neighbors (>= death_limit)
					# Otherwise it becomes floor (opens up caves)
					should_be_wall = wall_count >= death_limit
				else:
					# Floor becomes wall if surrounded by too many walls (>= birth_limit)
					should_be_wall = wall_count >= birth_limit

				changes.append({"x": x, "y": y, "is_wall": should_be_wall})

		# Apply changes
		for change in changes:
			var tile_type: String = wall_tile if change.is_wall else floor_tile
			map.tiles[Vector2i(change.x, change.y)] = GameTile.create(tile_type)


## Count walls adjacent to a position (8-directional)
func _count_adjacent_walls(map: GameMap, x: int, y: int) -> int:
	var count: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and nx < map.width and ny >= 0 and ny < map.height:
				if not map.tiles[Vector2i(nx, ny)].walkable:
					count += 1
	return count


## Smooth caves with additional passes using relaxed rules
func _smooth_caves(map: GameMap, smoothing_passes: int, wall_tile: String, floor_tile: String) -> void:
	for _i in range(smoothing_passes):
		_run_cellular_automata(map, 1, 5, 4, wall_tile, floor_tile)


## Ensure all floor areas are connected via flood fill
func _ensure_connectivity(map: GameMap, floor_tile: String) -> void:
	var regions: Array = _find_floor_regions(map)

	if regions.size() <= 1:
		return  # Already connected

	# Find largest region
	var largest_region: Array = regions[0]
	for region in regions:
		if region.size() > largest_region.size():
			largest_region = region

	for region in regions:
		if region == largest_region:
			continue
		_connect_regions(map, largest_region, region, floor_tile)


## Find all disconnected floor regions using flood fill
func _find_floor_regions(map: GameMap) -> Array:
	var visited: Dictionary = {}
	var regions: Array = []

	for y in range(map.height):
		for x in range(map.width):
			var pos := Vector2i(x, y)
			if map.tiles[pos].walkable and not visited.has(pos):
				var region: Array = []
				_flood_fill(map, x, y, visited, region)
				if region.size() > 0:
					regions.append(region)

	# Sort by size (largest first)
	regions.sort_custom(func(a, b): return a.size() > b.size())
	return regions


## Flood fill to find connected floor tiles
func _flood_fill(map: GameMap, start_x: int, start_y: int, visited: Dictionary, region: Array) -> void:
	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]

	while stack.size() > 0:
		var pos: Vector2i = stack.pop_back()

		if visited.has(pos):
			continue

		if pos.x < 0 or pos.x >= map.width or pos.y < 0 or pos.y >= map.height:
			continue

		if not map.tiles[pos].walkable:
			continue

		visited[pos] = true
		region.append(pos)

		# Add neighbors (4-directional)
		stack.append(Vector2i(pos.x + 1, pos.y))
		stack.append(Vector2i(pos.x - 1, pos.y))
		stack.append(Vector2i(pos.x, pos.y + 1))
		stack.append(Vector2i(pos.x, pos.y - 1))


## Connect two regions with a corridor
func _connect_regions(map: GameMap, region_a: Array, region_b: Array, floor_tile: String) -> void:
	# Find closest points between regions
	var min_dist: float = INF
	var best_a: Vector2i = region_a[0]
	var best_b: Vector2i = region_b[0]

	for pos_a in region_a:
		for pos_b in region_b:
			var dist: float = pos_a.distance_to(pos_b)
			if dist < min_dist:
				min_dist = dist
				best_a = pos_a
				best_b = pos_b

	# Carve corridor (L-shaped)
	var current: Vector2i = best_a

	# Horizontal
	while current.x != best_b.x:
		map.tiles[current] = GameTile.create(floor_tile)
		current.x += 1 if current.x < best_b.x else -1

	# Vertical
	while current.y != best_b.y:
		map.tiles[current] = GameTile.create(floor_tile)
		current.y += 1 if current.y < best_b.y else -1


## Place stairs in valid floor positions
func _add_stairs(map: GameMap, _floor_number: int) -> void:
	var floor_positions: Array[Vector2i] = []

	# Collect all floor positions
	for y in range(1, map.height - 1):
		for x in range(1, map.width - 1):
			var pos := Vector2i(x, y)
			if map.tiles[pos].walkable:
				floor_positions.append(pos)

	if floor_positions.size() < 2:
		return  # Not enough floor space

	# Shuffle to randomize stair placement
	floor_positions.shuffle()

	# Always place stairs up (floor 1 leads to overworld, deeper floors to previous floor)
	var up_pos: Vector2i = floor_positions[0]
	map.tiles[up_pos] = GameTile.create("stairs_up")
	map.metadata["stairs_up"] = up_pos

	# Place stairs down
	var down_pos: Vector2i = floor_positions[floor_positions.size() - 1]
	map.tiles[down_pos] = GameTile.create("stairs_down")
	map.metadata["stairs_down"] = down_pos


## Spawn enemies using data-driven system (spawn_dungeons + CR filtering)
## Falls back to legacy enemy_pools if no data-driven enemies found
func _spawn_enemies(map: GameMap, dungeon_def: Dictionary, floor_number: int, rng: SeededRandom) -> void:
	# Get floor positions for spawning
	var floor_positions: Array = _get_spawn_positions(map)

	# Try data-driven spawning first
	var spawned = _spawn_enemies_data_driven(map, dungeon_def, floor_number, floor_positions, rng)
	if spawned > 0:
		print("[CellularAutomataGenerator] Spawned %d enemies on floor %d" % [spawned, floor_number])
		return

	# Fallback to legacy enemy_pools
	_spawn_enemies_legacy(map, dungeon_def, floor_number, floor_positions, rng)


## Legacy enemy spawning using enemy_pools from dungeon JSON (backwards compatibility)
func _spawn_enemies_legacy(map: GameMap, dungeon_def: Dictionary, floor_number: int, floor_positions: Array, rng: SeededRandom) -> void:
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

	# Calculate spawn count based on difficulty curve
	var difficulty: Dictionary = dungeon_def.get("difficulty_curve", {})
	var base_count: int = difficulty.get("enemy_count_base", 5)
	var per_floor: float = difficulty.get("enemy_count_per_floor", 1.0)
	var spawn_count: int = int(base_count + floor_number * per_floor)

	var shuffled_positions = _seeded_shuffle(floor_positions, rng)
	var spawned: int = 0

	for pos in shuffled_positions:
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

		# Calculate enemy level with floor scaling
		var level_multiplier: float = difficulty.get("enemy_level_multiplier", 1.0)
		var enemy_level: int = max(1, int(floor_number * level_multiplier))

		# Store spawn data in metadata
		if not map.metadata.has("enemy_spawns"):
			map.metadata["enemy_spawns"] = []
		map.metadata.enemy_spawns.append({
			"enemy_id": chosen_enemy_id,
			"position": pos,
			"level": enemy_level
		})

		spawned += 1
