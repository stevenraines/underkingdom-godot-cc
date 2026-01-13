class_name Ritual
extends RefCounted

## Ritual - Data structure for ritual definitions
##
## Rituals are multi-step magical workings that require components,
## time to channel, and may have special requirements (altar, night, etc.).

var id: String = ""
var name: String = ""
var description: String = ""
var school: String = "transmutation"
var components: Array = []  # [{item_id, quantity}]
var channeling_turns: int = 5
var effects: Dictionary = {}
var requirements: Dictionary = {}
var failure_effects: Dictionary = {}
var discovery_location: String = ""  # Where ritual can be found/learned


func _init(data: Dictionary = {}) -> void:
	id = data.get("id", "")
	name = data.get("name", "Unknown Ritual")
	description = data.get("description", "")
	school = data.get("school", "transmutation")
	components = data.get("components", [])
	channeling_turns = data.get("channeling_turns", 5)
	effects = data.get("effects", {})
	requirements = data.get("requirements", {})
	failure_effects = data.get("failure_effects", {})
	discovery_location = data.get("discovery_location", "")


## Get a formatted string listing all components
func get_component_list() -> String:
	var parts: Array[String] = []
	for comp in components:
		var item_name = comp.get("item_id", "unknown")
		# Try to get proper item name from ItemManager
		var item_data = ItemManager.get_item_data(item_name)
		if item_data:
			item_name = item_data.get("name", item_name)
		parts.append("%dx %s" % [comp.get("quantity", 1), item_name])
	return ", ".join(parts)


## Get the minimum INT required
func get_min_intelligence() -> int:
	return requirements.get("intelligence", 8)


## Check if ritual requires altar
func requires_altar() -> bool:
	return requirements.get("near_altar", false)


## Check if ritual requires night
func requires_night() -> bool:
	return requirements.get("night_only", false)


## Get the school color for display
func get_school_color() -> Color:
	match school:
		"evocation": return Color.ORANGE_RED
		"conjuration": return Color.CYAN
		"enchantment": return Color.GOLD
		"transmutation": return Color.GREEN
		"divination": return Color.LIGHT_BLUE
		"necromancy": return Color.PURPLE
		"abjuration": return Color.WHITE
		"illusion": return Color.VIOLET
		_: return Color.GRAY


## Serialize ritual reference for saving
func serialize() -> Dictionary:
	return {"id": id}
