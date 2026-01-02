# Configuration Data Format

**Location**: `data/`
**Loaded By**: Various systems

## Overview

Configuration files control global game settings including world generation parameters, game balance constants, and system-wide defaults. These are separate from content definitions (items, enemies) and control how systems behave.

## World Generation Config

**File**: `data/world_generation_config.json`
**Loaded By**: WorldGenerator, ChunkManager

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `chunk_size` | int | 32 | Tiles per chunk side |
| `active_radius` | int | 1 | Chunks loaded around player |
| `cache_size` | int | 50 | LRU cache capacity |
| `elevation_scale` | float | 0.02 | Noise frequency for elevation |
| `moisture_scale` | float | 0.015 | Noise frequency for moisture |
| `island_mode` | bool | true | Enable island generation |
| `island_radius` | float | 0.8 | Island size (0-1) |
| `island_falloff` | float | 3.0 | Edge sharpness |

### Example

```json
{
    "chunk_size": 32,
    "active_radius": 1,
    "cache_size": 50,
    "elevation_scale": 0.02,
    "moisture_scale": 0.015,
    "island_mode": true,
    "island_radius": 0.8,
    "island_falloff": 3.0
}
```

### Noise Parameters

| Parameter | Effect |
|-----------|--------|
| Lower `elevation_scale` | Larger terrain features |
| Higher `elevation_scale` | More varied terrain |
| Lower `moisture_scale` | Larger biome regions |
| Higher `moisture_scale` | More biome variety |

### Island Mode

When `island_mode: true`:
- Distance from center reduces elevation
- Creates natural ocean boundaries
- `island_radius` controls land percentage
- `island_falloff` controls transition sharpness

## Game Constants

Various hardcoded constants that could become configurable:

### Turn System

| Constant | Value | Location |
|----------|-------|----------|
| TURNS_PER_DAY | 100 | turn_manager.gd |
| DAWN_START | 0 | turn_manager.gd |
| DAWN_END | 15 | turn_manager.gd |
| DAY_END | 70 | turn_manager.gd |
| DUSK_END | 85 | turn_manager.gd |

### Survival Rates

| Constant | Value | Location |
|----------|-------|----------|
| HUNGER_DRAIN_TURNS | 20 | survival_system.gd |
| THIRST_DRAIN_TURNS | 15 | survival_system.gd |
| STAMINA_REGEN_RATE | 1 | survival_system.gd |

### Combat

| Constant | Value | Location |
|----------|-------|----------|
| BASE_HIT_CHANCE | 70% | combat_system.gd |
| RANGE_PENALTY_PER_TILE | 5% | ranged_combat_system.gd |
| HALF_RANGE_THRESHOLD | 0.5 | ranged_combat_system.gd |

### Movement

| Constant | Value | Location |
|----------|-------|----------|
| MOVE_DELAY | 0.12s | input_handler.gd |
| INITIAL_DELAY | 0.2s | input_handler.gd |

### Perception

| Constant | Value | Location |
|----------|-------|----------|
| BASE_PERCEPTION | 5 | entity.gd |
| WIS_PERCEPTION_BONUS | WIS/2 | entity.gd |

## Biome Matrix

**Concept**: 2D lookup table mapping elevation × moisture to biome IDs

### Default Matrix (5×5)

```
Moisture →  Very Dry   Dry      Normal    Wet      Very Wet
Elev ↓
Very Low    ocean     ocean    ocean     ocean    ocean
Low         beach     beach    swamp     swamp    swamp
Normal      desert    grass    grass     forest   forest
High        desert    grass    forest    forest   rainforest
Very High   mountain  mountain mountain  mountain mountain
```

### Matrix Indices

| Elevation | Index |
|-----------|-------|
| < 0.2 | 0 (Very Low) |
| < 0.4 | 1 (Low) |
| < 0.6 | 2 (Normal) |
| < 0.8 | 3 (High) |
| >= 0.8 | 4 (Very High) |

| Moisture | Index |
|----------|-------|
| < 0.2 | 0 (Very Dry) |
| < 0.4 | 1 (Dry) |
| < 0.6 | 2 (Normal) |
| < 0.8 | 3 (Wet) |
| >= 0.8 | 4 (Very Wet) |

## FOV Configuration

| Setting | Value | Effect |
|---------|-------|--------|
| Night multiplier | 0.5 | 50% range at night |
| Dawn/Dusk multiplier | 0.75 | 75% range at twilight |
| Day multiplier | 1.0 | Full range |

## Encumbrance Thresholds

| Threshold | Effect |
|-----------|--------|
| 0-75% | No penalty |
| 75-100% | +50% stamina costs |
| 100-125% | 2 turns per move, +100% stamina |
| 125%+ | Cannot move |

## Save System

| Setting | Value |
|---------|-------|
| Max save slots | 3 |
| Save file extension | .json |
| Save directory | user://saves/ |

## Future Configuration Files

Planned additional config files:

### `data/balance_config.json`
```json
{
    "combat": {
        "base_hit_chance": 0.7,
        "range_penalty_per_tile": 0.05
    },
    "survival": {
        "hunger_drain_turns": 20,
        "thirst_drain_turns": 15
    }
}
```

### `data/ui_config.json`
```json
{
    "message_log_max": 100,
    "tooltip_delay": 0.5,
    "animation_speed": 1.0
}
```

## Related Documentation

- [World Generation Data](./world-generation.md) - Noise parameters
- [Biomes Data](./biomes.md) - Biome definitions
- [Turn Manager](../systems/turn-manager.md) - Day/night cycle
- [Survival System](../systems/survival-system.md) - Drain rates
