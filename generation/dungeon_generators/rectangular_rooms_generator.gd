class_name RectangularRoomsGenerator
extends BaseDungeonGenerator
## Rectangular rooms connected by corridors generator
##
## Creates dungeons with non-overlapping rectangular rooms connected by L-shaped
## corridors. Suitable for burial barrows, crypts, and structured dungeons.

## Room data structure for spatial tracking
class Room:
	var x: int
	var y: int
	var width: int
	var height: int

	func _init(p_x: int, p_y: int, p_width: int, p_height: int):
		x = p_x
		y = p_y
		width = p_width
		height = p_height

	## Check if this room intersects with another room (with 1-tile buffer)
	func intersects(other: Room) -> bool:
		return not (x + width + 1 < other.x or
					x > other.x + other.width + 1 or
					y + height + 1 < other.y or
					y > other.y + other.height + 1)


## Generate a dungeon floor with rectangular rooms and corridors
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
	var room_count_min: int = _get_param(dungeon_def, "room_count_range", [5, 8])[0]
	var room_count_max: int = _get_param(dungeon_def, "room_count_range", [5, 8])[1]
	var room_size_min: int = _get_param(dungeon_def, "room_size_range", [3, 8])[0]
	var room_size_max: int = _get_param(dungeon_def, "room_size_range", [3, 8])[1]
	var corridor_width: int = _get_param(dungeon_def, "corridor_width", 1)
	var connectivity: float = _get_param(dungeon_def, "connectivity", 0.7)

	# Extract tile definitions
	var tiles: Dictionary = dungeon_def.get("tiles", {})
	var wall_tile: String = tiles.get("wall", "wall")
	var floor_tile: String = tiles.get("floor", "floor")
	var door_tile: String = tiles.get("door", "wooden_door")

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
		"generator_type": "rectangular_rooms",
		"enemy_spawns": []
	}

	# Fill with walls (dictionary uses Vector2i keys)
	for y in range(height):
		for x in range(width):
			map.tiles[Vector2i(x, y)] = GameTile.create(wall_tile)

	# Generate rooms
	var room_count: int = rng.randi_range(room_count_min, room_count_max)
	var rooms: Array[Room] = []
	var max_attempts: int = 1000
	var attempts: int = 0

	while rooms.size() < room_count and attempts < max_attempts:
		attempts += 1

		var room_width: int = rng.randi_range(room_size_min, room_size_max)
		var room_height: int = rng.randi_range(room_size_min, room_size_max)
		var room_x: int = rng.randi_range(1, width - room_width - 1)
		var room_y: int = rng.randi_range(1, height - room_height - 1)

		var new_room := Room.new(room_x, room_y, room_width, room_height)

		# Check for intersections with existing rooms
		var valid: bool = true
		for existing_room in rooms:
			if new_room.intersects(existing_room):
				valid = false
				break

		if valid:
			rooms.append(new_room)
			# Carve out room floor
			for y in range(new_room.y, new_room.y + new_room.height):
				for x in range(new_room.x, new_room.x + new_room.width):
					map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)

	# Connect rooms with corridors
	for i in range(rooms.size() - 1):
		var room_a: Room = rooms[i]
		var room_b: Room = rooms[i + 1]

		# Add extra connections based on connectivity parameter
		if i > 0 and rng.randf() < connectivity:
			room_b = rooms[rng.randi_range(0, i)]

		_create_corridor(map, room_a, room_b, floor_tile, corridor_width)

	# Place stairs
	if rooms.size() > 0:
		var last_room: Room = rooms[rooms.size() - 1]
		var stairs_x: int = last_room.x + last_room.width / 2
		var stairs_y: int = last_room.y + last_room.height / 2
		map.tiles[Vector2i(stairs_x, stairs_y)] = GameTile.create("stairs_down")
		map.metadata["stairs_down"] = Vector2i(stairs_x, stairs_y)

		# Place up stairs in first room
		if floor_number > 1:
			var first_room: Room = rooms[0]
			var up_stairs_x: int = first_room.x + first_room.width / 2
			var up_stairs_y: int = first_room.y + first_room.height / 2
			map.tiles[Vector2i(up_stairs_x, up_stairs_y)] = GameTile.create("stairs_up")
			map.metadata["stairs_up"] = Vector2i(up_stairs_x, up_stairs_y)

	# Spawn enemies
	_spawn_enemies(map, dungeon_def, floor_number, rooms, rng)

	return map


## Create L-shaped corridor between two rooms
func _create_corridor(map: GameMap, room_a: Room, room_b: Room, floor_tile: String, width: int) -> void:
	var start_x: int = room_a.x + room_a.width / 2
	var start_y: int = room_a.y + room_a.height / 2
	var end_x: int = room_b.x + room_b.width / 2
	var end_y: int = room_b.y + room_b.height / 2

	# Horizontal then vertical corridor
	for w_offset in range(width):
		# Horizontal segment
		var x_step: int = 1 if end_x > start_x else -1
		for x in range(start_x, end_x + x_step, x_step):
			var y: int = start_y + w_offset - width / 2
			if y >= 0 and y < map.height and x >= 0 and x < map.width:
				map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)

		# Vertical segment
		var y_step: int = 1 if end_y > start_y else -1
		for y in range(start_y, end_y + y_step, y_step):
			var x: int = end_x + w_offset - width / 2
			if y >= 0 and y < map.height and x >= 0 and x < map.width:
				map.tiles[Vector2i(x, y)] = GameTile.create(floor_tile)


## Spawn enemies from dungeon definition enemy pools
func _spawn_enemies(map: GameMap, dungeon_def: Dictionary, floor_number: int, rooms: Array[Room], rng: SeededRandom) -> void:
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

	# Limit spawns to available rooms
	spawn_count = min(spawn_count, rooms.size() * 3)

	var spawned: int = 0
	var max_attempts: int = 100
	var attempts: int = 0

	while spawned < spawn_count and attempts < max_attempts:
		attempts += 1

		# Pick random room
		var room: Room = rooms[rng.randi_range(0, rooms.size() - 1)]
		var spawn_x: int = rng.randi_range(room.x, room.x + room.width - 1)
		var spawn_y: int = rng.randi_range(room.y, room.y + room.height - 1)

		# Check if position is walkable and not stairs
		var spawn_pos := Vector2i(spawn_x, spawn_y)
		if not map.tiles[spawn_pos].walkable:
			continue
		if map.tiles[spawn_pos].tile_type in ["stairs_up", "stairs_down"]:
			continue

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

		# Check if enemy is defined in EntityManager
		if not EntityManager.has_enemy_definition(chosen_enemy_id):
			push_warning("Enemy '%s' not defined in EntityManager" % chosen_enemy_id)
			continue

		# Calculate enemy level with floor scaling
		var level_multiplier: float = difficulty.get("enemy_level_multiplier", 1.0)
		var enemy_level: int = max(1, int(floor_number * level_multiplier))

		# Store spawn data in metadata
		map.metadata.enemy_spawns.append({
			"enemy_id": chosen_enemy_id,
			"position": Vector2i(spawn_x, spawn_y),
			"level": enemy_level
		})

		spawned += 1
