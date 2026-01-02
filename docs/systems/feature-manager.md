# Feature Manager

**Source File**: `autoload/feature_manager.gd`
**Type**: Autoload Singleton
**Class Name**: `FeatureManagerClass`

## Overview

The Feature Manager handles interactive dungeon features like treasure chests, altars, sarcophagi, and inscriptions. Features are loaded from JSON definitions and placed during dungeon generation. Players can interact with features to receive loot, summon enemies, read hints, or trigger special effects.

## Key Concepts

- **Feature Definitions**: JSON templates defining feature types
- **Active Features**: Runtime instances placed on current map
- **Feature Interaction**: Player triggering feature effects
- **Loot Generation**: Features can contain randomized treasure
- **Enemy Summoning**: Features can spawn enemies when opened

## Feature Lifecycle

1. **Definition Loading**: JSON files loaded at startup
2. **Placement**: Generator places features during map creation
3. **Activation**: Features stored in active_features dictionary
4. **Interaction**: Player interacts, effects applied
5. **Removal**: Some features removed after interaction

## Core Functionality

### Loading Definitions

```gdscript
FeatureManager.feature_definitions: Dictionary  # {feature_id: definition}
```

All JSON files in `data/features/` are loaded at startup.

### Active Features

```gdscript
FeatureManager.active_features: Dictionary  # {Vector2i: feature_data}
```

Current map's features, keyed by position.

### Interaction

```gdscript
var result = FeatureManager.interact_with_feature(position)
# Returns: {success, message, effects: [...]}
```

### Querying

```gdscript
# Get feature at position
var feature = FeatureManager.get_feature_at(pos)

# Check for interactable feature
var can_interact = FeatureManager.has_interactable_feature(pos)

# Check for blocking feature
var blocks = FeatureManager.has_blocking_feature(pos)
```

## Feature Definition Structure

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

## Feature Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | string | Unique identifier |
| `name` | string | Display name |
| `ascii_char` | string | Render character |
| `color` | string | Hex color code |
| `blocking` | bool | Blocks movement |
| `interactable` | bool | Can be interacted with |
| `interaction_verb` | string | Action word ("open", "examine") |
| `can_contain_loot` | bool | May have treasure |
| `can_summon_enemy` | bool | May spawn enemy |
| `can_grant_blessing` | bool | May give buff |
| `provides_hint` | bool | Shows dungeon hint |
| `harvestable` | bool | Gives yields on interact |
| `removes_on_interact` | bool | Disappears after use |
| `repeatable` | bool | Can interact multiple times |

## Interaction Effects

When interacting, effects are added to result array:

### Loot Effect
```gdscript
{"type": "loot", "items": [{"item_id": "gold_coin", "count": 25}]}
```

### Harvest Effect
```gdscript
{"type": "harvest", "items": [{"item_id": "cave_mushroom", "count": 2}]}
```

### Enemy Summon Effect
```gdscript
{"type": "summon_enemy", "enemy_id": "skeleton", "position": Vector2i}
```

### Hint Effect
```gdscript
{"type": "hint", "text": "Beware the darkness below..."}
```

### Blessing Effect
```gdscript
{"type": "blessing", "stat": "health", "amount": 10}
```

### Removed Effect
```gdscript
{"type": "removed"}
```

## Feature Placement

Features are placed by dungeon generators based on `room_features` in dungeon definition:

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

### Placement Process
1. Get floor positions from map
2. For each feature config, calculate spawn count
3. Filter positions (walkable, not stairs, not occupied)
4. Place features at random valid positions
5. Store in map metadata for persistence

## Loot Generation

Features with `can_contain_loot: true` generate treasure:

```gdscript
_generate_feature_loot(config, rng) -> Array
```

Loot is based on `loot_table` in config:
- `ancient_treasure`: 15-60 gold, 30% artifact
- Default: 5-25 gold

## Dungeon Hints

Features with `provides_hint: true` show random hints from dungeon definition:

```gdscript
FeatureManager.set_dungeon_hints(hints: Array)
```

When interacted, a random hint from `current_dungeon_hints` is displayed.

## Feature State

Each active feature tracks:

```gdscript
{
  "feature_id": "treasure_chest",
  "position": Vector2i,
  "definition": {...},
  "config": {...},
  "interacted": false,
  "state": {
    "loot": [...],          // If has loot
    "summons_enemy": "..."  // If summons enemy
  }
}
```

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `feature_interacted` | feature_id, position, result | After interaction |
| `feature_spawned_enemy` | enemy_id, position | When enemy summoned |

## Current Feature Types

| ID | Name | Blocking | Effects |
|----|------|----------|---------|
| `treasure_chest` | Treasure Chest | Yes | Loot |
| `sarcophagus` | Sarcophagus | Yes | Loot + Enemy |
| `altar` | Altar | Yes | Blessing |
| `tomb_inscription` | Tomb Inscription | No | Hint |
| `mushroom_patch` | Mushroom Patch | No | Harvest (mushrooms) |
| `crystal_formation` | Crystal Formation | No | Harvest (crystals) |
| `ore_vein` | Ore Vein | No | Harvest (ore) |
| `weapon_rack` | Weapon Rack | Yes | Loot (weapons) |
| `reliquary` | Reliquary | Yes | Loot (artifacts) |
| `summoning_circle` | Summoning Circle | No | Enemy + Loot |
| `rat_nest` | Rat Nest | No | Enemy (rats) |
| `smuggler_cache` | Smuggler Cache | No | Loot |
| `support_beam` | Support Beam | Yes | Destroyable |
| `sluice_gate` | Sluice Gate | Yes | Interactable |

## Map Persistence

Features are stored in `map.metadata.features` for save/load:

```gdscript
FeatureManager.load_features_from_map(map: GameMap)
```

This restores features when returning to a floor.

## Integration with Other Systems

- **DungeonManager**: Calls feature processing after generation
- **MapManager**: Triggers feature loading on map change
- **EntityManager**: Spawns summoned enemies
- **Player**: Processes interaction effects
- **LootTableManager**: Generates treasure

## Data Dependencies

- **Features** (`data/features/`): Feature definitions
- **Enemies** (`data/enemies/`): Summonable enemy IDs
- **Loot Tables** (`data/loot_tables/`): Treasure generation
- **Items** (`data/items/`): Loot item IDs

## Related Documentation

- [Features Data](../data/features.md) - Feature file format
- [Dungeon Manager](./dungeon-manager.md) - Feature placement
- [Loot Table Manager](./loot-table-manager.md) - Loot generation
- [Enemies Data](../data/enemies.md) - Summonable enemies
