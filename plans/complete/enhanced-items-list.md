# Feature - Extend the items list
**Goal**: Create a robust list of items available in the game world
**Status**: COMPLETED

---

## Completed Tasks

### 1. Warmth System for Armor
- Added `warmth: float` property to Item class
- Added `get_total_warmth()` to inventory system
- Integrated equipment warmth into SurvivalSystem temperature calculation

### 2. New Item Templates (AD&D-based)
Created weapon templates:
- dagger, mace, spear, warhammer, quarterstaff

Created armor templates:
- helm, gauntlets, greaves, boots, shield
- Updated chest_armor with warmth value

### 3. Material Variant Updates
Updated materials_armor.json with warmth modifiers:
- cloth (0.5x warmth), padded (1.5x), leather (1x), studded_leather (1x)
- chainmail (0.3x), scale_mail (0.2x), plate (0x - cold metal)
- mithril (0.8x), dragon_scale (2x)

### 4. New Legacy Items
Consumables: healing_potion, stamina_potion, antidote, bread, cheese, ale
Materials: oil, feather, iron_ingot, steel_ingot, charcoal, rope
Armor: cloak, fur_cloak, ring_protection
Added warmth to all leather armor pieces

### 5. Crafting Recipes
Created 16 new recipes:
- Consumables: healing_potion, stamina_potion, bread
- Materials: charcoal, iron_ingot, steel_ingot, rope
- Equipment: leather_boots, leather_cap, leather_gloves, leather_pants, cloak, fur_cloak
- Tools: arrow, iron_arrow, torch

### 6. Light Source System
Verified lanterns already work like torches with:
- provides_light, light_radius, burns_per_turn properties
- is_lit state for toggling
- Same key binding for light/extinguish

### 7. Loot Table Updates
Updated existing tables: ancient_treasure, beast_common, undead_common
Created new tables: shop_general, shop_blacksmith

## Summary
- Items increased from 66 to 81
- Recipes increased to 24
- 16 templates, 5 variant types
- All systems verified working


