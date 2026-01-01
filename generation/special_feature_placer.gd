class_name SpecialFeaturePlacer

## SpecialFeaturePlacer - Places special features (town, dungeon entrance, player spawn) in suitable biomes
##
## Uses biome data to find appropriate locations for special features.
## Features are placed deterministically based on world seed.
## Order: Town first, then dungeon 10-20 tiles away, then player spawn opposite dungeon.

## Find suitable location for town
## Prefers grassland or woodland near spawn area
static func place_town(world_seed: int) -> Vector2i:
	var search_radius = 8
	var suitable_biomes = ["grassland", "woodland", "forest"]

	# Try to find a suitable biome within search radius of spawn area
	for radius in range(1, search_radius):
		var positions = _get_spiral_positions(Vector2i(5, 5), radius)

		for chunk_coords in positions:
			# Check center of chunk for biome
			var world_pos = chunk_coords * 32 + Vector2i(16, 16)
			var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

			if biome.biome_name in suitable_biomes:
				# Found suitable location
				print("[SpecialFeaturePlacer] Town placed in %s biome at chunk %v" % [biome.biome_name, chunk_coords])
				return world_pos

	# Fallback to a fixed position if no suitable biome found
	push_warning("SpecialFeaturePlacer: Could not find suitable biome for town, using fallback")
	return Vector2i(4 * 32 + 16, 5 * 32 + 16)

## Find suitable location for dungeon entrance
## Places 10-20 tiles from town, not in town area, prefers rocky biomes
static func place_dungeon_entrance(world_seed: int, town_pos: Vector2i) -> Vector2i:
	var rng = SeededRandom.new(world_seed + 1000)  # Offset for dungeon placement

	var suitable_biomes = ["rocky_hills", "barren_rock", "mountains"]
	var min_distance = 10
	var max_distance = 20
	var town_radius = 10  # Town is 20x20 (radius 10)

	# Try random positions in a ring around the town
	for _attempt in range(100):
		# Random angle
		var angle = rng.randf() * 2 * PI
		# Random distance between min and max
		var distance = rng.randf_range(min_distance, max_distance)

		# Calculate position
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var candidate_pos = town_pos + Vector2i(int(offset.x), int(offset.y))

		# Ensure not in town
		var dist_to_town = (candidate_pos - town_pos).length()
		if dist_to_town <= town_radius:
			continue

		# Check biome preference (optional - accept any biome if attempts exhausted)
		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in suitable_biomes:
			print("[SpecialFeaturePlacer] Dungeon entrance placed in %s biome at %v (%d tiles from town)" % [biome.biome_name, candidate_pos, int(dist_to_town)])
			return candidate_pos

	# Fallback: place at fixed distance even if biome isn't ideal
	var fallback_pos = town_pos + Vector2i(15, 0)  # 15 tiles east of town
	push_warning("SpecialFeaturePlacer: Could not find suitable biome for dungeon entrance, using fallback")
	print("[SpecialFeaturePlacer] Dungeon entrance placed at fallback position %v" % fallback_pos)
	return fallback_pos

## Place player spawn just outside town, opposite side from dungeon
static func place_player_spawn(town_pos: Vector2i, entrance_pos: Vector2i) -> Vector2i:
	# Town is 15x15, so radius is ~7.5. Spawn just outside at 10 tiles
	var spawn_distance = 10

	# Calculate direction from town to dungeon
	var to_dungeon = Vector2(entrance_pos - town_pos).normalized()

	# Place spawn opposite direction from dungeon
	var spawn_offset = -to_dungeon * spawn_distance
	var spawn_pos = town_pos + Vector2i(int(spawn_offset.x), int(spawn_offset.y))

	var actual_dist = (spawn_pos - town_pos).length()
	print("[SpecialFeaturePlacer] Player spawn at %v (%.1f tiles from town %v, opposite dungeon %v)" % [spawn_pos, actual_dist, town_pos, entrance_pos])
	return spawn_pos

## Get positions in a spiral pattern at given radius from center
static func _get_spiral_positions(center: Vector2i, radius: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	# Generate positions in a square ring at this radius
	for x in range(-radius, radius + 1):
		# Top and bottom edges
		positions.append(center + Vector2i(x, -radius))
		positions.append(center + Vector2i(x, radius))

	for y in range(-radius + 1, radius):
		# Left and right edges (excluding corners already added)
		positions.append(center + Vector2i(-radius, y))
		positions.append(center + Vector2i(radius, y))

	return positions
