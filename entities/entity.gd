class_name Entity

## Entity - Base class for all game entities
##
## Represents any entity in the game: player, enemies, NPCs, items.
## For Core Loop, this is a minimal implementation.

var entity_id: String = ""
var position: Vector2i = Vector2i.ZERO
var ascii_char: String = "?"
var color: Color = Color.WHITE
var blocks_movement: bool = true

func _init(id: String = "", pos: Vector2i = Vector2i.ZERO, char: String = "?", entity_color: Color = Color.WHITE, blocks: bool = true) -> void:
	entity_id = id
	position = pos
	ascii_char = char
	color = entity_color
	blocks_movement = blocks
