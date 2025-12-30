extends Node

## EntityManager - Manages all entities in the game
##
## Keeps track of all entities (enemies, NPCs, items), handles spawning,
## and coordinates entity updates during turns.

# All active entities (excluding player)
var entities: Array[Entity] = []

# Enemy definitions cache
var enemy_definitions: Dictionary = {}

# Player reference (set by game scene)
var player: Player = null

func _ready() -> void:
	print("EntityManager initialized")
	_load_enemy_definitions()

## Load enemy definitions from JSON files
func _load_enemy_definitions() -> void:
	var enemy_files = ["grave_rat", "barrow_wight", "woodland_wolf"]

	for enemy_id in enemy_files:
		var file_path = "res://data/enemies/%s.json" % enemy_id
		var file = FileAccess.open(file_path, FileAccess.READ)

		if file:
			var json_string = file.get_as_text()
			var json = JSON.new()
			var parse_result = json.parse(json_string)

			if parse_result == OK:
				enemy_definitions[enemy_id] = json.data
				print("Loaded enemy definition: ", enemy_id)
			else:
				push_error("Failed to parse enemy JSON: " + file_path)

			file.close()
		else:
			push_error("Failed to load enemy file: " + file_path)

## Spawn an enemy at a position
func spawn_enemy(enemy_id: String, pos: Vector2i) -> Enemy:
	if not enemy_id in enemy_definitions:
		push_error("Unknown enemy ID: " + enemy_id)
		return null

	var enemy = Enemy.create(enemy_definitions[enemy_id])
	enemy.position = pos

	entities.append(enemy)

	# Add to current map's entity list
	if MapManager.current_map:
		MapManager.current_map.entities.append(enemy)

	print("Spawned %s at %s" % [enemy.name, pos])
	return enemy

## Remove an entity (when it dies or is removed)
func remove_entity(entity: Entity) -> void:
	entities.erase(entity)

	if MapManager.current_map:
		MapManager.current_map.entities.erase(entity)

## Get all entities at a position
func get_entities_at(pos: Vector2i) -> Array[Entity]:
	var result: Array[Entity] = []

	for entity in entities:
		if entity.position == pos and entity.is_alive:
			result.append(entity)

	return result

## Get entity blocking movement at position (returns first blocking entity)
func get_blocking_entity_at(pos: Vector2i) -> Entity:
	for entity in entities:
		if entity.position == pos and entity.blocks_movement and entity.is_alive:
			return entity

	return null

## Process all entity turns (called after player turn)
func process_entity_turns() -> void:
	for entity in entities:
		if entity.is_alive and entity is Enemy:
			(entity as Enemy).take_turn()

## Clear all entities (for map transitions)
func clear_entities() -> void:
	entities.clear()

## Get entities on current map
func get_current_map_entities() -> Array[Entity]:
	return entities.filter(func(e): return e.is_alive)
