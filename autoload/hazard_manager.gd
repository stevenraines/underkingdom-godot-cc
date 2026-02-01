extends Node
class_name HazardManagerClass
## Manages dungeon hazards - traps and environmental dangers
##
## Hazards are loaded from JSON files in data/hazards/
## Hazards trigger when entities enter their area or interact with triggers.

const HAZARD_DATA_PATH = "res://data/hazards"
const ChunkManagerClass = preload("res://autoload/chunk_manager.gd")

## Signal emitted when hazard is triggered
signal hazard_triggered(hazard_id: String, position: Vector2i, target, damage: int)

## Signal emitted when hazard is detected by player
signal hazard_detected(hazard_id: String, position: Vector2i)

## Signal emitted when hazard is disarmed
signal hazard_disarmed(hazard_id: String, position: Vector2i)

## Dictionary of active hazards on current map
## Key: Vector2i position, Value: hazard data dictionary
var active_hazards: Dictionary = {}

## Hazard type definitions loaded from JSON
var hazard_definitions: Dictionary = {}


func _ready() -> void:
	_load_hazard_definitions()
	print("[HazardManager] Initialized with %d hazard definitions" % hazard_definitions.size())

	# Connect to chunk unload signal to clean up hazards from unloaded chunks
	EventBus.chunk_unloaded.connect(_on_chunk_unloaded)


## Load all hazard definitions from JSON files
func _load_hazard_definitions() -> void:
	var dir = DirAccess.open(HAZARD_DATA_PATH)
	if not dir:
		push_error("[HazardManager] Failed to open hazard data directory: " + HAZARD_DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = HAZARD_DATA_PATH + "/" + file_name
			_load_hazard_file(file_path)
		file_name = dir.get_next()

	dir.list_dir_end()


## Load a single hazard definition from JSON
func _load_hazard_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[HazardManager] Failed to open hazard file: " + file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("[HazardManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	if not data.has("id"):
		push_error("[HazardManager] Hazard definition missing 'id' field: " + file_path)
		return

	# Convert color from hex string to Color
	if data.has("color") and data.color is String:
		data.color = Color.from_string(data.color, Color.RED)

	hazard_definitions[data.id] = data


## Clear all active hazards (called on map transition)
func clear_hazards() -> void:
	active_hazards.clear()


## Place hazards in a generated map based on dungeon definition
## Called by generators after basic layout is created
func place_hazards(map: GameMap, dungeon_def: Dictionary, rng: SeededRandom) -> void:
	var hazards: Array = dungeon_def.get("hazards", [])
	if hazards.is_empty():
		return

	# Find valid floor positions for hazard placement
	var floor_positions: Array[Vector2i] = _get_floor_positions(map)
	if floor_positions.is_empty():
		return

	for hazard_config in hazards:
		var hazard_id: String = hazard_config.get("hazard_id", "")
		var density: float = hazard_config.get("density", 0.05)

		if hazard_id.is_empty():
			continue

		# Calculate number of hazards based on density
		var hazard_count: int = int(floor_positions.size() * density)
		hazard_count = clampi(hazard_count, 1, 10)  # Reasonable limits

		# Place hazards
		floor_positions.shuffle()
		var placed: int = 0
		for pos in floor_positions:
			if placed >= hazard_count:
				break

			if _can_place_hazard_at(map, pos):
				_place_hazard(map, pos, hazard_id, hazard_config, rng)
				placed += 1


## Check if a hazard can be placed at position
func _can_place_hazard_at(map: GameMap, pos: Vector2i) -> bool:
	# Must be walkable floor
	var tile = map.get_tile(pos)
	if tile == null or not tile.walkable:
		return false

	# Can't be on stairs
	if tile.tile_type in ["stairs_up", "stairs_down"]:
		return false

	# Can't already have a hazard
	if active_hazards.has(pos):
		return false

	return true


## Place a hazard at position
func _place_hazard(map: GameMap, pos: Vector2i, hazard_id: String, config: Dictionary, rng: SeededRandom) -> void:
	var hazard_def: Dictionary = hazard_definitions.get(hazard_id, {})
	if hazard_def.is_empty():
		push_warning("Unknown hazard type: %s" % hazard_id)
		return

	# Create hazard instance data
	var hazard_data: Dictionary = {
		"hazard_id": hazard_id,
		"position": pos,
		"definition": hazard_def,
		"config": config,
		"triggered": false,
		"detected": false,
		"disarmed": false,
		"damage": config.get("damage", hazard_def.get("base_damage", 10))
	}

	# Store in active hazards
	active_hazards[pos] = hazard_data

	# Store in map metadata for persistence
	if not map.metadata.has("hazards"):
		map.metadata["hazards"] = []
	map.metadata.hazards.append(hazard_data)


## Get all floor positions in map
func _get_floor_positions(map: GameMap) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []

	for pos in map.tiles:
		var tile = map.tiles[pos]
		if tile != null and tile.walkable:
			positions.append(pos)

	return positions


## Check if entity should trigger hazard at position
## Called when entity moves to new position
func check_hazard_trigger(pos: Vector2i, entity) -> Dictionary:
	print("[HazardManager] Checking trigger at %v, active_hazards has %d entries" % [pos, active_hazards.size()])
	if not active_hazards.has(pos):
		# Debug: print keys to see type mismatch
		if active_hazards.size() > 0:
			var sample_key = active_hazards.keys()[0]
			print("[HazardManager] Sample key type: %s, checking type: %s" % [typeof(sample_key), typeof(pos)])
		return {"triggered": false}

	print("[HazardManager] Found hazard at %v, triggering!" % pos)
	var hazard: Dictionary = active_hazards[pos]
	var hazard_def: Dictionary = hazard.definition

	# Already triggered and one-time?
	if hazard.triggered and hazard_def.get("one_time", false):
		return {"triggered": false}

	# Already disarmed?
	if hazard.disarmed:
		return {"triggered": false}

	var trigger_type: String = hazard_def.get("trigger_type", "step")

	# Check trigger conditions
	match trigger_type:
		"step":
			return _trigger_hazard(hazard, entity)
		"proximity":
			return _trigger_hazard(hazard, entity)
		"pressure_plate":
			return _trigger_hazard(hazard, entity)
		_:
			return {"triggered": false}


## Trigger a hazard
func _trigger_hazard(hazard: Dictionary, entity) -> Dictionary:
	var hazard_def: Dictionary = hazard.definition
	var result: Dictionary = {
		"triggered": true,
		"hazard_id": hazard.hazard_id,
		"damage": hazard.damage,
		"damage_type": hazard_def.get("damage_type", "physical"),
		"effects": []
	}

	# Apply effect if present
	if hazard_def.has("effect"):
		result.effects.append({
			"type": hazard_def.effect,
			"duration": hazard_def.get("duration", 100)
		})

	# Mark as triggered
	hazard.triggered = true

	# Hidden hazards become permanently visible once triggered
	if hazard_def.get("hidden", false):
		hazard.detected = true

	# Emit signal
	hazard_triggered.emit(hazard.hazard_id, hazard.position, entity, hazard.damage)

	return result


## Try to detect hidden hazard at position (passive detection on movement)
## Returns true if hazard was detected
func try_detect_hazard(pos: Vector2i, perception: int) -> bool:
	if not active_hazards.has(pos):
		return false

	var hazard: Dictionary = active_hazards[pos]
	var hazard_def: Dictionary = hazard.definition

	# Already detected or not hidden
	if hazard.detected or not hazard_def.get("hidden", false):
		return false

	var detection_difficulty: int = hazard.config.get("detection_difficulty", 15)

	# Roll against perception
	if perception >= detection_difficulty:
		hazard.detected = true
		hazard_detected.emit(hazard.hazard_id, pos)
		return true

	return false


## Active trap detection with D&D-style skill check
## Roll: d20 + ability_modifier + skill + bonuses vs DC
## Returns: {detected: bool, message: String, hazard_name: String}
func try_active_detect_hazard(pos: Vector2i, ability_modifier: int, traps_skill: int, bonus: int = 0) -> Dictionary:
	if not active_hazards.has(pos):
		return {"detected": false, "message": "You find nothing suspicious.", "hazard_name": ""}

	var hazard: Dictionary = active_hazards[pos]
	var hazard_def: Dictionary = hazard.definition
	var hazard_name: String = hazard_def.get("name", "trap").to_lower()

	# Skip already-discovered hazards silently (detected by search OR triggered)
	if hazard.get("detected", false) or hazard.get("triggered", false):
		return {"detected": false, "message": "", "hazard_name": ""}

	# Skip already-disarmed hazards silently
	if hazard.get("disarmed", false):
		return {"detected": false, "message": "", "hazard_name": ""}

	# Skip non-hidden (visible) hazards silently - they're already visible
	if not hazard_def.get("hidden", false):
		return {"detected": false, "message": "", "hazard_name": ""}

	var detection_difficulty: int = hazard.config.get("detection_difficulty", hazard_def.get("detection_difficulty", 15))

	# D&D-style skill check: d20 + ability modifier + skill + bonuses vs DC
	var dice_roll: int = randi_range(1, 20)
	var total_roll: int = dice_roll + ability_modifier + traps_skill + bonus

	# Build roll breakdown string
	var roll_info = _format_d20_roll_with_bonus(dice_roll, ability_modifier, "WIS", traps_skill, bonus, total_roll, detection_difficulty)

	if total_roll >= detection_difficulty:
		hazard.detected = true
		hazard_detected.emit(hazard.hazard_id, pos)
		return {"detected": true, "message": "You discover a hidden %s! %s" % [hazard_name, roll_info], "hazard_name": hazard_name}

	return {"detected": false, "message": "You sense something, but can't pinpoint it... %s" % roll_info, "hazard_name": hazard_name}


## Try to disarm a hazard at position using player's traps skill
## Returns result dictionary: {success, message, triggered}
func try_disarm_hazard_with_player(pos: Vector2i, player) -> Dictionary:
	if not active_hazards.has(pos):
		return {"success": false, "message": "No hazard here."}

	var hazard: Dictionary = active_hazards[pos]
	var hazard_def: Dictionary = hazard.definition

	if not hazard_def.get("can_disarm", false):
		return {"success": false, "message": "This hazard cannot be disarmed."}

	if hazard.disarmed:
		return {"success": false, "message": "Already disarmed."}

	# Roll d20 + DEX modifier + traps_skill vs disarm DC (like D&D skill checks)
	var disarm_difficulty: int = hazard.config.get("disarm_difficulty", hazard_def.get("disarm_difficulty", 15))
	var dex = player.get_effective_attribute("DEX") if player.has_method("get_effective_attribute") else 10
	var dex_modifier: int = int((dex - 10) / 2.0)  # D&D-style modifier
	var traps_skill = player.skills.get("traps", 0) if "skills" in player else 0

	var dice_roll: int = randi_range(1, 20)
	var total_roll: int = dice_roll + dex_modifier + traps_skill

	# Build roll breakdown string (no bonus for disarm)
	var roll_info = _format_d20_roll_with_bonus(dice_roll, dex_modifier, "DEX", traps_skill, 0, total_roll, disarm_difficulty)

	if total_roll >= disarm_difficulty:
		hazard.disarmed = true
		hazard_disarmed.emit(hazard.hazard_id, pos)
		return {"success": true, "message": "You successfully disarm the %s. %s" % [hazard_def.name.to_lower(), roll_info]}
	else:
		# Failed - trigger hazard!
		return {"success": false, "message": "You fail to disarm the trap! %s" % roll_info, "triggered": true}


## Format d20 roll breakdown for display (grey colored)
## Returns: "[X (Roll) +Y (ATTR) +Z (Skill) +W (Search) = total vs DC N]"
func _format_d20_roll_with_bonus(dice_roll: int, modifier: int, attr_name: String, skill: int, bonus: int, total: int, dc: int) -> String:
	var parts: Array[String] = ["%d (Roll)" % dice_roll]
	parts.append("%+d (%s)" % [modifier, attr_name])
	if skill > 0:
		parts.append("+%d (Skill)" % skill)
	if bonus > 0:
		parts.append("+%d (Search)" % bonus)
	parts.append("= %d vs DC %d" % [total, dc])
	return "[color=gray][%s][/color]" % " ".join(parts)


## Try to disarm a hazard at position (legacy - uses raw skill value)
## Returns result dictionary
func try_disarm_hazard(pos: Vector2i, skill_value: int) -> Dictionary:
	if not active_hazards.has(pos):
		return {"success": false, "message": "No hazard here."}

	var hazard: Dictionary = active_hazards[pos]
	var hazard_def: Dictionary = hazard.definition

	if not hazard_def.get("can_disarm", false):
		return {"success": false, "message": "This hazard cannot be disarmed."}

	if hazard.disarmed:
		return {"success": false, "message": "Already disarmed."}

	var disarm_difficulty: int = hazard.config.get("detection_difficulty", 15)

	# Roll against skill
	if skill_value >= disarm_difficulty:
		hazard.disarmed = true
		hazard_disarmed.emit(hazard.hazard_id, pos)
		return {"success": true, "message": "You successfully disarm the %s." % hazard_def.name.to_lower()}
	else:
		# Failed - trigger hazard!
		return {"success": false, "message": "You fail to disarm the trap!", "triggered": true}


## Get hazard at position (or empty dict)
func get_hazard_at(pos: Vector2i) -> Dictionary:
	return active_hazards.get(pos, {})


## Check if position has visible hazard
func has_visible_hazard(pos: Vector2i) -> bool:
	if not active_hazards.has(pos):
		return false
	var hazard: Dictionary = active_hazards[pos]
	var hazard_def: Dictionary = hazard.definition
	return hazard.detected or not hazard_def.get("hidden", false)


## Check if position has any hazard (for AI)
func has_hazard(pos: Vector2i) -> bool:
	return active_hazards.has(pos)


## Load hazards from map metadata (for saved games and floor transitions)
func load_hazards_from_map(map: GameMap) -> void:
	clear_hazards()

	# Process pending hazards from generator (stored during generation)
	if map.metadata.has("pending_hazards"):
		_process_pending_hazards(map)

	# Load already-placed hazards (from saves or previous processing)
	if not map.metadata.has("hazards"):
		return

	for hazard_data in map.metadata.hazards:
		var pos: Vector2i = _parse_vector2i(hazard_data.position)

		# ALWAYS use fresh definition from hazard_definitions
		# (serialized definitions may have corrupted Color objects from JSON)
		var hazard_id: String = hazard_data.get("hazard_id", "")
		if hazard_definitions.has(hazard_id):
			hazard_data["definition"] = hazard_definitions[hazard_id]
		else:
			push_warning("[HazardManager] Unknown hazard type: %s" % hazard_id)
			continue

		active_hazards[pos] = hazard_data

	print("[HazardManager] Loaded %d hazards from map" % active_hazards.size())


## Process pending hazards stored by generator and convert to active hazards
func _process_pending_hazards(map: GameMap) -> void:
	var pending: Array = map.metadata.get("pending_hazards", [])
	if pending.is_empty():
		return

	# Initialize hazards array if needed
	if not map.metadata.has("hazards"):
		map.metadata["hazards"] = []

	for pending_data in pending:
		var hazard_id: String = pending_data.get("hazard_id", "")
		var pos: Vector2i = _parse_vector2i(pending_data.get("position", Vector2i.ZERO))
		var config: Dictionary = pending_data.get("config", {})

		if hazard_id.is_empty() or not hazard_definitions.has(hazard_id):
			continue

		var hazard_def: Dictionary = hazard_definitions[hazard_id]

		# Create full hazard data
		var hazard_data: Dictionary = {
			"hazard_id": hazard_id,
			"position": pos,
			"definition": hazard_def,
			"config": config,
			"triggered": false,
			"detected": false,
			"disarmed": false,
			"damage": config.get("damage", hazard_def.get("base_damage", 10))
		}

		# Store in active hazards and map metadata
		active_hazards[pos] = hazard_data
		map.metadata.hazards.append(hazard_data)

	# Clear pending after processing
	map.metadata.pending_hazards.clear()
	print("[HazardManager] Processed %d pending hazards" % pending.size())


## Check hazards in radius around position (for proximity triggers)
## Each proximity hazard has its own proximity_radius defined in its definition
func check_proximity_hazards(center: Vector2i, _max_radius: int, entity) -> Array:
	var triggered: Array = []

	# Check all active hazards to see if player is within their proximity radius
	for pos in active_hazards:
		var hazard: Dictionary = active_hazards[pos]
		var hazard_def: Dictionary = hazard.definition

		# Only check proximity triggers
		if hazard_def.get("trigger_type") != "proximity":
			continue

		# Skip already triggered hazards (proximity hazards only trigger once)
		if hazard.triggered:
			continue

		# Skip disarmed hazards
		if hazard.disarmed:
			continue

		# Get the hazard's proximity radius (default to 1)
		var proximity_radius: int = hazard_def.get("proximity_radius", 1)

		# Check if player is within this hazard's proximity radius
		var distance = max(abs(center.x - pos.x), abs(center.y - pos.y))  # Chebyshev distance
		if distance <= proximity_radius:
			var result = _trigger_hazard(hazard, entity)
			if result.triggered:
				triggered.append(result)

	return triggered


## Parse Vector2i from string format (handles save data serialization)
## Strings are in format "(x, y)" from JSON serialization
func _parse_vector2i(value) -> Vector2i:
	# Already a Vector2i - return as is
	if value is Vector2i:
		return value

	# String format - parse it
	if value is String:
		var cleaned = value.strip_edges().replace("(", "").replace(")", "")
		var parts = cleaned.split(",")
		if parts.size() != 2:
			push_warning("[HazardManager] Invalid Vector2i string format: %s" % value)
			return Vector2i.ZERO
		return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))

	# Dictionary format (alternative serialization)
	if value is Dictionary:
		return Vector2i(value.get("x", 0), value.get("y", 0))

	push_warning("[HazardManager] Cannot parse Vector2i from type: %s" % typeof(value))
	return Vector2i.ZERO

## Called when a chunk is unloaded - removes hazards that were spawned in that chunk
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
	var removed_count = 0
	var positions_to_remove: Array[Vector2i] = []

	# Find all hazards in the unloaded chunk
	for pos in active_hazards:
		var hazard_chunk = ChunkManagerClass.world_to_chunk(pos)
		if hazard_chunk == chunk_coords:
			positions_to_remove.append(pos)

	# Remove them
	for pos in positions_to_remove:
		active_hazards.erase(pos)
		removed_count += 1

	if removed_count > 0:
		print("[HazardManager] Cleaned up %d hazards from unloaded chunk %v" % [removed_count, chunk_coords])
