extends Node
class_name HazardManagerClass
## Manages dungeon hazards - traps and environmental dangers
##
## Hazards include: floor_trap, curse_zone, collapsing_ceiling, toxic_water,
## disease_zone, explosive_gas, etc. Hazards trigger when entities enter
## their area or interact with triggers.

## Signal emitted when hazard is triggered
signal hazard_triggered(hazard_id: String, position: Vector2i, target, damage: int)

## Signal emitted when hazard is detected by player
signal hazard_detected(hazard_id: String, position: Vector2i)

## Signal emitted when hazard is disarmed
signal hazard_disarmed(hazard_id: String, position: Vector2i)

## Dictionary of active hazards on current map
## Key: Vector2i position, Value: hazard data dictionary
var active_hazards: Dictionary = {}

## Hazard type definitions
var hazard_definitions: Dictionary = {
	"floor_trap": {
		"name": "Floor Trap",
		"ascii_char": "^",
		"color": Color.DARK_RED,
		"hidden": true,
		"trigger_type": "step",
		"damage_type": "physical",
		"base_damage": 10,
		"can_disarm": true,
		"detection_skill": "perception",
		"disarm_skill": "dexterity"
	},
	"curse_zone": {
		"name": "Curse Zone",
		"ascii_char": "~",
		"color": Color.PURPLE,
		"hidden": false,
		"trigger_type": "proximity",
		"damage_type": "magical",
		"effect": "stat_drain",
		"duration": 100,
		"can_disarm": false
	},
	"collapsing_ceiling": {
		"name": "Collapsing Ceiling",
		"ascii_char": "!",
		"color": Color.GRAY,
		"hidden": true,
		"trigger_type": "pressure_plate",
		"damage_type": "physical",
		"base_damage": 20,
		"can_disarm": false,
		"one_time": true
	},
	"pitfall": {
		"name": "Pitfall",
		"ascii_char": "O",
		"color": Color.BLACK,
		"hidden": true,
		"trigger_type": "step",
		"damage_type": "fall",
		"base_damage": 15,
		"can_disarm": false
	},
	"toxic_water": {
		"name": "Toxic Water",
		"ascii_char": "~",
		"color": Color.LIME_GREEN,
		"hidden": false,
		"trigger_type": "step",
		"damage_type": "poison",
		"base_damage": 5,
		"effect": "poison",
		"duration": 50,
		"can_disarm": false
	},
	"disease_zone": {
		"name": "Disease Zone",
		"ascii_char": ".",
		"color": Color.OLIVE_DRAB,
		"hidden": false,
		"trigger_type": "proximity",
		"damage_type": "disease",
		"effect": "disease",
		"duration": 200,
		"can_disarm": false
	},
	"explosive_gas": {
		"name": "Explosive Gas",
		"ascii_char": "*",
		"color": Color.ORANGE,
		"hidden": false,
		"trigger_type": "fire",
		"damage_type": "fire",
		"base_damage": 30,
		"radius": 3,
		"can_disarm": false
	},
	"arrow_slit": {
		"name": "Arrow Slit",
		"ascii_char": "-",
		"color": Color.DARK_GRAY,
		"hidden": false,
		"trigger_type": "line_of_sight",
		"damage_type": "physical",
		"base_damage": 8,
		"range": 10,
		"can_disarm": false
	},
	"magical_ward": {
		"name": "Magical Ward",
		"ascii_char": "*",
		"color": Color.CYAN,
		"hidden": true,
		"trigger_type": "proximity",
		"damage_type": "magical",
		"base_damage": 15,
		"can_disarm": true,
		"disarm_skill": "intelligence"
	},
	"sudden_flood": {
		"name": "Sudden Flood",
		"ascii_char": "=",
		"color": Color.DARK_BLUE,
		"hidden": true,
		"trigger_type": "timer",
		"damage_type": "drowning",
		"base_damage": 10,
		"effect": "slow",
		"duration": 30,
		"can_disarm": false
	},
	"divine_curse": {
		"name": "Divine Curse",
		"ascii_char": "X",
		"color": Color.GOLD,
		"hidden": false,
		"trigger_type": "theft",
		"damage_type": "divine",
		"effect": "curse",
		"duration": 500,
		"can_disarm": false
	},
	"unstable_ground": {
		"name": "Unstable Ground",
		"ascii_char": ".",
		"color": Color.TAN,
		"hidden": true,
		"trigger_type": "step",
		"damage_type": "fall",
		"base_damage": 10,
		"can_disarm": false
	}
}


func _ready() -> void:
	print("[HazardManager] Initialized with %d hazard definitions" % hazard_definitions.size())


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
	if not active_hazards.has(pos):
		return {"triggered": false}

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


## Check hazards in radius around position (for proximity triggers)
func check_proximity_hazards(center: Vector2i, radius: int, entity) -> Array:
	var triggered: Array = []

	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var pos := Vector2i(center.x + dx, center.y + dy)
			if active_hazards.has(pos):
				var hazard: Dictionary = active_hazards[pos]
				if hazard.definition.get("trigger_type") == "proximity":
					var result = _trigger_hazard(hazard, entity)
					if result.triggered:
						triggered.append(result)

	return triggered
