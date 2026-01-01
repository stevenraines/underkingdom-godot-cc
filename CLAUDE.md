# Underkingdom - Roguelike Survival Game

**Godot 4.x Turn-Based Roguelike** with ASCII rendering, procedural generation, and survival mechanics.

---

## Architecture Overview

### Event-Driven Architecture
The game uses a **signal-based event bus** for loose coupling between systems:
- **EventBus** (autoload): Central signal hub for all cross-system communication
- Systems emit signals, other systems listen - no direct dependencies
- Key signals: `turn_advanced`, `player_moved`, `entity_died`, `item_picked_up`, etc.

### Autoload Singletons (Managers)
Six persistent managers handle core systems:
1. **EventBus** - Signal relay for all events
2. **TurnManager** - Turn-based game loop, day/night cycle (1000 turns/day)
3. **GameManager** - High-level game state, world seed, save slot management
4. **MapManager** - Map caching, generation, transitions between overworld/dungeons
5. **EntityManager** - Enemy definitions, entity spawning, turn processing
6. **ItemManager** - Item definitions, item creation from JSON data

### Rendering Abstraction
Game logic never touches visuals directly:
```
Game Logic (positions, states)
    ↓ events/state
RenderInterface (abstract)
    ↓ concrete implementation
ASCIIRenderer (TileMapLayer-based)
```

**Current Implementation**: ASCIIRenderer using Unicode tileset (895 characters, 32-column grid)
- Rectangular tiles (38×64 pixels) optimized for monospace fonts
- Two TileMapLayer nodes: TerrainLayer (floors/walls) + EntityLayer (entities/items)
- Runtime color modulation via white tiles + modulated_cells dictionaries
- Floor hiding system: periods don't render when entities stand on them

**Future**: Graphics renderer can swap in without touching game logic

---

## Core Systems

### Turn-Based Game Loop
1. Player takes action (movement, attack, interact, wait)
2. `TurnManager.advance_turn()` increments turn counter
3. `EntityManager.process_entity_turns()` runs all enemy AI
4. Survival systems drain (hunger, thirst, fatigue)
5. Repeat

**Day/Night Cycle**: 1000 turns = 1 day
- Dawn (0-150), Day (150-700), Dusk (700-850), Night (850-1000)
- Affects: visibility range, enemy spawn rates, survival drain rates

### Entity-Component System
**Base Classes**:
- `Entity` (base) - Position, ASCII char, color, blocking, health, stats (STR/DEX/CON/INT/WIS/CHA)
- `Player` (extends Entity) - Inventory, equipment, survival stats, movement, interaction
- `Enemy` (extends Entity) - AI behavior (wander/guardian/aggressive/pack), loot table, aggro range
- `GroundItem` (extends Entity) - Item on ground, despawn timer

**Stats & Derived Values**:
- Health: Base 10 + (CON × 5)
- Stamina: Base 50 + (CON × 10)
- Carry Capacity: Base 20 + (STR × 5) kg
- Perception Range: Base 5 + (WIS / 2) tiles

### Map System
**Map Class**: Holds tiles (TileData), entities, metadata
- `map_id` (string): "overworld" or "dungeon_barrow_floor_N"
- `tiles` (2D array): TileData objects with walkable/transparent/ascii_char
- `entities` (array): Entities on this map

**MapManager**:
- Caches generated maps (same seed = same map)
- Handles transitions (stairs, dungeon entrances)
- Current map always accessible via `MapManager.current_map`

**TileData Properties**:
- `tile_type`: "floor", "wall", "tree", "water", "stairs_down", etc.
- `walkable`: Can entities move through?
- `transparent`: Does it block line of sight?
- `ascii_char`: Display character (e.g., ".", "░", ">")

### Procedural Generation (Seeded)
**World Seed**: Generated at new game, stored in save, deterministic regeneration
- Overworld: 100×100 temperate woodland biome (trees, water, grass)
- Dungeons: 50×50 burial barrow floors (1-50 depth), rectangular rooms + corridors
- Floor seed: `hash(world_seed + dungeon_id + floor_number)`

**Generators**:
- `WorldGenerator.generate_overworld(seed)` - Returns Map
- `BurialBarrowGenerator.generate_floor(world_seed, floor_number)` - Returns Map

**Wall Culling**: Dungeons use flood-fill algorithm to remove inaccessible wall tiles for cleaner visuals

### Combat System
**Turn-Based Tactical**:
- Bump-to-attack for melee (cardinal adjacency)
- Attack resolution: `Hit Chance = Attacker Accuracy - Defender Evasion`
- Damage: `Weapon Base + STR Modifier - Armor`

**Enemy AI** (based on INT):
- INT 1-3: Direct approach, no tactics
- INT 4-6: Flanking, retreats when low health
- INT 7-9: Group coordination, uses environment
- INT 10+: Predicts movement, calls reinforcements

**Phase 1 Enemies**:
- Grave Rat (INT 2): Swarm enemy, "r"
- Woodland Wolf (INT 4): Pack tactics, "w"
- Barrow Wight (INT 5): Undead guardian, "W"

### Survival Systems
All interconnected for emergent gameplay:

**Hunger** (0-100):
- Drain: 1 point per 20 turns
- Effects: Stamina regen penalty, STR loss, health drain at 0

**Thirst** (0-100):
- Drain: 1 point per 15 turns (faster than hunger)
- Effects: Stamina max reduction, WIS loss, perception loss, confusion, severe health drain

**Temperature** (Hypothermia ↔ Comfortable ↔ Hyperthermia):
- Sources: Weather, biome, time of day, equipment, fires
- Comfortable: 15-25°C
- Cold/Hot: Stat penalties, accelerated drain rates

**Stamina/Fatigue**:
- Stamina: 0-Max (CON-based), costs for movement/attacks
- Fatigue: 0-100, accumulates when stamina hits 0, reduces max stamina
- Regen: 1/turn when not acting

### Inventory & Equipment
**Structure**:
- Equipment slots: head, torso, hands, legs, feet, main_hand, off_hand, accessory×2
- General inventory: Unlimited slots, weight-limited

**Encumbrance**:
- 0-75%: No penalty
- 75-100%: Stamina costs +50%
- 100-125%: Movement costs 2 turns, stamina +100%
- 125%+: Cannot move

**Items**:
- All items defined in JSON (`data/items/*.json`)
- Properties: id, name, weight, value, stack size, ASCII char/color, durability
- Types: consumable, material, tool, weapon, armor, currency
- Equipped items provide stat bonuses (weapon damage, armor)

**GroundItems**:
- Items on the ground rendered on EntityLayer
- Floor tile (period) hidden when item/entity stands on it
- Pickup/drop mechanics integrated with movement

### Harvest System
**Generic resource harvesting** with configurable behaviors:
- All resources defined in separate JSON files (`data/resources/*.json`)
- Loaded recursively from subdirectories like items and enemies
- Three harvest behaviors: permanent destruction, renewable, non-consumable
- Tool requirements, stamina costs, yield tables with probability

**Harvest Behaviors**:
- **Destroy Permanent**: Resource destroyed forever (trees → wood, rocks → stone)
- **Destroy Renewable**: Resource respawns after N turns (wheat → grain)
- **Non-Consumable**: Never depletes (water → fresh water)

**Implemented Resources**:
- Trees (flint knife/iron knife/axe) → 2-4 wood, destroyed permanently
- Rocks (pickaxe) → 3-6 stone + 0-2 flint (30% chance), destroyed permanently
- Wheat (flint knife/iron knife/sickle) → 1-3 wheat, respawns after 5000 turns
- Water (waterskin/bottle) → waterskin full, never depletes
- Iron Ore (pickaxe) → 2-5 iron ore, destroyed permanently

**Player Interaction**:
- Press 'H' key to harvest
- Select direction with arrow keys or WASD
- System validates tool, consumes stamina, generates yields
- Renewable resources tracked for automatic respawn

**Extensibility**:
- Add new resources via JSON without code changes
- Configure yields with probability for rare drops
- Customize respawn rates per resource type

---

## Current Phase: 1.15 Complete → 1.16 Next

### Phase 1.10 (Inventory & Equipment) - ✅ COMPLETE
- Item base class with JSON data loading
- Inventory system with weight/encumbrance
- Equipment slots with stat bonuses
- Ground items, pickup/drop mechanics
- Basic inventory UI

### Phase 1.11 (Crafting) - ✅ COMPLETE
- Recipe data structure
- Crafting attempt logic (success/failure)
- Recipe memory (unlocking system)
- Discovery hints (INT-based)
- Tool requirement checking
- Proximity crafting (fire sources)
- Phase 1 recipes implemented
- Basic crafting UI

### Phase 1.12 (Harvest System) - ✅ COMPLETE
- Generic resource harvesting with configurable behaviors
- Three harvest behaviors: permanent destruction, renewable, non-consumable
- Tool requirements, stamina costs, yield tables with probability
- Resources defined in JSON files

### Phase 1.13 (Items) - ✅ COMPLETE
- All Phase 1 items implemented via JSON
- Consumables, materials, tools, weapons, armor
- ItemManager loads all items recursively

### Phase 1.14 (Town & Shop) - ✅ COMPLETE
- NPC base class with dialogue, gold, trade inventory
- ShopSystem with CHA-based pricing
- Town generation (20×20 safe zone)
- Shop NPC spawning from metadata
- Buy/sell interface integration

### Phase 1.15 (Save System) - ✅ COMPLETE
- SaveManager autoload with JSON serialization
- Three save slot management
- Comprehensive state serialization (world, player, NPCs, inventory)
- Deterministic map regeneration from seed
- Save/load operations with error handling

### Phase 1.16 (UI Polish) - ✅ COMPLETE
- Main menu with new game/load/quit options
- Character sheet (P key) with attributes, combat stats, survival stats
- Help screen (F1/? key) with keybindings and tips
- Keyboard navigation for all screens
- Consistent styling across inventory, character, and help screens

### Phase 1.17 (Overworld Generation) - ✅ COMPLETE
**Scope**: Enhanced overworld with improved town and generation
- [x] Expand town to 2 buildings: general store and blacksmith
- [x] Overworld generation with perlin noise (100x100 island map)
- [x] Pop-up map of entire island (M key - miniature island view)
- [x] Mining for ore (iron ore deposits spawn on island)

---

## File Structure

```
res://
├── autoload/           # Persistent managers
│   ├── event_bus.gd
│   ├── turn_manager.gd
│   ├── game_manager.gd
│   ├── map_manager.gd
│   ├── entity_manager.gd
│   ├── item_manager.gd
│   ├── recipe_manager.gd
│   └── save_manager.gd
├── entities/           # Entity classes
│   ├── entity.gd
│   ├── player.gd
│   ├── enemy.gd
│   ├── npc.gd
│   └── ground_item.gd
├── items/              # Item system
│   └── item.gd
├── systems/            # Game systems
│   ├── combat_system.gd
│   ├── survival_system.gd
│   ├── inventory_system.gd
│   ├── harvest_system.gd
│   ├── fov_system.gd
│   └── input_handler.gd
├── maps/               # Map data structures
│   ├── map.gd
│   └── tile_data.gd
├── generation/         # Procedural generation
│   ├── seeded_random.gd
│   ├── world_generator.gd
│   ├── town_generator.gd
│   └── dungeon_generators/
│       └── burial_barrow.gd
├── rendering/          # Rendering layer
│   ├── render_interface.gd
│   ├── ascii_renderer.gd
│   ├── generate_tilesets.py  # Python script (PIL)
│   └── tilesets/
│       ├── unicode_tileset.png  # 1216×1792, 32-column grid
│       ├── ascii_tileset.png    # 608×1024, CP437
│       └── *.txt                # Character maps
├── ui/                 # User interface
│   ├── hud.tscn
│   └── inventory_screen.tscn
├── data/               # JSON data files
│   ├── resources/      # Harvestable resource definitions
│   ├── items/
│   │   ├── consumables/
│   │   ├── materials/
│   │   ├── tools/
│   │   ├── weapons/
│   │   ├── armor/
│   │   └── misc/
│   ├── recipes/
│   │   ├── consumables/
│   │   ├── tools/
│   │   └── equipment/
│   ├── structures/
│   └── enemies/
├── scenes/             # Scene files
│   ├── main.tscn
│   └── game.tscn
└── plans/              # Implementation plans
    ├── roguelike-prd.md
    ├── core-loop-implementation.md
    ├── entity-system-implementation.md
    ├── combat-system-implementation.md
    ├── survival-systems-implementation.md
    ├── inventory-system-implementation.md
    └── harvest-system-implementation.md
```

---

## Key Design Patterns

1. **Singleton Autoloads**: Global managers for cross-cutting concerns
2. **Signal-Based Events**: Loose coupling via EventBus
3. **Strategy Pattern**: RenderInterface → ASCIIRenderer (swappable)
4. **Data-Driven**: All content in JSON, not hardcoded
5. **Seeded Randomness**: Deterministic procedural generation
6. **Composition Over Inheritance**: Components for extensibility

---

## Development Workflow

### Branch Naming
- `feature/system-name` (e.g., `feature/crafting-system`)
- Merge to `main` when phase complete

### Testing Approach
- Playtest after each phase
- Verify deterministic generation (same seed = same world)
- Check turn system advances correctly
- Validate survival stat drain rates

### Adding New Content
**Items**: Add to `data/items/*.json`, reload via ItemManager
**Enemies**: Add to `data/enemies/*.json`, reload via EntityManager
**Recipes**: Add to `data/recipes/*.json` (Phase 1.11)

---

## Rendering Technical Details

### Unicode Tileset
- **File**: `rendering/tilesets/unicode_tileset.png`
- **Dimensions**: 1216×1792 pixels (32 cols × 28 rows)
- **Tile Size**: 38×64 pixels (rectangular, not square)
- **Characters**: 895 total (Basic Latin, Latin-1, Box Drawing, Block Elements, Geometric Shapes, Symbols, Dingbats)
- **Font**: DejaVu Sans Mono (58pt), generated via Python PIL

### Character Mapping
Built-in `unicode_char_map` dictionary in `ascii_renderer.gd`:
- Maps character → tileset index
- Index → grid coords: `col = index % 32, row = index / 32`

### Color Modulation
- All tiles rendered white in tileset
- Runtime coloring via `modulated_cells` dictionaries
- Separate tracking for terrain + entity layers
- Custom tile data override for modulation

### Floor Hiding System
When entities/items render:
1. Check if standing on floor tile (period ".")
2. Store floor data in `hidden_floor_positions` dictionary
3. Erase floor tile from TerrainLayer
4. When entity moves, restore floor tile from stored data

---

## Common Tasks

### Adding a New Enemy
1. Create JSON in `data/enemies/[location]/enemy_name.json`
2. EntityManager auto-loads on startup
3. Spawn via `EntityManager.spawn_enemy("enemy_id", position)`

### Adding a New Item
1. Create JSON in `data/items/[type].json`
2. ItemManager auto-loads on startup
3. Create via `ItemManager.create_item("item_id", count)`

### Creating a New Map
1. Implement generator in `generation/` (extend Map class)
2. Register in MapManager's `get_or_generate_map()`
3. Use `SeededRandom` for deterministic generation

### Adding a New UI Screen
1. Create scene in `ui/screen_name.tscn`
2. Connect signals to EventBus
3. Register in `game.gd` input handling

---

## Debugging Tips

### Check Turn System
```gdscript
print("Turn: %d | %s" % [TurnManager.current_turn, TurnManager.time_of_day])
```

### Verify Map Generation
```gdscript
var map1 = WorldGenerator.generate_overworld(12345)
var map2 = WorldGenerator.generate_overworld(12345)
# Should be identical
```

### Inspect Entity State
```gdscript
print("Player HP: %d/%d" % [player.current_health, player.max_health])
print("Inventory Weight: %.1f/%.1f kg" % [player.inventory.get_total_weight(), player.inventory.max_weight])
```

### Watch Signals
```gdscript
EventBus.turn_advanced.connect(func(turn): print("Turn advanced: ", turn))
```

---

## Performance Notes

- **Map Size**: 100×100 overworld (10k tiles), 50×50 dungeons (2.5k tiles) - lightweight
- **TileMapLayer**: Godot 4's optimized rendering, handles thousands of tiles efficiently
- **Entity Count**: Typical dungeon ~20-50 enemies, overworld ~100 entities
- **No Performance Issues Expected**: Turn-based, no real-time physics

---

## Future Phases (Post-1.17)

- Phase 1.18: Enhanced Combat (targeting, ranged weapons)
- Phase 2: Systems Expansion (weather, player leveling, damage types)

---

**Last Updated**: December 31, 2025
**Current Branch**: `feature/town-blacksmith`
**Next Phase**: 1.17 - Overworld Generation (perlin noise, minimap, mining)
