# Recipes Data Format

**Location**: `data/recipes/`
**Subdirectories**: `consumables/`, `equipment/`, `tools/`
**File Count**: 8 files
**Loaded By**: RecipeManager

## Overview

Recipes define how items can be crafted from ingredients. Each recipe specifies required materials, optional tool requirements, fire proximity needs, difficulty level, and discovery hints. The RecipeManager recursively loads all JSON files at startup.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique recipe identifier | RecipeManager, CraftingSystem |
| `result` | string | Item ID of crafted item | CraftingSystem |
| `result_count` | int | Number of items produced | CraftingSystem |
| `ingredients` | array | Required materials | CraftingSystem |
| `difficulty` | int | Crafting difficulty (1-6) | CraftingSystem |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `tool_required` | string | "" | Tool type needed | CraftingSystem |
| `fire_required` | bool | false | Must be near fire | CraftingSystem |
| `discovery_hint` | string | "" | Hint shown based on INT | CraftingSystem |

## Property Details

### `id`
**Type**: string
**Required**: Yes

Unique identifier for the recipe. Usually matches the `result` item ID.

**Convention**: Use snake_case, match result item ID when possible.

### `result`
**Type**: string
**Required**: Yes

Item ID of the item created when crafting succeeds. Must be a valid item ID in ItemManager.

### `result_count`
**Type**: int
**Required**: Yes
**Typical Values**: 1

Number of items produced on successful craft. Most recipes produce 1 item.

### `ingredients`
**Type**: array of objects
**Required**: Yes

List of required materials. Each entry specifies an item ID and count.

**Entry Format**:
```json
{"item": "item_id", "count": 1}
```

### `difficulty`
**Type**: int
**Required**: Yes
**Range**: 1-6

Affects success chance calculation:
```
Base Success = 100% - (difficulty - 1) × 10%
```

| Difficulty | Base Success | Description |
|------------|--------------|-------------|
| 1 | 100% | Trivial - anyone can do it |
| 2 | 90% | Easy - basic skill needed |
| 3 | 80% | Medium - some expertise required |
| 4 | 70% | Hard - trained craftsmen |
| 5 | 60% | Expert - master level |
| 6 | 50% | Legendary - rarely succeeds |

### `tool_required`
**Type**: string
**Required**: No
**Default**: "" (no tool needed)

Tool type that must be in inventory or equipped. Common values:
- `"knife"` - Any knife item
- `"hammer"` - Hammer required
- `""` - No tool needed

### `fire_required`
**Type**: bool
**Required**: No
**Default**: false

If true, player must be within 3 tiles of a fire source (lit campfire, fire tile).

**Used for**: Cooking, metalworking, some advanced crafting

### `discovery_hint`
**Type**: string
**Required**: No
**Default**: ""

Hint text shown to players when they have high enough INT. Helps players discover recipes through experimentation.

**Shown when**: Player INT >= 12
**Partial hint**: INT 8-11 shows generic "might make something useful"
**No hint**: INT < 8 shows generic failure message

## Ingredients Array

### Entry Properties

| Property | Type | Description |
|----------|------|-------------|
| `item` | string | Item ID to consume |
| `count` | int | Quantity needed |

### Example
```json
"ingredients": [
    {"item": "leather", "count": 3},
    {"item": "cord", "count": 1}
]
```

## Complete Examples

### Simple Recipe (No Requirements)
```json
{
  "id": "flint_knife",
  "result": "flint_knife",
  "result_count": 1,
  "ingredients": [
    {"item": "flint", "count": 1},
    {"item": "wood", "count": 1}
  ],
  "tool_required": "",
  "fire_required": false,
  "difficulty": 1,
  "discovery_hint": "A sharp stone and sturdy handle make a crude cutting tool"
}
```

### Fire-Required Recipe
```json
{
  "id": "cooked_meat",
  "result": "cooked_meat",
  "result_count": 1,
  "ingredients": [
    {"item": "raw_meat", "count": 1}
  ],
  "tool_required": "",
  "fire_required": true,
  "difficulty": 1,
  "discovery_hint": "Meat could be safer to eat if heated"
}
```

### Tool-Required Recipe
```json
{
  "id": "leather_armor",
  "result": "leather_armor",
  "result_count": 1,
  "ingredients": [
    {"item": "leather", "count": 3},
    {"item": "cord", "count": 1}
  ],
  "tool_required": "knife",
  "fire_required": false,
  "difficulty": 3,
  "discovery_hint": "Leather can be shaped into protective gear with a cutting tool"
}
```

### Complex Recipe
```json
{
  "id": "iron_knife",
  "result": "iron_knife",
  "result_count": 1,
  "ingredients": [
    {"item": "iron_ore", "count": 1},
    {"item": "wood", "count": 1}
  ],
  "tool_required": "hammer",
  "fire_required": true,
  "difficulty": 3,
  "discovery_hint": "Heated metal can be shaped with a hammer into a blade"
}
```

## Current Recipes

### Consumables
| ID | Ingredients | Fire | Tool | Diff | Result |
|----|-------------|------|------|------|--------|
| cooked_meat | Raw Meat ×1 | Yes | - | 1 | Cooked Meat |
| bandage | Cloth ×1, Herb ×1 | No | - | 1 | Bandage |
| waterskin | Leather ×2, Cord ×1 | No | - | 2 | Waterskin Empty |

### Tools
| ID | Ingredients | Fire | Tool | Diff | Result |
|----|-------------|------|------|------|--------|
| flint_knife | Flint ×1, Wood ×1 | No | - | 1 | Flint Knife |
| hammer | Iron Ore ×1, Wood ×2 | No | - | 2 | Hammer |
| iron_knife | Iron Ore ×1, Wood ×1 | Yes | Hammer | 3 | Iron Knife |

### Equipment
| ID | Ingredients | Fire | Tool | Diff | Result |
|----|-------------|------|------|------|--------|
| leather_armor | Leather ×3, Cord ×1 | No | Knife | 3 | Leather Armor |
| wooden_shield | Wood ×2, Cord ×1 | No | Knife | 2 | Wooden Shield |

## Validation Rules

1. `id` must be unique across all recipes
2. `result` must be a valid item ID in ItemManager
3. `result_count` must be >= 1
4. `ingredients` must have at least 1 entry
5. Each ingredient `item` must be valid item ID
6. Each ingredient `count` must be >= 1
7. `difficulty` should be 1-6
8. `tool_required` must be empty string or valid tool type

## File Organization

Recipes organized by result category:
```
data/recipes/
├── consumables/    # Food, medicine, potions
├── equipment/      # Armor, accessories
└── tools/          # Tools and utility items
```

## Related Documentation

- [Crafting System](../systems/crafting-system.md) - How recipes are processed
- [Items Data](./items.md) - Valid ingredient and result item IDs
