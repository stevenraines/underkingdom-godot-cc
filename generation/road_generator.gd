class_name RoadGenerator
extends RefCounted

## RoadGenerator - Generates roads within towns and between towns
##
## Handles three types of roads:
## - Internal town roads connecting buildings
## - Town square paving
## - Inter-town roads connecting nearby towns

const GameTile = preload("res://maps/game_tile.gd")

## Road material types based on distance from structures
enum RoadMaterial {
	COBBLESTONE,  # Near structures (within towns)
	GRAVEL,       # Transition areas
	DIRT          # Remote paths
}

## Generate roads within a town connecting buildings
## tiles_dict: Dictionary of Vector2i -> GameTile (the world tiles)
## town_center: Center position of the town
## town_size: Size of the town area
## buildings: Array of building entries from town definition
## building_defs: Dictionary of building_id -> building definition
## has_town_square: Whether to pave a central town square
static func generate_town_roads(tiles_dict: Dictionary, town_center: Vector2i, town_size: Vector2i, buildings: Array, building_defs: Dictionary, has_town_square: bool = false) -> void:
	var half_size = town_size / 2
	var town_start = town_center - half_size

	# If town has a square, pave the central area
	if has_town_square:
		_pave_town_square(tiles_dict, town_center, town_size)

	# Get door positions of all buildings
	var door_positions: Array[Vector2i] = []
	for building_entry in buildings:
		var building_id = building_entry.get("building_id", "")
		var offset_array = building_entry.get("position_offset", [0, 0])
		var offset = Vector2i(offset_array[0], offset_array[1])
		var building_pos = town_center + offset
		var door_facing = building_entry.get("door_facing", "south")

		var building_def = building_defs.get(building_id, {})
		var door_pos = _get_door_position(building_pos, building_def, door_facing)
		if door_pos != Vector2i(-1, -1):
			door_positions.append(door_pos)

	# Connect all doors to the town center (or nearest road)
	for door_pos in door_positions:
		_create_road_path(tiles_dict, door_pos, town_center, RoadMaterial.COBBLESTONE, town_center, half_size.x)


## Pave the central town square with cobblestone
static func _pave_town_square(tiles_dict: Dictionary, town_center: Vector2i, town_size: Vector2i) -> void:
	# Town square is roughly 1/3 of town size, centered
	var square_size = Vector2i(town_size.x / 3, town_size.y / 3)
	var half_square = square_size / 2

	for x in range(-half_square.x, half_square.x + 1):
		for y in range(-half_square.y, half_square.y + 1):
			var pos = town_center + Vector2i(x, y)
			if pos in tiles_dict:
				var existing = tiles_dict[pos]
				# Only replace floor tiles, not buildings/doors/special tiles
				if existing.tile_type == "floor" and existing.walkable:
					var road_tile = GameTile.create("road_cobblestone")
					tiles_dict[pos] = road_tile


## Get the door position for a building
static func _get_door_position(building_pos: Vector2i, building_def: Dictionary, door_facing: String) -> Vector2i:
	if building_def.is_empty():
		return Vector2i(-1, -1)

	var template_type = building_def.get("template_type", "building")
	if template_type == "feature":
		# Features (wells, shrines) don't have doors
		return Vector2i(-1, -1)

	var size_array = building_def.get("size", [5, 5])
	var size = Vector2i(size_array[0], size_array[1])
	var half_size = size / 2

	# Calculate door position based on facing (position just outside the door)
	match door_facing:
		"south":
			return building_pos + Vector2i(0, half_size.y + 1)
		"north":
			return building_pos + Vector2i(0, -half_size.y - 1)
		"east":
			return building_pos + Vector2i(half_size.x + 1, 0)
		"west":
			return building_pos + Vector2i(-half_size.x - 1, 0)

	return building_pos + Vector2i(0, half_size.y + 1)  # Default south


## Create a road path between two points using simple pathfinding
## Uses L-shaped paths (horizontal then vertical, or vice versa)
static func _create_road_path(tiles_dict: Dictionary, from_pos: Vector2i, to_pos: Vector2i, material: RoadMaterial, town_center: Vector2i, town_radius: int) -> void:
	var road_type = _material_to_tile_type(material)

	# Use Manhattan path (horizontal first, then vertical)
	var current = from_pos

	# Horizontal segment
	var dx = sign(to_pos.x - current.x)
	while current.x != to_pos.x:
		_place_road_tile(tiles_dict, current, road_type, town_center, town_radius)
		current.x += dx

	# Vertical segment
	var dy = sign(to_pos.y - current.y)
	while current.y != to_pos.y:
		_place_road_tile(tiles_dict, current, road_type, town_center, town_radius)
		current.y += dy

	# Place final tile
	_place_road_tile(tiles_dict, current, road_type, town_center, town_radius)


## Place a road tile at position, respecting existing structures
static func _place_road_tile(tiles_dict: Dictionary, pos: Vector2i, road_type: String, town_center: Vector2i, town_radius: int) -> void:
	if pos not in tiles_dict:
		return

	var existing = tiles_dict[pos]

	# Don't replace special tiles
	if existing.tile_type in ["wall", "door", "dungeon_entrance", "stairs_down", "stairs_up", "tree", "water"]:
		return

	# If it's water, use a bridge instead
	if existing.tile_type == "water":
		var bridge_type = "bridge_stone" if road_type == "road_cobblestone" else "bridge_wood"
		tiles_dict[pos] = GameTile.create(bridge_type)
		return

	# Only replace floor/grass tiles
	if existing.walkable and existing.tile_type == "floor":
		tiles_dict[pos] = GameTile.create(road_type)


## Convert RoadMaterial enum to tile type string
static func _material_to_tile_type(material: RoadMaterial) -> String:
	match material:
		RoadMaterial.COBBLESTONE:
			return "road_cobblestone"
		RoadMaterial.GRAVEL:
			return "road_gravel"
		RoadMaterial.DIRT:
			return "road_dirt"
	return "road_dirt"


## Generate roads between towns
## tiles_dict: Dictionary of Vector2i -> GameTile (the world tiles)
## towns: Array of town data dictionaries with position, size, roads_connected flag
## world_seed: For deterministic randomness
static func generate_inter_town_roads(tiles_dict: Dictionary, towns: Array, world_seed: int) -> void:
	# Filter towns that want road connections
	var connected_towns: Array = []
	for town in towns:
		if town.get("roads_connected", false):
			connected_towns.append(town)

	if connected_towns.size() < 2:
		return

	# For each connected town, find and connect to nearest 2 towns
	var connections_made: Array = []  # Track [town1_id, town2_id] pairs to avoid duplicates

	for town in connected_towns:
		var town_pos = town.get("position", Vector2i(0, 0))
		var town_id = town.get("town_id", "")

		# Find nearest towns
		var nearest = _find_nearest_towns(town, connected_towns, 2)

		for other_town in nearest:
			var other_id = other_town.get("town_id", "")

			# Check if connection already made (in either direction)
			var connection_key = [town_id, other_id]
			connection_key.sort()
			if connection_key in connections_made:
				continue

			connections_made.append(connection_key)

			# Generate road between towns
			var other_pos = other_town.get("position", Vector2i(0, 0))
			_generate_road_between_towns(tiles_dict, town_pos, other_pos, world_seed)

	print("[RoadGenerator] Generated %d inter-town road connections" % connections_made.size())


## Find the N nearest towns to a given town
static func _find_nearest_towns(town: Dictionary, all_towns: Array, count: int) -> Array:
	var town_pos = town.get("position", Vector2i(0, 0))
	var town_id = town.get("town_id", "")

	var distances: Array = []
	for other in all_towns:
		var other_id = other.get("town_id", "")
		if other_id == town_id:
			continue

		var other_pos = other.get("position", Vector2i(0, 0))
		var dist = (other_pos - town_pos).length()
		distances.append({"town": other, "distance": dist})

	# Sort by distance
	distances.sort_custom(func(a, b): return a.distance < b.distance)

	# Return top N
	var result: Array = []
	for i in range(min(count, distances.size())):
		result.append(distances[i].town)

	return result


## Generate a road between two towns with material transitions
static func _generate_road_between_towns(tiles_dict: Dictionary, from_pos: Vector2i, to_pos: Vector2i, world_seed: int) -> void:
	var rng = SeededRandom.new(world_seed + from_pos.x * 1000 + from_pos.y + to_pos.x * 100 + to_pos.y)

	# Calculate total distance
	var total_dist = (to_pos - from_pos).length()

	# Transition thresholds (as fraction of total distance from nearest town)
	var cobblestone_threshold = 0.15  # 15% from each town is cobblestone
	var gravel_threshold = 0.30       # Next 15% is gravel
	# Rest is dirt

	# Use a slightly meandering path with segments
	var path = _generate_meandering_path(from_pos, to_pos, rng, total_dist)

	for i in range(path.size()):
		var pos = path[i]

		# Calculate distance from nearest town endpoint
		var dist_from_start = (pos - from_pos).length()
		var dist_from_end = (pos - to_pos).length()
		var min_dist = min(dist_from_start, dist_from_end)
		var dist_ratio = min_dist / total_dist

		# Determine road material based on distance from towns
		var road_type: String
		if dist_ratio < cobblestone_threshold:
			road_type = "road_cobblestone"
		elif dist_ratio < gravel_threshold:
			road_type = "road_gravel"
		else:
			road_type = "road_dirt"

		# Place the road tile
		_place_inter_town_road_tile(tiles_dict, pos, road_type)


## Generate a slightly meandering path between two points
static func _generate_meandering_path(from_pos: Vector2i, to_pos: Vector2i, rng: SeededRandom, total_dist: float) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	# For shorter distances, use simple straight path
	if total_dist < 30:
		return _generate_straight_path(from_pos, to_pos)

	# For longer distances, add waypoints with slight deviation
	var num_segments = int(total_dist / 20) + 1
	var waypoints: Array[Vector2i] = [from_pos]

	for i in range(1, num_segments):
		var t = float(i) / num_segments
		var base_pos = from_pos + Vector2i(
			int((to_pos.x - from_pos.x) * t),
			int((to_pos.y - from_pos.y) * t)
		)

		# Add some perpendicular deviation
		var perpendicular = Vector2(-(to_pos.y - from_pos.y), to_pos.x - from_pos.x).normalized()
		var deviation = rng.randf_range(-8.0, 8.0)
		var waypoint = base_pos + Vector2i(int(perpendicular.x * deviation), int(perpendicular.y * deviation))
		waypoints.append(waypoint)

	waypoints.append(to_pos)

	# Connect waypoints with straight segments
	for i in range(waypoints.size() - 1):
		var segment = _generate_straight_path(waypoints[i], waypoints[i + 1])
		for pos in segment:
			if pos not in path:
				path.append(pos)

	return path


## Generate a straight path between two points (Bresenham-like)
static func _generate_straight_path(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = from_pos

	var dx = abs(to_pos.x - from_pos.x)
	var dy = abs(to_pos.y - from_pos.y)
	var sx = 1 if from_pos.x < to_pos.x else -1
	var sy = 1 if from_pos.y < to_pos.y else -1
	var err = dx - dy

	while true:
		path.append(current)

		if current == to_pos:
			break

		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			current.x += sx
		if e2 < dx:
			err += dx
			current.y += sy

	return path


## Place an inter-town road tile, handling water crossings
static func _place_inter_town_road_tile(tiles_dict: Dictionary, pos: Vector2i, road_type: String) -> void:
	if pos not in tiles_dict:
		# Position not in tiles dict - might be in a chunk not yet generated
		# For chunk-based worlds, we'd need to queue this for later
		return

	var existing = tiles_dict[pos]

	# Don't replace special structures
	if existing.tile_type in ["wall", "door", "dungeon_entrance", "stairs_down", "stairs_up"]:
		return

	# Handle water crossings with bridges
	if existing.tile_type == "water":
		var bridge_type = "bridge_stone" if road_type == "road_cobblestone" else "bridge_wood"
		tiles_dict[pos] = GameTile.create(bridge_type)
		return

	# Don't replace trees on inter-town roads (go around in real pathfinding)
	# For now, we skip trees - a more advanced system would pathfind around them
	if existing.tile_type == "tree":
		return

	# Replace floor/grass tiles with road
	if existing.walkable:
		tiles_dict[pos] = GameTile.create(road_type)
