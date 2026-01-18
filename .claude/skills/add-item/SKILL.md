# Add Item Skill

Workflow for adding new items to the game.

---

## Choose Item Type

### Legacy Item (Simple, Fixed Properties)
Use for simple items that don't need variants.

### Templated Item (Dynamic, With Variants)
Use for items that come in multiple materials/qualities (e.g., "Iron Sword", "Steel Sword").

---

## Legacy Item Steps

### 1. Create Item JSON

Create `data/items/[category]/item_name.json`:

```json
{
  "id": "item_id",
  "name": "Item Name",
  "description": "Item description",
  "ascii_char": "*",
  "color": "#FFFFFF",
  "category": "consumable",
  "weight": 0.5,
  "value": 10,
  "max_stack": 10,
  "flags": {
    "consumable": true,
    "equippable": false
  },
  "effects": {
    "hunger": 20,
    "health": 5
  }
}
```

### 2. Categories
- `consumable` - Food, potions, scrolls
- `material` - Crafting ingredients
- `tool` - Harvesting tools
- `weapon` - Combat weapons
- `armor` - Protective equipment
- `misc` - Everything else

---

## Templated Item Steps

### 1. Create Template

Create `data/item_templates/[category]/template_name.json`:

```json
{
  "template_id": "sword",
  "display_name": "Sword",
  "description_base": "A sharp blade.",
  "category": "weapon",
  "base_properties": {
    "ascii_char": "/",
    "color": "#AAAAAA",
    "flags": {"equippable": true, "weapon": true},
    "slot": "main_hand",
    "attack_type": "melee"
  },
  "base_stats": {
    "weight": 2.0,
    "value": 50,
    "damage": 6
  },
  "applicable_variants": ["material", "quality"],
  "required_variants": ["material"],
  "default_variants": {"quality": "standard"}
}
```

### 2. Verify Variant Types Exist

Check `data/variants/` for needed variant types:
- `materials.json` - Weapon/tool materials
- `materials_armor.json` - Armor materials
- `quality.json` - Quality modifiers
- `origin.json` - Origin modifiers (dwarven, elven)

### 3. Add New Variant (If Needed)

Add to existing variant file or create new one:

```json
{
  "variant_type": "material",
  "variants": {
    "mithril": {
      "name_prefix": "Mithril",
      "tier": 5,
      "modifiers": {
        "value": {"type": "multiply", "value": 3.0},
        "damage": {"type": "add", "value": 4},
        "weight": {"type": "multiply", "value": 0.5}
      }
    }
  }
}
```

---

## Verification

1. Restart game (ItemManager/VariantManager load on startup)
2. Use debug menu to spawn the item
3. Check item properties are correct
4. For templated items, verify all variant combinations work

---

## Key Files

- `data/items/` - Legacy item definitions
- `data/item_templates/` - Item templates
- `data/variants/` - Variant modifiers
- `autoload/item_manager.gd` - Legacy item loading
- `autoload/variant_manager.gd` - Template/variant loading
- `items/item_factory.gd` - Creates templated items
