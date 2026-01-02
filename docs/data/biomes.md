# Biomes Data Format

**Location**: `data/biomes/`
**File Count**: 15 files
**Loaded By**: BiomeManager

## Overview

Biome definitions specify the visual appearance and terrain generation properties for each world region type. Biomes are selected based on elevation and moisture values during chunk generation. Each biome controls tile appearance, vegetation density, and color.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique identifier (snake_case) | BiomeManager |
| `name` | string | Display name | UI, debug |
| `base_tile` | string | Primary tile type | WorldChunk |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `grass_char` | string | "." | Grass/ground character | Renderer |
| `tree_density` | float | 0.0 | Tree spawn probability (0.0-1.0) | WorldChunk |
| `rock_density` | float | 0.0 | Rock spawn probability (0.0-1.0) | WorldChunk |
| `color_floor` | array | [1,1,1] | RGB floor color (0.0-1.0) | Renderer |
| `color_grass` | array | [1,1,1] | RGB grass color (0.0-1.0) | Renderer |

## Property Details

### `base_tile`
**Type**: string
**Required**: Yes

The primary tile type for walkable areas in this biome.

| Value | Description |
|-------|-------------|
| `floor` | Standard walkable ground |
| `water` | Impassable water |
| `wall` | Impassable rock/mountains |

### `grass_char`
**Type**: string
**Default**: "."

ASCII character for grass/ground decoration.

| Char | Typical Use |
|------|-------------|
| `"` | Tall grass |
| `,` | Short grass |
| `.` | Sparse grass |
| `~` | Water/waves |
| `*` | Snow/ice |

### `tree_density`
**Type**: float (0.0-1.0)
**Default**: 0.0

Probability of spawning a tree on each walkable tile.

| Value | Description | Trees per 100 tiles |
|-------|-------------|---------------------|
| 0.0 | None | 0 |
| 0.05 | Sparse | 5 |
| 0.15 | Light | 15 |
| 0.30 | Medium | 30 |
| 0.50 | Dense | 50 |

### `rock_density`
**Type**: float (0.0-1.0)
**Default**: 0.0

Probability of spawning a rock on each walkable tile.

### `color_floor` / `color_grass`
**Type**: array of 3 floats
**Default**: [1.0, 1.0, 1.0]

RGB color values in 0.0-1.0 range.

```json
"color_floor": [0.25, 0.35, 0.2]  // Dark green
```

## Biome Categories

### Water Biomes

| ID | Name | Base Tile | Description |
|----|------|-----------|-------------|
| `deep_ocean` | Deep Ocean | water | Far from shore |
| `ocean` | Ocean | water | Standard ocean |

### Coastal Biomes

| ID | Name | Tree Density | Description |
|----|------|--------------|-------------|
| `beach` | Beach | 0.0 | Sandy shores |
| `marsh` | Marsh | 0.1 | Wet grassland |
| `swamp` | Swamp | 0.2 | Dense wetland |

### Lowland Biomes

| ID | Name | Tree Density | Description |
|----|------|--------------|-------------|
| `grassland` | Grassland | 0.05 | Open plains |
| `woodland` | Woodland | 0.15 | Light forest |
| `forest` | Forest | 0.3 | Medium forest |
| `rainforest` | Rainforest | 0.5 | Dense jungle |

### Highland Biomes

| ID | Name | Tree Density | Description |
|----|------|--------------|-------------|
| `tundra` | Tundra | 0.02 | Cold flatland |
| `rocky_hills` | Rocky Hills | 0.02 | Rocky terrain |
| `barren_rock` | Barren Rock | 0.0 | Exposed stone |
| `mountains` | Mountains | 0.0 | Impassable peaks |

### Cold Biomes

| ID | Name | Base Tile | Description |
|----|------|-----------|-------------|
| `snow` | Snow | floor | Snowy ground |
| `snow_mountains` | Snow Mountains | wall | Frozen peaks |

## Complete Examples

### Walkable Biome

```json
{
  "id": "grassland",
  "name": "Grassland",
  "base_tile": "floor",
  "grass_char": "\"",
  "tree_density": 0.05,
  "rock_density": 0.01,
  "color_floor": [0.25, 0.35, 0.2],
  "color_grass": [0.3, 0.4, 0.25]
}
```

### Dense Vegetation

```json
{
  "id": "forest",
  "name": "Forest",
  "base_tile": "floor",
  "grass_char": ",",
  "tree_density": 0.3,
  "rock_density": 0.02,
  "color_floor": [0.15, 0.3, 0.15],
  "color_grass": [0.2, 0.35, 0.2]
}
```

### Water Biome

```json
{
  "id": "ocean",
  "name": "Ocean",
  "base_tile": "water",
  "grass_char": "~",
  "tree_density": 0.0,
  "rock_density": 0.0,
  "color_floor": [0.2, 0.3, 0.6],
  "color_grass": [0.25, 0.35, 0.65]
}
```

### Impassable Biome

```json
{
  "id": "mountains",
  "name": "Mountains",
  "base_tile": "wall",
  "grass_char": "^",
  "tree_density": 0.0,
  "rock_density": 0.0,
  "color_floor": [0.5, 0.5, 0.5],
  "color_grass": [0.6, 0.6, 0.6]
}
```

## Biome Selection

Biomes are selected via the biome matrix in `world_generation_config.json`:

```json
"biome_matrix": {
  "elevation_thresholds": [0.05, 0.25, 0.45, 0.62, 0.80],
  "moisture_thresholds": [0.2, 0.4, 0.6, 0.8],
  "matrix": [
    ["deep_ocean", "deep_ocean", "ocean", "ocean", "ocean"],
    ["ocean", "beach", "marsh", "swamp", "swamp"],
    ["beach", "grassland", "grassland", "forest", "rainforest"],
    ["barren_rock", "tundra", "grassland", "woodland", "forest"],
    ["barren_rock", "rocky_hills", "rocky_hills", "mountains", "mountains"],
    ["barren_rock", "snow", "snow", "snow_mountains", "snow_mountains"]
  ]
}
```

Matrix rows correspond to elevation (low → high).
Matrix columns correspond to moisture (dry → wet).

## Color Guidelines

### Green Tones (Vegetation)

| R | G | B | Description |
|---|---|---|-------------|
| 0.15-0.25 | 0.30-0.40 | 0.15-0.25 | Forest greens |
| 0.25-0.35 | 0.35-0.45 | 0.20-0.30 | Grassland |
| 0.20-0.30 | 0.35-0.45 | 0.25-0.35 | Marsh/swamp |

### Blue Tones (Water)

| R | G | B | Description |
|---|---|---|-------------|
| 0.15-0.25 | 0.25-0.35 | 0.55-0.65 | Deep water |
| 0.20-0.30 | 0.30-0.40 | 0.60-0.70 | Shallow water |

### Brown/Gray Tones (Rock)

| R | G | B | Description |
|---|---|---|-------------|
| 0.40-0.50 | 0.40-0.50 | 0.40-0.50 | Gray rock |
| 0.45-0.55 | 0.40-0.50 | 0.35-0.45 | Brown rock |

## Validation Rules

1. `id` must be unique across all biomes
2. `id` should use snake_case format
3. `base_tile` must be: floor, water, or wall
4. `grass_char` must be single character
5. `tree_density` must be 0.0-1.0
6. `rock_density` must be 0.0-1.0
7. Color values must be 0.0-1.0

## Related Documentation

- [Biome Manager](../systems/biome-manager.md) - Biome lookup system
- [World Generation](./world-generation.md) - Generation config
- [Chunk Manager](../systems/chunk-manager.md) - Terrain streaming
