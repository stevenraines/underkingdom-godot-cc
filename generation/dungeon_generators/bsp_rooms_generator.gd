class_name BSPRoomsGenerator
extends BaseDungeonGenerator
## Binary Space Partition generator for structured military layouts
##
## Creates organized room structures through recursive space partitioning.
## Suitable for military compounds, fortresses, and structured buildings.

## BSP tree node for recursive space partitioning
class BSPNode:
	var x: int
	var y: int
	var width: int
	var height: int
	var left_child: BSPNode = null
	var right_child: BSPNode = null
	var room: Rect2i = Rect2i()

	func _init(px: int, py: int, w: int, h: int):
		x = px
		y = py
		width = w
		height = h

	func is_leaf() -> bool:
		return left_child == null and right_child == null


## Generate a military compound floor using BSP
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
	var min_room_size: int = _get_param(dungeon_def, "min_room_size", 5)
	var max_room_size: int = _get_param(dungeon_def, "max_room_size", 12)
	var _split_ratio: float = _get_param(dungeon_def, "split_ratio", 0.5)

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
		"generator_type": "bsp_rooms",
		"enemy_spawns": []
	}

	# Fill with walls (dictionary uses Vector2i keys)
	for y in range(height):
		for x in range(width):
			map.tiles[Vector2i(x, y)] = GameTile.create(wall_tile)

	# Generate BSP structure
	var root := BSPNode.new(1, 1, width - 2, height - 2)
	_split_node(root, rng, min_room_size)

	# Create rooms from leaf nodes
	var rooms: Array = []
	_create_rooms(root, rng, min_room_size, max_room_size, rooms)

	# Carve out rooms
	for room in rooms:
		for y in range(room.position.y, room.position.y + room.size.y):
			for x in range(room.position.x, room.position.x + room.size.x):
				if x >= 0 and x < map.width and y >= 0 and y < map.height:
					map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)

	# Connect rooms with corridors
	_connect_rooms_recursive(map, root, floor_tile)

	# Place stairs
	_add_stairs(map, rooms, floor_number)

	# Spawn enemies
	_spawn_enemies(map, dungeon_def, floor_number, rng)

	# Place features and hazards
	_place_features_and_hazards(map, dungeon_def, rng)

	return map


## Recursively split BSP node into children
func _split_node(node: BSPNode, rng: SeededRandom, min_size: int) -> void:
	# Stop if too small to split
	if node.width < min_size * 2 and node.height < min_size * 2:
		return

	# Determine split direction
	var split_horizontal: bool = true

	if node.width > node.height and node.height >= min_size * 2:
		split_horizontal = false
	elif node.height > node.width and node.width >= min_size * 2:
		split_horizontal = true
	elif node.width >= min_size * 2 and node.height >= min_size * 2:
		split_horizontal = rng.randf() < 0.5
	else:
		return  # Cannot split

	# Calculate split position
	var split_pos: int

	if split_horizontal:
		var max_split: int = node.height - min_size
		split_pos = rng.randi_range(min_size, max_split)
		node.left_child = BSPNode.new(node.x, node.y, node.width, split_pos)
		node.right_child = BSPNode.new(node.x, node.y + split_pos, node.width, node.height - split_pos)
	else:
		var max_split: int = node.width - min_size
		split_pos = rng.randi_range(min_size, max_split)
		node.left_child = BSPNode.new(node.x, node.y, split_pos, node.height)
		node.right_child = BSPNode.new(node.x + split_pos, node.y, node.width - split_pos, node.height)

	# Recursively split children
	_split_node(node.left_child, rng, min_size)
	_split_node(node.right_child, rng, min_size)


## Create rooms in leaf nodes
func _create_rooms(node: BSPNode, rng: SeededRandom, min_size: int, max_size: int, rooms: Array) -> void:
	if node.is_leaf():
		# Create room within this leaf
		var room_width: int = rng.randi_range(min_size, min(max_size, node.width - 2))
		var room_height: int = rng.randi_range(min_size, min(max_size, node.height - 2))
		var room_x: int = node.x + rng.randi_range(1, max(1, node.width - room_width - 1))
		var room_y: int = node.y + rng.randi_range(1, max(1, node.height - room_height - 1))

		node.room = Rect2i(room_x, room_y, room_width, room_height)
		rooms.append(node.room)
	else:
		# Recursively get rooms from children
		if node.left_child:
			_create_rooms(node.left_child, rng, min_size, max_size, rooms)
		if node.right_child:
			_create_rooms(node.right_child, rng, min_size, max_size, rooms)


## Recursively connect rooms via corridors
func _connect_rooms_recursive(map: GameMap, node: BSPNode, floor_tile: String) -> void:
	if node.is_leaf():
		return

	# Recursively connect children first
	if node.left_child:
		_connect_rooms_recursive(map, node.left_child, floor_tile)
	if node.right_child:
		_connect_rooms_recursive(map, node.right_child, floor_tile)

	# Connect left and right subtrees
	if node.left_child and node.right_child:
		var left_room: Rect2i = _get_room_from_subtree(node.left_child)
		var right_room: Rect2i = _get_room_from_subtree(node.right_child)
		_connect_two_rooms(map, left_room, right_room, floor_tile)


## Get a room from a subtree (finds first leaf room)
func _get_room_from_subtree(node: BSPNode) -> Rect2i:
	if node.is_leaf():
		return node.room

	if node.left_child:
		return _get_room_from_subtree(node.left_child)

	if node.right_child:
		return _get_room_from_subtree(node.right_child)

	return Rect2i()


## Connect two rooms with an L-shaped corridor
func _connect_two_rooms(map: GameMap, room_a: Rect2i, room_b: Rect2i, floor_tile: String) -> void:
	var start: Vector2i = Vector2i(
		room_a.position.x + room_a.size.x / 2,
		room_a.position.y + room_a.size.y / 2
	)
	var end: Vector2i = Vector2i(
		room_b.position.x + room_b.size.x / 2,
		room_b.position.y + room_b.size.y / 2
	)

	var current: Vector2i = start

	# Horizontal segment
	while current.x != end.x:
		if current.x >= 0 and current.x < map.width and current.y >= 0 and current.y < map.height:
			map.tiles[current] = GameTile.create(floor_tile)
		current.x += 1 if current.x < end.x else -1

	# Vertical segment
	while current.y != end.y:
		if current.x >= 0 and current.x < map.width and current.y >= 0 and current.y < map.height:
			map.tiles[current] = GameTile.create(floor_tile)
		current.y += 1 if current.y < end.y else -1


## Place stairs in rooms
func _add_stairs(map: GameMap, rooms: Array, floor_number: int) -> void:
	if rooms.is_empty():
		return

	# Place stairs up in first room
	if floor_number > 1:
		var first_room: Rect2i = rooms[0]
		var up_pos := Vector2i(
			first_room.position.x + first_room.size.x / 2,
			first_room.position.y + first_room.size.y / 2
		)
		map.tiles[up_pos] = GameTile.create("stairs_up")
		map.metadata["stairs_up"] = up_pos

	# Place stairs down in last room
	var last_room: Rect2i = rooms[rooms.size() - 1]
	var down_pos := Vector2i(
		last_room.position.x + last_room.size.x / 2,
		last_room.position.y + last_room.size.y / 2
	)
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
