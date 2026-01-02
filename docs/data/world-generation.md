# World Generation Configuration

**Location**: `data/world_generation_config.json`
**File Count**: 1 file
**Loaded By**: BiomeManager

## Overview

The world generation configuration file controls all aspects of procedural world generation including noise parameters, biome selection, chunk settings, and island boundaries. This data-driven approach allows tuning world generation without code changes.

## JSON Structure

```json
{
  "elevation_noise": {...},
  "moisture_noise": {...},
  "coastline_noise": {...},
  "chunk_settings": {...},
  "island_settings": {...},
  "biome_matrix": {...},
  "special_features": {...}
}
```

## Noise Configuration

### Elevation Noise

Controls terrain height variation.

```json
"elevation_noise": {
  "frequency": 0.03,
  "octaves": 3,
  "lacunarity": 2.0,
  "gain": 0.5,
  "elevation_curve": 1.5
}
```

| Property | Type | Description |
|----------|------|-------------|
| `frequency` | float | Base noise frequency (lower = larger features) |
| `octaves` | int | Number of noise layers (more = more detail) |
| `lacunarity` | float | Frequency multiplier per octave |
| `gain` | float | Amplitude multiplier per octave |
| `elevation_curve` | float | Power curve for distribution |

**Frequency Guidelines**:
- 0.01-0.02: Very large continents
- 0.03-0.05: Medium landmasses
- 0.06-0.10: Small islands

### Moisture Noise

Controls vegetation and water distribution.

```json
"moisture_noise": {
  "frequency": 0.05,
  "octaves": 2,
  "lacunarity": 2.0,
  "gain": 0.5,
  "seed_offset": 1000
}
```

| Property | Type | Description |
|----------|------|-------------|
| `seed_offset` | int | Added to world seed for different pattern |

### Coastline Noise

Creates irregular coastlines.

```json
"coastline_noise": {
  "frequency": 0.002,
  "octaves": 3,
  "lacunarity": 2.0,
  "gain": 0.4,
  "seed_offset": 5000
}
```

Lower frequency creates larger-scale coastline variation.

## Chunk Settings

```json
"chunk_settings": {
  "chunk_size": 32,
  "load_radius": 3,
  "unload_radius": 5,
  "cache_max_size": 100
}
```

| Property | Type | Description |
|----------|------|-------------|
| `chunk_size` | int | Tiles per chunk dimension |
| `load_radius` | int | Chunk distance to load around player |
| `unload_radius` | int | Chunk distance to unload |
| `cache_max_size` | int | Maximum chunks in memory |

**Memory Calculation**:
```
Tiles in cache = cache_max_size × chunk_size²
                = 100 × 32 × 32 = 102,400 tiles
```

## Island Settings

```json
"island_settings": {
  "width_chunks": 25,
  "height_chunks": 25,
  "land_threshold": -0.1,
  "distance_weight": 1.5,
  "distance_exponent": 4.0,
  "coastline_amplitude": 0.3
}
```

| Property | Type | Description |
|----------|------|-------------|
| `width_chunks` | int | Island width in chunks |
| `height_chunks` | int | Island height in chunks |
| `land_threshold` | float | Elevation cutoff for land |
| `distance_weight` | float | Edge falloff strength |
| `distance_exponent` | float | Edge falloff curve steepness |
| `coastline_amplitude` | float | Coastline noise strength |

**World Size**:
```
Width = width_chunks × chunk_size = 25 × 32 = 800 tiles
Height = height_chunks × chunk_size = 25 × 32 = 800 tiles
```

### Edge Falloff

The island is surrounded by ocean using distance-based falloff:

```
distance = max(abs(x - center_x), abs(y - center_y)) / max_distance
falloff = distance^distance_exponent × distance_weight
elevation = noise_value - falloff + coastline_noise
```

## Biome Matrix

Maps elevation × moisture to biome IDs.

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

### Threshold Interpretation

**Elevation Rows** (low → high):
- Row 0: elevation < 0.05 (deep water)
- Row 1: 0.05 ≤ elevation < 0.25 (shallow water/coast)
- Row 2: 0.25 ≤ elevation < 0.45 (lowlands)
- Row 3: 0.45 ≤ elevation < 0.62 (midlands)
- Row 4: 0.62 ≤ elevation < 0.80 (highlands)
- Row 5: elevation ≥ 0.80 (peaks)

**Moisture Columns** (dry → wet):
- Col 0: moisture < 0.2 (arid)
- Col 1: 0.2 ≤ moisture < 0.4 (dry)
- Col 2: 0.4 ≤ moisture < 0.6 (moderate)
- Col 3: 0.6 ≤ moisture < 0.8 (wet)
- Col 4: moisture ≥ 0.8 (saturated)

## Special Features

```json
"special_features": {
  "dungeon_entrance": {
    "preferred_biomes": ["rocky_hills", "mountains", "barren_rock"],
    "min_distance_from_spawn": 2,
    "max_distance_from_spawn": 10,
    "tile_type": "stairs_down"
  },
  "town": {
    "preferred_biomes": ["grassland", "woodland", "forest"],
    "min_distance_from_dungeon": 3,
    "size": 20
  }
}
```

### Dungeon Entrance

| Property | Description |
|----------|-------------|
| `preferred_biomes` | Valid biomes for placement |
| `min_distance_from_spawn` | Minimum chunks from player spawn |
| `max_distance_from_spawn` | Maximum chunks from player spawn |
| `tile_type` | Tile type for entrance |

### Town

| Property | Description |
|----------|-------------|
| `preferred_biomes` | Valid biomes for placement |
| `min_distance_from_dungeon` | Buffer from dungeons |
| `size` | Town area in tiles |

## Complete Example

```json
{
  "elevation_noise": {
    "frequency": 0.03,
    "octaves": 3,
    "lacunarity": 2.0,
    "gain": 0.5,
    "elevation_curve": 1.5
  },
  "moisture_noise": {
    "frequency": 0.05,
    "octaves": 2,
    "lacunarity": 2.0,
    "gain": 0.5,
    "seed_offset": 1000
  },
  "coastline_noise": {
    "frequency": 0.002,
    "octaves": 3,
    "lacunarity": 2.0,
    "gain": 0.4,
    "seed_offset": 5000
  },
  "chunk_settings": {
    "chunk_size": 32,
    "load_radius": 3,
    "unload_radius": 5,
    "cache_max_size": 100
  },
  "island_settings": {
    "width_chunks": 25,
    "height_chunks": 25,
    "land_threshold": -0.1,
    "distance_weight": 1.5,
    "distance_exponent": 4.0,
    "coastline_amplitude": 0.3
  },
  "biome_matrix": {
    "elevation_thresholds": [0.05, 0.25, 0.45, 0.62, 0.80],
    "moisture_thresholds": [0.2, 0.4, 0.6, 0.8],
    "matrix": [...]
  },
  "special_features": {
    "dungeon_entrance": {...},
    "town": {...}
  }
}
```

## Tuning Guidelines

### Larger World

```json
"island_settings": {
  "width_chunks": 50,
  "height_chunks": 50
}
```

### More Ocean

```json
"island_settings": {
  "land_threshold": 0.1,
  "distance_weight": 2.0
}
```

### Rougher Coastline

```json
"coastline_noise": {
  "coastline_amplitude": 0.5
}
```

### More Biome Variety

Add more thresholds and matrix rows/columns.

## Validation Rules

1. Threshold arrays must be sorted ascending
2. Matrix rows must match elevation_thresholds.length + 1
3. Matrix columns must match moisture_thresholds.length + 1
4. All biome IDs in matrix must exist in biome definitions
5. Noise frequency should be > 0
6. Chunk size should be power of 2 (16, 32, 64)

## Related Documentation

- [Biome Manager](../systems/biome-manager.md) - Configuration loading
- [Biomes Data](./biomes.md) - Biome definitions
- [Chunk Manager](../systems/chunk-manager.md) - Chunk streaming
