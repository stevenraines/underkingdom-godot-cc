# Item System Domain Knowledge

Use this agent when implementing or modifying items, crafting, templates, variants, or the item factory system.

---

## Item System Overview

### Legacy Items
- Defined directly in JSON (`data/items/*.json`)
- Loaded by ItemManager
- Simple items with fixed properties

### Templated Items (Item Factory)
- Templates define base item properties (`data/item_templates/`)
- Variants define modifiers (`data/variants/`)
- `ItemFactory.create_item("knife", {"material": "iron"})` generates items dynamically
- Supports stacking multiple variants: "Dwarven Steel Sword", "Worn Flint Knife"

---

## Item Factory System

### Templates
Define base item properties in `data/item_templates/`:
```json
{
  "template_id": "knife",
  "display_name": "Knife",
  "category": "tool",
  "base_properties": {
    "ascii_char": "/",
    "flags": {"equippable": true, "tool": true}
  },
  "base_stats": {"weight": 0.5, "value": 10},
  "applicable_variants": ["material"],
  "required_variants": ["material"]
}
```

### Variants
Define modifiers in `data/variants/`:
```json
{
  "variant_type": "material",
  "variants": {
    "iron": {
      "name_prefix": "Iron",
      "tier": 2,
      "modifiers": {
        "value": {"type": "multiply", "value": 1.5},
        "damage": {"type": "add", "value": 2}
      }
    }
  }
}
```

### Modifier Types
- `multiply` (0.5 = 50% of original)
- `add` (+2 to value)
- `override` (replace value entirely)

### Effects vs Stats
For consumables, use `base_effects` for consumption effects:
```json
{
  "base_effects": {"hunger": 15},
  "base_stats": {"weight": 0.5, "value": 5}
}
```

Variants can add to effects:
```json
{
  "effects": {"hunger": 5}  // Additive
}
```

---

## Recipe System

### Recipe Format
```json
{
  "id": "cooked_fish",
  "result": "cooked_fish",
  "result_count": 1,
  "ingredients": [
    {"item": "raw_meat", "count": 1},
    {"flag": "fish", "count": 1, "display_name": "Any Fish"}
  ],
  "tool_required": "knife",
  "fire_required": true,
  "fire_distance": 3,
  "difficulty": 1
}
```

### Flag-Based Ingredients
Recipes can accept any item with a specific flag:
```json
{"flag": "fish", "count": 1, "display_name": "Any Fish"}
```

Uses `inventory.get_item_count_with_flag()` and `inventory.remove_item_with_flag()`

---

## Adding New Items

### Legacy Item
1. Create JSON in `data/items/[type]/item_name.json`
2. ItemManager auto-loads on startup
3. Create via `ItemManager.create_item("item_id", count)`

### Templated Item
1. Create template in `data/item_templates/[category]/template_name.json`
2. Add variant type in `data/variants/variant_type.json` if needed
3. Create via `ItemFactory.create_item("template_id", {"variant_type": "variant_name"})`

---

## Key Files

- `items/item.gd` - Item base class
- `items/item_factory.gd` - Creates items from templates + variants
- `autoload/item_manager.gd` - Legacy item loading
- `autoload/variant_manager.gd` - Template and variant loading
- `autoload/recipe_manager.gd` - Recipe loading
- `crafting/recipe.gd` - Recipe data class
- `systems/inventory_system.gd` - Inventory management
- `systems/crafting_system.gd` - Crafting logic
- `data/items/` - Legacy item definitions
- `data/item_templates/` - Item templates
- `data/variants/` - Variant modifiers
- `data/recipes/` - Recipe definitions
