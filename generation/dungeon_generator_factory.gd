class_name DungeonGeneratorFactory
extends RefCounted
## Factory for creating dungeon generators based on type string
##
## Maps generator_type strings from JSON to concrete generator implementations.
## Supports 8 different generation algorithms for varied dungeon types.


## Create a dungeon generator instance based on generator type
## @param generator_type: String identifier (e.g., "rectangular_rooms", "cellular_automata")
## @returns: Instance of appropriate generator class
static func create(generator_type: String) -> BaseDungeonGenerator:
	match generator_type:
		"rectangular_rooms":
			return RectangularRoomsGenerator.new()
		"cellular_automata":
			return CellularAutomataGenerator.new()
		"grid_tunnels":
			return GridTunnelsGenerator.new()
		"bsp_rooms":
			return BSPRoomsGenerator.new()
		"circular_floors":
			return CircularFloorsGenerator.new()
		"concentric_rings":
			return ConcentricRingsGenerator.new()
		"symmetric_layout":
			return SymmetricLayoutGenerator.new()
		"winding_tunnels":
			return WindingTunnelsGenerator.new()
		_:
			push_warning("Unknown generator type: %s, using rectangular_rooms fallback" % generator_type)
			return RectangularRoomsGenerator.new()


## Get all supported generator type identifiers
## @returns: Array of valid generator_type strings
static func get_all_generator_types() -> Array[String]:
	return [
		"rectangular_rooms",
		"cellular_automata",
		"grid_tunnels",
		"bsp_rooms",
		"circular_floors",
		"concentric_rings",
		"symmetric_layout",
		"winding_tunnels"
	]
