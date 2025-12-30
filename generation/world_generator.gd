class_name WorldGenerator

## WorldGenerator - Generate 100x100 overworld with temperate woodland biome
##
## Uses FastNoiseLite for terrain generation (Gaea optional for future).
## Creates a deterministic world based on seed.

const GameTile = preload("res://maps/game_tile.gd")

## Generate the overworld map
static func generate_overworld(seed_value: int) -> GameMap:
	var rng = SeededRandom.new(seed_value)
	var map = GameMap.new("overworld", 20, 20, seed_value)

	# Create noise generator for terrain
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.05

	# Generate terrain based on noise
	for y in range(map.height):
		for x in range(map.width):
			var noise_val = noise.get_noise_2d(float(x), float(y))
			var tile_type = _biome_from_noise(noise_val, rng)
			map.set_tile(Vector2i(x, y), _create_tile(tile_type))

	# Place dungeon entrance at a random walkable location
	var entrance_pos = _find_valid_location(map, rng)
	map.set_tile(entrance_pos, _create_tile("stairs_down"))
	print("Dungeon entrance placed at: ", entrance_pos)

	print("Overworld generated (100x100) with seed: ", seed_value)
	return map

## Map noise value to biome tile type (Temperate Woodland)
## Biome distribution: 60% floor, 30% trees, 5% water, 5% special
static func _biome_from_noise(noise_val: float, rng: SeededRandom) -> String:
	# Normalize noise from [-1, 1] to [0, 1]
	var normalized = (noise_val + 1.0) / 2.0

	# Use noise for terrain variation
	if normalized < 0.1:
		return "water"  # 10% water (ponds/streams)
	elif normalized < 0.4:
		return "tree"  # 30% trees
	else:
		# 60% walkable floor - add some variety
		var rand = rng.randf()
		if rand < 0.05:
			return "tree"  # Occasional extra tree
		else:
			return "floor"  # Grass/dirt

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
		"tree":
			tile.tile_type = "tree"
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "T"
		"water":
			tile.tile_type = "water"
			tile.walkable = false
			tile.transparent = true
			tile.ascii_char = "~"
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
		"door":
			tile.tile_type = "door"
			tile.walkable = true
			tile.transparent = false
			tile.ascii_char = "+"
		_:
			push_warning("Unknown tile type: " + type + ", defaulting to floor")
			tile.tile_type = "floor"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "."

	return tile

## Find a valid walkable location for dungeon entrance
static func _find_valid_location(map: GameMap, rng: SeededRandom) -> Vector2i:
	# Try random positions until we find a walkable one
	var max_attempts = 1000
	for attempt in range(max_attempts):
		var x = rng.randi_range(10, map.width - 10)
		var y = rng.randi_range(10, map.height - 10)
		var pos = Vector2i(x, y)

		if map.is_walkable(pos):
			return pos

	# Fallback to center if no valid location found
	push_warning("Could not find valid dungeon entrance location, using center")
	return Vector2i(map.width / 2, map.height / 2)
