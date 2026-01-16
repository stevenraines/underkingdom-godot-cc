class_name OreVeinGenerator
extends RefCounted
## Generates contiguous ore veins in dungeons
##
## Creates serpentine vein patterns that wind through dungeon walls,
## with portions adjacent to walkable areas so players can mine them.

const GameTile = preload("res://maps/game_tile.gd")

## Ore type definitions with depth ranges and rarity weights
## Higher weight = more common at that depth
const ORE_TYPES: Array = [
	{"id": "copper_vein", "min_floor": 1, "max_floor": 15, "weight": 1.0, "color": "#B87333"},
	{"id": "iron_vein", "min_floor": 1, "max_floor": 25, "weight": 0.7, "color": "#8B8B8B"},
	{"id": "silver_vein", "min_floor": 10, "max_floor": 35, "weight": 0.4, "color": "#C0C0C0"},
	{"id": "gold_vein", "min_floor": 20, "max_floor": 40, "weight": 0.2, "color": "#FFD700"},
	{"id": "mithril_vein", "min_floor": 30, "max_floor": 50, "weight": 0.1, "color": "#7DF9FF"}
]

## Cardinal + diagonal directions for vein expansion
const DIRECTIONS: Array = [
	Vector2i(0, -1),   # Up
	Vector2i(0, 1),    # Down
	Vector2i(-1, 0),   # Left
	Vector2i(1, 0),    # Right
	Vector2i(-1, -1),  # Up-left
	Vector2i(1, -1),   # Up-right
	Vector2i(-1, 1),   # Down-left
	Vector2i(1, 1)     # Down-right
]


## Generate ore veins for a dungeon floor
## @param map: The GameMap to add veins to
## @param floor_number: Current floor depth (affects ore types available)
## @param vein_count: Number of veins to attempt to generate
## @param rng: SeededRandom for deterministic generation
static func generate_veins(map: GameMap, floor_number: int, vein_count: int, rng: SeededRandom) -> void:
	# Get valid ore types for this floor depth
	var valid_ores = _get_valid_ores_for_floor(floor_number)
	if valid_ores.is_empty():
		return

	# Find wall tiles adjacent to walkable tiles (potential vein anchors)
	var anchor_candidates = _find_wall_tiles_adjacent_to_floor(map)
	if anchor_candidates.is_empty():
		return

	# Sort for deterministic order, then shuffle with seeded RNG
	anchor_candidates.sort_custom(func(a, b): return a.x * 10000 + a.y < b.x * 10000 + b.y)
	anchor_candidates = _seeded_shuffle(anchor_candidates, rng)

	var placed_veins: int = 0
	var used_positions: Dictionary = {}  # Track positions already in veins
	var anchor_index: int = 0

	while placed_veins < vein_count and anchor_index < anchor_candidates.size():
		var anchor_pos = anchor_candidates[anchor_index]
		anchor_index += 1

		# Skip if this position is already used
		if anchor_pos in used_positions:
			continue

		# Pick a weighted random ore type
		var ore_type = _pick_weighted_ore(valid_ores, rng)

		# Generate the vein shape starting from anchor
		var vein_tiles = _generate_vein_shape(map, anchor_pos, rng, used_positions)

		# Only place if vein is at least 3 tiles (minimum viable vein)
		if vein_tiles.size() >= 3:
			_place_vein_tiles(map, vein_tiles, ore_type)
			# Mark all positions as used
			for pos in vein_tiles:
				used_positions[pos] = true
			placed_veins += 1


## Get ore types valid for the given floor depth
static func _get_valid_ores_for_floor(floor_number: int) -> Array:
	var valid: Array = []
	for ore in ORE_TYPES:
		if floor_number >= ore.min_floor and floor_number <= ore.max_floor:
			valid.append(ore)
	return valid


## Find all wall tiles that are adjacent to at least one walkable tile
## These are the only positions where ore veins can be mined
static func _find_wall_tiles_adjacent_to_floor(map: GameMap) -> Array:
	var candidates: Array = []

	for pos in map.tiles:
		var tile = map.tiles[pos]
		# Must be a wall tile (non-walkable, non-transparent)
		if tile.walkable or tile.transparent:
			continue
		# Skip special tile types
		if tile.tile_type in ["stairs_up", "stairs_down", "door"]:
			continue

		# Check if adjacent to at least one walkable tile
		var adjacent_to_floor = false
		for dir in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var neighbor_pos = pos + dir
			if map.tiles.has(neighbor_pos):
				var neighbor = map.tiles[neighbor_pos]
				if neighbor.walkable:
					adjacent_to_floor = true
					break

		if adjacent_to_floor:
			candidates.append(pos)

	return candidates


## Pick a random ore type using weighted selection
static func _pick_weighted_ore(ores: Array, rng: SeededRandom) -> Dictionary:
	var total_weight: float = 0.0
	for ore in ores:
		total_weight += ore.weight

	if total_weight <= 0:
		return ores[0] if ores.size() > 0 else {}

	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0

	for ore in ores:
		cumulative += ore.weight
		if roll <= cumulative:
			return ore

	return ores[0]  # Fallback


## Generate a vein shape starting from anchor position
## Creates a serpentine path through wall tiles
static func _generate_vein_shape(map: GameMap, anchor: Vector2i, rng: SeededRandom, used_positions: Dictionary) -> Array:
	var vein_tiles: Array = [anchor]

	# Determine vein length (4-12 tiles)
	var target_length: int = rng.randi_range(4, 12)

	# Current position and direction
	var current_pos: Vector2i = anchor
	var current_dir: Vector2i = DIRECTIONS[rng.randi() % DIRECTIONS.size()]

	var attempts: int = 0
	var max_attempts: int = target_length * 5

	while vein_tiles.size() < target_length and attempts < max_attempts:
		attempts += 1

		# Occasionally change direction (30% chance) for serpentine effect
		if rng.randf() < 0.3:
			current_dir = DIRECTIONS[rng.randi() % DIRECTIONS.size()]

		# Try to expand in current direction
		var next_pos: Vector2i = current_pos + current_dir

		# Validate next position
		if not _is_valid_vein_position(map, next_pos, vein_tiles, used_positions):
			# Try a different direction
			current_dir = DIRECTIONS[rng.randi() % DIRECTIONS.size()]
			continue

		vein_tiles.append(next_pos)
		current_pos = next_pos

	return vein_tiles


## Check if a position is valid for vein expansion
static func _is_valid_vein_position(map: GameMap, pos: Vector2i, current_vein: Array, used_positions: Dictionary) -> bool:
	# Must be in map
	if not map.tiles.has(pos):
		return false

	# Must not already be in this vein
	if pos in current_vein:
		return false

	# Must not be in another vein
	if pos in used_positions:
		return false

	var tile = map.tiles[pos]

	# Must be a wall tile (non-walkable, non-transparent)
	if tile.walkable or tile.transparent:
		return false

	# Must not be a special tile
	if tile.tile_type in ["stairs_up", "stairs_down", "door"]:
		return false

	return true


## Place ore tiles on the map
static func _place_vein_tiles(map: GameMap, positions: Array, ore_type: Dictionary) -> void:
	var ore_id: String = ore_type.id
	var ore_color: String = ore_type.get("color", "#FFFFFF")

	for pos in positions:
		var ore_tile = GameTile.create(ore_id)
		ore_tile.color = Color.from_string(ore_color, Color.WHITE)
		map.tiles[pos] = ore_tile


## Fisher-Yates shuffle with seeded RNG
static func _seeded_shuffle(arr: Array, rng: SeededRandom) -> Array:
	var result = arr.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result
