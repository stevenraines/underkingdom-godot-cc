extends Node
class_name FeatureManagerClass
## Manages dungeon features - interactive objects placed during generation
##
## Features are loaded from JSON files in data/features/
## Each feature can contain loot, summon enemies, provide hints, or have
## other interactive effects.

const FEATURE_DATA_PATH = "res://data/features"
const _LockSystem = preload("res://systems/lock_system.gd")

## Signal emitted when a feature is interacted with
signal feature_interacted(feature_id: String, position: Vector2i, result: Dictionary)

## Signal emitted when a feature spawns an enemy
signal feature_spawned_enemy(enemy_id: String, position: Vector2i)

## Dictionary of active features on current map
## Key: Vector2i position, Value: feature data dictionary
var active_features: Dictionary = {}

## Feature type definitions loaded from JSON
var feature_definitions: Dictionary = {}

## Current dungeon's hints (loaded from dungeon definition)
var current_dungeon_hints: Array = []


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


## Set hints for the current dungeon (called when entering a dungeon)
func set_dungeon_hints(hints: Array) -> void:
	current_dungeon_hints = hints
	print("[FeatureManager] Loaded %d hints for current dungeon" % hints.size())


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
		# Ancient treasure always has gold
		loot.append({"item_id": "gold_coin", "count": rng.randi_range(15, 60)})
		# Chance for additional rare items
		if rng.randf() < 0.3:
			loot.append({"item_id": "ancient_artifact", "count": 1})
	else:
		# Default loot - always give something
		loot.append({"item_id": "gold_coin", "count": rng.randi_range(5, 25)})

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
## If player is provided, can attempt auto-unlock with keys
func interact_with_feature(pos: Vector2i, player = null) -> Dictionary:
	if not active_features.has(pos):
		return {"success": false, "message": "Nothing to interact with here."}

	var feature: Dictionary = active_features[pos]
	var feature_def: Dictionary = feature.definition
	var result: Dictionary = {"success": true, "effects": []}

	# Check if locked
	if feature.state.get("is_locked", false):
		if player:
			# Try to auto-unlock with key
			var unlock_result = _try_unlock_feature(feature, player)
			if not unlock_result.success:
				return {"success": false, "message": "It's locked. Press Y to pick the lock.", "is_locked": true}
			# If unlocked with key, continue to interaction
			result.message = unlock_result.message
		else:
			return {"success": false, "message": "It's locked.", "is_locked": true}

	if feature.interacted and not feature_def.get("repeatable", false):
		return {"success": false, "message": "Already interacted with this %s." % feature_def.name}

	# Mark as interacted
	feature.interacted = true

	# Get interaction verb for default messages
	var verb: String = feature_def.get("interaction_verb", "examine")
	var feature_name: String = feature_def.get("name", "feature").to_lower()

	# Default message - can be overwritten by specific effects
	result.message = "You %s the %s." % [verb, feature_name]

	# Handle harvestable yields (like mushrooms, crystals, ore)
	if feature_def.get("harvestable", false) and feature_def.has("yields"):
		var yields: Array = feature_def.get("yields", [])
		var harvested_items: Array = []
		for yield_data in yields:
			var item_id: String = yield_data.get("item_id", "")
			var count_min: int = yield_data.get("count_min", 1)
			var count_max: int = yield_data.get("count_max", 1)
			var count: int = randi_range(count_min, count_max)
			if not item_id.is_empty() and count > 0:
				harvested_items.append({"item_id": item_id, "count": count})
		if not harvested_items.is_empty():
			result.effects.append({"type": "harvest", "items": harvested_items})
			var total_items: int = 0
			for hi in harvested_items:
				total_items += hi.count
			result.message = "You %s the %s and gather %d item(s)." % [verb, feature_name, total_items]

	# Handle loot
	if feature.state.has("loot") and not feature.state.loot.is_empty():
		result.effects.append({"type": "loot", "items": feature.state.loot})
		result.message = "You %s the %s and find treasure!" % [verb, feature_name]
		feature.state.loot = []
	elif feature_def.get("can_contain_loot", false):
		# Has loot capability but was empty
		result.message = "You %s the %s but find nothing." % [verb, feature_name]

	# Handle enemy summon
	if feature.state.has("summons_enemy"):
		var enemy_id: String = feature.state.summons_enemy
		result.effects.append({"type": "summon_enemy", "enemy_id": enemy_id, "position": pos})
		result.message = "Something emerges from the %s!" % feature_name
		feature_spawned_enemy.emit(enemy_id, pos)

	# Handle hints
	if feature_def.get("provides_hint", false):
		result.effects.append({"type": "hint", "text": _generate_hint()})
		result.message = "You read the inscription..."

	# Handle blessing
	if feature_def.get("can_grant_blessing", false):
		result.effects.append({"type": "blessing", "stat": "health", "amount": 10})
		result.message = "You feel blessed!"

	# Handle features that should be removed after interaction
	if feature_def.get("removes_on_interact", false):
		_remove_feature(pos)
		result.effects.append({"type": "removed"})

	feature_interacted.emit(feature.feature_id, pos, result)
	return result


## Remove a feature from active features and map metadata
func _remove_feature(pos: Vector2i) -> void:
	if not active_features.has(pos):
		return

	var feature: Dictionary = active_features[pos]
	var feature_id: String = feature.get("feature_id", "")

	# Remove from active features
	active_features.erase(pos)

	# Remove from map metadata
	var map = MapManager.current_map
	if map and map.metadata.has("features"):
		var features: Array = map.metadata.features
		for i in range(features.size() - 1, -1, -1):
			var f: Dictionary = features[i]
			var f_pos = f.get("position", Vector2i.ZERO)
			# Handle both Vector2i (in memory) and String (from save data)
			if f_pos is String:
				f_pos = _parse_vector2i(f_pos)
			if f_pos == pos:
				features.remove_at(i)
				break

	print("[FeatureManager] Removed feature '%s' at %v" % [feature_id, pos])


## Generate a random hint from the current dungeon's hints
func _generate_hint() -> String:
	# Use hints from the current dungeon definition
	if current_dungeon_hints.size() > 0:
		return current_dungeon_hints[randi() % current_dungeon_hints.size()]

	# Fallback hints if no dungeon hints available
	var fallback_hints: Array = [
		"Ancient words fade from the stone...",
		"The inscription is too worn to read.",
		"Something was written here long ago."
	]
	return fallback_hints[randi() % fallback_hints.size()]


## Try to unlock a feature using player's keys (auto-unlock on interaction)
## Returns Dictionary: {success, message}
func _try_unlock_feature(feature: Dictionary, player) -> Dictionary:
	var lock_id: String = feature.state.get("lock_id", "")
	var lock_level: int = feature.state.get("lock_level", 1)

	# Try to unlock with key
	var unlock_result = _LockSystem.try_unlock_with_key(lock_id, lock_level, player.inventory)

	if unlock_result.success:
		# Unlock the feature
		feature.state["is_locked"] = false
		var pos = feature.get("position", Vector2i.ZERO)
		# Handle both Vector2i (in memory) and String (from save data)
		if pos is String:
			pos = _parse_vector2i(pos)
		EventBus.lock_opened.emit(pos, "key")
		return {"success": true, "message": unlock_result.message}

	return {"success": false, "message": unlock_result.message}


## Check if a feature at position is locked
func is_feature_locked(pos: Vector2i) -> bool:
	if not active_features.has(pos):
		return false
	var feature: Dictionary = active_features[pos]
	return feature.state.get("is_locked", false)


## Try to pick a feature's lock
## Returns Dictionary: {success, message, lockpick_broken}
func try_pick_feature_lock(pos: Vector2i, player) -> Dictionary:
	if not active_features.has(pos):
		return {"success": false, "message": "Nothing to pick here."}

	var feature: Dictionary = active_features[pos]

	if not feature.state.get("is_locked", false):
		return {"success": false, "message": "It's not locked."}

	var lock_level: int = feature.state.get("lock_level", 1)
	var feature_def: Dictionary = feature.definition
	var feature_name: String = feature_def.get("name", "feature").to_lower()

	# Try to pick the lock
	var pick_result = _LockSystem.try_pick_lock(lock_level, player)

	if pick_result.success:
		# Unlock the feature
		feature.state["is_locked"] = false
		EventBus.lock_picked.emit(pos, true)
		EventBus.lock_opened.emit(pos, "picked")
		return {"success": true, "message": "You pick the %s's lock." % feature_name}
	else:
		EventBus.lock_picked.emit(pos, false)
		if pick_result.lockpick_broken:
			EventBus.lockpick_broken.emit(pos)
		return {"success": false, "message": pick_result.message, "lockpick_broken": pick_result.lockpick_broken}


## Try to re-lock a feature (requires lockpick, half difficulty)
## Returns Dictionary: {success, message, lockpick_broken}
func try_lock_feature(pos: Vector2i, player) -> Dictionary:
	if not active_features.has(pos):
		return {"success": false, "message": "Nothing to lock here."}

	var feature: Dictionary = active_features[pos]

	if feature.state.get("is_locked", false):
		return {"success": false, "message": "It's already locked."}

	# Feature must have had a lock originally (lock_level > 0)
	var lock_level: int = feature.state.get("lock_level", 0)
	if lock_level <= 0:
		return {"success": false, "message": "This can't be locked."}

	var feature_def: Dictionary = feature.definition
	var feature_name: String = feature_def.get("name", "feature").to_lower()

	# Try to lock it (half difficulty)
	var lock_result = _LockSystem.try_lock_with_pick(lock_level, player)

	if lock_result.success:
		feature.state["is_locked"] = true
		return {"success": true, "message": "You re-lock the %s." % feature_name}
	else:
		if lock_result.lockpick_broken:
			EventBus.lockpick_broken.emit(pos)
		return {"success": false, "message": lock_result.message, "lockpick_broken": lock_result.lockpick_broken}


## Get feature at position (or null)
func get_feature_at(pos: Vector2i) -> Dictionary:
	return active_features.get(pos, {})


## Check if position has interactable feature
func has_interactable_feature(pos: Vector2i) -> bool:
	if not active_features.has(pos):
		return false
	var feature: Dictionary = active_features[pos]
	return feature.definition.get("interactable", false)


## Check if position has a blocking feature
func has_blocking_feature(pos: Vector2i) -> bool:
	if not active_features.has(pos):
		return false
	var feature: Dictionary = active_features[pos]
	var is_blocking = feature.definition.get("blocking", false)
	if is_blocking:
		print("[FeatureManager] Blocking feature found at %v: %s" % [pos, feature.feature_id])
	return is_blocking


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
		var pos = feature_data.position
		# Handle both Vector2i (in memory) and String (from save data)
		if pos is String:
			pos = _parse_vector2i(pos)
		elif not pos is Vector2i:
			pos = Vector2i.ZERO

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
		var pos = pending_data.get("position", Vector2i.ZERO)
		# Handle both Vector2i (in memory) and String (from save data)
		if pos is String:
			pos = _parse_vector2i(pos)
		elif not pos is Vector2i:
			pos = Vector2i.ZERO
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

		# Generate loot if applicable (check contains_loot flag OR loot_table presence)
		var should_have_loot = config.get("contains_loot", false) or config.has("loot_table")
		if feature_def.get("can_contain_loot", false) and should_have_loot:
			feature_data.state["loot"] = _generate_feature_loot(config, rng)
			print("[FeatureManager] Generated loot for %s at %v: %s" % [feature_id, pos, feature_data.state.loot])

		# Set enemy to summon if applicable
		if feature_def.get("can_summon_enemy", false) and config.has("summons_enemy"):
			feature_data.state["summons_enemy"] = config.get("summons_enemy")

		# Store in active features and map metadata
		active_features[pos] = feature_data
		map.metadata.features.append(feature_data)

	# Clear pending after processing
	map.metadata.pending_features.clear()
	print("[FeatureManager] Processed %d pending features" % pending.size())


## Parse Vector2i from string representation (handles JSON deserialization)
## Godot's JSON saves Vector2i as string like "(x, y)"
func _parse_vector2i(value: String) -> Vector2i:
	# Remove parentheses and split by comma
	var cleaned = value.strip_edges().replace("(", "").replace(")", "")
	var parts = cleaned.split(",")
	if parts.size() != 2:
		push_warning("[FeatureManager] Failed to parse Vector2i from string: %s" % value)
		return Vector2i.ZERO
	return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
