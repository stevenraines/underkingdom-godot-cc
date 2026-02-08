extends Node
class_name FeatureManagerClass
## Manages dungeon and overworld features - interactive objects placed during generation
##
## Features are loaded from JSON files in data/features/ (recursively)
## Each feature can contain loot, summon enemies, provide hints, or have
## other interactive effects. Supports variant system for harvested items.

const FEATURE_DATA_PATH = "res://data/features"
const _LockSystem = preload("res://systems/lock_system.gd")
const ChunkManagerClass = preload("res://autoload/chunk_manager.gd")
const ChunkCleanupHelper = preload("res://autoload/chunk_cleanup_helper.gd")

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

## Track features scheduled for respawn
## Key: respawn_turn, Value: Array of {feature_id, position, biome_id, map_id}
var respawning_features: Dictionary = {}


func _ready() -> void:
	_load_feature_definitions()
	#print("[FeatureManager] Initialized with %d feature definitions" % feature_definitions.size())

	# Connect to chunk unload signal to clean up features from unloaded chunks
	EventBus.chunk_unloaded.connect(_on_chunk_unloaded)


## Load all feature definitions recursively from JSON files
func _load_feature_definitions() -> void:
	var files = JsonHelper.load_all_from_directory(FEATURE_DATA_PATH)
	for file_entry in files:
		_process_feature_data(file_entry.path, file_entry.data)


## Process loaded feature data
func _process_feature_data(file_path: String, data) -> void:
	if not data is Dictionary:
		push_error("[FeatureManager] Invalid feature data in: " + file_path)
		return

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
	#print("[FeatureManager] Loaded %d hints for current dungeon" % hints.size())


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

	# Generate loot if applicable (check contains_loot flag OR loot_table presence)
	var should_have_loot = config.get("contains_loot", false) or config.has("loot_table")
	if feature_def.get("can_contain_loot", false) and should_have_loot:
		feature_data.state["loot"] = _generate_feature_loot(config, rng)

	# Set enemy to summon if applicable
	if feature_def.get("can_summon_enemy", false) and config.has("summons_enemy"):
		feature_data.state["summons_enemy"] = config.get("summons_enemy")

	# Initialize water source uses if applicable
	var max_uses: int = feature_def.get("max_uses", 0)
	if feature_def.get("water_source", false) and max_uses > 0:
		feature_data.state["uses_remaining"] = max_uses

	# Store in active features
	active_features[pos] = feature_data

	# Store in map metadata for persistence
	if not map.metadata.has("features"):
		map.metadata["features"] = []
	map.metadata.features.append(feature_data)


## Generate loot for a feature using LootTableManager
func _generate_feature_loot(config: Dictionary, rng: SeededRandom) -> Array:
	var loot_table: String = config.get("loot_table", "")

	# Use LootTableManager if a loot table is specified
	if loot_table != "":
		var generated = LootTableManager.generate_loot(loot_table, rng)
		if not generated.is_empty():
			return generated

	# Fallback: default loot if no loot table or generation failed
	return [{"item_id": "gold_coin", "count": rng.randi_range(5, 25)}]


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

	# Handle harvestable yields (like mushrooms, crystals, ore) with variant support
	if feature_def.get("harvestable", false) and feature_def.has("yields"):
		var yields: Array = feature_def.get("yields", [])
		var harvested_items: Array = []
		# Get biome for variant selection (stored in feature state or look up from position)
		var biome_id: String = feature.state.get("biome_id", "")
		if biome_id.is_empty():
			biome_id = _get_biome_at_position(pos)

		for yield_data in yields:
			var item_id: String = yield_data.get("item_id", "")
			var count_min: int = yield_data.get("count_min", 1)
			var count_max: int = yield_data.get("count_max", 1)
			var count: int = randi_range(count_min, count_max)
			if not item_id.is_empty() and count > 0:
				var harvest_data: Dictionary = {"item_id": item_id, "count": count}

				# Check for variant support
				var use_variant: bool = yield_data.get("use_variant", false)
				var variant_type: String = yield_data.get("variant_type", "")
				if use_variant and not variant_type.is_empty():
					var variant_name = _select_variant_for_biome(variant_type, biome_id)
					if not variant_name.is_empty():
						harvest_data["variant_name"] = variant_name

				harvested_items.append(harvest_data)

		if not harvested_items.is_empty():
			result.effects.append({"type": "harvest", "items": harvested_items})
			var item_names: Array = []
			for hi in harvested_items:
				# Build display name
				var display_name = hi.item_id.replace("_", " ")
				if hi.has("variant_name"):
					display_name = hi.variant_name.replace("_", " ")
				item_names.append("%d %s" % [hi.count, display_name])
			result.message = "You %s the %s and gather %s." % [verb, feature_name, ", ".join(item_names)]

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

	# Handle water source
	if feature_def.get("water_source", false):
		var max_uses: int = feature_def.get("max_uses", 0)

		# Check if depletable source is empty
		if max_uses > 0 and feature.state.get("uses_remaining", 0) <= 0:
			return {"success": false, "message": "The %s is empty." % feature_name}

		# Check remaining uses for running_low warning
		var is_running_low: bool = (max_uses > 0 and feature.state.get("uses_remaining", max_uses) == 1)

		# Add water source effect for player processing
		# Uses are decremented by consume_water_source() after player confirms use
		result.effects.append({
			"type": "water_source",
			"thirst_restored": feature_def.get("thirst_restored", 50),
			"fill_item_from": feature_def.get("fill_item_from", ""),
			"fill_item_to": feature_def.get("fill_item_to", ""),
			"feature_name": feature_name,
			"position": pos,
			"running_low": is_running_low
		})
		result.message = ""  # Player will set the message based on action taken

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
	var feature_def: Dictionary = feature.get("definition", {})
	var biome_id: String = feature.state.get("biome_id", "")

	# Remove from active features
	active_features.erase(pos)

	# Remove from map metadata
	var map = MapManager.current_map

	# Schedule respawn for renewable features
	if feature_def.get("renewable", false):
		var map_id = map.map_id if map else "overworld"
		schedule_feature_respawn(feature_id, pos, biome_id, map_id)
	if map and map.metadata.has("features"):
		var features: Array = map.metadata.features
		for i in range(features.size() - 1, -1, -1):
			var f: Dictionary = features[i]
			var f_pos = f.get("position", Vector2i.ZERO)
			# Handle both Vector2i (in memory) and String (from save data)
			if f_pos is String:
				f_pos = JsonHelper.parse_vector2i(f_pos)
			if f_pos == pos:
				features.remove_at(i)
				break

	#print("[FeatureManager] Removed feature '%s' at %v" % [feature_id, pos])


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
			pos = JsonHelper.parse_vector2i(pos)
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


## Consume one use of a water source at position (called after player confirms use)
func consume_water_source(pos: Vector2i) -> void:
	if not active_features.has(pos):
		return
	var feature: Dictionary = active_features[pos]
	var feature_def: Dictionary = feature.definition
	var max_uses: int = feature_def.get("max_uses", 0)
	if max_uses > 0:
		feature.state["uses_remaining"] = feature.state.get("uses_remaining", max_uses) - 1
		if feature.state.uses_remaining <= 0:
			feature.state["depleted"] = true


## Check if position has a blocking feature
func has_blocking_feature(pos: Vector2i) -> bool:
	if not active_features.has(pos):
		return false
	var feature: Dictionary = active_features[pos]
	var is_blocking = feature.definition.get("blocking", false)
	if is_blocking:
		#print("[FeatureManager] Blocking feature found at %v: %s" % [pos, feature.feature_id])
		pass
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
			pos = JsonHelper.parse_vector2i(pos)
		elif not pos is Vector2i:
			pos = Vector2i.ZERO

		# ALWAYS use fresh definition from feature_definitions
		# (serialized definitions may have corrupted Color objects from JSON)
		var feature_id: String = feature_data.get("feature_id", "")
		if feature_definitions.has(feature_id):
			feature_data["definition"] = feature_definitions[feature_id]
		else:
			push_warning("[FeatureManager] Unknown feature type: %s" % feature_id)
			continue

		active_features[pos] = feature_data

	#print("[FeatureManager] Loaded %d features from map" % active_features.size())


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
			pos = JsonHelper.parse_vector2i(pos)
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
			#print("[FeatureManager] Generated loot for %s at %v: %s" % [feature_id, pos, feature_data.state.loot])

		# Set enemy to summon if applicable
		if feature_def.get("can_summon_enemy", false) and config.has("summons_enemy"):
			feature_data.state["summons_enemy"] = config.get("summons_enemy")

		# Initialize water source uses if applicable
		var pending_max_uses: int = feature_def.get("max_uses", 0)
		if feature_def.get("water_source", false) and pending_max_uses > 0:
			feature_data.state["uses_remaining"] = pending_max_uses

		# Store in active features and map metadata
		active_features[pos] = feature_data
		map.metadata.features.append(feature_data)

	# Clear pending after processing
	map.metadata.pending_features.clear()
	#print("[FeatureManager] Processed %d pending features" % pending.size())


# =============================================================================
# VARIANT SUPPORT
# =============================================================================

## Get biome ID at a world position
func _get_biome_at_position(pos: Vector2i) -> String:
	var world_seed = GameManager.world_seed if GameManager.world_seed else 12345
	var biome = BiomeGenerator.get_biome_at(pos.x, pos.y, world_seed)
	if biome:
		return biome.get("id", "woodland")
	return "woodland"


## Select an appropriate variant for the given biome
## Prefers variants that match the biome, falls back to any variant
func _select_variant_for_biome(variant_type: String, biome_id: String) -> String:
	var variants: Dictionary = VariantManager.get_variants_of_type(variant_type)
	if variants.is_empty():
		return ""

	# Collect variants that match this biome
	var biome_variants: Array[String] = []
	var all_variants: Array[String] = []

	for variant_name in variants:
		all_variants.append(variant_name)
		var variant_data: Dictionary = variants[variant_name]
		var biomes: Array = variant_data.get("biomes", [])
		if biomes.is_empty() or biome_id in biomes:
			biome_variants.append(variant_name)

	# Prefer biome-appropriate variants, fall back to all variants
	var candidate_list = biome_variants if not biome_variants.is_empty() else all_variants
	if candidate_list.is_empty():
		return ""

	# Random selection
	return candidate_list[randi() % candidate_list.size()]


# =============================================================================
# OVERWORLD FEATURE SPAWNING
# =============================================================================

## Spawn an overworld feature at position
## Called by ResourceSpawner/WorldChunk when generating flora
func spawn_overworld_feature(feature_id: String, pos: Vector2i, biome_id: String = "", map: GameMap = null) -> void:
	if not feature_definitions.has(feature_id):
		push_warning("[FeatureManager] Unknown feature type for overworld spawn: %s" % feature_id)
		return

	var feature_def: Dictionary = feature_definitions[feature_id]

	# Use current map if not specified
	if map == null:
		map = MapManager.current_map
	if map == null:
		push_warning("[FeatureManager] No map available for overworld feature spawn")
		return

	# Create feature instance data
	var feature_data: Dictionary = {
		"feature_id": feature_id,
		"position": pos,
		"definition": feature_def,
		"config": {},
		"interacted": false,
		"state": {
			"biome_id": biome_id  # Store biome for variant selection
		}
	}

	# Initialize water source uses if applicable
	var ow_max_uses: int = feature_def.get("max_uses", 0)
	if feature_def.get("water_source", false) and ow_max_uses > 0:
		feature_data.state["uses_remaining"] = ow_max_uses

	# Store in active features
	active_features[pos] = feature_data

	# Store in map metadata for persistence
	if not map.metadata.has("features"):
		map.metadata["features"] = []
	map.metadata.features.append(feature_data)


## Get the ascii char for a feature type (used for rendering)
func get_feature_ascii_char(feature_id: String) -> String:
	var feature_def = feature_definitions.get(feature_id, {})
	return feature_def.get("ascii_char", "?")


## Get the color for a feature type (used for rendering)
func get_feature_color(feature_id: String) -> Color:
	var feature_def = feature_definitions.get(feature_id, {})
	return feature_def.get("color", Color.WHITE)


# =============================================================================
# RESPAWN SYSTEM
# =============================================================================

## Schedule a feature for respawn after interaction
func schedule_feature_respawn(feature_id: String, pos: Vector2i, biome_id: String, map_id: String) -> void:
	var feature_def = feature_definitions.get(feature_id, {})
	if not feature_def.get("renewable", false):
		return

	var respawn_turns: int = feature_def.get("respawn_turns", 3000)
	var respawn_turn: int = TurnManager.current_turn + respawn_turns

	if not respawning_features.has(respawn_turn):
		respawning_features[respawn_turn] = []

	respawning_features[respawn_turn].append({
		"feature_id": feature_id,
		"position": pos,
		"biome_id": biome_id,
		"map_id": map_id
	})

	#print("[FeatureManager] Scheduled respawn for %s at %v in %d turns" % [feature_id, pos, respawn_turns])


## Process respawns (called by TurnManager each turn)
## OPTIMIZATION: Only processes respawns within reasonable distance of player
func process_feature_respawns() -> void:
	var current_turn = TurnManager.current_turn
	var current_map_id = MapManager.current_map.map_id if MapManager.current_map else ""

	# Get player position for spatial filtering
	var player_pos = EntityManager.player.position if EntityManager.player else Vector2i.ZERO
	const RESPAWN_PROCESS_RANGE = 100  # Only process respawns within 100 tiles of player

	# DIAGNOSTIC: Log feature count and active chunks
	var active_chunk_coords = ChunkManager.get_active_chunk_coords()
	#print("[FeatureManager] Processing respawns (turn %d, active features: %d, active chunks: %d)" % [current_turn, active_features.size(), active_chunk_coords.size()])

	# Find any features ready to respawn
	var turns_to_remove: Array = []
	var respawns_processed = 0
	var respawns_skipped_distance = 0

	for respawn_turn in respawning_features:
		if current_turn >= respawn_turn:
			for respawn_data in respawning_features[respawn_turn]:
				# Only respawn if we're on the same map
				if respawn_data.map_id == current_map_id:
					var pos = respawn_data.position
					# Handle position as string or Vector2i
					if pos is String:
						pos = JsonHelper.parse_vector2i(pos)

					# Spatial filter: Only process if near player (Manhattan distance)
					var dist = abs(pos.x - player_pos.x) + abs(pos.y - player_pos.y)
					if dist > RESPAWN_PROCESS_RANGE:
						respawns_skipped_distance += 1
						continue  # Skip distant respawns, they'll be processed when player gets closer

					# Check if position is clear (no entity or feature there)
					if not active_features.has(pos):
						spawn_overworld_feature(
							respawn_data.feature_id,
							pos,
							respawn_data.biome_id,
							MapManager.current_map
						)
						respawns_processed += 1

			turns_to_remove.append(respawn_turn)

	# Clean up processed respawns
	for turn_key in turns_to_remove:
		respawning_features.erase(turn_key)

	if respawns_processed > 0 or respawns_skipped_distance > 0:
		#print("[FeatureManager] Respawn complete: %d spawned, %d skipped (too far)" % [respawns_processed, respawns_skipped_distance])
		pass

	# Periodic cleanup: Remove features outside loaded chunks (every 20 turns)
	if current_turn % 20 == 0 and MapManager.current_map and MapManager.current_map.chunk_based:
		#print("[FeatureManager] Running periodic cleanup (turn %d)" % current_turn)
		_cleanup_distant_features()

## Clean up features that are outside currently loaded chunks (called periodically)
## OPTIMIZATION: Only runs every 20 turns to avoid per-turn overhead
func _cleanup_distant_features() -> void:
	const CHUNK_SIZE = 32  # Must match WorldChunk.CHUNK_SIZE
	var positions_to_remove: Array[Vector2i] = []

	# Get active chunk coordinates from ChunkManager
	var active_chunk_coords = ChunkManager.get_active_chunk_coords()

	# Build a set of active chunk coords for O(1) lookup
	var active_chunks_set: Dictionary = {}
	for chunk_coord in active_chunk_coords:
		active_chunks_set[chunk_coord] = true

	# Check each feature
	for pos in active_features:
		# Calculate chunk coord inline to avoid static function warning
		var chunk_coord = Vector2i(
			floori(float(pos.x) / CHUNK_SIZE),
			floori(float(pos.y) / CHUNK_SIZE)
		)

		# If feature's chunk is not active, mark for removal
		if not active_chunks_set.has(chunk_coord):
			positions_to_remove.append(pos)

	# Remove features outside loaded chunks
	for pos in positions_to_remove:
		active_features.erase(pos)

	if positions_to_remove.size() > 0:
		#print("[FeatureManager] Cleaned up %d features outside loaded chunks" % positions_to_remove.size())
		pass

## Called when a chunk is unloaded - removes features that were spawned in that chunk
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
	ChunkCleanupHelper.cleanup_positions_in_chunk(active_features, chunk_coords, "FeatureManager")
