extends Node
class_name ClassManagerClass
## Manages class definitions for player character creation
##
## Classes are loaded from JSON files in data/classes/
## Provides class definitions including stat modifiers, skill bonuses, feats, and restrictions.
##
## Each class has:
## - stat_modifiers: Bonuses/penalties to base attributes
## - skill_bonuses: Starting skill level bonuses
## - feats: Passive and active feats unique to the class
## - restrictions: Equipment and spell casting restrictions

const CLASS_DATA_PATH = "res://data/classes"

## Class definitions loaded from JSON
## Key: class_id (e.g., "warrior"), Value: full definition dictionary
var class_definitions: Dictionary = {}

## Default class if none selected (adventurer has no restrictions)
const DEFAULT_CLASS = "adventurer"


func _ready() -> void:
	_load_class_definitions()
	print("[ClassManager] Initialized with %d class definitions" % class_definitions.size())


## Load all class definitions from JSON files
func _load_class_definitions() -> void:
	var dir = DirAccess.open(CLASS_DATA_PATH)
	if not dir:
		push_warning("[ClassManager] No class data directory found: " + CLASS_DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = CLASS_DATA_PATH + "/" + file_name
			_load_class_file(file_path)
		file_name = dir.get_next()

	dir.list_dir_end()


## Load a single class definition from JSON
func _load_class_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[ClassManager] Failed to open file: " + file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("[ClassManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	if not data.has("id"):
		push_error("[ClassManager] Missing 'id' field in: " + file_path)
		return

	class_definitions[data.id] = data


## Get a class definition by ID
## Returns empty dictionary if not found
## Note: Named get_class_def() to avoid conflict with Godot's built-in Object.get_class()
func get_class_def(class_id: String) -> Dictionary:
	return class_definitions.get(class_id, {})


## Get all class IDs
func get_all_class_ids() -> Array[String]:
	var result: Array[String] = []
	for class_id in class_definitions:
		result.append(class_id)
	return result


## Get all classes sorted by name for display
func get_all_classes_sorted() -> Array[Dictionary]:
	var classes: Array[Dictionary] = []
	for class_id in class_definitions:
		classes.append(class_definitions[class_id])
	classes.sort_custom(func(a, b): return a.name < b.name)
	return classes


## Get stat modifiers for a class
## Returns dictionary of {stat_name: modifier_value}
func get_stat_modifiers(class_id: String) -> Dictionary:
	var cls = get_class_def(class_id)
	return cls.get("stat_modifiers", {})


## Get skill bonuses for a class
## Returns dictionary of {skill_id: bonus_value}
func get_skill_bonuses(class_id: String) -> Dictionary:
	var cls = get_class_def(class_id)
	return cls.get("skill_bonuses", {})


## Get feats for a class
## Returns array of feat dictionaries
func get_feats(class_id: String) -> Array:
	var cls = get_class_def(class_id)
	return cls.get("feats", [])


## Get a specific feat by ID from a class
func get_feat(class_id: String, feat_id: String) -> Dictionary:
	var feats = get_feats(class_id)
	for feat in feats:
		if feat.get("id", "") == feat_id:
			return feat
	return {}


## Check if a class has a specific feat
func has_feat(class_id: String, feat_id: String) -> bool:
	return not get_feat(class_id, feat_id).is_empty()


## Get restrictions for a class
## Returns dictionary with restriction rules
func get_restrictions(class_id: String) -> Dictionary:
	var cls = get_class_def(class_id)
	return cls.get("restrictions", {})


## Get starting equipment for a class
## Returns array of {item_id, count} dictionaries
func get_starting_equipment(class_id: String) -> Array:
	var cls = get_class_def(class_id)
	return cls.get("starting_equipment", [])


## Get display name for a class
func get_class_name(class_id: String) -> String:
	var cls = get_class_def(class_id)
	return cls.get("name", class_id.capitalize())


## Get description for a class
func get_class_description(class_id: String) -> String:
	var cls = get_class_def(class_id)
	return cls.get("description", "")


## Get ASCII color for a class (for UI display)
func get_class_color(class_id: String) -> String:
	var cls = get_class_def(class_id)
	return cls.get("ascii_color", "#FFFFFF")


## Format stat modifiers as display string
## e.g., "+2 INT, -1 CON, -1 STR"
func format_stat_modifiers(class_id: String) -> String:
	var modifiers = get_stat_modifiers(class_id)
	var parts: Array[String] = []

	for stat in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		var mod = modifiers.get(stat, 0)
		if mod != 0:
			var sign = "+" if mod > 0 else ""
			parts.append("%s%d %s" % [sign, mod, stat])

	if parts.is_empty():
		return "No modifiers"
	return ", ".join(parts)


## Format skill bonuses as display string
## e.g., "+2 Swords, +1 Axes"
func format_skill_bonuses(class_id: String) -> String:
	var bonuses = get_skill_bonuses(class_id)
	var parts: Array[String] = []

	for skill in bonuses:
		var bonus = bonuses[skill]
		if bonus != 0:
			var sign = "+" if bonus > 0 else ""
			parts.append("%s%d %s" % [sign, bonus, skill.capitalize()])

	if parts.is_empty():
		return "No skill bonuses"
	return ", ".join(parts)


## Format feats as display string (names only)
func format_feats(class_id: String) -> String:
	var feats = get_feats(class_id)
	if feats.is_empty():
		return "None"

	var names: Array[String] = []
	for feat in feats:
		names.append(feat.get("name", "Unknown"))
	return ", ".join(names)


## Get feat effect for a specific effect type
## Returns the effect value or null if not found
func get_feat_effect(class_id: String, feat_id: String, effect_key: String):
	var feat = get_feat(class_id, feat_id)
	if feat.is_empty():
		return null
	var effect = feat.get("effect", {})
	return effect.get(effect_key, null)


## Check if feat is active type (has limited uses)
func is_feat_active(class_id: String, feat_id: String) -> bool:
	var feat = get_feat(class_id, feat_id)
	return feat.get("type", "passive") == "active"


## Get uses per day for an active feat
func get_feat_uses_per_day(class_id: String, feat_id: String) -> int:
	var feat = get_feat(class_id, feat_id)
	return feat.get("uses_per_day", 0)


# =============================================================================
# CLASS RESTRICTION SYSTEM
# =============================================================================

## Check if class can equip an item
## Returns {"allowed": bool, "reason": String (if not allowed)}
func can_equip_item(class_id: String, item) -> Dictionary:
	var restrictions = get_restrictions(class_id)
	if restrictions.is_empty():
		return {"allowed": true}

	# Check armor material restrictions
	if item.item_type == "armor":
		var material = item.get("material") if item.has_method("get") else item.material if "material" in item else ""
		if restrictions.has("forbidden_armor_materials"):
			if material in restrictions.forbidden_armor_materials:
				return {"allowed": false, "reason": "Your class cannot wear %s armor" % material}

		var weight_class = item.get("weight_class") if item.has_method("get") else item.weight_class if "weight_class" in item else "light"
		if restrictions.has("forbidden_armor_weights"):
			if weight_class in restrictions.forbidden_armor_weights:
				return {"allowed": false, "reason": "Your class cannot wear %s armor" % weight_class}

	# Check weapon restrictions
	if item.item_type == "weapon":
		var weapon_type = item.get("weapon_type") if item.has_method("get") else item.weapon_type if "weapon_type" in item else ""
		if restrictions.has("forbidden_weapon_types"):
			if weapon_type in restrictions.forbidden_weapon_types:
				return {"allowed": false, "reason": "Your class cannot use %s" % item.name}

	return {"allowed": true}


## Get spell failure chance based on current equipment
## Returns {"chance": int (0-100), "message": String (if failing)}
func get_spell_failure_chance(class_id: String, equipped_items: Dictionary) -> Dictionary:
	var restrictions = get_restrictions(class_id)
	if not restrictions.has("spell_failure"):
		return {"chance": 0}

	var spell_failure = restrictions.spell_failure
	for condition in spell_failure.get("conditions", []):
		var check_type = condition.get("check", "")
		var values = condition.get("values", [])

		# Always fail check (for Barbarian)
		if check_type == "always":
			return {
				"chance": condition.get("failure_chance", 100),
				"message": condition.get("message", "Your class cannot cast spells!")
			}

		# Armor material check
		if check_type == "armor_material":
			for slot in ["torso", "head", "hands", "legs", "feet"]:
				var item = equipped_items.get(slot)
				if item:
					var material = ""
					if item.has_method("get"):
						material = item.get("material", "")
					elif "material" in item:
						material = item.material
					if material in values:
						return {
							"chance": condition.get("failure_chance", 0),
							"message": condition.get("message", "Equipment interferes with spellcasting")
						}

		# Armor weight check
		elif check_type == "armor_weight":
			for slot in ["torso", "head", "hands", "legs", "feet"]:
				var item = equipped_items.get(slot)
				if item:
					var weight_class = ""
					if item.has_method("get"):
						weight_class = item.get("weight_class", "")
					elif "weight_class" in item:
						weight_class = item.weight_class
					if weight_class in values:
						return {
							"chance": condition.get("failure_chance", 0),
							"message": condition.get("message", "Armor interferes with spellcasting")
						}

	return {"chance": 0}


## Check if class has any restrictions
func has_restrictions(class_id: String) -> bool:
	var restrictions = get_restrictions(class_id)
	return not restrictions.is_empty()


## Format restrictions as display string for UI
func format_restrictions(class_id: String) -> String:
	var restrictions = get_restrictions(class_id)
	if restrictions.is_empty():
		return "No restrictions"

	var parts: Array[String] = []

	if restrictions.has("forbidden_armor_materials"):
		parts.append("Cannot wear: %s armor" % ", ".join(restrictions.forbidden_armor_materials))

	if restrictions.has("forbidden_armor_weights"):
		parts.append("Cannot wear: %s armor" % ", ".join(restrictions.forbidden_armor_weights))

	if restrictions.has("forbidden_weapon_types"):
		parts.append("Cannot use: %s" % ", ".join(restrictions.forbidden_weapon_types))

	if restrictions.has("spell_failure"):
		var conditions = restrictions.spell_failure.get("conditions", [])
		for cond in conditions:
			if cond.get("check") == "always":
				parts.append("Cannot cast spells")
			elif cond.get("failure_chance", 0) > 0:
				parts.append("%d%% spell failure in certain armor" % cond.get("failure_chance", 0))

	if parts.is_empty():
		return "No restrictions"
	return "; ".join(parts)
