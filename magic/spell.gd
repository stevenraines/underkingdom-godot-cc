class_name Spell
extends RefCounted

## Spell - Data class representing a spell definition
##
## Holds all data for a single spell loaded from JSON.
## Used by SpellManager to look up spell properties and by
## the casting system to execute spell effects.

# Core identification
var id: String = ""
var name: String = ""
var description: String = ""

# Classification
var school: String = ""  # evocation, conjuration, enchantment, transmutation, divination, necromancy, abjuration, illusion
var level: int = 1  # Spell level 0-10 (0 = cantrip)

# Resource costs
var mana_cost: int = 0

# Requirements to cast
var requirements: Dictionary = {
	"character_level": 1,
	"intelligence": 8
}

# Targeting information
var targeting: Dictionary = {
	"mode": "self",  # self, touch, ranged, cone, line, aoe
	"range": 0,
	"aoe_radius": 0,
	"requires_los": true
}

# Spell effects (damage, healing, buffs, summons, etc.)
var effects: Dictionary = {}

# Saving throw information
var save: Dictionary = {
	"type": "",  # none, dodge, fortitude, will
	"on_success": "half"  # half, none, negates
}

# Concentration requirement
var concentration: bool = false

# Duration information
var duration: Dictionary = {
	"type": "instant",  # instant, turns, permanent
	"base": 0,
	"scaling": 0  # Additional duration per caster level
}

# Scaling with caster level
var scaling: Dictionary = {}

# Display properties
var cast_message: String = ""
var ascii_char: String = "*"
var ascii_color: String = "#FFFFFF"

## Create a Spell from a dictionary (typically loaded from JSON)
static func from_dict(data: Dictionary):
	var script = load("res://magic/spell.gd")
	var spell = script.new()

	# Core identification
	spell.id = data.get("id", "")
	spell.name = data.get("name", spell.id.capitalize())
	spell.description = data.get("description", "")

	# Classification
	spell.school = data.get("school", "evocation")
	spell.level = data.get("level", 1)

	# Resource costs
	spell.mana_cost = data.get("mana_cost", 5)

	# Requirements
	if data.has("requirements"):
		spell.requirements = data.requirements.duplicate()

	# Targeting
	if data.has("targeting"):
		spell.targeting = data.targeting.duplicate()

	# Effects
	if data.has("effects"):
		spell.effects = data.effects.duplicate(true)  # Deep copy

	# Save
	if data.has("save"):
		spell.save = data.save.duplicate()

	# Concentration
	spell.concentration = data.get("concentration", false)

	# Duration
	if data.has("duration"):
		spell.duration = data.duration.duplicate()

	# Scaling
	if data.has("scaling"):
		spell.scaling = data.scaling.duplicate()

	# Display
	spell.cast_message = data.get("cast_message", "You cast %s!" % spell.name)
	spell.ascii_char = data.get("ascii_char", "*")
	spell.ascii_color = data.get("ascii_color", "#FFFFFF")

	return spell

## Check if this spell is a cantrip (level 0)
func is_cantrip() -> bool:
	return level == 0

## Get the effective mana cost (cantrips may cost 0)
func get_mana_cost() -> int:
	return mana_cost

## Get the minimum INT required to cast this spell
func get_min_intelligence() -> int:
	return requirements.get("intelligence", 8)

## Get the minimum character level required
func get_min_level() -> int:
	return requirements.get("character_level", 1)

## Get the targeting mode
func get_targeting_mode() -> String:
	return targeting.get("mode", "self")

## Get the spell range (0 for self/touch)
func get_range() -> int:
	return targeting.get("range", 0)

## Check if spell requires line of sight
func requires_los() -> bool:
	return targeting.get("requires_los", true)

## Get damage info if this is a damage spell
func get_damage() -> Dictionary:
	return effects.get("damage", {})

## Get buff info if this is a buff spell
func get_buff() -> Dictionary:
	return effects.get("buff", {})

## Get heal info if this is a healing spell
func get_heal() -> Dictionary:
	return effects.get("heal", {})

## Check if this spell deals damage
func is_damage_spell() -> bool:
	return effects.has("damage")

## Check if this spell provides a buff
func is_buff_spell() -> bool:
	return effects.has("buff")

## Check if this spell heals
func is_heal_spell() -> bool:
	return effects.has("heal")

## Check if this spell summons creatures
func is_summon_spell() -> bool:
	return effects.has("summon")

## Get display color as Color object
func get_color() -> Color:
	return Color.from_string(ascii_color, Color.WHITE)

## Convert to dictionary (for serialization)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"description": description,
		"school": school,
		"level": level,
		"mana_cost": mana_cost,
		"requirements": requirements.duplicate(),
		"targeting": targeting.duplicate(),
		"effects": effects.duplicate(true),
		"save": save.duplicate(),
		"concentration": concentration,
		"duration": duration.duplicate(),
		"scaling": scaling.duplicate(),
		"cast_message": cast_message,
		"ascii_char": ascii_char,
		"ascii_color": ascii_color
	}
