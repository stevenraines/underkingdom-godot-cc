class_name GameTile

## GameTile - Represents a single tile's properties
##
## Stores all data needed for a tile: type, movement/visibility properties,
## and visual representation.

var tile_type: String  # "floor", "wall", "tree", "water", "stairs_down", etc.
var walkable: bool
var transparent: bool  # For FOV calculations
var ascii_char: String  # Visual representation

func _init(type: String = "floor", is_walkable: bool = true, is_transparent: bool = true, character: String = ".") -> void:
	tile_type = type
	walkable = is_walkable
	transparent = is_transparent
	ascii_char = character

## Factory method to create tiles by type
static func create(type: String) -> GameTile:
	var tile = GameTile.new()

	match type:
		"floor":
			tile.tile_type = "floor"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "."
		"wall":
			tile.tile_type = "wall"
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "#"
		"tree":
			tile.tile_type = "tree"
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "T"
		"water":
			tile.tile_type = "water"
			tile.walkable = false
			tile.transparent = true
			tile.ascii_char = "~"
		"stairs_down":
			tile.tile_type = "stairs_down"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = ">"
		"stairs_up":
			tile.tile_type = "stairs_up"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "<"
		"door":
			tile.tile_type = "door"
			tile.walkable = true
			tile.transparent = false
			tile.ascii_char = "+"
		_:
			push_warning("Unknown tile type: " + type + ", defaulting to floor")
			tile.tile_type = "floor"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "."

	return tile
