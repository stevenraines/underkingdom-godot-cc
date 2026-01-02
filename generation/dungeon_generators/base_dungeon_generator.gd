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

	# Get floor positions
	var floor_positions: Array = []
	for pos in map.tiles:
		var tile = map.tiles[pos]
		if tile != null and tile.walkable and tile.tile_type not in ["stairs_up", "stairs_down"]:
			floor_positions.append(pos)

	for feature_config in room_features:
		var feature_id: String = feature_config.get("feature_id", "")
		var spawn_chance: float = feature_config.get("spawn_chance", 0.1)

		if feature_id.is_empty():
			continue

		# Randomly select positions based on spawn chance
		for pos in floor_positions:
			if rng.randf() < spawn_chance * 0.05:  # Very low chance per tile
				map.metadata.pending_features.append({
					"feature_id": feature_id,
					"position": pos,
					"config": feature_config
				})


## Fallback: Store hazard placement data in map metadata
## Used when HazardManager autoload is not available during generation
func _store_hazard_data(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
	var hazards: Array = dungeon_def.get("hazards", [])
	if hazards.is_empty():
		return

	# Store raw hazard config for later processing
	if not map.metadata.has("pending_hazards"):
		map.metadata["pending_hazards"] = []

	# Get floor positions
	var floor_positions: Array = []
	for pos in map.tiles:
		var tile = map.tiles[pos]
		if tile != null and tile.walkable and tile.tile_type not in ["stairs_up", "stairs_down"]:
			floor_positions.append(pos)

	for hazard_config in hazards:
		var hazard_id: String = hazard_config.get("hazard_id", "")
		var density: float = hazard_config.get("density", 0.05)

		if hazard_id.is_empty():
			continue

		# Calculate hazard count based on density
		var hazard_count: int = int(floor_positions.size() * density)
		hazard_count = clampi(hazard_count, 1, 10)

		var placed: int = 0
		for pos in floor_positions:
			if placed >= hazard_count:
				break
			if rng.randf() < 0.5:  # 50% chance to try this position
				map.metadata.pending_hazards.append({
					"hazard_id": hazard_id,
					"position": pos,
					"config": hazard_config
				})
				placed += 1
