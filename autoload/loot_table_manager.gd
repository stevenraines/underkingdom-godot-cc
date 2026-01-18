extends Node
class_name LootTableManagerClass
## Manages loot tables - defines what items drop from enemies and containers
##
## Loot tables are loaded from JSON files in data/loot_tables/
## Each table defines guaranteed drops and chance-based drops
##
## Features:
## - Multiple loot tables per entity (creature type defaults + entity-specific)
## - CR-based scaling for currency and gems (cr_scales property)
## - D&D-style CR bands: 0-4 (1x), 5-10 (2x), 11-16 (5x), 17+ (10x)

const LOOT_TABLE_PATH = "res://data/loot_tables"

## CR band multipliers for scaling loot quantities
const CR_MULTIPLIERS = {
	0: 1.0,   # CR 0-4: Base loot
	1: 2.0,   # CR 5-10: 2x loot
	2: 5.0,   # CR 11-16: 5x loot
	3: 10.0   # CR 17+: 10x loot
}

## Loot table definitions loaded from JSON
var loot_tables: Dictionary = {}


func _ready() -> void:
	_load_loot_tables()
	print("[LootTableManager] Initialized with %d loot tables" % loot_tables.size())


## Load all loot table definitions from JSON files
func _load_loot_tables() -> void:
	var dir = DirAccess.open(LOOT_TABLE_PATH)
	if not dir:
		push_warning("[LootTableManager] Loot tables directory not found: " + LOOT_TABLE_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = LOOT_TABLE_PATH + "/" + file_name
			_load_loot_table_file(file_path)
		file_name = dir.get_next()

	dir.list_dir_end()


## Load a single loot table from JSON
func _load_loot_table_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[LootTableManager] Failed to open loot table file: " + file_path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())

	if error != OK:
		push_error("[LootTableManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return

	var data: Dictionary = json.data
	if not data.has("id"):
		push_error("[LootTableManager] Loot table missing 'id' field: " + file_path)
		return

	loot_tables[data.id] = data


## Generate loot from a loot table
## @param table_id: The loot table ID to use
## @param rng: Optional SeededRandom for deterministic generation
## @returns: Array of {item_id, count} dictionaries
func generate_loot(table_id: String, rng: SeededRandom = null) -> Array:
	if not loot_tables.has(table_id):
		push_warning("[LootTableManager] Unknown loot table: %s" % table_id)
		return []

	var table: Dictionary = loot_tables[table_id]
	var loot: Array = []

	# Process guaranteed drops first
	var guaranteed: Array = table.get("guaranteed_drops", [])
	for drop in guaranteed:
		var item_id: String = drop.get("item_id", "")
		if item_id.is_empty():
			continue

		var min_count: int = drop.get("min_count", 1)
		var max_count: int = drop.get("max_count", 1)
		var count: int = _random_range(min_count, max_count, rng)

		loot.append({"item_id": item_id, "count": count})

	# Process chance-based drops
	var drops: Array = table.get("drops", [])
	for drop in drops:
		var item_id: String = drop.get("item_id", "")
		if item_id.is_empty():
			continue

		var chance: float = drop.get("chance", 0.5)
		var roll: float = _random_float(rng)

		if roll < chance:
			var min_count: int = drop.get("min_count", 1)
			var max_count: int = drop.get("max_count", 1)
			var count: int = _random_range(min_count, max_count, rng)

			loot.append({"item_id": item_id, "count": count})

	return loot


## Check if a loot table exists
func has_loot_table(table_id: String) -> bool:
	return loot_tables.has(table_id)


## Get a random int in range using seeded or unseeded random
func _random_range(min_val: int, max_val: int, rng: SeededRandom = null) -> int:
	if rng:
		return rng.randi_range(min_val, max_val)
	else:
		return randi_range(min_val, max_val)


## Get a random float using seeded or unseeded random
func _random_float(rng: SeededRandom = null) -> float:
	if rng:
		return rng.randf()
	else:
		return randf()


# =========================================
# ENTITY-BASED LOOT GENERATION
# =========================================

## Get all loot tables for an entity (creature type defaults + entity-specific)
## @param entity: The entity to get loot tables for (must have creature_type and loot_tables)
## @returns: Array of loot table IDs to roll on
func get_loot_tables_for_entity(entity) -> Array[String]:
	var result: Array[String] = []

	# Get creature type defaults
	if "creature_type" in entity and entity.creature_type != "":
		var type_defaults = CreatureTypeManager.get_default_loot_tables(entity.creature_type)
		for table_id in type_defaults:
			if has_loot_table(table_id):
				result.append(table_id)

	# Add entity-specific loot tables
	if "loot_tables" in entity:
		for table_id in entity.loot_tables:
			if has_loot_table(table_id) and table_id not in result:
				result.append(table_id)

	return result


## Generate loot for an entity, combining all loot tables with CR scaling
## @param entity: The entity to generate loot for (must have creature_type, loot_tables, cr)
## @param rng: Optional SeededRandom for deterministic generation
## @returns: Array of {item_id, count} dictionaries
func generate_loot_for_entity(entity, rng: SeededRandom = null) -> Array:
	var all_loot: Array = []
	var entity_cr: int = entity.cr if "cr" in entity else 0

	# Get all applicable loot tables
	var tables = get_loot_tables_for_entity(entity)

	# Roll on each table
	for table_id in tables:
		var table_loot = generate_loot_with_scaling(table_id, entity_cr, rng)
		all_loot.append_array(table_loot)

	# Combine duplicate items
	return _combine_loot(all_loot)


## Generate loot from a single table with CR scaling applied
## @param table_id: The loot table ID to use
## @param cr: Challenge rating for scaling
## @param rng: Optional SeededRandom for deterministic generation
## @returns: Array of {item_id, count} dictionaries
func generate_loot_with_scaling(table_id: String, cr: int, rng: SeededRandom = null) -> Array:
	if not loot_tables.has(table_id):
		push_warning("[LootTableManager] Unknown loot table: %s" % table_id)
		return []

	var table: Dictionary = loot_tables[table_id]
	var loot: Array = []
	var multiplier: float = _get_cr_multiplier(cr)

	# Process guaranteed drops
	var guaranteed: Array = table.get("guaranteed_drops", [])
	for drop in guaranteed:
		var item_id: String = drop.get("item_id", "")
		if item_id.is_empty():
			continue

		var min_count: int = drop.get("min_count", 1)
		var max_count: int = drop.get("max_count", 1)
		var count: int = _random_range(min_count, max_count, rng)

		# Apply CR scaling if marked
		if drop.get("cr_scales", false):
			count = int(count * multiplier)

		if count > 0:
			loot.append({"item_id": item_id, "count": count})

	# Process chance-based drops
	var drops: Array = table.get("drops", [])
	for drop in drops:
		var item_id: String = drop.get("item_id", "")
		if item_id.is_empty():
			continue

		var chance: float = drop.get("chance", 0.5)
		var roll: float = _random_float(rng)

		if roll < chance:
			var min_count: int = drop.get("min_count", 1)
			var max_count: int = drop.get("max_count", 1)
			var count: int = _random_range(min_count, max_count, rng)

			# Apply CR scaling if marked
			if drop.get("cr_scales", false):
				count = int(count * multiplier)

			if count > 0:
				loot.append({"item_id": item_id, "count": count})

	return loot


## Get the CR band for a given challenge rating
## @returns: 0 (CR 0-4), 1 (CR 5-10), 2 (CR 11-16), 3 (CR 17+)
func _get_cr_band(cr: int) -> int:
	if cr >= 17:
		return 3
	elif cr >= 11:
		return 2
	elif cr >= 5:
		return 1
	else:
		return 0


## Get the loot multiplier for a given CR
func _get_cr_multiplier(cr: int) -> float:
	var band = _get_cr_band(cr)
	return CR_MULTIPLIERS.get(band, 1.0)


## Combine duplicate items in loot array
## @param loot: Array of {item_id, count} dictionaries
## @returns: Consolidated array with combined counts
func _combine_loot(loot: Array) -> Array:
	var combined: Dictionary = {}

	for drop in loot:
		var item_id = drop.get("item_id", "")
		var count = drop.get("count", 0)
		if item_id != "" and count > 0:
			if item_id in combined:
				combined[item_id] += count
			else:
				combined[item_id] = count

	var result: Array = []
	for item_id in combined:
		result.append({"item_id": item_id, "count": combined[item_id]})

	return result
