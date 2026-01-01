extends Node
## TownGenerator - Generates town area in the overworld
##
## Creates a safe zone with buildings, NPCs, and resources.
## Phase 1.17: Town with general store and blacksmith.
## Buildings have varied sizes and door positions for verisimilitude.

# Type references
const GameTile = preload("res://maps/game_tile.gd")
const SeededRandom = preload("res://generation/seeded_random.gd")

# Town constants - now represents the cleared area, buildings placed organically within
const TOWN_CLEAR_RADIUS = 12  # Radius of cleared area around town center

## Generates town in the overworld map
## Finds a valid location on land and places buildings with varied layouts
static func generate_town(world_map: GameMap, world_seed: int):
	var rng = SeededRandom.new(world_seed + 999)  # Seed offset for town generation

	# Find a valid town location (must be on land, away from water)
	var town_center = _find_valid_town_location(world_map, rng)
	if town_center == Vector2i(-1, -1):
		push_warning("TownGenerator: Could not find valid town location")
		return

	# Clear area for town (circular/organic clearing)
	_clear_town_area(world_map, town_center, rng)

	# Initialize NPC spawns metadata
	if not world_map.has_meta("npc_spawns"):
		world_map.set_meta("npc_spawns", [])
	var npc_spawns = world_map.get_meta("npc_spawns")

	# Generate varied building layouts
	var general_store = _generate_building_layout(rng, "general")
	var blacksmith = _generate_building_layout(rng, "blacksmith")

	# Place General Store
	var general_store_pos = town_center + Vector2i(-6, -2)
	_place_building(world_map, general_store_pos, general_store, rng)
	var general_npc_pos = general_store_pos + Vector2i(general_store.width / 2, general_store.height / 2)
	npc_spawns.append({
		"npc_type": "shop",
		"shop_type": "general",
		"npc_id": "shop_keeper",
		"position": general_npc_pos,
		"name": "Olaf the Trader",
		"gold": 500,
		"restock_interval": 500
	})

	# Place Blacksmith (offset from general store)
	var blacksmith_pos = town_center + Vector2i(2, 1)
	_place_building(world_map, blacksmith_pos, blacksmith, rng)
	var blacksmith_npc_pos = blacksmith_pos + Vector2i(blacksmith.width / 2, blacksmith.height / 2)
	npc_spawns.append({
		"npc_type": "shop",
		"shop_type": "blacksmith",
		"npc_id": "blacksmith",
		"position": blacksmith_npc_pos,
		"name": "Grenda the Smith",
		"gold": 800,
		"restock_interval": 500
	})

	world_map.set_meta("npc_spawns", npc_spawns)

	# Place well (water source) in town square area
	var well_pos = town_center + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-4, -2))
	_place_well(world_map, well_pos)

	# Add some decorative elements
	_add_town_decorations(world_map, town_center, rng)

	# Mark as safe zone (no enemy spawns)
	world_map.set_meta("safe_zone", true)
	world_map.set_meta("town_center", town_center)

	print("Town generated at position: ", town_center)

## Find a valid location for the town (on land, not near water edges)
static func _find_valid_town_location(world_map: GameMap, rng: SeededRandom) -> Vector2i:
	var margin = TOWN_CLEAR_RADIUS + 5
	var max_attempts = 200

	for attempt in range(max_attempts):
		var x = rng.randi_range(margin, world_map.width - margin)
		var y = rng.randi_range(margin, world_map.height - margin)
		var pos = Vector2i(x, y)

		# Check if this location and surrounding area is valid (all land)
		if _is_valid_town_location(world_map, pos):
			return pos

	# Fallback: try center of map
	var center = Vector2i(world_map.width / 2, world_map.height / 2)
	if _is_valid_town_location(world_map, center):
		return center

	return Vector2i(-1, -1)

## Check if a position is valid for town placement
static func _is_valid_town_location(world_map: GameMap, center: Vector2i) -> bool:
	var check_radius = TOWN_CLEAR_RADIUS + 2

	# Sample points around the town area to ensure it's all on land
	for dx in range(-check_radius, check_radius + 1, 3):
		for dy in range(-check_radius, check_radius + 1, 3):
			var check_pos = center + Vector2i(dx, dy)

			if check_pos.x < 0 or check_pos.x >= world_map.width:
				return false
			if check_pos.y < 0 or check_pos.y >= world_map.height:
				return false

			var tile = world_map.get_tile(check_pos)
			if tile and tile.tile_type == "water":
				return false

	return true

## Building layout data structure
class BuildingLayout:
	var width: int
	var height: int
	var door_side: String  # "north", "south", "east", "west"
	var door_offset: int   # Offset along the wall from corner

## Generate a varied building layout
static func _generate_building_layout(rng: SeededRandom, building_type: String) -> BuildingLayout:
	var layout = BuildingLayout.new()

	# Vary building size based on type
	match building_type:
		"general":
			layout.width = rng.randi_range(5, 7)
			layout.height = rng.randi_range(4, 6)
		"blacksmith":
			layout.width = rng.randi_range(6, 8)
			layout.height = rng.randi_range(5, 6)
		_:
			layout.width = rng.randi_range(4, 6)
			layout.height = rng.randi_range(4, 5)

	# Randomize door position
	var sides = ["north", "south", "east", "west"]
	layout.door_side = sides[rng.randi_range(0, 3)]

	# Door offset from corner (not in corner, somewhere along the wall)
	if layout.door_side == "north" or layout.door_side == "south":
		layout.door_offset = rng.randi_range(1, layout.width - 2)
	else:
		layout.door_offset = rng.randi_range(1, layout.height - 2)

	return layout

## Clears the town area with an organic shape (not rectangular)
static func _clear_town_area(world_map: GameMap, center: Vector2i, rng: SeededRandom):
	for dx in range(-TOWN_CLEAR_RADIUS, TOWN_CLEAR_RADIUS + 1):
		for dy in range(-TOWN_CLEAR_RADIUS, TOWN_CLEAR_RADIUS + 1):
			var pos = center + Vector2i(dx, dy)

			if pos.x < 0 or pos.x >= world_map.width:
				continue
			if pos.y < 0 or pos.y >= world_map.height:
				continue

			# Use distance with some noise for organic shape
			var dist = sqrt(float(dx * dx + dy * dy))
			var noise_offset = sin(float(dx) * 0.5) * cos(float(dy) * 0.7) * 2.0

			if dist < TOWN_CLEAR_RADIUS + noise_offset:
				var tile = GameTile.create("floor")
				world_map.set_tile(pos, tile)

## Places a building with varied layout
static func _place_building(world_map: GameMap, pos: Vector2i, layout: BuildingLayout, rng: SeededRandom):
	# Create walls and floor
	for x in range(pos.x, pos.x + layout.width):
		for y in range(pos.y, pos.y + layout.height):
			if x < 0 or x >= world_map.width or y < 0 or y >= world_map.height:
				continue

			var is_wall = (x == pos.x or x == pos.x + layout.width - 1 or
						   y == pos.y or y == pos.y + layout.height - 1)

			var tile = GameTile.create("wall" if is_wall else "floor")
			world_map.set_tile(Vector2i(x, y), tile)

	# Place door based on layout
	var door_pos = _get_door_position(pos, layout)
	if door_pos.x >= 0 and door_pos.x < world_map.width and door_pos.y >= 0 and door_pos.y < world_map.height:
		var door_tile = GameTile.create("door")
		world_map.set_tile(door_pos, door_tile)

## Calculate door position based on building layout
static func _get_door_position(building_pos: Vector2i, layout: BuildingLayout) -> Vector2i:
	match layout.door_side:
		"north":
			return Vector2i(building_pos.x + layout.door_offset, building_pos.y)
		"south":
			return Vector2i(building_pos.x + layout.door_offset, building_pos.y + layout.height - 1)
		"east":
			return Vector2i(building_pos.x + layout.width - 1, building_pos.y + layout.door_offset)
		"west":
			return Vector2i(building_pos.x, building_pos.y + layout.door_offset)
		_:
			return Vector2i(building_pos.x + layout.width / 2, building_pos.y + layout.height - 1)

## Places a well (water source)
static func _place_well(world_map: GameMap, pos: Vector2i):
	if pos.x >= 0 and pos.x < world_map.width and pos.y >= 0 and pos.y < world_map.height:
		var well_tile = GameTile.create("water")
		world_map.set_tile(pos, well_tile)

## Adds decorative elements to the town
static func _add_town_decorations(world_map: GameMap, center: Vector2i, rng: SeededRandom):
	# Add a few trees around the edges of the cleared area
	var num_trees = rng.randi_range(4, 8)

	for i in range(num_trees):
		var angle = rng.randf() * TAU
		var dist = TOWN_CLEAR_RADIUS - rng.randi_range(1, 3)
		var dx = int(cos(angle) * dist)
		var dy = int(sin(angle) * dist)
		var tree_pos = center + Vector2i(dx, dy)

		if tree_pos.x >= 0 and tree_pos.x < world_map.width and tree_pos.y >= 0 and tree_pos.y < world_map.height:
			var tile = world_map.get_tile(tree_pos)
			if tile and tile.walkable and tile.tile_type == "floor":
				var tree_tile = GameTile.create("tree")
				world_map.set_tile(tree_pos, tree_tile)

## Checks if a position is within the town bounds
static func is_in_town(position: Vector2i, world_map: GameMap) -> bool:
	if not world_map.has_meta("town_center"):
		return false
	var town_center = world_map.get_meta("town_center")
	var dist = (position - town_center).length()
	return dist <= TOWN_CLEAR_RADIUS
