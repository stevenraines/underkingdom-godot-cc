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

	print("[SpecialFeaturePlacer] Town definitions to place: %s" % [town_types])

	# Sort towns so starter_town is placed first (it determines player spawn)
	# sort_custom expects: negative if a < b, 0 if equal, positive if a > b
	# We want starter_town first, so it should be "less than" others
	town_types.sort_custom(func(a, b):
		if a == "starter_town" and b != "starter_town":
			return true  # a comes first
		if b == "starter_town" and a != "starter_town":
			return false  # b comes first
		return a < b  # alphabetical for others
	)

	print("[SpecialFeaturePlacer] Sorted town order: %s" % [town_types])

	for town_id in town_types:
		var town_def = town_definitions.get(town_id, {})
		var biome_prefs = town_def.get("biome_preferences", ["grassland", "woodland"])
		var placement = town_def.get("placement", "any")

		print("[SpecialFeaturePlacer] Processing town: %s (biome_prefs=%s, placement=%s)" % [town_id, biome_prefs, placement])

		var town_pos: Vector2i

		if town_id == "starter_town" or towns.is_empty():
			# First town uses original placement logic (coastal preferred)
			print("[SpecialFeaturePlacer] Using primary town placement for %s" % town_id)
			town_pos = _place_primary_town(world_seed, biome_prefs, placement)
		else:
			# Additional towns placed with spacing from existing towns
			print("[SpecialFeaturePlacer] Using additional town placement for %s (existing positions: %s)" % [town_id, placed_positions])
			town_pos = _place_additional_town(world_seed, placed_positions, biome_prefs, placement, rng)

		print("[SpecialFeaturePlacer] Town %s placement result: %v" % [town_id, town_pos])

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
			print("[SpecialFeaturePlacer] SUCCESS: Placed town %s (%s) at %v" % [town_id, town_def.get("name", town_id), town_pos])
		else:
			push_warning("[SpecialFeaturePlacer] FAILED: Could not place town %s" % town_id)

	print("[SpecialFeaturePlacer] Total towns placed: %d" % towns.size())
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
	# For coastal towns, we want to be ON land biomes but NEAR water
	# Split biome prefs: coastal biomes (beach, marsh) indicate "near water" requirement
	# Land biomes (grassland, woodland) are where we actually place the town
	var coastal_indicator_biomes = ["beach", "marsh"]
	var land_biomes: Array = []
	var wants_coastal = placement == "coastal"

	for biome in biome_prefs:
		if biome in coastal_indicator_biomes:
			wants_coastal = true  # Having beach/marsh in prefs implies coastal
		else:
			land_biomes.append(biome)

	# If no land biomes specified, default to common ones
	if land_biomes.is_empty():
		land_biomes = ["grassland", "woodland"]

	var excluded_biomes = ["ocean", "deep_ocean", "water"]
	var min_distance_from_towns = 30  # Minimum tiles between town centers
	var max_distance_from_towns = 120  # Maximum tiles from nearest town

	print("[SpecialFeaturePlacer] Placing additional town: land_biomes=%s, wants_coastal=%s" % [land_biomes, wants_coastal])

	# Get island bounds
	var island_settings = BiomeManager.get_island_settings()
	var island_width_chunks = island_settings.get("width_chunks", 25)
	var island_height_chunks = island_settings.get("height_chunks", 25)

	var best_candidate = Vector2i(-1, -1)
	var best_score = -1

	# Try random positions
	for _attempt in range(300):
		# Random chunk within island
		var chunk_x = rng.randi_range(2, island_width_chunks - 3)
		var chunk_y = rng.randi_range(2, island_height_chunks - 3)
		var candidate_pos = Vector2i(chunk_x * 32 + 16, chunk_y * 32 + 16)

		# Check biome - must be on a land biome (not water)
		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		# Check if on a suitable land biome
		var on_suitable_land = biome.biome_name in land_biomes
		if not on_suitable_land:
			# After many attempts, accept any non-water biome
			if _attempt < 200:
				continue

		# Check distance from existing towns
		var too_close = false
		var min_dist_to_town = 9999.0
		for pos in existing_positions:
			var dist = (candidate_pos - pos).length()
			if dist < min_distance_from_towns:
				too_close = true
				break
			if dist < min_dist_to_town:
				min_dist_to_town = dist

		if too_close:
			continue

		# Score this candidate
		var score = 0

		# Prefer suitable land biomes
		if on_suitable_land:
			score += 100

		# Check coastal requirement
		var is_coastal = false
		if wants_coastal:
			is_coastal = _is_near_coast(candidate_pos, world_seed)
			if is_coastal:
				score += 50

		# Prefer reasonable distance from other towns
		if min_dist_to_town >= min_distance_from_towns and min_dist_to_town <= max_distance_from_towns:
			score += 25

		# Track best candidate
		if score > best_score:
			best_score = score
			best_candidate = candidate_pos
			print("[SpecialFeaturePlacer] New best candidate at %v (score=%d, biome=%s, coastal=%s)" % [candidate_pos, score, biome.biome_name, is_coastal])

		# If we found an ideal candidate (suitable land + coastal), return immediately
		if score >= 150:
			print("[SpecialFeaturePlacer] Found ideal position at %v (score=%d, biome=%s)" % [candidate_pos, score, biome.biome_name])
			return candidate_pos

	# Return best candidate found, or -1,-1 if none
	if best_candidate != Vector2i(-1, -1):
		print("[SpecialFeaturePlacer] Using best candidate at %v (score=%d)" % [best_candidate, best_score])
	else:
		push_warning("[SpecialFeaturePlacer] Failed to place additional town after 300 attempts! land_biomes=%s, wants_coastal=%s" % [land_biomes, wants_coastal])
	return best_candidate


## Check if a position is near coastal biomes (beach, marsh, or ocean)
static func _is_near_coast(pos: Vector2i, world_seed: int) -> bool:
	var coastal_biomes = ["beach", "marsh", "ocean", "deep_ocean"]
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
			# Place within the town itself (sewers, etc.)
			entrance_pos = _place_town_dungeon(world_seed, primary_town_pos, placed_positions, rng)
		elif placement == "near_town":
			# Place near but outside town (barrows, etc.) - within 20-60 tiles
			entrance_pos = _place_near_town_dungeon(world_seed, primary_town_pos, placed_positions, biome_prefs, rng)
		else:
			# Place in wilderness across the island
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


## Place a dungeon entrance near but outside town (20-60 tiles away)
static func _place_near_town_dungeon(world_seed: int, town_pos: Vector2i, existing: Array, biome_prefs: Array, rng: SeededRandom) -> Vector2i:
	var min_distance = 20  # Outside town bounds
	var max_distance = 60  # But not too far
	var min_distance_from_others = 15
	var excluded_biomes = ["ocean", "deep_ocean", "water"]

	for _attempt in range(100):
		var angle = rng.randf() * 2 * PI
		var distance = rng.randf_range(min_distance, max_distance)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var candidate_pos = town_pos + Vector2i(int(offset.x), int(offset.y))

		# Check biome
		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		# Check biome preference
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

	# Fallback: accept any non-water biome near town
	for _attempt in range(50):
		var angle = rng.randf() * 2 * PI
		var distance = rng.randf_range(min_distance, max_distance)
		var offset = Vector2(cos(angle), sin(angle)) * distance
		var candidate_pos = town_pos + Vector2i(int(offset.x), int(offset.y))

		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		return candidate_pos

	# Ultimate fallback
	return town_pos + Vector2i(30, 30)


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
## Distributes dungeons across the entire island, not just near town
static func _place_wilderness_dungeon(world_seed: int, town_pos: Vector2i, existing: Array, biome_prefs: Array, rng: SeededRandom) -> Vector2i:
	var min_distance_from_town = 25  # Not too close to starter town
	var min_distance_from_others = 40  # Spread dungeons apart
	var excluded_biomes = ["ocean", "deep_ocean", "water"]

	# Get island bounds for full-island placement
	var island_settings = BiomeManager.get_island_settings()
	var island_width_chunks = island_settings.get("width_chunks", 25)
	var island_height_chunks = island_settings.get("height_chunks", 25)

	# Try to find a suitable position anywhere on the island
	for _attempt in range(200):
		# Random position anywhere on the island (avoiding edge chunks)
		var chunk_x = rng.randi_range(3, island_width_chunks - 4)
		var chunk_y = rng.randi_range(3, island_height_chunks - 4)
		var candidate_pos = Vector2i(chunk_x * 32 + rng.randi_range(8, 24), chunk_y * 32 + rng.randi_range(8, 24))

		# Check biome
		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		# Check biome preference (skip if not "any" and not matching)
		if not ("any" in biome_prefs) and not (biome.biome_name in biome_prefs):
			continue

		# Check distance from town
		var dist_to_town = (candidate_pos - town_pos).length()
		if dist_to_town < min_distance_from_town:
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

	# Second pass: accept any non-water biome, relax distance constraints
	for _attempt in range(200):
		var chunk_x = rng.randi_range(3, island_width_chunks - 4)
		var chunk_y = rng.randi_range(3, island_height_chunks - 4)
		var candidate_pos = Vector2i(chunk_x * 32 + rng.randi_range(8, 24), chunk_y * 32 + rng.randi_range(8, 24))

		var biome = BiomeGenerator.get_biome_at(candidate_pos.x, candidate_pos.y, world_seed)
		if biome.biome_name in excluded_biomes:
			continue

		# Relaxed distance check - just avoid being on top of others
		var too_close = false
		for pos in existing:
			if (candidate_pos - pos).length() < 20:  # Reduced minimum
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
