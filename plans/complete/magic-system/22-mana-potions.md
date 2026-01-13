# Phase 22: Mana Potions

## Overview
Implement mana restoration potions with crafting recipes.

## Dependencies
- Phase 1: Mana System
- Phase 1.11: Crafting System (existing)

## Implementation Steps

### 22.1 Create Mana Potion Items
**File:** `data/items/consumables/mana_potion_minor.json`

```json
{
  "id": "mana_potion_minor",
  "name": "Minor Mana Potion",
  "description": "A small vial of glowing blue liquid. Restores some mana.",
  "category": "consumable",
  "subcategory": "potion",
  "flags": {"consumable": true, "magical": true},
  "effects": {
    "restore_mana": 15
  },
  "weight": 0.3,
  "value": 20,
  "stack_max": 10,
  "ascii_char": "!",
  "ascii_color": "#6688FF"
}
```

**File:** `data/items/consumables/mana_potion.json`

```json
{
  "id": "mana_potion",
  "name": "Mana Potion",
  "description": "A vial of swirling blue energy. Restores a moderate amount of mana.",
  "category": "consumable",
  "subcategory": "potion",
  "flags": {"consumable": true, "magical": true},
  "effects": {
    "restore_mana": 35
  },
  "weight": 0.3,
  "value": 50,
  "stack_max": 10,
  "ascii_char": "!",
  "ascii_color": "#4466FF"
}
```

**File:** `data/items/consumables/mana_potion_greater.json`

```json
{
  "id": "mana_potion_greater",
  "name": "Greater Mana Potion",
  "description": "A large flask of concentrated arcane energy. Fully restores mana.",
  "category": "consumable",
  "subcategory": "potion",
  "flags": {"consumable": true, "magical": true},
  "effects": {
    "restore_mana": 100,
    "restore_mana_percent": true
  },
  "weight": 0.5,
  "value": 150,
  "stack_max": 5,
  "ascii_char": "!",
  "ascii_color": "#2244FF"
}
```

### 22.2 Create Mana Crystal Material
**File:** `data/items/materials/mana_crystal.json`

```json
{
  "id": "mana_crystal",
  "name": "Mana Crystal",
  "description": "A crystallized fragment of pure magical energy.",
  "category": "material",
  "subcategory": "magical",
  "flags": {"magical": true},
  "weight": 0.1,
  "value": 30,
  "stack_max": 20,
  "ascii_char": "*",
  "ascii_color": "#88AAFF"
}
```

**File:** `data/items/materials/moonpetal.json`

```json
{
  "id": "moonpetal",
  "name": "Moonpetal",
  "description": "A luminescent flower petal with magical properties.",
  "category": "material",
  "subcategory": "herb",
  "flags": {"magical": true},
  "weight": 0.05,
  "value": 15,
  "stack_max": 30,
  "ascii_char": ",",
  "ascii_color": "#CCCCFF"
}
```

### 22.3 Create Mana Potion Recipes
**File:** `data/recipes/consumables/mana_potion_minor.json`

```json
{
  "id": "mana_potion_minor_recipe",
  "name": "Minor Mana Potion",
  "description": "Brew a minor mana potion.",
  "category": "consumable",
  "ingredients": [
    {"item_id": "empty_vial", "quantity": 1},
    {"item_id": "moonpetal", "quantity": 2},
    {"item_id": "water_flask", "quantity": 1}
  ],
  "result": {"item_id": "mana_potion_minor", "quantity": 1},
  "byproducts": [
    {"item_id": "empty_flask", "quantity": 1}
  ],
  "requirements": {
    "intelligence": 9,
    "near_fire": true
  },
  "difficulty": 2,
  "stamina_cost": 5,
  "discovery_hints": ["magical herb", "brewing", "mana"],
  "known_by_default": false
}
```

**File:** `data/recipes/consumables/mana_potion.json`

```json
{
  "id": "mana_potion_recipe",
  "name": "Mana Potion",
  "description": "Brew a standard mana potion.",
  "category": "consumable",
  "ingredients": [
    {"item_id": "empty_vial", "quantity": 1},
    {"item_id": "mana_crystal", "quantity": 1},
    {"item_id": "moonpetal", "quantity": 3},
    {"item_id": "water_flask", "quantity": 1}
  ],
  "result": {"item_id": "mana_potion", "quantity": 1},
  "byproducts": [
    {"item_id": "empty_flask", "quantity": 1}
  ],
  "requirements": {
    "intelligence": 11,
    "near_fire": true
  },
  "difficulty": 4,
  "stamina_cost": 8,
  "discovery_hints": ["mana crystal", "alchemy", "arcane brewing"],
  "known_by_default": false
}
```

**File:** `data/recipes/consumables/mana_potion_greater.json`

```json
{
  "id": "mana_potion_greater_recipe",
  "name": "Greater Mana Potion",
  "description": "Brew a powerful mana restoration potion.",
  "category": "consumable",
  "ingredients": [
    {"item_id": "empty_flask", "quantity": 1},
    {"item_id": "mana_crystal", "quantity": 3},
    {"item_id": "moonpetal", "quantity": 5},
    {"item_id": "arcane_essence", "quantity": 1}
  ],
  "result": {"item_id": "mana_potion_greater", "quantity": 1},
  "requirements": {
    "intelligence": 14,
    "near_fire": true,
    "has_alchemy_kit": true
  },
  "difficulty": 7,
  "stamina_cost": 15,
  "discovery_hints": ["advanced alchemy", "arcane essence", "concentrated mana"],
  "known_by_default": false
}
```

### 22.4 Create Arcane Essence Material
**File:** `data/items/materials/arcane_essence.json`

```json
{
  "id": "arcane_essence",
  "name": "Arcane Essence",
  "description": "Distilled magical energy in its purest form.",
  "category": "material",
  "subcategory": "magical",
  "flags": {"magical": true, "rare": true},
  "weight": 0.1,
  "value": 100,
  "stack_max": 10,
  "ascii_char": "*",
  "ascii_color": "#FF88FF"
}
```

### 22.5 Implement Mana Restoration Effect
**File:** `systems/inventory_system.gd`

```gdscript
func use_consumable(item: Item, user: Entity) -> bool:
    # ... existing consumable logic ...

    # Handle mana restoration
    if "restore_mana" in item.effects:
        var amount = item.effects.restore_mana

        if item.effects.get("restore_mana_percent", false):
            # Restore percentage of max mana
            amount = user.survival.max_mana

        var old_mana = user.survival.mana
        user.survival.mana = mini(user.survival.mana + amount, user.survival.max_mana)
        var restored = user.survival.mana - old_mana

        EventBus.message_logged.emit(
            "You drink the %s. Mana restored: %d" % [item.display_name, restored],
            Color.CYAN
        )
        EventBus.mana_changed.emit(user, user.survival.mana, user.survival.max_mana)

        return true

    return false
```

### 22.6 Add Mana Crystal Drop to Magical Enemies
**File:** `data/loot_tables/enemies/`

Update magical enemy loot tables to include mana crystals:

```json
{
  "id": "skeleton_mage_loot",
  "entries": [
    {"item_id": "gold", "min": 5, "max": 15, "chance": 1.0},
    {"item_id": "mana_crystal", "min": 1, "max": 2, "chance": 0.4},
    {"item_id": "moonpetal", "min": 1, "max": 3, "chance": 0.3},
    {"item_id": "scroll_spark", "chance": 0.2}
  ]
}
```

### 22.7 Add Moonpetal as Harvestable Resource
**File:** `data/resources/overworld/moonpetal_flower.json`

```json
{
  "id": "moonpetal_flower",
  "name": "Moonpetal Flower",
  "description": "A luminescent flower that blooms under moonlight.",
  "ascii_char": ",",
  "ascii_color": "#CCCCFF",
  "harvest_behavior": "destroy_renewable",
  "respawn_turns": 3000,
  "tool_required": null,
  "yields": [
    {"item_id": "moonpetal", "min": 1, "max": 3, "chance": 1.0}
  ],
  "stamina_cost": 2,
  "spawn_biomes": ["forest", "meadow"],
  "spawn_time": "night"
}
```

### 22.8 Add Alchemy Kit Item
**File:** `data/items/tools/alchemy_kit.json`

```json
{
  "id": "alchemy_kit",
  "name": "Alchemy Kit",
  "description": "A set of tools for brewing potions.",
  "category": "tool",
  "subcategory": "crafting",
  "flags": {"tool": true},
  "tool_type": "alchemy",
  "durability": {"current": 50, "max": 50},
  "weight": 2.0,
  "value": 75,
  "ascii_char": "&",
  "ascii_color": "#886644"
}
```

### 22.9 Create Empty Vial and Flask Items
**File:** `data/items/materials/empty_vial.json`

```json
{
  "id": "empty_vial",
  "name": "Empty Vial",
  "description": "A small glass vial for holding liquids.",
  "category": "material",
  "subcategory": "container",
  "weight": 0.1,
  "value": 5,
  "stack_max": 20,
  "ascii_char": "!",
  "ascii_color": "#888888"
}
```

**File:** `data/items/materials/empty_flask.json`

```json
{
  "id": "empty_flask",
  "name": "Empty Flask",
  "description": "A glass flask for holding liquids.",
  "category": "material",
  "subcategory": "container",
  "weight": 0.2,
  "value": 8,
  "stack_max": 15,
  "ascii_char": "!",
  "ascii_color": "#888888"
}
```

### 22.10 Add Mana Potions to Town Mage Shop
**File:** `data/npcs/town/eldric_mage.json`

Update shop inventory:
```json
{
  "shop_inventory": [
    {"item_id": "mana_potion_minor", "stock": 5, "restock_turns": 500},
    {"item_id": "mana_potion", "stock": 2, "restock_turns": 1000},
    {"item_id": "mana_potion_greater", "stock": 1, "restock_turns": 3000},
    {"item_id": "empty_vial", "stock": 10, "restock_turns": 200},
    {"item_id": "alchemy_kit", "stock": 1, "restock_turns": 5000}
  ]
}
```

## Testing Checklist

- [ ] Minor mana potion restores 15 mana
- [ ] Mana potion restores 35 mana
- [ ] Greater mana potion restores 100% mana
- [ ] Mana potions stack correctly
- [ ] Minor mana potion recipe works
- [ ] Mana potion recipe requires mana crystal
- [ ] Greater mana potion recipe requires alchemy kit
- [ ] Moonpetal can be harvested at night
- [ ] Mana crystals drop from magical enemies
- [ ] Eldric sells mana potions
- [ ] Recipe discovery works for mana potions
- [ ] Empty vials returned as byproduct

## Documentation Updates

- [ ] CLAUDE.md updated with mana potion info
- [ ] Help screen updated with potion crafting
- [ ] `docs/data/items.md` updated with potion format
- [ ] `docs/data/recipes.md` updated with mana potion recipes

## Files Modified
- `systems/inventory_system.gd`
- `data/npcs/town/eldric_mage.json`
- Various enemy loot tables

## Files Created
- `data/items/consumables/mana_potion_minor.json`
- `data/items/consumables/mana_potion.json`
- `data/items/consumables/mana_potion_greater.json`
- `data/items/materials/mana_crystal.json`
- `data/items/materials/moonpetal.json`
- `data/items/materials/arcane_essence.json`
- `data/items/materials/empty_vial.json`
- `data/items/materials/empty_flask.json`
- `data/items/tools/alchemy_kit.json`
- `data/recipes/consumables/mana_potion_minor.json`
- `data/recipes/consumables/mana_potion.json`
- `data/recipes/consumables/mana_potion_greater.json`
- `data/resources/overworld/moonpetal_flower.json`

## Next Phase
Once mana potions work, proceed to **Phase 23: Cursed Items**
