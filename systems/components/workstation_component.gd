class_name WorkstationComponent
extends RefCounted

## WorkstationComponent - Provides workstation functionality for crafting
##
## Attached to structures like forges and anvils to enable specialized crafting.
## Workstations may require specific tools to use.

# Workstation properties
var workstation_type: String = ""  # "forge", "anvil", etc.
var required_tool: String = ""     # Tool type required to use this workstation (e.g., "tongs", "hammer")
var tool_durability_cost: int = 1  # How much tool durability is consumed per craft

## Check if this workstation can be used (player has required tool)
func can_use(inventory: Inventory) -> bool:
	if required_tool == "":
		return true
	return inventory.has_tool(required_tool)

## Get the tool requirement message (for UI)
func get_tool_requirement_message() -> String:
	if required_tool == "":
		return ""
	return "You need %s to use this workstation." % required_tool

## Consume tool durability when crafting
## Returns true if tool was found and durability consumed, false otherwise
func consume_tool_durability(inventory: Inventory) -> bool:
	if required_tool == "":
		return true  # No tool required

	# Find the tool in inventory and reduce its durability
	for item in inventory.items:
		if item.tool_type == required_tool:
			if "durability" in item and item.durability > 0:
				item.durability -= tool_durability_cost
				# Check if tool broke
				if item.durability <= 0:
					EventBus.message_log.emit("Your %s broke!" % item.name)
					inventory.remove_item(item)
				return true
			elif "durability" not in item or item.durability == -1:
				# Tool has infinite durability
				return true
	return false
