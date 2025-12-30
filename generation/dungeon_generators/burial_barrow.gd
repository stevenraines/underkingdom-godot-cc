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
			tile.ascii_char = "#"
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
