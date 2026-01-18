# Add Town Skill

Workflow for adding new towns to the game.

---

## Steps

### 1. Create Town JSON

Create `data/towns/town_name.json`:

```json
{
  "id": "starter_town",
  "name": "Thornhaven",
  "description": "A small trading settlement where travelers rest.",
  "size": [25, 25],
  "biome_preferences": ["grassland", "woodland"],
  "placement": "any",
  "is_safe_zone": true,
  "known_at_start": true,
  "buildings": [
    {
      "building_id": "shop",
      "position_offset": [-7, -7],
      "npc_id": "shop_keeper",
      "door_facing": "south"
    },
    {
      "building_id": "blacksmith",
      "position_offset": [5, -5],
      "npc_id": "blacksmith",
      "door_facing": "south"
    },
    {
      "building_id": "well",
      "position_offset": [0, 8]
    }
  ],
  "decorations": {
    "perimeter_trees": true,
    "max_trees": 16
  },
  "roads": {
    "internal_roads": true,
    "town_square": true,
    "connected_to_other_towns": true
  }
}
```

### 2. Town Properties

| Property | Description |
|----------|-------------|
| `size` | [width, height] in tiles |
| `biome_preferences` | Where town can spawn |
| `placement` | "any", "coastal", "mountain" |
| `is_safe_zone` | Enemies don't spawn inside |
| `known_at_start` | Visible on map at game start |

### 3. Building Configuration

```json
{
  "building_id": "shop",
  "position_offset": [-7, -7],
  "npc_id": "shop_keeper",
  "door_facing": "south"
}
```

Building IDs: `shop`, `blacksmith`, `temple`, `mage_tower`, `tavern`, `well`, `house`

Door facings: `north`, `south`, `east`, `west`

### 4. NPC Assignment

Each building with an NPC should reference an NPC ID from `data/npcs/`:
```json
"npc_id": "blacksmith"
```

NPCs spawn inside their assigned building.

### 5. Decorations

```json
"decorations": {
  "perimeter_trees": true,
  "max_trees": 16,
  "gardens": true,
  "fountains": 1,
  "market_stalls": 3
}
```

### 6. Road Configuration

```json
"roads": {
  "internal_roads": true,
  "town_square": true,
  "connected_to_other_towns": true,
  "main_road_direction": "east_west"
}
```

---

## Verification

1. Restart game (TownManager loads on startup)
2. Check town generates in valid biome
3. Verify all buildings placed correctly
4. Check NPCs spawn in correct buildings
5. Test safe zone behavior
6. Verify roads connect properly

---

## Key Files

- `data/towns/` - Town definitions
- `autoload/town_manager.gd` - Town loading
- `generation/town_generator.gd` - Town generation
- `data/npcs/` - NPC definitions for towns
