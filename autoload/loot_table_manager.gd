extends Node
class_name LootTableManagerClass
## Manages loot tables - defines what items drop from enemies and containers
##
## Loot tables are loaded from JSON files in data/loot_tables/
## Each table defines guaranteed drops and chance-based drops

const LOOT_TABLE_PATH = "res://data/loot_tables"

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
