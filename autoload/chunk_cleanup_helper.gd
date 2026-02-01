class_name ChunkCleanupHelper
extends RefCounted

## ChunkCleanupHelper - Utility for cleaning up entities when chunks unload
##
## Provides static methods for removing items from collections based on chunk coordinates.
## Used by EntityManager, FeatureManager, and HazardManager.

const ChunkManagerClass = preload("res://autoload/chunk_manager.gd")


## Remove items from an array where item.source_chunk matches the given chunk
## Returns Array of removed items (caller can perform additional cleanup if needed)
## Items must have a 'source_chunk' property of type Vector2i
static func cleanup_array_by_chunk(arr: Array, chunk_coords: Vector2i, manager_name: String = "") -> Array:
	var removed: Array = []

	# Iterate backwards to safely remove items
	for i in range(arr.size() - 1, -1, -1):
		var item = arr[i]
		if "source_chunk" in item and item.source_chunk == chunk_coords:
			removed.append(item)
			arr.remove_at(i)

	if removed.size() > 0 and manager_name != "":
		#print("[%s] Cleaned up %d items from chunk %s" % [manager_name, removed.size(), chunk_coords])
		pass

	return removed


## Remove items from a dictionary where value.source_chunk matches the given chunk
## Returns the number of items removed
static func cleanup_dict_by_chunk(dict: Dictionary, chunk_coords: Vector2i, manager_name: String = "") -> int:
	var removed_count = 0
	var keys_to_remove: Array = []

	for key in dict:
		var item = dict[key]
		if item != null and "source_chunk" in item:
			if item.source_chunk == chunk_coords:
				keys_to_remove.append(key)

	for key in keys_to_remove:
		dict.erase(key)
		removed_count += 1

	if removed_count > 0 and manager_name != "":
		#print("[%s] Cleaned up %d items from chunk %s" % [manager_name, removed_count, chunk_coords])
		pass

	return removed_count


## Remove positions from a dictionary where the position falls within the given chunk
## Useful for position-keyed dictionaries like active_features or active_hazards
## Returns the number of items removed
static func cleanup_positions_in_chunk(dict: Dictionary, chunk_coords: Vector2i, manager_name: String = "") -> int:
	var removed_count = 0
	var keys_to_remove: Array = []

	for pos in dict:
		if pos is Vector2i:
			var pos_chunk = ChunkManagerClass.world_to_chunk(pos)
			if pos_chunk == chunk_coords:
				keys_to_remove.append(pos)

	for key in keys_to_remove:
		dict.erase(key)
		removed_count += 1

	if removed_count > 0 and manager_name != "":
		#print("[%s] Cleaned up %d positions from chunk %s" % [manager_name, removed_count, chunk_coords])
		pass

	return removed_count


## Check if a position is within a given chunk
static func is_position_in_chunk(position: Vector2i, chunk_coords: Vector2i) -> bool:
	var pos_chunk = ChunkManagerClass.world_to_chunk(position)
	return pos_chunk == chunk_coords
