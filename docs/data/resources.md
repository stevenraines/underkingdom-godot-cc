# Resources Data Format

**Location**: `data/resources/`
**File Count**: 5 files
**Loaded By**: HarvestSystem

## Overview

Resources define harvestable objects in the world like trees, rocks, and water sources. Each resource specifies tool requirements, stamina costs, harvest behavior, and item yields. The HarvestSystem loads all JSON files recursively at startup.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique resource identifier | HarvestSystem |
| `name` | string | Display name | UI, messages |
| `harvest_behavior` | string | How resource responds to harvesting | HarvestSystem |
| `yields` | array | Items produced when harvested | HarvestSystem |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `required_tools` | array | [] | Tool IDs that can harvest | HarvestSystem |
| `tool_must_be_equipped` | bool | true | Tool must be in hand slot | HarvestSystem |
| `stamina_cost` | int | 10 | Stamina consumed | HarvestSystem |
| `respawn_turns` | int | 0 | Turns until respawn (renewable only) | HarvestSystem |
| `replacement_tile` | string | "" | Tile type to place after harvest | HarvestSystem |
| `harvest_message` | string | "Harvested %resource%" | Message shown on harvest | HarvestSystem |

## Property Details

### `id`
**Type**: string
**Required**: Yes

Unique identifier for the resource. This ID is used to match tiles to their harvest definitions.

**Convention**: Use snake_case, match tile type when possible.

### `name`
**Type**: string
**Required**: Yes

Human-readable name shown in messages and UI.

### `harvest_behavior`
**Type**: string
**Required**: Yes
**Valid Values**: `"destroy_permanent"`, `"destroy_renewable"`, `"non_consumable"`

Determines what happens to the resource after harvesting.

| Value | Description | Tile Change | Respawn |
|-------|-------------|-------------|---------|
| `destroy_permanent` | Gone forever | Yes | Never |
| `destroy_renewable` | Returns after time | Yes (temporary) | After N turns |
| `non_consumable` | Never consumed | No | Not needed |

### `required_tools`
**Type**: array of strings
**Required**: No
**Default**: [] (can harvest with bare hands)

List of item IDs that can be used to harvest this resource. If empty, no tool is needed.

**Example**: `["axe", "flint_knife", "iron_knife"]`

Any tool in the list works - player only needs one of them.

### `tool_must_be_equipped`
**Type**: bool
**Required**: No
**Default**: true

If true, tool must be in main_hand or off_hand equipment slot.
If false, tool can be anywhere in inventory.

**Use cases**:
- `true`: Axe for trees (need to swing it)
- `false`: Waterskin for water (just needs to be carried)

### `stamina_cost`
**Type**: int
**Required**: No
**Default**: 10

Stamina consumed when harvesting. Harvest fails if player doesn't have enough stamina.

**Typical Values**:
- Light work (water): 5
- Medium work (wheat): 5-10
- Heavy work (trees, rocks): 15-20

### `respawn_turns`
**Type**: int
**Required**: No (only for `destroy_renewable`)
**Default**: 0

Number of turns until the resource respawns. Only used with `destroy_renewable` behavior.

**Example**: Wheat with `respawn_turns: 5000` returns after 5 in-game days (at 1000 turns/day).

### `replacement_tile`
**Type**: string
**Required**: No
**Default**: ""

Tile type to place after harvesting. Used with `destroy_permanent` and `destroy_renewable`.

**Common Values**:
- `"floor"` - Replace tree/rock with walkable floor
- `""` - Don't change tile (for non_consumable)

### `harvest_message`
**Type**: string
**Required**: No
**Default**: "Harvested %resource%"

Message template shown after successful harvest.

**Placeholders**:
| Placeholder | Replaced With |
|-------------|---------------|
| `%tool%` | Name of tool used |
| `%yield%` | Comma-separated list of yields |
| `%resource%` | Resource name |

**Example**: "Harvested tree with %tool%, got %yield%"
→ "Harvested tree with Axe, got 3 Wood"

## Yields Array

### Entry Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `item_id` | string | required | Item ID to create |
| `min_count` | int | 1 | Minimum quantity |
| `max_count` | int | 1 | Maximum quantity |
| `chance` | float | 1.0 | Probability (0.0-1.0) |

### Yield Calculation
1. For each yield entry, roll against `chance`
2. If roll passes, generate random count between min and max
3. Create item with that quantity

### Example
```json
"yields": [
    {"item_id": "stone", "min_count": 3, "max_count": 6},
    {"item_id": "flint", "min_count": 0, "max_count": 2, "chance": 0.3}
]
```
This produces:
- Stone: 3-6 pieces (always)
- Flint: 0-2 pieces (30% chance)

## Complete Examples

### Permanent Destruction
```json
{
  "id": "tree",
  "name": "Tree",
  "required_tools": ["axe", "flint_knife", "iron_knife"],
  "tool_must_be_equipped": true,
  "harvest_behavior": "destroy_permanent",
  "stamina_cost": 20,
  "yields": [
    {"item_id": "wood", "min_count": 2, "max_count": 4}
  ],
  "replacement_tile": "floor",
  "harvest_message": "Harvested tree with %tool%, got %yield%"
}
```

### Renewable Resource
```json
{
  "id": "wheat",
  "name": "Wheat",
  "required_tools": ["flint_knife", "iron_knife", "sickle"],
  "tool_must_be_equipped": true,
  "harvest_behavior": "destroy_renewable",
  "stamina_cost": 5,
  "respawn_turns": 5000,
  "yields": [
    {"item_id": "wheat", "min_count": 1, "max_count": 3}
  ],
  "replacement_tile": "floor",
  "harvest_message": "Harvested wheat with %tool%, got %yield%"
}
```

### Non-Consumable (Tool Transform)
```json
{
  "id": "water",
  "name": "Water",
  "required_tools": ["waterskin_empty", "bottle"],
  "tool_must_be_equipped": false,
  "harvest_behavior": "non_consumable",
  "stamina_cost": 5,
  "yields": [
    {"item_id": "waterskin_full", "min_count": 1, "max_count": 1}
  ],
  "harvest_message": "Filled %tool% with water"
}
```

### Multiple Yields with Probability
```json
{
  "id": "rock",
  "name": "Rock",
  "required_tools": ["pickaxe"],
  "tool_must_be_equipped": true,
  "harvest_behavior": "destroy_permanent",
  "stamina_cost": 15,
  "yields": [
    {"item_id": "stone", "min_count": 3, "max_count": 6},
    {"item_id": "flint", "min_count": 1, "max_count": 2, "chance": 0.3}
  ],
  "replacement_tile": "floor",
  "harvest_message": "Broke rock with %tool%, got %yield%"
}
```

## Current Resources

| ID | Tools | Behavior | Stamina | Yields | Respawn |
|----|-------|----------|---------|--------|---------|
| tree | axe, knives | Permanent | 20 | Wood ×2-4 | Never |
| rock | pickaxe | Permanent | 15 | Stone ×3-6, Flint ×1-2 (30%) | Never |
| iron_ore | pickaxe | Permanent | 15 | Iron Ore ×2-5 | Never |
| wheat | knives, sickle | Renewable | 5 | Wheat ×1-3 | 5000 turns |
| water | waterskin, bottle | Non-consumable | 5 | Waterskin Full ×1 | N/A |

## Validation Rules

1. `id` must be unique across all resources
2. `harvest_behavior` must be one of the three valid values
3. `yields` must have at least 1 entry
4. Each yield `item_id` must be valid item ID
5. Each yield `chance` must be 0.0-1.0 (not percentages)
6. `respawn_turns` should only be set for `destroy_renewable`
7. `replacement_tile` should be set for destructive behaviors
8. `required_tools` items must be valid item IDs

## Related Documentation

- [Harvest System](../systems/harvest-system.md) - How resources are processed
- [Items Data](./items.md) - Valid yield item IDs and tool IDs
- [Survival System](../systems/survival-system.md) - Stamina mechanics
