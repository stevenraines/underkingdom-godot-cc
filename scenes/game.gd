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
	player.position = Vector2i(10, 10)  # Center of 20x20 map
	MapManager.current_map.entities.append(player)

	# Set player reference in input handler
	input_handler.set_player(player)

	# Initial render
	_render_map()
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
	_render_map()

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
