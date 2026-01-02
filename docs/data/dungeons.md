# Dungeons Data Format

**Location**: `data/dungeons/`
**File Count**: 8 files
**Loaded By**: DungeonManager

## Overview

Dungeon definitions specify procedurally generated underground areas including map size, enemy pools, loot tables, features, hazards, and difficulty scaling. Each JSON file defines a complete dungeon type with all its generation parameters.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique identifier (snake_case) | DungeonManager |
| `name` | string | Display name | UI, messages |
| `floor_count` | object | Min/max floors | DungeonManager |
| `generator_type` | string | Generation algorithm | DungeonGeneratorFactory |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `description` | string | "" | Flavor text | UI |
| `entrance_char` | string | ">" | Entrance display character | Renderer |
| `entrance_color` | string | "#FFFFFF" | Entrance hex color | Renderer |
| `biome_preferences` | array | [] | Preferred spawn biomes | WorldGenerator |
| `placement` | string | "wilderness" | Where entrances spawn | WorldGenerator |
| `map_size` | object | 50×50 | Width/height in tiles | Generator |
| `generation_params` | object | {} | Algorithm parameters | Generator |
| `tiles` | object | {} | Tile type mappings | Generator |
| `lighting` | object | {} | Visibility settings | FOVSystem |
| `enemy_pools` | array | [] | Enemy spawn definitions | EntityManager |
| `loot_tables` | array | [] | Floor loot configuration | LootTableManager |
| `room_features` | array | [] | Feature spawn rules | FeatureManager |
| `hazards` | array | [] | Hazard spawn rules | HazardManager |
| `special_rooms` | array | [] | Special room definitions | Generator |
| `difficulty_curve` | object | {} | Scaling parameters | DungeonManager |
| `hints` | array | [] | Inscription messages | FeatureManager |

## Property Details

### `floor_count`
**Type**: object
**Required**: Yes

Defines the number of floors in the dungeon.

```json
"floor_count": {
  "min": 10,
  "max": 20
}
```

Actual floor count is randomly selected within range at dungeon creation.

### `map_size`
**Type**: object
**Default**: 50×50

Dimensions of each floor in tiles.

```json
"map_size": {
  "width": 50,
  "height": 50
}
```

### `generator_type`
**Type**: string
**Required**: Yes

Algorithm used for floor generation.

| Generator | Description |
|-----------|-------------|
| `rectangular_rooms` | Standard rooms connected by corridors |
| `cellular_automata` | Organic cave-like structures |
| `bsp` | Binary space partition rooms |

### `generation_params`
**Type**: object
**Varies by generator_type**

Parameters for the generation algorithm.

**For `rectangular_rooms`:**
```json
"generation_params": {
  "room_count_range": [5, 8],
  "room_size_range": [3, 8],
  "corridor_width": 1,
  "connectivity": 0.7
}
```

| Parameter | Description |
|-----------|-------------|
| `room_count_range` | [min, max] rooms to generate |
| `room_size_range` | [min, max] room dimensions |
| `corridor_width` | Corridor tile width |
| `connectivity` | 0.0-1.0 extra corridor probability |

### `tiles`
**Type**: object

Tile type mappings for generation.

```json
"tiles": {
  "wall": "wall",
  "floor": "floor",
  "door": "door"
}
```

### `lighting`
**Type**: object

Visibility and lighting parameters.

```json
"lighting": {
  "base_visibility": 0.3,
  "torch_radius": 5
}
```

| Property | Description |
|----------|-------------|
| `base_visibility` | Ambient light level (0.0-1.0) |
| `torch_radius` | Torch light distance in tiles |

### `enemy_pools`
**Type**: array

Defines which enemies spawn on which floors.

```json
"enemy_pools": [
  {
    "enemy_id": "skeleton",
    "weight": 0.4,
    "floor_range": [1, 10]
  },
  {
    "enemy_id": "barrow_lord",
    "weight": 1.0,
    "floor_range": [20, 20],
    "max_per_floor": 1
  }
]
```

| Property | Type | Description |
|----------|------|-------------|
| `enemy_id` | string | Enemy definition ID |
| `weight` | float | Spawn probability weight |
| `floor_range` | [min, max] | Valid floor range |
| `max_per_floor` | int | Optional spawn limit |

### `loot_tables`
**Type**: array

Floor-level loot generation rules.

```json
"loot_tables": [
  {
    "item_id": "ancient_gold",
    "chance": 0.3,
    "count_range": [10, 50]
  }
]
```

### `room_features`
**Type**: array

Interactive feature placement rules.

```json
"room_features": [
  {
    "feature_id": "sarcophagus",
    "spawn_chance": 0.3,
    "room_types": ["large", "end"],
    "contains_loot": true,
    "summons_enemy": "skeleton"
  },
  {
    "feature_id": "treasure_chest",
    "spawn_chance": 0.15,
    "room_types": ["end"],
    "loot_table": "ancient_treasure"
  }
]
```

| Property | Type | Description |
|----------|------|-------------|
| `feature_id` | string | Feature definition ID |
| `spawn_chance` | float | Probability (0.0-1.0) |
| `room_types` | array | Valid room types |
| `contains_loot` | bool | Has loot inside |
| `loot_table` | string | Loot table ID for contents |
| `summons_enemy` | string | Enemy spawned on interaction |

**Room Types**: `any`, `small`, `large`, `end`, `corridor`

### `hazards`
**Type**: array

Hazard placement rules.

```json
"hazards": [
  {
    "hazard_id": "floor_trap",
    "density": 0.01,
    "damage": 10,
    "detection_difficulty": 15
  },
  {
    "hazard_id": "curse_zone",
    "density": 0.005,
    "effect": "stat_drain",
    "duration": 100
  }
]
```

| Property | Type | Description |
|----------|------|-------------|
| `hazard_id` | string | Hazard definition ID |
| `density` | float | Hazards per floor tile |
| `damage` | int | Override base damage |
| `detection_difficulty` | int | Override detection DC |
| `effect` | string | Status effect applied |
| `duration` | int | Effect duration in turns |

### `special_rooms`
**Type**: array

Special room generation.

```json
"special_rooms": [
  {
    "room_type": "crypt",
    "chance": 0.2,
    "contains": "boss_enemy",
    "loot_multiplier": 2.0
  }
]
```

### `difficulty_curve`
**Type**: object

Scaling parameters per floor.

```json
"difficulty_curve": {
  "enemy_level_multiplier": 1.0,
  "enemy_count_base": 3,
  "enemy_count_per_floor": 0.5,
  "loot_quality_multiplier": 1.2
}
```

| Property | Description |
|----------|-------------|
| `enemy_level_multiplier` | Base enemy scaling |
| `enemy_count_base` | Minimum enemies per floor |
| `enemy_count_per_floor` | Additional enemies per depth |
| `loot_quality_multiplier` | Better loot per floor |

### `hints`
**Type**: array

Messages displayed by tomb inscriptions.

```json
"hints": [
  "Beware the darkness below...",
  "The treasure lies beyond the guardian.",
  "Only the worthy may pass."
]
```

## Complete Example

```json
{
  "id": "burial_barrow",
  "name": "Burial Barrow",
  "description": "An ancient tomb filled with restless undead",
  "entrance_char": ">",
  "entrance_color": "#AA88FF",
  "biome_preferences": ["grassland", "woodland", "forest"],
  "placement": "wilderness",

  "map_size": {
    "width": 50,
    "height": 50
  },
  "floor_count": {
    "min": 10,
    "max": 20
  },

  "generator_type": "rectangular_rooms",
  "generation_params": {
    "room_count_range": [5, 8],
    "room_size_range": [3, 8],
    "corridor_width": 1,
    "connectivity": 0.7
  },

  "tiles": {
    "wall": "wall",
    "floor": "floor",
    "door": "door"
  },
  "lighting": {
    "base_visibility": 0.3,
    "torch_radius": 5
  },

  "enemy_pools": [
    {
      "enemy_id": "rat",
      "weight": 0.6,
      "floor_range": [1, 5]
    },
    {
      "enemy_id": "skeleton",
      "weight": 0.4,
      "floor_range": [1, 10]
    },
    {
      "enemy_id": "barrow_wight",
      "weight": 0.2,
      "floor_range": [10, 20]
    },
    {
      "enemy_id": "barrow_lord",
      "weight": 1.0,
      "floor_range": [20, 20],
      "max_per_floor": 1
    }
  ],

  "room_features": [
    {
      "feature_id": "sarcophagus",
      "spawn_chance": 0.3,
      "room_types": ["large", "end"],
      "contains_loot": true,
      "summons_enemy": "skeleton"
    },
    {
      "feature_id": "treasure_chest",
      "spawn_chance": 0.15,
      "room_types": ["end"],
      "loot_table": "ancient_treasure"
    },
    {
      "feature_id": "tomb_inscription",
      "spawn_chance": 0.2,
      "room_types": ["any"],
      "provides_hint": true
    }
  ],

  "hazards": [
    {
      "hazard_id": "floor_trap",
      "density": 0.01,
      "damage": 10,
      "detection_difficulty": 15
    },
    {
      "hazard_id": "curse_zone",
      "density": 0.005,
      "effect": "stat_drain",
      "duration": 100
    }
  ],

  "difficulty_curve": {
    "enemy_level_multiplier": 1.0,
    "enemy_count_base": 3,
    "enemy_count_per_floor": 0.5,
    "loot_quality_multiplier": 1.2
  },

  "hints": [
    "Beware the darkness below...",
    "The treasure lies beyond the guardian.",
    "Death awaits the unprepared."
  ]
}
```

## Current Dungeon Types

| ID | Name | Floors | Theme |
|----|------|--------|-------|
| `burial_barrow` | Burial Barrow | 10-20 | Undead, ancient tombs |
| `natural_cave` | Natural Cave | 5-15 | Beasts, natural hazards |
| `abandoned_mine` | Abandoned Mine | 8-12 | Cave-ins, ores |
| `ancient_fort` | Ancient Fort | 6-10 | Soldiers, defenses |
| `military_compound` | Military Compound | 4-8 | Guards, weapons |
| `temple_ruins` | Temple Ruins | 10-15 | Divine hazards, relics |
| `wizard_tower` | Wizard Tower | 5-10 | Magical hazards, constructs |
| `sewers` | Sewers | 3-6 | Rats, disease |

## Validation Rules

1. `id` must be unique across all dungeons
2. `floor_count.min` must be ≤ `floor_count.max`
3. `enemy_id` values must match enemies in EntityManager
4. `feature_id` values must match features in FeatureManager
5. `hazard_id` values must match hazards in HazardManager
6. `loot_table` values must match tables in LootTableManager
7. `density` should be 0.0-0.1 (higher creates many hazards)
8. `spawn_chance` must be 0.0-1.0

## Related Documentation

- [Dungeon Manager](../systems/dungeon-manager.md) - Dungeon generation system
- [Enemies Data](./enemies.md) - Enemy definitions
- [Features Data](./features.md) - Feature definitions
- [Hazards Data](./hazards.md) - Hazard definitions
- [Loot Tables Data](./loot-tables.md) - Loot table definitions
