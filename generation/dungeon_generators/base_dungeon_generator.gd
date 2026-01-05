class_name BaseDungeonGenerator
extends RefCounted
## Base interface for all dungeon generators
##
## Each generator type implements generate_floor() differently to create
## unique dungeon layouts (rectangular rooms, cellular automata, BSP, etc.)
##
## All generators must extend this class and implement the generate_floor method.


## Generate a single dungeon floor
## @param dungeon_def: Dictionary from DungeonManager (JSON data)
## @param floor_number: Current floor depth (1-based)
## @param world_seed: Global world seed for deterministic generation
## @returns: Generated GameMap instance
func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
	push_error("BaseDungeonGenerator.generate_floor() must be overridden by subclass")
	return null


## Helper: Create deterministic floor seed from world seed + dungeon ID + floor number
## Ensures same seed always produces same floor layout
func _create_floor_seed(world_seed: int, dungeon_id: String, floor_number: int) -> int:
	var combined = "%s_%s_%d" % [world_seed, dungeon_id, floor_number]
	return combined.hash()


## Helper: Get generation parameter from dungeon definition with fallback
## Safely retrieves parameters from JSON with default values
func _get_param(dungeon_def: Dictionary, key: String, default):
	return dungeon_def.get("generation_params", {}).get(key, default)


## Helper: Shuffle an array using seeded RNG for deterministic results
## Fisher-Yates shuffle algorithm with seeded random
func _seeded_shuffle(arr: Array, rng: SeededRandom) -> Array:
	var result = arr.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result


## Helper: Place features and hazards after basic generation is complete
## Should be called by child generators at end of generate_floor()
## @param map: The generated map to populate
## @param dungeon_def: Dungeon definition with room_features and hazards arrays
## @param rng: SeededRandom instance for deterministic placement
func _place_features_and_hazards(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
	# Generators (RefCounted) can't access autoloads directly
	# Store placement data in map metadata for processing by DungeonManager
	_store_feature_data(map, dungeon_def, rng)
	_store_hazard_data(map, dungeon_def, rng)


## Fallback: Store feature placement data in map metadata
## Used when FeatureManager autoload is not available during generation
func _store_feature_data(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
	var room_features: Array = dungeon_def.get("room_features", [])
	if room_features.is_empty():
		return

	# Store raw feature config for later processing
	if not map.metadata.has("pending_features"):
		map.metadata["pending_features"] = []

	# Get floor positions (excluding stairs)
	var floor_positions: Array = []
	for pos in map.tiles:
		var tile = map.tiles[pos]
		if tile != null and tile.walkable and tile.tile_type not in ["stairs_up", "stairs_down"]:
			floor_positions.append(pos)

	# Sort positions for deterministic order, then shuffle with seeded RNG
	floor_positions.sort_custom(func(a, b): return a.x * 10000 + a.y < b.x * 10000 + b.y)
	var shuffled_positions = _seeded_shuffle(floor_positions, rng)

	for feature_config in room_features:
		var feature_id: String = feature_config.get("feature_id", "")
		var spawn_chance: float = feature_config.get("spawn_chance", 0.1)

		if feature_id.is_empty():
			continue

		# Calculate how many of this feature to place based on spawn chance
		var feature_count: int = int(spawn_chance * 5)  # e.g., 0.3 spawn_chance = ~1-2 features
		feature_count = maxi(1, feature_count)  # At least 1 if configured
		var placed: int = 0

		for pos in shuffled_positions:
			if placed >= feature_count:
				break
			if rng.randf() < spawn_chance:
				map.metadata.pending_features.append({
					"feature_id": feature_id,
					"position": pos,
					"config": feature_config
				})
				placed += 1


## Fallback: Store hazard placement data in map metadata
## Used when HazardManager autoload is not available during generation
func _store_hazard_data(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
	var hazards: Array = dungeon_def.get("hazards", [])
	if hazards.is_empty():
		return

	# Store raw hazard config for later processing
	if not map.metadata.has("pending_hazards"):
		map.metadata["pending_hazards"] = []

	# Get floor positions (excluding stairs)
	var floor_positions: Array = []
	for pos in map.tiles:
		var tile = map.tiles[pos]
		if tile != null and tile.walkable and tile.tile_type not in ["stairs_up", "stairs_down"]:
			floor_positions.append(pos)

	# Sort positions for deterministic order, then shuffle with seeded RNG
	floor_positions.sort_custom(func(a, b): return a.x * 10000 + a.y < b.x * 10000 + b.y)
	var shuffled_positions = _seeded_shuffle(floor_positions, rng)

	for hazard_config in hazards:
		var hazard_id: String = hazard_config.get("hazard_id", "")
		var density: float = hazard_config.get("density", 0.05)

		if hazard_id.is_empty():
			continue

		# Calculate hazard count based on density
		# For low densities, use random chance to spawn any at all
		var hazard_count: int = int(floor_positions.size() * density)
		if hazard_count == 0 and rng.randf() < (floor_positions.size() * density):
			hazard_count = 1  # Small chance to spawn 1 if density is very low
		hazard_count = mini(hazard_count, 5)  # Cap at 5 per hazard type

		var placed: int = 0
		for pos in shuffled_positions:
			if placed >= hazard_count:
				break
			if rng.randf() < 0.5:  # 50% chance to try this position
				map.metadata.pending_hazards.append({
					"hazard_id": hazard_id,
					"position": pos,
					"config": hazard_config
				})
				placed += 1


## Spawn enemies using data-driven spawn_dungeons and CR-based floor filtering
## Enemies are selected based on:
## 1. spawn_dungeons array matching current dungeon type
## 2. min_spawn_level/max_spawn_level matching current floor
## 3. spawn_density_dungeon for weighted selection
## Call from child generators: _spawn_enemies_data_driven(map, dungeon_def, floor_number, floor_positions, rng)
func _spawn_enemies_data_driven(map: GameMap, dungeon_def: Dictionary, floor_number: int, floor_positions: Array, rng: SeededRandom) -> int:
	var dungeon_type: String = dungeon_def.get("id", "unknown")

	# Get enemies valid for this dungeon type AND floor level
	var weighted_enemies = EntityManager.get_weighted_enemies_for_dungeon_floor(dungeon_type, floor_number)

	if weighted_enemies.is_empty():
		return 0  # No data-driven enemies found

	# Calculate spawn count based on difficulty curve
	var difficulty: Dictionary = dungeon_def.get("difficulty_curve", {})
	var base_count: int = difficulty.get("enemy_count_base", 5)
	var per_floor: float = difficulty.get("enemy_count_per_floor", 1.0)
	var spawn_count: int = int(base_count + floor_number * per_floor)

	# Limit spawns to available floor positions
	spawn_count = min(spawn_count, floor_positions.size() / 3)

	# Initialize enemy_spawns if not present
	if not map.metadata.has("enemy_spawns"):
		map.metadata["enemy_spawns"] = []

	# Shuffle positions for random placement
	var shuffled_positions = _seeded_shuffle(floor_positions, rng)

	var spawned: int = 0
	var position_index: int = 0

	while spawned < spawn_count and position_index < shuffled_positions.size():
		var spawn_pos = shuffled_positions[position_index]
		position_index += 1

		# Pick weighted random enemy from data-driven list
		var chosen_enemy_id = _pick_weighted_enemy(weighted_enemies, rng)
		if chosen_enemy_id.is_empty():
			continue

		# Calculate enemy level with floor scaling
		var level_multiplier: float = difficulty.get("enemy_level_multiplier", 1.0)
		var enemy_level: int = max(1, int(floor_number * level_multiplier))

		# Store spawn data in metadata
		map.metadata.enemy_spawns.append({
			"enemy_id": chosen_enemy_id,
			"position": spawn_pos,
			"level": enemy_level
		})

		spawned += 1

	return spawned


## Pick a random enemy from weighted list (helper for data-driven spawning)
func _pick_weighted_enemy(weighted_enemies: Array, rng: SeededRandom) -> String:
	var total_weight: float = 0.0
	for enemy_data in weighted_enemies:
		total_weight += enemy_data.get("weight", 1.0)

	if total_weight <= 0:
		return ""

	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0

	for enemy_data in weighted_enemies:
		cumulative += enemy_data.get("weight", 1.0)
		if roll <= cumulative:
			return enemy_data.get("enemy_id", "")

	return ""


## Get valid spawn positions from map (floor tiles, not stairs)
func _get_spawn_positions(map: GameMap) -> Array:
	var floor_positions: Array = []
	for pos in map.tiles:
		var tile = map.tiles[pos]
		if tile != null and tile.walkable and tile.tile_type not in ["stairs_up", "stairs_down"]:
			floor_positions.append(pos)
	return floor_positions
