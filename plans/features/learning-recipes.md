# Feature: Learning Recipes

**Goal**: Implement ways for the player to learn recipes

---

## Overview

Players can craft recipes, but they have no way to learn new ones. This feature implements three new mechanics:

1. **NPC Training** - NPCs sell recipes via a training interaction
2. **Books** - Reading books teaches recipes (dynamically generated from recipe data)
3. **Experimentation** - UI in crafting screen for combining ingredients to discover recipes

---

## Implementation Plan

### Part 1: NPC Training System

#### 1.1 Extend NPC Data Structure
**File**: `data/npcs/priest.json`

Add `recipes_for_sale` array to NPCs that can train:
```json
{
  "id": "priest",
  "name": "Father Aldric",
  "npc_type": "trainer",
  "recipes_for_sale": [
    {"recipe_id": "healing_potion", "base_price": 150}
  ],
  ...
}
```

#### 1.2 Update NPC Entity
**File**: `entities/npc.gd`

- Add `recipes_for_sale: Array = []` property
- Update `from_dict()` / `to_dict()` to serialize recipes
- Add helper methods:
  - `get_recipe_for_sale(recipe_id: String) -> Dictionary`
  - `remove_recipe_for_sale(recipe_id: String)`
  - `has_recipes_for_sale() -> bool`

#### 1.3 Create Training System
**File**: `systems/training_system.gd` (new)

Static class similar to ShopSystem:
- `calculate_training_price(base_price: int, difficulty: int, charisma: int) -> int`
  - Formula: `base_price + (difficulty * 25)`, then apply CHA modifier like shop
- `attempt_purchase_training(npc: NPC, recipe_id: String, player: Player) -> bool`
  - Validates player has gold
  - Deducts gold, adds recipe to player.known_recipes
  - Removes recipe from NPC's list (one-time sale)
  - Emits signal

#### 1.4 Create NPC Interaction Menu Screen
**File**: `ui/npc_menu_screen.gd` (new)
**File**: `ui/npc_menu_screen.tscn` (new)

When player presses T near an NPC with multiple services:
- Shows menu with options: "Trade" / "Train" (if applicable)
- Arrow keys to select, Enter to confirm
- Routes to appropriate screen (ShopScreen or TrainingScreen)

#### 1.5 Create Training Screen
**File**: `ui/training_screen.gd` (new)
**File**: `ui/training_screen.tscn` (new)

Similar to ShopScreen but for recipes:
- Left panel: Available recipes from NPC
- Right panel: Recipe details (name, result item, difficulty, price)
- Does NOT show ingredients (per spec)
- Shows: Recipe name, result item description, difficulty stars, gold cost
- Enter to purchase, Escape to close

#### 1.6 Update Game Scene Integration
**File**: `scenes/game.gd`

- Instantiate NpcMenuScreen and TrainingScreen
- Connect signals:
  - `npc_menu_opened(npc, player)` -> opens menu
  - `training_opened(npc, player)` -> opens training screen
  - `recipe_trained(recipe, player)` -> show message

#### 1.7 Update NPC Interaction Flow
**File**: `entities/npc.gd`

Modify `interact()`:
```gdscript
func interact(player: Player):
    EventBus.emit_signal("npc_interacted", self, player)

    # Check what services this NPC offers
    var has_shop = npc_type == "shop" or trade_inventory.size() > 0
    var has_training = recipes_for_sale.size() > 0

    if has_shop and has_training:
        # Show menu to choose
        EventBus.emit_signal("npc_menu_opened", self, player)
    elif has_shop:
        open_shop(player)
    elif has_training:
        open_training(player)
    else:
        speak_greeting()
```

#### 1.8 Add EventBus Signals
**File**: `autoload/event_bus.gd`

```gdscript
signal npc_menu_opened(npc, player)
signal training_opened(npc, player)
signal recipe_trained(recipe_id: String, price: int)
```

---

### Part 2: Recipe Books System

#### 2.1 Add Book Properties to Recipe
**File**: `crafting/recipe.gd`

Add optional book-related properties:
```gdscript
var book_name: String = ""      # Medieval-style book title
var book_description: String = "" # Description shown when reading
```

#### 2.2 Update Recipe JSON Schema
**File**: `data/recipes/consumables/healing_potion.json` (example)

Add optional book metadata:
```json
{
  "id": "healing_potion",
  "book_name": "The Apothecary's Compendium",
  "book_description": "A treatise on the preparation of healing draughts...",
  ...
}
```

#### 2.3 Create Book Item Generator
**File**: `autoload/item_manager.gd`

Add function to dynamically generate recipe books:
```gdscript
func create_recipe_book(recipe_id: String) -> Item:
    var recipe = RecipeManager.get_recipe(recipe_id)
    if not recipe:
        return null

    var book = Item.new()
    book.id = "recipe_book_" + recipe_id
    book.name = recipe.book_name if recipe.book_name else _generate_book_name(recipe)
    book.description = recipe.book_description if recipe.book_description else _generate_book_description(recipe)
    book.item_type = "book"
    book.category = "book"
    book.flags = {"readable": true, "book": true}
    book.weight = 0.5
    book.value = 50 + recipe.difficulty * 25
    book.ascii_char = "+"
    book.ascii_color = "#8B4513"  # Saddle brown
    book.teaches_recipe = recipe_id
    book.max_stack = 1
    return book

func _generate_book_name(recipe: Recipe) -> String:
    # Generate medieval-style book names
    var prefixes = ["Tome of", "Secrets of", "The Art of", "Codex:", "Manual of", "Treatise on"]
    var prefix = prefixes[randi() % prefixes.size()]
    return "%s %s" % [prefix, recipe.get_display_name()]

func _generate_book_description(recipe: Recipe) -> String:
    return "A leather-bound volume containing knowledge of crafting %s." % recipe.get_display_name()
```

#### 2.4 Add Book Property to Item Class
**File**: `items/item.gd`

Add:
```gdscript
var teaches_recipe: String = ""  # Recipe ID this book teaches when read
```

Update `create_from_data()` to load this property.
Update `duplicate_item()` to copy this property.
Update `serialize()` if needed.

#### 2.5 Implement Book Reading
**File**: `items/item.gd`

Update `use()` method:
```gdscript
func use(user: Entity) -> Dictionary:
    # ... existing code ...

    # Handle books
    if flags.get("book", false) or flags.get("readable", false):
        return _use_book(user)
```

Add `_use_book()` method:
```gdscript
func _use_book(user: Entity) -> Dictionary:
    var result = {
        "success": false,
        "consumed": false,
        "message": ""
    }

    if teaches_recipe == "":
        result.message = "You read %s but learn nothing new." % name
        result.success = true
        return result

    # Check if player already knows recipe
    if user.has_method("knows_recipe") and user.knows_recipe(teaches_recipe):
        result.message = "You already know the recipe in this book."
        result.success = true
        return result

    # Teach the recipe
    if user.has_method("learn_recipe"):
        user.learn_recipe(teaches_recipe)
        var recipe = RecipeManager.get_recipe(teaches_recipe)
        var recipe_name = recipe.get_display_name() if recipe else teaches_recipe
        result.message = "You read %s and learn how to craft %s!" % [name, recipe_name]
        result.success = true
        EventBus.recipe_discovered.emit(recipe)

    return result
```

#### 2.6 Add Book to Shopkeeper Inventory
**File**: `data/npcs/shop_keeper.json` or `entities/npc.gd`

Add healing potion recipe book to shopkeeper's trade inventory. Since books are dynamically generated, we need a way to reference them:

Option A: Add to NPC JSON trade_inventory:
```json
"trade_inventory": [
    {"item_id": "recipe_book_healing_potion", "count": 1, "base_price": 100},
    ...
]
```

Option B: Generate at runtime in NPC loading.

**Chosen approach**: Option A - Add a static book item definition, and also support dynamic generation for future books.

#### 2.7 Create Static Book Item Definitions
**File**: `data/items/books/recipe_book_healing_potion.json` (new directory)

```json
{
    "id": "recipe_book_healing_potion",
    "name": "The Apothecary's Compendium",
    "description": "A leather-bound tome detailing the preparation of healing draughts.",
    "item_type": "book",
    "category": "book",
    "flags": {"readable": true, "book": true},
    "weight": 0.5,
    "value": 100,
    "max_stack": 1,
    "ascii_char": "+",
    "ascii_color": "#8B4513",
    "teaches_recipe": "healing_potion"
}
```

---

### Part 3: Experimentation UI

#### 3.1 Extend Crafting Screen with Mode Toggle
**File**: `ui/crafting_screen.gd`

Add mode switching:
```gdscript
enum CraftingMode { RECIPES, EXPERIMENT }
var current_mode: CraftingMode = CraftingMode.RECIPES
```

- Tab key toggles between "Recipes" and "Experiment" modes
- Update title to show current mode
- Different UI for each mode

#### 3.2 Implement Experiment Mode UI
**File**: `ui/crafting_screen.gd`

In experiment mode:
- Left panel: Player's inventory (materials only, filtered)
- Right panel: Selected ingredients (2-4 slots)
- Show "Select ingredients to combine (2-4)"
- Arrow keys navigate inventory
- Enter adds selected item to experiment slots
- Backspace removes last ingredient
- 'C' or second Enter attempts the experiment

#### 3.3 Update Crafting System for Partial Consumption
**File**: `systems/crafting_system.gd`

Modify `attempt_experiment()` for partial ingredient consumption on failure:
```gdscript
static func attempt_experiment(player: Player, ingredient_ids: Array[String], near_fire: bool) -> Dictionary:
    # ... existing validation ...

    if recipe:
        # Found a recipe! Attempt to craft it (normal consumption)
        return attempt_craft(player, recipe, near_fire)
    else:
        # No matching recipe - partial consumption (50% chance per item)
        var consumed_items: Array[String] = []
        for item_id in ingredient_ids:
            if randf() < 0.5:  # 50% chance to lose each ingredient
                player.inventory.remove_item_by_id(item_id, 1)
                consumed_items.append(item_id)

        EventBus.inventory_changed.emit()

        var hint = get_experiment_hint(ingredient_ids, player.attributes["INT"])
        if consumed_items.size() > 0:
            result.message = hint + " Lost: " + ", ".join(consumed_items)
        else:
            result.message = hint + " Somehow, your materials survived intact."
        return result
```

#### 3.4 UI Layout for Experiment Mode

```
+------------------------------------------+
|  CRAFTING - Experiment Mode    [Tab]     |
+------------------------------------------+
| Materials:     | Selected (2-4):         |
| > Wood (5)     | 1. Flint               |
|   Flint (3)    | 2. Wood                |
|   Leather (2)  | 3. -                   |
|   Herb (4)     | 4. -                   |
|                |                         |
|                | [Enter] Add ingredient  |
|                | [Backspace] Remove last |
|                | [C] Combine             |
+------------------------------------------+
| Near Fire: NO                            |
+------------------------------------------+
| Select 2-4 ingredients to experiment     |
+------------------------------------------+
```

---

### Part 4: Additional Recipes for Training/Books

#### 4.1 Add More Trainable Recipes

Create additional NPCs or add recipes to existing ones:

**Farmer (Greta)** - Can train food recipes:
- `bread` - Already exists, add to farmer's training

**Priest (Father Aldric)** - Healing recipes:
- `healing_potion` - Primary training item
- `healing_salve` - Secondary option

#### 4.2 Recipe Book Variants

Add a few more recipe books to demonstrate the system:
- `recipe_book_bread.json` - "The Baker's Primer"
- `recipe_book_torch.json` - "Illumination for Travelers"
- `recipe_book_bandage.json` - "Field Medicine Fundamentals"

---

## File Changes Summary

### New Files
1. `systems/training_system.gd` - Training price calculation and purchase logic
2. `ui/npc_menu_screen.gd` - NPC interaction menu (Trade/Train options)
3. `ui/npc_menu_screen.tscn` - Scene for NPC menu
4. `ui/training_screen.gd` - Recipe training UI
5. `ui/training_screen.tscn` - Scene for training screen
6. `data/items/books/recipe_book_healing_potion.json` - Healing potion recipe book
7. `data/items/books/recipe_book_bread.json` - Bread recipe book
8. `data/items/books/recipe_book_torch.json` - Torch recipe book

### Modified Files
1. `entities/npc.gd` - Add recipes_for_sale, update interact()
2. `items/item.gd` - Add teaches_recipe property, book reading logic
3. `autoload/event_bus.gd` - Add training signals
4. `autoload/item_manager.gd` - Add create_recipe_book() function
5. `crafting/recipe.gd` - Add book_name, book_description properties
6. `systems/crafting_system.gd` - Update experiment for partial consumption
7. `ui/crafting_screen.gd` - Add experiment mode with Tab toggle
8. `scenes/game.gd` - Integrate new screens
9. `data/npcs/priest.json` - Add recipes_for_sale for healing_potion
10. `data/npcs/farmer.json` - Add recipes_for_sale for bread (if exists)
11. `data/npcs/shop_keeper.json` - Add recipe books to trade inventory

---

## Implementation Order

1. **EventBus signals** - Foundation for all new features
2. **Item.teaches_recipe + book reading** - Simplest self-contained feature
3. **Recipe book items** - Create book JSON files
4. **NPC.recipes_for_sale** - Extend NPC data structure
5. **TrainingSystem** - Price calculation and purchase logic
6. **TrainingScreen** - UI for purchasing training
7. **NpcMenuScreen** - Menu for choosing Trade/Train
8. **Game.gd integration** - Wire up all screens
9. **Priest NPC update** - Add healing potion training
10. **Shopkeeper update** - Add recipe books to inventory
11. **CraftingScreen experiment mode** - Tab toggle and experiment UI
12. **Partial consumption** - Update experiment failure logic

---

## Testing Checklist

### NPC Training
- [ ] Priest offers healing potion training
- [ ] Training screen shows recipe name, result, difficulty, price
- [ ] Training screen does NOT show ingredients
- [ ] Price reflects base_price + difficulty + CHA modifier
- [ ] Gold is deducted on purchase
- [ ] Recipe is added to player.known_recipes
- [ ] Recipe is removed from NPC's list (can't buy twice)
- [ ] Message confirms learning

### Books
- [ ] Recipe books load from JSON
- [ ] Books appear in shopkeeper inventory
- [ ] Reading book teaches recipe (if not known)
- [ ] Reading book when already known shows appropriate message
- [ ] Book is NOT consumed after reading (can be sold/traded)
- [ ] Book has medieval-style name

### Experimentation
- [ ] Tab toggles between Recipes and Experiment modes
- [ ] Experiment mode shows materials from inventory
- [ ] Can select 2-4 ingredients
- [ ] Combining correct ingredients discovers recipe
- [ ] Failed experiment partially consumes ingredients (50% each)
- [ ] INT affects hint quality on failure
- [ ] Near fire status still shown and affects recipes

### Integration
- [ ] NPC menu appears when NPC has both shop and training
- [ ] Can navigate between Trade and Train
- [ ] All screens close properly with Escape
- [ ] Turns advance appropriately
