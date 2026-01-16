extends Node
## TownGenerator - Generates towns based on data-driven definitions
##
## Creates safe zones with buildings, NPCs, and resources based on
## JSON town definitions loaded by TownManager.

# Type references
const GameTile = preload("res://maps/game_tile.gd")
const SeededRandom = preload("res://generation/seeded_random.gd")
const RoadGeneratorClass = preload("res://generation/road_generator.gd")

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
		var door_facing = building_entry.get("door_facing", "south")
		var dock_auto_orient = building_entry.get("dock_auto_orient", false)

		var building_def = building_defs.get(building_id, {})
		var building_pos = center_pos + offset

		# Handle dock auto-orientation toward ocean
		if dock_auto_orient and building_def.get("dock_building", false):
			var dock_result = _place_dock_toward_ocean(tiles_dict, building_def, center_pos, town_size, world_seed)
			door_facing = dock_result.direction
			building_pos = dock_result.position
			print("[TownGenerator] Auto-oriented dock to face %s at %v" % [door_facing, building_pos])

		var npc_pos = _place_building(tiles_dict, building_def, building_pos, rng, door_facing)

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

	# Generate internal town roads if enabled
	var roads_config = town_def.get("roads", {})
	if roads_config.get("internal_roads", false) or roads_config.get("town_square", false):
		var has_town_square = roads_config.get("town_square", false)
		RoadGeneratorClass.generate_town_roads(tiles_dict, center_pos, town_size, buildings, building_defs, has_town_square)

	# Generate crop fields if defined
	var features = town_def.get("features", {})
	var crop_fields = features.get("crop_fields", [])
	var crop_spawns: Array = []
	for field in crop_fields:
		var field_crops = _generate_crop_field(tiles_dict, center_pos, field, rng)
		crop_spawns.append_array(field_crops)

	# Build result data
	var town_data = {
		"town_id": town_id,
		"name": town_def.get("name", town_id),
		"position": center_pos,
		"size": town_size,
		"is_safe_zone": town_def.get("is_safe_zone", true),
		"npc_spawns": npc_spawns,
		"crop_spawns": crop_spawns,
		"roads_connected": roads_config.get("connected_to_other_towns", false)
	}

	print("[TownGenerator] Generated %s at %v (size %v, %d NPCs)" % [town_data.name, center_pos, town_size, npc_spawns.size()])
	return town_data

## Clear the town area to walkable floor
## Preserves special tiles like dungeon entrances
static func _clear_town_area(tiles_dict: Dictionary, center: Vector2i, size: Vector2i, world_seed: int) -> void:
	var half_size = size / 2
	var start = center - half_size

	for x in range(size.x):
		for y in range(size.y):
			var local_pos = Vector2i(x, y)
			var world_pos = start + local_pos

			# Preserve dungeon entrance tiles - don't overwrite them
			if world_pos in tiles_dict:
				var existing = tiles_dict[world_pos]
				if existing.tile_type == "dungeon_entrance":
					continue

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
static func _place_building(tiles_dict: Dictionary, building_def: Dictionary, pos: Vector2i, rng: SeededRandom, door_facing: String = "south") -> Vector2i:
	if building_def.is_empty():
		push_warning("[TownGenerator] Empty building definition")
		return Vector2i(-1, -1)

	var template_type = building_def.get("template_type", "building")

	if template_type == "feature":
		# Simple single-tile feature (like well)
		return _place_feature(tiles_dict, building_def, pos)
	elif template_type == "building":
		# Standard building with walls, floor, door
		return _place_standard_building(tiles_dict, building_def, pos, rng, door_facing)
	elif template_type == "custom":
		# Custom tile-by-tile layout with rotation support
		return _place_custom_building(tiles_dict, building_def, pos, door_facing)

	return Vector2i(-1, -1)

## Place a simple feature tile (well, shrine, etc.)
static func _place_feature(tiles_dict: Dictionary, building_def: Dictionary, pos: Vector2i) -> Vector2i:
	var tile_type = building_def.get("tile_type", "floor")
	var tile = GameTile.create(tile_type)

	# Apply custom ascii_char and color if specified
	if building_def.has("ascii_char"):
		tile.ascii_char = building_def.get("ascii_char")
		print("[TownGenerator] Feature '%s' placed at %v with char '%s' (U+%04X)" % [building_def.get("id", "unknown"), pos, tile.ascii_char, tile.ascii_char.unicode_at(0)])
	if building_def.has("ascii_color"):
		tile.color = Color.html(building_def.get("ascii_color"))

	# Apply walkable/transparent properties if specified (e.g., shrine is blocking)
	if building_def.has("walkable"):
		tile.walkable = building_def.get("walkable")
	if building_def.has("transparent"):
		tile.transparent = building_def.get("transparent")

	tiles_dict[pos] = tile
	return Vector2i(-1, -1)  # Features don't have NPC positions

## Place a standard building with walls and door
## Preserves dungeon entrance tiles
static func _place_standard_building(tiles_dict: Dictionary, building_def: Dictionary, pos: Vector2i, _rng: SeededRandom, door_facing: String = "south") -> Vector2i:
	var size_array = building_def.get("size", [5, 5])
	var size = Vector2i(size_array[0], size_array[1])
	var half_size = size / 2
	var start = pos - half_size

	# Use door_facing from town definition, fall back to building's door_position
	var door_position = door_facing if door_facing != "" else building_def.get("door_position", "south")
	var npc_offset_array = building_def.get("npc_offset", [size.x / 2, size.y / 2])
	var npc_offset = Vector2i(npc_offset_array[0], npc_offset_array[1])

	# Place walls and floor
	for x in range(size.x):
		for y in range(size.y):
			var world_pos = start + Vector2i(x, y)

			# Preserve dungeon entrance tiles - don't overwrite them
			if world_pos in tiles_dict:
				var existing = tiles_dict[world_pos]
				if existing.tile_type == "dungeon_entrance":
					continue

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
				tile = GameTile.create("door_closed")  # Exterior doors start closed
				tile.is_interior = true  # Mark doors as interior for FOV
			elif is_wall:
				tile = GameTile.create("wall")
				tile.is_interior = true  # Mark walls as interior for FOV
			else:
				tile = GameTile.create("floor")
				tile.color = Color.WHITE  # Indoor floor uses default color
				tile.is_interior = true  # Mark as interior for temperature bonus

			tiles_dict[world_pos] = tile

	# Return NPC spawn position (inside the building)
	return start + npc_offset

## Place a custom building with tile-by-tile layout
## Supports rotation via door_facing parameter (south=0, west=90, north=180, east=270)
## Supports structure placement via legend dictionary in building definition
static func _place_custom_building(tiles_dict: Dictionary, building_def: Dictionary, pos: Vector2i, door_facing: String = "south") -> Vector2i:
	var layout = building_def.get("layout", null)
	if layout == null:
		push_warning("[TownGenerator] Custom building missing layout")
		return Vector2i(-1, -1)

	var size_array = building_def.get("size", [5, 5])
	var size = Vector2i(size_array[0], size_array[1])

	# Get legend for custom structure mapping
	var legend = building_def.get("legend", {})

	# Rotate layout if needed (layouts are defined with door facing south)
	var rotated_layout = _rotate_layout(layout, door_facing)
	var rotated_size = size if door_facing in ["south", "north"] else Vector2i(size.y, size.x)

	var half_size = rotated_size / 2
	var start = pos - half_size

	var npc_pos = Vector2i(-1, -1)
	var door_positions: Array[Vector2i] = []
	var structure_placements: Array = []  # [{structure_id, position}]

	# First pass: place all tiles and track door positions
	for y in range(min(rotated_layout.size(), rotated_size.y)):
		var row = rotated_layout[y]
		for x in range(min(row.length(), rotated_size.x)):
			var tile_char = row[x]
			if tile_char == " ":
				continue  # Skip empty spaces
			var world_pos = start + Vector2i(x, y)

			# Check legend for structure placement
			if tile_char in legend:
				var legend_entry = legend[tile_char]
				if legend_entry == "npc_spawn":
					# NPC spawn marker
					var tile = GameTile.create("floor")
					tile.color = Color.WHITE
					tile.is_interior = true
					tiles_dict[world_pos] = tile
					npc_pos = world_pos
				else:
					# Structure placement - place floor tile and queue structure
					var tile = GameTile.create("floor")
					tile.is_interior = true
					tiles_dict[world_pos] = tile
					structure_placements.append({
						"structure_id": legend_entry,
						"position": world_pos
					})
			else:
				var tile = _char_to_tile(tile_char)
				tiles_dict[world_pos] = tile

				# '@' marks NPC spawn position (default)
				if tile_char == "@":
					npc_pos = world_pos

				# Track door positions for second pass
				if tile_char == "+":
					door_positions.append(world_pos)

	# Second pass: lock interior doors (doors surrounded by interior tiles)
	for door_pos in door_positions:
		if _is_interior_door(tiles_dict, door_pos):
			var door_tile = tiles_dict[door_pos]
			door_tile.is_open = false
			door_tile.walkable = false
			door_tile.transparent = false
			door_tile.ascii_char = "+"
			door_tile.is_locked = true

	# Third pass: place structures from legend
	for placement in structure_placements:
		var structure_id = placement.structure_id
		var structure_pos = placement.position
		var structure = StructureManager.create_structure(structure_id, structure_pos)
		if structure:
			var map_id = "overworld"  # Town structures are placed in overworld
			StructureManager.place_structure(map_id, structure)
			print("[TownGenerator] Placed structure '%s' at %v" % [structure_id, structure_pos])

	return npc_pos

## Check if a door is an interior door (has walkable interior floor tiles on both sides)
## Interior doors connect two interior spaces, exterior doors connect interior to exterior
## Must check for walkable floor tiles, not walls (which are also marked as interior for FOV)
static func _is_interior_door(tiles_dict: Dictionary, door_pos: Vector2i) -> bool:
	# Check horizontal neighbors (left and right)
	var left_pos = door_pos + Vector2i(-1, 0)
	var right_pos = door_pos + Vector2i(1, 0)
	var left_tile = tiles_dict.get(left_pos)
	var right_tile = tiles_dict.get(right_pos)

	# If both left and right are walkable interior floor tiles, this is a horizontal interior door
	if left_tile and right_tile:
		if left_tile.is_interior and left_tile.walkable and right_tile.is_interior and right_tile.walkable:
			return true

	# Check vertical neighbors (up and down)
	var up_pos = door_pos + Vector2i(0, -1)
	var down_pos = door_pos + Vector2i(0, 1)
	var up_tile = tiles_dict.get(up_pos)
	var down_tile = tiles_dict.get(down_pos)

	# If both up and down are walkable interior floor tiles, this is a vertical interior door
	if up_tile and down_tile:
		if up_tile.is_interior and up_tile.walkable and down_tile.is_interior and down_tile.walkable:
			return true

	return false

## Rotate a layout array based on door facing direction
## Layouts are defined with door facing south (bottom)
static func _rotate_layout(layout: Array, door_facing: String) -> Array:
	if door_facing == "south":
		return layout  # No rotation needed

	var height = layout.size()
	var width = 0
	for row in layout:
		width = max(width, row.length())

	# Pad rows to equal width
	var padded: Array = []
	for row in layout:
		padded.append(row + " ".repeat(width - row.length()))

	var rotated: Array = []

	if door_facing == "north":
		# 180 degree rotation
		for y in range(height - 1, -1, -1):
			var new_row = ""
			for x in range(width - 1, -1, -1):
				new_row += padded[y][x]
			rotated.append(new_row)
	elif door_facing == "west":
		# 90 degree clockwise rotation
		for x in range(width):
			var new_row = ""
			for y in range(height - 1, -1, -1):
				new_row += padded[y][x]
			rotated.append(new_row)
	elif door_facing == "east":
		# 90 degree counter-clockwise rotation
		for x in range(width - 1, -1, -1):
			var new_row = ""
			for y in range(height):
				new_row += padded[y][x]
			rotated.append(new_row)

	return rotated

## Convert layout character to tile
static func _char_to_tile(tile_char: String) -> GameTile:
	match tile_char:
		"#":
			var tile = GameTile.create("wall")
			tile.is_interior = true  # Mark walls as interior for FOV
			return tile
		"+":
			var tile = GameTile.create("door_closed")  # Doors start closed
			tile.is_interior = true  # Mark doors as interior for FOV
			return tile
		".":
			var tile = GameTile.create("floor")
			tile.is_interior = true  # Floor inside building
			return tile
		"~":
			return GameTile.create("water")
		"=":
			# Dock plank - walkable wooden surface over water
			return GameTile.create("dock_plank")
		"O":
			# Dock post - mooring post at end of dock
			return GameTile.create("dock_post")
		"@":
			var tile = GameTile.create("floor")
			tile.color = Color.WHITE
			tile.is_interior = true  # NPC spawn point is inside building
			return tile
		_:
			var tile = GameTile.create("floor")
			tile.is_interior = true  # Default to interior for unknown chars in buildings
			return tile

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
				var tree_tile = GameTile.create("tree")
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

## Generate a crop field and return array of crop spawn data
## Each spawn has: crop_id, position, mature (bool)
static func _generate_crop_field(tiles_dict: Dictionary, center_pos: Vector2i, field_def: Dictionary, _rng: SeededRandom) -> Array:
	var crop_spawns: Array = []

	var crop_id = field_def.get("crop_id", "")
	if crop_id.is_empty():
		return crop_spawns

	var offset_array = field_def.get("position_offset", [0, 0])
	var offset = Vector2i(offset_array[0], offset_array[1])
	var width = field_def.get("width", 3)
	var height = field_def.get("height", 3)
	var mature = field_def.get("mature", false)

	var field_start = center_pos + offset

	for x in range(width):
		for y in range(height):
			var pos = field_start + Vector2i(x, y)

			# Place tilled soil tile at this position
			var soil_tile = GameTile.create("tilled_soil")
			tiles_dict[pos] = soil_tile

			# Add crop spawn data (crops will be spawned by the chunk/map system)
			crop_spawns.append({
				"crop_id": crop_id,
				"position": pos,
				"mature": mature
			})

	print("[TownGenerator] Generated %dx%d crop field of %s at %v (mature=%s)" % [width, height, crop_id, field_start, mature])
	return crop_spawns


## Place a dock building oriented toward the nearest water body (ocean or fresh water lake)
## Returns dictionary with "direction" (door_facing) and "position" for the dock
static func _place_dock_toward_ocean(_tiles_dict: Dictionary, building_def: Dictionary, town_center: Vector2i, _town_size: Vector2i, world_seed: int) -> Dictionary:
	var water_biomes = ["ocean", "deep_ocean", "fresh_water", "deep_fresh_water"]

	# Check cardinal directions first (preferred for dock orientation)
	# Store distances for each direction
	var direction_distances = {}
	var directions = [
		{"name": "north", "dx": 0, "dy": -1},
		{"name": "south", "dx": 0, "dy": 1},
		{"name": "east", "dx": 1, "dy": 0},
		{"name": "west", "dx": -1, "dy": 0}
	]

	# Find water distance in each cardinal direction
	for dir in directions:
		for dist in range(1, 80):
			var check_pos = town_center + Vector2i(dir.dx * dist, dir.dy * dist)
			var biome = BiomeGenerator.get_biome_at(check_pos.x, check_pos.y, world_seed)

			if biome.biome_name in water_biomes:
				direction_distances[dir.name] = dist
				print("[TownGenerator] Water found %s at distance %d (biome: %s)" % [dir.name, dist, biome.biome_name])
				break

	# Find the direction with the shortest distance to water
	var min_distance = 9999
	var best_direction = "south"  # Default fallback

	for dir_name in direction_distances:
		var dist = direction_distances[dir_name]
		if dist < min_distance:
			min_distance = dist
			best_direction = dir_name

	# Safety check: if no water found, use a reasonable default
	if direction_distances.is_empty():
		push_warning("[TownGenerator] No water found near town center %v - placing dock at default position" % town_center)
		min_distance = 10  # Default distance

	var cardinal_direction = best_direction
	print("[TownGenerator] Best water direction: %s at %d tiles" % [cardinal_direction, min_distance])

	# Get dock size - the long dimension (height) extends toward water
	var size_array = building_def.get("size", [3, 8])
	var dock_length = size_array[1]  # The long dimension extends toward water
	var half_dock = dock_length / 2

	# Position dock so its far end reaches INTO the water
	# The dock is placed at its center, so:
	# - Near end is at center - (half_dock - 1) = center - 3 for an 8-tile dock
	# - Far end is at center + (half_dock - 1) = center + 3
	# We want the far end to be 2 tiles past the water edge (into the water)
	# So: center_offset + (half_dock - 1) = min_distance + 2
	# Therefore: center_offset = min_distance - half_dock + 3
	var center_offset = min_distance - half_dock + 3

	# Ensure minimum offset so dock near end isn't at town center
	center_offset = maxi(center_offset, half_dock + 1)

	var dock_pos = town_center

	print("[TownGenerator] Dock calc: min_distance=%d, dock_length=%d, half_dock=%d, center_offset=%d" % [min_distance, dock_length, half_dock, center_offset])

	match cardinal_direction:
		"north":
			dock_pos = town_center + Vector2i(0, -center_offset)
		"south":
			dock_pos = town_center + Vector2i(0, center_offset)
		"east":
			dock_pos = town_center + Vector2i(center_offset, 0)
		"west":
			dock_pos = town_center + Vector2i(-center_offset, 0)

	print("[TownGenerator] Placing dock at %v facing %s (water at %d tiles from town center)" % [dock_pos, cardinal_direction, min_distance])

	return {
		"direction": cardinal_direction,
		"position": dock_pos
	}
