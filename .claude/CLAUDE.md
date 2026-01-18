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
Key persistent managers handle core systems:
1. **EventBus** - Signal relay for all events
2. **TurnManager** - Turn-based game loop, day/night cycle
3. **GameManager** - High-level game state, world seed, save slot management
4. **MapManager** - Map caching, generation, transitions between overworld/dungeons
5. **EntityManager** - Enemy definitions, entity spawning, turn processing
6. **ItemManager** - Item definitions, item creation from JSON data (legacy + templated)
7. **VariantManager** - Item templates and variant definitions for dynamic item generation
8. **SpellManager** - Spell definitions, casting requirements, spell lookup by school/level

### Rendering Abstraction
Game logic never touches visuals directly:
```
Game Logic (positions, states) → RenderInterface (abstract) → ASCIIRenderer (TileMapLayer-based)
```
Future graphics renderer can swap in without touching game logic.

---

## Key Design Patterns

1. **Singleton Autoloads**: Global managers for cross-cutting concerns
2. **Signal-Based Events**: Loose coupling via EventBus
3. **Strategy Pattern**: RenderInterface → ASCIIRenderer (swappable)
4. **Data-Driven Design**: All content defined in JSON, loaded at runtime
5. **Seeded Randomness**: Deterministic procedural generation
6. **Composition Over Inheritance**: Components for extensibility

### Data-Driven Design Principle
**IMPORTANT**: All game content MUST be data-driven. Never hardcode definitions in manager classes.

**Pattern for new systems:**
1. Create JSON files in `data/<system_name>/` directory (one file per definition)
2. Manager loads definitions from JSON at `_ready()` using `DirAccess` + `JSON.parse()`
3. Definitions stored in a dictionary keyed by ID
4. Runtime instances reference loaded definitions

**Existing data-driven systems:**
- Items: `data/items/` → ItemManager
- Item Templates: `data/item_templates/` → VariantManager
- Item Variants: `data/variants/` → VariantManager
- Enemies: `data/enemies/` → EntityManager
- Recipes: `data/recipes/` → RecipeManager
- Resources: `data/resources/` → HarvestSystem
- Dungeons: `data/dungeons/` → DungeonManager
- Features: `data/features/` → FeatureManager
- Hazards: `data/hazards/` → HazardManager
- Spells: `data/spells/` → SpellManager
- Creature Types: `data/creature_types/` → CreatureTypeManager

### Data Value Conventions
**IMPORTANT**: Use consistent value formats across all JSON data files:

- **Probability/Chance values**: Always use decimal (0.0-1.0), never percentages
- **Weight values**: Use kilograms as the unit
- **Distance/Range values**: Use tiles as the unit (integers)

---

## Critical GDScript Patterns

### Cross-Script Class References (CRITICAL)
**MANDATORY**: When one script needs to call methods on another script class, you MUST use `preload()` at the top of the file. **Never rely on `class_name` being globally available**.

```gdscript
# At the TOP of your script, after extends:
const RangedCombatSystemClass = preload("res://systems/ranged_combat_system.gd")
const CombatSystemClass = preload("res://systems/combat_system.gd")

# Then use the preloaded const throughout:
func some_function():
    var result = RangedCombatSystemClass.attempt_ranged_attack(...)
```

**Naming Convention**: Use `*Class` suffix for preloaded script constants.

**Checklist when creating a new system:**
1. Add `class_name` declaration at top of new script
2. In EVERY file that uses the new system, add `const NewSystemClass = preload("res://path/to/new_system.gd")`
3. Use `NewSystemClass.method()` for all calls, never bare `NewSystem.method()`

### Autoload Registration (CRITICAL)
**MANDATORY**: When creating a new autoload manager, you MUST register it in `project.godot` under `[autoload]`.

**Registration Format:**
```
ManagerName="*res://autoload/manager_name.gd"
```

**Current autoloads** (add new ones after these):
- EventBus, GameConfig, TileTypeManager, CalendarManager, TurnManager
- GameManager, FeatureManager, HazardManager, TownManager, NPCManager
- MapManager, ChunkManager, BiomeManager, DungeonManager, EntityManager
- ItemManager, RecipeManager, StructureManager, SaveManager, VariantManager
- WeatherManager, LootTableManager, SpellManager, IdentificationManager, RitualManager
- SkillManager, CreatureTypeManager

### GDScript Runtime Loading Pattern
For scripts with complex dependency chains, use runtime `load()` instead of `preload()`:

```gdscript
const GENERATOR_PATH = "res://generation/my_generator.gd"
static func create():
    var script = load(GENERATOR_PATH)
    return script.new()
```

---

## File Structure

```
res://
├── autoload/           # Persistent managers
├── entities/           # Entity classes (entity.gd, player.gd, enemy.gd, npc.gd)
├── items/              # Item system (item.gd, item_factory.gd)
├── magic/              # Magic system (spell.gd)
├── systems/            # Game systems (combat, survival, inventory, harvest, fov, input)
├── maps/               # Map data structures (map.gd, tile_data.gd)
├── generation/         # Procedural generation (seeded_random, generators)
├── rendering/          # Rendering layer (render_interface, ascii_renderer)
├── ui/                 # User interface scenes
├── data/               # JSON data files (items, enemies, recipes, resources, etc.)
├── scenes/             # Scene files (main.tscn, game.tscn)
└── plans/              # Implementation plans
```

---

## Current Phase Status

**Current**: Phase 1.15 Complete (Save System)
**Next**: Phase 1.16 (UI Polish)

See `docs/reference/phase-history.md` for completed phase details.
See `docs/reference/magic-system-overview.md` for planned magic system.

---

## Domain-Specific Knowledge

For detailed system documentation, see these agent files:
- `.claude/agents/game-systems.md` - Combat, survival, inventory, turn loop
- `.claude/agents/map-generation.md` - Map system, procedural generation
- `.claude/agents/item-system.md` - Items, crafting, templates, variants
- `.claude/agents/rendering.md` - ASCII rendering, tileset handling

For common workflows, see these skill files:
- `.claude/skills/add-enemy/` - Adding new enemies
- `.claude/skills/add-item/` - Adding new items
- `.claude/skills/add-recipe/` - Adding new recipes
- `.claude/skills/debug-test/` - Debugging and testing

---

## Documentation Maintenance

### Update Rules

When modifying the codebase, update documentation accordingly:

1. **System Changes**: Update `docs/systems/{system}.md` when formulas, functions, or signals change
2. **Data Format Changes**: Update `docs/data/{type}.md` when JSON properties change
3. **New User Features**: Update `README.md`, `ui/help_screen.gd`, and `docs/systems/input-handler.md`

### Documentation Checklist

Before committing changes, verify:
- [ ] System docs updated if mechanics changed
- [ ] Data docs updated if JSON format changed
- [ ] README.md updated if new user feature
- [ ] help_screen.gd updated if new keybindings

---

**Last Updated**: January 18, 2026
**Current Branch**: `feature/reduce-context-usage`
**Next Phase**: 1.16 - UI Polish
