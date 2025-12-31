# Harvest System Implementation

## Overview

Implemented a **generic, data-driven harvesting system** that supports multiple resource types with different behaviors:
- **Permanent destruction** (trees, rocks - never respawn)
- **Renewable resources** (wheat - respawns after time)
- **Non-consumable sources** (water - never depletes)

## Architecture

### Core Components

1. **HarvestSystem** ([systems/harvest_system.gd](systems/harvest_system.gd))
   - Static class managing all harvest logic
   - Loads resource definitions from separate JSON files
   - Recursively scans `data/resources/` directory like ItemManager
   - Handles tool checking, stamina costs, yield generation
   - Tracks renewable resource respawns

2. **Harvestable Resource Data** ([data/resources/](data/resources/))
   - Separate JSON file for each resource type
   - Loaded recursively from subdirectories
   - Configurable: tools, yields, stamina cost, respawn time

3. **GameTile Enhancement** ([maps/game_tile.gd](maps/game_tile.gd))
   - Added `harvestable_resource_id` property
   - Tile types now reference resource definitions

### Harvest Behaviors

```gdscript
enum HarvestBehavior {
    DESTROY_PERMANENT,  # Destroyed forever (trees, rocks)
    DESTROY_RENEWABLE,  # Respawns after N turns (wheat)
    NON_CONSUMABLE      # Never consumed (water sources)
}
```

## Resource Definitions

Each resource has:
- **Required Tools**: Array of tool IDs (e.g., `["axe", "knife"]`)
- **Harvest Behavior**: How resource responds to harvesting
- **Stamina Cost**: Energy required to harvest
- **Yields**: Items produced (with min/max counts, probability)
- **Replacement Tile**: What tile replaces resource after harvest
- **Respawn Turns**: For renewable resources only

### Example: Tree Resource ([data/resources/tree.json](data/resources/tree.json))

```json
{
  "id": "tree",
  "required_tools": ["axe", "flint_knife", "iron_knife"],
  "harvest_behavior": "destroy_permanent",
  "stamina_cost": 20,
  "yields": [
    {"item_id": "wood", "min_count": 2, "max_count": 4}
  ],
  "replacement_tile": "floor"
}
```

### Example: Wheat Resource (Renewable)

```json
{
  "id": "wheat",
  "required_tools": ["knife", "sickle"],
  "harvest_behavior": "destroy_renewable",
  "stamina_cost": 5,
  "respawn_turns": 5000,
  "yields": [
    {"item_id": "wheat", "min_count": 1, "max_count": 3}
  ],
  "replacement_tile": "floor"
}
```

### Example: Water Resource (Non-Consumable)

```json
{
  "id": "water",
  "required_tools": ["waterskin", "bottle"],
  "harvest_behavior": "non_consumable",
  "stamina_cost": 5,
  "yields": [
    {"item_id": "fresh_water", "min_count": 1, "max_count": 1}
  ]
}
```

## Implemented Resources

1. **tree** - Produces wood, destroyed permanently
2. **rock** - Produces stone + flint (30% chance), destroyed permanently
3. **wheat** - Produces wheat grain, renewable (respawns after 5000 turns)
4. **water** - Fills containers with fresh water, never depletes
5. **iron_ore** - Produces iron ore, destroyed permanently

## Tile Types

Added new harvestable tile types to GameTile factory:
- `"tree"` - Character: "T", harvestable_resource_id: "tree"
- `"rock"` - Character: "◆", harvestable_resource_id: "rock"
- `"wheat"` - Character: "\"", harvestable_resource_id: "wheat"
- `"water"` - Character: "~", harvestable_resource_id: "water"
- `"iron_ore"` - Character: "◊", harvestable_resource_id: "iron_ore"

## Player Interaction

### Input Flow
1. Player presses **H** key
2. Prompted: "Harvest which direction? (Arrow keys or WASD)"
3. Press arrow/WASD to harvest in that direction
4. System checks for harvestable resource
5. Validates tool requirement
6. Consumes stamina
7. Generates yields and drops items at harvest position
8. Updates tile based on behavior
9. Tracks renewable resources for respawn (if applicable)

### Method: `Player.harvest_resource(direction)`

```gdscript
func harvest_resource(direction: Vector2i) -> Dictionary:
    # Check for harvestable resource at target position
    # Delegate to HarvestSystem.harvest()
    return {"success": bool, "message": String}
```

## Renewable Resource Tracking

### RenewableResourceInstance Class
Tracks depleted renewable resources:
- `map_id`: Which map the resource is on
- `position`: Tile coordinates
- `resource_id`: Which resource to respawn
- `respawn_turn`: Turn number when it respawns

### Respawn Processing
- Called each turn via `TurnManager.advance_turn()`
- `HarvestSystem.process_renewable_resources()` checks respawn timers
- When current_turn >= respawn_turn, restores the original tile
- Only respawns on currently loaded map (other maps respawn when loaded)

### Save/Load Support
Serialization methods included for future save system:
- `HarvestSystem.serialize_renewable_resources()` → Array[Dictionary]
- `HarvestSystem.deserialize_renewable_resources(data)` → void

## Yield Probability System

Yields support probability for rare drops:

```json
"yields": [
  {"item_id": "stone", "min_count": 3, "max_count": 6},
  {"item_id": "flint", "min_count": 0, "max_count": 2, "chance": 0.3}
]
```

- Each yield has a `chance` field (default: 1.0 = 100%)
- Random roll determines if yield is granted
- Enables rare drops from common resources

## Integration Points

### Modified Files

1. **[entities/player.gd](entities/player.gd:151-164)**
   - Replaced `harvest_tree()` with generic `harvest_resource()`
   - Preloaded HarvestSystem

2. **[systems/input_handler.gd](systems/input_handler.gd:94-124)**
   - Added harvest direction input handling
   - 'H' key initiates harvest mode
   - Arrow/WASD keys select direction
   - ESC cancels harvest

3. **[autoload/turn_manager.gd](autoload/turn_manager.gd:40)**
   - Added `HarvestSystem.process_renewable_resources()` call each turn

4. **[autoload/game_manager.gd](autoload/game_manager.gd:17)**
   - Calls `HarvestSystem.load_resources()` on startup

5. **[maps/game_tile.gd](maps/game_tile.gd:13,42,48,69,75,81)**
   - Added `harvestable_resource_id` property
   - Updated tile factory for harvestable types

## New Items Created

1. **[data/items/materials/stone.json](data/items/materials/stone.json)**
   - Harvested from rocks

2. **[data/items/materials/wheat.json](data/items/materials/wheat.json)**
   - Harvested from wheat crops

3. **[data/items/consumables/fresh_water.json](data/items/consumables/fresh_water.json)**
   - Harvested from water sources
   - Restores 50 thirst

## Future Expansion

### Adding New Harvestable Resources
1. Define resource in `data/harvestable_resources.json`
2. Create item JSON files for yields
3. Add tile type to `GameTile.create()` factory
4. (Optional) Add to map generators

### Example: Berry Bush

```json
{
  "id": "berry_bush",
  "required_tools": [],  // Can harvest with hands
  "harvest_behavior": "destroy_renewable",
  "stamina_cost": 3,
  "respawn_turns": 2000,  // Respawns faster than wheat
  "yields": [
    {"item_id": "berries", "min_count": 2, "max_count": 5}
  ],
  "replacement_tile": "floor"
}
```

## Design Patterns Used

1. **Data-Driven Design**: All resources defined in JSON
2. **Strategy Pattern**: Different behaviors for resource depletion
3. **Static Utility Class**: HarvestSystem acts as pure logic processor
4. **Probability Tables**: Configurable yield randomness

## Performance Considerations

- Renewable resource tracking uses array iteration (O(n))
- Expected max ~100 renewable resources on map
- Processed once per turn, negligible cost
- Could optimize with priority queue if needed (future)

## Testing Checklist

- [x] System compiles without errors
- [x] HarvestSystem loads 5 resource definitions
- [ ] Can harvest trees with axe/knife
- [ ] Trees drop 2-4 wood
- [ ] Trees are destroyed permanently
- [ ] Can harvest rocks with pickaxe
- [ ] Rocks drop stone + occasional flint
- [ ] Can harvest wheat with knife/sickle
- [ ] Wheat respawns after 5000 turns
- [ ] Can fill waterskin from water tiles
- [ ] Water tiles never deplete
- [ ] Harvest requires correct tool
- [ ] Harvest fails when too tired
- [ ] Message shows what was harvested

---

**Status**: ✅ Complete
**Phase**: 1.13 Base Building
**Next**: Test in-game, add more harvestable tiles to world generation
