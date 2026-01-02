class_name SpecialFeaturePlacer

## SpecialFeaturePlacer - Places special features (town, dungeon entrances, player spawn) in suitable biomes
##
## Uses biome data to find appropriate locations for special features.
## Features are placed deterministically based on world seed.
## Order: Town first, then dungeons (one of each type), then player spawn opposite first dungeon.

## Place all dungeon entrances based on dungeon definitions
## Returns array of dictionaries with dungeon_type, position, entrance_char, entrance_color
static func place_all_dungeon_entrances(world_seed: int, town_pos: Vector2i) -> Array:
	var entrances: Array = []
	var placed_positions: Array = []
	var rng = SeededRandom.new(world_seed + 2000)  # Offset for dungeon placement

	# Get all dungeon types from DungeonManager
	var dungeon_types = DungeonManager.get_all_dungeon_types()

	for dungeon_type in dungeon_types:
		var dungeon_def = DungeonManager.get_dungeon(dungeon_type)
		var placement = dungeon_def.get("placement", "wilderness")
		var biome_prefs = dungeon_def.get("biome_preferences", ["any"])

		var entrance_pos: Vector2i

		if placement == "town":
			# Place in/near town (sewers, etc.)
			entrance_pos = _place_town_dungeon(world_seed, town_pos, placed_positions, rng)
		else:
			# Place in wilderness with appropriate biome
			entrance_pos = _place_wilderness_dungeon(world_seed, town_pos, placed_positions, biome_prefs, rng)

		if entrance_pos != Vector2i(-1, -1):
			placed_positions.append(entrance_pos)
			entrances.append({
				"dungeon_type": dungeon_type,
				"position": entrance_pos,
				"entrance_char": dungeon_def.get("entrance_char", ">"),
				"entrance_color": dungeon_def.get("entrance_color", "#FFFFFF"),
				"name": dungeon_def.get("name", dungeon_type)
			})
			print("[SpecialFeaturePlacer] Placed %s at %v" % [dungeon_type, entrance_pos])
		else:
			push_warning("[SpecialFeaturePlacer] Could not place %s" % dungeon_type)

	return entrances


## Place a dungeon entrance in/near town
static func _place_town_dungeon(_world_seed: int, town_pos: Vector2i, existing: Array, rng: SeededRandom) -> Vector2i:
	# Place within the town area but not in a building
	# Town is 15x15, shop is 5x5 centered on town_pos
	var town_radius = 7

	for _attempt in range(50):
		var offset = Vector2i(rng.randi_range(-town_radius, town_radius), rng.randi_range(-town_radius, town_radius))
		var candidate_pos = town_pos + offset

		# Skip if too close to shop center (5x5 building)
		var dist_to_center = (candidate_pos - town_pos).length()
		if dist_to_center < 4:  # Shop is centered, avoid it
			continue

		# Skip if too close to existing entrances
		var too_close = false
		for pos in existing:
			if (candidate_pos - pos).length() < 5:
				too_close = true
				break
		if too_close:
			continue

		# Valid position
		return candidate_pos

	# Fallback: place at fixed offset from town
	return town_pos + Vector2i(6, 6)


## Place a dungeon entrance in wilderness with biome preference
static func _place_wilderness_dungeon(world_seed: int, town_pos: Vector2i, existing: Array, biome_prefs: Array, rng: SeededRandom) -> Vector2i:
	var min_distance_from_town = 20
	var max_distance_from_town = 60
	var min_distance_from_others = 15
	var excluded_biomes = ["ocean", "deep_ocean", "water"]

	# Try to find a suitable position
	for _attempt in range(100):
		var angle = rng.randf() * 2 * PI
		var distance = rng.randf_range(min_distance_from_town, max_distance_from_town)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var candidate_pos = town_pos + Vector2i(int(offset.x), int(offset.y))

		# Check biome
		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		# Check biome preference (skip if not "any" and not matching)
		if not ("any" in biome_prefs) and not (biome.biome_name in biome_prefs):
			continue

		# Check distance from other entrances
		var too_close = false
		for pos in existing:
			if (candidate_pos - pos).length() < min_distance_from_others:
				too_close = true
				break
		if too_close:
			continue

		return candidate_pos

	# Second pass: accept any non-water biome
	for _attempt in range(100):
		var angle = rng.randf() * 2 * PI
		var distance = rng.randf_range(min_distance_from_town, max_distance_from_town)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var candidate_pos = town_pos + Vector2i(int(offset.x), int(offset.y))

		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		var too_close = false
		for pos in existing:
			if (candidate_pos - pos).length() < min_distance_from_others:
				too_close = true
				break
		if too_close:
			continue

		return candidate_pos

	# Fallback position
	return Vector2i(-1, -1)


## Find suitable location for town
## Prefers grassland or woodland near the coast (beach biome nearby)
static func place_town(world_seed: int) -> Vector2i:
	var suitable_biomes = ["grassland", "woodland", "forest"]
	var coastal_biomes = ["beach", "marsh"]  # Biomes that indicate nearby coast
	var excluded_biomes = ["ocean", "deep_ocean", "water"]  # Never spawn in water

	# Get island center from config (in chunks)
	var island_settings = BiomeManager.get_island_settings()
	var island_width_chunks = island_settings.get("width_chunks", 25)
	var island_height_chunks = island_settings.get("height_chunks", 25)
	var center_chunk = Vector2i(island_width_chunks / 2, island_height_chunks / 2)

	# First pass: find suitable biomes near coast (within 2 chunks of beach)
	var coastal_candidates: Array = []
	for radius in range(1, 12):  # Search wider area
		var positions = _get_spiral_positions(center_chunk, radius)

		for chunk_coords in positions:
			var world_pos = chunk_coords * 32 + Vector2i(16, 16)
			var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

			if biome.biome_name in excluded_biomes:
				continue

			if biome.biome_name in suitable_biomes:
				# Check if near coast (any nearby tile is beach/marsh)
				var is_coastal = false
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						if dx == 0 and dy == 0:
							continue
						var neighbor_pos = world_pos + Vector2i(dx * 32, dy * 32)
						var neighbor_biome = BiomeGenerator.get_biome_at(neighbor_pos.x, neighbor_pos.y, world_seed)
						if neighbor_biome.biome_name in coastal_biomes:
							is_coastal = true
							break
					if is_coastal:
						break

				if is_coastal:
					coastal_candidates.append({"pos": world_pos, "chunk": chunk_coords, "biome": biome.biome_name})

	# Pick the first coastal candidate (deterministic based on spiral search order)
	if coastal_candidates.size() > 0:
		var selected = coastal_candidates[0]
		print("[SpecialFeaturePlacer] Town placed in coastal %s biome at chunk %v" % [selected.biome, selected.chunk])
		return selected.pos

	# Second pass: fall back to any suitable biome if no coastal location found
	for radius in range(1, 12):
		var positions = _get_spiral_positions(center_chunk, radius)

		for chunk_coords in positions:
			var world_pos = chunk_coords * 32 + Vector2i(16, 16)
			var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

			if biome.biome_name in excluded_biomes:
				continue

			if biome.biome_name in suitable_biomes:
				print("[SpecialFeaturePlacer] Town placed in %s biome at chunk %v (no coastal location found)" % [biome.biome_name, chunk_coords])
				return world_pos

	# Fallback to island center if no suitable biome found
	push_warning("SpecialFeaturePlacer: Could not find suitable biome for town, using island center")
	return center_chunk * 32 + Vector2i(16, 16)

## Find suitable location for dungeon entrance (legacy single entrance)
## Places 10-20 tiles from town, not in town area, prefers rocky biomes
static func place_dungeon_entrance(world_seed: int, town_pos: Vector2i) -> Vector2i:
	var rng = SeededRandom.new(world_seed + 1000)  # Offset for dungeon placement

	var suitable_biomes = ["rocky_hills", "barren_rock", "mountains"]
	var excluded_biomes = ["ocean", "deep_ocean", "water"]  # Never spawn in water
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

		# Check biome - never place in water
		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		# Prefer suitable biomes but accept any non-water biome
		if biome.biome_name in suitable_biomes:
			print("[SpecialFeaturePlacer] Dungeon entrance placed in %s biome at %v (%d tiles from town)" % [biome.biome_name, candidate_pos, int(dist_to_town)])
			return candidate_pos

	# Second pass: accept any non-water biome if preferred biomes not found
	for _attempt in range(100):
		var angle = rng.randf() * 2 * PI
		var distance = rng.randf_range(min_distance, max_distance)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var candidate_pos = town_pos + Vector2i(int(offset.x), int(offset.y))

		var dist_to_town = (candidate_pos - town_pos).length()
		if dist_to_town <= town_radius:
			continue

		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if not biome.biome_name in excluded_biomes:
			print("[SpecialFeaturePlacer] Dungeon entrance placed in %s biome at %v (%d tiles from town)" % [biome.biome_name, candidate_pos, int(dist_to_town)])
			return candidate_pos

	# Fallback: place at fixed distance even if biome isn't ideal
	var fallback_pos = town_pos + Vector2i(15, 0)  # 15 tiles east of town
	push_warning("SpecialFeaturePlacer: Could not find suitable biome for dungeon entrance, using fallback")
	print("[SpecialFeaturePlacer] Dungeon entrance placed at fallback position %v" % fallback_pos)
	return fallback_pos

## Place player spawn just outside town, opposite side from dungeon
static func place_player_spawn(town_pos: Vector2i, entrance_pos: Vector2i, world_seed: int) -> Vector2i:
	var excluded_biomes = ["ocean", "deep_ocean", "water"]  # Never spawn in water
	var spawn_distance = 10

	# Calculate direction from town to dungeon
	var to_dungeon = Vector2(entrance_pos - town_pos).normalized()

	# Place spawn opposite direction from dungeon
	var spawn_offset = -to_dungeon * spawn_distance
	var spawn_pos = town_pos + Vector2i(int(spawn_offset.x), int(spawn_offset.y))

	# Check if spawn position is in water
	var biome = BiomeGenerator.get_biome_at(spawn_pos.x, spawn_pos.y, world_seed)
	if biome.biome_name in excluded_biomes:
		# Try perpendicular directions if opposite from dungeon is in water
		var perpendicular = Vector2(-to_dungeon.y, to_dungeon.x)  # Rotate 90 degrees
		for angle_offset in [0, PI/4, -PI/4, PI/2, -PI/2, 3*PI/4, -3*PI/4]:
			var rotated = perpendicular.rotated(angle_offset)
			var test_pos = town_pos + Vector2i(int(rotated.x * spawn_distance), int(rotated.y * spawn_distance))
			var test_biome = BiomeGenerator.get_biome_at(test_pos.x, test_pos.y, world_seed)
			if not test_biome.biome_name in excluded_biomes:
				spawn_pos = test_pos
				print("[SpecialFeaturePlacer] Player spawn adjusted to avoid water: %v" % spawn_pos)
				break

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
