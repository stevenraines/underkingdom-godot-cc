class_name ConcentricRingsGenerator
extends BaseDungeonGenerator
## Concentric rings generator for fortress layouts
##
## Creates defensive fortress structures with concentric walls and courtyards.
## Suitable for ancient forts, castles, and defensive compounds.

## Generate a fortress floor with concentric rings
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
	var wall_count: int = _get_param(dungeon_def, "wall_count", 3)
	var courtyard_size: int = _get_param(dungeon_def, "courtyard_size", 15)
	var keep_size: int = _get_param(dungeon_def, "keep_size", 8)
	var gatehouse_count: int = _get_param(dungeon_def, "gatehouse_positions", 4)

	# Extract tile definitions
	var tiles: Dictionary = dungeon_def.get("tiles", {})
	var wall_tile: String = tiles.get("wall", "wall")
	var floor_tile: String = tiles.get("floor", "floor")

	# Create floor seed
	var floor_seed: int = _create_floor_seed(world_seed, dungeon_id, floor_number)
	var rng := SeededRandom.new(floor_seed)

	# Initialize map with open ground (dirt/grass)
	var map := GameMap.new()
	map.map_id = "%s_floor_%d" % [dungeon_id, floor_number]
	map.width = width
	map.height = height
	map.tiles = {}
	map.entities = []
	map.metadata = {
		"dungeon_id": dungeon_id,
		"floor_number": floor_number,
		"generator_type": "concentric_rings",
		"enemy_spawns": []
	}

	# Fill with floor (courtyard ground) - dictionary uses Vector2i keys
	for y in range(height):
		for x in range(width):
			map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)

	# Generate fortress structure
	var center := Vector2i(width / 2, height / 2)
	_create_keep(map, center, keep_size, wall_tile, floor_tile)
	_create_concentric_walls(map, center, wall_count, courtyard_size, wall_tile)
	_add_gatehouses(map, center, gatehouse_count, floor_tile)

	# Place stairs
	_add_stairs(map, center, floor_number)

	# Spawn enemies
	_spawn_enemies(map, dungeon_def, floor_number, rng)

	return map


## Create central keep
func _create_keep(map: GameMap, center: Vector2i, size: int, wall_tile: String, floor_tile: String) -> void:
	# Create hollow square keep
	for y in range(center.y - size, center.y + size + 1):
		for x in range(center.x - size, center.x + size + 1):
			var pos := Vector2i(x, y)
			if x >= 0 and x < map.width and y >= 0 and y < map.height:
				# Walls on perimeter, floor inside
				if x == center.x - size or x == center.x + size or y == center.y - size or y == center.y + size:
					map.tiles[pos] = GameTile.create(wall_tile)
				else:
					map.tiles[pos] = GameTile.create(floor_tile)

	# Add door to keep
	var door_x: int = center.x
	var door_y: int = center.y + size
	var door_pos := Vector2i(door_x, door_y)
	if door_y >= 0 and door_y < map.height:
		map.tiles[door_pos] = GameTile.create(floor_tile)


## Create concentric defensive walls
func _create_concentric_walls(map: GameMap, center: Vector2i, count: int, spacing: int, wall_tile: String) -> void:
	for ring in range(1, count + 1):
		var radius: int = spacing * ring

		# Draw square ring
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if x < 0 or x >= map.width or y < 0 or y >= map.height:
					continue

				# Check if on perimeter of square
				if x == center.x - radius or x == center.x + radius or y == center.y - radius or y == center.y + radius:
					map.tiles[Vector2i(x, y)] = GameTile.create(wall_tile)


## Add gatehouses at cardinal directions
func _add_gatehouses(map: GameMap, center: Vector2i, count: int, floor_tile: String) -> void:
	# Cardinal directions
	var directions: Array = [
		Vector2i(0, -1),  # North
		Vector2i(1, 0),   # East
		Vector2i(0, 1),   # South
		Vector2i(-1, 0)   # West
	]

	for i in range(min(count, 4)):
		var dir: Vector2i = directions[i]
		var gate_distance: int = 15  # Distance from center

		var gate_pos := Vector2i(
			center.x + dir.x * gate_distance,
			center.y + dir.y * gate_distance
		)

		if gate_pos.x >= 0 and gate_pos.x < map.width and gate_pos.y >= 0 and gate_pos.y < map.height:
			# Create 3-tile wide passage through walls
			for offset in range(-1, 2):
				var x: int = gate_pos.x + (dir.y * offset)  # Perpendicular to direction
				var y: int = gate_pos.y + (dir.x * offset)
				var pos := Vector2i(x, y)

				if x >= 0 and x < map.width and y >= 0 and y < map.height:
					map.tiles[pos] = GameTile.create(floor_tile)


## Place stairs
func _add_stairs(map: GameMap, center: Vector2i, floor_number: int) -> void:
	# Place stairs in keep center
	if floor_number > 1:
		var up_pos := Vector2i(center.x - 1, center.y - 1)
		if up_pos.x >= 0 and up_pos.x < map.width and up_pos.y >= 0 and up_pos.y < map.height:
			map.tiles[up_pos] = GameTile.create("stairs_up")
			map.metadata["stairs_up"] = up_pos

	var down_pos := Vector2i(center.x + 1, center.y + 1)
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
