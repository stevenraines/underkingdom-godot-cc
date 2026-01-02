# Dungeon Manager

**Source File**: `autoload/dungeon_manager.gd`
**Type**: Autoload Singleton

## Overview

The Dungeon Manager handles loading dungeon definitions from JSON and provides dungeon data to procedural generators. Each dungeon type defines its map size, floor count, generation algorithm, enemy pools, loot tables, features, hazards, and difficulty curve. All dungeons are data-driven and defined in `data/dungeons/`.

## Key Concepts

- **Dungeon Definitions**: JSON files defining dungeon types
- **Floor Generation**: Creating individual dungeon floors procedurally
- **Enemy Pools**: Weighted enemy spawn lists per floor range
- **Features/Hazards**: Interactive objects and traps placed during generation
- **Difficulty Curve**: Scaling enemy count and loot quality by floor

## Core Functionality

### Loading Definitions

At startup, all JSON files in `data/dungeons/` are loaded into `dungeon_definitions` dictionary.

```gdscript
DungeonManager.dungeon_definitions: Dictionary  # {dungeon_id: definition}
```

### Getting Dungeon Data

```gdscript
# Get full dungeon definition
var def = DungeonManager.get_dungeon("burial_barrow")

# Get all available dungeon types
var types = DungeonManager.get_all_dungeon_types()  # ["burial_barrow", "sewers", ...]

# Get random dungeon type using seeded RNG
var random_type = DungeonManager.get_random_dungeon_type(rng)
```

### Floor Generation

```gdscript
# Generate a single dungeon floor
var map: GameMap = DungeonManager.generate_floor(dungeon_id, floor_number, world_seed)
```

This is the primary API for creating dungeon maps. It:
1. Gets dungeon definition
2. Determines generator type
3. Creates generator via factory
4. Generates map with seeded RNG
5. Processes pending features and hazards
6. Returns complete GameMap

### Floor Count

```gdscript
var floor_count = DungeonManager.get_floor_count("burial_barrow", rng)
# Returns random value between floor_count.min and floor_count.max
```

### Map Size

```gdscript
var size: Vector2i = DungeonManager.get_map_size("burial_barrow")
# Returns Vector2i(width, height)
```

## Dungeon Definition Structure

```json
{
  "id": "burial_barrow",
  "name": "Burial Barrow",
  "description": "An ancient tomb filled with restless undead",

  "map_size": {"width": 50, "height": 50},
  "floor_count": {"min": 10, "max": 20},

  "generator_type": "rectangular_rooms",
  "generation_params": {...},

  "tiles": {...},
  "lighting": {...},

  "enemy_pools": [...],
  "loot_tables": [...],
  "room_features": [...],
  "hazards": [...],

  "difficulty_curve": {...},
  "hints": [...]
}
```

## Generator Types

| Type | Algorithm | Characteristics |
|------|-----------|-----------------|
| `rectangular_rooms` | BSP + rectangular rooms | Structured rooms with corridors |
| `cellular_automata` | Cellular automata | Organic cave-like layouts |
| `prefab_rooms` | Pre-designed templates | Hand-crafted room shapes |

## Enemy Pool System

Enemies are spawned based on weighted pools filtered by floor range.

### Pool Entry
```json
{
  "enemy_id": "skeleton",
  "weight": 0.4,
  "floor_range": [1, 10],
  "max_per_floor": 5  // Optional limit
}
```

### Selection Process
1. Filter pools to current floor range
2. Normalize weights
3. Roll weighted random selection
4. Spawn enemy at valid position

## Difficulty Curve

Controls how difficulty scales with floor depth.

```json
"difficulty_curve": {
  "enemy_level_multiplier": 1.0,
  "enemy_count_base": 3,
  "enemy_count_per_floor": 0.5,
  "loot_quality_multiplier": 1.2
}
```

### Enemy Count Formula
```
Enemy Count = enemy_count_base + (floor_number × enemy_count_per_floor)
```

Floor 1: 3 + 0.5 = 3.5 ≈ 3-4 enemies
Floor 10: 3 + 5 = 8 enemies
Floor 20: 3 + 10 = 13 enemies

## Feature Processing

After map generation, pending features are converted to active features.

```gdscript
_process_pending_features(map: GameMap)
```

Features stored in `map.metadata.pending_features` are:
1. Given full definition reference
2. Assigned loot if applicable
3. Assigned summoned enemy if applicable
4. Added to `map.metadata.features`

## Hazard Processing

Similar to features, hazards are processed after generation.

```gdscript
_process_pending_hazards(map: GameMap)
```

Hazards stored in `map.metadata.pending_hazards` are:
1. Given full definition reference
2. Assigned damage value
3. Added to `map.metadata.hazards`

## Fallback Definition

If a dungeon type is not found, a safe fallback is returned:

```gdscript
{
  "id": "unknown",
  "generator_type": "rectangular_rooms",
  "map_size": {"width": 50, "height": 50},
  "floor_count": {"min": 5, "max": 10},
  // ... safe defaults
}
```

## Current Dungeon Types

| ID | Name | Floors | Generator | Notes |
|----|------|--------|-----------|-------|
| `burial_barrow` | Burial Barrow | 10-20 | rectangular_rooms | Undead-themed |
| `sewers` | Sewers | 5-10 | rectangular_rooms | Urban, rats |
| `natural_cave` | Natural Cave | 8-15 | cellular_automata | Organic layout |
| `abandoned_mine` | Abandoned Mine | 10-15 | rectangular_rooms | Mining themed |
| `ancient_fort` | Ancient Fort | 5-10 | rectangular_rooms | Military |
| `temple_ruins` | Temple Ruins | 8-12 | prefab_rooms | Religious |
| `wizard_tower` | Wizard Tower | 5-8 | rectangular_rooms | Magical |
| `military_compound` | Military Compound | 6-10 | rectangular_rooms | Modern military |

## Integration with Other Systems

- **MapManager**: Calls `generate_floor()` during map transitions
- **FeatureManager**: Receives processed features
- **HazardManager**: Receives processed hazards
- **EntityManager**: Uses enemy pools for spawning
- **LootTableManager**: Referenced by loot_tables

## Data Dependencies

- **Dungeons** (`data/dungeons/`): Dungeon definitions
- **Enemies** (`data/enemies/`): Valid enemy IDs for pools
- **Features** (`data/features/`): Valid feature IDs
- **Hazards** (`data/hazards/`): Valid hazard IDs
- **Loot Tables** (`data/loot_tables/`): Loot generation

## Related Documentation

- [Dungeons Data](../data/dungeons.md) - Dungeon file format
- [Feature Manager](./feature-manager.md) - Feature handling
- [Hazard Manager](./hazard-manager.md) - Hazard handling
- [Enemies Data](../data/enemies.md) - Enemy definitions
