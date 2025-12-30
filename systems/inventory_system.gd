class_name Inventory
extends RefCounted

## Inventory - Manages items and equipment for an entity
##
## Handles weight tracking, equipment slots, and encumbrance penalties.

# General inventory items
var items: Array[Item] = []

# Equipment slots
var equipment: Dictionary = {
	"head": null,
	"torso": null,
	"hands": null,
	"legs": null,
	"feet": null,
	"main_hand": null,
	"off_hand": null,
	"accessory_1": null,
	"accessory_2": null
}

# Capacity
var max_weight: float = 45.0  # Default, recalculated from STR

# Owner reference
var _owner: Entity = null

# Equipment slot display names
const SLOT_NAMES: Dictionary = {
	"head": "Head",
	"torso": "Torso",
	"hands": "Hands",
	"legs": "Legs",
	"feet": "Feet",
	"main_hand": "Main Hand",
	"off_hand": "Off Hand",
	"accessory_1": "Accessory",
	"accessory_2": "Accessory"
}

func _init(owner: Entity = null) -> void:
	_owner = owner
	if owner:
		recalculate_max_weight(owner.attributes.get("STR", 10))

## Recalculate max carry weight based on STR
## Formula: Base 20 + (STR × 5) kg
func recalculate_max_weight(strength: int) -> void:
	max_weight = 20.0 + (strength * 5.0)

## Get total weight of all carried items (inventory + equipped)
func get_total_weight() -> float:
	var total: float = 0.0
	
	# Inventory items
	for item in items:
		total += item.get_total_weight()
	
	# Equipped items
	for slot in equipment:
		var equipped = equipment[slot]
		if equipped:
			total += equipped.get_total_weight()
	
	return total

## Get encumbrance ratio (0.0 = empty, 1.0 = at capacity, >1.0 = overweight)
func get_encumbrance_ratio() -> float:
	if max_weight <= 0:
		return 0.0
	return get_total_weight() / max_weight

## Get encumbrance penalty details
func get_encumbrance_penalty() -> Dictionary:
	var ratio = get_encumbrance_ratio()
	var result = {
		"can_move": true,
		"stamina_multiplier": 1.0,
		"movement_cost": 1,
		"ratio": ratio,
		"state": "normal"
	}
	
	if ratio > 1.25:
		result.can_move = false
		result.state = "immobile"
	elif ratio > 1.0:
		result.stamina_multiplier = 2.0
		result.movement_cost = 2
		result.state = "overburdened"
	elif ratio > 0.75:
		result.stamina_multiplier = 1.5
		result.state = "encumbered"
	
	return result

## Add an item to inventory
## Returns false if item couldn't be added (overweight or other reason)
func add_item(item: Item) -> bool:
	if not item:
		return false
	
	# Try to stack with existing items first
	if item.max_stack > 1:
		for existing in items:
			if existing.can_stack_with(item):
				var leftover = existing.add_to_stack(item.stack_size)
				if leftover <= 0:
					EventBus.inventory_changed.emit()
					return true
				item.stack_size = leftover
	
	# Add as new item
	items.append(item)
	EventBus.inventory_changed.emit()
	EventBus.encumbrance_changed.emit(get_encumbrance_ratio())
	
	return true

## Remove an item from inventory
func remove_item(item: Item) -> bool:
	var index = items.find(item)
	if index >= 0:
		items.remove_at(index)
		EventBus.inventory_changed.emit()
		EventBus.encumbrance_changed.emit(get_encumbrance_ratio())
		return true
	return false

## Remove items by ID and count
## Returns the actual number removed
func remove_item_by_id(item_id: String, count: int = 1) -> int:
	var removed = 0
	var to_remove: Array[Item] = []
	
	for item in items:
		if item.id == item_id and removed < count:
			var can_remove = min(item.stack_size, count - removed)
			item.remove_from_stack(can_remove)
			removed += can_remove
			
			if item.is_empty():
				to_remove.append(item)
	
	# Clean up empty stacks
	for item in to_remove:
		items.erase(item)
	
	if removed > 0:
		EventBus.inventory_changed.emit()
		EventBus.encumbrance_changed.emit(get_encumbrance_ratio())
	
	return removed

## Check if inventory contains item(s) by ID
func has_item(item_id: String, count: int = 1) -> bool:
	return get_item_count(item_id) >= count

## Get total count of an item by ID
func get_item_count(item_id: String) -> int:
	var total = 0
	for item in items:
		if item.id == item_id:
			total += item.stack_size
	return total

## Get first item matching ID
func get_item_by_id(item_id: String) -> Item:
	for item in items:
		if item.id == item_id:
			return item
	return null

## Check if a specific item instance is in the inventory array (not equipped)
func contains_item(item: Item) -> bool:
	return item in items

## Check if inventory has a tool of specified type (including equipped)
func has_tool(tool_type: String) -> bool:
	# Check inventory
	for item in items:
		if item.is_tool_type(tool_type):
			return true
	
	# Check equipped items
	for slot in equipment:
		var equipped = equipment[slot]
		if equipped and equipped.is_tool_type(tool_type):
			return true
	
	return false

## Get a tool of specified type
func get_tool(tool_type: String) -> Item:
	# Check equipped first
	for slot in equipment:
		var equipped = equipment[slot]
		if equipped and equipped.is_tool_type(tool_type):
			return equipped
	
	# Then check inventory
	for item in items:
		if item.is_tool_type(tool_type):
			return item
	
	return null

## Equip an item
## Returns the previously equipped item (or null)
func equip_item(item: Item) -> Item:
	if not item or not item.is_equippable():
		return null
	
	var slot = item.equip_slot
	
	# Handle accessory slots (use first available)
	if slot == "accessory":
		if equipment["accessory_1"] == null:
			slot = "accessory_1"
		elif equipment["accessory_2"] == null:
			slot = "accessory_2"
		else:
			slot = "accessory_1"  # Replace first
	
	if slot not in equipment:
		push_error("Inventory: Invalid equip slot: %s" % slot)
		return null
	
	# Remove from inventory
	remove_item(item)
	
	# Swap with currently equipped
	var previous = equipment[slot]
	equipment[slot] = item
	
	# Put previous item back in inventory
	if previous:
		add_item(previous)
	
	EventBus.item_equipped.emit(item, slot)
	return previous

## Unequip an item from a slot
## Returns the unequipped item
func unequip_slot(slot: String) -> Item:
	if slot not in equipment:
		return null
	
	var item = equipment[slot]
	if not item:
		return null
	
	equipment[slot] = null
	add_item(item)
	
	EventBus.item_unequipped.emit(item, slot)
	return item

## Get equipped item in a slot
func get_equipped(slot: String) -> Item:
	return equipment.get(slot, null)

## Use an item
## Returns result dictionary with success, consumed, message
func use_item(item: Item) -> Dictionary:
	if not item:
		return {"success": false, "consumed": false, "message": "No item"}
	
	var result = item.use(_owner)
	
	if result.consumed:
		# Reduce stack or remove
		item.remove_from_stack(1)
		if item.is_empty():
			remove_item(item)
		else:
			EventBus.inventory_changed.emit()
	
	EventBus.item_used.emit(item, result)
	return result

## Get total weapon damage bonus from equipped main hand
func get_weapon_damage_bonus() -> int:
	var weapon = equipment.get("main_hand", null)
	return weapon.damage_bonus if weapon else 0

## Get total armor value from all equipped items
func get_total_armor() -> int:
	var total = 0
	for slot in equipment:
		var item = equipment[slot]
		if item:
			total += item.armor_value
	return total

## Get all items as array (for UI display)
func get_all_items() -> Array[Item]:
	return items

## Get number of items (stacks) in inventory
func get_item_slot_count() -> int:
	return items.size()

## Clear all items (for testing or death)
func clear() -> void:
	items.clear()
	for slot in equipment:
		equipment[slot] = null
	EventBus.inventory_changed.emit()

## Get inventory summary for display
func get_summary() -> String:
	var lines: Array[String] = []
	var weight = get_total_weight()
	var ratio = get_encumbrance_ratio()
	
	lines.append("Weight: %.1f/%.1f kg (%d%%)" % [weight, max_weight, int(ratio * 100)])
	
	var penalty = get_encumbrance_penalty()
	if penalty.state != "normal":
		lines.append("Status: %s" % penalty.state.capitalize())
	
	lines.append("")
	lines.append("Items: %d" % items.size())
	
	return "\n".join(lines)

## Serialize inventory for saving
func serialize() -> Dictionary:
	var data: Dictionary = {
		"items": [],
		"equipment": {}
	}
	
	# Serialize inventory items
	for item in items:
		data.items.append(_serialize_item(item))
	
	# Serialize equipped items
	for slot in equipment:
		if equipment[slot]:
			data.equipment[slot] = _serialize_item(equipment[slot])
	
	return data

## Serialize a single item
func _serialize_item(item: Item) -> Dictionary:
	return {
		"id": item.id,
		"stack_size": item.stack_size,
		"durability": item.durability
	}

## Deserialize inventory from save data
func deserialize(data: Dictionary) -> void:
	clear()
	
	# Load inventory items
	if "items" in data:
		for item_data in data.items:
			var item = ItemManager.create_item(item_data.id, item_data.get("stack_size", 1))
			if item:
				item.durability = item_data.get("durability", item.max_durability)
				items.append(item)
	
	# Load equipped items
	if "equipment" in data:
		for slot in data.equipment:
			var item_data = data.equipment[slot]
			var item = ItemManager.create_item(item_data.id, 1)
			if item:
				item.durability = item_data.get("durability", item.max_durability)
				equipment[slot] = item
	
	EventBus.inventory_changed.emit()
	EventBus.encumbrance_changed.emit(get_encumbrance_ratio())
