class_name BaseDungeonGenerator
extends RefCounted
## Base interface for all dungeon generators
##
## Each generator type implements generate_floor() differently to create
## unique dungeon layouts (rectangular rooms, cellular automata, BSP, etc.)
##
## All generators must extend this class and implement the generate_floor method.


## Generate a single dungeon floor
## @param dungeon_def: Dictionary from DungeonManager (JSON data)
## @param floor_number: Current floor depth (1-based)
## @param world_seed: Global world seed for deterministic generation
## @returns: Generated GameMap instance
func generate_floor(dungeon_def: Dictionary, floor_number: int, world_seed: int) -> GameMap:
	push_error("BaseDungeonGenerator.generate_floor() must be overridden by subclass")
	return null


## Helper: Create deterministic floor seed from world seed + dungeon ID + floor number
## Ensures same seed always produces same floor layout
func _create_floor_seed(world_seed: int, dungeon_id: String, floor_number: int) -> int:
	var combined = "%s_%s_%d" % [world_seed, dungeon_id, floor_number]
	return combined.hash()


## Helper: Get generation parameter from dungeon definition with fallback
## Safely retrieves parameters from JSON with default values
func _get_param(dungeon_def: Dictionary, key: String, default):
	return dungeon_def.get("generation_params", {}).get(key, default)
