extends Node
class_name RaceManagerClass
## Manages race definitions for player character creation
##
## Races are loaded from JSON files in data/races/
## Provides race definitions including stat modifiers, traits, and abilities.
##
## Each race has:
## - stat_modifiers: Bonuses/penalties to base attributes
## - bonus_stat_points: Extra points for player to distribute (Human)
## - traits: Passive and active abilities unique to the race

const RACE_DATA_PATH = "res://data/races"

## Race definitions loaded from JSON
## Key: race_id (e.g., "human"), Value: full definition dictionary
var race_definitions: Dictionary = {}

## Default race if none selected
const DEFAULT_RACE = "human"


func _ready() -> void:
	_load_race_definitions()
	print("[RaceManager] Initialized with %d race definitions" % race_definitions.size())


## Load all race definitions from JSON files
func _load_race_definitions() -> void:
	var dir = DirAccess.open(RACE_DATA_PATH)
	if not dir:
		push_warning("[RaceManager] No race data directory found: " + RACE_DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = RACE_DATA_PATH + "/" + file_name
			_load_race_file(file_path)
		file_name = dir.get_next()

	dir.list_dir_end()


## Load a single race definition from JSON
func _load_race_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[RaceManager] Failed to open file: " + file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("[RaceManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	if not data.has("id"):
		push_error("[RaceManager] Missing 'id' field in: " + file_path)
		return

	race_definitions[data.id] = data


## Get a race definition by ID
## Returns empty dictionary if not found
func get_race(race_id: String) -> Dictionary:
	return race_definitions.get(race_id, {})


## Get all race IDs
func get_all_race_ids() -> Array[String]:
	var result: Array[String] = []
	for race_id in race_definitions:
		result.append(race_id)
	return result


## Get all races sorted by name for display
func get_all_races_sorted() -> Array[Dictionary]:
	var races: Array[Dictionary] = []
	for race_id in race_definitions:
		races.append(race_definitions[race_id])
	races.sort_custom(func(a, b): return a.name < b.name)
	return races


## Get stat modifiers for a race
## Returns dictionary of {stat_name: modifier_value}
func get_stat_modifiers(race_id: String) -> Dictionary:
	var race = get_race(race_id)
	return race.get("stat_modifiers", {})


## Get traits for a race
## Returns array of trait dictionaries
func get_traits(race_id: String) -> Array:
	var race = get_race(race_id)
	return race.get("traits", [])


## Get a specific trait by ID from a race
func get_trait(race_id: String, trait_id: String) -> Dictionary:
	var all_traits = get_traits(race_id)
	for trait_def in all_traits:
		if trait_def.get("id", "") == trait_id:
			return trait_def
	return {}


## Check if a race has a specific trait
func has_trait(race_id: String, trait_id: String) -> bool:
	return not get_trait(race_id, trait_id).is_empty()


## Get bonus stat points for a race (for distribution at creation)
func get_bonus_stat_points(race_id: String) -> int:
	var race = get_race(race_id)
	return race.get("bonus_stat_points", 0)


## Get starting items for a race (race-specific items)
func get_starting_items(race_id: String) -> Array:
	var race = get_race(race_id)
	return race.get("starting_items", [])


## Get display name for a race
func get_race_name(race_id: String) -> String:
	var race = get_race(race_id)
	return race.get("name", race_id.capitalize())


## Get description for a race
func get_race_description(race_id: String) -> String:
	var race = get_race(race_id)
	return race.get("description", "")


## Get ASCII color for a race (for player display)
func get_race_color(race_id: String) -> String:
	var race = get_race(race_id)
	return race.get("ascii_color", "#FFFFFF")


## Format stat modifiers as display string
## e.g., "+2 DEX, +1 INT, -1 CON"
func format_stat_modifiers(race_id: String) -> String:
	var modifiers = get_stat_modifiers(race_id)
	var parts: Array[String] = []

	for stat in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		var mod = modifiers.get(stat, 0)
		if mod != 0:
			var sign = "+" if mod > 0 else ""
			parts.append("%s%d %s" % [sign, mod, stat])

	if parts.is_empty():
		return "No modifiers"
	return ", ".join(parts)


## Format traits as display string (names only)
func format_traits(race_id: String) -> String:
	var all_traits = get_traits(race_id)
	if all_traits.is_empty():
		return "None"

	var names: Array[String] = []
	for trait_def in all_traits:
		names.append(trait_def.get("name", "Unknown"))
	return ", ".join(names)


## Get trait effect for a specific effect type
## Returns the effect value or null if not found
func get_trait_effect(race_id: String, trait_id: String, effect_key: String):
	var trait_def = get_trait(race_id, trait_id)
	if trait_def.is_empty():
		return null
	var effect = trait_def.get("effect", {})
	return effect.get(effect_key, null)


## Check if trait is active type (has limited uses)
func is_trait_active(race_id: String, trait_id: String) -> bool:
	var trait_def = get_trait(race_id, trait_id)
	return trait_def.get("type", "passive") == "active"


## Get uses per rest for an active trait
func get_trait_uses_per_rest(race_id: String, trait_id: String) -> int:
	var trait_def = get_trait(race_id, trait_id)
	return trait_def.get("uses_per_rest", 0)
