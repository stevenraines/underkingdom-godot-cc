class_name DungeonGeneratorFactory
extends RefCounted
## Factory for creating dungeon generators based on type string
##
## Maps generator_type strings from JSON to concrete generator implementations.
## Supports 8 different generation algorithms for varied dungeon types.

# Generator script paths - loaded at runtime to avoid parse-time dependency issues
const GENERATOR_PATHS = {
	"rectangular_rooms": "res://generation/dungeon_generators/rectangular_rooms_generator.gd",
	"cellular_automata": "res://generation/dungeon_generators/cellular_automata_generator.gd",
	"grid_tunnels": "res://generation/dungeon_generators/grid_tunnels_generator.gd",
	"bsp_rooms": "res://generation/dungeon_generators/bsp_rooms_generator.gd",
	"circular_floors": "res://generation/dungeon_generators/circular_floors_generator.gd",
	"concentric_rings": "res://generation/dungeon_generators/concentric_rings_generator.gd",
	"symmetric_layout": "res://generation/dungeon_generators/symmetric_layout_generator.gd",
	"winding_tunnels": "res://generation/dungeon_generators/winding_tunnels_generator.gd"
}


## Create a dungeon generator instance based on generator type
## @param generator_type: String identifier (e.g., "rectangular_rooms", "cellular_automata")
## @returns: Instance of appropriate generator class
static func create(generator_type: String):
	var path = GENERATOR_PATHS.get(generator_type, "")
	if path.is_empty():
		push_warning("Unknown generator type: %s, using rectangular_rooms fallback" % generator_type)
		path = GENERATOR_PATHS["rectangular_rooms"]

	var script = load(path)
	if script == null:
		push_error("Failed to load generator script: %s" % path)
		return null

	return script.new()


## Get all supported generator type identifiers
## @returns: Array of valid generator_type strings
static func get_all_generator_types() -> Array[String]:
	var types: Array[String] = []
	for key in GENERATOR_PATHS:
		types.append(key)
	return types
