extends Node
## NameGenerator autoload singleton - do not use class_name to avoid conflict

## NameGenerator - Generates fantasy names for NPCs, places, enemies, and items
##
## Uses syllable-based assembly with cultural patterns loaded from JSON.
## All generation is deterministic based on SeededRandom for consistency.

const SeededRandomClass = preload("res://generation/seeded_random.gd")
const DATA_PATH = "res://data/name_patterns"

## Name pattern definitions loaded from JSON
## Key: pattern_id (e.g., "human_male", "dwarf_settlement", "book_title")
var name_patterns: Dictionary = {}

func _ready() -> void:
	_load_name_patterns()
	print("[NameGenerator] Loaded %d name patterns" % name_patterns.size())

## Load all name pattern definitions from JSON files
func _load_name_patterns() -> void:
	var dir = DirAccess.open(DATA_PATH)
	if not dir:
		push_warning("[NameGenerator] Could not open directory: %s" % DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_pattern_file(DATA_PATH + "/" + file_name)
		elif dir.current_is_dir() and not file_name.begins_with("."):
			# Recursively load subdirectories
			_load_patterns_from_subdirectory(DATA_PATH + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Recursively load from subdirectory
func _load_patterns_from_subdirectory(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_pattern_file(path + "/" + file_name)
		elif dir.current_is_dir() and not file_name.begins_with("."):
			_load_patterns_from_subdirectory(path + "/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

## Load a single name pattern file
func _load_pattern_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[NameGenerator] Could not open file: %s" % file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_warning("[NameGenerator] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	var id = data.get("id", "")
	if id.is_empty():
		push_warning("[NameGenerator] Pattern missing 'id' in %s" % file_path)
		return

	name_patterns[id] = data
	#print("[NameGenerator] Loaded pattern: %s" % id)

## Generate a name using a specific pattern
## @param pattern_id: The ID of the pattern to use (e.g., "human_male", "dwarf_settlement")
## @param rng: SeededRandom instance for deterministic generation
## @return: Generated name as a String
func generate_name(pattern_id: String, rng: SeededRandomClass) -> String:
	var pattern = name_patterns.get(pattern_id, {})
	if pattern.is_empty():
		push_warning("[NameGenerator] Unknown pattern: %s" % pattern_id)
		return "Unknown"

	var name_type = pattern.get("type", "syllable")

	match name_type:
		"syllable":
			return _generate_syllable_name(pattern, rng)
		"template":
			return _generate_template_name(pattern, rng)
		"compound":
			return _generate_compound_name(pattern, rng)
		_:
			push_warning("[NameGenerator] Unknown name type: %s" % name_type)
			return "Unknown"

## Generate a syllable-based name
func _generate_syllable_name(pattern: Dictionary, rng: SeededRandomClass) -> String:
	var prefixes = pattern.get("prefixes", [])
	var middles = pattern.get("middles", [])
	var suffixes = pattern.get("suffixes", [])
	var structure = pattern.get("structure", "prefix-suffix")

	var parts = []

	match structure:
		"prefix-suffix":
			if not prefixes.is_empty():
				parts.append(rng.choice(prefixes))
			if not suffixes.is_empty():
				parts.append(rng.choice(suffixes))
		"prefix-middle-suffix":
			if not prefixes.is_empty():
				parts.append(rng.choice(prefixes))
			if not middles.is_empty():
				parts.append(rng.choice(middles))
			if not suffixes.is_empty():
				parts.append(rng.choice(suffixes))
		"prefix-optional-middle-suffix":
			if not prefixes.is_empty():
				parts.append(rng.choice(prefixes))
			# 50% chance to include middle
			if not middles.is_empty() and rng.randf() < 0.5:
				parts.append(rng.choice(middles))
			if not suffixes.is_empty():
				parts.append(rng.choice(suffixes))

	var name = "".join(parts)

	# Apply capitalization
	var capitalization = pattern.get("capitalization", "first")
	match capitalization:
		"first":
			name = name.capitalize()
		"all":
			name = name.to_upper()
		"none":
			pass

	return name

## Generate a template-based name (e.g., "The [adjective] [noun]")
func _generate_template_name(pattern: Dictionary, rng: SeededRandomClass) -> String:
	var templates = pattern.get("templates", [])
	if templates.is_empty():
		return "Unknown"

	var template = rng.choice(templates)
	var result = template

	# Replace placeholders with random words from word lists
	var word_lists = pattern.get("word_lists", {})
	for list_name in word_lists.keys():
		var placeholder = "[%s]" % list_name
		if placeholder in result:
			var words = word_lists[list_name]
			if not words.is_empty():
				var word = rng.choice(words)
				result = result.replace(placeholder, word)

	return result

## Generate a compound name (combines multiple patterns)
func _generate_compound_name(pattern: Dictionary, rng: SeededRandomClass) -> String:
	var parts = []
	var components = pattern.get("components", [])

	for component in components:
		var component_pattern_id = component.get("pattern_id", "")
		if component_pattern_id.is_empty():
			continue

		var part = generate_name(component_pattern_id, rng)

		# Apply optional transformation
		var transform = component.get("transform", "")
		match transform:
			"lowercase":
				part = part.to_lower()
			"uppercase":
				part = part.to_upper()

		parts.append(part)

	var separator = pattern.get("separator", " ")
	return separator.join(parts)

## Generate a personal name (first + last name)
## @param race: Race/culture identifier (e.g., "human", "dwarf", "elf")
## @param gender: Gender identifier ("male" or "female")
## @param rng: SeededRandom instance
## @return: Full name as "FirstName LastName"
func generate_personal_name(race: String, gender: String, rng: SeededRandomClass) -> String:
	var first_pattern = "%s_%s" % [race, gender]
	var last_pattern = "%s_surname" % race

	var first_name = generate_name(first_pattern, rng)
	var last_name = generate_name(last_pattern, rng)

	return "%s %s" % [first_name, last_name]

## Generate a settlement name
## @param settlement_type: Type of settlement (e.g., "town", "village", "fort")
## @param biome: Optional biome hint for thematic names
## @param rng: SeededRandom instance
## @return: Settlement name
func generate_settlement_name(settlement_type: String, biome: String, rng: SeededRandomClass) -> String:
	var pattern_id = "settlement_%s" % settlement_type

	# Try biome-specific pattern first
	if not biome.is_empty():
		var biome_pattern = "settlement_%s_%s" % [settlement_type, biome]
		if name_patterns.has(biome_pattern):
			pattern_id = biome_pattern

	return generate_name(pattern_id, rng)

## Generate a book title
## @param topic: Optional topic/category for the book
## @param rng: SeededRandom instance
## @return: Book title
func generate_book_title(topic: String, rng: SeededRandomClass) -> String:
	var pattern_id = "book_title"

	# Try topic-specific pattern if provided
	if not topic.is_empty():
		var topic_pattern = "book_title_%s" % topic
		if name_patterns.has(topic_pattern):
			pattern_id = topic_pattern

	return generate_name(pattern_id, rng)

## Generate a ship name
## @param rng: SeededRandom instance
## @return: Ship name
func generate_ship_name(rng: SeededRandomClass) -> String:
	return generate_name("ship_name", rng)

## Get all available pattern IDs
func get_all_patterns() -> Array:
	return name_patterns.keys()

## Check if a pattern exists
func has_pattern(pattern_id: String) -> bool:
	return name_patterns.has(pattern_id)
