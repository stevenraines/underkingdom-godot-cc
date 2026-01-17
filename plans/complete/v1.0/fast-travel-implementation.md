# Fast Travel System - Implementation Plan

## Overview
Implement a fast travel system allowing players to teleport to visited locations (towns and dungeon entrances).

## Requirements (from feature spec)
- Player can fast travel to any location they are aware of
- Towns: Start as visited by default
- Dungeons: Marked visited when player enters the chunk containing the dungeon
- UI should match the character sheet look and feel
- Teleport to walkable tile near entrance (dungeons) or within town bounds

---

## Implementation Steps

### Step 1: Add Visited Location Tracking to GameManager

Add a `visited_locations` dictionary to `GameManager` to track discovered locations:

```gdscript
# In game_manager.gd
var visited_locations: Dictionary = {}  # location_id -> {type, name, position, visited_turn}

func mark_location_visited(location_id: String, location_type: String, name: String, position: Vector2i) -> void:
    if not visited_locations.has(location_id):
        visited_locations[location_id] = {
            "type": location_type,  # "town" or "dungeon"
            "name": name,
            "position": position,
            "visited_turn": TurnManager.current_turn
        }
        EventBus.location_discovered.emit(location_id, name)

func is_location_visited(location_id: String) -> bool:
    return visited_locations.has(location_id)

func get_visited_locations() -> Dictionary:
    return visited_locations
```

### Step 2: Add EventBus Signal

Add new signal to `event_bus.gd`:
```gdscript
signal location_discovered(location_id: String, name: String)
```

### Step 3: Mark Towns as Visited at Game Start

In `game_manager.gd` `start_new_game()`, after map generation:
```gdscript
# Mark all towns as visited by default
func _mark_all_towns_visited() -> void:
    for town in TownManager.placed_towns:
        mark_location_visited(
            town.town_id,
            "town",
            town.name,
            town.position
        )
```

### Step 4: Track Dungeon Discovery via ChunkManager

When a chunk loads that contains a dungeon entrance, mark it as visited.

In `chunk_manager.gd`, after generating chunk content, check if any dungeon entrance is in the chunk:
```gdscript
func _check_for_dungeon_discoveries(chunk_pos: Vector2i) -> void:
    var entrances = MapManager.current_map.get_meta("dungeon_entrances", [])
    for entrance in entrances:
        var entrance_chunk = _get_chunk_coords(entrance.position)
        if entrance_chunk == chunk_pos and not GameManager.is_location_visited(entrance.dungeon_type):
            GameManager.mark_location_visited(
                entrance.dungeon_type,
                "dungeon",
                entrance.name,
                entrance.position
            )
```

### Step 5: Create FastTravelScreen UI

Create `ui/fast_travel_screen.gd` and `ui/fast_travel_screen.tscn` following the character sheet pattern:

**Structure:**
- Panel with MarginContainer
- VBoxContainer with:
  - Title label "== FAST TRAVEL =="
  - ScrollContainer with location list
  - Instructions label at bottom

**Features:**
- List all visited locations grouped by type (Towns, Dungeons)
- Arrow key navigation to select location
- Enter to travel, Escape to cancel
- Show location name and type
- Highlight selected location

### Step 6: Implement Fast Travel Logic

In `fast_travel_screen.gd`:
```gdscript
func _travel_to_location(location_id: String) -> void:
    var location = GameManager.visited_locations[location_id]
    var target_pos = location.position

    # If on overworld, teleport directly
    if MapManager.current_map.map_id == "overworld":
        _teleport_player_to(target_pos)
    else:
        # If in dungeon, first return to overworld, then teleport
        MapManager.current_dungeon_floor = 0
        MapManager.current_dungeon_type = ""
        MapManager.transition_to_map("overworld")
        # Defer teleport to after map transition
        await EventBus.map_changed
        _teleport_player_to(target_pos)

    close()

func _teleport_player_to(target_pos: Vector2i) -> void:
    var player = EntityManager.player
    # Find walkable tile near target
    var final_pos = _find_walkable_near(target_pos)
    player.position = final_pos
    EventBus.player_moved.emit(player.position, final_pos)
    EventBus.message_logged.emit("You fast travel to the destination.")
```

### Step 7: Add Input Handler Integration

In `input_handler.gd`:
```gdscript
KEY_Z:
    var game = get_parent()
    if game and game.has_method("toggle_fast_travel"):
        game.toggle_fast_travel()
```

Note: F key was already used for dungeon feature interaction, so Z key is used instead.

### Step 8: Add to Game Scene

In `game.gd`:
```gdscript
@onready var fast_travel_screen: Control = $UILayer/FastTravelScreen

func toggle_fast_travel() -> void:
    if fast_travel_screen.visible:
        fast_travel_screen.close()
    else:
        fast_travel_screen.open()
```

### Step 9: Save/Load Integration

In `save_manager.gd`:

**Serialize:**
```gdscript
func _serialize_world() -> Dictionary:
    return {
        # ... existing fields ...
        "visited_locations": GameManager.visited_locations.duplicate(true)
    }
```

**Deserialize:**
```gdscript
func _deserialize_world(world_data: Dictionary):
    # ... existing code ...
    if world_data.has("visited_locations"):
        GameManager.visited_locations = world_data.visited_locations.duplicate(true)
```

### Step 10: Update Help Screen

Add 'Z' key binding to help screen documentation.

---

## File Changes Summary

| File | Change |
|------|--------|
| `autoload/game_manager.gd` | Add visited_locations tracking |
| `autoload/event_bus.gd` | Add location_discovered signal |
| `autoload/chunk_manager.gd` | Add dungeon discovery on chunk load |
| `autoload/save_manager.gd` | Serialize/deserialize visited_locations |
| `ui/fast_travel_screen.gd` | New file - UI logic |
| `ui/fast_travel_screen.tscn` | New file - UI scene |
| `systems/input_handler.gd` | Add Z key binding |
| `scenes/game.gd` | Add toggle_fast_travel method |
| `scenes/game.tscn` | Add FastTravelScreen node |
| `ui/help_screen.gd` | Add Z key to help text |

---

## UI Design

```
╔════════════════════════════════════════╗
║          == FAST TRAVEL ==             ║
╠════════════════════════════════════════╣
║                                        ║
║  == TOWNS ==                           ║
║  > Thornhaven                          ║
║    Fishing Village                     ║
║    Mountain Outpost                    ║
║                                        ║
║  == DUNGEONS ==                        ║
║    Burial Barrow                       ║
║    Abandoned Mine                      ║
║                                        ║
╠════════════════════════════════════════╣
║  ↑↓ Select   Enter: Travel   Esc: Back ║
╚════════════════════════════════════════╝
```

**Colors (matching character sheet):**
- Section headers: `Color(0.8, 0.8, 0.5)` (golden)
- Location names: `Color(0.85, 0.85, 0.7)` (light tan)
- Selected location: `Color(0.7, 0.9, 0.7)` (light green)
- Unvisited (if shown): `Color(0.5, 0.5, 0.5)` (gray)

---

## Testing Checklist

- [ ] All towns appear as visited at game start
- [ ] Dungeons appear after entering their chunk
- [ ] Can fast travel from overworld to town
- [ ] Can fast travel from overworld to dungeon entrance
- [ ] Can fast travel from inside dungeon (returns to overworld first)
- [ ] Player lands on walkable tile
- [ ] Visited locations persist through save/load
- [ ] Z key opens fast travel screen
- [ ] Escape closes fast travel screen
- [ ] Arrow keys navigate location list
- [ ] Enter executes travel