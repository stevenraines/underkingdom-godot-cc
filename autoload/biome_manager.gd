extends Node

## BiomeManager - Loads and manages biome definitions from JSON
##
## Replaces hardcoded BiomeDefinition with data-driven system

# Biome data cache (id -> data dictionary)
var biome_definitions: Dictionary = {}

# World generation config
var generation_config: Dictionary = {}

# Base paths
const BIOME_DATA_PATH: String = "res://data/biomes"
const CONFIG_PATH: String = "res://data/configuration/world_generation_config.json"

func _ready() -> void:
	_load_generation_config()
	_load_biome_definitions()
	print("BiomeManager: Loaded %d biome definitions" % biome_definitions.size())

## Load world generation configuration
func _load_generation_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("BiomeManager: Config file not found: %s" % CONFIG_PATH)
		_set_default_config()
		return

	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		push_error("BiomeManager: Could not open config file: %s" % CONFIG_PATH)
		_set_default_config()
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("BiomeManager: JSON parse error in config at line %d: %s" % [
			json.get_error_line(), json.get_error_message()
		])
		_set_default_config()
		return

	generation_config = json.data
	print("BiomeManager: Loaded world generation config")

## Set default configuration if JSON fails to load
func _set_default_config() -> void:
	generation_config = {
		"elevation_noise": {
			"frequency": 0.03,
			"octaves": 3,
			"lacunarity": 2.0,
			"gain": 0.5,
			"elevation_curve": 1.5
		},
		"moisture_noise": {
			"frequency": 0.05,
			"octaves": 2,
			"lacunarity": 2.0,
			"gain": 0.5,
			"seed_offset": 1000
		},
		"chunk_settings": {
			"chunk_size": 32,
			"load_radius": 3,
			"unload_radius": 5,
			"cache_max_size": 100
		},
		"island_settings": {
			"width_chunks": 50,
			"height_chunks": 50,
			"falloff_start": 0.7,
			"falloff_strength": 3.0
		}
	}

## Load all biome definitions from JSON files
func _load_biome_definitions() -> void:
	var files = JsonHelper.load_all_from_directory(BIOME_DATA_PATH, false)
	for file_entry in files:
		_process_biome_data(file_entry.path, file_entry.data)


## Process loaded biome data
func _process_biome_data(path: String, data) -> void:
	if data is Dictionary and "id" in data:
		var biome_id = data.get("id", "")
		if biome_id != "":
			biome_definitions[biome_id] = data
			print("BiomeManager: Loaded biome '%s'" % biome_id)
		else:
			push_warning("BiomeManager: Biome without ID in %s" % path)
	else:
		push_warning("BiomeManager: Invalid biome file format in %s" % path)

## Get biome definition by ID
func get_biome(biome_id: String) -> Dictionary:
	if biome_definitions.has(biome_id):
		return biome_definitions[biome_id]

	# Return default grassland if not found
	push_warning("BiomeManager: Biome '%s' not found, using grassland" % biome_id)
	return {
		"id": "grassland",
		"name": "Grassland",
		"base_tile": "floor",
		"grass_char": "\"",
		"tree_density": 0.05,
		"rock_density": 0.01,
		"color_floor": [0.4, 0.6, 0.3],
		"color_grass": [0.5, 0.7, 0.4]
	}

## Get biome ID from elevation and moisture values
func get_biome_id_from_values(elevation: float, moisture: float) -> String:
	# Check for inland fresh water first
	# Positive elevation = inside island (not contiguous with edge ocean)
	# Low positive elevation = inland water depression (lake/pond)
	if elevation >= 0 and elevation < 0.05:
		# Inside island but low elevation = inland fresh water (NOT ocean)
		if moisture < 0.4:
			return "deep_fresh_water"
		else:
			return "fresh_water"

	# Negative elevation = outside island = actual ocean (contiguous with edge)
	# Falls through to matrix lookup which returns ocean/deep_ocean

	# Use biome matrix from config if available
	if generation_config.has("biome_matrix"):
		var matrix_data = generation_config["biome_matrix"]
		var elev_thresholds = matrix_data.get("elevation_thresholds", [0.25, 0.4, 0.55, 0.7, 0.85])
		var moist_thresholds = matrix_data.get("moisture_thresholds", [0.2, 0.4, 0.6, 0.8])
		var matrix = matrix_data.get("matrix", [])

		# Find elevation row
		var elev_index = 0
		for threshold in elev_thresholds:
			if elevation < threshold:
				break
			elev_index += 1

		# Find moisture column
		var moist_index = 0
		for threshold in moist_thresholds:
			if moisture < threshold:
				break
			moist_index += 1

		# Lookup in matrix
		if elev_index < matrix.size():
			var row = matrix[elev_index]
			if moist_index < row.size():
				return row[moist_index]

	# Fallback to simple logic
	if elevation < 0.25:
		return "ocean"
	elif elevation < 0.4:
		return "grassland"
	elif elevation < 0.7:
		return "forest"
	else:
		return "mountains"

## Get noise configuration
func get_elevation_noise_config() -> Dictionary:
	return generation_config.get("elevation_noise", {})

func get_moisture_noise_config() -> Dictionary:
	return generation_config.get("moisture_noise", {})

func get_chunk_settings() -> Dictionary:
	return generation_config.get("chunk_settings", {})

func get_island_settings() -> Dictionary:
	return generation_config.get("island_settings", {})

func get_coastline_noise_config() -> Dictionary:
	return generation_config.get("coastline_noise", {})
