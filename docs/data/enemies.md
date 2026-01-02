# Enemies Data Format

**Location**: `data/enemies/`
**File Count**: 33 files
**Loaded By**: EntityManager

## Overview

Enemy definitions specify all hostile creatures in the game including their stats, AI behavior, appearance, and loot. Each JSON file defines a single enemy type that can be spawned in dungeons or the overworld. Enemies are referenced by dungeon `enemy_pools` configurations.

## JSON Schema

### Required Properties

| Property | Type | Description | Used By |
|----------|------|-------------|---------|
| `id` | string | Unique identifier (snake_case) | EntityManager |
| `name` | string | Display name | UI, messages |
| `ascii_char` | string | Display character | Renderer |
| `ascii_color` | string | Hex color code | Renderer |
| `stats` | object | Core attributes | CombatSystem |
| `behavior` | string | AI behavior type | Enemy AI |
| `base_damage` | int | Unarmed attack damage | CombatSystem |

### Optional Properties

| Property | Type | Default | Description | Used By |
|----------|------|---------|-------------|---------|
| `armor` | int | 0 | Damage reduction | CombatSystem |
| `loot_table` | string | "" | Loot table ID | LootTableManager |
| `yields` | array | [] | Direct item drops | EntityManager |
| `xp_value` | int | 0 | Experience on kill | Future XP system |
| `spawn_density_overworld` | int | 0 | Overworld spawn weight | WorldGenerator |
| `spawn_density_dungeon` | int | 0 | Dungeon spawn weight | DungeonManager |
| `min_spawn_level` | int | 1 | Earliest floor to spawn | DungeonManager |
| `max_spawn_level` | int | 50 | Latest floor to spawn | DungeonManager |
| `feared_components` | array | [] | Components that cause fear | Enemy AI |
| `fear_distance` | int | 0 | Fear reaction distance | Enemy AI |

## Property Details

### `stats`
**Type**: object
**Required**: Yes

Core RPG attributes affecting combat and abilities.

```json
"stats": {
  "health": 25,
  "str": 12,
  "dex": 8,
  "con": 14,
  "int": 5,
  "wis": 6,
  "cha": 4
}
```

| Stat | Description | Combat Use |
|------|-------------|------------|
| `health` | Maximum hit points | Damage threshold |
| `str` | Strength | Melee damage modifier |
| `dex` | Dexterity | Accuracy, evasion |
| `con` | Constitution | Health scaling |
| `int` | Intelligence | AI complexity |
| `wis` | Wisdom | Perception, detection |
| `cha` | Charisma | Future social systems |

### `behavior`
**Type**: string
**Required**: Yes

AI behavior pattern determining combat tactics.

| Behavior | Description | Typical INT |
|----------|-------------|-------------|
| `aggressive` | Always attacks on sight | 2-4 |
| `guardian` | Defends area, attacks intruders | 4-6 |
| `wander` | Roams randomly, attacks if threatened | 2-3 |
| `pack` | Coordinates with nearby allies | 4-6 |

### `base_damage`
**Type**: int
**Required**: Yes

Damage dealt on successful melee attack before modifiers.

```
Final Damage = base_damage + STR_modifier - target_armor
STR_modifier = (STR - 10) / 2  (rounded down)
```

### `armor`
**Type**: int
**Default**: 0

Flat damage reduction applied to incoming attacks.

### `loot_table`
**Type**: string
**Default**: ""

ID of loot table used when enemy dies. If empty, no loot drops.

```json
"loot_table": "undead_common"
```

### `yields`
**Type**: array
**Default**: []

Direct item drops independent of loot table. Always evaluated.

```json
"yields": [
  {"item_id": "raw_meat", "min_count": 0, "max_count": 1}
]
```

Note: `min_count: 0` means item may not drop.

### `feared_components`
**Type**: array
**Default**: []

Component types that cause this enemy to flee.

```json
"feared_components": ["fire"]
```

When within `fear_distance` of a feared component, enemy moves away instead of attacking.

### Spawn Densities

Control where and how often enemies spawn.

| Property | Description |
|----------|-------------|
| `spawn_density_overworld` | Weight for overworld spawning |
| `spawn_density_dungeon` | Weight for dungeon spawning |

Higher values = more likely to spawn. 0 = never spawns in that area.

### Spawn Levels

Control dungeon depth range.

| Property | Description |
|----------|-------------|
| `min_spawn_level` | First floor enemy can appear |
| `max_spawn_level` | Last floor enemy can appear |

## Enemy Categories

### Vermin

| ID | Name | Char | Health | Damage | Behavior |
|----|------|------|--------|--------|----------|
| `rat` | Rat | r | 5 | 1 | wander |
| `grave_rat` | Grave Rat | r | 8 | 2 | aggressive |
| `rat_swarm` | Rat Swarm | R | 15 | 3 | aggressive |

### Beasts

| ID | Name | Char | Health | Damage | Behavior |
|----|------|------|--------|--------|----------|
| `woodland_wolf` | Woodland Wolf | w | 20 | 4 | pack |
| `cave_bear` | Cave Bear | B | 50 | 8 | guardian |
| `cave_bat` | Cave Bat | b | 6 | 2 | wander |
| `crocodile` | Crocodile | C | 35 | 6 | guardian |

### Undead

| ID | Name | Char | Health | Damage | Behavior |
|----|------|------|--------|--------|----------|
| `skeleton` | Skeleton | s | 15 | 4 | guardian |
| `wight` | Wight | W | 20 | 5 | aggressive |
| `barrow_wight` | Barrow Wight | W | 25 | 5 | guardian |
| `barrow_lord` | Barrow Lord | L | 60 | 10 | guardian |

### Humanoids

| ID | Name | Char | Health | Damage | Behavior |
|----|------|------|--------|--------|----------|
| `bandit` | Bandit | @ | 20 | 4 | aggressive |
| `criminal` | Criminal | @ | 15 | 3 | wander |
| `cultist` | Cultist | c | 18 | 4 | pack |
| `soldier` | Soldier | S | 30 | 5 | guardian |
| `guard_captain` | Guard Captain | G | 45 | 7 | guardian |

### Magical

| ID | Name | Char | Health | Damage | Behavior |
|----|------|------|--------|--------|----------|
| `wizard` | Wizard | W | 25 | 6 | guardian |
| `magical_construct` | Magical Construct | M | 40 | 7 | guardian |
| `possessed_statue` | Possessed Statue | S | 35 | 6 | guardian |
| `rogue_spell` | Rogue Spell | * | 10 | 8 | aggressive |

## Complete Examples

### Basic Enemy

```json
{
  "id": "rat",
  "name": "Rat",
  "ascii_char": "r",
  "ascii_color": "#8B4513",
  "stats": {
    "health": 5,
    "str": 3,
    "dex": 14,
    "con": 4,
    "int": 1,
    "wis": 10,
    "cha": 2
  },
  "behavior": "wander",
  "base_damage": 1,
  "armor": 0,
  "loot_table": "rat_common",
  "xp_value": 2,
  "spawn_density_overworld": 30,
  "spawn_density_dungeon": 20
}
```

### Fear-Reactive Enemy

```json
{
  "id": "grave_rat",
  "name": "Grave Rat",
  "ascii_char": "r",
  "ascii_color": "#8B4513",
  "stats": {
    "health": 8,
    "str": 4,
    "dex": 12,
    "con": 6,
    "int": 2,
    "wis": 8,
    "cha": 3
  },
  "yields": [
    {"item_id": "raw_meat", "min_count": 0, "max_count": 1}
  ],
  "behavior": "aggressive",
  "base_damage": 2,
  "armor": 0,
  "feared_components": ["fire"],
  "fear_distance": 3,
  "loot_table": "rat_common",
  "xp_value": 5,
  "spawn_density_overworld": 0,
  "spawn_density_dungeon": 50,
  "min_spawn_level": 1,
  "max_spawn_level": 15
}
```

### Dungeon Boss

```json
{
  "id": "barrow_lord",
  "name": "Barrow Lord",
  "ascii_char": "L",
  "ascii_color": "#00FF00",
  "stats": {
    "health": 60,
    "str": 16,
    "dex": 10,
    "con": 18,
    "int": 8,
    "wis": 10,
    "cha": 14
  },
  "behavior": "guardian",
  "base_damage": 10,
  "armor": 4,
  "loot_table": "undead_boss",
  "xp_value": 200,
  "spawn_density_overworld": 0,
  "spawn_density_dungeon": 10,
  "min_spawn_level": 15,
  "max_spawn_level": 20
}
```

## Dungeon Enemy Pools

Enemies are spawned via dungeon `enemy_pools`:

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

### Pool Properties

| Property | Description |
|----------|-------------|
| `enemy_id` | Enemy definition ID |
| `weight` | Spawn probability weight |
| `floor_range` | [min, max] valid floors |
| `max_per_floor` | Optional spawn limit |

## AI Behavior by INT

| INT Range | Tactics |
|-----------|---------|
| 1-3 | Direct approach, no tactics |
| 4-6 | Flanking, retreats when low health |
| 7-9 | Group coordination, uses environment |
| 10+ | Predicts movement, calls reinforcements |

## Validation Rules

1. `id` must be unique across all enemies
2. `id` should use snake_case format
3. `ascii_char` must be a single character
4. `ascii_color` must be valid hex format (#RRGGBB)
5. `behavior` must be: aggressive, guardian, wander, or pack
6. `stats.health` must be positive
7. `base_damage` must be non-negative
8. `loot_table` must match a table in LootTableManager
9. `min_spawn_level` must be ≤ `max_spawn_level`

## Related Documentation

- [Dungeon Manager](../systems/dungeon-manager.md) - Enemy spawning
- [Combat System](../systems/combat-system.md) - Damage calculations
- [Loot Tables Data](./loot-tables.md) - Enemy drops
- [Dungeons Data](./dungeons.md) - Enemy pool configuration
