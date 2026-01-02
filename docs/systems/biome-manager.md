# Biome Manager

**Source File**: `autoload/biome_manager.gd`
**Type**: Autoload Singleton

## Overview

The Biome Manager loads and manages biome definitions from JSON files. It provides biome lookup based on elevation and moisture values using a configurable biome matrix. This system enables data-driven world generation with different terrain types.

## Key Concepts

- **Biome Definitions**: JSON files defining biome properties
- **Biome Matrix**: 2D lookup table for elevation/moisture → biome
- **Noise Configuration**: Parameters for procedural generation
- **Island Settings**: World boundary configuration

## Data Locations

| Data Type | Path |
|-----------|------|
| Biome Definitions | `data/biomes/*.json` |
| Generation Config | `data/world_generation_config.json` |

## Core Properties

```gdscript
var biome_definitions: Dictionary = {}   # id -> biome data
var generation_config: Dictionary = {}   # World gen parameters
```

## Core Functionality

### Get Biome Definition

```gdscript
var biome = BiomeManager.get_biome("forest")
# Returns biome dictionary with all properties
```

Falls back to grassland if biome not found.

### Get Biome from Values

```gdscript
var biome_id = BiomeManager.get_biome_id_from_values(elevation, moisture)
# Returns biome ID string based on biome matrix
```

### Configuration Getters

```gdscript
var elev = BiomeManager.get_elevation_noise_config()
var moist = BiomeManager.get_moisture_noise_config()
var coast = BiomeManager.get_coastline_noise_config()
var chunks = BiomeManager.get_chunk_settings()
var island = BiomeManager.get_island_settings()
```

## Biome Matrix

The biome matrix maps elevation/moisture pairs to biome IDs:

```json
"biome_matrix": {
  "elevation_thresholds": [0.05, 0.25, 0.45, 0.62, 0.80],
  "moisture_thresholds": [0.2, 0.4, 0.6, 0.8],
  "matrix": [
    ["deep_ocean", "deep_ocean", "ocean", "ocean", "ocean"],
    ["ocean", "beach", "marsh", "swamp", "swamp"],
    ["beach", "grassland", "grassland", "forest", "rainforest"],
    ...
  ]
}
```

### Lookup Algorithm

1. Find elevation row by comparing to thresholds
2. Find moisture column by comparing to thresholds
3. Return biome ID at matrix[row][column]

## Noise Configuration

### Elevation Noise

```json
"elevation_noise": {
  "frequency": 0.03,
  "octaves": 3,
  "lacunarity": 2.0,
  "gain": 0.5,
  "elevation_curve": 1.5
}
```

| Property | Description |
|----------|-------------|
| `frequency` | Base noise frequency (lower = larger features) |
| `octaves` | Number of noise layers |
| `lacunarity` | Frequency multiplier per octave |
| `gain` | Amplitude multiplier per octave |
| `elevation_curve` | Power curve for elevation distribution |

### Moisture Noise

```json
"moisture_noise": {
  "frequency": 0.05,
  "octaves": 2,
  "lacunarity": 2.0,
  "gain": 0.5,
  "seed_offset": 1000
}
```

### Coastline Noise

```json
"coastline_noise": {
  "frequency": 0.002,
  "octaves": 3,
  "lacunarity": 2.0,
  "gain": 0.4,
  "seed_offset": 5000
}
```

Creates irregular coastlines by modifying island falloff.

## Chunk Settings

```json
"chunk_settings": {
  "chunk_size": 32,
  "load_radius": 3,
  "unload_radius": 5,
  "cache_max_size": 100
}
```

| Property | Description |
|----------|-------------|
| `chunk_size` | Tiles per chunk (32×32) |
| `load_radius` | Chunks to load around player |
| `unload_radius` | Chunks to unload beyond |
| `cache_max_size` | Maximum cached chunks |

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

| Property | Description |
|----------|-------------|
| `width_chunks` | Island width in chunks |
| `height_chunks` | Island height in chunks |
| `land_threshold` | Cutoff for land vs water |
| `distance_weight` | Edge falloff strength |
| `distance_exponent` | Edge falloff curve |
| `coastline_amplitude` | Coastline noise strength |

World size: 25 × 32 = 800 tiles in each dimension.

## Special Features Config

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

## Biome Definition Structure

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

See [Biomes Data](../data/biomes.md) for full property reference.

## Current Biomes

| ID | Name | Tree Density | Base Tile |
|----|------|--------------|-----------|
| `deep_ocean` | Deep Ocean | 0.0 | water |
| `ocean` | Ocean | 0.0 | water |
| `beach` | Beach | 0.0 | floor |
| `grassland` | Grassland | 0.05 | floor |
| `woodland` | Woodland | 0.15 | floor |
| `forest` | Forest | 0.3 | floor |
| `rainforest` | Rainforest | 0.5 | floor |
| `marsh` | Marsh | 0.1 | floor |
| `swamp` | Swamp | 0.2 | floor |
| `tundra` | Tundra | 0.02 | floor |
| `rocky_hills` | Rocky Hills | 0.02 | floor |
| `mountains` | Mountains | 0.0 | wall |
| `barren_rock` | Barren Rock | 0.0 | wall |
| `snow` | Snow | 0.0 | floor |
| `snow_mountains` | Snow Mountains | 0.0 | wall |

## Fallback Behavior

If biome not found or config fails to load:

```gdscript
# Default biome
{
  "id": "grassland",
  "name": "Grassland",
  "base_tile": "floor",
  "grass_char": "\"",
  "tree_density": 0.05,
  "rock_density": 0.01,
  "color_floor": [0.4, 0.6, 0.3],
  "color_grass": [0.5, 0.7, 0.4]
}
```

## Integration with Other Systems

- **ChunkManager**: Uses chunk and island settings
- **WorldChunk**: Uses biome data for terrain generation
- **SpecialFeaturePlacer**: Uses biome preferences for placement
- **Renderer**: Uses biome colors for tile rendering

## Related Documentation

- [Biomes Data](../data/biomes.md) - Biome JSON format
- [World Generation](../data/world-generation.md) - Config format
- [Chunk Manager](./chunk-manager.md) - Chunk streaming
- [Map Manager](./map-manager.md) - Map coordination
