class_name GroundItem
extends Entity

## GroundItem - An item lying on the ground in the world
##
## Can be picked up by the player when walking over or interacting.

# The actual item this represents
var item: Item = null

# Turn when this item will despawn (-1 = never)
var despawn_turn: int = -1

func _init(p_item: Item = null, pos: Vector2i = Vector2i.ZERO) -> void:
	if p_item:
		item = p_item
		super._init(
			"ground_item_" + p_item.id,
			pos,
			p_item.ascii_char,
			p_item.get_color(),
			false  # Ground items don't block movement
		)
		entity_type = "ground_item"
		name = p_item.name
	else:
		super._init("ground_item", pos, "?", Color.WHITE, false)
		entity_type = "ground_item"

## Create a ground item from an item
static func create(p_item: Item, pos: Vector2i, despawn_after_turns: int = -1) -> GroundItem:
	var ground_item = GroundItem.new(p_item, pos)
	if despawn_after_turns > 0:
		ground_item.despawn_turn = TurnManager.current_turn + despawn_after_turns
	return ground_item

## Check if this ground item should despawn
func should_despawn(current_turn: int) -> bool:
	return despawn_turn > 0 and current_turn >= despawn_turn

## Get item tooltip
func get_interaction_text() -> String:
	if item:
		return "Pick up: %s" % item.name
	return "Pick up item"

## Get full tooltip with item details
func get_tooltip() -> String:
	if item:
		return item.get_tooltip()
	return "Unknown item"
