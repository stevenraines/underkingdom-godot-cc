# Feature - Farming Mechanic
**Goal**: Implement a crop farming system where players can till soil, plant seeds, wait for crops to grow, and harvest them for food and more seeds.

---

## Overview

Players should be able to engage in agriculture as a sustainable food source. The farming loop consists of:

1. **Till** - Use a hoe to convert appropriate tiles (grass, dirt) into tilled soil
2. **Plant** - Use seeds from inventory on tilled soil to plant crops
3. **Wait** - Crops grow through multiple stages over time (turns)
4. **Harvest** - Mature crops yield produce and seeds (variable amounts)

This system builds on the existing harvest system patterns but adds tile transformation and growth state tracking.

---

## Core Mechanics

### Tillable Tiles

Only certain tile types can be tilled:
- `grass` → `tilled_soil`
- `dirt` → `tilled_soil`

Tiles that cannot be tilled:
- Water, rock, trees, floors, walls, roads, etc.

### Tilling Action

- **Tool Required**: Hoe (any variant: flint_hoe, iron_hoe, etc.)
- **Stamina Cost**: 8 per tile
- **Input**: Player presses a key (suggestion: 'F' for farm/till) then selects direction
- **Result**: Tile transforms to `tilled_soil`

### Tilled Soil Properties

```json
{
  "tile_type": "tilled_soil",
  "ascii_char": "≈",
  "color": "#8B4513",
  "walkable": true,
  "transparent": true,
  "can_plant": true
}
```

Tilled soil should revert to grass/dirt if:
- No crop is planted within N turns (suggestion: 1000 turns)
- This prevents permanent landscape scarring

### Planting Action

- **Requirements**:
  - Player has seeds in inventory
  - Target tile is `tilled_soil` with no existing crop
- **Input**: Player uses seed item on adjacent tilled soil (similar to harvest direction selection)
- **Stamina Cost**: 3 per planting
- **Result**:
  - Seed consumed from inventory
  - Crop entity spawned at tile position
  - Crop begins in "seedling" growth stage

### Crop Growth System

Crops grow through stages over time. Each stage has a visual representation and a duration.

#### Growth Stages

| Stage | Name | ASCII | Color | Turns to Next | Harvestable |
|-------|------|-------|-------|---------------|-------------|
| 0 | Seedling | `.` | `#90EE90` (light green) | 500 | No |
| 1 | Sprout | `"` | `#32CD32` (lime green) | 750 | No |
| 2 | Growing | `♣` | `#228B22` (forest green) | 1000 | No |
| 3 | Mature | `¥` | `#FFD700` (gold/yellow) | - | Yes |

Total growth time: ~2250 turns (~2.25 days)

#### Growth Processing

- Each turn, TurnManager calls `FarmingSystem.process_crop_growth()`
- Crops advance stage when enough turns have passed
- Only crops on currently loaded map chunks are processed (others catch up on load)

### Harvesting Crops

Mature crops can be harvested using the standard harvest system ('H' key).

#### Harvest Yields

Yields are defined per crop type with variable ranges:

```json
{
  "crop_id": "wheat_crop",
  "yields": [
    {
      "item_id": "wheat_grain",
      "min_count": 2,
      "max_count": 5
    },
    {
      "item_id": "wheat_seeds",
      "min_count": 1,
      "max_count": 3,
      "chance": 0.8
    }
  ]
}
```

- Primary yield (crop produce) is always granted
- Secondary yield (seeds) has a chance-based drop
- This creates sustainable farming but requires some seed management

#### Post-Harvest

After harvesting:
- Crop entity is removed
- Tilled soil remains (can plant again immediately)
- Yields drop on ground at crop position

### Crop Failure Conditions

Crops can fail/die under certain conditions:

1. **Neglect**: If tilled soil reverts before planting (timeout)
2. **Trampling**: If player or entity walks on seedling/sprout stage (optional)
3. **Season** (future): Winter kills certain crops (if seasons implemented)

Dead crops become `withered_crop` tile/entity that must be cleared.

---

## Data Structures

### Crop Definition (`data/crops/*.json`)

```json
{
  "id": "wheat_crop",
  "name": "Wheat",
  "seed_item_id": "wheat_seeds",
  "growth_stages": [
    {
      "name": "Seedling",
      "ascii_char": ".",
      "color": "#90EE90",
      "duration_turns": 500,
      "harvestable": false,
      "trample_vulnerable": true
    },
    {
      "name": "Sprout",
      "ascii_char": "\"",
      "color": "#32CD32",
      "duration_turns": 750,
      "harvestable": false,
      "trample_vulnerable": true
    },
    {
      "name": "Growing",
      "ascii_char": "♣",
      "color": "#228B22",
      "duration_turns": 1000,
      "harvestable": false,
      "trample_vulnerable": false
    },
    {
      "name": "Mature",
      "ascii_char": "¥",
      "color": "#FFD700",
      "duration_turns": -1,
      "harvestable": true,
      "trample_vulnerable": false
    }
  ],
  "yields": [
    {"item_id": "wheat_grain", "min_count": 2, "max_count": 5},
    {"item_id": "wheat_seeds", "min_count": 1, "max_count": 3, "chance": 0.8}
  ],
  "harvest_stamina_cost": 5,
  "harvest_message": "Harvested %yield% from the wheat"
}
```

### Seed Item Definition (`data/items/seeds/*.json`)

```json
{
  "id": "wheat_seeds",
  "name": "Wheat Seeds",
  "description": "Seeds for planting wheat crops",
  "type": "seed",
  "crop_id": "wheat_crop",
  "ascii_char": "•",
  "color": "#DEB887",
  "weight": 0.1,
  "value": 2,
  "stack_size": 50
}
```

### Crop Entity

```gdscript
class_name CropEntity extends Entity

var crop_id: String
var current_stage: int = 0
var turns_in_stage: int = 0
var planted_turn: int  # Turn when planted

func advance_growth() -> void:
    # Called each turn, advances stage when duration met

func get_current_stage_data() -> Dictionary:
    # Returns current stage visual/behavior info

func is_harvestable() -> bool:
    # True if current stage is harvestable
```

---

## Implementation Plan

### Phase 1: Tool and Tile Setup

1. **Create Hoe Tool**
   - Add `data/item_templates/tools/hoe.json` with tool_type "hoe"
   - Add material variants (flint_hoe, iron_hoe, steel_hoe)

2. **Create Tilled Soil Tile**
   - Add `tilled_soil` tile type to `GameTile.create()`
   - Properties: walkable, transparent, `can_plant: true`

3. **Create Till Action**
   - Add 'T' key binding for till mode (or reuse 'F' for farm)
   - Direction selection similar to harvest
   - Validate tile can be tilled
   - Consume stamina, transform tile

### Phase 2: Seed and Planting System

1. **Create Seed Items**
   - Add `data/items/seeds/` directory
   - Create wheat_seeds.json, carrot_seeds.json, etc.
   - Seeds reference their crop_id

2. **Create Planting Action**
   - Add 'P' key binding for plant mode
   - Select seed from inventory
   - Select direction to plant
   - Validate tilled soil, consume seed, spawn crop

3. **Create Crop Definitions**
   - Add `data/crops/` directory
   - Create wheat_crop.json, carrot_crop.json, etc.

### Phase 3: Crop Entity and Growth

1. **Create CropEntity Class**
   - Extends Entity
   - Tracks growth stage, turns in stage
   - Visual updates based on stage

2. **Create FarmingSystem**
   - Static class like HarvestSystem
   - Loads crop definitions from JSON
   - `process_crop_growth()` called each turn
   - Handles stage advancement

3. **Integrate with TurnManager**
   - Add `FarmingSystem.process_crop_growth()` to turn processing

### Phase 4: Harvesting Integration

1. **Register Crops as Harvestable**
   - Mature crops respond to 'H' harvest key
   - Use crop's yield definitions
   - Remove crop entity on harvest
   - Leave tilled soil behind

2. **Variable Yield Generation**
   - Random count between min/max
   - Chance-based secondary drops (seeds)

### Phase 5: Polish and Edge Cases

1. **Tilled Soil Decay**
   - Track when soil was tilled
   - Revert to grass if no crop planted in time

2. **Crop Trampling (Optional)**
   - Early stage crops destroyed if walked on
   - Message: "You trampled the seedling"

3. **Save/Load Integration**
   - Serialize crop entities with growth state
   - Serialize tilled soil decay timers

---

## Suggested Crops (Phase 1)

| Crop | Growth Time | Primary Yield | Seed Return |
|------|-------------|---------------|-------------|
| Wheat | 2250 turns | 2-5 wheat grain | 1-3 seeds (80%) |
| Carrots | 1500 turns | 2-4 carrots | 1-2 seeds (70%) |
| Potatoes | 2000 turns | 3-6 potatoes | 1-2 seeds (75%) |
| Cabbage | 1800 turns | 1-2 cabbage | 1 seed (60%) |

---

## New Files Required

### Data Files

```
data/
├── crops/
│   ├── wheat_crop.json
│   ├── carrot_crop.json
│   ├── potato_crop.json
│   └── cabbage_crop.json
├── items/
│   └── seeds/
│       ├── wheat_seeds.json
│       ├── carrot_seeds.json
│       ├── potato_seeds.json
│       └── cabbage_seeds.json
└── item_templates/
    └── tools/
        └── hoe.json
```

### Code Files

```
entities/
└── crop_entity.gd

systems/
└── farming_system.gd
```

### Modified Files

- `maps/game_tile.gd` - Add tilled_soil tile type
- `systems/input_handler.gd` - Add till and plant input modes
- `entities/player.gd` - Add till_soil() and plant_seed() methods
- `autoload/turn_manager.gd` - Call FarmingSystem.process_crop_growth()
- `autoload/save_manager.gd` - Serialize/deserialize crops and tilled soil

---

## Input Bindings

| Key | Action | Description |
|-----|--------|-------------|
| T | Till | Enter till mode, select direction to till soil |
| P | Plant | Enter plant mode, select seed and direction |
| H | Harvest | (Existing) Harvest mature crops |

---

## UI Messages

- "Till which direction?" - When entering till mode
- "The ground here cannot be tilled" - Invalid tile type
- "You till the soil" - Successful till
- "Plant which direction?" - When entering plant mode
- "Select seeds to plant: [seed list]" - Seed selection
- "You plant the [seed name]" - Successful planting
- "The [crop name] has matured!" - When crop reaches harvestable stage
- "Harvested [yield] from the [crop name]" - Successful harvest

---

## Future Enhancements

1. **Watering**: Crops require water to grow faster/at all
2. **Fertilizer**: Crafted item that increases yield
3. **Seasons**: Certain crops only grow in certain seasons
4. **Crop Quality**: Better tools/care = higher quality produce
5. **Pests**: Random events that damage crops
6. **Scarecrow**: Structure that protects crops from pests/trampling
7. **Irrigation**: Channels that auto-water adjacent crops

---

## Testing Checklist

- [ ] Hoe can be crafted/found/bought
- [ ] Grass/dirt tiles can be tilled with hoe
- [ ] Tilled soil appears with correct visual
- [ ] Seeds can be planted on tilled soil
- [ ] Crop entity spawns at seedling stage
- [ ] Crops advance through growth stages over time
- [ ] Mature crops show harvestable visual
- [ ] Harvesting mature crop yields produce + seeds
- [ ] Yield amounts are within defined ranges
- [ ] Seed drop chance works correctly
- [ ] Tilled soil remains after harvest
- [ ] Can immediately replant after harvest
- [ ] Crops save/load correctly with growth state
- [ ] Tilled soil decay works (reverts if unused)
