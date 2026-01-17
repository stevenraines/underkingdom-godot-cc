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
	"neck": null,
	"torso": null,
	"back": null,
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
	"neck": "Neck",
	"torso": "Torso",
	"back": "Back",
	"hands": "Hands",
	"legs": "Legs",
	"feet": "Feet",
	"main_hand": "Main Hand",
	"off_hand": "Off Hand",
	"accessory_1": "Ring",
	"accessory_2": "Ring"
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

## Check if inventory contains any item with a specific flag
func has_item_with_flag(flag_name: String) -> bool:
	for item in items:
		if item.has_flag(flag_name):
			return true
	# Also check equipped items
	for slot in equipment.values():
		if slot and slot.has_flag(flag_name):
			return true
	return false

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

## Equip an item to a specific slot (or auto-select if slot is empty)
## Returns an array of previously equipped items (can be multiple for two-handed)
func equip_item(item: Item, target_slot: String = "") -> Array[Item]:
	var unequipped: Array[Item] = []
	
	if not item or not item.is_equippable():
		return unequipped
	
	var slot = target_slot
	
	# If no target slot specified, pick the first available or first in list
	if slot == "":
		slot = _get_best_slot_for_item(item)
	
	# Handle accessory slots specially
	if slot == "accessory":
		if equipment["accessory_1"] == null:
			slot = "accessory_1"
		elif equipment["accessory_2"] == null:
			slot = "accessory_2"
		else:
			slot = "accessory_1"  # Replace first
	
	# Verify item can equip to this slot
	if not item.can_equip_to_slot(slot):
		push_error("Inventory: Item %s cannot equip to slot %s" % [item.id, slot])
		return unequipped
	
	if slot not in equipment:
		push_error("Inventory: Invalid equip slot: %s" % slot)
		return unequipped
	
	# Check if off_hand is blocked by a two-handed weapon
	if slot == "off_hand" and is_off_hand_blocked():
		push_warning("Inventory: Cannot equip to off_hand - blocked by two-handed weapon")
		return unequipped
	
	# Remove from inventory first
	remove_item(item)
	
	# Handle two-handed weapon - must unequip off_hand first
	if item.is_two_handed() and slot == "main_hand":
		var off_hand_item = equipment["off_hand"]
		if off_hand_item:
			equipment["off_hand"] = null
			add_item(off_hand_item)
			unequipped.append(off_hand_item)
			EventBus.item_unequipped.emit(off_hand_item, "off_hand")
	
	# Swap with currently equipped
	var previous = equipment[slot]
	equipment[slot] = item
	
	# Put previous item back in inventory
	if previous:
		add_item(previous)
		unequipped.append(previous)
	
	EventBus.item_equipped.emit(item, slot)
	return unequipped

## Get the best slot to equip an item to (first empty, or first in list)
func _get_best_slot_for_item(item: Item) -> String:
	var slots = item.get_equip_slots()
	if slots.is_empty():
		return ""
	
	# For accessories, check both slots
	if "accessory" in slots:
		if equipment["accessory_1"] == null:
			return "accessory_1"
		if equipment["accessory_2"] == null:
			return "accessory_2"
		return "accessory_1"
	
	# Check if any slot is empty
	for slot in slots:
		if equipment.get(slot, null) == null:
			return slot
	
	# Return first slot (will replace existing)
	return slots[0]

## Check if the off_hand slot is blocked by a two-handed main_hand weapon
func is_off_hand_blocked() -> bool:
	var main_hand = equipment.get("main_hand", null)
	return main_hand != null and main_hand.is_two_handed()

## Get items that can be equipped to a specific slot
func get_items_for_slot(slot: String) -> Array[Item]:
	var result: Array[Item] = []
	for item in items:
		if item.can_equip_to_slot(slot):
			result.append(item)
	return result

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
		# Check if item transforms into something else (e.g., waterskin_full -> waterskin_empty)
		if item.transforms_into != "":
			var transformed_item = ItemManager.create_item(item.transforms_into, 1)
			if transformed_item:
				add_item(transformed_item)

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

## Get total warmth bonus from all equipped items
## Returns the sum of warmth values (positive = warmer, negative = cooler)
func get_total_warmth() -> float:
	var total: float = 0.0
	for slot in equipment:
		var item = equipment[slot]
		if item:
			total += item.warmth
	return total

## Get light radius from equipped light sources
## Returns 0 if no light source equipped or if the light source is not lit
func get_equipped_light_radius() -> int:
	# Check off-hand first (typical light source slot)
	var off_hand = equipment.get("off_hand", null)
	if off_hand and off_hand.provides_light and _is_light_active(off_hand):
		return off_hand.light_radius

	# Check main hand (torch can be wielded)
	var main_hand = equipment.get("main_hand", null)
	if main_hand and main_hand.provides_light and _is_light_active(main_hand):
		return main_hand.light_radius

	# Check accessory slots for magical light sources
	for slot in ["accessory_1", "accessory_2"]:
		var accessory = equipment.get(slot, null)
		if accessory and accessory.provides_light and _is_light_active(accessory):
			return accessory.light_radius

	return 0

## Check if a light source is actually active
## For items that burn (torches, lanterns), they must be lit
## For magical items, they are always active
func _is_light_active(item: Item) -> bool:
	# Items that burn need to be lit
	if item.burns_per_turn > 0:
		return item.is_lit
	# Magical or non-burning light sources are always active
	return true

## Check if player has a light source equipped
func has_light_source_equipped() -> bool:
	return get_equipped_light_radius() > 0

## Filter types for inventory organization
enum FilterType {
	ALL,           # Show everything (default)
	WEAPONS,       # Swords, axes, bows, etc.
	ARMOR,         # All equippable armor pieces
	TOOLS,         # Knives, hammers, waterskins, etc.
	CONSUMABLES,   # Food, bandages, potions
	MATERIALS,     # Crafting materials, ore, leather
	AMMUNITION,    # Arrows, bolts
	BOOKS,         # Recipe books
	SEEDS,         # Farming seeds
	MISC           # Currency, keys, other items
}

## Get all items as array (for UI display)
func get_all_items() -> Array[Item]:
	return items

## Get items filtered by category and sorted by value
func get_items_by_filter(filter: FilterType) -> Array[Item]:
	var filtered = _filter_items(items, filter)
	return _sort_items(filtered)

## Filter items by category
func _filter_items(item_list: Array[Item], filter: FilterType) -> Array[Item]:
	if filter == FilterType.ALL:
		return item_list.duplicate()

	var result: Array[Item] = []
	for item in item_list:
		if _item_matches_filter(item, filter):
			result.append(item)
	return result

## Check if item matches filter category
func _item_matches_filter(item: Item, filter: FilterType) -> bool:
	match filter:
		FilterType.WEAPONS:
			return item.category == "weapons" or (item.flags.get("weapon", false) and item.equip_slots.size() > 0)
		FilterType.ARMOR:
			return item.category == "armor" or (item.flags.get("equippable", false) and item.armor_value > 0)
		FilterType.TOOLS:
			return item.category == "tools" or item.flags.get("tool", false)
		FilterType.CONSUMABLES:
			return item.category == "consumables" or item.flags.get("consumable", false)
		FilterType.MATERIALS:
			return item.category == "materials" or item.item_type == "material"
		FilterType.AMMUNITION:
			return item.category == "ammunition"
		FilterType.BOOKS:
			return item.category == "books" or item.teaches_recipe != ""
		FilterType.SEEDS:
			return item.category == "seeds"
		FilterType.MISC:
			# Misc includes currency, keys, and anything that doesn't fit other categories
			return item.category == "misc" or item.item_type == "currency" or (
				item.category not in ["weapons", "armor", "tools", "consumables", "materials", "ammunition", "books", "seeds"]
			)
	return false

## Sort items by value (ascending), then name (alphabetical)
func _sort_items(item_list: Array[Item]) -> Array[Item]:
	var sorted = item_list.duplicate()
	sorted.sort_custom(func(a, b):
		if a.value == b.value:
			return a.name < b.name
		return a.value < b.value
	)
	return sorted

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
	var data = {
		"id": item.id,
		"stack_size": item.stack_size,
		"durability": item.durability
	}
	# Save lit state for light sources
	if item.is_lit:
		data["is_lit"] = true
	return data

## Deserialize inventory from save data
func deserialize(data: Dictionary) -> void:
	clear()

	# Load inventory items
	if "items" in data:
		for item_data in data.items:
			var item = ItemManager.create_item(item_data.id, item_data.get("stack_size", 1))
			if item:
				item.durability = item_data.get("durability", item.max_durability)
				item.is_lit = item_data.get("is_lit", false)
				items.append(item)

	# Load equipped items
	if "equipment" in data:
		for slot in data.equipment:
			var item_data = data.equipment[slot]
			var item = ItemManager.create_item(item_data.id, 1)
			if item:
				item.durability = item_data.get("durability", item.max_durability)
				item.is_lit = item_data.get("is_lit", false)
				equipment[slot] = item

	EventBus.inventory_changed.emit()
	EventBus.encumbrance_changed.emit(get_encumbrance_ratio())
