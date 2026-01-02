# Crafting System

**Source File**: `systems/crafting_system.gd`
**Type**: Game System (Static Class)

## Overview

The Crafting System handles all crafting attempts in Underkingdom, including recipe-based crafting, experimentation with unknown ingredient combinations, and recipe discovery. Crafting has a chance of failure based on recipe difficulty and player Intelligence.

## Key Concepts

- **Known Recipes**: Recipes the player has discovered and can craft reliably
- **Experimentation**: Combining ingredients to discover new recipes
- **Success Chance**: Probability of successful craft based on difficulty and INT
- **Fire Proximity**: Some recipes require being near a fire source
- **Discovery Hints**: INT-based hints about possible recipes

## Core Mechanics

### Success Chance Calculation

Crafting success depends on recipe difficulty and player INT.

**Formula**:
```
Base Success = 100% - (difficulty - 1) × 10%
INT Bonus = (INT - 10) × 5%
Success Chance = Base Success + INT Bonus
Clamped to: 50% minimum, 100% maximum
```

### Success Chance by Difficulty and INT

| Difficulty | INT 8 | INT 10 | INT 12 | INT 14 | INT 16 |
|------------|-------|--------|--------|--------|--------|
| 1 | 90% | 100% | 100% | 100% | 100% |
| 2 | 80% | 90% | 100% | 100% | 100% |
| 3 | 70% | 80% | 90% | 100% | 100% |
| 4 | 60% | 70% | 80% | 90% | 100% |
| 5 | 50% | 60% | 70% | 80% | 90% |
| 6 | 50% | 50% | 60% | 70% | 80% |

### Example Calculations

**Crafting Flint Knife (difficulty 1) with INT 10:**
- Base Success: 100% - (1 - 1) × 10% = 100%
- INT Bonus: (10 - 10) × 5% = 0%
- Final: 100% (capped)

**Crafting Iron Knife (difficulty 3) with INT 8:**
- Base Success: 100% - (3 - 1) × 10% = 80%
- INT Bonus: (8 - 10) × 5% = -10%
- Final: 80% - 10% = **70%**

## Ingredient Consumption

**IMPORTANT**: Ingredients are always consumed when crafting is attempted, regardless of success or failure.

This creates meaningful decisions:
- Low INT characters risk losing materials
- Experimentation with unknown recipes can waste resources
- Players should learn recipes before mass production

## Fire Proximity Check

Recipes with `fire_required: true` need the player within 3 tiles of a fire source.

### Valid Fire Sources
- Lit campfire structures (StructureManager)
- Tiles with `is_fire_source` property
- Entities with `is_fire_source` property

### Fire Range
```
For each tile within 3 tiles of player:
  If fire source found:
    Return true
Return false
```

## Recipe-Based Crafting

When player knows a recipe, they can craft it directly.

### Process
1. Check if player has all required ingredients
2. Check fire proximity if required
3. Check tool requirements
4. Calculate success chance
5. Roll for success
6. **Consume ingredients** (always)
7. If success: Create result item, add to inventory
8. If failure: Display failure message (ingredients lost)
9. If recipe not known: Learn it (mark as discovered)

### Result Dictionary
```gdscript
{
    "success": bool,         # Whether craft succeeded
    "result_item": Item,     # Created item (null if failed)
    "message": String,       # Status message
    "recipe_learned": bool   # True if this was first successful craft
}
```

## Experimentation

Players can combine 2-4 ingredients to discover new recipes.

### Process
1. Validate 2-4 ingredients selected
2. Search for matching recipe in RecipeManager
3. If found: Attempt craft (same as recipe-based)
4. If not found: Consume ingredients, show hint based on INT
5. On successful discovery: Learn recipe for future use

### Experiment Hints (Based on INT)

| INT | Hint Message |
|-----|--------------|
| 14+ | "These materials don't seem compatible. Experiment failed, components lost." |
| 10-13 | "You're not sure what these could make. Experiment failed." |
| <10 | "The experiment failed. Components were wasted." |

## Discovery Hints

Recipes have `discovery_hint` text shown based on INT.

| INT | Hint Shown |
|-----|------------|
| 12+ | Full discovery hint from recipe |
| 8-11 | "These materials might make something useful..." |
| <8 | "You're not sure what these could make." |

### Example Discovery Hints
- Flint Knife: "A sharp stone and sturdy handle make a crude cutting tool"
- Cooked Meat: "Meat could be safer to eat if heated"
- Bandage: "Cloth and herbs might help with wounds"

## Recipe Requirements

Recipes can have multiple requirement types:

### Ingredients
```json
"ingredients": [
    {"item": "raw_meat", "count": 1},
    {"item": "herb", "count": 2}
]
```

### Tool Requirements
```json
"tool_required": "knife"  // Must have this tool type in inventory/equipped
```

### Fire Proximity
```json
"fire_required": true  // Must be within 3 tiles of fire source
```

## Signals Emitted

| Signal | Parameters | Description |
|--------|------------|-------------|
| `craft_attempted` | recipe: Recipe, success: bool | After any craft attempt |
| `craft_succeeded` | recipe: Recipe, item: Item | After successful craft |
| `craft_failed` | recipe: Recipe | After failed craft attempt |
| `recipe_discovered` | recipe: Recipe | When player learns new recipe |
| `inventory_changed` | (none) | After ingredients consumed |

## Current Recipes

### Consumables (fire_required)
| Recipe | Ingredients | Difficulty | Result |
|--------|-------------|------------|--------|
| Cooked Meat | Raw Meat ×1 | 1 | Cooked Meat ×1 |
| Bandage | Cloth ×1, Herb ×1 | 1 | Bandage ×1 |
| Waterskin | Leather ×2, Cord ×1 | 2 | Waterskin (empty) ×1 |

### Tools
| Recipe | Ingredients | Difficulty | Result |
|--------|-------------|------------|--------|
| Flint Knife | Flint ×1, Wood ×1 | 1 | Flint Knife ×1 |
| Hammer | Iron Ore ×1, Wood ×2 | 2 | Hammer ×1 |
| Iron Knife | Iron Ore ×1, Wood ×1 | 3 | Iron Knife ×1 |

### Equipment
| Recipe | Ingredients | Tool | Difficulty | Result |
|--------|-------------|------|------------|--------|
| Leather Armor | Leather ×3, Cord ×1 | Knife | 3 | Leather Armor ×1 |
| Wooden Shield | Wood ×2, Cord ×1 | Knife | 2 | Wooden Shield ×1 |

## Integration with Other Systems

- **RecipeManager**: Provides recipe definitions and lookup
- **InventorySystem**: Checks and consumes ingredients, adds results
- **StructureManager**: Fire source detection for campfires
- **MapManager**: Tile-based fire source detection
- **EventBus**: Broadcasts crafting events

## Data Dependencies

- **Recipes** (`data/recipes/`): Recipe definitions with ingredients, difficulty
- **Items** (`data/items/`): Valid item IDs for ingredients and results

## Related Documentation

- [Recipes Data](../data/recipes.md) - Recipe file format
- [Inventory System](./inventory-system.md) - Ingredient management
- [Items Data](../data/items.md) - Item definitions
- [Fire Component](./fire-component.md) - Fire sources
