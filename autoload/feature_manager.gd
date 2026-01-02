extends Node
class_name FeatureManagerClass
## Manages dungeon features - interactive objects placed during generation
##
## Features are loaded from JSON files in data/features/
## Each feature can contain loot, summon enemies, provide hints, or have
## other interactive effects.

const FEATURE_DATA_PATH = "res://data/features"

## Signal emitted when a feature is interacted with
signal feature_interacted(feature_id: String, position: Vector2i, result: Dictionary)

## Signal emitted when a feature spawns an enemy
signal feature_spawned_enemy(enemy_id: String, position: Vector2i)

## Dictionary of active features on current map
## Key: Vector2i position, Value: feature data dictionary
var active_features: Dictionary = {}

## Feature type definitions loaded from JSON
var feature_definitions: Dictionary = {}


func _ready() -> void:
	_load_feature_definitions()
	print("[FeatureManager] Initialized with %d feature definitions" % feature_definitions.size())


## Load all feature definitions from JSON files
func _load_feature_definitions() -> void:
	var dir = DirAccess.open(FEATURE_DATA_PATH)
	if not dir:
		push_error("[FeatureManager] Failed to open feature data directory: " + FEATURE_DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = FEATURE_DATA_PATH + "/" + file_name
			_load_feature_file(file_path)
		file_name = dir.get_next()

	dir.list_dir_end()


## Load a single feature definition from JSON
func _load_feature_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[FeatureManager] Failed to open feature file: " + file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("[FeatureManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	if not data.has("id"):
		push_error("[FeatureManager] Feature definition missing 'id' field: " + file_path)
		return

	# Convert color from hex string to Color
	if data.has("color") and data.color is String:
		data.color = Color.from_string(data.color, Color.WHITE)

	feature_definitions[data.id] = data


## Clear all active features (called on map transition)
func clear_features() -> void:
	active_features.clear()


## Place features in a generated map based on dungeon definition
## Called by generators after basic layout is created
func place_features(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
	var room_features: Array = dungeon_def.get("room_features", [])
	if room_features.is_empty():
		return

	# Find valid floor positions for feature placement
	var floor_positions: Array[Vector2i] = _get_floor_positions(map)
	if floor_positions.is_empty():
		return

	for feature_config in room_features:
		var feature_id: String = feature_config.get("feature_id", "")
		var spawn_chance: float = feature_config.get("spawn_chance", 0.1)

		if feature_id.is_empty():
			continue

		# Determine number of features to place
		var feature_count: int = 0
		for pos in floor_positions:
			if rng.randf() < spawn_chance * 0.1:  # Scaled down for per-tile check
				feature_count += 1

		# Cap features per type
		feature_count = mini(feature_count, 5)

		# Place features
		floor_positions.shuffle()
		var placed: int = 0
		for pos in floor_positions:
			if placed >= feature_count:
				break

			if _can_place_feature_at(map, pos):
				_place_feature(map, pos, feature_id, feature_config, rng)
				placed += 1


## Check if a feature can be placed at position
func _can_place_feature_at(map: GameMap, pos: Vector2i) -> bool:
	# Must be walkable floor
	var tile = map.get_tile(pos)
	if tile == null or not tile.walkable:
		return false

	# Can't be on stairs
	if tile.tile_type in ["stairs_up", "stairs_down"]:
		return false

	# Can't already have a feature
	if active_features.has(pos):
		return false

	return true


## Place a feature at position
func _place_feature(map: GameMap, pos: Vector2i, feature_id: String, config: Dictionary, rng: SeededRandom) -> void:
	var feature_def: Dictionary = feature_definitions.get(feature_id, {})
	if feature_def.is_empty():
		push_warning("Unknown feature type: %s" % feature_id)
		return

	# Create feature instance data
	var feature_data: Dictionary = {
		"feature_id": feature_id,
		"position": pos,
		"definition": feature_def,
		"config": config,
		"interacted": false,
		"state": {}
	}

	# Generate loot if applicable
	if feature_def.get("can_contain_loot", false) and config.get("contains_loot", false):
		feature_data.state["loot"] = _generate_feature_loot(config, rng)

	# Set enemy to summon if applicable
	if feature_def.get("can_summon_enemy", false) and config.has("summons_enemy"):
		feature_data.state["summons_enemy"] = config.get("summons_enemy")

	# Store in active features
	active_features[pos] = feature_data

	# Store in map metadata for persistence
	if not map.metadata.has("features"):
		map.metadata["features"] = []
	map.metadata.features.append(feature_data)


## Generate loot for a feature
func _generate_feature_loot(config: Dictionary, rng: SeededRandom) -> Array:
	var loot: Array = []
	var loot_table: String = config.get("loot_table", "")

	# Simple loot generation (can be expanded later)
	if loot_table == "ancient_treasure":
		if rng.randf() < 0.5:
			loot.append({"item_id": "gold_coins", "count": rng.randi_range(10, 50)})
		if rng.randf() < 0.2:
			loot.append({"item_id": "ancient_artifact", "count": 1})
	else:
		# Default loot
		if rng.randf() < 0.7:
			loot.append({"item_id": "gold_coins", "count": rng.randi_range(5, 20)})

	return loot


## Get all floor positions in map
func _get_floor_positions(map: GameMap) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	for pos in map.tiles:
		var tile = map.tiles[pos]
		if tile != null and tile.walkable:
			positions.append(pos)

	return positions


## Interact with a feature at position
## Returns result dictionary with effects
func interact_with_feature(pos: Vector2i) -> Dictionary:
	if not active_features.has(pos):
		return {"success": false, "message": "Nothing to interact with here."}

	var feature: Dictionary = active_features[pos]
	var feature_def: Dictionary = feature.definition
	var result: Dictionary = {"success": true, "effects": []}

	if feature.interacted and not feature_def.get("repeatable", false):
		return {"success": false, "message": "Already interacted with this %s." % feature_def.name}

	# Mark as interacted
	feature.interacted = true

	# Handle loot
	if feature.state.has("loot") and not feature.state.loot.is_empty():
		result.effects.append({"type": "loot", "items": feature.state.loot})
		result.message = "You found items in the %s!" % feature_def.name.to_lower()
		feature.state.loot = []

	# Handle enemy summon
	if feature.state.has("summons_enemy"):
		var enemy_id: String = feature.state.summons_enemy
		result.effects.append({"type": "summon_enemy", "enemy_id": enemy_id, "position": pos})
		result.message = "Something emerges from the %s!" % feature_def.name.to_lower()
		feature_spawned_enemy.emit(enemy_id, pos)

	# Handle hints
	if feature_def.get("provides_hint", false):
		result.effects.append({"type": "hint", "text": _generate_hint()})
		result.message = "You read the inscription..."

	# Handle blessing
	if feature_def.get("can_grant_blessing", false):
		result.effects.append({"type": "blessing", "stat": "health", "amount": 10})
		result.message = "You feel blessed!"

	feature_interacted.emit(feature.feature_id, pos, result)
	return result


## Generate a random hint
func _generate_hint() -> String:
	var hints: Array = [
		"Beware the darkness below...",
		"The treasure lies beyond the guardian.",
		"Only the worthy may pass.",
		"Death awaits the unprepared.",
		"Seek the light in the deepest dark."
	]
	return hints[randi() % hints.size()]


## Get feature at position (or null)
func get_feature_at(pos: Vector2i) -> Dictionary:
	return active_features.get(pos, {})


## Check if position has interactable feature
func has_interactable_feature(pos: Vector2i) -> bool:
	if not active_features.has(pos):
		return false
	var feature: Dictionary = active_features[pos]
	return feature.definition.get("interactable", false)


## Load features from map metadata (for saved games and floor transitions)
func load_features_from_map(map: GameMap) -> void:
	clear_features()

	# Process pending features from generator (stored during generation)
	if map.metadata.has("pending_features"):
		_process_pending_features(map)

	# Load already-placed features (from saves or previous processing)
	if not map.metadata.has("features"):
		return

	for feature_data in map.metadata.features:
		var pos: Vector2i = feature_data.position

		# Ensure feature has its definition reference
		if not feature_data.has("definition"):
			var feature_id: String = feature_data.get("feature_id", "")
			if feature_definitions.has(feature_id):
				feature_data["definition"] = feature_definitions[feature_id]
			else:
				push_warning("[FeatureManager] Unknown feature type: %s" % feature_id)
				continue

		active_features[pos] = feature_data

	print("[FeatureManager] Loaded %d features from map" % active_features.size())


## Process pending features stored by generator and convert to active features
func _process_pending_features(map: GameMap) -> void:
	var pending: Array = map.metadata.get("pending_features", [])
	if pending.is_empty():
		return

	# Initialize features array if needed
	if not map.metadata.has("features"):
		map.metadata["features"] = []

	# Create RNG for loot generation
	var map_seed: int = map.seed if map.seed else 12345
	var rng = SeededRandom.new(map_seed)

	for pending_data in pending:
		var feature_id: String = pending_data.get("feature_id", "")
		var pos: Vector2i = pending_data.get("position", Vector2i.ZERO)
		var config: Dictionary = pending_data.get("config", {})

		if feature_id.is_empty() or not feature_definitions.has(feature_id):
			continue

		var feature_def: Dictionary = feature_definitions[feature_id]

		# Create full feature data
		var feature_data: Dictionary = {
			"feature_id": feature_id,
			"position": pos,
			"definition": feature_def,
			"config": config,
			"interacted": false,
			"state": {}
		}

		# Generate loot if applicable
		if feature_def.get("can_contain_loot", false) and config.get("contains_loot", false):
			feature_data.state["loot"] = _generate_feature_loot(config, rng)

		# Set enemy to summon if applicable
		if feature_def.get("can_summon_enemy", false) and config.has("summons_enemy"):
			feature_data.state["summons_enemy"] = config.get("summons_enemy")

		# Store in active features and map metadata
		active_features[pos] = feature_data
		map.metadata.features.append(feature_data)

	# Clear pending after processing
	map.metadata.pending_features.clear()
	print("[FeatureManager] Processed %d pending features" % pending.size())
