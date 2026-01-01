class_name SpecialFeaturePlacer

## SpecialFeaturePlacer - Places special features (dungeon entrance, town) in suitable biomes
##
## Uses biome data to find appropriate locations for special features.
## Features are placed deterministically based on world seed.

## Find suitable location for dungeon entrance
## Prefers rocky hills, mountains, or barren rock biomes
static func place_dungeon_entrance(world_seed: int) -> Vector2i:
	var rng = SeededRandom.new(world_seed + 1000)  # Offset for dungeon placement

	# Search outward from spawn area (chunk 5,5) in a spiral pattern
	var search_radius = 10  # Search up to 10 chunks away
	var suitable_biomes = ["rocky_hills", "barren_rock", "mountains"]

	# Try to find a suitable biome within search radius
	for radius in range(2, search_radius):  # Start at radius 2 to avoid spawn chunk
		var positions = _get_spiral_positions(Vector2i(5, 5), radius)

		for chunk_coords in positions:
			# Check center of chunk for biome
			var world_pos = chunk_coords * 32 + Vector2i(16, 16)
			var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

			if biome.biome_name in suitable_biomes:
				# Found suitable location
				print("[SpecialFeaturePlacer] Dungeon entrance placed in %s biome at chunk %v" % [biome.biome_name, chunk_coords])
				return world_pos

	# Fallback to a fixed position if no suitable biome found
	push_warning("SpecialFeaturePlacer: Could not find suitable biome for dungeon entrance, using fallback")
	return Vector2i(5 * 32 + 16, 5 * 32 + 16)

## Find suitable location for town
## Prefers grassland or woodland near spawn, not too close to dungeon
static func place_town(world_seed: int, entrance_pos: Vector2i) -> Vector2i:
	var rng = SeededRandom.new(world_seed + 2000)  # Different offset for town placement

	var search_radius = 8
	var suitable_biomes = ["grassland", "woodland", "forest"]
	var entrance_chunk = ChunkManager.world_to_chunk(entrance_pos)

	# Try to find a suitable biome within search radius
	for radius in range(1, search_radius):
		var positions = _get_spiral_positions(Vector2i(5, 5), radius)

		for chunk_coords in positions:
			# Don't place too close to dungeon entrance
			var distance_to_entrance = (chunk_coords - entrance_chunk).length()
			if distance_to_entrance < 3:
				continue

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
