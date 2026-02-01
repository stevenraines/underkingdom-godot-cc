# Refactor 04: Chunk Cleanup Mixin

**Risk Level**: Low
**Estimated Changes**: 1 new file, 4 files updated

---

## Goal

Create a shared utility for chunk cleanup logic that is duplicated across 4 managers:
- EntityManager
- FeatureManager
- HazardManager
- StructureManager

---

## Current State

Each manager implements similar `_on_chunk_unloaded()` handlers:

**entity_manager.gd:**
```gdscript
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    var removed_count = 0
    for i in range(entities.size() - 1, -1, -1):
        var entity = entities[i]
        if entity.source_chunk == chunk_coords:
            entities.remove_at(i)
            removed_count += 1

    if removed_count > 0:
        print("[EntityManager] Cleaned up %d entities from chunk %s" % [removed_count, chunk_coords])
```

Similar patterns in feature_manager.gd, hazard_manager.gd, and structure_manager.gd.

---

## Implementation

### Step 1: Create autoload/chunk_cleanup_helper.gd

```gdscript
class_name ChunkCleanupHelper
extends RefCounted

## ChunkCleanupHelper - Utility for cleaning up entities when chunks unload
##
## Provides static methods for removing items from collections based on chunk coordinates.
## Used by EntityManager, FeatureManager, HazardManager, and StructureManager.

const ChunkManagerClass = preload("res://autoload/chunk_manager.gd")


## Remove items from an array where item.source_chunk matches the given chunk
## Returns the number of items removed
## Items must have a 'source_chunk' property of type Vector2i
static func cleanup_array_by_chunk(arr: Array, chunk_coords: Vector2i, manager_name: String = "") -> int:
	var removed_count = 0

	# Iterate backwards to safely remove items
	for i in range(arr.size() - 1, -1, -1):
		var item = arr[i]
		if item.has_method("get") or "source_chunk" in item:
			var item_chunk = item.source_chunk if "source_chunk" in item else null
			if item_chunk == chunk_coords:
				arr.remove_at(i)
				removed_count += 1

	if removed_count > 0 and manager_name != "":
		print("[%s] Cleaned up %d items from chunk %s" % [manager_name, removed_count, chunk_coords])

	return removed_count


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
		print("[%s] Cleaned up %d items from chunk %s" % [manager_name, removed_count, chunk_coords])

	return removed_count


## Remove positions from a dictionary where the position falls within the given chunk
## Useful for position-keyed dictionaries like ground_items or placed_features
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
		print("[%s] Cleaned up %d positions from chunk %s" % [manager_name, removed_count, chunk_coords])

	return removed_count


## Check if a position is within a given chunk
static func is_position_in_chunk(position: Vector2i, chunk_coords: Vector2i) -> bool:
	var pos_chunk = ChunkManagerClass.world_to_chunk(position)
	return pos_chunk == chunk_coords
```

---

### Step 2: Update autoload/entity_manager.gd

**Replace** the `_on_chunk_unloaded` method:

```gdscript
# Before:
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    var removed_count = 0
    for i in range(entities.size() - 1, -1, -1):
        var entity = entities[i]
        if entity.source_chunk == chunk_coords:
            entities.remove_at(i)
            removed_count += 1

    if removed_count > 0:
        print("[EntityManager] Cleaned up %d entities from chunk %s" % [removed_count, chunk_coords])

# After:
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    ChunkCleanupHelper.cleanup_array_by_chunk(entities, chunk_coords, "EntityManager")
```

---

### Step 3: Update autoload/feature_manager.gd

**Replace** the `_on_chunk_unloaded` method:

```gdscript
# Before:
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    var removed_count = 0
    # ... similar cleanup logic for placed_features dictionary

# After:
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    ChunkCleanupHelper.cleanup_positions_in_chunk(placed_features, chunk_coords, "FeatureManager")
```

---

### Step 4: Update autoload/hazard_manager.gd

**Replace** the `_on_chunk_unloaded` method:

```gdscript
# Before:
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    var removed_count = 0
    # ... similar cleanup logic

# After:
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    ChunkCleanupHelper.cleanup_positions_in_chunk(active_hazards, chunk_coords, "HazardManager")
```

---

### Step 5: Update autoload/structure_manager.gd

**Replace** the `_on_chunk_unloaded` method:

```gdscript
# Before:
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    # ... similar cleanup logic

# After:
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
    ChunkCleanupHelper.cleanup_positions_in_chunk(placed_structures, chunk_coords, "StructureManager")
```

---

## Note on Implementation

This is **not** registered as an autoload since it only contains static methods. The class is used via `ChunkCleanupHelper.method_name()` syntax.

If any manager needs instance-specific cleanup logic beyond the standard patterns, they can still implement custom code alongside the helper calls.

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Start new game in overworld
- [ ] Walk around to load/unload chunks
  - [ ] Check console for cleanup messages
  - [ ] Verify entities disappear when chunks unload
  - [ ] Verify they reappear when chunks reload
- [ ] Enter and exit dungeon
  - [ ] Features clean up properly
  - [ ] Hazards clean up properly
- [ ] Place structures (campfire, etc.)
  - [ ] Walk away until chunk unloads
  - [ ] Return - structure should be saved/restored
- [ ] Save and load game
  - [ ] All positions preserved correctly
- [ ] No memory leaks (entity count stable over time)
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- autoload/chunk_cleanup_helper.gd
git checkout HEAD -- autoload/entity_manager.gd
git checkout HEAD -- autoload/feature_manager.gd
git checkout HEAD -- autoload/hazard_manager.gd
git checkout HEAD -- autoload/structure_manager.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
