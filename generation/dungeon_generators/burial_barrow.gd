class_name BurialBarrowGenerator

## BurialBarrowGenerator - Generate burial barrow dungeon floors
##
## Creates rectangular rooms connected by corridors.
## Depth: 1-50 floors, deterministic based on world seed + floor number.

const GameTile = preload("res://maps/game_tile.gd")

## Room data structure
class Room:
	var x: int
	var y: int
	var width: int
	var height: int

	func _init(rx: int, ry: int, rw: int, rh: int) -> void:
		x = rx
		y = ry
		width = rw
		height = rh

	func center() -> Vector2i:
		return Vector2i(x + width / 2, y + height / 2)

	func intersects(other: Room) -> bool:
		return (x < other.x + other.width and
				x + width > other.x and
				y < other.y + other.height and
				y + height > other.y)

## Generate a dungeon floor
static func generate_floor(world_seed: int, floor_number: int) -> GameMap:
	# Create deterministic seed for this floor
	var floor_seed = hash(str(world_seed) + "_barrow_" + str(floor_number))
	var rng = SeededRandom.new(floor_seed)

	var map = GameMap.new("dungeon_barrow_floor_%d" % floor_number, 50, 50, floor_seed)

	# Fill with walls
	map.fill("wall")

	# Generate rooms
	var rooms: Array[Room] = []
	var num_rooms = rng.randi_range(5, 10)

	for i in range(num_rooms):
		var room = _generate_room(map, rng, rooms)
		if room:
			rooms.append(room)
			_carve_room(map, room)

	# Connect rooms with corridors
	for i in range(rooms.size() - 1):
		_create_corridor(map, rooms[i].center(), rooms[i + 1].center())

	# Place stairs
	if rooms.size() > 0:
		# Stairs up in first room
		var up_pos = rooms[0].center()
		map.set_tile(up_pos, _create_tile("stairs_up"))

		# Stairs down in last room (unless floor 50)
		if floor_number < 50:
			var down_pos = rooms[rooms.size() - 1].center()
			map.set_tile(down_pos, _create_tile("stairs_down"))

	# Spawn enemies (after stairs so we don't spawn on stairs)
	_spawn_enemies(map, rng, rooms, floor_number)

	print("Burial barrow floor %d generated with %d rooms" % [floor_number, rooms.size()])
	return map

## Generate a room that doesn't overlap existing rooms
static func _generate_room(map: GameMap, rng: SeededRandom, existing_rooms: Array[Room]) -> Room:
	var max_attempts = 50

	for attempt in range(max_attempts):
		var w = rng.randi_range(5, 12)
		var h = rng.randi_range(5, 12)
		var x = rng.randi_range(1, map.width - w - 1)
		var y = rng.randi_range(1, map.height - h - 1)

		var new_room = Room.new(x, y, w, h)

		# Check if it intersects with any existing room
		var valid = true
		for room in existing_rooms:
			if new_room.intersects(room):
				valid = false
				break

		if valid:
			return new_room

	return null  # Could not place room

## Carve out a room (set tiles to floor)
static func _carve_room(map: GameMap, room: Room) -> void:
	for y in range(room.y, room.y + room.height):
		for x in range(room.x, room.x + room.width):
			map.set_tile(Vector2i(x, y), _create_tile("floor"))

## Create a corridor between two points
static func _create_corridor(map: GameMap, start: Vector2i, end: Vector2i) -> void:
	var current = start

	# Horizontal then vertical corridor
	while current.x != end.x:
		map.set_tile(current, _create_tile("floor"))
		current.x += 1 if current.x < end.x else -1

	while current.y != end.y:
		map.set_tile(current, _create_tile("floor"))
		current.y += 1 if current.y < end.y else -1

	# Set final position
	map.set_tile(current, _create_tile("floor"))

## Create a tile by type (helper function to avoid static method issues)
static func _create_tile(type: String) -> GameTile:
	var tile = GameTile.new()

	match type:
		"floor":
			tile.tile_type = "floor"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "."
		"wall":
			tile.tile_type = "wall"
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "░"  # CP437 light shade (U+2591, index 176)
		"stairs_down":
			tile.tile_type = "stairs_down"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = ">"
		"stairs_up":
			tile.tile_type = "stairs_up"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "<"
		_:
			push_warning("Unknown tile type: " + type + ", defaulting to floor")
			tile.tile_type = "floor"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "."

	return tile

## Spawn enemies in rooms
static func _spawn_enemies(map: GameMap, rng: SeededRandom, rooms: Array[Room], floor_number: int) -> void:
	# Get enemy data for spawn density
	var rat_data = EntityManager.get_enemy_definition("grave_rat")
	var wight_data = EntityManager.get_enemy_definition("barrow_wight")

	# Skip first room (has stairs up, player spawns there)
	for i in range(1, rooms.size()):
		var room = rooms[i]
		var room_area = room.width * room.height

		# Choose enemy type based on floor depth and spawn level restrictions
		var enemy_id: String = ""
		var spawn_density: int = 0

		# Try wights on deeper floors
		if floor_number >= 5 and rng.randf() > 0.6:
			if not wight_data.is_empty():
				var min_level = wight_data.get("min_spawn_level", 0)
				var max_level = wight_data.get("max_spawn_level", 0)
				# Check if this floor is within spawn range (0 means no restriction)
				if (min_level == 0 or floor_number >= min_level) and \
				   (max_level == 0 or floor_number <= max_level):
					enemy_id = "barrow_wight"
					spawn_density = wight_data.get("spawn_density_dungeon", 0)

		# Fall back to rats if wights can't spawn or weren't chosen
		if enemy_id == "" and not rat_data.is_empty():
			var min_level = rat_data.get("min_spawn_level", 0)
			var max_level = rat_data.get("max_spawn_level", 0)
			# Check if this floor is within spawn range (0 means no restriction)
			if (min_level == 0 or floor_number >= min_level) and \
			   (max_level == 0 or floor_number <= max_level):
				enemy_id = "grave_rat"
				spawn_density = rat_data.get("spawn_density_dungeon", 0)

		# Skip if no valid enemy or spawn density is 0
		if enemy_id == "" or spawn_density == 0:
			continue

		# Calculate number of enemies for this room
		var num_enemies = max(0, int(room_area / spawn_density))

		# Add floor scaling (deeper = slightly more enemies)
		var floor_bonus = int(floor_number / 10.0)
		num_enemies += floor_bonus

		# Add some randomness (±50%)
		if num_enemies > 0:
			var variance = max(1, int(num_enemies * 0.5))
			num_enemies = rng.randi_range(max(0, num_enemies - variance), num_enemies + variance)

		for j in range(num_enemies):
			# Find a valid spawn position in the room
			var spawn_pos = _find_spawn_position_in_room(map, rng, room)
			if spawn_pos != Vector2i(-1, -1):
				# Store enemy spawn data in map metadata
				# Actual spawning happens when map is loaded in EntityManager
				if not map.has_meta("enemy_spawns"):
					map.set_meta("enemy_spawns", [])

				var spawns = map.get_meta("enemy_spawns")
				spawns.append({"enemy_id": enemy_id, "position": spawn_pos})
				map.set_meta("enemy_spawns", spawns)

## Find a valid spawn position within a room (not on stairs, not occupied)
static func _find_spawn_position_in_room(map: GameMap, rng: SeededRandom, room: Room) -> Vector2i:
	var max_attempts = 20

	for attempt in range(max_attempts):
		var x = rng.randi_range(room.x + 1, room.x + room.width - 2)
		var y = rng.randi_range(room.y + 1, room.y + room.height - 2)
		var pos = Vector2i(x, y)

		var tile = map.get_tile(pos)

		# Check if position is valid (walkable floor, not stairs)
		if tile and tile.walkable and tile.tile_type == "floor":
			return pos

	return Vector2i(-1, -1)  # Failed to find position
