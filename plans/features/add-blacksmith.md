# Feature: Add Blacksmith

**Goal**: Add a blacksmith NPC who sells metal weapons/armor and can train the player in metalworking crafts, with forge and anvil workstations for metal crafting.

---

## Overview

The starter town (Thornhaven) will have a blacksmith shop building containing a blacksmith NPC, a forge, and an anvil. The blacksmith serves dual purposes: as a merchant selling iron and steel weapons and armor, and as a trainer who teaches metalworking recipes.

The forge and anvil are new workstation types that recipes can require, similar to how some recipes currently require fire. Metal smelting recipes (ingots) require the forge, while metal shaping recipes (weapons, armor) require the anvil. Using the anvil requires having a hammer in inventory, and using the forge requires having tongs.

---

## Core Mechanics

### Workstation System

Expand the existing proximity crafting system to support multiple workstation types:

- **Fire source**: Existing system - campfires, lit torches, etc. (3 tile radius)
- **Forge**: New workstation for smelting metal (requires tongs in inventory)
- **Anvil**: New workstation for shaping metal (requires hammer in inventory)

### Tool Requirements for Workstations

Unlike `tool_required` in recipes (which checks if player has a specific tool type), workstation tools are required to *use the workstation itself*:

- **Forge**: Player must have `tongs` in inventory (not necessarily equipped)
- **Anvil**: Player must have `hammer` in inventory (not necessarily equipped)

If the player lacks the required tool, display a message like:
- "You need tongs to use the forge."
- "You need a hammer to use the anvil."

Tool durability is consumed when crafting at the workstation.

### Recipe Requirements

Recipes will use a new `workstation_required` field:

```json
{
  "workstation_required": "forge"  // or "anvil", or "" for none
}
```

This replaces `fire_required` for forge recipes (forge provides fire). Recipes requiring both forging AND shaping should use `"anvil"` since the blacksmith shop has both.

---

## Data Structures

### New Tool: Tongs

```json
// data/items/tools/tongs.json
{
  "id": "tongs",
  "name": "Tongs",
  "description": "Metal tongs for handling hot materials at the forge.",
  "category": "tool",
  "subtype": "tongs",
  "flags": {
    "equippable": false,
    "consumable": false,
    "craftable": true,
    "tool": true
  },
  "weight": 0.5,
  "value": 15,
  "max_stack": 1,
  "ascii_char": "(",
  "ascii_color": "#8B8B8B",
  "durability": 100,
  "tool_type": "tongs"
}
```

### New Structure: Forge

```json
// data/structures/forge.json
{
  "id": "forge",
  "name": "Forge",
  "description": "A hot forge for smelting metals. Requires tongs to use.",
  "ascii_char": "&",
  "ascii_color": "#FF4500",
  "blocks_movement": true,
  "structure_type": "forge",
  "durability": -1,
  "components": {
    "fire": {
      "heat_radius": 2,
      "temperature_bonus": 25.0,
      "light_radius": 3
    },
    "workstation": {
      "workstation_type": "forge",
      "required_tool": "tongs",
      "tool_durability_cost": 1
    }
  }
}
```

### New Structure: Anvil

```json
// data/structures/anvil.json
{
  "id": "anvil",
  "name": "Anvil",
  "description": "A heavy anvil for shaping metal. Requires a hammer to use.",
  "ascii_char": "n",
  "ascii_color": "#505050",
  "blocks_movement": true,
  "structure_type": "anvil",
  "durability": -1,
  "components": {
    "workstation": {
      "workstation_type": "anvil",
      "required_tool": "hammer",
      "tool_durability_cost": 1
    }
  }
}
```

### New NPC: Blacksmith

```json
// data/npcs/blacksmith.json
{
  "id": "blacksmith",
  "name": "Brom Ironhand",
  "npc_type": "shop",
  "ascii_char": "@",
  "ascii_color": "#CD853F",
  "faction": "neutral",
  "gold": 400,
  "restock_interval": 500,
  "dialogue": {
    "greeting": "The forge runs hot today! Looking for quality metalwork?",
    "training": "I can teach you the ways of the smith. It's honest work.",
    "farewell": "May your blade stay sharp.",
    "no_gold": "No coin, no steel. That's how it works."
  },
  "trade_inventory": [
    {"item_id": "iron_ingot", "count": 10, "base_price": 15},
    {"item_id": "steel_ingot", "count": 5, "base_price": 40},
    {"item_id": "iron_sword", "count": 2, "base_price": 50},
    {"item_id": "iron_knife", "count": 3, "base_price": 25},
    {"item_id": "iron_arrow", "count": 20, "base_price": 3},
    {"item_id": "hammer", "count": 2, "base_price": 25},
    {"item_id": "tongs", "count": 2, "base_price": 20},
    {"item_id": "chainmail_chest_armor", "count": 1, "base_price": 120},
    {"item_id": "chainmail_helm", "count": 1, "base_price": 60},
    {"item_id": "iron_shield", "count": 1, "base_price": 45}
  ],
  "recipes_for_sale": [
    {"recipe_id": "iron_ingot", "base_price": 30},
    {"recipe_id": "steel_ingot", "base_price": 75},
    {"recipe_id": "iron_sword", "base_price": 50},
    {"recipe_id": "iron_dagger", "base_price": 35},
    {"recipe_id": "iron_mace", "base_price": 45},
    {"recipe_id": "iron_spear", "base_price": 40},
    {"recipe_id": "chainmail_chest_armor", "base_price": 100},
    {"recipe_id": "chainmail_helm", "base_price": 60},
    {"recipe_id": "chainmail_gauntlets", "base_price": 50},
    {"recipe_id": "chainmail_greaves", "base_price": 55},
    {"recipe_id": "iron_shield", "base_price": 45},
    {"recipe_id": "tongs", "base_price": 20}
  ]
}
```

### New Building: Blacksmith Shop

```json
// data/buildings/blacksmith.json
{
  "id": "blacksmith",
  "name": "Blacksmith",
  "description": "A smithy with forge and anvil for metalworking.",
  "size": [10, 7],
  "template_type": "custom",
  "layout": [
    "##########",
    "#........#",
    "#.&..n.@.#",
    "#........#",
    "#..####..#",
    "#........#",
    "####+#####"
  ],
  "legend": {
    "&": "forge",
    "n": "anvil",
    "@": "npc_spawn"
  }
}
```

### Updated Recipe Format

Recipes requiring workstations use the new `workstation_required` field:

```json
// Example: data/recipes/materials/iron_ingot.json (updated)
{
  "id": "iron_ingot",
  "result": "iron_ingot",
  "result_count": 1,
  "ingredients": [
    {"item": "iron_ore", "count": 2},
    {"item": "charcoal", "count": 1}
  ],
  "tool_required": "",
  "workstation_required": "forge",
  "difficulty": 2,
  "discovery_hint": "Smelting ore with fuel at a forge produces pure metal"
}
```

---

## Implementation Plan

### Phase 1: Core Infrastructure

1. Add `workstation_required` field to Recipe class
2. Create workstation component for structures
3. Update CraftingSystem to check workstation proximity
4. Add workstation tool requirement validation
5. Add tool durability consumption on workstation use

### Phase 2: New Items and Structures

1. Create tongs.json tool definition
2. Create forge.json structure definition
3. Create anvil.json structure definition
4. Create chainmail armor items (chest, helm, gauntlets, greaves, boots)
5. Create iron shield item
6. Create iron weapon variants (dagger, mace, spear)

### Phase 3: Recipes

1. Update iron_ingot recipe with `workstation_required: "forge"`
2. Update steel_ingot recipe with `workstation_required: "forge"`
3. Create iron weapon recipes (sword, dagger, mace, spear) with `workstation_required: "anvil"`
4. Create chainmail armor recipes with `workstation_required: "anvil"`
5. Create iron shield recipe with `workstation_required: "anvil"`
6. Create tongs recipe (anvil required)

### Phase 4: NPC and Building

1. Create blacksmith.json NPC definition
2. Create blacksmith.json building definition with forge and anvil placement
3. Update starter_town.json to include blacksmith building
4. Update TownGenerator to handle structure placement from building layouts

### Phase 5: UI Updates

1. Update crafting screen to show workstation requirements
2. Add workstation proximity indicator to crafting UI
3. Display tool requirement messages when missing tongs/hammer

---

## New Files Required

### Data Files

```
data/
├── items/
│   ├── tools/
│   │   └── tongs.json
│   ├── weapons/
│   │   ├── iron_dagger.json
│   │   ├── iron_mace.json
│   │   └── iron_spear.json
│   └── armor/
│       ├── chainmail_chest_armor.json
│       ├── chainmail_helm.json
│       ├── chainmail_gauntlets.json
│       ├── chainmail_greaves.json
│       ├── chainmail_boots.json
│       └── iron_shield.json
├── structures/
│   ├── forge.json
│   └── anvil.json
├── npcs/
│   └── blacksmith.json
├── buildings/
│   └── blacksmith.json
└── recipes/
    ├── weapons/
    │   ├── iron_sword.json
    │   ├── iron_dagger.json
    │   ├── iron_mace.json
    │   └── iron_spear.json
    ├── armor/
    │   ├── chainmail_chest_armor.json
    │   ├── chainmail_helm.json
    │   ├── chainmail_gauntlets.json
    │   ├── chainmail_greaves.json
    │   ├── chainmail_boots.json
    │   └── iron_shield.json
    └── tools/
        └── tongs.json
```

### Code Files

```
systems/
└── components/
    └── workstation_component.gd  (new)
```

### Modified Files

- `crafting/recipe.gd` - Add `workstation_required` field and validation
- `systems/crafting_system.gd` - Add workstation proximity check, tool validation, durability consumption
- `ui/crafting_screen.gd` - Display workstation requirements and missing tool messages
- `autoload/structure_manager.gd` - Add workstation lookup methods
- `generation/town_generator.gd` - Handle structure placement from building layouts
- `data/recipes/materials/iron_ingot.json` - Change to `workstation_required: "forge"`
- `data/recipes/materials/steel_ingot.json` - Change to `workstation_required: "forge"`
- `data/towns/starter_town.json` - Add blacksmith building

---

## UI Messages

- "You need tongs to use the forge." - When attempting to craft at forge without tongs
- "You need a hammer to use the anvil." - When attempting to craft at anvil without hammer
- "Requires: Forge (within 3 tiles)" - In crafting screen for forge recipes
- "Requires: Anvil (within 3 tiles)" - In crafting screen for anvil recipes
- "Forge: Available" / "Forge: Not found" - Workstation status indicator
- "Anvil: Available" / "Anvil: Not found" - Workstation status indicator

---

## Future Enhancements

1. **Steel variants**: Add steel weapon/armor recipes once steel ingots are easier to obtain
2. **Advanced smithing**: Higher-tier materials (silver, eventually mithril from special vendors)
3. **Repair system**: Use blacksmith to repair damaged equipment
4. **Tempering/enchanting**: Apply bonuses to weapons at the forge
5. **Player-buildable forge/anvil**: Allow crafting portable versions for wilderness smithing

---

## Testing Checklist

- [ ] Blacksmith building appears in Thornhaven with forge and anvil inside
- [ ] Blacksmith NPC spawns inside the building
- [ ] Player can buy weapons and armor from blacksmith
- [ ] Player can learn metalworking recipes from blacksmith
- [ ] Forge recipes require being near forge (3 tiles)
- [ ] Anvil recipes require being near anvil (3 tiles)
- [ ] "You need tongs" message appears when trying to use forge without tongs
- [ ] "You need a hammer" message appears when trying to use anvil without hammer
- [ ] Tongs lose durability when crafting at forge
- [ ] Hammer loses durability when crafting at anvil
- [ ] Iron ingot recipe works at forge with tongs
- [ ] Steel ingot recipe works at forge with tongs
- [ ] Iron sword recipe works at anvil with hammer
- [ ] Chainmail armor recipes work at anvil with hammer
- [ ] Crafting screen shows workstation requirements
- [ ] Crafting screen shows workstation availability status
