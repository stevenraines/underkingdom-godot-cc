# Feature - Fresh Water Sources

**Goal**: Add diverse water sources across all map types so players have reliable access to hydration beyond consumable items.

---

## Overview

Currently the game has a thirst system that drains every 15 turns (faster in hot weather) and causes penalties and death when depleted. Players can drink consumable items (ale, full waterskin) but there are no interactable water source features in the world. The `waterskin_empty` + `waterskin_full` item pair exists with a `fillable` flag, and water tiles already support `harvestable_resource_id = "water"` for the harvest system, but no feature-based water sources exist.

This feature adds **5 new water source features** placed across overworld, underworld dungeons, and towns. Each acts as a repeatable interaction point where the player can drink directly (restoring thirst) or fill an empty waterskin. Some sources (barrels, cisterns) are depletable and run dry after a few uses, while natural sources (springs, underground lakes) and built sources (wells) are permanent.

---

## Core Mechanics

### Water Source Types

| Source | Location | ASCII | Color | Permanent? | Uses | Thirst Restored |
|--------|----------|-------|-------|------------|------|-----------------|
| **Well** | Towns, dungeons | `O` | `#4488FF` | Yes | Infinite | 75 |
| **Spring** | Overworld (wilderness) | `~` | `#66CCFF` | Yes | Infinite | 100 |
| **Underground Lake** | Dungeons (natural caves, mines) | `~` | `#3366CC` | Yes | Infinite | 75 |
| **Barrel** | Dungeons (forts, compounds, ruins) | `0` | `#8B6914` | No | 3 uses | 50 |
| **Cistern** | Dungeons (sewers, temples, towers) | `U` | `#557788` | No | 5 uses | 75 |

### Interaction Behavior

When the player presses **F** (interact) on a water source:

1. **Check uses remaining** (for depletable sources). If empty, show "The barrel is empty."
2. **Check for empty waterskin** in inventory:
   - If player has `waterskin_empty`: fill it (transform to `waterskin_full`), show "You fill your waterskin."
   - If no waterskin: drink directly, restore thirst by the source's `thirst_restored` value, show "You drink from the spring. (+75 thirst)"
3. **Decrement uses** for depletable sources. When reaching 0, update the feature's display name (e.g., "Empty Barrel").

### New Effect Type: `"water_source"`

Add a new effect type to the FeatureManager interaction handler:

```gdscript
"water_source":
    # handled in player.gd _interact_with_feature_at()
    # Check for fillable containers, then drink directly
```

The feature JSON will use a new property `water_source: true` alongside `thirst_restored`, `max_uses` (0 = infinite), and `repeatable: true`.

---

## Data Structures

### Feature JSON Schema (new water source properties)

```json
{
  "id": "spring",
  "name": "Spring",
  "ascii_char": "~",
  "color": "#66CCFF",
  "blocking": false,
  "interactable": true,
  "interaction_verb": "drink from",
  "repeatable": true,
  "water_source": true,
  "thirst_restored": 100,
  "max_uses": 0,
  "fill_item_from": "waterskin_empty",
  "fill_item_to": "waterskin_full"
}
```

**New properties:**
- `water_source` (bool): Marks this feature as a drinkable water source
- `thirst_restored` (int): How much thirst is restored per drink (0-100)
- `max_uses` (int): Number of times the source can be used. `0` = infinite
- `fill_item_from` (string): Item ID that can be filled at this source
- `fill_item_to` (string): Item ID the container transforms into when filled

### Feature State (runtime)

For depletable sources, the feature's `state` dictionary tracks:
```gdscript
{
  "uses_remaining": 3  # Only set for max_uses > 0
}
```

---

## Implementation Plan

### Phase 1: Water Source Feature Definitions (JSON Data)

1. Create `data/features/water_sources/well.json`
2. Create `data/features/water_sources/spring.json`
3. Create `data/features/water_sources/underground_lake.json`
4. Create `data/features/water_sources/barrel.json`
5. Create `data/features/water_sources/cistern.json`

### Phase 2: FeatureManager Water Source Handling

1. In `autoload/feature_manager.gd` `interact_with_feature()`:
   - Add a `water_source` check block (after existing `harvestable` / `loot` / etc. blocks)
   - When `feature_def.get("water_source", false)` is true:
     - Check `max_uses > 0` and `state.uses_remaining <= 0` → return "empty" message
     - Add `"water_source"` effect to result with `thirst_restored`, `fill_item_from`, `fill_item_to`
     - Decrement `state.uses_remaining` for depletable sources
     - When depleted, update `feature.display_name` to "Empty [name]"
   - Mark the feature as `repeatable: true` so it can be interacted with multiple times

### Phase 3: Player Water Source Effect Handling

1. In `entities/player.gd` `_interact_with_feature_at()`:
   - Add `"water_source"` case to the effect match block
   - Check inventory for `fill_item_from` item (e.g., `waterskin_empty`)
   - If found: remove `fill_item_from`, add `fill_item_to` to inventory, show fill message
   - If not found: call `survival.drink(thirst_restored)`, show drink message
   - If thirst already at 100: show "You're not thirsty." and don't consume a use

### Phase 4: Overworld Spring Placement

1. In `maps/world_chunk.gd` `_generate_chunk()`:
   - After flora spawning, add spring placement logic
   - Use a low density (~0.002) to place springs on walkable, non-town, non-road tiles
   - Only spawn in biomes with `spring_density > 0` (woodland, grassland, swamp — not barren_rock or desert)
   - Use `FeatureManager.spawn_overworld_feature("spring", world_pos, biome_id, map)`

2. Add `"spring_density"` field to relevant biome definitions (or use a hardcoded default density in the chunk generator, consistent with herb/flower density pattern)

### Phase 5: Dungeon Water Source Placement

1. Add water source entries to each dungeon definition's `room_features` array:

   | Dungeon | Water Source | Notes |
   |---------|-------------|-------|
   | `natural_cave` | `underground_lake` | Already referenced (placeholder), now real |
   | `abandoned_mine` | `barrel` | Miners' water supply |
   | `ancient_fort` | `cistern` | Fort's water storage |
   | `military_compound` | `barrel` | Military water supply |
   | `burial_barrow` | `underground_lake` | Seepage pools |
   | `sewers` | `cistern` | Drainage collection (clean section) |
   | `temple_ruins` | `well` | Sacred well |
   | `wizard_tower` | `cistern` | Tower's water supply |

2. In `generation/dungeon_generators/base_dungeon_generator.gd` `_store_feature_data()`:
   - Add **guaranteed water source placement** logic:
   - After normal feature placement, check if a water source was placed on this floor
   - If not, and `floor_number % 5 == 0` (every 5th floor): place the dungeon's water source with ~80% probability
   - Water source feature IDs are identified by checking the feature definition for `water_source: true`
   - This ensures water is available roughly every 5 levels without being guaranteed (adds tension per your preference)

### Phase 6: Town Well Placement

1. In town generation (wherever town features/structures are placed):
   - Each town should spawn 1 well feature at a central, walkable position
   - Use `FeatureManager.spawn_overworld_feature("well", pos, biome_id, map)`

---

## New Files Required

### Data Files
```
data/features/water_sources/
├── well.json
├── spring.json
├── underground_lake.json
├── barrel.json
└── cistern.json
```

### Modified Files
- `autoload/feature_manager.gd` - Add `water_source` effect handling in `interact_with_feature()`
- `entities/player.gd` - Add `"water_source"` case in `_interact_with_feature_at()` effect processing
- `maps/world_chunk.gd` - Add spring spawning in overworld chunk generation
- `generation/dungeon_generators/base_dungeon_generator.gd` - Add guaranteed water source placement every ~5 floors
- `data/dungeons/natural_cave.json` - Update `underground_lake` feature reference
- `data/dungeons/abandoned_mine.json` - Add `barrel` water source
- `data/dungeons/ancient_fort.json` - Add `cistern` water source
- `data/dungeons/military_compound.json` - Add `barrel` water source
- `data/dungeons/burial_barrow.json` - Add `underground_lake` water source
- `data/dungeons/sewers.json` - Add `cistern` water source
- `data/dungeons/temple_ruins.json` - Add `well` water source
- `data/dungeons/wizard_tower.json` - Add `cistern` water source
- Town generation code - Add well placement per town

---

## UI Messages

- "You drink from the %s. (+%d thirst)" - When drinking directly
- "You fill your waterskin from the %s." - When filling a waterskin
- "You're not thirsty." - When thirst is already at 100 and no waterskin to fill
- "The %s is empty." - When depletable source has no uses remaining
- "The %s is running low." - When depletable source has 1 use remaining (warning)

---

## Future Enhancements

1. **Water quality**: Sewer cisterns could cause minor sickness if drunk from (chance of poisoning)
2. **Empty flask support**: Allow `empty_flask` as an alternative fillable container (already in item data)
3. **Rain barrels**: Overworld barrels that slowly refill during rain weather events
4. **Create Water spell integration**: The existing `create_water` conjuration spell could spawn a temporary spring feature
5. **Contaminated water**: Some dungeon water sources could be tainted, requiring purification
6. **Visual feedback**: Empty barrels/cisterns could change ASCII char (e.g., barrel `0` → empty barrel `o`)

---

## Testing Checklist

- [ ] Spring features spawn on overworld in appropriate biomes
- [ ] Springs do NOT spawn in towns, on roads, or in desert/barren biomes
- [ ] Well features appear in towns
- [ ] Each dungeon type spawns its assigned water source type
- [ ] Water sources appear roughly every 5 dungeon floors (~80% chance)
- [ ] Drinking from a water source restores correct thirst amount
- [ ] Drinking when thirst is full shows "not thirsty" and doesn't consume a use
- [ ] Filling waterskin removes `waterskin_empty` and adds `waterskin_full`
- [ ] If no waterskin, player drinks directly instead
- [ ] Barrel depletes after 3 uses and shows "empty" message
- [ ] Cistern depletes after 5 uses and shows "empty" message
- [ ] Well, spring, and underground lake never deplete
- [ ] "Running low" warning shows at 1 use remaining
- [ ] Water sources persist through save/load (feature state serialization)
- [ ] Depletable source use counts persist through save/load
