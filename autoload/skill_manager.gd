extends Node

## SkillManager - Autoload singleton for skill data management
##
## Loads skill definitions from JSON files and provides lookup methods.
## Skills are loaded from individual JSON files in the data/skills folder
## organized by category subdirectories (weapons/, actions/).

# Skill definition class
class SkillDefinition:
	var id: String
	var name: String
	var description: String
	var category: String  # "weapon" or "action"
	var weapon_subtypes: Array[String] = []  # For weapon skills
	var attack_types: Array[String] = []  # For thrown weapons (attack_type: "thrown")
	var bonus_type: String  # "hit_chance", "success_chance", "yield"
	var bonus_per_level: int = 1
	var max_level: int = 20

	static func from_dict(data: Dictionary) -> SkillDefinition:
		var skill = SkillDefinition.new()
		skill.id = data.get("id", "")
		skill.name = data.get("name", "Unknown Skill")
		skill.description = data.get("description", "")
		skill.category = data.get("category", "action")

		# Load weapon subtypes
		var subtypes = data.get("weapon_subtypes", [])
		for subtype in subtypes:
			skill.weapon_subtypes.append(str(subtype))

		# Load attack types (for thrown weapons)
		var atk_types = data.get("attack_types", [])
		for atk_type in atk_types:
			skill.attack_types.append(str(atk_type))

		skill.bonus_type = data.get("bonus_type", "")
		skill.bonus_per_level = data.get("bonus_per_level", 1)
		skill.max_level = data.get("max_level", 20)
		return skill

# Skill data cache (id -> SkillDefinition)
var _skills: Dictionary = {}

# Skills organized by category
var _skills_by_category: Dictionary = {}

# Weapon subtype to skill mapping (cached for combat lookup)
var _subtype_to_skill: Dictionary = {}

# Attack type to skill mapping (for thrown weapons)
var _attack_type_to_skill: Dictionary = {}

# Base path for skill data
const SKILL_DATA_PATH: String = "res://data/skills"

func _ready() -> void:
	_load_all_skills()
	_build_weapon_skill_mapping()
	print("SkillManager: Loaded %d skill definitions" % _skills.size())

## Load all skill definitions by recursively scanning folders
func _load_all_skills() -> void:
	_load_skills_from_folder(SKILL_DATA_PATH)

## Recursively load skills from a folder and all subfolders
func _load_skills_from_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		# Don't warn if the skills directory doesn't exist yet
		if path == SKILL_DATA_PATH:
			print("SkillManager: No skill data directory found at %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name

		if dir.current_is_dir():
			# Skip hidden folders and navigate into subfolders
			if not file_name.begins_with("."):
				_load_skills_from_folder(full_path)
		elif file_name.ends_with(".json"):
			# Load JSON file as skill data
			_load_skill_from_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

## Load a single skill from a JSON file
func _load_skill_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("SkillManager: Skill file not found: %s" % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SkillManager: Could not open file: %s" % path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("SkillManager: JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return

	var data = json.data

	# Handle skill data
	if data is Dictionary and "id" in data:
		var skill = SkillDefinition.from_dict(data)
		_register_skill(skill)

## Register a skill in all lookup dictionaries
func _register_skill(skill: SkillDefinition) -> void:
	if skill.id.is_empty():
		push_warning("SkillManager: Attempted to register skill with empty ID")
		return

	# Store in main dictionary
	_skills[skill.id] = skill

	# Store by category
	if not _skills_by_category.has(skill.category):
		_skills_by_category[skill.category] = []
	_skills_by_category[skill.category].append(skill)

## Build weapon subtype-to-skill mapping for fast combat lookup
func _build_weapon_skill_mapping() -> void:
	for skill_id in _skills:
		var skill: SkillDefinition = _skills[skill_id]
		if skill.category != "weapon":
			continue

		# Map weapon subtypes to this skill
		for subtype in skill.weapon_subtypes:
			_subtype_to_skill[subtype] = skill

		# Map attack types to this skill (for thrown weapons)
		for attack_type in skill.attack_types:
			_attack_type_to_skill[attack_type] = skill

## Get a skill by ID
## Returns SkillDefinition or null if not found
func get_skill(skill_id: String) -> SkillDefinition:
	return _skills.get(skill_id, null)

## Check if a skill exists
func has_skill(skill_id: String) -> bool:
	return _skills.has(skill_id)

## Get all skill IDs
func get_all_skill_ids() -> Array:
	return _skills.keys()

## Get all skills
func get_all_skills() -> Array:
	return _skills.values()

## Get all weapon skills
func get_weapon_skills() -> Array:
	return _skills_by_category.get("weapon", [])

## Get all action skills
func get_action_skills() -> Array:
	return _skills_by_category.get("action", [])

## Get skill categories
func get_categories() -> Array:
	return _skills_by_category.keys()

## Get skills by category
func get_skills_by_category(category: String) -> Array:
	return _skills_by_category.get(category, [])

## Get the weapon skill that applies to a weapon subtype
func get_weapon_skill_for_subtype(subtype: String) -> SkillDefinition:
	return _subtype_to_skill.get(subtype, null)

## Get the weapon skill for a weapon item
## Checks attack_type first (for thrown weapons), then subtype
func get_weapon_skill_for_weapon(weapon) -> SkillDefinition:
	if not weapon:
		return null

	# For thrown weapons, check attack_type first
	var attack_type = ""
	if "attack_type" in weapon:
		attack_type = weapon.attack_type
	elif weapon is Dictionary:
		attack_type = weapon.get("attack_type", "")

	if attack_type == "thrown" and _attack_type_to_skill.has("thrown"):
		return _attack_type_to_skill["thrown"]

	# Otherwise, map by subtype
	var subtype = ""
	if "subtype" in weapon:
		subtype = weapon.subtype
	elif weapon is Dictionary:
		subtype = weapon.get("subtype", "")

	return _subtype_to_skill.get(subtype, null)

## Calculate skill bonus for a skill at a given level
## Returns: skill_level * bonus_per_level
func get_skill_bonus(skill_id: String, skill_level: int) -> int:
	var skill = get_skill(skill_id)
	if not skill:
		return 0
	return skill_level * skill.bonus_per_level

## Get the max level for a skill
func get_skill_max_level(skill_id: String) -> int:
	var skill = get_skill(skill_id)
	if not skill:
		return 20  # Default max
	return skill.max_level
