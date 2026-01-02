extends Node
class_name HazardManagerClass
## Manages dungeon hazards - traps and environmental dangers
##
## Hazards are loaded from JSON files in data/hazards/
## Hazards trigger when entities enter their area or interact with triggers.

const HAZARD_DATA_PATH = "res://data/hazards"

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


## Try to detect hidden hazard at position
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


## Try to disarm a hazard at position
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
		var pos: Vector2i = hazard_data.position

		# Ensure hazard has its definition reference
		if not hazard_data.has("definition"):
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
		var pos: Vector2i = pending_data.get("position", Vector2i.ZERO)
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
