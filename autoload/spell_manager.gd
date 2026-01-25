extends Node

## SpellManager - Autoload singleton for spell data management
##
## Loads spell definitions from JSON files and provides lookup methods.
## Spells are loaded from individual JSON files in the data/spells folder
## organized by school subdirectories.

# Preload Spell class for spell creation
const SpellClass = preload("res://magic/spell.gd")

# Spell data cache (id -> Spell)
var _spells: Dictionary = {}

# Spells organized by school
var _spells_by_school: Dictionary = {}

# Spells organized by level
var _spells_by_level: Dictionary = {}

# Base path for spell data
const SPELL_DATA_PATH: String = "res://data/spells"

# Minimum INT required for any magic
const MIN_MAGIC_INT: int = 8

func _ready() -> void:
	_load_all_spells()
	print("SpellManager: Loaded %d spell definitions" % _spells.size())

## Load all spell definitions by recursively scanning folders
func _load_all_spells() -> void:
	_load_spells_from_folder(SPELL_DATA_PATH)

## Recursively load spells from a folder and all subfolders
func _load_spells_from_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		# Don't warn if the spells directory doesn't exist yet
		if path == SPELL_DATA_PATH:
			print("SpellManager: No spell data directory found at %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name

		if dir.current_is_dir():
			# Skip hidden folders and navigate into subfolders
			if not file_name.begins_with("."):
				_load_spells_from_folder(full_path)
		elif file_name.ends_with(".json"):
			# Load JSON file as spell data
			_load_spell_from_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

## Load a single spell from a JSON file
func _load_spell_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("SpellManager: Spell file not found: %s" % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("SpellManager: Could not open file: %s" % path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("SpellManager: JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return

	var data = json.data

	# Handle spell data
	if data is Dictionary and "id" in data:
		var spell = SpellClass.from_dict(data)
		_register_spell(spell)

## Register a spell in all lookup dictionaries
func _register_spell(spell) -> void:
	if spell.id.is_empty():
		push_warning("SpellManager: Attempted to register spell with empty ID")
		return

	# Store in main dictionary
	_spells[spell.id] = spell

	# Store by school
	if not _spells_by_school.has(spell.school):
		_spells_by_school[spell.school] = []
	_spells_by_school[spell.school].append(spell)

	# Store by level
	if not _spells_by_level.has(spell.level):
		_spells_by_level[spell.level] = []
	_spells_by_level[spell.level].append(spell)

## Get a spell by ID
## Returns Spell object or null if not found
func get_spell(spell_id: String):
	return _spells.get(spell_id, null)

## Check if a spell exists
func has_spell(spell_id: String) -> bool:
	return _spells.has(spell_id)

## Get all spells of a specific school
func get_spells_by_school(school: String) -> Array:
	return _spells_by_school.get(school, [])

## Get all spells of a specific level
func get_spells_by_level(level: int) -> Array:
	return _spells_by_level.get(level, [])

## Get all cantrips (level 0 spells)
func get_cantrips() -> Array:
	return get_spells_by_level(0)

## Get all spell IDs
func get_all_spell_ids() -> Array:
	return _spells.keys()

## Get all spells
func get_all_spells() -> Array:
	return _spells.values()

## Get list of all schools that have spells
func get_schools() -> Array:
	return _spells_by_school.keys()

## Check if a caster can cast a specific spell
## Returns: {can_cast: bool, reason: String}
func can_cast(caster, spell) -> Dictionary:
	if not spell:
		return {can_cast = false, reason = "Invalid spell"}

	if not caster:
		return {can_cast = false, reason = "Invalid caster"}

	# Check magic type and focus requirements (only for Player)
	if caster.has_method("has_focus_for_spell"):
		var focus_check = caster.has_focus_for_spell(spell)
		if not focus_check.valid:
			return {can_cast = false, reason = focus_check.message}

	# Check minimum INT for any magic (8)
	var caster_int = _get_caster_int(caster)
	if caster_int < MIN_MAGIC_INT:
		return {can_cast = false, reason = "Requires %d INT for magic (have %d)" % [MIN_MAGIC_INT, caster_int]}

	# Check spell-specific INT requirement
	var required_int = spell.get_min_intelligence()
	if caster_int < required_int:
		return {can_cast = false, reason = "Requires %d INT (have %d)" % [required_int, caster_int]}

	# Check level requirement
	var caster_level = _get_caster_level(caster)
	var required_level = spell.get_min_level()
	if caster_level < required_level:
		return {can_cast = false, reason = "Requires level %d (have %d)" % [required_level, caster_level]}

	# Check mana (skip for cantrips with 0 cost)
	var mana_cost = spell.get_mana_cost()
	if mana_cost > 0:
		var caster_mana = _get_caster_mana(caster)
		if caster_mana < mana_cost:
			return {can_cast = false, reason = "Requires %d mana (have %d)" % [mana_cost, int(caster_mana)]}

	return {can_cast = true, reason = ""}

## Get caster's INT attribute
func _get_caster_int(caster) -> int:
	# Support different entity types
	if caster.has_method("get_effective_attribute"):
		return caster.get_effective_attribute("INT")
	elif "attributes" in caster:
		return caster.attributes.get("INT", 10)
	return 10

## Get caster's level
func _get_caster_level(caster) -> int:
	if "level" in caster:
		return caster.level
	return 1

## Get caster's current mana
func _get_caster_mana(caster) -> float:
	if "survival" in caster and caster.survival:
		return caster.survival.mana
	return 0.0

## Calculate spell damage for a caster
## Returns base damage + scaling bonus
func calculate_spell_damage(spell, caster) -> int:
	var damage_info = spell.get_damage()
	if damage_info.is_empty():
		return 0

	var base_damage = damage_info.get("base", 0)
	var scaling = damage_info.get("scaling", 0)
	var caster_level = _get_caster_level(caster)

	# Damage scales with caster level above spell's required level
	var level_bonus = max(0, caster_level - spell.get_min_level())
	var total_damage = base_damage + (scaling * level_bonus)

	return total_damage

## Calculate spell duration for a caster
## Returns base duration + scaling bonus
## Checks both top-level duration and effect-specific durations (buff/debuff)
func calculate_spell_duration(spell, caster) -> int:
	var base_duration = 0
	var scaling = 0

	# First check top-level duration
	var duration_type = spell.duration.get("type", "instant")
	if duration_type != "instant":
		base_duration = spell.duration.get("base", 0)
		scaling = spell.duration.get("scaling", 0)
	else:
		# Fallback to buff duration if present
		if spell.is_buff_spell():
			var buff_info = spell.get_buff()
			base_duration = buff_info.get("duration", 0)
			scaling = buff_info.get("duration_scaling", 0)
		# Fallback to debuff duration if present
		elif spell.is_debuff_spell():
			var debuff_info = spell.get_debuff()
			base_duration = debuff_info.get("duration", 0)
			scaling = debuff_info.get("duration_scaling", 0)

	if base_duration == 0:
		return 0

	var caster_level = _get_caster_level(caster)

	# Duration scales with caster level above spell's required level
	var level_bonus = max(0, caster_level - spell.get_min_level())
	var total_duration = base_duration + (scaling * level_bonus)

	return total_duration


## Calculate spell healing for a caster
## Returns base healing + scaling bonus
func calculate_spell_healing(spell, caster) -> int:
	if not spell.is_heal_spell():
		return 0

	var heal_info = spell.get_heal()
	var base_heal = heal_info.get("base", 0)
	var scaling = heal_info.get("scaling", 0)
	var caster_level = _get_caster_level(caster)

	# Healing scales with caster level above spell's required level
	var level_bonus = max(0, caster_level - spell.get_min_level())
	var total_heal = base_heal + (scaling * level_bonus)

	return total_heal
