class_name CircularFloorsGenerator
extends BaseDungeonGenerator
## Circular floor generator for vertical wizard towers
##
## Creates circular tower floors with segmented rooms around a central feature.
## Suitable for wizard towers, mage colleges, and vertical dungeons.

## Generate a circular tower floor
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
	var floor_radius: int = _get_param(dungeon_def, "floor_radius", 12)
	var room_segments: int = _get_param(dungeon_def, "room_segments", 6)
	var _spiral_stairs: bool = _get_param(dungeon_def, "spiral_staircase", true)

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
		"generator_type": "circular_floors",
		"enemy_spawns": []
	}

	# Fill with walls (dictionary uses Vector2i keys)
	for y in range(height):
		for x in range(width):
			map.tiles[Vector2i(x, y)] = GameTile.create(wall_tile)

	# Generate circular floor
	var center := Vector2i(width / 2, height / 2)
	_carve_circular_floor(map, center, floor_radius, floor_tile)
	_create_segmented_rooms(map, center, floor_radius, room_segments, wall_tile, rng)

	# Place stairs
	_add_stairs(map, center, floor_number)

	# Spawn enemies
	_spawn_enemies(map, dungeon_def, floor_number, rng)

	# Place features and hazards
	_place_features_and_hazards(map, dungeon_def, rng)

	return map


## Carve circular floor area
func _carve_circular_floor(map: GameMap, center: Vector2i, radius: int, floor_tile: String) -> void:
	for y in range(max(0, center.y - radius), min(map.height, center.y + radius + 1)):
		for x in range(max(0, center.x - radius), min(map.width, center.x + radius + 1)):
			var pos := Vector2i(x, y)
			var dist: float = center.distance_to(pos)
			if dist <= radius:
				map.tiles[pos] = GameTile.create(floor_tile)


## Create segmented rooms by dividing circle with radial walls
func _create_segmented_rooms(map: GameMap, center: Vector2i, radius: int, segments: int, wall_tile: String, rng: SeededRandom) -> void:
	# Divide circle into segments with radial walls
	for i in range(segments):
		var angle: float = (PI * 2.0 / segments) * i
		var wall_length: int = radius - 3  # Leave center open

		for r in range(3, wall_length):
			var x: int = center.x + int(cos(angle) * r)
			var y: int = center.y + int(sin(angle) * r)
			var pos := Vector2i(x, y)

			if x >= 0 and x < map.width and y >= 0 and y < map.height:
				map.tiles[pos] = GameTile.create(wall_tile)

				# Make walls 2-thick for visibility
				var x2: int = center.x + int(cos(angle) * r + sin(angle))
				var y2: int = center.y + int(sin(angle) * r - cos(angle))
				var pos2 := Vector2i(x2, y2)
				if x2 >= 0 and x2 < map.width and y2 >= 0 and y2 < map.height:
					map.tiles[pos2] = GameTile.create(wall_tile)

	# Add doors between segments (randomly remove some radial wall sections)
	for i in range(segments):
		var angle: float = (PI * 2.0 / segments) * i
		var door_r: int = rng.randi_range(5, radius - 5)

		# Create 2-tile wide opening
		for dr in range(-1, 2):
			var rx: int = center.x + int(cos(angle) * (door_r + dr))
			var ry: int = center.y + int(sin(angle) * (door_r + dr))
			var pos := Vector2i(rx, ry)
			if rx >= 0 and rx < map.width and ry >= 0 and ry < map.height:
				if map.tiles[pos].walkable == false:  # Only carve walls
					map.tiles[pos] = GameTile.create("floor")


## Place stairs (up and down for tower progression)
func _add_stairs(map: GameMap, center: Vector2i, _floor_number: int) -> void:
	# Place spiral staircase in center going both up and down
	# Stairs up
	var up_pos := Vector2i(center.x - 1, center.y - 1)
	if up_pos.x >= 0 and up_pos.x < map.width and up_pos.y >= 0 and up_pos.y < map.height:
		map.tiles[up_pos] = GameTile.create("stairs_up")
		map.metadata["stairs_up"] = up_pos

	# Stairs down (for going back down)
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
