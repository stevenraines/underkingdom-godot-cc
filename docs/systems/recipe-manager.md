# Recipe Manager

**Source File**: `autoload/recipe_manager.gd`
**Type**: Autoload Singleton
**Depends On**: ItemManager

## Overview

The Recipe Manager loads and indexes all crafting recipes from JSON files. It provides recipe lookup by ID, result item, or ingredient combination for the crafting system and recipe discovery.

## Key Concepts

- **Recipe Loading**: Recursive scan of `data/recipes/` directory
- **Dual Indexing**: By recipe ID and by result item
- **Ingredient Matching**: Find recipes by combining items

## Data Storage

```gdscript
var all_recipes: Dictionary = {}           # recipe_id → Recipe
var recipes_by_result: Dictionary = {}     # item_id → [Recipe, ...]
```

## Data Path

```gdscript
const RECIPE_DATA_BASE_PATH: String = "res://data/recipes"
```

Directory structure:
```
data/recipes/
├── consumables/
│   └── cooked_meat.json
├── tools/
│   ├── flint_knife.json
│   └── hammer.json
└── equipment/
    └── leather_armor.json
```

## Loading Process

### Initialization

```gdscript
func _ready() -> void:
    _load_all_recipes()
```

### Recursive Loading

```gdscript
func _load_recipes_from_folder(path: String) -> void:
    var dir = DirAccess.open(path)
    dir.list_dir_begin()
    var file_name = dir.get_next()

    while file_name != "":
        var full_path = path + "/" + file_name

        if dir.current_is_dir():
            if not file_name.begins_with("."):
                _load_recipes_from_folder(full_path)  # Recurse
        elif file_name.ends_with(".json"):
            _load_recipe_from_file(full_path)

        file_name = dir.get_next()
```

### File Parsing

```gdscript
func _load_recipe_from_file(file_path: String) -> void:
    var file = FileAccess.open(file_path, FileAccess.READ)
    var json_string = file.get_as_text()

    var json = JSON.new()
    json.parse(json_string)
    var data = json.data

    if data is Dictionary and "id" in data:
        var recipe = Recipe.create_from_data(data)
        all_recipes[recipe.id] = recipe

        # Index by result item
        if recipe.result_item_id not in recipes_by_result:
            recipes_by_result[recipe.result_item_id] = []
        recipes_by_result[recipe.result_item_id].append(recipe)
```

## Core Functions

### Get Recipe by ID

```gdscript
func get_recipe(recipe_id: String) -> Recipe:
    return all_recipes.get(recipe_id, null)
```

### Get Recipes for Item

```gdscript
func get_recipes_for_item(item_id: String) -> Array[Recipe]:
    var result: Array[Recipe] = []
    if item_id in recipes_by_result:
        result.assign(recipes_by_result[item_id])
    return result
```

Returns all recipes that produce the given item.

### Find Recipe by Ingredients

```gdscript
func find_recipe_by_ingredients(ingredient_ids: Array[String]) -> Recipe:
    # Sort for comparison
    var sorted_ingredients = ingredient_ids.duplicate()
    sorted_ingredients.sort()

    for recipe_id in all_recipes:
        var recipe: Recipe = all_recipes[recipe_id]

        # Build sorted recipe ingredients
        var recipe_ingredients: Array[String] = []
        for ingredient in recipe.ingredients:
            for i in range(ingredient["count"]):
                recipe_ingredients.append(ingredient["item"])
        recipe_ingredients.sort()

        if recipe_ingredients == sorted_ingredients:
            return recipe

    return null
```

Used for recipe discovery through experimentation.

### Get All Recipe IDs

```gdscript
func get_all_recipe_ids() -> Array[String]:
    var result: Array[String] = []
    for recipe_id in all_recipes:
        result.append(recipe_id)
    return result
```

### Get All Recipes

```gdscript
func get_all_recipes() -> Array[Recipe]:
    var result: Array[Recipe] = []
    for recipe_id in all_recipes:
        result.append(all_recipes[recipe_id])
    return result
```

## Recipe Class

Loaded recipes are `Recipe` instances:

```gdscript
class Recipe:
    var id: String                      # "leather_armor"
    var result_item_id: String          # "leather_armor"
    var result_count: int               # 1
    var ingredients: Array[Dictionary]  # [{item: "leather", count: 3}]
    var tool_required: String           # "knife"
    var fire_required: bool             # false
    var difficulty: int                 # 1-5
    var discovery_hint: String          # Shown based on INT
```

## Ingredient Matching Algorithm

```
Input: ["leather", "leather", "leather", "cord"]
Process:
1. Sort input: ["cord", "leather", "leather", "leather"]
2. For each recipe:
   a. Expand ingredients: leather x3, cord x1 →
      ["cord", "leather", "leather", "leather"]
   b. Sort: ["cord", "leather", "leather", "leather"]
   c. Compare arrays
3. Return matching recipe or null
```

## Usage by Crafting System

```gdscript
# Check if player can craft
var recipe = RecipeManager.get_recipe("leather_armor")
if recipe.has_requirements(player.inventory, is_near_fire):
    # Show as craftable in UI

# Recipe discovery
var selected_items = ["leather", "leather", "leather", "cord"]
var discovered = RecipeManager.find_recipe_by_ingredients(selected_items)
if discovered:
    player.discovered_recipes.append(discovered.id)
```

## Output Logging

```
RecipeManager initialized
Loaded recipe: cooked_meat
Loaded recipe: flint_knife
Loaded recipe: hammer
Loaded recipe: leather_armor
RecipeManager: Loaded 8 recipes
```

## Integration with Other Systems

- **CraftingSystem**: Queries recipes for UI and crafting attempts
- **ItemManager**: Recipe references item IDs
- **Player**: Stores discovered recipe IDs

## Related Documentation

- [Crafting System](./crafting-system.md) - Crafting mechanics
- [Recipes Data](../data/recipes.md) - Recipe JSON format
- [Items Data](../data/items.md) - Item definitions
