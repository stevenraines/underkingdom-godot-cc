# Features Data Format

**Location**: `data/features/`
**File Count**: 14 files
**Loaded By**: FeatureManager

## Overview

Features are interactive dungeon objects such as treasure chests, altars, inscriptions, and environmental elements. Each feature definition specifies its appearance, interaction behavior, and potential effects. Features are placed in dungeon rooms based on `room_features` in dungeon definitions.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique identifier (snake_case) | FeatureManager |
| `name` | string | Display name | UI, messages |
| `ascii_char` | string | Display character | Renderer |
| `color` | string | Hex color code | Renderer |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `blocking` | bool | false | Blocks movement | Map, Pathfinding |
| `interactable` | bool | false | Can be interacted with | InputHandler |
| `interaction_verb` | string | "use" | Action description | UI messages |
| `can_contain_loot` | bool | false | Has loot inside | FeatureManager |
| `can_be_trapped` | bool | false | May have trap | HazardManager |
| `can_summon_enemy` | bool | false | Spawns enemy on use | EntityManager |
| `can_grant_blessing` | bool | false | Provides buff | Player |
| `provides_hint` | bool | false | Shows hint text | UI |

## Property Details

### `blocking`
**Type**: bool
**Default**: false

When true, entities cannot move through this tile. Used for solid objects like chests and sarcophagi.

### `interactable`
**Type**: bool
**Default**: false

When true, player can interact with the feature using the interact key. The `interaction_verb` is displayed in the action prompt.

### `interaction_verb`
**Type**: string
**Default**: "use"

Verb displayed in interaction prompts: "[G] to {verb} {name}"

Examples: "open", "read", "pray at", "examine"

### `can_contain_loot`
**Type**: bool
**Default**: false

When true, the feature can contain items. Loot is generated from the `loot_table` specified in the dungeon's `room_features` configuration.

### `can_be_trapped`
**Type**: bool
**Default**: false

When true, the feature may trigger a hazard when interacted with. Trap type and chance are configured at the dungeon level.

### `can_summon_enemy`
**Type**: bool
**Default**: false

When true, interacting with the feature may spawn an enemy. Enemy type is specified in dungeon's `room_features` via `summons_enemy`.

### `can_grant_blessing`
**Type**: bool
**Default**: false

When true, interacting grants a temporary buff. Used for altars and shrines.

### `provides_hint`
**Type**: bool
**Default**: false

When true, interacting displays a hint from the dungeon's `hints` array. Used for inscriptions and tablets.

## Feature Categories

### Containers
Features that hold loot.

| ID | Name | Char | Properties |
|----|------|------|------------|
| `treasure_chest` | Treasure Chest | Z | blocking, loot, trapped |
| `sarcophagus` | Sarcophagus | & | blocking, loot, summons |
| `smuggler_cache` | Smuggler's Cache | $ | loot |
| `weapon_rack` | Weapon Rack | \| | loot |

### Informational
Features that provide information.

| ID | Name | Char | Properties |
|----|------|------|------------|
| `tomb_inscription` | Tomb Inscription | ? | hints |
| `altar` | Altar | _ | blessing |

### Environmental
Features that affect the environment.

| ID | Name | Char | Properties |
|----|------|------|------------|
| `ore_vein` | Ore Vein | * | harvestable |
| `crystal_formation` | Crystal Formation | ♦ | harvestable |
| `mushroom_patch` | Mushroom Patch | % | harvestable |
| `rat_nest` | Rat Nest | @ | summons |
| `support_beam` | Support Beam | H | destructible |
| `sluice_gate` | Sluice Gate | = | environment |
| `summoning_circle` | Summoning Circle | O | summons |
| `reliquary` | Reliquary | + | loot, blessing |

## Complete Examples

### Container Feature

```json
{
  "id": "treasure_chest",
  "name": "Treasure Chest",
  "ascii_char": "Z",
  "color": "#DAA520",
  "blocking": true,
  "interactable": true,
  "interaction_verb": "open",
  "can_contain_loot": true,
  "can_be_trapped": true
}
```

### Loot + Enemy Summon

```json
{
  "id": "sarcophagus",
  "name": "Sarcophagus",
  "ascii_char": "&",
  "color": "#808080",
  "blocking": true,
  "interactable": true,
  "interaction_verb": "open",
  "can_contain_loot": true,
  "can_summon_enemy": true
}
```

### Hint Provider

```json
{
  "id": "tomb_inscription",
  "name": "Tomb Inscription",
  "ascii_char": "?",
  "color": "#D3D3D3",
  "blocking": false,
  "interactable": true,
  "interaction_verb": "read",
  "provides_hint": true
}
```

### Blessing Provider

```json
{
  "id": "altar",
  "name": "Altar",
  "ascii_char": "_",
  "color": "#FFFFFF",
  "blocking": true,
  "interactable": true,
  "interaction_verb": "pray at",
  "can_grant_blessing": true
}
```

### Non-Blocking Feature

```json
{
  "id": "mushroom_patch",
  "name": "Mushroom Patch",
  "ascii_char": "%",
  "color": "#8B4513",
  "blocking": false,
  "interactable": true,
  "interaction_verb": "harvest"
}
```

## Feature Placement

Features are placed via dungeon `room_features` configuration:

```json
"room_features": [
  {
    "feature_id": "treasure_chest",
    "spawn_chance": 0.15,
    "room_types": ["end"],
    "loot_table": "ancient_treasure"
  }
]
```

### Placement Properties

| Property | Description |
|----------|-------------|
| `feature_id` | Must match a feature definition |
| `spawn_chance` | 0.0-1.0 probability per room |
| `room_types` | Where feature can spawn |
| `loot_table` | Loot table ID for contents |
| `summons_enemy` | Enemy ID spawned on interaction |

### Room Types

| Type | Description |
|------|-------------|
| `any` | Can appear in any room |
| `small` | Only in small rooms |
| `large` | Only in large rooms |
| `end` | Only in dead-end rooms |
| `corridor` | Only in corridors |

## Interaction Flow

```
Player adjacent to feature
    ↓
Press interact key (G)
    ↓
FeatureManager.interact_with_feature()
    ↓
Check feature flags
    ↓
├─ can_be_trapped → Check for trap
├─ can_summon_enemy → Roll for enemy spawn
├─ can_contain_loot → Generate and drop items
├─ can_grant_blessing → Apply buff
└─ provides_hint → Display message
    ↓
Emit feature_interacted signal
```

## Active Feature State

When placed on a map, features track:

```gdscript
{
  "feature_id": "treasure_chest",
  "position": Vector2i,
  "definition": {...},
  "opened": false,
  "looted": false,
  "has_trap": true
}
```

Stored in `map.metadata.features` for save/load.

## Validation Rules

1. `id` must be unique across all features
2. `id` should use snake_case format
3. `ascii_char` must be a single character
4. `color` must be valid hex format (#RRGGBB)
5. `interaction_verb` should be lowercase
6. Only set flags that apply to the feature type

## Related Documentation

- [Feature Manager](../systems/feature-manager.md) - Feature system mechanics
- [Dungeons Data](./dungeons.md) - Dungeon room_features config
- [Hazards Data](./hazards.md) - Trap hazards
- [Loot Tables Data](./loot-tables.md) - Feature loot generation
