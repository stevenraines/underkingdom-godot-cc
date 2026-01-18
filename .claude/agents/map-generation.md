# Map Generation Domain Knowledge

Use this agent when implementing or modifying map generation, procedural generation, or world/dungeon systems.

---

## Map System

### Map Class
Holds tiles (TileData), entities, metadata:
- `map_id` (string): "overworld" or "dungeon_barrow_floor_N"
- `tiles` (2D array): TileData objects with walkable/transparent/ascii_char
- `entities` (array): Entities on this map

### MapManager
- Caches generated maps (same seed = same map)
- Handles transitions (stairs, dungeon entrances)
- Current map always accessible via `MapManager.current_map`

### TileData Properties
- `tile_type`: "floor", "wall", "tree", "water", "stairs_down", etc.
- `walkable`: Can entities move through?
- `transparent`: Does it block line of sight?
- `ascii_char`: Display character (e.g., ".", "░", ">")

---

## Procedural Generation (Seeded)

### World Seed
Generated at new game, stored in save, deterministic regeneration:
- Overworld: 100×100 temperate woodland biome (trees, water, grass)
- Dungeons: 50×50 burial barrow floors (1-50 depth), rectangular rooms + corridors
- Floor seed: `hash(world_seed + dungeon_id + floor_number)`

### Generators
- `WorldGenerator.generate_overworld(seed)` - Returns Map
- `BurialBarrowGenerator.generate_floor(world_seed, floor_number)` - Returns Map

### Wall Culling
Dungeons use flood-fill algorithm to remove inaccessible wall tiles for cleaner visuals

---

## SeededRandom Usage

For deterministic generation, always use `SeededRandom`:

```gdscript
var rng = SeededRandom.new(seed_value)
var random_int = rng.randi_range(0, 10)
var random_float = rng.randf_range(0.0, 1.0)
```

---

## Creating a New Map Generator

1. Implement generator in `generation/` (extend Map class)
2. Register in MapManager's `get_or_generate_map()`
3. Use `SeededRandom` for deterministic generation
4. Ensure same seed always produces identical map

---

## GDScript Runtime Loading Pattern

For scripts with complex dependency chains (e.g., scripts extending other custom classes), use runtime `load()` instead of `preload()` to avoid parse-time circular dependency issues:

```gdscript
# For complex inheritance chains - use runtime load()
const GENERATOR_PATH = "res://generation/my_generator.gd"
static func create():
    var script = load(GENERATOR_PATH)
    return script.new()
```

This pattern is used in `DungeonGeneratorFactory` and `BurialBarrowGenerator` for loading dungeon generators.

---

## Key Files

- `maps/map.gd` - Map data structure
- `maps/tile_data.gd` - Tile properties
- `autoload/map_manager.gd` - Map caching and transitions
- `autoload/chunk_manager.gd` - Chunk streaming
- `autoload/biome_manager.gd` - Biome lookup
- `autoload/dungeon_manager.gd` - Dungeon generation
- `generation/seeded_random.gd` - Deterministic RNG
- `generation/world_generator.gd` - Overworld generation
- `generation/town_generator.gd` - Town generation
- `generation/dungeon_generators/burial_barrow.gd` - Dungeon generation
- `data/dungeons/` - Dungeon type definitions
- `data/biomes/` - Biome definitions
