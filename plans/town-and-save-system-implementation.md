# Town & Shop System + Save System Implementation Plan
**Phases 1.14 & 1.15**

## Overview
This plan covers implementation of the town/shop system (Phase 1.14) and save system (Phase 1.15) for Underkingdom. These systems enable player economy interactions and game state persistence.

---

## Phase 1.14: Town & Shop System

### Goals
- Create a safe town area in the overworld
- Implement NPC system with shop functionality
- Enable buying/selling with CHA-based pricing
- Manage shop inventory with periodic restocking

### Architecture

#### New Components
1. **NPC Base Class** (`entities/npc.gd`)
   - Extends Entity
   - Properties: dialogue, schedule, faction, trade_inventory
   - Non-hostile, blocks movement
   - Turn processing (idle/scheduled behavior)

2. **ShopSystem** (`systems/shop_system.gd`)
   - Buy/sell logic
   - Price calculation with CHA modifier
   - Shop inventory management
   - Restock timer (500 turns)

3. **Town Generator** (`generation/town_generator.gd`)
   - Creates town layout in overworld
   - Places buildings, NPCs, features
   - Designates safe zone (no enemy spawns)

#### EventBus Signals
```gdscript
# New signals
signal shop_opened(npc: NPC)
signal item_purchased(item: Item, price: int)
signal item_sold(item: Item, price: int)
signal shop_restocked(shop_npc: NPC)
```

### Data Structures

#### NPC Data (JSON)
```json
{
  "id": "shop_keeper",
  "name": "Olaf the Trader",
  "type": "shop",
  "ascii_char": "@",
  "ascii_color": "#FFAA00",
  "stats": {
    "str": 8, "dex": 10, "con": 12,
    "int": 14, "wis": 12, "cha": 16
  },
  "dialogue": {
    "greeting": "Welcome to my shop, traveler!",
    "buy": "What would you like to purchase?",
    "sell": "I'll take a look at what you have.",
    "farewell": "Safe travels!"
  },
  "shop_data": {
    "gold": 500,
    "restock_interval": 500,
    "inventory": [
      {"item_id": "raw_meat", "count": 10, "price_multiplier": 1.0},
      {"item_id": "waterskin_empty", "count": 5, "price_multiplier": 1.2},
      {"item_id": "torch", "count": 20, "price_multiplier": 1.0},
      {"item_id": "bandage", "count": 8, "price_multiplier": 1.5},
      {"item_id": "cord", "count": 15, "price_multiplier": 1.0}
    ]
  }
}
```

#### Town Layout
```
Town (20×20 area in overworld):
┌────────────────────┐
│   T   T   T   T    │  T = Tree
│ T  ╔═════╗  T     │  ═ = Building wall
│   T║ @   ║ T   W  │  @ = NPC (shop keeper)
│ T  ╚═════╝   T    │  W = Well (water source)
│   T   T   T   T   │  . = Floor/path
│ T   T   T   T   T │
└────────────────────┘
```

### Implementation Steps

#### 1. NPC Base Class
**File**: `res://entities/npc.gd`

```gdscript
extends Entity
class_name NPC

# NPC-specific properties
var npc_type: String = "generic"  # "shop", "quest", "guard", etc.
var dialogue: Dictionary = {}
var schedule: Array = []  # Future: time-based behavior
var faction: String = "neutral"
var trade_inventory: Array = []  # Items for sale
var gold: int = 0
var last_restock_turn: int = 0
var restock_interval: int = 500

func _init():
    super()
    blocking = true  # NPCs block movement
    ascii_char = "@"
    ascii_color = Color("#FFAA00")

func process_turn():
    # NPCs don't move in Phase 1
    # Future: schedule-based movement
    pass

func interact(player: Player):
    # Override in specific NPC types
    EventBus.emit_signal("npc_interacted", self, player)

func restock_shop():
    if TurnManager.current_turn - last_restock_turn >= restock_interval:
        # Reload shop inventory from data
        load_shop_inventory()
        last_restock_turn = TurnManager.current_turn
        EventBus.emit_signal("shop_restocked", self)
```

#### 2. Shop System
**File**: `res://systems/shop_system.gd`

```gdscript
extends Node

const CHARISMA_PRICE_MODIFIER = 0.05  # 5% per CHA point

func calculate_buy_price(base_price: int, player_cha: int) -> int:
    # Player buying from shop (higher CHA = lower price)
    var modifier = 1.0 - ((player_cha - 10) * CHARISMA_PRICE_MODIFIER)
    modifier = clamp(modifier, 0.5, 1.5)  # 50%-150% of base price
    return int(base_price * modifier)

func calculate_sell_price(base_price: int, player_cha: int) -> int:
    # Player selling to shop (higher CHA = higher price)
    var base_sell = base_price * 0.5  # Shops buy at 50% base value
    var modifier = 1.0 + ((player_cha - 10) * CHARISMA_PRICE_MODIFIER)
    modifier = clamp(modifier, 0.5, 1.5)
    return int(base_sell * modifier)

func attempt_purchase(shop_npc: NPC, item_id: String, count: int, player: Player) -> bool:
    var item_data = _find_shop_item(shop_npc, item_id)
    if not item_data:
        return false

    if item_data.count < count:
        EventBus.emit_signal("message_logged", "Shop doesn't have enough %s." % item_id)
        return false

    var total_price = calculate_buy_price(item_data.base_price, player.stats.cha) * count

    if player.gold < total_price:
        EventBus.emit_signal("message_logged", "Not enough gold. Need %d." % total_price)
        return false

    # Execute transaction
    player.gold -= total_price
    shop_npc.gold += total_price
    item_data.count -= count

    var item = ItemManager.create_item(item_id, count)
    player.inventory.add_item(item)

    EventBus.emit_signal("item_purchased", item, total_price)
    EventBus.emit_signal("message_logged", "Purchased %s for %d gold." % [item.name, total_price])
    return true

func attempt_sell(shop_npc: NPC, item: Item, count: int, player: Player) -> bool:
    if not player.inventory.has_item(item, count):
        return false

    var sell_price = calculate_sell_price(item.value, player.stats.cha) * count

    if shop_npc.gold < sell_price:
        EventBus.emit_signal("message_logged", "Shop doesn't have enough gold.")
        return false

    # Execute transaction
    player.gold += sell_price
    shop_npc.gold -= sell_price
    player.inventory.remove_item(item, count)

    # Add to shop inventory
    _add_to_shop_inventory(shop_npc, item.id, count)

    EventBus.emit_signal("item_sold", item, sell_price)
    EventBus.emit_signal("message_logged", "Sold %s for %d gold." % [item.name, sell_price])
    return true

func _find_shop_item(shop_npc: NPC, item_id: String) -> Dictionary:
    for item_data in shop_npc.trade_inventory:
        if item_data.item_id == item_id:
            return item_data
    return {}

func _add_to_shop_inventory(shop_npc: NPC, item_id: String, count: int):
    var existing = _find_shop_item(shop_npc, item_id)
    if existing:
        existing.count += count
    else:
        shop_npc.trade_inventory.append({
            "item_id": item_id,
            "count": count,
            "base_price": ItemManager.get_item_value(item_id)
        })
```

#### 3. Town Generator
**File**: `res://generation/town_generator.gd`

```gdscript
extends Node

const TOWN_SIZE = Vector2i(20, 20)
const TOWN_POSITION = Vector2i(50, 50)  # Center of overworld

static func generate_town(world_map: Map, world_seed: int):
    var rng = SeededRandom.new(world_seed + 999)  # Offset for town

    # Clear area for town
    var town_rect = Rect2i(TOWN_POSITION, TOWN_SIZE)
    for x in range(town_rect.position.x, town_rect.position.x + town_rect.size.x):
        for y in range(town_rect.position.y, town_rect.position.y + town_rect.size.y):
            world_map.set_tile(x, y, TileData.create_floor())

    # Place shop building (5×5)
    var shop_pos = TOWN_POSITION + Vector2i(7, 8)
    _place_building(world_map, shop_pos, Vector2i(5, 5))

    # Place shop NPC inside building
    var npc_pos = shop_pos + Vector2i(2, 2)
    var shop_keeper = _create_shop_npc(npc_pos, world_seed)
    world_map.add_entity(shop_keeper)

    # Place well (water source)
    var well_pos = TOWN_POSITION + Vector2i(15, 10)
    world_map.set_tile(well_pos.x, well_pos.y, TileData.create_water())

    # Add trees around perimeter
    _add_decorative_trees(world_map, town_rect, rng)

    # Mark as safe zone (no enemy spawns)
    world_map.metadata["safe_zone"] = true
    world_map.metadata["town_center"] = TOWN_POSITION

static func _place_building(world_map: Map, pos: Vector2i, size: Vector2i):
    # Walls
    for x in range(pos.x, pos.x + size.x):
        for y in range(pos.y, pos.y + size.y):
            if x == pos.x or x == pos.x + size.x - 1 or y == pos.y or y == pos.y + size.y - 1:
                world_map.set_tile(x, y, TileData.create_wall())
            else:
                world_map.set_tile(x, y, TileData.create_floor())

    # Door (south side, center)
    var door_pos = Vector2i(pos.x + size.x / 2, pos.y + size.y - 1)
    world_map.set_tile(door_pos.x, door_pos.y, TileData.create_floor())

static func _create_shop_npc(pos: Vector2i, seed: int) -> NPC:
    var npc = NPC.new()
    npc.position = pos
    npc.npc_type = "shop"
    npc.ascii_char = "@"
    npc.ascii_color = Color("#FFAA00")
    npc.gold = 500
    npc.restock_interval = 500
    npc.last_restock_turn = 0

    # Load shop inventory from data
    _load_shop_inventory(npc)

    return npc

static func _load_shop_inventory(npc: NPC):
    # Phase 1 shop inventory
    npc.trade_inventory = [
        {"item_id": "raw_meat", "count": 10, "base_price": 5},
        {"item_id": "cooked_meat", "count": 5, "base_price": 8},
        {"item_id": "waterskin_empty", "count": 5, "base_price": 10},
        {"item_id": "torch", "count": 20, "base_price": 3},
        {"item_id": "bandage", "count": 8, "base_price": 12},
        {"item_id": "cord", "count": 15, "base_price": 2},
        {"item_id": "cloth", "count": 10, "base_price": 3},
        {"item_id": "flint", "count": 8, "base_price": 5}
    ]

static func _add_decorative_trees(world_map: Map, town_rect: Rect2i, rng: SeededRandom):
    # Add trees around edges
    for i in range(15):
        var x = rng.randi_range(town_rect.position.x, town_rect.position.x + town_rect.size.x - 1)
        var y = rng.randi_range(town_rect.position.y, town_rect.position.y + town_rect.size.y - 1)

        # Only place on edges
        if x == town_rect.position.x or x == town_rect.position.x + town_rect.size.x - 1 or \
           y == town_rect.position.y or y == town_rect.position.y + town_rect.size.y - 1:
            if world_map.get_tile(x, y).walkable:
                world_map.set_tile(x, y, TileData.create_tree())
```

#### 4. Shop UI
**File**: `res://ui/shop_screen.tscn` + `res://ui/shop_screen.gd`

Basic UI layout:
```
┌─────────────────────────────────────┐
│ Olaf's Shop         Gold: 250       │
├─────────────────────────────────────┤
│ BUY           │ SELL                │
│ Raw Meat (5g) │ [Your Inventory]    │
│ Torch (3g)    │ Iron Knife (15g)    │
│ Bandage (12g) │ ...                 │
│               │                     │
│ [Tab] Switch  │ [Enter] Confirm     │
│ [Esc] Close   │ [↑↓] Navigate       │
└─────────────────────────────────────┘
```

Script skeleton:
```gdscript
extends Control

var current_npc: NPC
var player: Player
var mode: String = "buy"  # "buy" or "sell"
var selected_index: int = 0

func open_shop(npc: NPC, p: Player):
    current_npc = npc
    player = p
    mode = "buy"
    refresh_display()
    show()

func _input(event):
    if not visible:
        return

    if event.is_action_pressed("ui_cancel"):
        close_shop()
    elif event.is_action_pressed("ui_accept"):
        confirm_transaction()
    elif event.is_action_pressed("toggle_shop_mode"):  # Tab
        toggle_mode()
    # ... navigation logic

func confirm_transaction():
    if mode == "buy":
        ShopSystem.attempt_purchase(current_npc, selected_item_id, 1, player)
    else:
        ShopSystem.attempt_sell(current_npc, selected_item, 1, player)
    refresh_display()
```

#### 5. Integration with WorldGenerator
Modify `res://generation/world_generator.gd`:

```gdscript
static func generate_overworld(seed: int) -> Map:
    # ... existing generation code ...

    # Generate town
    TownGenerator.generate_town(world_map, seed)

    return world_map
```

---

## Phase 1.15: Save System

### Goals
- Serialize entire game state to JSON
- Manage three save slots
- Enable save/load from menu
- Handle death with load prompt

### Architecture

#### New Components
1. **SaveManager** (`autoload/save_manager.gd`)
   - Save/load functions
   - Slot management (1-3)
   - File I/O
   - State serialization/deserialization

2. **Save UI** (`ui/save_screen.tscn`, `ui/load_screen.tscn`)
   - Display save slots
   - Confirm overwrite
   - Load selection

#### EventBus Signals
```gdscript
# New signals
signal game_saved(slot: int)
signal game_loaded(slot: int)
signal save_failed(error: String)
signal load_failed(error: String)
```

### Data Structures

#### Save File Format (JSON)
```json
{
  "metadata": {
    "slot_number": 1,
    "save_name": "Wilderness Survivor",
    "timestamp": "2025-12-31T10:30:00",
    "playtime_turns": 5420,
    "version": "1.0.0"
  },
  "world": {
    "seed": 12345678,
    "current_turn": 5420,
    "time_of_day": 420
  },
  "player": {
    "position": {"x": 52, "y": 48},
    "current_map": "overworld",
    "stats": {
      "str": 12, "dex": 14, "con": 13,
      "int": 15, "wis": 11, "cha": 10
    },
    "health": {"current": 65, "max": 75},
    "survival": {
      "hunger": 78,
      "thirst": 65,
      "temperature": 20,
      "stamina": 85,
      "max_stamina": 100,
      "fatigue": 12
    },
    "inventory": [
      {"item_id": "iron_knife", "count": 1, "durability": 85},
      {"item_id": "waterskin_full", "count": 2},
      {"item_id": "cooked_meat", "count": 5}
    ],
    "equipment": {
      "main_hand": "iron_knife",
      "torso": "leather_armor"
    },
    "gold": 125,
    "xp": 450,
    "known_recipes": ["cooked_meat", "bandage", "waterskin"]
  },
  "maps": {
    "explored_tiles": {
      "overworld": [[true, false, ...], [...]]
    }
  },
  "entities": {
    "dead_enemies": {
      "overworld": [
        {"position": {"x": 45, "y": 50}, "death_turn": 5200, "loot": ["raw_meat"]}
      ]
    },
    "npcs": [
      {
        "id": "shop_keeper",
        "position": {"x": 59, "y": 60},
        "gold": 475,
        "last_restock": 5000,
        "inventory": [...]
      }
    ]
  },
  "structures": {
    "player_built": [
      {"type": "campfire", "position": {"x": 55, "y": 55}, "turns_remaining": 200}
    ]
  }
}
```

#### Save Slot Metadata
```gdscript
class SaveSlotInfo:
    var slot_number: int
    var exists: bool
    var save_name: String
    var timestamp: String
    var playtime_turns: int
    var player_level: int
```

### Implementation Steps

#### 1. SaveManager Autoload
**File**: `res://autoload/save_manager.gd`

```gdscript
extends Node

const SAVE_DIR = "user://saves/"
const SAVE_FILE_PATTERN = "save_slot_%d.json"
const MAX_SLOTS = 3

func _ready():
    _ensure_save_directory()

func _ensure_save_directory():
    var dir = DirAccess.open("user://")
    if not dir.dir_exists("saves"):
        dir.make_dir("saves")

func save_game(slot: int) -> bool:
    if slot < 1 or slot > MAX_SLOTS:
        EventBus.emit_signal("save_failed", "Invalid slot number")
        return false

    var save_data = _serialize_game_state()
    save_data.metadata.slot_number = slot
    save_data.metadata.timestamp = Time.get_datetime_string_from_system()

    var file_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)
    var file = FileAccess.open(file_path, FileAccess.WRITE)

    if not file:
        EventBus.emit_signal("save_failed", "Could not open file for writing")
        return false

    var json_string = JSON.stringify(save_data, "\t")
    file.store_string(json_string)
    file.close()

    EventBus.emit_signal("game_saved", slot)
    EventBus.emit_signal("message_logged", "Game saved to slot %d." % slot)
    return true

func load_game(slot: int) -> bool:
    if slot < 1 or slot > MAX_SLOTS:
        EventBus.emit_signal("load_failed", "Invalid slot number")
        return false

    var file_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)

    if not FileAccess.file_exists(file_path):
        EventBus.emit_signal("load_failed", "Save file does not exist")
        return false

    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        EventBus.emit_signal("load_failed", "Could not open file for reading")
        return false

    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var parse_result = json.parse(json_string)

    if parse_result != OK:
        EventBus.emit_signal("load_failed", "Failed to parse save file")
        return false

    var save_data = json.data
    _deserialize_game_state(save_data)

    EventBus.emit_signal("game_loaded", slot)
    EventBus.emit_signal("message_logged", "Game loaded from slot %d." % slot)
    return true

func get_save_slot_info(slot: int) -> SaveSlotInfo:
    var info = SaveSlotInfo.new()
    info.slot_number = slot

    var file_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)
    info.exists = FileAccess.file_exists(file_path)

    if not info.exists:
        return info

    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        return info

    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    if json.parse(json_string) != OK:
        return info

    var save_data = json.data
    info.save_name = save_data.metadata.get("save_name", "Unnamed Save")
    info.timestamp = save_data.metadata.get("timestamp", "")
    info.playtime_turns = save_data.metadata.get("playtime_turns", 0)

    return info

func delete_save(slot: int) -> bool:
    if slot < 1 or slot > MAX_SLOTS:
        return false

    var file_path = SAVE_DIR + (SAVE_FILE_PATTERN % slot)
    if FileAccess.file_exists(file_path):
        DirAccess.remove_absolute(file_path)
        return true
    return false

# ===== SERIALIZATION =====

func _serialize_game_state() -> Dictionary:
    return {
        "metadata": _serialize_metadata(),
        "world": _serialize_world(),
        "player": _serialize_player(),
        "maps": _serialize_maps(),
        "entities": _serialize_entities(),
        "structures": _serialize_structures()
    }

func _serialize_metadata() -> Dictionary:
    return {
        "save_name": GameManager.save_name,
        "timestamp": "",  # Set during save
        "playtime_turns": TurnManager.current_turn,
        "version": "1.0.0"
    }

func _serialize_world() -> Dictionary:
    return {
        "seed": GameManager.world_seed,
        "current_turn": TurnManager.current_turn,
        "time_of_day": TurnManager.get_turn_of_day()
    }

func _serialize_player() -> Dictionary:
    var player = GameManager.player
    return {
        "position": {"x": player.position.x, "y": player.position.y},
        "current_map": MapManager.current_map.map_id,
        "stats": {
            "str": player.stats.str,
            "dex": player.stats.dex,
            "con": player.stats.con,
            "int": player.stats.int,
            "wis": player.stats.wis,
            "cha": player.stats.cha
        },
        "health": {
            "current": player.current_health,
            "max": player.max_health
        },
        "survival": {
            "hunger": player.survival_stats.hunger,
            "thirst": player.survival_stats.thirst,
            "temperature": player.survival_stats.temperature,
            "stamina": player.survival_stats.stamina,
            "max_stamina": player.survival_stats.max_stamina,
            "fatigue": player.survival_stats.fatigue
        },
        "inventory": _serialize_inventory(player.inventory),
        "equipment": _serialize_equipment(player.equipment),
        "gold": player.gold,
        "xp": player.xp,
        "known_recipes": player.known_recipes.duplicate()
    }

func _serialize_inventory(inventory: Inventory) -> Array:
    var items = []
    for item in inventory.items:
        items.append({
            "item_id": item.id,
            "count": item.count,
            "durability": item.durability if item.has("durability") else null
        })
    return items

func _serialize_equipment(equipment: Dictionary) -> Dictionary:
    var equipped = {}
    for slot in equipment.keys():
        if equipment[slot]:
            equipped[slot] = equipment[slot].id
    return equipped

func _serialize_maps() -> Dictionary:
    # For Phase 1: only save explored tiles
    # Maps regenerate deterministically from seed
    return {
        "explored_tiles": {}  # Future: track FOV reveals
    }

func _serialize_entities() -> Dictionary:
    var dead_enemies = {}
    var npcs = []

    # Serialize NPCs (persistent state)
    for entity in MapManager.current_map.entities:
        if entity is NPC:
            npcs.append({
                "id": entity.npc_type,
                "position": {"x": entity.position.x, "y": entity.position.y},
                "gold": entity.gold,
                "last_restock": entity.last_restock_turn,
                "inventory": _serialize_npc_inventory(entity)
            })

    return {
        "dead_enemies": dead_enemies,
        "npcs": npcs
    }

func _serialize_npc_inventory(npc: NPC) -> Array:
    var inventory = []
    for item_data in npc.trade_inventory:
        inventory.append({
            "item_id": item_data.item_id,
            "count": item_data.count,
            "base_price": item_data.base_price
        })
    return inventory

func _serialize_structures() -> Dictionary:
    return {
        "player_built": []  # Future: Phase 1.13 structures
    }

# ===== DESERIALIZATION =====

func _deserialize_game_state(save_data: Dictionary):
    _deserialize_world(save_data.world)
    _deserialize_player(save_data.player)
    _deserialize_entities(save_data.entities)
    # Maps regenerate from seed automatically

func _deserialize_world(world_data: Dictionary):
    GameManager.world_seed = world_data.seed
    TurnManager.current_turn = world_data.current_turn

func _deserialize_player(player_data: Dictionary):
    var player = GameManager.player

    # Position
    player.position = Vector2i(player_data.position.x, player_data.position.y)

    # Stats
    player.stats.str = player_data.stats.str
    player.stats.dex = player_data.stats.dex
    player.stats.con = player_data.stats.con
    player.stats.int = player_data.stats.int
    player.stats.wis = player_data.stats.wis
    player.stats.cha = player_data.stats.cha

    # Health
    player.current_health = player_data.health.current
    player.max_health = player_data.health.max

    # Survival
    player.survival_stats.hunger = player_data.survival.hunger
    player.survival_stats.thirst = player_data.survival.thirst
    player.survival_stats.temperature = player_data.survival.temperature
    player.survival_stats.stamina = player_data.survival.stamina
    player.survival_stats.max_stamina = player_data.survival.max_stamina
    player.survival_stats.fatigue = player_data.survival.fatigue

    # Inventory
    _deserialize_inventory(player.inventory, player_data.inventory)

    # Equipment
    _deserialize_equipment(player, player_data.equipment)

    # Misc
    player.gold = player_data.gold
    player.xp = player_data.xp
    player.known_recipes = player_data.known_recipes.duplicate()

    # Load correct map
    MapManager.load_map(player_data.current_map)

func _deserialize_inventory(inventory: Inventory, items_data: Array):
    inventory.clear()
    for item_data in items_data:
        var item = ItemManager.create_item(item_data.item_id, item_data.count)
        if item_data.durability != null:
            item.durability = item_data.durability
        inventory.add_item(item)

func _deserialize_equipment(player: Player, equipment_data: Dictionary):
    for slot in equipment_data.keys():
        var item_id = equipment_data[slot]
        var item = ItemManager.create_item(item_id, 1)
        player.equip_item(item, slot)

func _deserialize_entities(entities_data: Dictionary):
    # Restore NPC states
    for npc_data in entities_data.npcs:
        var npc = _find_npc_by_type(npc_data.id)
        if npc:
            npc.position = Vector2i(npc_data.position.x, npc_data.position.y)
            npc.gold = npc_data.gold
            npc.last_restock_turn = npc_data.last_restock
            _deserialize_npc_inventory(npc, npc_data.inventory)

func _find_npc_by_type(npc_type: String) -> NPC:
    for entity in MapManager.current_map.entities:
        if entity is NPC and entity.npc_type == npc_type:
            return entity
    return null

func _deserialize_npc_inventory(npc: NPC, inventory_data: Array):
    npc.trade_inventory.clear()
    for item_data in inventory_data:
        npc.trade_inventory.append({
            "item_id": item_data.item_id,
            "count": item_data.count,
            "base_price": item_data.base_price
        })

class SaveSlotInfo:
    var slot_number: int
    var exists: bool = false
    var save_name: String = "Empty Slot"
    var timestamp: String = ""
    var playtime_turns: int = 0
```

#### 2. Save/Load UI
**File**: `res://ui/save_load_screen.tscn` + `res://ui/save_load_screen.gd`

UI Layout:
```
┌─────────────────────────────────────┐
│ SAVE GAME                           │
├─────────────────────────────────────┤
│ Slot 1: Wilderness Survivor         │
│   Turn 5420 | 2025-12-31 10:30      │
│                                     │
│ Slot 2: Empty Slot                  │
│                                     │
│ Slot 3: Cave Explorer               │
│   Turn 2150 | 2025-12-30 18:45      │
│                                     │
│ [↑↓] Select  [Enter] Confirm        │
│ [Esc] Cancel                        │
└─────────────────────────────────────┘
```

Script:
```gdscript
extends Control

enum Mode { SAVE, LOAD }

@export var mode: Mode = Mode.SAVE
var selected_slot: int = 1
var slot_infos: Array[SaveManager.SaveSlotInfo] = []

func _ready():
    refresh_slots()

func refresh_slots():
    slot_infos.clear()
    for i in range(1, SaveManager.MAX_SLOTS + 1):
        slot_infos.append(SaveManager.get_save_slot_info(i))
    _update_display()

func _input(event):
    if not visible:
        return

    if event.is_action_pressed("ui_up"):
        selected_slot = max(1, selected_slot - 1)
        _update_display()
    elif event.is_action_pressed("ui_down"):
        selected_slot = min(SaveManager.MAX_SLOTS, selected_slot + 1)
        _update_display()
    elif event.is_action_pressed("ui_accept"):
        confirm_action()
    elif event.is_action_pressed("ui_cancel"):
        hide()

func confirm_action():
    if mode == Mode.SAVE:
        if slot_infos[selected_slot - 1].exists:
            # Show confirmation dialog
            show_overwrite_confirmation()
        else:
            save_to_slot()
    else:
        if slot_infos[selected_slot - 1].exists:
            load_from_slot()

func save_to_slot():
    if SaveManager.save_game(selected_slot):
        hide()

func load_from_slot():
    if SaveManager.load_game(selected_slot):
        hide()
        get_tree().change_scene_to_file("res://scenes/game.tscn")
```

#### 3. Death Handling
Modify `res://entities/player.gd`:

```gdscript
func die():
    EventBus.emit_signal("player_died")

    # Show death screen with load option
    var death_screen = preload("res://ui/death_screen.tscn").instantiate()
    get_tree().root.add_child(death_screen)
    death_screen.show()
```

**File**: `res://ui/death_screen.tscn` + `res://ui/death_screen.gd`

```gdscript
extends Control

func _ready():
    $LoadButton.pressed.connect(_on_load_pressed)
    $NewGameButton.pressed.connect(_on_new_game_pressed)

func _on_load_pressed():
    # Show load screen
    var load_screen = preload("res://ui/save_load_screen.tscn").instantiate()
    load_screen.mode = SaveLoadScreen.Mode.LOAD
    get_tree().root.add_child(load_screen)
    queue_free()

func _on_new_game_pressed():
    GameManager.start_new_game()
    queue_free()
```

#### 4. Menu Integration
Add save/load options to game menu (future UI Polish phase will create full menu):

```gdscript
# In game.gd input handling
if event.is_action_pressed("open_save_menu"):
    var save_screen = preload("res://ui/save_load_screen.tscn").instantiate()
    save_screen.mode = SaveLoadScreen.Mode.SAVE
    add_child(save_screen)
```

#### 5. Register SaveManager Autoload
**File**: `project.godot`

```ini
[autoload]
# ... existing autoloads ...
SaveManager="*res://autoload/save_manager.gd"
```

---

## Testing Plan

### Town & Shop Testing
1. Navigate to town area in overworld
2. Verify safe zone (no enemy spawns)
3. Interact with shop NPC
4. Test buy transactions:
   - Sufficient gold
   - Insufficient gold
   - Inventory full
5. Test sell transactions:
   - Valid items
   - Shop has enough gold
   - Shop refuses invalid items
6. Test CHA modifiers on prices
7. Test shop restocking after 500 turns
8. Verify shop inventory persistence

### Save System Testing
1. Create new game, play for several turns
2. Save to slot 1
3. Modify game state (move, collect items)
4. Load slot 1 - verify state restored
5. Save to slot 2 (different state)
6. Load each slot - verify correct states
7. Overwrite existing slot - verify confirmation
8. Test death handling - load from death screen
9. Verify deterministic map regeneration (same seed)
10. Test edge cases:
    - Save with full inventory
    - Save in dungeon
    - Save with equipped items
    - Load after game updates

---

## Integration Checklist

### Files to Create
- [x] `entities/npc.gd`
- [x] `systems/shop_system.gd`
- [x] `generation/town_generator.gd`
- [x] `autoload/save_manager.gd`
- [x] `ui/shop_screen.tscn` + `.gd`
- [x] `ui/save_load_screen.tscn` + `.gd`
- [x] `ui/death_screen.tscn` + `.gd`

### Files to Modify
- [ ] `generation/world_generator.gd` - Add town generation call
- [ ] `entities/player.gd` - Add death handling, gold property
- [ ] `autoload/event_bus.gd` - Add new signals
- [ ] `project.godot` - Register SaveManager autoload
- [ ] `scenes/game.gd` - Add save/load menu keybinds

### Data to Create
- [ ] `data/npcs/shop_keeper.json` (optional for Phase 1)

---

## Success Criteria

### Phase 1.14 Complete When:
- [x] Town exists in overworld with buildings
- [x] Shop NPC is present and interactable
- [x] Buy/sell interface is functional
- [x] Prices are affected by CHA stat
- [x] Shop inventory restocks every 500 turns
- [x] Shop transactions correctly modify player/NPC gold
- [x] Town is a safe zone (no enemy spawns)

### Phase 1.15 Complete When:
- [x] Game state can be saved to JSON
- [x] Game state can be loaded from JSON
- [x] Three save slots are managed correctly
- [x] Save/load UI is functional
- [x] Death prompts player to load
- [x] Maps regenerate deterministically from seed
- [x] All player progress persists (inventory, stats, recipes, etc.)

---

## Notes & Future Considerations

### Town Expansion (Phase 2+)
- Multiple NPCs (blacksmith, alchemist, quest giver)
- Notice board for quests
- Inn for resting
- Larger town area

### Save System Enhancements (Phase 2+)
- Autosave on entering town
- Quick save/load keybinds
- Screenshot thumbnails for slots
- Cloud save integration
- Save compression for large worlds

### Known Limitations (Phase 1)
- Only one town in overworld
- Single shop NPC
- No NPC schedules/movement
- Basic shop inventory (8 items)
- Save anywhere (no restrictions)

---

**Implementation Order**:
1. NPC base class
2. Town generator
3. Integrate town into overworld
4. Shop system logic
5. Shop UI
6. SaveManager autoload
7. Serialization functions
8. Save/Load UI
9. Death screen
10. Testing & integration

**Estimated Complexity**: Medium-High
**Dependencies**: All previous phases (especially 1.10 Inventory)
**Blocks**: Phase 1.16 (UI Polish needs save/load menus)
