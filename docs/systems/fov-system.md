# FOV System

**Source File**: `systems/fov_system.gd`
**Type**: Static Class
**Class Name**: `FOVSystem`

## Overview

The FOV (Field of View) System calculates which tiles are visible to an entity using recursive shadowcasting. It implements symmetric shadowcasting for accurate line-of-sight with caching to avoid unnecessary recalculations. Time of day affects visibility range.

## Key Concepts

- **Shadowcasting**: Traces shadows from opaque tiles
- **Symmetric FOV**: Seeing implies being seen
- **8 Quadrants**: Covers all directions
- **Caching**: Avoids recalculation when position unchanged

## Algorithm

Based on symmetric shadowcasting:
- Reference: https://www.albertford.com/shadowcasting/
- Reference: https://www.roguebasin.com/index.php/FOV_using_recursive_shadowcasting

## Core Function

```gdscript
var visible = FOVSystem.calculate_fov(origin, range, map)
# Returns: Array[Vector2i] of visible tile positions
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `origin` | Vector2i | Center position for FOV |
| `range` | int | Maximum visibility distance |
| `map` | GameMap | Map for transparency checks |

## Caching

The system caches results to avoid recalculation:

```gdscript
static var cached_fov: Array[Vector2i] = []
static var cache_origin: Vector2i
static var cache_range: int
static var cache_time: String
static var cache_map_id: String
static var cache_dirty: bool = true
```

Cache is valid when:
- Origin unchanged
- Range unchanged
- Time of day unchanged
- Map unchanged
- Cache not invalidated

### Invalidating Cache

```gdscript
FOVSystem.invalidate_cache()
```

Call when:
- Map tiles change
- Structures placed/removed
- Doors opened/closed

## Time of Day Modifiers

Range is adjusted based on time:

| Time | Multiplier | Effect |
|------|------------|--------|
| Day | 100% | Full range |
| Dawn/Dusk | 75% | 25% reduction |
| Night | 50% | 50% reduction |

```gdscript
static func _adjust_range_for_time(base_range: int) -> int:
    match TurnManager.time_of_day:
        "night": return int(base_range * 0.5)
        "dawn", "dusk": return int(base_range * 0.75)
        _: return base_range  # "day"
```

## Quadrant Processing

FOV is calculated for 8 quadrants/octants:

```
    7 | 0 | 1
   ---+---+---
    6 | P | 2
   ---+---+---
    5 | 4 | 3
```

P = Player/Origin

Each quadrant uses the same algorithm with coordinate transforms.

## Coordinate Transform

```gdscript
static func transform_tile(origin, col, depth, direction) -> Vector2i:
    match direction:
        0: return Vector2i(origin.x + col, origin.y - depth)  # North
        1: return Vector2i(origin.x + depth, origin.y - col)  # NE
        2: return Vector2i(origin.x + depth, origin.y + col)  # East
        # ... etc for all 8 directions
```

## Row Structure

The algorithm uses rows with slope bounds:

```gdscript
class Row:
    var depth: int        # Distance from origin
    var start_slope: float  # Starting angle
    var end_slope: float    # Ending angle

    func tiles() -> Array:
        # Returns column indices in this row
```

## Scanning Process

```
1. Start with Row(depth=1, start=-1.0, end=1.0)
2. For each column in row:
   a. Transform to world coordinates
   b. Check bounds and range
   c. Mark tile as visible
   d. If tile blocks, create shadow (adjust slopes)
3. Continue to next row if not blocked
4. Recursively process sub-rows with adjusted slopes
```

## Transparency Check

```gdscript
var blocks_vision = not map.is_transparent(tile_pos)
```

Opaque tiles (walls, closed doors) block vision and create shadows.

## Slope Calculation

```gdscript
static func _slope(col: int) -> float:
    return (2.0 * float(col) - 1.0) / 2.0
```

Uses tile edges for accurate shadow boundaries.

## Chunk-Based Maps

For infinite/chunk-based maps:
```gdscript
if not map.chunk_based:
    # Check bounds only for fixed-size maps
    if tile_pos.x < 0 or tile_pos.x >= map.width:
        continue
```

## Usage Example

```gdscript
# Calculate player FOV
var visible_tiles = FOVSystem.calculate_fov(
    player.position,
    player.perception_range,
    MapManager.current_map
)

# Check if tile is visible
if visible_tiles.has(enemy.position):
    # Enemy is visible to player
```

## Performance

- Caching minimizes recalculation
- Only processes tiles within range
- Uses integer math where possible
- Typical FOV (range 10) processes ~300 tiles

## Integration with Other Systems

- **Renderer**: Renders only visible tiles
- **TurnManager**: Time of day affects range
- **StructureManager**: Invalidates cache on changes
- **HazardManager**: Detection uses visibility

## Related Documentation

- [Map Manager](./map-manager.md) - Map transparency
- [Turn Manager](./turn-manager.md) - Time of day
- [Ranged Combat System](./ranged-combat-system.md) - LOS checks
