extends Node
class_name CreatureTypeManagerClass
## Manages creature type definitions and type-level resistances
##
## Creature types are loaded from JSON files in data/creature_types/
## Provides type-level and subtype-level resistances that can be overridden
## by per-creature definitions in enemy JSON files.
##
## Resistance precedence (highest to lowest):
## 1. Per-creature elemental_resistances in enemy JSON
## 2. Subtype resistances (e.g., fire elemental fire immunity)
## 3. Type-level base_resistances (e.g., undead poison immunity)

const CREATURE_TYPE_DATA_PATH = "res://data/creature_types"

## Creature type definitions loaded from JSON
## Key: creature_type_id (e.g., "undead"), Value: full definition dictionary
var creature_type_definitions: Dictionary = {}


func _ready() -> void:
	_load_creature_type_definitions()
	print("[CreatureTypeManager] Initialized with %d creature type definitions" % creature_type_definitions.size())


## Load all creature type definitions from JSON files
func _load_creature_type_definitions() -> void:
	var dir = DirAccess.open(CREATURE_TYPE_DATA_PATH)
	if not dir:
		push_warning("[CreatureTypeManager] No creature type data directory found: " + CREATURE_TYPE_DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = CREATURE_TYPE_DATA_PATH + "/" + file_name
			_load_creature_type_file(file_path)
		file_name = dir.get_next()

	dir.list_dir_end()


## Load a single creature type definition from JSON
func _load_creature_type_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[CreatureTypeManager] Failed to open file: " + file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("[CreatureTypeManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	if not data.has("id"):
		push_error("[CreatureTypeManager] Missing 'id' field in: " + file_path)
		return

	creature_type_definitions[data.id] = data


## Get a creature type definition by ID
## Returns empty dictionary if not found
func get_creature_type(creature_type_id: String) -> Dictionary:
	return creature_type_definitions.get(creature_type_id, {})


## Get all creature type IDs
func get_all_creature_type_ids() -> Array[String]:
	var result: Array[String] = []
	for type_id in creature_type_definitions:
		result.append(type_id)
	return result


## Calculate merged resistances for a creature
## Applies resistances in order: type base -> subtype -> per-creature
## Higher priority values override lower priority values for the same element
##
## Parameters:
##   creature_type: Base type (e.g., "elemental", "undead")
##   element_subtype: Optional subtype (e.g., "fire", "ice")
##   creature_resistances: Per-creature overrides from enemy JSON
##
## Returns: Dictionary of merged resistances {element: value}
func get_merged_resistances(creature_type: String, element_subtype: String = "", creature_resistances: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}

	# Layer 1: Type-level base resistances (lowest priority)
	var type_def = get_creature_type(creature_type)
	if not type_def.is_empty():
		var base_res = type_def.get("base_resistances", {})
		for element in base_res:
			result[element] = base_res[element]

	# Layer 2: Subtype resistances (medium priority)
	if element_subtype != "" and not type_def.is_empty():
		var subtypes = type_def.get("subtypes", {})
		if subtypes.has(element_subtype):
			var subtype_res = subtypes[element_subtype].get("resistances", {})
			for element in subtype_res:
				result[element] = subtype_res[element]

	# Layer 3: Per-creature resistances (highest priority)
	for element in creature_resistances:
		result[element] = creature_resistances[element]

	return result


## Check if a creature type has a special rule
## Special rules include: heals_from_necrotic, vulnerable_to_radiant, immune_to_poison, etc.
func has_special_rule(creature_type: String, rule_name: String) -> bool:
	var type_def = get_creature_type(creature_type)
	if type_def.is_empty():
		return false
	var rules = type_def.get("special_rules", {})
	return rules.get(rule_name, false)


## Get a special rule value (for rules with numeric values like radiant_vulnerability_bonus)
func get_special_rule_value(creature_type: String, rule_name: String, default_value = null):
	var type_def = get_creature_type(creature_type)
	if type_def.is_empty():
		return default_value
	return type_def.get(rule_name, default_value)


## Get default loot tables for a creature type
## Returns array of loot table IDs that all creatures of this type inherit
func get_default_loot_tables(creature_type: String) -> Array[String]:
	var result: Array[String] = []
	var type_def = get_creature_type(creature_type)
	if type_def.is_empty():
		return result
	var default_tables = type_def.get("default_loot_tables", [])
	for table_id in default_tables:
		result.append(table_id)
	return result


## Get display name for a creature type
func get_type_display_name(creature_type: String) -> String:
	var type_def = get_creature_type(creature_type)
	return type_def.get("name", creature_type.capitalize())


## Get display name for a subtype
func get_subtype_display_name(creature_type: String, element_subtype: String) -> String:
	var type_def = get_creature_type(creature_type)
	if type_def.is_empty():
		return element_subtype.capitalize()
	var subtypes = type_def.get("subtypes", {})
	if subtypes.has(element_subtype):
		return subtypes[element_subtype].get("name", element_subtype.capitalize())
	return element_subtype.capitalize()


## Get abbreviated creature type for display (3-4 chars)
func get_type_abbreviation(creature_type: String) -> String:
	match creature_type:
		"humanoid": return "HUM"
		"undead": return "UND"
		"elemental": return "ELE"
		"construct": return "CON"
		"demon": return "DEM"
		"ooze": return "OOZ"
		"beast": return "BST"
		"monstrosity": return "MON"
		"aberration": return "ABR"
		"animal": return "ANI"
		_: return creature_type.substr(0, 3).to_upper()


## Get description for a creature type
func get_type_description(creature_type: String) -> String:
	var type_def = get_creature_type(creature_type)
	return type_def.get("description", "")


## Get ascii color for a creature type (for UI display)
func get_type_color(creature_type: String) -> String:
	var type_def = get_creature_type(creature_type)
	return type_def.get("ascii_color", "#FFFFFF")
