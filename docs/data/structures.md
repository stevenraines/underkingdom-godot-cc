# Structures Data Format

**Location**: `data/structures/`
**File Count**: 3 files
**Loaded By**: StructureManager

## Overview

Structure definitions specify player-buildable objects including campfires, shelters, and storage containers. Each structure has build requirements, visual appearance, and optional components that provide functionality like heat, shelter, or storage.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique identifier (snake_case) | StructureManager |
| `name` | string | Display name | UI, messages |
| `ascii_char` | string | Display character | Renderer |
| `ascii_color` | string | Hex color code | Renderer |
| `structure_type` | string | Category type | StructureManager |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `description` | string | "" | Flavor text | UI |
| `blocks_movement` | bool | false | Impassable when placed | Pathfinding |
| `durability` | int | 100 | Structure health | Future damage |
| `components` | object | {} | Functional components | Various systems |
| `build_requirements` | array | [] | Required materials | StructurePlacement |
| `build_tool` | string | "" | Required tool | StructurePlacement |
| `build_time_turns` | int | 1 | Turns to build | Future building |

## Property Details

### `structure_type`
**Type**: string
**Required**: Yes

Category for the structure type.

| Type | Description |
|------|-------------|
| `campfire` | Fire source for heat and cooking |
| `shelter` | Protection from elements |
| `container` | Item storage |
| `workbench` | Crafting station (future) |

### `blocks_movement`
**Type**: bool
**Default**: false

When true, entities cannot walk through the structure.

### `components`
**Type**: object
**Default**: {}

Contains component configurations that provide functionality.

### `build_requirements`
**Type**: array
**Default**: []

Materials consumed when building.

```json
"build_requirements": [
    {"item": "wood", "count": 3},
    {"item": "iron_ore", "count": 2}
]
```

### `build_tool`
**Type**: string
**Default**: ""

Tool required to build (not consumed).

| Tool | Used For |
|------|----------|
| `flint` | Starting fires |
| `knife` | Cutting materials |
| `hammer` | Construction |

## Components

### Fire Component

Provides heat and cooking capability.

```json
"components": {
    "fire": {
        "heat_radius": 3,
        "temperature_bonus": 15.0,
        "light_radius": 5
    }
}
```

| Property | Type | Description |
|----------|------|-------------|
| `heat_radius` | int | Tiles warmed by fire |
| `temperature_bonus` | float | Temperature increase |
| `light_radius` | int | Light range in tiles |

Fire components enable:
- Nearby crafting (cooking)
- Temperature bonus
- Light source
- Enemy deterrent (feared by some creatures)

### Shelter Component

Provides protection from weather.

```json
"components": {
    "shelter": {
        "shelter_radius": 2,
        "temperature_bonus": 5.0,
        "blocks_rain": true
    }
}
```

| Property | Type | Description |
|----------|------|-------------|
| `shelter_radius` | int | Protected area |
| `temperature_bonus` | float | Temperature modifier |
| `blocks_rain` | bool | Prevents rain effects |

### Container Component

Provides item storage.

```json
"components": {
    "container": {
        "max_weight": 50.0
    }
}
```

| Property | Type | Description |
|----------|------|-------------|
| `max_weight` | float | Maximum storage weight in kg |

## Complete Examples

### Campfire

```json
{
    "id": "campfire",
    "name": "Campfire",
    "description": "A warming fire that can be used for cooking.",
    "ascii_char": "^",
    "ascii_color": "#FF6600",
    "blocks_movement": false,
    "structure_type": "campfire",
    "durability": 100,
    "components": {
        "fire": {
            "heat_radius": 3,
            "temperature_bonus": 15.0,
            "light_radius": 5
        }
    },
    "build_requirements": [
        {"item": "wood", "count": 3}
    ],
    "build_tool": "flint",
    "build_time_turns": 1
}
```

### Lean-to Shelter

```json
{
    "id": "lean_to",
    "name": "Lean-to Shelter",
    "description": "A simple shelter providing protection from the elements.",
    "ascii_char": "A",
    "ascii_color": "#8B4513",
    "blocks_movement": false,
    "structure_type": "shelter",
    "durability": 150,
    "components": {
        "shelter": {
            "shelter_radius": 2,
            "temperature_bonus": 5.0,
            "blocks_rain": true
        }
    },
    "build_requirements": [
        {"item": "wood", "count": 5},
        {"item": "cord", "count": 2}
    ],
    "build_tool": "knife",
    "build_time_turns": 1
}
```

### Storage Chest

```json
{
    "id": "chest",
    "name": "Storage Chest",
    "description": "A sturdy chest for storing items.",
    "ascii_char": "&",
    "ascii_color": "#CD853F",
    "blocks_movement": false,
    "structure_type": "container",
    "durability": 200,
    "components": {
        "container": {
            "max_weight": 50.0
        }
    },
    "build_requirements": [
        {"item": "wood", "count": 4},
        {"item": "iron_ore", "count": 2}
    ],
    "build_tool": "hammer",
    "build_time_turns": 1
}
```

## Current Structures

| ID | Name | Type | Materials |
|----|------|------|-----------|
| `campfire` | Campfire | Fire | 3 wood, flint |
| `lean_to` | Lean-to Shelter | Shelter | 5 wood, 2 cord, knife |
| `chest` | Storage Chest | Container | 4 wood, 2 iron_ore, hammer |

## Build Requirement Format

```json
{
    "item": "item_id",
    "count": 1
}
```

Materials are consumed from player inventory on successful build.

## Placement Rules

1. Only on overworld (not in dungeons)
2. Player must be within 1 tile
3. Position must be walkable
4. If blocks_movement, position must be empty
5. All materials must be available
6. Required tool must be present

## Validation Rules

1. `id` must be unique across all structures
2. `id` should use snake_case format
3. `ascii_char` must be single character
4. `ascii_color` must be valid hex (#RRGGBB)
5. `build_requirements.item` must match item IDs
6. `build_requirements.count` must be positive
7. Component properties must match expected types

## Related Documentation

- [Structure Manager](../systems/structure-manager.md) - Structure loading
- [Structure Placement](../systems/structure-placement.md) - Build validation
- [Survival System](../systems/survival-system.md) - Fire/shelter effects
- [Items Data](./items.md) - Build materials
