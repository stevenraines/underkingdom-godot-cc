class_name Player
extends Entity

## Player - The player character entity
##
## Handles player movement, interactions, and dungeon navigation.

# Preload combat system to ensure it's available
const _CombatSystem = preload("res://systems/combat_system.gd")
const _SurvivalSystem = preload("res://systems/survival_system.gd")

var perception_range: int = 10
var survival: SurvivalSystem = null

func _init() -> void:
	super("player", Vector2i(10, 10), "@", Color(1.0, 1.0, 0.0), true)
	_setup_player()

## Setup player-specific properties
func _setup_player() -> void:
	entity_type = "player"
	name = "Player"
	base_damage = 2  # Unarmed combat damage
	armor = 0  # No armor initially

	# Player starts with base attributes (defined in Entity)
	# Perception range calculated from WIS: Base 5 + (WIS / 2)
	perception_range = 5 + int(attributes["WIS"] / 2.0)
	
	# Initialize survival system
	survival = _SurvivalSystem.new(self)

## Attempt to attack a target entity
func attack(target: Entity) -> Dictionary:
	# Consume stamina for attack
	if survival and not survival.consume_stamina(survival.STAMINA_COST_ATTACK):
		return {"hit": false, "no_stamina": true}
	return _CombatSystem.attempt_attack(self, target)

## Attempt to move in a direction
func move(direction: Vector2i) -> bool:
	var new_pos = position + direction

	# Check if new position is walkable
	if MapManager.current_map and MapManager.current_map.is_walkable(new_pos):
		# Consume stamina for movement (allow move even if depleted, just add fatigue)
		if survival:
			if not survival.consume_stamina(survival.STAMINA_COST_MOVE):
				# Out of stamina - still allow movement but warn player
				pass
		
		var old_pos = position
		position = new_pos
		EventBus.player_moved.emit(old_pos, new_pos)
		return true

	return false

## Process survival systems for a turn
func process_survival_turn(turn_number: int) -> Dictionary:
	if not survival:
		return {}
	
	# Update temperature based on current location and time
	var map_id = MapManager.current_map.map_id if MapManager.current_map else "overworld"
	survival.update_temperature(map_id, TurnManager.time_of_day)
	
	# Process survival effects
	var effects = survival.process_turn(turn_number)
	
	# Apply stat modifiers from survival
	apply_stat_modifiers(survival.get_stat_modifiers())
	
	# Update perception range based on survival effects
	var survival_effects = survival._calculate_survival_effects()
	var base_perception = 5 + int(attributes["WIS"] / 2.0)
	perception_range = max(2, base_perception + survival_effects.perception_modifier)
	
	return effects

## Regenerate stamina (called when waiting/not acting)
func regenerate_stamina() -> void:
	if survival:
		var effects = survival._calculate_survival_effects()
		survival.regenerate_stamina(effects.stamina_regen_modifier)

## Interact with the tile the player is standing on
func interact_with_tile() -> void:
	if not MapManager.current_map:
		return

	var tile = MapManager.current_map.get_tile(position)

	if tile.tile_type == "stairs_down":
		_descend_stairs()
	elif tile.tile_type == "stairs_up":
		_ascend_stairs()

## Descend stairs to next floor
func _descend_stairs() -> void:
	print("Player descending stairs...")
	MapManager.descend_dungeon()

	# Find stairs up on new floor and position player there
	_find_and_move_to_stairs("stairs_up")

## Ascend stairs to previous floor
func _ascend_stairs() -> void:
	print("Player ascending stairs...")
	MapManager.ascend_dungeon()

	# Find stairs down on new floor and position player there
	# (works for both overworld entrance and dungeon floors)
	_find_and_move_to_stairs("stairs_down")

## Find stairs of given type and move player there
func _find_and_move_to_stairs(stairs_type: String) -> void:
	if not MapManager.current_map:
		return

	var old_pos = position

	# Search for stairs
	for y in range(MapManager.current_map.height):
		for x in range(MapManager.current_map.width):
			var pos = Vector2i(x, y)
			var tile = MapManager.current_map.get_tile(pos)
			if tile.tile_type == stairs_type:
				position = pos
				print("Player positioned at ", stairs_type, ": ", position)
				EventBus.player_moved.emit(old_pos, position)
				return

	# Fallback to center if stairs not found
	@warning_ignore("integer_division")
	position = Vector2i(MapManager.current_map.width / 2, MapManager.current_map.height / 2)
	push_warning("Could not find ", stairs_type, ", positioning at center")
	EventBus.player_moved.emit(old_pos, position)
