# Entity System Implementation Plan - Phase 1.7

**Scope**: Task 1.7 (Entity System) from PRD
**Branch**: `feature/entity-system`
**Goal**: Functional entity system with enemy spawning and basic AI movement

---

## Overview

Phase 1.7 establishes the entity management infrastructure that will support enemies, NPCs, and other game entities. This phase focuses on:

- Entity management and tracking across maps
- Enemy spawning during map generation
- Basic AI behavior for enemy movement
- Visual rendering of enemies on the game map

---

## Implementation Components

### 1. Entity Manager (Autoload)
**File**: `res://autoload/entity_manager.gd`
**Status**: ✅ Complete

**Purpose**: Central manager for all non-player entities

**Key Features:**
- Tracks all entities per map
- Loads enemy definitions from JSON data files
- Spawns enemies at specified positions
- Provides entity lookup by position
- Processes entity turns (AI execution)
- Handles entity removal on death

**Key Methods:**
```gdscript
func spawn_enemy(enemy_id: String, pos: Vector2i) -> Enemy
func get_entities_at(pos: Vector2i) -> Array[Entity]
func get_blocking_entity_at(pos: Vector2i) -> Entity
func process_entity_turns() -> void
func clear_entities() -> void
```

---

### 2. Enemy Base Class
**File**: `res://entities/enemy.gd`
**Status**: ✅ Complete

**Purpose**: Base class for all enemy entities with AI behavior

**Properties:**
- `behavior_type`: AI behavior pattern ("aggressive", "guardian", "pack", "wander")
- `aggro_range`: Detection range (scales with INT attribute)
- `is_alerted`: Whether enemy has detected the player
- `loot_table`: Reference for future loot drops
- `xp_value`: Experience reward on kill

**AI Behaviors:**
| Behavior | Description |
|----------|-------------|
| `aggressive` | Always chases player when in range |
| `guardian` | Holds position, chases only when player is close |
| `pack` | Chase behavior (future: coordinate with pack members) |
| `wander` | Random movement until player detected |

**Key Methods:**
```gdscript
static func create(enemy_data: Dictionary) -> Enemy
func take_turn() -> void
func _move_toward_target(target: Vector2i) -> void
func _wander() -> void
```

---

### 3. Enemy Data Files
**Location**: `res://data/enemies/`
**Status**: ✅ Complete

**Files:**
- `grave_rat.json` - Dungeon swarm enemy (INT 2, aggressive)
- `barrow_wight.json` - Dungeon guardian (INT 5, guardian)
- `woodland_wolf.json` - Overworld predator (INT 4, pack)

**Data Format:**
```json
{
  "id": "enemy_id",
  "name": "Display Name",
  "ascii_char": "X",
  "ascii_color": "#RRGGBB",
  "stats": {
    "health": 25,
    "str": 10,
    "dex": 10,
    "con": 10,
    "int": 5,
    "wis": 6,
    "cha": 4
  },
  "behavior": "aggressive",
  "loot_table": "table_id",
  "xp_value": 50
}
```

---

### 4. Enemy Spawning System
**Files**: 
- `res://generation/dungeon_generators/burial_barrow.gd`
- `res://generation/world_generator.gd`
**Status**: ✅ Complete

**Dungeon Spawning:**
- Enemies spawn in rooms (not first room where player starts)
- Number scales with floor depth: `1 + floor_number / 10`
- Deeper floors have higher chance of Barrow Wights vs Grave Rats
- Spawn data stored in map metadata for deferred instantiation

**Overworld Spawning:**
- Woodland Wolves scattered across walkable terrain
- 3-8 wolves per 20x20 overworld map
- Avoid spawning on stairs or special tiles

---

### 5. Turn System Integration
**File**: `res://autoload/turn_manager.gd`
**Status**: ✅ Complete

**Changes:**
- `advance_turn()` now calls `EntityManager.process_entity_turns()`
- Enemies act after player completes their action
- Each enemy's `take_turn()` method executes AI behavior

**Turn Order:**
1. Player takes action
2. Turn counter increments
3. All enemies execute their turns
4. `turn_advanced` signal emitted
5. Player turn flag reset

---

### 6. Event Bus Signals
**File**: `res://autoload/event_bus.gd`
**Status**: ✅ Complete

**New Signals:**
```gdscript
signal entity_moved(entity: Entity, old_pos: Vector2i, new_pos: Vector2i)
signal entity_died(entity: Entity)
```

**Usage:**
- `entity_moved`: Triggers rendering update when enemy moves
- `entity_died`: Triggers death message and visual cleanup

---

### 7. Game Scene Updates
**File**: `res://scenes/game.gd`
**Status**: ✅ Complete

**New Signal Handlers:**
```gdscript
func _on_entity_moved(entity: Entity, old_pos: Vector2i, new_pos: Vector2i)
func _on_entity_died(entity: Entity)
```

**Features:**
- Renders all enemies on map load
- Updates enemy positions when they move
- Displays death messages in log
- Clears enemy visuals on death

---

## Enemy Stats Reference

| Enemy | HP | STR | DEX | CON | INT | WIS | Behavior | XP |
|-------|-----|-----|-----|-----|-----|-----|----------|-----|
| Grave Rat | 8 | 4 | 12 | 6 | 2 | 8 | aggressive | 5 |
| Barrow Wight | 25 | 12 | 8 | 14 | 5 | 6 | guardian | 50 |
| Woodland Wolf | 18 | 10 | 14 | 12 | 4 | 10 | pack | 30 |

**Aggro Range Formula**: `3 + INT`

---

## Testing Checklist

### Entity Manager Tests
- [x] Enemy definitions load from JSON on startup
- [x] `spawn_enemy()` creates enemy at correct position
- [x] `get_blocking_entity_at()` returns enemy blocking tile
- [x] `process_entity_turns()` calls all enemy AI
- [x] `clear_entities()` removes all entities on map change

### Enemy AI Tests
- [x] Enemies detect player within aggro range
- [x] Aggressive enemies chase player
- [x] Guardian enemies only chase when close
- [x] Enemies pathfind around obstacles (basic)
- [x] Enemies stop at player position (don't overlap)

### Spawning Tests
- [x] Dungeon rooms contain enemies (except starting room)
- [x] Enemy count scales with floor depth
- [x] Overworld spawns woodland wolves
- [x] Enemies don't spawn on stairs

### Rendering Tests
- [x] Enemies render with correct ASCII character
- [x] Enemies render with correct color
- [x] Enemy position updates when they move
- [x] Dead enemies are cleared from display

---

## Files Modified/Created

### New Files
- `res://plans/entity-system-implementation.md` (this document)

### Modified Files
- `res://autoload/event_bus.gd` - Added entity signals
- `res://autoload/turn_manager.gd` - Enemy turn processing
- `res://entities/enemy.gd` - Full AI implementation
- `res://scenes/game.gd` - Entity event handling

### Pre-existing Files (Already Complete)
- `res://autoload/entity_manager.gd` - Entity management
- `res://entities/entity.gd` - Base entity class
- `res://data/enemies/grave_rat.json` - Enemy data
- `res://data/enemies/barrow_wight.json` - Enemy data
- `res://data/enemies/woodland_wolf.json` - Enemy data
- `res://generation/dungeon_generators/burial_barrow.gd` - Dungeon spawning
- `res://generation/world_generator.gd` - Overworld spawning

---

## Known Limitations

1. **No Combat Yet**: Enemies chase but don't attack (Phase 1.8)
2. **Simple Pathfinding**: Enemies use greedy movement, no A* pathfinding
3. **No Pack Coordination**: Pack behavior identical to aggressive for now
4. **No Enemy Persistence**: Enemies respawn on map re-entry (by design for now)

---

## Next Steps (Phase 1.8 - Combat)

Phase 1.8 will add:
- [ ] Bump-to-attack melee combat
- [ ] Attack resolution (hit chance, damage calculation)
- [ ] Player attacking enemies
- [ ] Enemies attacking player
- [ ] Health/damage display
- [ ] Death handling with corpses
- [ ] Basic loot drops

---

## Success Criteria

Phase 1.7 is complete when:
1. ✅ EntityManager tracks all entities per map
2. ✅ Enemy JSON data files define all Phase 1 enemies
3. ✅ Enemies spawn in dungeons and overworld
4. ✅ Enemies render with correct ASCII characters and colors
5. ✅ Enemies take turns after player acts
6. ✅ Enemies detect player within aggro range
7. ✅ Enemies move toward detected player
8. ✅ Different behavior types produce different AI patterns
9. ✅ Enemy death clears them from display
10. ✅ Map transitions properly spawn/clear enemies

---

**Phase Status**: ✅ COMPLETE

**Git Branch**: `feature/entity-system`
**Commits**: 
- `de81591` - Implement enemy AI movement system

---

*Document Version: 1.0*
*Last Updated: December 30, 2025*
