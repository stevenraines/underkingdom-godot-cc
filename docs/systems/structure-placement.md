# Structure Placement

**Source File**: `systems/structure_placement.gd`
**Type**: Static Class
**Class Name**: `StructurePlacement`

## Overview

Structure Placement handles validation and placement of player-built structures. It validates positioning, checks material requirements, consumes resources, and creates placed structures. All methods are static.

## Key Concepts

- **Placement Validation**: Multiple checks before allowing placement
- **Material Consumption**: Resources removed from inventory
- **Tool Requirements**: Some structures need specific tools
- **Adjacency Requirement**: Player must be near placement position

## Core Functions

### Validate Placement

```gdscript
var result = StructurePlacement.can_place_structure(structure_id, pos, player, map)
# Returns: {valid: bool, reason: String}
```

### Place Structure

```gdscript
var result = StructurePlacement.place_structure(structure_id, pos, player, map)
# Returns: {success: bool, structure: Structure, message: String}
```

### Remove Structure

```gdscript
var success = StructurePlacement.remove_structure(structure, map)
```

## Validation Checks

Placement validation performs these checks in order:

### 1. Structure Exists

```gdscript
if not StructureManager.structure_definitions.has(structure_id):
    return {valid: false, reason: "Unknown structure type"}
```

### 2. Map Type

```gdscript
if current_map.map_id.begins_with("dungeon_"):
    return {valid: false, reason: "Cannot build structures in dungeons"}
```

Structures only allowed on overworld.

### 3. Adjacency

```gdscript
var distance = max(dx, dy)  # Chebyshev distance
if distance > 1:
    return {valid: false, reason: "Too far away to build here"}
```

Player must be within 1 tile (including diagonals).

### 4. Walkable Terrain

```gdscript
if not tile or not tile.walkable:
    return {valid: false, reason: "Cannot build on unwalkable terrain"}
```

### 5. Position Clear (for blocking structures)

```gdscript
if blocks_movement:
    # Check entities
    for entity in EntityManager.entities:
        if entity.position == pos and entity.blocks_movement:
            return {valid: false, reason: "Position is blocked"}

    # Check existing structures
    var existing = StructureManager.get_structures_at(pos, map_id)
    for structure in existing:
        if structure.blocks_movement:
            return {valid: false, reason: "Another structure is already here"}
```

### 6. Materials Available

```gdscript
for req in build_requirements:
    if player.inventory.get_item_count(item_id) < count:
        return {valid: false, reason: "Missing materials: %s x%d"}
```

### 7. Tool Available

```gdscript
if build_tool != "":
    # Check inventory items with matching subtype
    # Check equipped items
    # Check if player has item with that ID
    if not has_tool:
        return {valid: false, reason: "Requires tool: %s"}
```

## Placement Process

When all validation passes:

1. Consume materials from inventory
2. Create structure instance via StructureManager
3. Register with StructureManager for map
4. Emit `inventory_changed` signal
5. Emit `structure_placed` signal
6. Return success with structure reference

## Placement Result

```gdscript
{
    "success": true,
    "structure": <Structure instance>,
    "message": "Built Campfire"
}
```

Or on failure:
```gdscript
{
    "success": false,
    "structure": null,
    "message": "Missing materials: wood x3"
}
```

## Build Requirements

From structure definition:
```json
"build_requirements": [
    {"item": "wood", "count": 3}
]
```

## Tool Requirements

From structure definition:
```json
"build_tool": "flint"
```

Tool check looks for:
- Items with matching subtype
- Equipped items with matching subtype
- Items with matching ID

## Adjacency Diagram

```
. X X X .
X X X X X
X X P X X
X X X X X
. X X X .
```

P = Player, X = Valid placement (distance ≤ 1)

Uses Chebyshev distance (max of dx, dy) to allow diagonal placement.

## Error Messages

| Condition | Message |
|-----------|---------|
| Unknown structure | "Unknown structure type" |
| In dungeon | "Cannot build structures in dungeons" |
| Too far | "Too far away to build here" |
| Unwalkable | "Cannot build on unwalkable terrain" |
| Entity blocking | "Position is blocked" |
| Structure exists | "Another structure is already here" |
| Missing materials | "Missing materials: wood x3" |
| Missing tool | "Requires tool: flint" |

## Integration with Other Systems

- **StructureManager**: Creates and registers structures
- **Player Inventory**: Checks and consumes materials
- **EntityManager**: Checks for blocking entities
- **EventBus**: Emits placement signals

## Related Documentation

- [Structure Manager](./structure-manager.md) - Structure management
- [Structures Data](../data/structures.md) - Build requirements
- [Inventory System](./inventory-system.md) - Material checking
