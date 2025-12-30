class_name Item
extends RefCounted

## Item - Base class for all items in the game
##
## Items can be consumables, materials, tools, weapons, or armor.
## They exist in inventories or as ground items in the world.
## Items use a flags system to indicate multiple properties.

# Core identification
var id: String = ""                 # Unique identifier (e.g., "iron_knife")
var name: String = ""               # Display name
var description: String = ""        # Item description

# Classification
var item_type: String = ""          # Legacy: "consumable", "material", "tool", "weapon", "armor", "currency"
var category: String = ""           # Folder category (weapon, armor, tool, consumable, material, misc)
var subtype: String = ""            # Further classification (e.g., "knife", "chest_armor")

# Flags - flexible boolean properties
var flags: Dictionary = {}          # {"equippable": true, "consumable": false, "tool": true, etc.}

# Physical properties
var weight: float = 0.0             # Weight in kg
var value: int = 0                  # Base gold value

# Stacking
var stack_size: int = 1             # Current stack count
var max_stack: int = 1              # Maximum stack size

# Display
var ascii_char: String = "?"        # ASCII display character
var ascii_color: String = "#FFFFFF" # Hex color for rendering

# Durability (for tools/weapons/armor)
var durability: int = -1            # -1 = no durability
var max_durability: int = -1        # -1 = no durability

# Equipment properties
var equip_slot: String = ""         # Legacy: single slot (for backwards compatibility)
var equip_slots: Array[String] = [] # Which slots this can equip to (e.g., ["main_hand", "off_hand"])
var armor_value: int = 0            # Damage reduction when equipped
var damage_bonus: int = 0           # Added to base damage when equipped

# Tool properties
var tool_type: String = ""          # "knife", "hammer", etc. for crafting requirements

# Consumable effects
var effects: Dictionary = {}        # {"hunger": 30, "thirst": 20, "health": 10}

# Transform on use (e.g., full waterskin -> empty waterskin)
var transforms_into: String = ""    # Item ID to transform into after use

## Create an item from a data dictionary (loaded from JSON)
static func create_from_data(data: Dictionary) -> Item:
	var item = Item.new()
	
	# Core properties
	item.id = data.get("id", "unknown")
	item.name = data.get("name", "Unknown Item")
	item.description = data.get("description", "")
	
	# Classification
	item.item_type = data.get("item_type", "material")
	item.category = data.get("category", "")
	item.subtype = data.get("subtype", "")
	
	# Flags
	item.flags = data.get("flags", {})
	
	# Physical
	item.weight = data.get("weight", 0.0)
	item.value = data.get("value", 0)
	
	# Stacking
	item.max_stack = data.get("max_stack", 1)
	item.stack_size = 1
	
	# Display
	item.ascii_char = data.get("ascii_char", "?")
	item.ascii_color = data.get("ascii_color", "#FFFFFF")
	
	# Durability
	item.max_durability = data.get("durability", -1)
	item.durability = item.max_durability
	
	# Equipment - support both new equip_slots array and legacy equip_slot
	var slots_data = data.get("equip_slots", [])
	if slots_data is Array:
		for slot in slots_data:
			item.equip_slots.append(str(slot))
	
	# Legacy support: if equip_slot exists but equip_slots is empty, use it
	var legacy_slot = data.get("equip_slot", "")
	if legacy_slot != "" and item.equip_slots.is_empty():
		item.equip_slots.append(legacy_slot)
	
	# Set equip_slot to first slot for backwards compatibility
	if not item.equip_slots.is_empty():
		item.equip_slot = item.equip_slots[0]
	
	item.armor_value = data.get("armor_value", 0)
	item.damage_bonus = data.get("damage_bonus", 0)
	
	# Tool
	item.tool_type = data.get("tool_type", "")
	
	# Consumable effects
	item.effects = data.get("effects", {})
	
	# Transform on use
	item.transforms_into = data.get("transforms_into", "")
	
	return item

## Create a copy of this item
func duplicate_item() -> Item:
	var copy = Item.new()
	copy.id = id
	copy.name = name
	copy.description = description
	copy.item_type = item_type
	copy.category = category
	copy.subtype = subtype
	copy.flags = flags.duplicate()
	copy.weight = weight
	copy.value = value
	copy.stack_size = stack_size
	copy.max_stack = max_stack
	copy.ascii_char = ascii_char
	copy.ascii_color = ascii_color
	copy.durability = durability
	copy.max_durability = max_durability
	copy.equip_slot = equip_slot
	copy.equip_slots = equip_slots.duplicate()
	copy.armor_value = armor_value
	copy.damage_bonus = damage_bonus
	copy.tool_type = tool_type
	copy.effects = effects.duplicate()
	copy.transforms_into = transforms_into
	return copy

## Use this item on an entity
## Returns true if the item should be consumed (removed from inventory)
func use(user: Entity) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"consumed": false,
		"message": ""
	}
	
	match item_type:
		"consumable":
			result = _use_consumable(user)
		"tool":
			# Tools are generally not "used" directly
			# Waterskin is special case
			if id == "waterskin_full":
				result = _use_consumable(user)
			else:
				result.message = "You can't use that directly."
		_:
			result.message = "You can't use that."
	
	return result

## Apply consumable effects to user
func _use_consumable(user: Entity) -> Dictionary:
	var result = {
		"success": true,
		"consumed": true,
		"message": "You use the %s." % name
	}
	
	# Apply effects
	if user.has_method("apply_item_effects"):
		user.apply_item_effects(effects)
	else:
		# Fallback for direct effect application
		if "hunger" in effects and user.get("survival"):
			user.survival.eat(effects.hunger)
			result.message = "You eat the %s." % name
		if "thirst" in effects and user.get("survival"):
			user.survival.drink(effects.thirst)
			result.message = "You drink from the %s." % name
		if "health" in effects:
			user.heal(effects.health)
			result.message = "You use the %s and feel better." % name
	
	return result

## Check if this item can stack with another item
func can_stack_with(other: Item) -> bool:
	if not other:
		return false
	if id != other.id:
		return false
	if max_stack <= 1:
		return false
	if stack_size >= max_stack:
		return false
	return true

## Add to this item's stack
## Returns the leftover amount that couldn't be added
func add_to_stack(amount: int) -> int:
	var space = max_stack - stack_size
	var to_add = min(amount, space)
	stack_size += to_add
	return amount - to_add

## Remove from this item's stack
## Returns the amount actually removed
func remove_from_stack(amount: int) -> int:
	var to_remove = min(amount, stack_size)
	stack_size -= to_remove
	return to_remove

## Get the total weight of this item stack
func get_total_weight() -> float:
	return weight * stack_size

## Check if this item can be equipped (uses flags or equip_slots)
func is_equippable() -> bool:
	# Check flag first, then fall back to equip_slots
	if flags.get("equippable", false):
		return true
	return not equip_slots.is_empty()

## Check if this item can be equipped to a specific slot
func can_equip_to_slot(slot: String) -> bool:
	if not is_equippable():
		return false
	# Handle accessory slots specially - both accessory_1 and accessory_2 match "accessory"
	if slot in ["accessory_1", "accessory_2"]:
		return "accessory" in equip_slots
	return slot in equip_slots

## Get all slots this item can be equipped to
func get_equip_slots() -> Array[String]:
	return equip_slots

## Check if this item requires two hands
func is_two_handed() -> bool:
	return flags.get("two_handed", false)

## Check if this item is consumable
func is_consumable() -> bool:
	if flags.get("consumable", false):
		return true
	return item_type == "consumable"

## Check if this item is a tool
func is_tool() -> bool:
	if flags.get("tool", false):
		return true
	return item_type == "tool" or tool_type != ""

## Check if this item is a crafting material
func is_crafting_material() -> bool:
	return flags.get("crafting_material", false) or item_type == "material"

## Check if this item has a specific flag
func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

## Get all flags for this item
func get_flags() -> Dictionary:
	return flags

## Check if this item is a tool of the specified type
func is_tool_type(required_type: String) -> bool:
	return tool_type == required_type

## Reduce durability by 1
## Returns true if item broke
func use_durability() -> bool:
	if durability <= 0 and max_durability > 0:
		return true  # Already broken
	
	if durability > 0:
		durability -= 1
		if durability <= 0:
			return true  # Just broke
	
	return false

## Get durability as a percentage (0-100)
func get_durability_percent() -> int:
	if max_durability <= 0:
		return 100  # No durability = always full
	return int((float(durability) / float(max_durability)) * 100.0)

## Get tooltip text for this item
func get_tooltip() -> String:
	var lines: Array[String] = []
	
	lines.append(name)
	
	if description != "":
		lines.append(description)
	
	lines.append("")
	lines.append("Type: %s" % item_type.capitalize())
	lines.append("Weight: %.2f kg" % weight)
	
	if value > 0:
		lines.append("Value: %d gold" % value)
	
	if stack_size > 1:
		lines.append("Stack: %d/%d" % [stack_size, max_stack])
	
	if equip_slot != "":
		lines.append("Equips to: %s" % equip_slot.replace("_", " ").capitalize())
		if damage_bonus > 0:
			lines.append("Damage: +%d" % damage_bonus)
		if armor_value > 0:
			lines.append("Armor: %d" % armor_value)
	
	if tool_type != "":
		lines.append("Tool type: %s" % tool_type.capitalize())
	
	if durability > 0:
		lines.append("Durability: %d/%d" % [durability, max_durability])
	
	if effects.size() > 0:
		lines.append("")
		lines.append("Effects:")
		for effect_name in effects:
			var effect_value = effects[effect_name]
			var sign_str = "+" if effect_value > 0 else ""
			lines.append("  %s: %s%d" % [effect_name.capitalize(), sign_str, effect_value])
	
	return "\n".join(lines)

## Get display color as Color object
func get_color() -> Color:
	return Color.from_string(ascii_color, Color.WHITE)

## Check if item stack is empty
func is_empty() -> bool:
	return stack_size <= 0
