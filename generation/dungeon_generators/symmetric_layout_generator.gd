class_name SymmetricLayoutGenerator
extends BaseDungeonGenerator
## Symmetric layout generator for temple ruins
##
## Creates symmetrical sacred structures using mirroring.
## Suitable for temples, shrines, and sacred ruins.

## Generate a symmetrical temple floor
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
	var symmetry_axis: String = _get_param(dungeon_def, "symmetry_axis", "both")
	var chamber_count: int = _get_param(dungeon_def, "chamber_count", 4)
	var hallway_width: int = _get_param(dungeon_def, "hallway_width", 3)
	var sanctum_size: int = _get_param(dungeon_def, "sanctum_size", 10)

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
		"generator_type": "symmetric_layout",
		"enemy_spawns": []
	}

	# Fill with walls (dictionary uses Vector2i keys)
	for y in range(height):
		for x in range(width):
			map.tiles[Vector2i(x, y)] = GameTile.create(wall_tile)

	# Generate temple structure
	var center := Vector2i(width / 2, height / 2)
	_create_central_sanctum(map, center, sanctum_size, floor_tile)
	_generate_quadrant(map, center, chamber_count, floor_tile, rng)
	_apply_symmetry(map, center, symmetry_axis)
	_create_hallways(map, center, hallway_width, floor_tile)

	# Place stairs
	_add_stairs(map, center, floor_number)

	# Spawn enemies
	_spawn_enemies(map, dungeon_def, floor_number, rng)

	# Place features and hazards
	_place_features_and_hazards(map, dungeon_def, rng)

	return map


## Create central sanctum
func _create_central_sanctum(map: GameMap, center: Vector2i, size: int, floor_tile: String) -> void:
	var half_size: int = size / 2

	for y in range(center.y - half_size, center.y + half_size + 1):
		for x in range(center.x - half_size, center.x + half_size + 1):
			if x >= 0 and x < map.width and y >= 0 and y < map.height:
				map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)


## Generate chambers in one quadrant (will be mirrored)
func _generate_quadrant(map: GameMap, center: Vector2i, chamber_count: int, floor_tile: String, rng: SeededRandom) -> void:
	# Generate chambers in top-right quadrant only
	for _i in range(chamber_count):
		var chamber_size: int = rng.randi_range(4, 7)
		var chamber_x: int = center.x + rng.randi_range(5, 15)
		var chamber_y: int = center.y - rng.randi_range(5, 15)

		for y in range(chamber_y, chamber_y + chamber_size):
			for x in range(chamber_x, chamber_x + chamber_size):
				if x >= 0 and x < map.width and y >= 0 and y < map.height:
					map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)


## Apply symmetry based on axis parameter
func _apply_symmetry(map: GameMap, center: Vector2i, axis: String) -> void:
	match axis:
		"horizontal":
			_mirror_horizontal(map, center)
		"vertical":
			_mirror_vertical(map, center)
		"both":
			_mirror_horizontal(map, center)
			_mirror_vertical(map, center)


## Mirror top half to bottom half
func _mirror_horizontal(map: GameMap, center: Vector2i) -> void:
	for y in range(center.y):
		for x in range(map.width):
			var source_pos := Vector2i(x, y)
			var source_tile: GameTile = map.tiles[source_pos]
			var mirror_y: int = center.y + (center.y - y)

			if mirror_y >= 0 and mirror_y < map.height:
				# Create a copy of the tile
				map.tiles[Vector2i(x, mirror_y)] = GameTile.create(source_tile.tile_type)


## Mirror left half to right half
func _mirror_vertical(map: GameMap, center: Vector2i) -> void:
	for x in range(center.x):
		for y in range(map.height):
			var source_pos := Vector2i(x, y)
			var source_tile: GameTile = map.tiles[source_pos]
			var mirror_x: int = center.x + (center.x - x)

			if mirror_x >= 0 and mirror_x < map.width:
				# Create a copy of the tile
				map.tiles[Vector2i(mirror_x, y)] = GameTile.create(source_tile.tile_type)


## Create cross-shaped hallways connecting all areas
func _create_hallways(map: GameMap, center: Vector2i, hallway_width: int, floor_tile: String) -> void:
	@warning_ignore("integer_division")
	var half_width: int = hallway_width / 2

	# Horizontal hallway - but preserve 1-tile wall border
	for x in range(1, map.width - 1):
		for dy in range(-half_width, half_width + 1):
			var y: int = center.y + dy
			if y >= 1 and y < map.height - 1:
				map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)

	# Vertical hallway - but preserve 1-tile wall border
	for y in range(1, map.height - 1):
		for dx in range(-half_width, half_width + 1):
			var hallway_x: int = center.x + dx
			if hallway_x >= 1 and hallway_x < map.width - 1:
				map.tiles[Vector2i(hallway_x, y)] = GameTile.create(floor_tile)


## Place stairs
func _add_stairs(map: GameMap, center: Vector2i, _floor_number: int) -> void:
	# Place stairs near center
	# Always place stairs_up (floor 1 leads to overworld, deeper floors to previous floor)
	var up_pos := Vector2i(center.x - 2, center.y)
	if up_pos.x >= 0 and up_pos.x < map.width and up_pos.y >= 0 and up_pos.y < map.height:
		map.tiles[up_pos] = GameTile.create("stairs_up")
		map.metadata["stairs_up"] = up_pos

	var down_pos := Vector2i(center.x + 2, center.y)
	if down_pos.x >= 0 and down_pos.x < map.width and down_pos.y >= 0 and down_pos.y < map.height:
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
