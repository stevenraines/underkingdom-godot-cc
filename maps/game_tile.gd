class_name GameTile

## GameTile - Represents a single tile's properties
##
## Stores all data needed for a tile: type, movement/visibility properties,
## and visual representation.

var tile_type: String  # "floor", "wall", "tree", "water", "stairs_down", etc.
var walkable: bool
var transparent: bool  # For FOV calculations
var ascii_char: String  # Visual representation
var is_fire_source: bool = false  # Used for proximity crafting
var harvestable_resource_id: String = ""  # ID of harvestable resource (if any)
var color: Color = Color.WHITE  # Tile color (set by biome for floor/grass tiles)
var is_open: bool = false  # For doors: true = open (walkable/transparent), false = closed

# Lock properties (for doors)
var is_locked: bool = false      # Whether the door is locked
var lock_id: String = ""         # Unique ID matching a specific key
var lock_level: int = 1          # Lock difficulty (1-10, higher = harder)

func _init(type: String = "floor", is_walkable: bool = true, is_transparent: bool = true, character: String = ".", fire: bool = false) -> void:
	tile_type = type
	walkable = is_walkable
	transparent = is_transparent
	ascii_char = character
	is_fire_source = fire

## Factory method to create tiles by type
static func create(type: String) -> GameTile:
	var tile = GameTile.new()

	match type:
		"floor", "stone_floor":
			tile.tile_type = type
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "."
		"wall", "stone_wall":
			tile.tile_type = type
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "#"
		"tree":
			tile.tile_type = "tree"
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "T"
			tile.harvestable_resource_id = "tree"
		"water":
			tile.tile_type = "water"
			tile.walkable = false
			tile.transparent = true
			tile.ascii_char = "~"
			tile.harvestable_resource_id = "water"
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
		"dungeon_entrance":
			tile.tile_type = "dungeon_entrance"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = ">"  # Default, will be overridden
		"door", "wooden_door", "door_open":
			# Open door: walkable and transparent
			tile.tile_type = "door"
			tile.is_open = true
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "/"
		"door_closed":
			# Closed door: blocks movement and vision
			tile.tile_type = "door"
			tile.is_open = false
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "+"
		"door_locked":
			# Locked closed door: blocks movement and vision, requires key/lockpick
			tile.tile_type = "door"
			tile.is_open = false
			tile.is_locked = true
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "+"
		"rock":
			tile.tile_type = "rock"
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "◆"
			tile.harvestable_resource_id = "rock"
		"wheat":
			tile.tile_type = "wheat"
			tile.walkable = false
			tile.transparent = true
			tile.ascii_char = "\""
			tile.harvestable_resource_id = "wheat"
		"iron_ore":
			tile.tile_type = "iron_ore"
			tile.walkable = false
			tile.transparent = false
			tile.ascii_char = "◊"
			tile.harvestable_resource_id = "iron_ore"
		_:
			push_warning("Unknown tile type: " + type + ", defaulting to floor")
			tile.tile_type = "floor"
			tile.walkable = true
			tile.transparent = true
			tile.ascii_char = "."

	return tile

## Toggle door open/closed state
## Returns true if successful, false if not a door
func toggle_door() -> bool:
	if tile_type != "door":
		return false
	is_open = !is_open
	walkable = is_open
	transparent = is_open
	ascii_char = "/" if is_open else "+"
	return true

## Open a door (if closed)
## Returns true if door was opened, false if already open or not a door
func open_door() -> bool:
	if tile_type != "door" or is_open:
		return false
	is_open = true
	walkable = true
	transparent = true
	ascii_char = "/"
	return true

## Close a door (if open)
## Returns true if door was closed, false if already closed or not a door
func close_door() -> bool:
	if tile_type != "door" or not is_open:
		return false
	is_open = false
	walkable = false
	transparent = false
	ascii_char = "+"
	return true

## Unlock a locked door
## Returns true if door was unlocked, false if not locked or not a door
func unlock() -> bool:
	if tile_type != "door" or not is_locked:
		return false
	is_locked = false
	return true

## Lock an unlocked closed door
## Returns true if door was locked, false if open, already locked, or not a door
func lock() -> bool:
	if tile_type != "door" or is_open or is_locked:
		return false
	is_locked = true
	return true

## Set lock properties for this door
func set_lock(new_lock_id: String, new_lock_level: int) -> void:
	lock_id = new_lock_id
	lock_level = new_lock_level
	is_locked = true
