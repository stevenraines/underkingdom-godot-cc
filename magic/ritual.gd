class_name Ritual
extends RefCounted

## Ritual - Data class representing a ritual definition
##
## Rituals are powerful magical workings that require:
## - Components (items consumed during the ritual)
## - Channeling time (multiple turns of uninterrupted concentration)
## - No level requirement (but still requires 8+ INT)

# Core identification
var id: String = ""
var name: String = ""
var description: String = ""

# Classification
var school: String = ""  # Same schools as spells
var rarity: String = "common"  # common, uncommon, rare, very_rare

# Requirements (no level requirement, just INT 8)
var requirements: Dictionary = {
	"intelligence": 8
}

# Components required (list of {item_id, count})
var components: Array = []

# Channeling time in turns
var channeling_turns: int = 10

# Whether the ritual can be interrupted by damage
var interruptible: bool = true

# Targeting information
var targeting: Dictionary = {
	"mode": "self",  # self, tile, inventory
	"range": 0,
	"valid_categories": []  # For inventory targeting
}

# Ritual effects
var effects: Dictionary = {}

# Failure consequences (fizzle, backfire, wild_magic)
var failure_consequences: Dictionary = {
	"lose_components": true,  # Whether components are lost on failure
	"backfire_chance": 0.2,   # Chance of backfire vs fizzle
	"wild_magic_chance": 0.1  # Chance of wild magic
}

# Display properties
var success_message: String = ""
var failure_message: String = ""
var channel_message: String = ""
var ascii_char: String = "+"
var ascii_color: String = "#AA44FF"

## Create a Ritual from a dictionary (typically loaded from JSON)
static func from_dict(data: Dictionary):
	var script = load("res://magic/ritual.gd")
	var ritual = script.new()

	# Core identification
	ritual.id = data.get("id", "")
	ritual.name = data.get("name", ritual.id.capitalize())
	ritual.description = data.get("description", "")

	# Classification
	ritual.school = data.get("school", "transmutation")
	ritual.rarity = data.get("rarity", "common")

	# Requirements
	if data.has("requirements"):
		ritual.requirements = data.requirements.duplicate()

	# Components
	if data.has("components"):
		ritual.components = data.components.duplicate(true)

	# Channeling time
	ritual.channeling_turns = data.get("channeling_turns", 10)

	# Interruptible
	ritual.interruptible = data.get("interruptible", true)

	# Targeting
	if data.has("targeting"):
		ritual.targeting = data.targeting.duplicate(true)

	# Effects
	if data.has("effects"):
		ritual.effects = data.effects.duplicate(true)

	# Failure consequences
	if data.has("failure_consequences"):
		ritual.failure_consequences = data.failure_consequences.duplicate()

	# Display
	ritual.success_message = data.get("success_message", "The ritual is complete!")
	ritual.failure_message = data.get("failure_message", "The ritual fails!")
	ritual.channel_message = data.get("channel_message", "You continue channeling the ritual...")
	ritual.ascii_char = data.get("ascii_char", "+")
	ritual.ascii_color = data.get("ascii_color", "#AA44FF")

	return ritual

## Get the minimum INT required
func get_min_intelligence() -> int:
	return requirements.get("intelligence", 8)

## Get the targeting mode
func get_targeting_mode() -> String:
	return targeting.get("mode", "self")

## Check if an entity has the required components
func has_components(inventory) -> Dictionary:
	if not inventory:
		return {has_all = false, missing = components}

	var missing: Array = []
	for component in components:
		var item_id = component.get("item_id", "")
		var count = component.get("count", 1)
		if not inventory.has_item(item_id, count):
			missing.append(component)

	return {has_all = missing.is_empty(), missing = missing}

## Consume the required components from inventory
func consume_components(inventory) -> bool:
	if not inventory:
		return false

	for component in components:
		var item_id = component.get("item_id", "")
		var count = component.get("count", 1)
		if not inventory.remove_item(item_id, count):
			return false

	return true

## Get display color as Color object
func get_color() -> Color:
	return Color.from_string(ascii_color, Color.WHITE)

## Get a formatted list of components for display
func get_component_list() -> Array[String]:
	var result: Array[String] = []
	for component in components:
		var item_id = component.get("item_id", "")
		var count = component.get("count", 1)
		var item = ItemManager.get_item_data(item_id)
		var item_name = item.get("name", item_id) if item else item_id
		if count > 1:
			result.append("%s x%d" % [item_name, count])
		else:
			result.append(item_name)
	return result

## Convert to dictionary (for serialization)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"school": school,
		"rarity": rarity,
		"requirements": requirements.duplicate(),
		"components": components.duplicate(true),
		"channeling_turns": channeling_turns,
		"interruptible": interruptible,
		"targeting": targeting.duplicate(true),
		"effects": effects.duplicate(true),
		"failure_consequences": failure_consequences.duplicate(),
		"success_message": success_message,
		"failure_message": failure_message,
		"channel_message": channel_message,
		"ascii_char": ascii_char,
		"ascii_color": ascii_color
	}
