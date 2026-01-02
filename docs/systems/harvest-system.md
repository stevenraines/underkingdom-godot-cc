# Harvest System

**Source File**: `systems/harvest_system.gd`
**Type**: Game System (Static Class with Node extension)

## Overview

The Harvest System provides generic resource harvesting with configurable behaviors. All harvestable resources are data-driven and defined in JSON files. The system supports permanent destruction, renewable resources, and non-consumable sources like water.

## Key Concepts

- **Harvestable Resources**: Tiles that can be harvested for items (trees, rocks, water)
- **Tool Requirements**: Some resources require specific tools
- **Harvest Behaviors**: How the resource responds to harvesting
- **Yields**: Items produced when harvesting
- **Respawning**: Renewable resources return after time

## Harvest Behaviors

### DESTROY_PERMANENT
Resource is destroyed forever after harvesting.

**Examples**: Trees (wood), Rocks (stone), Iron Ore
**Tile Change**: Replaced with `replacement_tile` (usually "floor")
**Respawn**: Never

### DESTROY_RENEWABLE
Resource is destroyed but respawns after a set number of turns.

**Examples**: Wheat (grain), Berry bushes
**Tile Change**: Replaced temporarily with `replacement_tile`
**Respawn**: After `respawn_turns` turns, original tile restored

### NON_CONSUMABLE
Resource is never consumed, can be harvested infinitely.

**Examples**: Water sources (fill waterskin)
**Tile Change**: None
**Respawn**: Not needed (never consumed)

## Tool Requirements

Resources can require specific tools to harvest.

### Tool Check Logic
1. Check `required_tools` array in resource definition
2. If empty: Can harvest with bare hands
3. If `tool_must_be_equipped: true`: Tool must be in main_hand or off_hand
4. If `tool_must_be_equipped: false`: Tool can be in inventory

### Tool Priority
1. Check main_hand equipped item
2. Check off_hand equipped item
3. If `tool_must_be_equipped: false`, check inventory items

### Example Tool Requirements
| Resource | Required Tools | Must Be Equipped |
|----------|----------------|------------------|
| Tree | axe, flint_knife, iron_knife | Yes |
| Rock | pickaxe | Yes |
| Water | waterskin_empty, bottle | No |
| Wheat | flint_knife, iron_knife, sickle | Yes |

## Core Mechanics

### Harvest Attempt

```gdscript
HarvestSystem.harvest(player, target_pos, resource_id) -> Dictionary
```

### Process
1. Look up resource definition by ID
2. Check tool requirements
3. Consume stamina
4. Generate yields from yield table
5. Handle tool transformation (waterskin_empty → waterskin_full)
6. Apply tile changes based on behavior
7. Track renewable resources for respawn
8. Return result with message

### Result Dictionary
```gdscript
{
    "success": bool,      # Whether harvest succeeded
    "message": String     # Formatted harvest message
}
```

## Stamina Cost

Each resource has a `stamina_cost` that is consumed when harvesting.

| Resource | Stamina Cost |
|----------|--------------|
| Tree | 20 |
| Rock | 15 |
| Iron Ore | 15 |
| Wheat | 5 |
| Water | 5 |

If player doesn't have enough stamina, harvest fails with message: "Too tired to harvest"

## Yield Generation

Each resource has a `yields` array defining possible drops.

### Yield Entry Format
```json
{
    "item_id": "wood",
    "min_count": 2,
    "max_count": 4,
    "chance": 1.0
}
```

### Yield Calculation
1. For each yield entry:
   - Roll against `chance` (0.0-1.0)
   - If passed: Generate random count between min_count and max_count
2. Create item instances
3. Drop at harvest position (or add to inventory for tool transforms)

### Example Yields

**Tree**:
- Wood: 2-4 (100% chance)

**Rock**:
- Stone: 3-6 (100% chance)
- Flint: 0-2 (30% chance)

**Iron Ore**:
- Iron Ore: 2-5 (100% chance)

## Tool Transformation

Special handling for resources that transform the harvesting tool.

**Example: Water + Waterskin**
1. Player harvests water with waterskin_empty
2. System detects yield (waterskin_full) involves tool transformation
3. Original tool (waterskin_empty) consumed from inventory
4. Yield (waterskin_full) added directly to inventory
5. Message: "Filled waterskin_empty with water"

## Renewable Resource Tracking

Resources with `DESTROY_RENEWABLE` behavior are tracked for respawning.

### Tracked Data
- `map_id`: Which map the resource was on
- `position`: Tile coordinates
- `resource_id`: Type of resource
- `respawn_turn`: Turn number when it should respawn

### Respawn Processing
Each turn, `process_renewable_resources()` checks:
1. If current turn >= respawn_turn
2. If player is on the correct map
3. Restore original resource tile

## Message Formatting

Harvest messages support placeholders:

| Placeholder | Replaced With |
|-------------|---------------|
| `%tool%` | Name of tool used |
| `%yield%` | Comma-separated yield list |
| `%resource%` | Resource name |

**Example**: "Harvested tree with Axe, got 3 Wood"

## Player Interaction

### Controls
1. Press `H` to enter harvest mode
2. Select direction with arrow keys or WASD
3. System identifies resource at target tile
4. Harvest attempt is made

### Requirements Check
Before harvesting, system validates:
- Target tile has harvestable resource
- Player has required tool
- Player has enough stamina

## Serialization

Renewable resources are saved/loaded with game state.

### Save Format
```gdscript
[
    {
        "map_id": "overworld",
        "position": {"x": 45, "y": 23},
        "resource_id": "wheat",
        "respawn_turn": 15000
    }
]
```

## Current Resources

| Resource | Tools | Behavior | Stamina | Yields |
|----------|-------|----------|---------|--------|
| Tree | axe, knives | Permanent | 20 | Wood ×2-4 |
| Rock | pickaxe | Permanent | 15 | Stone ×3-6, Flint ×0-2 (30%) |
| Iron Ore | pickaxe | Permanent | 15 | Iron Ore ×2-5 |
| Wheat | knives, sickle | Renewable (5000 turns) | 5 | Wheat ×1-3 |
| Water | waterskin, bottle | Non-consumable | 5 | Waterskin Full ×1 |

## Integration with Other Systems

- **SurvivalSystem**: Consumes stamina for harvesting
- **InventorySystem**: Checks for tools, adds harvested items
- **MapManager**: Tile modifications, resource tile detection
- **TurnManager**: Tracks turns for respawn timing
- **ItemManager**: Creates yield items
- **FOVSystem**: Invalidates cache when tiles change (tree removed)

## Data Dependencies

- **Resources** (`data/resources/`): Resource definitions
- **Items** (`data/items/`): Valid item IDs for yields and tools

## Related Documentation

- [Resources Data](../data/resources.md) - Resource file format
- [Survival System](./survival-system.md) - Stamina mechanics
- [Inventory System](./inventory-system.md) - Tool and item management
- [Items Data](../data/items.md) - Item definitions
