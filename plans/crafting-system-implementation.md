# Crafting System Implementation Plan - Phase 1.11

**Scope**: Task 1.11 (Crafting) from PRD
**Branch**: `feature/crafting-system`
**Goal**: Discovery-based crafting with recipe memory, tool requirements, and proximity crafting

---

## Overview

Phase 1.11 implements the crafting system that allows players to combine items to create new items. The system is **discovery-based** - players don't start with a recipe book. Recipes are learned through:
- Experimentation (combining items)
- Recipe scrolls/books (future)
- NPC teaching (future)
- Examining crafted items (future)

---

## Crafting System Reference (from PRD)

### Discovery-Based Approach
- No recipe book at start
- Players experiment with item combinations
- Successful craft = recipe remembered
- Failed craft = components consumed, nothing produced

### Crafting Process
1. Select 2-4 components from inventory
2. (Optional) Select tool if owned
3. Attempt craft
4. **Success**: Item created, recipe remembered
5. **Failure**: Components consumed, nothing produced

### Discovery Hints
- INT affects hint quality when examining unknown combinations
- High INT might reveal: "These materials could make something protective"
- Low INT: No hints

### Tools
- Required for certain recipes (not stations)
- Tools in inventory enable recipes, not consumed
- Examples: Knife, Hammer, Needle & Thread, Pestle
- Tools have durability, degrade with use

### Material Variants
- Base recipe + material quality = output quality
- Example: Knife recipe
  - Flint + Wood = Flint Knife (damage 2)
  - Iron + Wood = Iron Knife (damage 4, +durability)
  - Steel + Wood = Steel Knife (damage 5, ++durability)

### Proximity Crafting
Some recipes require proximity to a heat/fire source rather than a tool:
- Player must be within 3 tiles of campfire or other fire source
- Fire source checked at craft attempt time
- **UI indication**:
  - HUD shows "Near fire" text when in range
  - Crafting screen shows fire-required recipes as available/unavailable
  - Unavailable fire recipes display "Fire required" in red

---

## Phase 1 Recipes (from PRD)

### Consumables
| Result | Ingredients | Tool/Requirement | Difficulty |
|--------|-------------|------------------|------------|
| Cooked Meat | Raw Meat | Fire (3 tiles) | 1 |
| Bandage | Cloth + Herb | None | 1 |
| Waterskin | Leather + Cord | Knife | 2 |

### Tools
| Result | Ingredients | Tool/Requirement | Difficulty |
|--------|-------------|------------------|------------|
| Flint Knife | Flint + Wood | None | 1 |
| Iron Knife | Iron Ore + Wood | Hammer | 3 |
| Hammer | Iron Ore + Wood ×2 | None | 2 |

### Equipment
| Result | Ingredients | Tool/Requirement | Difficulty |
|--------|-------------|------------------|------------|
| Leather Armor | Leather ×3 + Cord | Knife | 3 |
| Wooden Shield | Wood ×2 + Cord | Knife | 2 |

**Total**: 8 recipes for Phase 1

---

## Implementation Components

### 1. Recipe Data Structure
**File**: `res://crafting/recipe.gd`
**Status**: ⬜ Pending

**Purpose**: Represents a single crafting recipe

**Properties:**
```gdscript
class_name Recipe
extends RefCounted

var id: String                      # Unique identifier (e.g., "leather_armor")
var result_item_id: String          # Item ID to create
var result_count: int = 1           # How many items produced
var ingredients: Array[Dictionary] = []  # [{item_id: String, count: int}]
var tool_required: String = ""      # Tool type needed ("knife", "hammer", "")
var fire_required: bool = false     # Must be near fire?
var difficulty: int = 1             # Base difficulty (1-5)
var discovery_hint: String = ""     # INT-based hint text
```

**Key Methods:**
```gdscript
static func create_from_data(data: Dictionary) -> Recipe
func has_requirements(inventory: Inventory, near_fire: bool) -> bool
func get_missing_requirements(inventory: Inventory, near_fire: bool) -> Array[String]
func consume_ingredients(inventory: Inventory) -> bool
```

---

### 2. Recipe Data Files
**Location**: `res://data/recipes/`
**Status**: ⬜ Pending

**Structure:**
- `recipes.json` - All Phase 1 recipes in one file

**Example Recipe Data:**
```json
{
  "recipes": [
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
    },
    {
      "id": "bandage",
      "result": "bandage",
      "result_count": 1,
      "ingredients": [
        {"item": "cloth", "count": 1},
        {"item": "herb", "count": 1}
      ],
      "tool_required": "",
      "fire_required": false,
      "difficulty": 1,
      "discovery_hint": "Medicinal plants and fabric make effective wound dressing"
    },
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
      "discovery_hint": "Protective garment from animal hides"
    }
  ]
}
```

---

### 3. Recipe Manager (Autoload)
**File**: `res://autoload/recipe_manager.gd`
**Status**: ⬜ Pending

**Purpose**: Loads and caches recipe definitions, provides recipe lookup

**Key Properties:**
```gdscript
var all_recipes: Dictionary = {}  # recipe_id -> Recipe
var recipes_by_result: Dictionary = {}  # result_item_id -> Array[Recipe]
```

**Key Methods:**
```gdscript
func _ready():
    _load_all_recipes()

func get_recipe(recipe_id: String) -> Recipe
func get_recipes_for_item(item_id: String) -> Array[Recipe]
func find_recipe_by_ingredients(ingredient_ids: Array[String]) -> Recipe
func get_all_recipe_ids() -> Array[String]
```

---

### 4. Crafting System
**File**: `res://systems/crafting_system.gd`
**Status**: ⬜ Pending

**Purpose**: Handles crafting attempts, success/failure logic, discovery

**Key Methods:**
```gdscript
static func attempt_craft(player: Player, recipe: Recipe, near_fire: bool) -> Dictionary:
    # Returns: {success: bool, result_item: Item, message: String}
    # 1. Check if has all ingredients
    # 2. Check tool requirement
    # 3. Check fire requirement
    # 4. Calculate success chance (base 100% - difficulty penalty)
    # 5. Roll for success
    # 6. Consume ingredients
    # 7. Create result item (if success)
    # 8. Remember recipe (if success and not already known)
    # 9. Emit signals
    # 10. Return result

static func get_discovery_hint(recipe: Recipe, intelligence: int) -> String:
    # High INT = show hint
    # Low INT = "You're not sure what these could make"

static func calculate_success_chance(difficulty: int, intelligence: int) -> float:
    # Base 100% for difficulty 1
    # -10% per difficulty level
    # +5% per INT point above 10
    # Minimum 50% chance

static func is_near_fire(player_pos: Vector2i) -> bool:
    # Check 3-tile radius for fire sources
    # Fire sources: campfire, torches (future), other fire entities
```

---

### 5. Event Bus Crafting Signals
**File**: `res://autoload/event_bus.gd`
**Status**: ⬜ Pending

**New Signals:**
```gdscript
signal craft_attempted(recipe: Recipe, success: bool)
signal craft_succeeded(recipe: Recipe, result: Item)
signal craft_failed(recipe: Recipe)
signal recipe_discovered(recipe: Recipe)
```

---

### 6. Player Recipe Memory
**File**: `res://entities/player.gd`
**Status**: ⬜ Pending

**New Properties:**
```gdscript
var known_recipes: Array[String] = []  # Array of recipe IDs
```

**New Methods:**
```gdscript
func knows_recipe(recipe_id: String) -> bool
func learn_recipe(recipe_id: String) -> void
func get_known_recipes() -> Array[Recipe]
func get_craftable_recipes() -> Array[Recipe]:
    # Returns recipes player knows AND has ingredients for
```

---

### 7. Fire Source Detection
**File**: `res://maps/tile_data.gd` and `res://entities/entity.gd`
**Status**: ⬜ Pending

**Approach 1: Tile-based** (for Phase 1.13 campfires)
- Add `is_fire_source: bool` to TileData
- Campfire tiles set this to true

**Approach 2: Entity-based** (for portable fire items)
- Add `is_fire_source: bool` to Entity
- Campfire, torch entities set this to true

**Detection Logic:**
```gdscript
static func is_near_fire(player_pos: Vector2i) -> bool:
    var fire_range = 3
    for offset_x in range(-fire_range, fire_range + 1):
        for offset_y in range(-fire_range, fire_range + 1):
            var check_pos = player_pos + Vector2i(offset_x, offset_y)

            # Check tiles
            var tile = MapManager.current_map.get_tile(check_pos)
            if tile and tile.is_fire_source:
                return true

            # Check entities
            var entities = EntityManager.get_entities_at(check_pos)
            for entity in entities:
                if entity.is_fire_source:
                    return true

    return false
```

---

### 8. Crafting UI Screen
**File**: `res://ui/crafting_screen.tscn` and `res://ui/crafting_screen.gd`
**Status**: ⬜ Pending

**Features:**
- Recipe list (known recipes)
- Ingredient requirements display
- Tool requirement indicator
- Fire requirement indicator
- Success chance display
- "Craft" button (consumes ingredients, attempts craft)
- Discovery mode: Select 2-4 items manually to experiment

**ASCII-Style UI:**
```
╔════════════════════════════════════════════════════╗
║             CRAFTING                               ║
║ Near Fire: [YES] / [NO]                           ║
╠════════════════════════════════════════════════════╣
║ KNOWN RECIPES:                                     ║
║ > Bandage                     [Can Craft]          ║
║   Cloth x1, Herb x1                               ║
║   Tool: None                  Success: 100%       ║
║                                                    ║
║   Leather Armor               [Missing: Knife]     ║
║   Leather x3, Cord x1                             ║
║   Tool: Knife                 Success: 85%        ║
║                                                    ║
║   Cooked Meat                 [Fire Required]     ║
║   Raw Meat x1                                     ║
║   Requirement: Fire (3 tiles) Success: 100%       ║
╠════════════════════════════════════════════════════╣
║ EXPERIMENT:                                        ║
║ Select 2-4 items to try crafting                  ║
║ [ ] Raw Meat  [ ] Cloth  [ ] Herb  [ ] Leather   ║
╠════════════════════════════════════════════════════╣
║ [C]raft [E]xperiment [X]Close                     ║
╚════════════════════════════════════════════════════╝
```

**Discovery Experiment Mode:**
1. Player selects 2-4 items from inventory
2. Click "Experiment"
3. System checks if combination matches a recipe
4. If match found:
   - Attempt craft (success/failure based on difficulty)
   - Learn recipe on success
5. If no match:
   - Show discovery hint based on INT
   - Consume components anyway (failed experiment)

---

### 9. Input Handler Updates
**File**: `res://systems/input_handler.gd`
**Status**: ⬜ Pending

**New Input Actions:**
- `crafting` (C key) - Open crafting screen

---

### 10. HUD Fire Indicator
**File**: `res://ui/hud.tscn` and `res://ui/hud.gd`
**Status**: ⬜ Pending

**Feature:**
- Display "🔥 Near Fire" when player is within 3 tiles of fire source
- Update every turn/movement

---

## Implementation Order

### Stage 1: Data Foundation
1. ✅ Review PRD recipes
2. Create Recipe class (`crafting/recipe.gd`)
3. Create recipe JSON data (`data/recipes/recipes.json`)
4. Create RecipeManager autoload (`autoload/recipe_manager.gd`)
5. Add crafting signals to EventBus
6. Register RecipeManager in `project.godot`

### Stage 2: Core Crafting Logic
7. Create CraftingSystem (`systems/crafting_system.gd`)
8. Implement `attempt_craft()` logic
9. Implement success chance calculation
10. Implement discovery hints
11. Add fire source detection

### Stage 3: Player Integration
12. Add `known_recipes` to Player
13. Implement recipe learning/memory
14. Add crafting methods to Player

### Stage 4: UI & Interaction
15. Create crafting screen scene (`ui/crafting_screen.tscn`)
16. Implement recipe list display
17. Implement experiment mode
18. Add HUD fire indicator
19. Add crafting input to InputHandler

### Stage 5: Testing & Polish
20. Test all 8 Phase 1 recipes
21. Test success/failure paths
22. Test recipe discovery
23. Test fire proximity detection
24. Balance success rates

---

## Testing Checklist

### Recipe Loading
- [ ] All 8 Phase 1 recipes load from JSON
- [ ] RecipeManager creates Recipe instances correctly
- [ ] Recipes have correct ingredients/requirements

### Crafting Attempts
- [ ] Successful craft creates item
- [ ] Successful craft consumes ingredients
- [ ] Successful craft remembers recipe
- [ ] Failed craft consumes ingredients
- [ ] Failed craft doesn't create item
- [ ] Cannot craft without required tool
- [ ] Cannot craft fire recipes without fire

### Fire Detection
- [ ] Fire detection works within 3 tiles
- [ ] Fire detection ignores non-fire sources
- [ ] HUD shows "Near Fire" correctly

### Discovery System
- [ ] Unknown recipe experiment succeeds/fails
- [ ] Recipe learned on first success
- [ ] Known recipes show in crafting list
- [ ] Discovery hints scale with INT

### Success Rates
- [ ] Difficulty 1: ~100% success
- [ ] Difficulty 2: ~90% success
- [ ] Difficulty 3: ~80% success
- [ ] INT bonuses apply correctly

### UI
- [ ] Crafting screen opens/closes
- [ ] Recipe list displays correctly
- [ ] Ingredient requirements shown
- [ ] Can craft / missing indicators correct
- [ ] Experiment mode works

---

## Files to Create

### New Files
- `res://crafting/recipe.gd` - Recipe data class
- `res://autoload/recipe_manager.gd` - Recipe management autoload
- `res://systems/crafting_system.gd` - Crafting logic
- `res://ui/crafting_screen.tscn` - Crafting UI scene
- `res://ui/crafting_screen.gd` - Crafting UI script
- `res://data/recipes/recipes.json` - Recipe data
- `res://plans/crafting-system-implementation.md` - This document

### Modified Files
- `res://autoload/event_bus.gd` - Add crafting signals
- `res://entities/player.gd` - Add recipe memory
- `res://systems/input_handler.gd` - Add crafting input
- `res://ui/hud.gd` - Add fire indicator
- `res://maps/tile_data.gd` - Add `is_fire_source` property
- `res://entities/entity.gd` - Add `is_fire_source` property
- `res://scenes/game.gd` - Add crafting UI handling
- `res://project.godot` - Register RecipeManager autoload

---

## Success Criteria

Phase 1.11 is complete when:
1. All 8 Phase 1 recipes exist as JSON data
2. Recipes load correctly on game start
3. Player can attempt crafts (success/failure)
4. Successful crafts create items and consume ingredients
5. Failed crafts consume ingredients without creating items
6. Tool requirements are checked correctly
7. Fire proximity detection works (3-tile range)
8. Recipe memory/unlocking works (learn on success)
9. Discovery hints scale with INT
10. Crafting UI displays known recipes
11. Experiment mode allows unknown recipe attempts
12. HUD shows "Near Fire" indicator
13. All 8 recipes craftable in-game

---

## Material Variants (Future Enhancement)

Not implemented in Phase 1.11, but designed for extensibility:

**Recipe with Variants:**
```json
{
  "id": "knife",
  "result_variants": [
    {"material": "flint", "result": "flint_knife"},
    {"material": "iron_ore", "result": "iron_knife"},
    {"material": "steel", "result": "steel_knife"}
  ],
  "ingredients": [
    {"item_type": "sharp_material", "count": 1},
    {"item": "wood", "count": 1}
  ],
  "tool_required": "",
  "difficulty": 1
}
```

This allows:
- Flint + Wood → Flint Knife
- Iron + Wood → Iron Knife
- Steel + Wood → Steel Knife

**Phase 2 Feature**: Recipe ingredient matching by type (not just specific item ID)

---

## Integration with Future Systems

### Phase 1.12 (Items)
- All Phase 1 items should be craftable or findable
- Crafting provides alternate acquisition path

### Phase 1.13 (Base Building)
- Campfire is a fire source for cooking
- Campfire placement enables cooking recipes
- Storage chest stores crafting materials

### Phase 1.14 (Town & Shop)
- Shop sells crafting materials
- Shop sells recipe scrolls (future)
- CHA affects material prices

### Phase 1.15 (Save System)
- Save `known_recipes` array
- Load known recipes on game load

---

## Crafting Balancing Notes

### Success Rate Formula
```
Base Success = 100% - (Difficulty - 1) * 10%
INT Bonus = (INT - 10) * 5%
Final Success = Clamp(Base Success + INT Bonus, 50%, 100%)
```

**Examples:**
- Difficulty 1, INT 10: 100% success
- Difficulty 2, INT 10: 90% success
- Difficulty 3, INT 10: 80% success
- Difficulty 3, INT 12: 90% success (80% + 10%)
- Difficulty 5, INT 8: 50% success (60% - 10%, clamped)

### Turn Costs
- Simple craft (1-2 ingredients): 1 turn
- Complex craft (3-4 ingredients): 2 turns (future)
- Crafting consumes turn (player action)

---

*Document Version: 1.0*
*Last Updated: December 30, 2025*
