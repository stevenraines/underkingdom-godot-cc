# Roguelike Survival Game Framework - Product Requirements Document

## Overview

A turn-based roguelike survival game built in Godot 4 using the Gaea plugin for procedural generation. The game features an open island overworld, dungeon exploration, complex survival mechanics, and discovery-based crafting. Phase 1 establishes an extensible framework with minimal implementations of each system.

### Design Philosophy

- **Extensible First**: Every system should be data-driven and easily expandable
- **Test at Each Step**: Each phase produces a playable build validating specific mechanics
- **Visual Abstraction**: Rendering layer separated from game logic to allow ASCII → graphics swap

---

## Core Specifications

### Genre & Feel
- Turn-based classic roguelike (world advances when player acts)
- Hybrid permadeath: Death reverts to last manual save (up to 3 save slots)
- Save anywhere functionality

### Primary Pillars (Priority Order)
1. Exploration/Discovery
2. Combat
3. Survival
4. Crafting/Building
5. Story/Quests (future phases)

### Technical Stack
- Godot 4.x
- Gaea plugin for procedural generation
- GDScript

### Input
- Phase 1: Keyboard only
- Mouse support deferred to future phase

---

## World Structure

### Overworld
- Procedurally generated island map
- Biomes based on Great Britain geography:
  - Temperate deciduous woodland
  - Moorland/heathland
  - Coastal cliffs
  - Wetland/marsh
  - Highlands/mountains
- World seed system: seed generated at new game, stored with save, produces identical world on regeneration
- Contains:
  - Dungeon entrances (themed to biome)
  - Town (one in Phase 1)
  - Resource nodes
  - Points of interest

### Dungeons
- Separate procedural spaces entered from overworld
- Depth: 1-50 floors (weighted toward shallow: use inverse square or similar distribution)
- Same seed + dungeon ID = identical layout on re-entry
- Themed to biome of entrance location

### Phase 1 Scope
- Small overworld (roughly 100x100 tiles)
- One biome: Temperate deciduous woodland
- One dungeon type: Burial barrow
- One town with single shop

---

## Time & Turn System

### Turn Structure
- Player action consumes 1 turn (movement, attack, interact, craft, wait)
- Some actions may consume multiple turns (complex crafting, resting)
- All entities act in initiative order each turn

### Day/Night Cycle
- 1 full day = 1000 turns
- Dawn: turns 0-150
- Day: turns 150-700
- Dusk: turns 700-850
- Night: turns 850-1000
- Affects: visibility, enemy spawns, temperature, NPC schedules

---

## Character System

### Attributes (Classic RPG)
- **STR** (Strength): Melee damage, carry capacity, physical interactions
- **DEX** (Dexterity): Accuracy, evasion, ranged damage, action speed
- **CON** (Constitution): Max health, survival resistance, poison/disease resistance
- **INT** (Intelligence): Crafting success, recipe discovery hints, magic (future)
- **WIS** (Wisdom): Perception, trap detection, survival efficiency
- **CHA** (Charisma): Shop prices, NPC interactions (future)

### Derived Stats
- **Health**: Base 10 + (CON × 5)
- **Stamina**: Base 50 + (CON × 10)
- **Carry Capacity**: Base 20 + (STR × 5) kg
- **Perception Range**: Base 5 + (WIS / 2) tiles
- **Base Accuracy**: 50% + (DEX × 2)%
- **Base Evasion**: 5% + (DEX × 1)%

### Character Progression
- No predefined classes
- Emergent builds from:
  - Equipment found/crafted
  - Stats increased on level up
  - Recipes discovered
- Experience from: combat, exploration discoveries, crafting successes

---

## Inventory System

### Structure
- Slot-based equipment:
  - Head
  - Torso
  - Hands
  - Legs
  - Feet
  - Main hand
  - Off hand
  - Accessory ×2
- General inventory: unlimited slots, weight-limited

### Encumbrance
- Items have weight in kg
- Current weight / Carry capacity = encumbrance ratio
- Penalties:
  - 0-75%: No penalty
  - 75-100%: Stamina costs +50%
  - 100-125%: Movement costs 2 turns, stamina costs +100%
  - 125%+: Cannot move

---

## Survival Systems

All systems interconnected for emergent gameplay.

### Hunger
- Scale: 0-100 (starts at 100)
- Drain: 1 point per 20 turns base
- Effects:
  - 75-100: Normal
  - 50-75: Stamina regen -25%
  - 25-50: Stamina regen -50%, STR -1
  - 1-25: Stamina regen -75%, STR -2, health drain 1/50 turns
  - 0: Health drain 1/10 turns, STR -3, DEX -2

### Thirst
- Scale: 0-100 (starts at 100)
- Drain: 1 point per 15 turns base
- Effects (more severe than hunger):
  - 75-100: Normal
  - 50-75: Stamina max -20%
  - 25-50: Stamina max -40%, WIS -1, perception range -2
  - 1-25: Health drain 1/25 turns, WIS -2, confusion chance
  - 0: Health drain 1/5 turns, severe stat penalties

### Temperature
- Scale: Hypothermia ← Cold ← Comfortable → Hot → Hyperthermia
- Sources: Weather, biome, time of day, equipment, fires
- Comfortable range: 15-25°C
- Effects:
  - Cold (<10°C): Stamina drain, DEX penalty
  - Freezing (<0°C): Health drain, severe penalties
  - Hot (>30°C): Thirst drain accelerated
  - Hyperthermia (>40°C): Health drain, confusion

### Stamina/Fatigue
- Stamina: 0-Max (derived from CON)
- Fatigue: Accumulated exhaustion 0-100
- Stamina costs:
  - Movement: 1
  - Attack: 3
  - Sprint (2-tile move): 5
  - Heavy attack: 6
- Regeneration: 1/turn when not acting, modified by survival states
- Fatigue:
  - Increases when stamina hits 0
  - Increases slowly over time (1 per 100 turns)
  - Reduces max stamina (fatigue% = max stamina reduction%)
  - Reduced by sleeping

### Health & Injury
- Health: Current/Max HP
- Injury system (future phase - stub for extensibility):
  - Wounds reduce max HP until treated
  - Broken limbs affect specific actions
  - Bleeding causes ongoing damage

### Day/Night Danger
- Night (turns 850-1000):
  - Enemy spawn rate +100%
  - Aggressive enemy behavior
  - Special nocturnal enemies
  - Visibility reduced

---

## Combat System

### Turn-Based Tactical
- Bump-to-attack for basic melee
- Directional attacks for reach weapons
- Abilities with turn cooldowns

### Attack Resolution
```
Hit Chance = Attacker Accuracy - Defender Evasion + Situational Modifiers
Damage = Weapon Base + (STR or DEX modifier) - Armor
```

### Tactical Elements (by Enemy Intelligence)
Enemy AI complexity based on INT attribute:

**INT 1-3 (Bestial)**:
- Direct approach to player
- No terrain awareness
- Attacks when adjacent

**INT 4-6 (Cunning)**:
- Basic flanking attempts
- Retreats when health low
- Uses chokepoints

**INT 7-9 (Tactical)**:
- Group coordination
- Ranged enemies maintain distance
- Uses environmental hazards
- Ambush behavior

**INT 10+ (Strategic)**:
- All above plus:
- Predicts player movement
- Disengages to heal/regroup
- Calls for reinforcements

### Phase 1 Enemies
- **Barrow Wight** (INT 5): Undead guardian, medium threat
- **Grave Rat** (INT 2): Swarm enemy, low individual threat
- **Woodland Wolf** (INT 4): Overworld enemy, pack tactics

### Enemy Persistence
- Killed enemies stay dead when re-entering a map
- Dead enemy positions stored in save data per map
- Corpses remain for 500 turns, then disappear
- **Corpses are containers**: Interact to open loot interface (like chests)
- Corpse inventory generated from enemy loot table on death
- When corpse disappears, any remaining loot is lost
- Enemy respawn: None in Phase 1 (future: time-based respawn for overworld only)

---

## Crafting System

### Discovery-Based
- No recipe book at start
- Recipes discovered by:
  - Experimentation (combining items)
  - Finding recipe scrolls/books
  - Learning from NPCs (future)
  - Examining crafted items found in world

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

### Phase 1 Recipes
Minimum set to validate system:

**Consumables**:
- Cooked Meat: Raw Meat + (within 3 tiles of fire source)
- Bandage: Cloth + Herb
- Waterskin: Leather + Cord

### Proximity Crafting
Some recipes require proximity to a heat/fire source rather than a tool:
- Player must be within 3 tiles of campfire or other fire source
- Fire source checked at craft attempt time
- **UI indication**: 
  - HUD shows "Near fire" text when in range
  - Crafting screen shows fire-required recipes as available/unavailable
  - Unavailable fire recipes display "Fire required" in red

**Tools**:
- Knife: Sharp material + Handle material
- Hammer: Hard material + Handle material

**Equipment**:
- Leather Armor: Leather ×3 + Cord + (Knife)
- Wooden Shield: Wood ×2 + Cord

---

## Base Building

### Phase 1 Scope
- Campfire: Provides warmth, cooking, light
- Lean-to: Basic shelter, reduces exposure
- Storage chest: Persistent container

### Placement Rules
- Overworld only (no building in dungeons)
- Cannot block paths
- Persists in save file

### Future Extensibility
- Wall/floor placement
- Crafting stations
- Defenses
- NPC shelters

---

## Town & Economy

### Phase 1 Town
- Single town in overworld
- Safe zone (no enemies)
- Contains:
  - General Shop (1 NPC)
  - Well (water source)
  - Notice board (future: quests)

### Shop System
- Buy/sell interface
- Prices affected by CHA
- Shop has limited gold
- Inventory refreshes periodically (every 500 turns)

### Currency
- Gold coins (weight: 0.01 kg each)

### Phase 1 Shop Inventory
- Food items
- Basic tools
- Common materials
- Waterskins
- Torches

---

## Procedural Generation (Gaea Integration)

### World Generation Pipeline
1. Generate heightmap from seed
2. Apply biome rules based on elevation, moisture
3. Place features (towns, dungeon entrances, resources)
4. Generate connectivity paths
5. Store generation parameters with save

### Repeatability Requirement
- Same seed = identical world
- Dungeon regeneration: `hash(world_seed + dungeon_id + floor_number)` = floor seed
- All RNG during generation must use seeded random

### Gaea Configuration (Phase 1)
- Study Gaea's generator system
- Create custom generator for:
  - Overworld terrain
  - Burial barrow dungeon rooms
  - Room connection logic

### Dungeon Generation Rules
- Burial Barrow theme:
  - Rectangular rooms
  - Narrow corridors
  - Central burial chamber on deepest floor
  - Tomb alcoves with loot/enemies
  - Occasional cave-in blocked paths

---

## Rendering Architecture

### Abstraction Layer
Core game logic must not reference specific visuals.

```
┌─────────────────┐
│   Game Logic    │  (Entities, positions, states)
└────────┬────────┘
         │ Events/State
         ▼
┌─────────────────┐
│ Render Interface│  (Abstract: "Draw entity X at tile Y")
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐ ┌───────┐
│ ASCII │ │Sprite │  (Concrete implementations)
│Renderer│ │Renderer│
└───────┘ └───────┘
```

### Phase 1: ASCII Renderer
- TileMapLayer for terrain
- TileMapLayer for entities
- Tileset of ASCII characters as sprites
- Character map:
  - `@` Player
  - `W` Wight
  - `r` Rat
  - `w` Wolf
  - `%` Corpse
  - `.` Floor
  - `#` Wall
  - `+` Door
  - `>` Stairs down
  - `<` Stairs up
  - `T` Tree
  - `~` Water
  - `$` Shop
  - `&` Chest/Container
  - Colors indicate state/type

### Future: Graphics Renderer
- Same TileMapLayer structure
- Different tileset with sprite graphics
- Animation support via AnimatedSprite2D overlay or animated tiles
- Entity components include animation state

---

## Save System

### Save Data Structure
```
SaveData:
  - metadata:
      slot_number: int
      save_name: string
      timestamp: datetime
      playtime_turns: int
  - world:
      seed: int
      current_turn: int
      time_of_day: int
  - player:
      position: Vector2i
      current_map: string (overworld/dungeon_id)
      attributes: dict
      inventory: array
      equipment: dict
      survival_states: dict
      known_recipes: array
  - maps:
      visited_maps: dict (map_id -> revealed tiles)
      dead_enemies: dict (map_id -> array of {position, death_turn, loot})
  - entities:
      persistent_entities: array (NPCs, containers)
      corpses: array (position, death_turn, remaining_loot)
  - structures:
      player_built: array
```

### Save/Load Flow
1. Save: Serialize current state → JSON → file
2. Load: File → JSON → Reconstruct state
3. Death: Prompt to load save or start new game

### Three Slot System
- Slots 1-3 available
- Can overwrite existing saves
- Save includes screenshot thumbnail (future)

---

## Implementation Phases

### Phase 1: Core Framework (Current)
**Goal**: Playable loop validating all systems with minimal content

#### 1.1 Project Setup
- [X] Create Godot 4 project
- [ ] Install and configure Gaea plugin
- [X] Establish folder structure
- [X] Create autoload singletons (GameManager, EventBus)

#### 1.2 Turn System & Time
- [X] Implement turn manager
- [X] Day/night cycle
- [X] Action queue system
- [X] Turn counter display

#### 1.3 Rendering Foundation
- [X] Create ASCII tileset (bitmap font or generated)
- [X] Implement RenderInterface base class
- [X] Implement ASCIIRenderer
- [X] Camera following player

#### 1.4 Map System
- [X] Tile data structure
- [X] Map class (holds tiles, entities)
- [X] Map manager (handles multiple maps, transitions)
- [X] Basic FOV/visibility

#### 1.5 Procedural Generation
- [ ] Gaea learning/prototyping
- [X] Seeded random wrapper
- [X] Overworld generator (simple version)
- [X] Burial barrow generator
- [X] Regeneration verification tests

#### 1.6 Player & Movement
- [X] Player entity
- [X] Turn-based movement (arrow keys/WASD)
- [X] Collision detection
- [X] Map transitions (stairs, dungeon entrance)

#### 1.7 Entity System
- [X] Base Entity class
- [X] Component system (or composition pattern)
- [X] Entity manager
- [X] Basic enemy entities

#### 1.8 Combat
- [X] Attack resolution
- [X] Health/damage
- [X] Death handling
- [X] Enemy AI (one per INT tier: 2, 5)

#### 1.9 Survival Systems
- [X] Survival stats (hunger, thirst, temp, stamina, fatigue)
- [X] Stat drain over time
- [X] Effect application
- [X] UI indicators

#### 1.10 Inventory & Equipment
- [X] Inventory data structure
- [X] Equipment slots
- [X] Weight/encumbrance
- [X] Pickup/drop
- [X] Equip/unequip
- [X] Basic UI

#### 1.11 Crafting
- [X] Recipe data structure
- [X] Crafting attempt logic
- [X] Recipe memory
- [ ] Discovery hints
- [X] Tool requirement checking
- [X] Phase 1 recipes implemented
- [X] Basic UI

#### 1.12 Items
- [X] Item base class
- [X] Consumables (food, bandages)
- [X] Equipment (weapon, armor)
- [X] Tools
- [X] Materials
- [X] Phase 1 items implemented

#### 1.13 Base Building
- [X] Placeable structure system
- [X] Campfire (warmth, cooking)
- [X] Lean-to (shelter)
- [X] Storage chest

#### 1.14 Town & Shop
- [X] Town area in overworld
- [X] Shop NPC
- [X] Buy/sell interface
- [X] Price calculation (CHA modifier)
- [X] Shop inventory management

#### 1.15 Save System
- [X] Save data serialization
- [X] Save/load functions
- [X] Three slot management
- [ ] Death → show death splash screen and prompt to return to main menu
- [X] Save anywhere trigger (menu)
- [X] Support Saves in Web (html/wasm) deployment

#### 1.16 UI Polish
- [X] Main menu
- [ ] Character sheet
- [ ] Contextual Help for Game sheet (? key - show all keys available to character)

#### 1.17 Overworld Generation
- [ ] Expand town to 2 buildings: general store (general goods) and blacksmith (armour)
- [ ] Mining for ore (rocks with ore in it)
- [ ] Overworld Generation with perlin noise
- [ ] Pop-up map of entire island (in miniature)

#### 1.18 Enhanced Combat
- [ ] Targeting an enemy
- [ ] Ranged weapon attacks


---

### Phase 2: Systems Expansion (Future)
- Barrow dungeon type has max of 3 levels
- When reentering a level, creatures and items retain last position instead of resetting
- Weather system
- Allow selection of world-seed at game creation (default 'Underkingdom') for repeatable worlds
- Player leveling based on XP
- Damage type (fire, cold, electric, etc.) and corresponding resistance modifiers for enemies.


### Phase 3: Advanced Features (Future)
- Additional biomes (4 remaining)
- Dungeon types per biome
- Skill system (lockpicking, stealth, arcana, nature, etc)
- Special abilities (regeneration, fire breathing, etc)
- Conditions (prone, poisoned, blinded, etc) (see https://www.dandwiki.com/wiki/5e_SRD:Conditions)
- More NPCs
- Faction reputation
- Magic system
- Quest system
- Procedural quests
- Sound design
- More enemies (3+ per biome)
- Expanded recipe tree
- More equipment tiers
- Injury system implementation

### Phase 4: Graphics Mode (Future)
- Sprite tileset creation
- GraphicsRenderer implementation
- Animation system
- Visual effects
- Renderer toggle in options

---

## Data File Formats

All game content should be data-driven for extensibility.

### Items (JSON)
```json
{
  "id": "iron_knife",
  "name": "Iron Knife",
  "type": "tool",
  "subtype": "knife",
  "weight": 0.5,
  "durability": 100,
  "value": 15,
  "ascii_char": "/",
  "ascii_color": "#AAAAAA",
  "sprite": "res://sprites/items/iron_knife.png",
  "effects": {
    "tool_type": "knife",
    "damage": 4
  }
}
```

### Recipes (JSON)
```json
{
  "id": "leather_armor",
  "result": "leather_armor",
  "result_count": 1,
  "ingredients": [
    {"item": "leather", "count": 3},
    {"item": "cord", "count": 1}
  ],
  "tool_required": "knife",
  "difficulty": 3,
  "discovery_hint": "Protective garment from animal hides"
}
```

### Enemies (JSON)
```json
{
  "id": "barrow_wight",
  "name": "Barrow Wight",
  "ascii_char": "W",
  "ascii_color": "#44FF44",
  "stats": {
    "health": 25,
    "str": 12,
    "dex": 8,
    "con": 14,
    "int": 5,
    "wis": 6
  },
  "behavior": "guardian",
  "loot_table": "undead_common",
  "xp_value": 50
}
```

---

## Technical Notes

### Godot Project Structure
```
res://
├── autoload/
│   ├── game_manager.gd
│   ├── event_bus.gd
│   ├── save_manager.gd
│   └── turn_manager.gd
├── entities/
│   ├── entity.gd
│   ├── player.gd
│   ├── enemy.gd
│   └── npc.gd
├── systems/
│   ├── combat_system.gd
│   ├── survival_system.gd
│   ├── crafting_system.gd
│   ├── inventory_system.gd
│   └── ai/
│       ├── ai_base.gd
│       └── behaviors/
├── maps/
│   ├── map.gd
│   ├── map_manager.gd
│   └── tile_data.gd
├── generation/
│   ├── world_generator.gd
│   ├── dungeon_generators/
│   │   └── burial_barrow.gd
│   └── gaea_configs/
├── rendering/
│   ├── render_interface.gd
│   ├── ascii_renderer.gd
│   └── tilesets/
├── ui/
│   ├── hud.tscn
│   ├── inventory_screen.tscn
│   ├── crafting_screen.tscn
│   └── main_menu.tscn
├── data/
│   ├── items/
│   ├── recipes/
│   ├── enemies/
│   └── biomes/
└── scenes/
    ├── main.tscn
    └── game.tscn
```

### Key Architectural Decisions

1. **Event-Driven**: Use signal bus for loose coupling between systems
2. **Data-Driven**: All content in JSON/Resource files, not hardcoded
3. **Component Preference**: Favor composition over inheritance for entities
4. **Render Separation**: Game logic never references visual nodes directly
5. **Seeded Randomness**: All procedural generation uses injectable seed

---

## Acceptance Criteria (Phase 1)

Phase 1 is complete when:

1. ✓ Player can start new game with generated world
2. ✓ Overworld with single biome is explorable
3. ✓ One dungeon (burial barrow) is enterable with multiple floors
4. ✓ Re-entering dungeon produces identical layout
5. ✓ Turn-based movement and time passes
6. ✓ Day/night cycle affects gameplay
7. ✓ Combat works against 2+ enemy types
8. ✓ All 5 survival systems drain and affect player
9. ✓ Items can be picked up, equipped, used
10. ✓ At least 5 recipes discoverable through experimentation
11. ✓ Tools affect crafting availability
12. ✓ Campfire, lean-to, chest can be built
13. ✓ Town shop allows buying/selling
14. ✓ Game can be saved to 3 slots and loaded
15. ✓ Death returns to last save
16. ✓ ASCII visuals render correctly
17. ✓ Framework clearly extensible for Phase 2

---

## Open Questions

To be resolved during implementation:

1. **Gaea Fit**: May need custom generator if Gaea doesn't suit roguelike room/corridor style
2. **Performance**: Large dungeon floors (50 deep) - lazy generation or pre-generate?
3. **Balance**: Initial numbers are estimates - need playtesting

---

## Appendix A: Phase 1 Content Lists

### Items
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
| torch | Torch | tool | 0.5 | | |
| gold_coin | Gold Coin | currency | 0.01 | $ |

### Enemies
| ID | Name | Location | INT | ASCII |
|----|------|----------|-----|-------|
| grave_rat | Grave Rat | Dungeon | 2 | r |
| barrow_wight | Barrow Wight | Dungeon | 5 | W |
| woodland_wolf | Woodland Wolf | Overworld | 4 | w |

### Recipes
| Result | Ingredients | Tool/Requirement | Difficulty |
|--------|-------------|------------------|------------|
| Cooked Meat | Raw Meat | Fire (3 tiles) | 1 |
| Bandage | Cloth + Herb | None | 1 |
| Waterskin | Leather + Cord | Knife | 2 |
| Flint Knife | Flint + Wood | None | 1 |
| Iron Knife | Iron Ore + Wood | Hammer | 3 |
| Hammer | Iron Ore + Wood ×2 | None | 2 |
| Leather Armor | Leather ×3 + Cord | Knife | 3 |
| Wooden Shield | Wood ×2 + Cord | Knife | 2 |

---

*Document Version: 1.0*
*Last Updated: Phase 1 Planning*
