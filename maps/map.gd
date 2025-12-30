class_name GameMap

## GameMap - Holds a single map's tiles and metadata
##
## Stores the tile grid, entities, and metadata for a map.
## Can be the overworld or a dungeon floor.

const GameTile = preload("res://maps/game_tile.gd")

var map_id: String  # "overworld" or "dungeon_barrow_floor_5"
var width: int
var height: int
var tiles: Dictionary = {}  # Vector2i -> GameTile
var seed: int  # Seed used to generate this map
var entities: Array = []  # Array of Entity objects

func _init(id: String = "", w: int = 100, h: int = 100, s: int = 0) -> void:
	map_id = id
	width = w
	height = h
	seed = s

## Get tile at position
func get_tile(pos: Vector2i) -> GameTile:
	if pos in tiles:
		return tiles[pos]
	# Return wall if out of bounds
	return _create_tile("wall")

## Set tile at position
func set_tile(pos: Vector2i, tile: GameTile) -> void:
	tiles[pos] = tile

## Check if position is walkable
func is_walkable(pos: Vector2i) -> bool:
	# Check bounds
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return false

	var tile = get_tile(pos)
	if not tile.walkable:
		return false

	# Check if any entity blocks movement at this position
	for entity in entities:
		if entity.position == pos and entity.blocks_movement:
			return false

	return true

## Check if position is transparent (for FOV)
func is_transparent(pos: Vector2i) -> bool:
	# Out of bounds is not transparent
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return false

	return get_tile(pos).transparent

## Fill entire map with a tile type
func fill(tile_type: String) -> void:
	for y in range(height):
		for x in range(width):
			set_tile(Vector2i(x, y), _create_tile(tile_type))

## Create a tile by type (helper function)
func _create_tile(type: String) -> GameTile:
	return GameTile.create(type)
