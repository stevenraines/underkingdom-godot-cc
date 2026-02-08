class_name InventorySerializer
extends RefCounted

## InventorySerializer - Handles inventory and equipment serialization
##
## Extracted from SaveManager to separate item/equipment serialization concerns.

const ItemFactoryClass = preload("res://items/item_factory.gd")


## Serialize inventory items to array
static func serialize_inventory(inventory: Inventory) -> Array:
	if not inventory:
		return []

	var items = []
	for item in inventory.items:
		if item is Item:
			# Use Item's serialize method for proper template/variant handling
			items.append(item.serialize())
		else:
			# Legacy fallback for non-Item objects
			var count_val = item.count if "count" in item else 1
			var durability_val = item.get("durability") if typeof(item) == TYPE_DICTIONARY else null
			items.append({
				"id": item.id,
				"stack_size": count_val,
				"durability": durability_val
			})
	return items


## Serialize equipment dictionary
static func serialize_equipment(equipment: Dictionary) -> Dictionary:
	var equipped = {}
	for slot in equipment.keys():
		var item = equipment[slot]
		if item:
			# Use Item's serialize method for proper template/variant handling
			if item is Item:
				equipped[slot] = item.serialize()
			else:
				equipped[slot] = {"id": item.id, "stack_size": 1}
	return equipped


## Deserialize inventory items from array
static func deserialize_inventory(inventory: Inventory, items_data: Array) -> void:
	if not inventory:
		return

	inventory.items.clear()
	for item_data in items_data:
		var item: Item = null

		# Check if this is a templated item (has template_id and variants)
		if item_data.has("template_id") and item_data.has("variants"):
			item = ItemFactoryClass.create_item(
				item_data.template_id,
				item_data.variants,
				item_data.get("stack_size", 1)
			)
		else:
			# Legacy format or non-templated item
			var item_id = item_data.get("id", item_data.get("item_id", ""))
			var count = item_data.get("stack_size", item_data.get("count", 1))
			item = ItemManager.create_item(item_id, count)

		if item:
			# Restore durability if it was saved
			if item_data.has("durability") and item_data.durability != null:
				item.durability = item_data.durability
			# Restore inscription if it was saved
			if item_data.has("inscription") and item_data.inscription != null:
				item.inscription = item_data.inscription
			# Restore lit state for light sources
			if item_data.has("is_lit"):
				item.is_lit = item_data.is_lit
			inventory.items.append(item)


## Deserialize equipment from dictionary
static func deserialize_equipment(inventory: Inventory, equipment_data: Dictionary) -> void:
	if not inventory:
		return

	# Clear current equipment
	for slot in inventory.equipment.keys():
		inventory.equipment[slot] = null

	# Load equipped items
	for slot in equipment_data.keys():
		var item_data = equipment_data[slot]
		var item: Item = null

		# Handle new format (dictionary with possible template_id)
		if item_data is Dictionary:
			if item_data.has("template_id") and item_data.has("variants"):
				item = ItemFactoryClass.create_item(
					item_data.template_id,
					item_data.variants,
					1
				)
			else:
				var item_id = item_data.get("id", "")
				item = ItemManager.create_item(item_id, 1)

			# Restore durability if saved
			if item and item_data.has("durability") and item_data.durability != null:
				item.durability = item_data.durability
			# Restore inscription if saved
			if item and item_data.has("inscription") and item_data.inscription != null:
				item.inscription = item_data.inscription
			# Restore lit state for light sources
			if item and item_data.has("is_lit"):
				item.is_lit = item_data.is_lit
		else:
			# Legacy format: just item_id string
			item = ItemManager.create_item(item_data, 1)

		if item:
			inventory.equipment[slot] = item
