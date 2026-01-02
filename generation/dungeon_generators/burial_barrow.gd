class_name BurialBarrowGenerator
## BurialBarrowGenerator - Backward compatibility wrapper for burial barrow dungeons
##
## Delegates to the new data-driven RectangularRoomsGenerator using burial_barrow.json
## Maintains the existing API: generate_floor(world_seed, floor_number) -> GameMap
##
## DEPRECATED: New code should use DungeonManager.generate_floor("burial_barrow", floor_number, world_seed)

## Generate a burial barrow dungeon floor (backward compatible API)
## @param world_seed: World seed for deterministic generation
## @param floor_number: Current floor number (1-based)
## @returns: Generated GameMap instance
static func generate_floor(world_seed: int, floor_number: int) -> GameMap:
	# Get dungeon definition from DungeonManager
	var dungeon_def: Dictionary = DungeonManager.get_dungeon("burial_barrow")

	# Get generator type from dungeon definition
	var generator_type: String = dungeon_def.get("generator_type", "rectangular_rooms")

	# Create appropriate generator via factory
	var generator: BaseDungeonGenerator = DungeonGeneratorFactory.create(generator_type)

	# Delegate to generator
	var map: GameMap = generator.generate_floor(dungeon_def, floor_number, world_seed)

	print("Burial barrow floor %d generated (via %s generator)" % [floor_number, generator_type])
	return map
