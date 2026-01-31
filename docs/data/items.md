# Items Data Format

**Location**: `data/items/`
**Subdirectories**: `ammunition/`, `armor/`, `consumables/`, `materials/`, `misc/`, `tools/`, `weapons/`
**File Count**: 57 files
**Loaded By**: ItemManager

## Overview

Items are all objects that can be carried, used, equipped, or traded. Every item in the game is defined by a JSON file in one of the item subdirectories. The ItemManager autoload recursively loads all JSON files at startup.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique identifier (snake_case) | All systems |
| `name` | string | Display name | UI, messages |
| `category` | string | Item type (see categories below) | InventorySystem, UI |
| `weight` | float | Weight in kilograms | InventorySystem |
| `value` | int | Base gold value | ShopSystem |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `description` | string | "" | Item description text | UI tooltips |
| `subtype` | string | "" | Subcategory (sword, food, etc.) | UI filtering |
| `max_stack` | int | 1 | Maximum stack size | InventorySystem |
| `ascii_char` | string | "?" | Display character | Renderer |
| `ascii_color` | string | "#FFFFFF" | Hex color code | Renderer |
| `durability` | int | -1 | Max durability (-1 = indestructible) | Future durability system |
| `transforms_into` | string | "" | Item ID to create when consumed | InventorySystem |
| `provides_ingredient` | string | "" | Item ID this item can substitute in crafting | CraftingSystem |

## Categories

| Category | Description | Typical Properties |
|----------|-------------|-------------------|
| `weapon` | Combat weapons | damage_bonus, attack_type, equip_slots |
| `armor` | Protective gear | armor_value, equip_slots |
| `consumable` | Food, potions | effects, flags.consumable |
| `material` | Crafting materials | max_stack (usually high) |
| `tool` | Harvesting/crafting tools | tool_types, equip_slots |
| `misc` | Quest items, treasures | value |
| `currency` | Money | max_stack |
| `ammunition` | Projectiles | ammunition_type, recovery_chance |

## Flags Object

The `flags` object contains boolean properties:

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `equippable` | bool | false | Can be equipped to a slot |
| `consumable` | bool | false | Can be used/consumed |
| `craftable` | bool | false | Can be crafted from recipe |
| `tool` | bool | false | Used for harvesting/crafting |
| `two_handed` | bool | false | Requires both hands (blocks off_hand) |
| `ammunition` | bool | false | Is ammunition for ranged weapons |
| `key` | bool | false | Is a key (specific or skeleton) |
| `skeleton_key` | bool | false | Is a skeleton key (works on multiple locks) |

## Category-Specific Properties

### Weapons

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `damage_bonus` | int | 0 | Damage added to attacks |
| `attack_type` | string | "melee" | "melee", "ranged", or "thrown" |
| `attack_range` | int | 1 | Range in tiles (ranged/thrown) |
| `ammunition_type` | string | "" | Required ammo ID for ranged weapons |
| `accuracy_modifier` | int | 0 | Added to accuracy rolls |
| `equip_slots` | array | [] | Valid slots: ["main_hand"] |

**Weapon Types**:
- `melee`: Standard bump-to-attack weapons
- `ranged`: Bows, crossbows, slings (require ammunition)
- `thrown`: Throwing knives, axes (consumed on use)

### Armor

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `armor_value` | int | 0 | Flat damage reduction |
| `equip_slots` | array | [] | Valid slots for this armor |
| `stat_modifiers` | object | {} | Attribute bonuses when equipped |

**Equipment Slots**:
- Head: `["head"]`
- Body: `["torso"]`
- Hands: `["hands"]`
- Legs: `["legs"]`
- Feet: `["feet"]`
- Shield: `["off_hand"]`
- Accessory: `["accessory"]` (maps to accessory_1 or accessory_2)

### Consumables

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `effects` | object | {} | Effects when consumed |
| `effects.hunger` | float | 0 | Hunger restored |
| `effects.thirst` | float | 0 | Thirst restored |
| `effects.healing` | int | 0 | Health restored |
| `effects.stamina` | float | 0 | Stamina restored |

### Ammunition

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ammunition_type` | string | "" | Type ID (matches weapon requirement) |
| `damage_bonus` | int | 0 | Added to weapon damage |
| `recovery_chance` | float | 0.5 | Probability of recovery (0.0-1.0) |

**IMPORTANT**: `recovery_chance` must use decimal format (0.0-1.0), not percentages.

### Tools

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `tool_types` | array | [] | Tool categories (axe, pickaxe, knife) |
| `equip_slots` | array | [] | Usually ["main_hand"] |

### Keys & Lockpicks

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `key_id` | string | "" | Lock ID this key opens (specific keys) |
| `skeleton_key_level` | int | 0 | Max lock level this key can open (skeleton keys) |
| `tool_type` | string | "" | Set to "lockpick" for lockpicks |

**Key Types**:
- **Specific Key**: Has `key_id` matching a lock's `lock_id`, always opens that lock
- **Skeleton Key**: Has `skeleton_key_level`, opens any lock with `lock_level <= skeleton_key_level`
- **Lockpick**: Has `tool_type: "lockpick"`, uses DEX skill check to open locks

## Property Details

### `id`
**Type**: string
**Required**: Yes

Unique identifier for the item. Must be unique across ALL items. Use snake_case format.

**Conventions**:
- All lowercase
- Words separated by underscores
- Descriptive but concise

**Examples**: `iron_sword`, `leather_armor`, `cooked_meat`, `short_bow`

### `weight`
**Type**: float
**Required**: Yes
**Unit**: Kilograms

Mass of the item affecting encumbrance calculations.

**Conventions**:
- Small items: 0.05-0.5 kg
- Medium items: 0.5-2.0 kg
- Heavy items: 2.0-10.0 kg

**Used by**: InventorySystem for encumbrance calculations

### `damage_bonus`
**Type**: int
**Required**: No (weapons/ammunition only)
**Default**: 0

The flat damage value added to attack damage.

**For melee weapons**: This is the weapon's base damage
**For ranged weapons**: Added to ammunition damage
**For ammunition**: Added to weapon damage
**For thrown weapons**: This is the base damage (+ STR modifier)

**Formula**: `Damage = weapon.damage_bonus + ammo.damage_bonus + STR_modifier - target_armor`

### `recovery_chance`
**Type**: float (0.0 - 1.0)
**Required**: No (ammunition/thrown only)
**Default**: 0.5

Probability that ammunition or thrown weapons can be recovered after use.

**On hit**: Full chance applies
**On miss**: Reduced to 70% of base value

**CRITICAL**: Always use decimal format:
- Correct: `"recovery_chance": 0.85` (85%)
- Wrong: `"recovery_chance": 85`

### `effects`
**Type**: object
**Required**: No (consumables only)

Effects applied when item is consumed.

| Effect | Type | Description |
|--------|------|-------------|
| `hunger` | float | Points added to hunger (0-100 scale) |
| `thirst` | float | Points added to thirst (0-100 scale) |
| `healing` | int | Health points restored |
| `stamina` | float | Stamina points restored |

### `equip_slots`
**Type**: array of strings
**Required**: No (equippable items only)

List of valid equipment slots. Item can be equipped to any slot in this list.

**Valid slots**: `head`, `torso`, `hands`, `legs`, `feet`, `main_hand`, `off_hand`, `accessory`

**Note**: `accessory` automatically maps to `accessory_1` or `accessory_2`

### `transforms_into`
**Type**: string
**Required**: No
**Default**: ""

Item ID to create when this item is consumed. Used for reusable containers.

**Example**: `waterskin_full` transforms into `waterskin_empty` when drunk.

### `provides_ingredient`
**Type**: string
**Required**: No
**Default**: ""

Item ID that this item can substitute for in crafting recipes. Used for containers that hold ingredients.

When a recipe requires an ingredient (e.g., `fresh_water`), the crafting system will also accept items that have `provides_ingredient` set to that ingredient ID. When consumed during crafting, the provider item transforms (via `transforms_into`) instead of being destroyed.

**Example**: `waterskin_full` has `provides_ingredient: "fresh_water"` and `transforms_into: "waterskin_empty"`. When a recipe requires `fresh_water`, the waterskin can be used and it transforms to empty.

**Use Cases**:
- Water containers providing `fresh_water` for potions
- Oil lamps providing `oil` for lantern crafting
- Any container whose contents are the actual ingredient

## Complete Examples

### Melee Weapon
```json
{
  "id": "iron_sword",
  "name": "Iron Sword",
  "description": "A well-crafted iron sword.",
  "category": "weapon",
  "subtype": "sword",
  "flags": {
    "equippable": true,
    "consumable": false,
    "craftable": true,
    "tool": false
  },
  "weight": 1.5,
  "value": 40,
  "max_stack": 1,
  "ascii_char": "|",
  "ascii_color": "#AAAAAA",
  "durability": 100,
  "equip_slots": ["main_hand"],
  "damage_bonus": 6
}
```

### Ranged Weapon
```json
{
  "id": "short_bow",
  "name": "Short Bow",
  "description": "A compact bow suitable for hunting small game.",
  "category": "weapon",
  "subtype": "bow",
  "attack_type": "ranged",
  "attack_range": 10,
  "ammunition_type": "arrow",
  "accuracy_modifier": 5,
  "flags": {
    "equippable": true,
    "two_handed": true,
    "craftable": true
  },
  "weight": 1.0,
  "value": 25,
  "max_stack": 1,
  "ascii_char": ")",
  "ascii_color": "#8B7355",
  "durability": 60,
  "equip_slots": ["main_hand", "off_hand"],
  "damage_bonus": 3
}
```

### Ammunition
```json
{
  "id": "arrow",
  "name": "Arrow",
  "description": "A simple wooden arrow with a stone tip.",
  "category": "ammunition",
  "ammunition_type": "arrow",
  "flags": {
    "ammunition": true,
    "craftable": true
  },
  "weight": 0.05,
  "value": 2,
  "max_stack": 20,
  "ascii_char": "/",
  "ascii_color": "#8B7355",
  "damage_bonus": 1,
  "recovery_chance": 0.85
}
```

### Armor
```json
{
  "id": "leather_armor",
  "name": "Leather Armor",
  "description": "Sturdy leather armor that provides basic protection.",
  "category": "armor",
  "subtype": "body",
  "flags": {
    "equippable": true,
    "consumable": false,
    "craftable": true,
    "tool": false
  },
  "weight": 3.0,
  "value": 30,
  "max_stack": 1,
  "ascii_char": "[",
  "ascii_color": "#8B4513",
  "durability": 100,
  "equip_slots": ["torso"],
  "armor_value": 3
}
```

### Consumable
```json
{
  "id": "cooked_meat",
  "name": "Cooked Meat",
  "description": "Well-cooked meat. Nutritious and safe to eat.",
  "category": "consumable",
  "subtype": "food",
  "flags": {
    "equippable": false,
    "consumable": true,
    "craftable": true,
    "tool": false
  },
  "weight": 0.25,
  "value": 5,
  "max_stack": 10,
  "ascii_char": "%",
  "ascii_color": "#884422",
  "effects": {
    "hunger": 35
  }
}
```

### Material
```json
{
  "id": "iron_ore",
  "name": "Iron Ore",
  "description": "Raw iron ore that can be smelted into iron.",
  "category": "material",
  "flags": {
    "craftable": false
  },
  "weight": 0.5,
  "value": 5,
  "max_stack": 20,
  "ascii_char": "*",
  "ascii_color": "#8B8682"
}
```

### Tool
```json
{
  "id": "axe",
  "name": "Axe",
  "description": "A sturdy axe for chopping wood.",
  "category": "tool",
  "subtype": "axe",
  "tool_types": ["axe"],
  "flags": {
    "equippable": true,
    "tool": true
  },
  "weight": 2.0,
  "value": 15,
  "max_stack": 1,
  "ascii_char": "P",
  "ascii_color": "#8B8682",
  "durability": 80,
  "equip_slots": ["main_hand"],
  "damage_bonus": 3
}
```

### Lockpick
```json
{
  "id": "lockpick",
  "name": "Lockpick",
  "description": "A set of metal picks for opening locks.",
  "category": "tool",
  "tool_type": "lockpick",
  "flags": {
    "tool": true
  },
  "weight": 0.1,
  "value": 15,
  "max_stack": 10,
  "ascii_char": "-",
  "ascii_color": "#AAAAAA"
}
```

### Skeleton Key
```json
{
  "id": "skeleton_key_basic",
  "name": "Basic Skeleton Key",
  "description": "A crude skeleton key that can open simple locks.",
  "category": "misc",
  "subtype": "skeleton_key",
  "flags": {
    "key": true,
    "skeleton_key": true
  },
  "weight": 0.1,
  "value": 75,
  "max_stack": 1,
  "ascii_char": "k",
  "ascii_color": "#AAAAAA",
  "skeleton_key_level": 2
}
```

## Validation Rules

1. `id` must be unique across all items
2. `id` should use snake_case format
3. `category` must be one of: weapon, armor, consumable, material, tool, misc, currency, ammunition
4. `weight` must be positive (in kilograms)
5. `value` must be non-negative (in gold)
6. `recovery_chance` must be 0.0-1.0 (not 0-100)
7. `attack_range` must be positive integer (in tiles)
8. `max_stack` must be at least 1
9. `equip_slots` must contain valid slot names
10. `ammunition_type` on weapons must match an ammunition item's `ammunition_type`

## File Organization

Items are organized by category in subdirectories:

```
data/items/
├── ammunition/     # Arrows, bolts, sling stones
├── armor/          # All protective equipment
├── consumables/    # Food, potions, medicine
├── materials/      # Crafting materials
├── misc/           # Quest items, treasures
├── tools/          # Harvesting and crafting tools
└── weapons/        # All combat weapons
```

## Related Documentation

- [Combat System](../systems/combat-system.md) - How damage_bonus and armor_value are used
- [Ranged Combat System](../systems/ranged-combat-system.md) - Ranged weapon and ammunition mechanics
- [Inventory System](../systems/inventory-system.md) - Equipment and weight management
- [Survival System](../systems/survival-system.md) - Consumable effects
- [Recipes Data](./recipes.md) - Crafting requirements
