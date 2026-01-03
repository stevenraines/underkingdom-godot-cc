extends Node
## TownGenerator - Generates towns based on data-driven definitions
##
## Creates safe zones with buildings, NPCs, and resources based on
## JSON town definitions loaded by TownManager.

# Type references
const GameTile = preload("res://maps/game_tile.gd")
const SeededRandom = preload("res://generation/seeded_random.gd")

## Generates a town at the specified position using the given town definition
## Returns the town data dictionary with all placement information
## town_def and building_defs are passed from TownManager to avoid static scope issues
static func generate_town(town_id: String, center_pos: Vector2i, world_seed: int, tiles_dict: Dictionary, town_def: Dictionary, building_defs: Dictionary) -> Dictionary:
	if town_def.is_empty():
		push_warning("[TownGenerator] Empty town definition for: %s, using defaults" % town_id)
		town_def = _get_default_town_definition()

	var rng = SeededRandom.new(world_seed + hash(town_id) + center_pos.x * 1000 + center_pos.y)

	# Get town size from definition
	var size_array = town_def.get("size", [15, 15])
	var town_size = Vector2i(size_array[0], size_array[1])

	# Clear the town area (make it walkable floor)
	_clear_town_area(tiles_dict, center_pos, town_size, world_seed)

	# Track NPC spawn positions
	var npc_spawns: Array = []

	# Place buildings from definition
	var buildings = town_def.get("buildings", [])
	for building_entry in buildings:
		var building_id = building_entry.get("building_id", "")
		var offset_array = building_entry.get("position_offset", [0, 0])
		var offset = Vector2i(offset_array[0], offset_array[1])
		var npc_id = building_entry.get("npc_id", "")

		var building_pos = center_pos + offset
		var building_def = building_defs.get(building_id, {})
		var npc_pos = _place_building(tiles_dict, building_def, building_pos, rng)

		# If building has an NPC, record spawn position
		if not npc_id.is_empty() and npc_pos != Vector2i(-1, -1):
			npc_spawns.append({
				"npc_id": npc_id,
				"position": npc_pos
			})

	# Add decorative trees if enabled
	var decorations = town_def.get("decorations", {})
	if decorations.get("perimeter_trees", false):
		var max_trees = decorations.get("max_trees", 12)
		_add_decorative_trees(tiles_dict, center_pos, town_size, max_trees, rng)

	# Build result data
	var town_data = {
		"town_id": town_id,
		"name": town_def.get("name", town_id),
		"position": center_pos,
		"size": town_size,
		"is_safe_zone": town_def.get("is_safe_zone", true),
		"npc_spawns": npc_spawns
	}

	print("[TownGenerator] Generated %s at %v (size %v, %d NPCs)" % [town_data.name, center_pos, town_size, npc_spawns.size()])
	return town_data

## Clear the town area to walkable floor
static func _clear_town_area(tiles_dict: Dictionary, center: Vector2i, size: Vector2i, world_seed: int) -> void:
	var half_size = size / 2
	var start = center - half_size

	for x in range(size.x):
		for y in range(size.y):
			var local_pos = Vector2i(x, y)
			var world_pos = start + local_pos

			# Get biome for appropriate floor coloring
			var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

			var tile = GameTile.create("floor")
			tile.ascii_char = biome.grass_char
			if biome.grass_char == ".":
				tile.color = biome.color_floor
			else:
				tile.color = biome.color_grass

			tiles_dict[world_pos] = tile

## Place a building and return the NPC spawn position (or -1,-1 if no NPC position)
static func _place_building(tiles_dict: Dictionary, building_def: Dictionary, pos: Vector2i, rng: SeededRandom) -> Vector2i:
	if building_def.is_empty():
		push_warning("[TownGenerator] Empty building definition")
		return Vector2i(-1, -1)

	var template_type = building_def.get("template_type", "building")

	if template_type == "feature":
		# Simple single-tile feature (like well)
		return _place_feature(tiles_dict, building_def, pos)
	elif template_type == "building":
		# Standard building with walls, floor, door
		return _place_standard_building(tiles_dict, building_def, pos, rng)
	elif template_type == "custom":
		# Custom tile-by-tile layout
		return _place_custom_building(tiles_dict, building_def, pos)

	return Vector2i(-1, -1)

## Place a simple feature tile (well, shrine, etc.)
static func _place_feature(tiles_dict: Dictionary, building_def: Dictionary, pos: Vector2i) -> Vector2i:
	var tile_type = building_def.get("tile_type", "floor")
	var tile = GameTile.create(tile_type)
	tiles_dict[pos] = tile
	return Vector2i(-1, -1)  # Features don't have NPC positions

## Place a standard building with walls and door
static func _place_standard_building(tiles_dict: Dictionary, building_def: Dictionary, pos: Vector2i, _rng: SeededRandom) -> Vector2i:
	var size_array = building_def.get("size", [5, 5])
	var size = Vector2i(size_array[0], size_array[1])
	var half_size = size / 2
	var start = pos - half_size

	var door_position = building_def.get("door_position", "south")
	var npc_offset_array = building_def.get("npc_offset", [size.x / 2, size.y / 2])
	var npc_offset = Vector2i(npc_offset_array[0], npc_offset_array[1])

	# Place walls and floor
	for x in range(size.x):
		for y in range(size.y):
			var world_pos = start + Vector2i(x, y)
			var is_wall = (x == 0 or x == size.x - 1 or y == 0 or y == size.y - 1)

			# Check for door position
			var is_door = false
			if door_position == "south" and y == size.y - 1 and x == size.x / 2:
				is_door = true
			elif door_position == "north" and y == 0 and x == size.x / 2:
				is_door = true
			elif door_position == "east" and x == size.x - 1 and y == size.y / 2:
				is_door = true
			elif door_position == "west" and x == 0 and y == size.y / 2:
				is_door = true

			var tile: GameTile
			if is_door:
				tile = GameTile.create("door")
			elif is_wall:
				tile = GameTile.create("wall")
			else:
				tile = GameTile.create("floor")
				tile.color = Color.WHITE  # Indoor floor uses default color

			tiles_dict[world_pos] = tile

	# Return NPC spawn position (inside the building)
	return start + npc_offset

## Place a custom building with tile-by-tile layout
static func _place_custom_building(tiles_dict: Dictionary, building_def: Dictionary, pos: Vector2i) -> Vector2i:
	var layout = building_def.get("layout", null)
	if layout == null:
		push_warning("[TownGenerator] Custom building missing layout")
		return Vector2i(-1, -1)

	var size_array = building_def.get("size", [5, 5])
	var size = Vector2i(size_array[0], size_array[1])
	var half_size = size / 2
	var start = pos - half_size

	var npc_pos = Vector2i(-1, -1)

	# Layout is expected to be an array of strings, each representing a row
	for y in range(min(layout.size(), size.y)):
		var row = layout[y]
		for x in range(min(row.length(), size.x)):
			var tile_char = row[x]
			var world_pos = start + Vector2i(x, y)
			var tile = _char_to_tile(tile_char)
			tiles_dict[world_pos] = tile

			# '@' marks NPC spawn position
			if tile_char == "@":
				npc_pos = world_pos

	return npc_pos

## Convert layout character to tile
static func _char_to_tile(tile_char: String) -> GameTile:
	match tile_char:
		"#":
			return GameTile.create("wall")
		"+":
			return GameTile.create("door")
		".":
			return GameTile.create("floor")
		"~":
			return GameTile.create("water")
		"@":
			var tile = GameTile.create("floor")
			tile.color = Color.WHITE
			return tile
		_:
			return GameTile.create("floor")

## Add decorative trees around town perimeter
static func _add_decorative_trees(tiles_dict: Dictionary, center: Vector2i, size: Vector2i, max_trees: int, rng: SeededRandom) -> void:
	var half_size = size / 2
	var start = center - half_size
	var trees_placed = 0

	while trees_placed < max_trees:
		# Random position on perimeter
		var edge = rng.randi_range(0, 3)
		var x: int
		var y: int

		match edge:
			0:  # Top edge
				x = rng.randi_range(0, size.x - 1)
				y = 0
			1:  # Bottom edge
				x = rng.randi_range(0, size.x - 1)
				y = size.y - 1
			2:  # Left edge
				x = 0
				y = rng.randi_range(0, size.y - 1)
			3:  # Right edge
				x = size.x - 1
				y = rng.randi_range(0, size.y - 1)

		var pos = start + Vector2i(x, y)

		# Only place on walkable floor that doesn't already have something
		if pos in tiles_dict:
			var existing = tiles_dict[pos]
			if existing.walkable and existing.tile_type == "floor":
				var tree_tile = GameTile.create("floor")
				tree_tile.walkable = false
				tree_tile.transparent = false
				tree_tile.ascii_char = "T"
				tree_tile.color = Color.WHITE
				tiles_dict[pos] = tree_tile
				trees_placed += 1

## Returns default town definition for fallback
static func _get_default_town_definition() -> Dictionary:
	return {
		"id": "default",
		"name": "Settlement",
		"size": [15, 15],
		"is_safe_zone": true,
		"buildings": [
			{"building_id": "shop", "position_offset": [0, 0], "npc_id": "shop_keeper"},
			{"building_id": "well", "position_offset": [4, 4]}
		],
		"decorations": {"perimeter_trees": true, "max_trees": 12}
	}
