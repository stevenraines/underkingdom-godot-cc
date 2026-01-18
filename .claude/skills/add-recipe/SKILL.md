# Add Recipe Skill

Workflow for adding new crafting recipes to the game.

---

## Steps

### 1. Create Recipe JSON

Create `data/recipes/[category]/recipe_name.json`:

```json
{
  "id": "recipe_id",
  "name": "Recipe Name",
  "description": "What this recipe creates",
  "result": "item_id",
  "result_count": 1,
  "ingredients": [
    {"item": "wood", "count": 2},
    {"item": "iron_ore", "count": 1}
  ],
  "tool_required": "hammer",
  "fire_required": false,
  "fire_distance": 3,
  "difficulty": 2,
  "skill_required": "",
  "skill_level": 0,
  "discovery_hint": "Perhaps a hammer could shape metal..."
}
```

### 2. Ingredient Types

#### Item-Based (Specific Item)
```json
{"item": "iron_ore", "count": 2}
```

#### Flag-Based (Any Item with Flag)
```json
{"flag": "fish", "count": 1, "display_name": "Any Fish"}
```

Common flags: `fish`, `herb`, `meat`, `leather`, `cloth`

### 3. Recipe Properties

| Property | Description |
|----------|-------------|
| `result` | Item ID to create |
| `result_count` | How many to create |
| `tool_required` | Tool that must be in inventory |
| `fire_required` | Must be near fire source |
| `fire_distance` | Max tiles from fire (default 3) |
| `difficulty` | 1-5, affects success chance |
| `skill_required` | Skill name (if any) |
| `skill_level` | Minimum skill level needed |
| `discovery_hint` | Shown when player has ingredients |

### 4. Categories

- `consumables/` - Food, potions
- `tools/` - Crafting/harvesting tools
- `equipment/` - Weapons, armor
- `materials/` - Processed materials

---

## Verification

1. Restart game (RecipeManager loads on startup)
2. Open crafting menu (C key)
3. Verify recipe appears when player has ingredients
4. Test crafting success/failure
5. Check result item is correct

---

## Key Files

- `data/recipes/` - Recipe definitions
- `autoload/recipe_manager.gd` - Recipe loading
- `crafting/recipe.gd` - Recipe data class
- `systems/crafting_system.gd` - Crafting logic
- `ui/crafting_screen.gd` - Crafting UI
