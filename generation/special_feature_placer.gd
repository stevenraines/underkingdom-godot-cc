class_name SpecialFeaturePlacer

## SpecialFeaturePlacer - Places special features (towns, dungeon entrances, player spawn) in suitable biomes
##
## Uses biome data to find appropriate locations for special features.
## Features are placed deterministically based on world seed.
## Order: Towns first, then dungeons, then player spawn.

## Place all towns based on town definitions
## town_definitions: Dictionary of town_id -> town definition (from TownManager)
## Returns array of dictionaries with town_id, position, biome_preferences
static func place_all_towns(world_seed: int, town_definitions: Dictionary) -> Array:
	var towns: Array = []
	var placed_positions: Array = []
	var rng = SeededRandom.new(world_seed + 3000)  # Offset for town placement

	# Get all town types from definitions
	var town_types = town_definitions.keys()

	# Sort towns so starter_town is placed first (it determines player spawn)
	town_types.sort_custom(func(a, _b): return a == "starter_town")

	for town_id in town_types:
		var town_def = town_definitions.get(town_id, {})
		var biome_prefs = town_def.get("biome_preferences", ["grassland", "woodland"])
		var placement = town_def.get("placement", "any")

		var town_pos: Vector2i

		if town_id == "starter_town" or towns.is_empty():
			# First town uses original placement logic (coastal preferred)
			town_pos = _place_primary_town(world_seed, biome_prefs, placement)
		else:
			# Additional towns placed with spacing from existing towns
			town_pos = _place_additional_town(world_seed, placed_positions, biome_prefs, placement, rng)

		if town_pos != Vector2i(-1, -1):
			placed_positions.append(town_pos)

			# Get town size for bounds checking
			var size_array = town_def.get("size", [15, 15])
			var town_size = Vector2i(size_array[0], size_array[1])

			towns.append({
				"town_id": town_id,
				"position": town_pos,
				"size": town_size,
				"name": town_def.get("name", town_id),
				"is_safe_zone": town_def.get("is_safe_zone", true)
			})
			print("[SpecialFeaturePlacer] Placed town %s at %v" % [town_id, town_pos])
		else:
			push_warning("[SpecialFeaturePlacer] Could not place town %s" % town_id)

	return towns


## Place the primary/starter town (uses original coastal logic)
static func _place_primary_town(world_seed: int, biome_prefs: Array, placement: String) -> Vector2i:
	var suitable_biomes = biome_prefs if not biome_prefs.is_empty() else ["grassland", "woodland", "forest"]
	var coastal_biomes = ["beach", "marsh"]  # Biomes that indicate nearby coast
	var excluded_biomes = ["ocean", "deep_ocean", "water"]  # Never spawn in water

	# Get island center from config (in chunks)
	var island_settings = BiomeManager.get_island_settings()
	var island_width_chunks = island_settings.get("width_chunks", 25)
	var island_height_chunks = island_settings.get("height_chunks", 25)
	var center_chunk = Vector2i(island_width_chunks / 2, island_height_chunks / 2)

	# If coastal placement preferred, look for coast first
	if placement == "coastal":
		var coastal_candidates: Array = []
		for radius in range(1, 12):
			var positions = _get_spiral_positions(center_chunk, radius)

			for chunk_coords in positions:
				var world_pos = chunk_coords * 32 + Vector2i(16, 16)
				var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

				if biome.biome_name in excluded_biomes:
					continue

				if biome.biome_name in suitable_biomes:
					# Check if near coast
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

		if coastal_candidates.size() > 0:
			var selected = coastal_candidates[0]
			print("[SpecialFeaturePlacer] Primary town placed in coastal %s biome at chunk %v" % [selected.biome, selected.chunk])
			return selected.pos

	# Fallback: any suitable biome
	for radius in range(1, 12):
		var positions = _get_spiral_positions(center_chunk, radius)

		for chunk_coords in positions:
			var world_pos = chunk_coords * 32 + Vector2i(16, 16)
			var biome = BiomeGenerator.get_biome_at(world_pos.x, world_pos.y, world_seed)

			if biome.biome_name in excluded_biomes:
				continue

			if biome.biome_name in suitable_biomes:
				print("[SpecialFeaturePlacer] Primary town placed in %s biome at chunk %v" % [biome.biome_name, chunk_coords])
				return world_pos

	# Ultimate fallback
	push_warning("SpecialFeaturePlacer: Could not find suitable biome for primary town")
	return center_chunk * 32 + Vector2i(16, 16)


## Place an additional town with spacing from existing towns
static func _place_additional_town(world_seed: int, existing_positions: Array, biome_prefs: Array, placement: String, rng: SeededRandom) -> Vector2i:
	var suitable_biomes = biome_prefs if not biome_prefs.is_empty() else ["grassland", "woodland"]
	var excluded_biomes = ["ocean", "deep_ocean", "water"]
	var min_distance_from_towns = 40  # Minimum tiles between town centers
	var max_distance_from_towns = 80  # Maximum tiles from nearest town

	# Get island bounds
	var island_settings = BiomeManager.get_island_settings()
	var island_width_chunks = island_settings.get("width_chunks", 25)
	var island_height_chunks = island_settings.get("height_chunks", 25)

	# Try random positions
	for _attempt in range(200):
		# Random chunk within island
		var chunk_x = rng.randi_range(2, island_width_chunks - 3)
		var chunk_y = rng.randi_range(2, island_height_chunks - 3)
		var candidate_pos = Vector2i(chunk_x * 32 + 16, chunk_y * 32 + 16)

		# Check biome
		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		# Check biome preference
		if not suitable_biomes.is_empty() and not (biome.biome_name in suitable_biomes):
			continue

		# Check distance from existing towns
		var too_close = false
		var too_far = true
		for pos in existing_positions:
			var dist = (candidate_pos - pos).length()
			if dist < min_distance_from_towns:
				too_close = true
				break
			if dist <= max_distance_from_towns:
				too_far = false

		if too_close:
			continue

		# If all towns are too far, accept anyway if this is the best we found
		# (This handles cases where the island is large)
		if too_far and existing_positions.size() > 0:
			# Relax distance requirement after many attempts
			if _attempt < 100:
				continue

		# Check coastal requirement if specified
		if placement == "coastal":
			var is_coastal = _is_near_coast(candidate_pos, world_seed)
			if not is_coastal and _attempt < 150:  # Relax after many attempts
				continue

		return candidate_pos

	return Vector2i(-1, -1)


## Check if a position is near coastal biomes
static func _is_near_coast(pos: Vector2i, world_seed: int) -> bool:
	var coastal_biomes = ["beach", "marsh"]
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if dx == 0 and dy == 0:
				continue
			var neighbor_pos = pos + Vector2i(dx * 32, dy * 32)
			var biome = BiomeGenerator.get_biome_at(neighbor_pos.x, neighbor_pos.y, world_seed)
			if biome.biome_name in coastal_biomes:
				return true
	return false


## Place all dungeon entrances based on dungeon definitions
## Returns array of dictionaries with dungeon_type, position, entrance_char, entrance_color
static func place_all_dungeon_entrances(world_seed: int, primary_town_pos: Vector2i) -> Array:
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
			# Place in/near primary town (sewers, etc.)
			entrance_pos = _place_town_dungeon(world_seed, primary_town_pos, placed_positions, rng)
		else:
			# Place in wilderness with appropriate biome
			entrance_pos = _place_wilderness_dungeon(world_seed, primary_town_pos, placed_positions, biome_prefs, rng)

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


## Find suitable location for town (legacy - now use place_all_towns)
## Prefers grassland or woodland near the coast (beach biome nearby)
## Note: This legacy function uses default town definition for backwards compatibility
static func place_town(world_seed: int) -> Vector2i:
	# Use default starter town definition for legacy compatibility
	var default_town_defs = {
		"starter_town": {
			"id": "starter_town",
			"name": "Thornhaven",
			"size": [15, 15],
			"biome_preferences": ["grassland", "woodland"],
			"placement": "coastal",
			"is_safe_zone": true
		}
	}
	var towns = place_all_towns(world_seed, default_town_defs)
	if towns.size() > 0:
		return towns[0].position
	return Vector2i(400, 400)  # Fallback


## Find suitable location for dungeon entrance (legacy single entrance)
static func place_dungeon_entrance(world_seed: int, town_pos: Vector2i) -> Vector2i:
	var rng = SeededRandom.new(world_seed + 1000)
	return _place_wilderness_dungeon(world_seed, town_pos, [], ["any"], rng)


## Place player spawn just outside primary town, opposite side from first dungeon
static func place_player_spawn(town_pos: Vector2i, entrance_pos: Vector2i, world_seed: int) -> Vector2i:
	var excluded_biomes = ["ocean", "deep_ocean", "water"]
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
		var perpendicular = Vector2(-to_dungeon.y, to_dungeon.x)
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
