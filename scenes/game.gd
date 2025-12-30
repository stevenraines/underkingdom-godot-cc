extends Node2D

## Game - Main game scene
##
## Initializes the game, creates player, manages rendering and updates.

var player: Player
var renderer: ASCIIRenderer
var input_handler: Node

@onready var hud: CanvasLayer = $HUD
@onready var turn_counter: Label = $HUD/TurnCounter
@onready var message_label: Label = $HUD/MessageLabel

func _ready() -> void:
	# Get renderer reference
	renderer = $ASCIIRenderer

	# Get input handler
	input_handler = $InputHandler

	# Start new game
	GameManager.start_new_game()

	# Generate overworld
	MapManager.transition_to_map("overworld")

	# Create player
	player = Player.new()
	player.position = _find_valid_spawn_position()
	MapManager.current_map.entities.append(player)

	# Set player reference in input handler and EntityManager
	input_handler.set_player(player)
	EntityManager.player = player

	# Spawn initial enemies
	_spawn_map_enemies()

	# Initial render
	_render_map()
	_render_all_entities()
	renderer.render_entity(player.position, "@", Color.YELLOW)
	renderer.center_camera(player.position)

	# Calculate initial FOV
	var visible_tiles = FOVSystem.calculate_fov(player.position, player.perception_range, MapManager.current_map)
	renderer.update_fov(visible_tiles)

	# Connect signals
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.turn_advanced.connect(_on_turn_advanced)

	# Update HUD
	_update_hud()

	print("Game scene initialized")

## Render the entire current map
func _render_map() -> void:
	if not MapManager.current_map:
		return

	renderer.clear_all()

	for y in range(MapManager.current_map.height):
		for x in range(MapManager.current_map.width):
			var pos = Vector2i(x, y)
			var tile = MapManager.current_map.get_tile(pos)
			renderer.render_tile(pos, tile.ascii_char)

## Called when player moves
func _on_player_moved(old_pos: Vector2i, new_pos: Vector2i) -> void:
	renderer.clear_entity(old_pos)
	renderer.render_entity(new_pos, "@", Color.YELLOW)
	renderer.center_camera(new_pos)

	# Update FOV
	var visible_tiles = FOVSystem.calculate_fov(new_pos, player.perception_range, MapManager.current_map)
	renderer.update_fov(visible_tiles)

	# Check if standing on stairs and update message
	_update_message()

## Called when map changes (dungeon transitions, etc.)
func _on_map_changed(map_id: String) -> void:
	print("Map changed to: ", map_id)

	# Clear existing entities from EntityManager
	EntityManager.clear_entities()

	# Spawn enemies for the new map
	_spawn_map_enemies()

	# Render map and entities
	_render_map()
	_render_all_entities()

	# Re-render player at new position
	renderer.render_entity(player.position, "@", Color.YELLOW)
	renderer.center_camera(player.position)

	# Update FOV
	var visible_tiles = FOVSystem.calculate_fov(player.position, player.perception_range, MapManager.current_map)
	renderer.update_fov(visible_tiles)

	# Update message
	_update_message()

## Called when turn advances
func _on_turn_advanced(_turn_number: int) -> void:
	_update_hud()

## Update HUD display
func _update_hud() -> void:
	if turn_counter:
		var map_name = MapManager.current_map.map_id if MapManager.current_map else "Unknown"
		turn_counter.text = "Turn: %d | %s | Map: %s" % [TurnManager.current_turn, TurnManager.time_of_day, map_name]

## Update message based on player position
func _update_message() -> void:
	if not message_label or not player or not MapManager.current_map:
		return

	var tile = MapManager.current_map.get_tile(player.position)

	if tile.tile_type == "stairs_down":
		message_label.text = "Standing on stairs (>) - Press > to descend"
	elif tile.tile_type == "stairs_up":
		message_label.text = "Standing on stairs (<) - Press < to ascend"
	else:
		message_label.text = "WASD/Arrows: Move"

## Spawn enemies from map metadata
func _spawn_map_enemies() -> void:
	if not MapManager.current_map or not MapManager.current_map.has_meta("enemy_spawns"):
		return

	var enemy_spawns = MapManager.current_map.get_meta("enemy_spawns")

	for spawn_data in enemy_spawns:
		var enemy_id = spawn_data["enemy_id"]
		var spawn_pos = spawn_data["position"]
		EntityManager.spawn_enemy(enemy_id, spawn_pos)

## Render all entities on the current map
func _render_all_entities() -> void:
	for entity in EntityManager.entities:
		if entity.is_alive:
			renderer.render_entity(entity.position, entity.ascii_char, entity.color)

## Find a valid spawn position for the player (walkable, not occupied)
func _find_valid_spawn_position() -> Vector2i:
	if not MapManager.current_map:
		return Vector2i(10, 10)  # Fallback

	# Try center first
	var center = Vector2i(MapManager.current_map.width / 2, MapManager.current_map.height / 2)
	if _is_valid_spawn_position(center):
		return center

	# Search in a spiral pattern from center
	var max_radius = max(MapManager.current_map.width, MapManager.current_map.height)

	for radius in range(1, max_radius):
		for angle in range(0, 360, 15):  # Check every 15 degrees
			var rad = deg_to_rad(angle)
			var offset = Vector2i(int(cos(rad) * radius), int(sin(rad) * radius))
			var pos = center + offset

			if _is_valid_spawn_position(pos):
				return pos

	# Last resort: find ANY walkable tile
	for y in range(MapManager.current_map.height):
		for x in range(MapManager.current_map.width):
			var pos = Vector2i(x, y)
			if _is_valid_spawn_position(pos):
				return pos

	# Absolute fallback
	push_warning("Could not find valid spawn position, using center anyway")
	return center

## Check if a position is valid for player spawn
func _is_valid_spawn_position(pos: Vector2i) -> bool:
	if not MapManager.current_map:
		return false

	# Check bounds
	if pos.x < 0 or pos.x >= MapManager.current_map.width:
		return false
	if pos.y < 0 or pos.y >= MapManager.current_map.height:
		return false

	# Check if walkable
	if not MapManager.current_map.is_walkable(pos):
		return false

	# Check not occupied by enemy
	var blocking_entity = EntityManager.get_blocking_entity_at(pos)
	if blocking_entity != null:
		return false

	return true
