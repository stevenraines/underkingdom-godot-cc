class_name Player
extends Entity

## Player - The player character entity
##
## Handles player movement, interactions, and dungeon navigation.

# Player attributes (stub for now, full implementation in Phase 1.7)
var attributes: Dictionary = {
	"STR": 10,
	"DEX": 10,
	"CON": 10,
	"INT": 10,
	"WIS": 10,
	"CHA": 10
}

var perception_range: int = 10

func _init() -> void:
	super("player", Vector2i(10, 10), "@", Color(1.0, 1.0, 0.0), true)

## Attempt to move in a direction
func move(direction: Vector2i) -> bool:
	var new_pos = position + direction

	# Check if new position is walkable
	if MapManager.current_map and MapManager.current_map.is_walkable(new_pos):
		var old_pos = position
		position = new_pos
		EventBus.player_moved.emit(old_pos, new_pos)
		return true

	return false

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
