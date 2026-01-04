# Feature: Room Descriptions for Dungeons

**Goal**: Generate thematic, atmospheric descriptions for dungeon rooms that enhance immersion and provide gameplay hints. Inspired by the [donjon 5-Room Dungeon Generator](https://donjon.bin.sh/fantasy/5_room/).

---

## Overview

Currently, dungeon rooms are generated as geometric shapes without identity or atmosphere. This feature adds:

1. **Room Type Classification** - Categorize rooms by purpose (crypt, armory, ritual chamber, etc.)
2. **Dynamic Descriptions** - Generate atmospheric text based on room type and dungeon theme
3. **Visual Details** - Hint at contents (features, hazards, loot) through description
4. **Discovery Moments** - Display room description when player first enters

---

## Current State

### What Exists
- Rectangular and BSP room generators create rooms with position/size
- Dungeon definitions have `special_rooms` config (not implemented)
- Feature and hazard placement is random, not room-aware
- No room identity persists after generation

### What's Missing
- Room bounds not stored in map metadata
- No room type assignment
- No description generation system
- No "player entered room" detection

---

## Implementation Plan

### Phase 1: Room Tracking Infrastructure

**1.1 Store Room Data in Map Metadata**

Modify generators to persist room information:

```gdscript
# In map.metadata after generation:
"rooms": [
    {
        "id": "room_0",
        "bounds": {"x": 5, "y": 10, "width": 8, "height": 6},
        "type": "normal",  # or "entrance", "crypt", "treasure", etc.
        "connections": ["room_1", "corridor_0"],
        "first_entered": false
    },
    ...
]
```

**1.2 Add Room Query Methods**

Add to MapManager or create RoomManager:

```gdscript
func get_room_at(position: Vector2i) -> Dictionary
func get_room_by_id(room_id: String) -> Dictionary
func mark_room_entered(room_id: String) -> void
func is_room_discovered(room_id: String) -> bool
```

**Files to modify:**
- `generation/dungeon_generators/rectangular_rooms_generator.gd`
- `generation/dungeon_generators/bsp_rooms_generator.gd`
- `autoload/map_manager.gd` (or new `autoload/room_manager.gd`)

---

### Phase 2: Room Type Classification

**2.1 Define Room Types**

Create `data/room_types.json`:

```json
{
    "room_types": [
        {
            "id": "entrance",
            "name": "Entrance",
            "assignment": "first",
            "description_pool": "entrance"
        },
        {
            "id": "crypt",
            "name": "Crypt",
            "assignment": "random",
            "weight": 1.0,
            "dungeon_types": ["burial_barrow", "temple_ruins"],
            "description_pool": "crypt"
        },
        {
            "id": "armory",
            "name": "Armory",
            "assignment": "random",
            "weight": 0.5,
            "dungeon_types": ["ancient_fort", "military_compound"],
            "description_pool": "armory"
        },
        {
            "id": "ritual_chamber",
            "name": "Ritual Chamber",
            "assignment": "random",
            "weight": 0.3,
            "dungeon_types": ["temple_ruins", "wizard_tower"],
            "description_pool": "ritual"
        },
        {
            "id": "treasure_room",
            "name": "Treasure Chamber",
            "assignment": "random",
            "weight": 0.2,
            "max_per_floor": 1,
            "description_pool": "treasure"
        },
        {
            "id": "normal",
            "name": "Chamber",
            "assignment": "default",
            "description_pool": "normal"
        }
    ]
}
```

**2.2 Room Type Assignment Algorithm**

During generation:
1. First room = "entrance" type
2. Room with stairs_down = eligible for "stairs" descriptions
3. Randomly assign special types based on:
   - Dungeon type compatibility
   - Weight/probability
   - Max per floor limits
4. Remaining rooms = "normal" type

---

### Phase 3: Description Generation System

**3.1 Description Data Structure**

Create `data/room_descriptions/` directory with per-dungeon-theme files:

```json
// data/room_descriptions/burial_barrow.json
{
    "dungeon_id": "burial_barrow",
    "theme_adjectives": ["ancient", "musty", "cold", "silent", "forgotten"],
    "pools": {
        "entrance": {
            "templates": [
                "You descend into {adjective} darkness. {detail}",
                "Stone steps lead down into a {adjective} chamber. {detail}",
                "The entrance opens into {adjective} gloom. {detail}"
            ],
            "details": [
                "Cobwebs hang from the ceiling.",
                "The air smells of dust and decay.",
                "Your footsteps echo off ancient stone.",
                "Faded carvings line the walls."
            ]
        },
        "crypt": {
            "templates": [
                "Rows of {adjective} stone sarcophagi fill this chamber. {detail}",
                "This {adjective} crypt holds the remains of the forgotten dead. {detail}",
                "Burial niches line the walls of this {adjective} room. {detail}"
            ],
            "details": [
                "Some lids appear disturbed.",
                "Offerings of tarnished coins litter the floor.",
                "The names on the tombs have worn away.",
                "A faint moan echoes from somewhere deeper."
            ]
        },
        "normal": {
            "templates": [
                "A {adjective} chamber stretches before you. {detail}",
                "You enter a {adjective} room carved from stone. {detail}",
                "This {adjective} passage opens into a wider space. {detail}"
            ],
            "details": [
                "Shadows dance at the edge of your torchlight.",
                "The floor is worn smooth by ancient feet.",
                "Dust motes drift in the stale air.",
                "Something skitters in the darkness."
            ]
        }
    }
}
```

**3.2 Content-Aware Details**

Add conditional details based on room contents:

```json
"conditional_details": {
    "has_feature:altar": [
        "A dark altar dominates the center of the room.",
        "An ominous altar radiates cold malevolence."
    ],
    "has_feature:chest": [
        "A weathered chest sits against one wall.",
        "Something glints in the corner."
    ],
    "has_hazard:pit_trap": [
        "The floor appears uneven in places.",
        "You notice subtle variations in the stonework."
    ],
    "has_enemy": [
        "You sense movement in the shadows.",
        "Something stirs ahead.",
        "You are not alone."
    ],
    "has_loot": [
        "Glimmers of metal catch your eye.",
        "Scattered remains suggest previous visitors."
    ]
}
```

**3.3 Description Generator**

Create `systems/room_description_generator.gd`:

```gdscript
class_name RoomDescriptionGenerator

static func generate_description(room: Dictionary, dungeon_type: String, map: Map) -> String:
    var desc_data = _load_description_data(dungeon_type)
    var pool = desc_data.pools.get(room.type, desc_data.pools.normal)

    # Select template
    var template = pool.templates[rng.randi() % pool.templates.size()]

    # Select base detail
    var detail = pool.details[rng.randi() % pool.details.size()]

    # Add conditional details based on room contents
    var conditional = _get_conditional_detail(room, map, desc_data)
    if conditional:
        detail += " " + conditional

    # Select adjective
    var adjective = desc_data.theme_adjectives[rng.randi() % desc_data.theme_adjectives.size()]

    # Build final description
    return template.replace("{adjective}", adjective).replace("{detail}", detail)
```

---

### Phase 4: Display Integration

**4.1 Room Entry Detection**

In player movement or game loop:

```gdscript
func _on_player_moved(old_pos: Vector2i, new_pos: Vector2i) -> void:
    var old_room = MapManager.get_room_at(old_pos)
    var new_room = MapManager.get_room_at(new_pos)

    if new_room and new_room.id != old_room.get("id", ""):
        if not new_room.first_entered:
            _display_room_description(new_room)
            MapManager.mark_room_entered(new_room.id)
```

**4.2 Description Display**

Options for display:
- **Message Log**: Add to existing message system (simple)
- **Popup Panel**: Brief overlay that fades (more immersive)
- **Look Mode**: Show when player uses look command in room

Recommended: Message log with distinct color (e.g., dim cyan for atmosphere text).

**4.3 Signal for Room Entry**

Add to EventBus:

```gdscript
signal room_entered(room_id: String, room_data: Dictionary, is_first_time: bool)
```

---

### Phase 5: Save/Load Integration

**5.1 Persist Room Discovery State**

Add to save data:

```gdscript
# In SaveManager._serialize_map()
"discovered_rooms": ["room_0", "room_1", "room_3"]
```

**5.2 Restore on Load**

Mark rooms as discovered when loading saved game.

---

## Data Files to Create

| File | Purpose |
|------|---------|
| `data/room_types.json` | Room type definitions and weights |
| `data/room_descriptions/burial_barrow.json` | Burial Barrow descriptions |
| `data/room_descriptions/abandoned_mine.json` | Abandoned Mine descriptions |
| `data/room_descriptions/natural_cave.json` | Natural Cave descriptions |
| `data/room_descriptions/temple_ruins.json` | Temple Ruins descriptions |
| `data/room_descriptions/ancient_fort.json` | Ancient Fort descriptions |
| `data/room_descriptions/sewers.json` | Sewers descriptions |
| `data/room_descriptions/military_compound.json` | Military Compound descriptions |
| `data/room_descriptions/wizard_tower.json` | Wizard Tower descriptions |
| `data/room_descriptions/common.json` | Shared fallback descriptions |

---

## Files to Modify

| File | Changes |
|------|---------|
| `generation/dungeon_generators/rectangular_rooms_generator.gd` | Store room data in metadata |
| `generation/dungeon_generators/bsp_rooms_generator.gd` | Store room data in metadata |
| `autoload/map_manager.gd` | Add room query methods |
| `autoload/save_manager.gd` | Save/load discovered rooms |
| `autoload/event_bus.gd` | Add `room_entered` signal |
| `scenes/game.gd` | Listen for room entry, display descriptions |
| `entities/player.gd` or `systems/input_handler.gd` | Trigger room entry check |

---

## New Files to Create

| File | Purpose |
|------|---------|
| `systems/room_description_generator.gd` | Generate descriptions from templates |
| `autoload/room_manager.gd` (optional) | Centralize room tracking |

---

## Example Output

When player enters a crypt room in burial_barrow:

> *Rows of ancient stone sarcophagi fill this chamber. Some lids appear disturbed. You sense movement in the shadows.*

When player enters a normal room:

> *You enter a cold room carved from stone. The floor is worn smooth by ancient feet.*

---

## Future Enhancements

1. **WIS-based Hints**: Higher WIS reveals more details about hazards/enemies
2. **Revisit Descriptions**: Different text for returning to discovered rooms
3. **Dynamic Events**: Descriptions change based on game state (enemies cleared, loot taken)
4. **Audio Cues**: Pair descriptions with ambient sound effects
5. **Room Naming**: Generate names like "The Forgotten Ossuary" for special rooms

---

## Implementation Order

1. **Phase 1**: Room tracking (required foundation)
2. **Phase 2**: Room type classification
3. **Phase 3**: Description generation with 2-3 dungeon themes
4. **Phase 4**: Display integration
5. **Phase 5**: Save/load
6. **Expand**: Add remaining dungeon themes

Estimated scope: Medium-large feature (~3-4 implementation sessions)
