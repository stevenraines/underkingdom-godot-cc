# Inventory & Equipment System Implementation Plan - Phase 1.10

**Scope**: Task 1.10 (Inventory & Equipment) from PRD
**Branch**: `feature/inventory-system`
**Goal**: Functional inventory with slot-based equipment, weight/encumbrance, and pickup/drop mechanics

---

## Overview

Phase 1.10 implements the inventory and equipment systems that enable players to collect, carry, and equip items found in the world. This phase establishes the foundation for the crafting system (Phase 1.11) and all item-related gameplay.

---

## Inventory System Reference (from PRD)

### Structure
- **Equipment Slots** (slot-based):
  - Head
  - Torso
  - Hands
  - Legs
  - Feet
  - Main Hand
  - Off Hand
  - Accessory ×2

- **General Inventory**: Unlimited slots, weight-limited

### Encumbrance
- Items have weight in kg
- Current weight / Carry capacity = encumbrance ratio
- **Carry Capacity**: Base 20 + (STR × 5) kg

### Encumbrance Penalties
| Encumbrance | Penalty |
|-------------|---------|
| 0-75% | No penalty |
| 75-100% | Stamina costs +50% |
| 100-125% | Movement costs 2 turns, stamina costs +100% |
| 125%+ | Cannot move |

---

## Phase 1 Items Reference (from PRD)

| ID | Name | Type | Weight | ASCII |
|----|------|------|--------|-------|
| raw_meat | Raw Meat | consumable | 0.3 | % |
| cooked_meat | Cooked Meat | consumable | 0.25 | % |
| herb | Herb | material | 0.05 | " |
| cloth | Cloth | material | 0.1 | ~ |
| bandage | Bandage | consumable | 0.1 | + |
| leather | Leather | material | 0.3 | & |
| cord | Cord | material | 0.1 | - |
| waterskin_empty | Empty Waterskin | tool | 0.2 | ! |
| waterskin_full | Full Waterskin | consumable | 1.2 | ! |
| wood | Wood | material | 0.5 | = |
| flint | Flint | material | 0.2 | * |
| iron_ore | Iron Ore | material | 1.0 | o |
| flint_knife | Flint Knife | tool | 0.3 | / |
| iron_knife | Iron Knife | tool | 0.5 | / |
| hammer | Hammer | tool | 1.0 | T |
| leather_armor | Leather Armor | armor | 3.0 | [ |
| wooden_shield | Wooden Shield | armor | 2.5 | ) |
| torch | Torch | tool | 0.5 | \| |
| gold_coin | Gold Coin | currency | 0.01 | $ |

---

## Implementation Components

### 1. Item Base Class
**File**: `res://items/item.gd`
**Status**: ✅ Complete

**Purpose**: Base class for all items in the game

**Properties:**
```gdscript
class_name Item
extends RefCounted

var id: String              # Unique identifier (e.g., "iron_knife")
var name: String            # Display name
var description: String     # Item description
var item_type: String       # "consumable", "material", "tool", "weapon", "armor", "currency"
var subtype: String         # Further classification (e.g., "knife", "chest_armor")
var weight: float           # Weight in kg
var value: int              # Base gold value
var stack_size: int = 1     # Current stack count
var max_stack: int = 1      # Maximum stack size (materials can stack to 99)
var ascii_char: String      # ASCII display character
var ascii_color: String     # Hex color for rendering
var durability: int = -1    # -1 = no durability, otherwise current durability
var max_durability: int = -1

# Equipment-specific
var equip_slot: String = "" # Which slot this equips to ("", "main_hand", "torso", etc.)
var armor_value: int = 0    # Damage reduction when equipped
var damage_bonus: int = 0   # Added to base damage when equipped

# Tool-specific
var tool_type: String = ""  # "knife", "hammer", etc. for crafting requirements

# Consumable-specific
var effects: Dictionary = {} # {"hunger": 30, "thirst": 20, "health": 10}
```

**Key Methods:**
```gdscript
static func create_from_data(data: Dictionary) -> Item
func use(user: Entity) -> bool  # Returns true if consumed
func get_tooltip() -> String
func can_stack_with(other: Item) -> bool
func add_to_stack(amount: int) -> int  # Returns leftover
```

---

### 2. Item Data Files
**Location**: `res://data/items/`
**Status**: ✅ Complete

**Structure:**
- `consumables.json` - Food, bandages, potions
- `materials.json` - Crafting materials
- `tools.json` - Knives, hammers, waterskins
- `weapons.json` - Swords, axes, etc.
- `armor.json` - Leather armor, shields, etc.

**Example Item Data:**
```json
{
  "id": "iron_knife",
  "name": "Iron Knife",
  "description": "A sturdy iron knife. Good for crafting and self-defense.",
  "item_type": "tool",
  "subtype": "knife",
  "weight": 0.5,
  "value": 15,
  "max_stack": 1,
  "ascii_char": "/",
  "ascii_color": "#AAAAAA",
  "durability": 100,
  "tool_type": "knife",
  "equip_slot": "main_hand",
  "damage_bonus": 4
}
```

---

### 3. Item Manager (Autoload)
**File**: `res://autoload/item_manager.gd`
**Status**: ✅ Complete

**Purpose**: Loads and caches item definitions, creates item instances

**Key Methods:**
```gdscript
func _ready():
    _load_all_items()

func get_item_data(item_id: String) -> Dictionary
func create_item(item_id: String, count: int = 1) -> Item
func create_item_stack(item_id: String, count: int) -> Array[Item]
```

---

### 4. Inventory Class
**File**: `res://systems/inventory_system.gd`
**Status**: ✅ Complete

**Purpose**: Manages player inventory with weight tracking

**Properties:**
```gdscript
class_name Inventory
extends RefCounted

var items: Array[Item] = []          # General inventory
var equipment: Dictionary = {}        # Slot -> Item mapping
var max_weight: float = 45.0         # Calculated from STR
var _owner: Entity = null

# Equipment slot names
const EQUIP_SLOTS = [
    "head", "torso", "hands", "legs", "feet",
    "main_hand", "off_hand", "accessory_1", "accessory_2"
]
```

**Key Methods:**
```gdscript
func add_item(item: Item) -> bool  # Returns false if over capacity
func remove_item(item: Item) -> bool
func remove_item_by_id(item_id: String, count: int = 1) -> int  # Returns removed count
func has_item(item_id: String, count: int = 1) -> bool
func get_item_count(item_id: String) -> int
func get_total_weight() -> float
func get_encumbrance_ratio() -> float
func equip_item(item: Item) -> Item  # Returns unequipped item or null
func unequip_slot(slot: String) -> Item
func get_equipped(slot: String) -> Item
func has_tool(tool_type: String) -> bool  # For crafting checks
func use_item(item: Item) -> bool
func recalculate_max_weight(strength: int) -> void
```

---

### 5. Event Bus Inventory Signals
**File**: `res://autoload/event_bus.gd`
**Status**: ✅ Complete

**New Signals:**
```gdscript
signal item_picked_up(item: Item)
signal item_dropped(item: Item, position: Vector2i)
signal item_used(item: Item, result: Dictionary)
signal item_equipped(item: Item, slot: String)
signal item_unequipped(item: Item, slot: String)
signal inventory_changed()
signal encumbrance_changed(ratio: float)
```

---

### 6. Ground Items (World Items)
**File**: `res://entities/ground_item.gd`
**Status**: ✅ Complete

**Purpose**: Entity representing items on the ground

**Properties:**
```gdscript
class_name GroundItem
extends Entity

var item: Item
var despawn_turn: int = -1  # -1 = never despawn
```

**Integration:**
- Rendered on entity layer with item's ASCII character
- Player can pick up by walking over (auto) or interacting
- EntityManager tracks ground items per map

---

### 7. Player Inventory Integration
**File**: `res://entities/player.gd`
**Status**: ✅ Complete

**New Properties:**
```gdscript
var inventory: Inventory = null
```

**New Methods:**
```gdscript
func pickup_item(ground_item: GroundItem) -> bool
func drop_item(item: Item) -> bool
func use_item(item: Item) -> bool
func equip_item(item: Item) -> Item
func get_weapon_damage() -> int  # Base + equipped weapon bonus
func get_total_armor() -> int    # Sum of all equipped armor
```

**Combat Integration:**
- `get_weapon_damage()` returns base_damage + equipped weapon bonus
- `get_total_armor()` returns sum of all equipped armor values
- Combat system uses these for damage calculation

---

### 8. Encumbrance System
**File**: `res://systems/inventory_system.gd` (part of Inventory)
**Status**: ✅ Complete

**Implementation:**
```gdscript
func get_encumbrance_penalty() -> Dictionary:
    var ratio = get_encumbrance_ratio()
    var result = {
        "can_move": true,
        "stamina_multiplier": 1.0,
        "movement_cost": 1
    }
    
    if ratio > 1.25:
        result.can_move = false
    elif ratio > 1.0:
        result.stamina_multiplier = 2.0
        result.movement_cost = 2
    elif ratio > 0.75:
        result.stamina_multiplier = 1.5
    
    return result
```

**Player Movement Integration:**
- Check encumbrance before moving
- Apply stamina cost multiplier
- Multiple turns for movement if heavily encumbered
- Block movement entirely if over 125%

---

### 9. Input Handler Updates
**File**: `res://systems/input_handler.gd`
**Status**: ✅ Complete

**New Input Actions:**
- `inventory` (I key) - Open inventory screen
- `pickup` (G or , key) - Pick up item at feet
- `drop` (D key) - Open drop menu
- `use` (U key) - Use selected item

---

### 10. Basic Inventory UI
**File**: `res://ui/inventory_screen.tscn` and `res://ui/inventory_screen.gd`
**Status**: ✅ Complete

**Features:**
- List of inventory items with weight
- Equipment slots display
- Total weight / capacity display
- Encumbrance indicator
- Actions: Use, Equip, Drop, Examine

**ASCII-Style UI:**
```
╔════════════════════════════════════╗
║         INVENTORY                  ║
║ Weight: 12.5/45.0 kg (28%)        ║
╠════════════════════════════════════╣
║ EQUIPPED:                          ║
║ Head:      [Empty]                 ║
║ Torso:     Leather Armor [3.0kg]   ║
║ Hands:     [Empty]                 ║
║ Legs:      [Empty]                 ║
║ Feet:      [Empty]                 ║
║ Main Hand: Iron Knife [0.5kg]      ║
║ Off Hand:  Wooden Shield [2.5kg]   ║
║ Accessory: [Empty]                 ║
║ Accessory: [Empty]                 ║
╠════════════════════════════════════╣
║ ITEMS:                             ║
║ > Raw Meat x3 [0.9kg]              ║
║   Bandage x2 [0.2kg]               ║
║   Herb x5 [0.25kg]                 ║
║   Gold Coins x50 [0.5kg]           ║
╠════════════════════════════════════╣
║ [U]se [E]quip [D]rop [X]Close      ║
╚════════════════════════════════════╝
```

---

### 11. Loot System Integration
**Files**: `res://entities/enemy.gd`, `res://autoload/entity_manager.gd`
**Status**: ⬜ Deferred to Combat Enhancement Phase

**Death → Corpse → Loot Flow:**
1. Enemy dies
2. Corpse entity created at death position
3. Corpse has inventory generated from loot table
4. Player interacts with corpse to open loot UI
5. Player can take items from corpse
6. Corpse despawns after 500 turns

**Corpse Entity:**
```gdscript
class_name Corpse
extends Entity

var inventory: Inventory
var despawn_turn: int
var original_entity_name: String
```

---

## Implementation Order

### Stage 1: Data Foundation
1. ✅ Create Item base class (`items/item.gd`)
2. ✅ Create item data JSON files (`data/items/*.json`)
3. ✅ Create ItemManager autoload (`autoload/item_manager.gd`)
4. ✅ Add inventory signals to EventBus

### Stage 2: Inventory System
5. ✅ Create Inventory class (`systems/inventory_system.gd`)
6. ✅ Implement weight/encumbrance calculations
7. ✅ Add inventory to Player entity
8. ✅ Integrate encumbrance with movement/stamina

### Stage 3: World Items
9. ✅ Create GroundItem entity class
10. ✅ Implement pickup mechanics
11. ✅ Implement drop mechanics
12. ✅ Add ground item rendering

### Stage 4: Equipment System
13. ✅ Implement equipment slots
14. ✅ Add equip/unequip functionality
15. ✅ Integrate with combat (weapon damage, armor)
16. ✅ Add consumable use functionality

### Stage 5: UI & Polish
17. ✅ Create inventory screen scene
18. ✅ Implement inventory navigation
19. ✅ Add item tooltips
20. ✅ Update HUD with inventory summary

### Stage 6: Loot Integration
21. ⬜ Create Corpse entity class (deferred)
22. ⬜ Generate loot on enemy death (deferred)
23. ⬜ Implement corpse interaction (deferred)
24. ⬜ Add corpse despawn timer (deferred)

---

## Testing Checklist

### Item System
- [ ] Items load from JSON data files
- [ ] ItemManager creates item instances correctly
- [ ] Items have correct properties from data
- [ ] Stackable items stack properly
- [ ] Non-stackable items don't stack

### Inventory Management
- [ ] Items can be added to inventory
- [ ] Items can be removed from inventory
- [ ] Weight is tracked correctly
- [ ] Max weight updates with STR changes
- [ ] has_item() returns correct values

### Encumbrance
- [ ] Encumbrance ratio calculates correctly
- [ ] 0-75%: No penalty
- [ ] 75-100%: +50% stamina cost
- [ ] 100-125%: 2-turn movement, +100% stamina
- [ ] 125%+: Cannot move

### Equipment
- [ ] Items equip to correct slots
- [ ] Equipped items provide stat bonuses
- [ ] Weapon damage bonus applies in combat
- [ ] Armor reduces incoming damage
- [ ] Unequipping returns item to inventory

### World Items
- [ ] Ground items render with correct ASCII
- [ ] Player can pick up ground items
- [ ] Player can drop items
- [ ] Dropped items appear at player position

### Consumables
- [ ] Food increases hunger
- [ ] Water increases thirst
- [ ] Bandages heal health
- [ ] Consumables are removed after use

### UI
- [ ] Inventory screen opens/closes
- [ ] Items display with weight
- [ ] Equipment slots show equipped items
- [ ] Encumbrance displays correctly
- [ ] Actions work (use, equip, drop)

---

## Files to Create

### New Files
- `res://items/item.gd` - Item base class
- `res://autoload/item_manager.gd` - Item management autoload
- `res://systems/inventory_system.gd` - Inventory class
- `res://entities/ground_item.gd` - World item entity
- `res://entities/corpse.gd` - Corpse entity for loot
- `res://ui/inventory_screen.tscn` - Inventory UI scene
- `res://ui/inventory_screen.gd` - Inventory UI script
- `res://data/items/consumables.json` - Consumable item data
- `res://data/items/materials.json` - Material item data
- `res://data/items/tools.json` - Tool item data
- `res://data/items/weapons.json` - Weapon item data
- `res://data/items/armor.json` - Armor item data
- `res://plans/inventory-system-implementation.md` - This document

### Modified Files
- `res://autoload/event_bus.gd` - Add inventory signals
- `res://entities/player.gd` - Add inventory integration
- `res://entities/enemy.gd` - Add loot generation on death
- `res://systems/input_handler.gd` - Add inventory input actions
- `res://systems/combat_system.gd` - Use equipped weapon/armor stats
- `res://scenes/game.gd` - Add inventory UI handling
- `res://project.godot` - Register ItemManager autoload

---

## Success Criteria

Phase 1.10 is complete when:
1. ✅ All Phase 1 items exist as JSON data
2. ✅ Items can be created from data definitions
3. ✅ Player has functional inventory with weight tracking
4. ✅ Equipment slots work (head, torso, hands, legs, feet, main_hand, off_hand, accessory×2)
5. ✅ Items can be picked up from ground
6. ✅ Items can be dropped to ground
7. ✅ Items can be equipped/unequipped
8. ✅ Equipped weapons affect combat damage
9. ✅ Equipped armor reduces incoming damage
10. ✅ Consumables restore hunger/thirst/health
11. ✅ Encumbrance affects movement and stamina
12. ✅ Inventory UI displays all information
13. ⬜ Enemy corpses can be looted (deferred to future phase)

---

**Phase Status**: ✅ COMPLETE

**Git Branch**: `feature/inventory-system`
**Files Created:**
- `res://items/item.gd` - Item base class
- `res://autoload/item_manager.gd` - Item management autoload
- `res://systems/inventory_system.gd` - Inventory class
- `res://entities/ground_item.gd` - World item entity
- `res://ui/inventory_screen.gd` - Inventory UI script
- `res://ui/inventory_screen.tscn` - Inventory UI scene
- `res://data/items/consumables.json` - Consumable items
- `res://data/items/materials.json` - Material items
- `res://data/items/tools.json` - Tool items
- `res://data/items/equipment.json` - Weapons and armor
- `res://plans/inventory-system-implementation.md` - This document

**Files Modified:**
- `res://autoload/event_bus.gd` - Added inventory signals
- `res://autoload/entity_manager.gd` - Added ground item methods
- `res://entities/player.gd` - Inventory integration
- `res://systems/input_handler.gd` - Inventory input handling
- `res://systems/combat_system.gd` - Use equipped weapon/armor stats
- `res://scenes/game.gd` - Inventory UI and starter items
- `res://project.godot` - Register ItemManager autoload

---

## Future Enhancements (Not in Phase 1.10)

- **Item Durability**: Tools/weapons degrade with use
- **Item Quality**: Variable stats based on crafting skill
- **Item Comparison**: Show stat differences when equipping
- **Quick Slots**: Hotbar for consumables
- **Sorting**: Auto-sort inventory by type/weight/name
- **Storage Containers**: Chests, bags, etc.
- **Item Stacking UI**: Split/merge stacks

---

## Combat Integration Details

### Weapon Damage Calculation
```gdscript
# In Player.gd
func get_weapon_damage() -> int:
    var weapon = inventory.get_equipped("main_hand")
    var bonus = weapon.damage_bonus if weapon else 0
    return base_damage + bonus
```

### Armor Damage Reduction
```gdscript
# In CombatSystem.gd - updated damage calculation
static func calculate_damage(attacker: Entity, defender: Entity) -> int:
    var base = attacker.get_weapon_damage() if attacker.has_method("get_weapon_damage") else attacker.base_damage
    var str_mod = (attacker.get_effective_attribute("STR") - 10) / 2
    var armor = defender.get_total_armor() if defender.has_method("get_total_armor") else defender.armor
    return max(1, base + str_mod - armor)
```

---

*Document Version: 1.0*
*Last Updated: December 30, 2025*
