extends Node
## TownGenerator - Generates town area in the overworld
##
## Creates a safe zone with buildings, NPCs, and resources.
## Phase 1: Single town with one shop NPC.

# Type references
const GameTile = preload("res://maps/game_tile.gd")
const SeededRandom = preload("res://generation/seeded_random.gd")

# Town constants
const TOWN_SIZE = Vector2i(15, 15)  # Smaller to fit in 20x20 map
const TOWN_POSITION = Vector2i(2, 2)  # Top-left corner of town in 20x20 map
const SHOP_SIZE = Vector2i(5, 5)

## Generates town in the overworld map
static func generate_town(world_map: GameMap, world_seed: int):
	var rng = SeededRandom.new(world_seed + 999)  # Seed offset for town generation

	# Clear area for town
	var town_rect = Rect2i(TOWN_POSITION, TOWN_SIZE)
	_clear_town_area(world_map, town_rect)

	# Place shop building
	var shop_pos = TOWN_POSITION + Vector2i(7, 8)
	_place_building(world_map, shop_pos, SHOP_SIZE)

	# Store shop NPC spawn data in metadata (will be created when map loads)
	var npc_pos = shop_pos + Vector2i(2, 2)
	if not world_map.has_meta("npc_spawns"):
		world_map.set_meta("npc_spawns", [])

	var npc_spawns = world_map.get_meta("npc_spawns")
	npc_spawns.append({
		"npc_type": "shop",
		"npc_id": "shop_keeper",
		"position": npc_pos,
		"name": "Olaf the Trader",
		"gold": 500
	})
	world_map.set_meta("npc_spawns", npc_spawns)

	# Place well (water source) near town center
	var well_pos = TOWN_POSITION + Vector2i(15, 10)
	_place_well(world_map, well_pos)

	# Add decorative trees around perimeter
	_add_decorative_trees(world_map, town_rect, rng)

	# Mark as safe zone (no enemy spawns)
	world_map.metadata["safe_zone"] = true
	world_map.metadata["town_center"] = TOWN_POSITION

	print("Town generated at position: ", TOWN_POSITION)

## Clears the town area of trees and creates grass floor
static func _clear_town_area(world_map: GameMap, town_rect: Rect2i):
	for x in range(town_rect.position.x, town_rect.position.x + town_rect.size.x):
		for y in range(town_rect.position.y, town_rect.position.y + town_rect.size.y):
			if x >= 0 and x < world_map.width and y >= 0 and y < world_map.height:
				var tile = GameTile.create("floor")
				world_map.set_tile(Vector2i(x, y), tile)

## Places a building (walls and floor)
static func _place_building(world_map: GameMap, pos: Vector2i, size: Vector2i):
	# Create walls and floor
	for x in range(pos.x, pos.x + size.x):
		for y in range(pos.y, pos.y + size.y):
			var is_wall = (x == pos.x or x == pos.x + size.x - 1 or
						   y == pos.y or y == pos.y + size.y - 1)

			var tile = GameTile.create("wall" if is_wall else "floor")
			world_map.set_tile(Vector2i(x, y), tile)

	# Add door on south side (center)
	var door_pos = Vector2i(pos.x + size.x / 2, pos.y + size.y - 1)
	var door_tile = GameTile.create("door")
	world_map.set_tile(door_pos, door_tile)


## Places a well (water source)
static func _place_well(world_map: GameMap, pos: Vector2i):
	var well_tile = GameTile.create("water")
	world_map.set_tile(pos, well_tile)

## Adds decorative trees around town perimeter
static func _add_decorative_trees(world_map: GameMap, town_rect: Rect2i, rng: SeededRandom):
	var trees_placed = 0
	var max_trees = 20

	while trees_placed < max_trees:
		var x = rng.randi_range(town_rect.position.x, town_rect.position.x + town_rect.size.x - 1)
		var y = rng.randi_range(town_rect.position.y, town_rect.position.y + town_rect.size.y - 1)
		var pos = Vector2i(x, y)

		# Only place on perimeter (edges of town)
		var is_perimeter = (x == town_rect.position.x or
							x == town_rect.position.x + town_rect.size.x - 1 or
							y == town_rect.position.y or
							y == town_rect.position.y + town_rect.size.y - 1)

		if is_perimeter and world_map.get_tile(pos).walkable:
			var tree_tile = GameTile.create("tree")
			world_map.set_tile(pos, tree_tile)
			trees_placed += 1

## Checks if a position is within the town bounds
static func is_in_town(position: Vector2i) -> bool:
	var town_rect = Rect2i(TOWN_POSITION, TOWN_SIZE)
	return town_rect.has_point(position)

