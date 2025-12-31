class_name ContainerComponent
extends RefCounted

## ContainerComponent - Stores items like a chest or storage container
##
## Wraps the Inventory class to provide storage functionality for structures.

# Storage
var inventory: Inventory = null
var max_weight: float = 50.0  # kg
var is_locked: bool = false  # Future: lock/key system

func _init(max_weight_kg: float = 50.0) -> void:
	max_weight = max_weight_kg
	# Create inventory without an owner (structures don't have stats)
	inventory = Inventory.new(null)
	inventory.max_weight = max_weight

## Add item to container
func add_item(item: Item) -> bool:
	if is_locked:
		return false

	return inventory.add_item(item)

## Remove item from container
func remove_item(item: Item) -> bool:
	if is_locked:
		return false

	return inventory.remove_item(item)

## Get all items in container
func get_items() -> Array[Item]:
	return inventory.items

## Get total weight of items
func get_total_weight() -> float:
	return inventory.get_total_weight()

## Check if container is full
func is_full() -> bool:
	return inventory.get_total_weight() >= max_weight

## Serialize container state for save system
func serialize() -> Dictionary:
	return {
		"max_weight": max_weight,
		"is_locked": is_locked,
		"inventory": inventory.serialize()
	}

## Deserialize container state from save data
func deserialize(data: Dictionary) -> void:
	max_weight = data.get("max_weight", 50.0)
	is_locked = data.get("is_locked", false)

	if data.has("inventory"):
		inventory.deserialize(data.inventory)
