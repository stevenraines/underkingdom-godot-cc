# Game Loop Simplification Plan

## Problem Summary

**Issue**: Game freezes when player fights monsters in adjacent chunks (cross-chunk combat).

**Root Cause**: During `EntityManager.process_entity_turns()`, line-of-sight checks in `RangedCombatSystem.is_tile_transparent()` trigger chunk loading via `ChunkManager.get_tile()`. Chunk loading emits signals (`chunk_loaded`, `chunk_unloaded`) that modify the `entities` array while it's being iterated, causing stale snapshots and infinite loops.

**Secondary Issue**: Turn loop complexity with 15 sequential steps and 3 separate entity loops (DoTs, effects, turns) makes the code difficult to understand and maintain.

## Current Architecture Issues

### Turn Loop (TurnManager.advance_turn, lines 46-112)
- **15 sequential steps** per turn
- **3 separate entity loops**:
  - DoTs processing (line 67, calls `_process_dot_effects()`)
  - Effect durations (line 71, calls `_process_effect_durations()`)
  - Entity turns (line 76, calls `EntityManager.process_entity_turns()`)
- Each loop calls `entities.duplicate()` separately (3N array copies per turn)
- Each loop does independent 20-tile range checks (3N distance calculations)
- No protection against chunk loading during entity processing

### Freeze Vector
```
Player attacks enemy in adjacent chunk
  ↓
RangedCombatSystem.attempt_ranged_attack()
  ↓
has_line_of_sight() traces tiles through multiple chunks
  ↓
is_tile_transparent() for each tile (line 335)
  ↓
ChunkManager.get_tile() triggers load_chunk() for unloaded chunks (line 342)
  ↓
load_chunk() emits EventBus.chunk_loaded signal (line 122)
  ↓
Signal handlers trigger chunk unloading
  ↓
_on_chunk_unloaded() modifies EntityManager.entities during iteration
  ↓
entities_snapshot becomes stale, entity skip logic breaks
  ↓
INFINITE LOOP or HANG
```

## Solution: 3-Phase Turn System

### Architecture Philosophy
Separate turn processing into 3 distinct phases with clear boundaries:

1. **PRE-TURN (Setup)**: Freeze world state, snapshot data
2. **EXECUTION**: Process all entity actions with frozen chunks
3. **POST-TURN (Cleanup)**: Apply deferred changes, emit signals

### Key Innovation: Chunk Operation Freezing
During entity processing (Phase 2), **freeze all chunk loading/unloading operations**:
- Queue chunk load/unload requests instead of executing them
- Return cached chunks or null for unloaded chunks
- Apply queued operations in Phase 3 after entity processing completes
- Prevents signal cascade that modifies entities array mid-iteration

### Performance Benefits
- **3N → N array copies**: Single `entities.duplicate()` instead of 3
- **3 loops → 1 loop**: Process DoTs, effects, and turns per entity in single pass
- **Better cache locality**: Sequential processing per entity
- **Reduced signal spam**: Batch chunk operations

## Implementation Plan

### Phase 1: Pre-Turn (Setup)

**Location**: `TurnManager.advance_turn()` (lines 46-65)

**Changes**:
1. Keep existing setup (lines 47-64): emit `player_turn_ended`, increment turn, update time
2. **NEW (after line 64)**: Freeze chunk operations
   ```gdscript
   ChunkManager.freeze_chunk_operations()
   ```
3. **NEW**: Prepare entity snapshot
   ```gdscript
   EntityManager.prepare_turn_snapshot()
   ```
4. Process player-only systems (survival, ritual) - no changes needed

**Result**: World state frozen, all snapshots prepared, ready for entity processing.

---

### Phase 2: Execution (Entity Processing)

**Location**: `TurnManager.advance_turn()` (lines 66-77) and `EntityManager.process_entity_turns()`

**Changes to TurnManager**:
- **DELETE lines 67-68**: Remove `_process_dot_effects()` call
- **DELETE lines 71-72**: Remove `_process_effect_durations()` call
- **KEEP line 76**: `EntityManager.process_entity_turns()`

**Changes to EntityManager**:
- **ADD new method**: `prepare_turn_snapshot()`
- **REWRITE**: `process_entity_turns()` to consolidate all entity processing

**New Consolidated Entity Loop**:
```gdscript
func process_entity_turns() -> void:
    var player_pos = player.position if player else Vector2i.ZERO

    # Process player summons first (existing pattern)
    if player:
        for summon in player.active_summons.duplicate():
            if summon.is_alive and summon.tick_duration():
                # Process effects inline
                if summon.has_method("process_dot_effects"):
                    summon.process_dot_effects()
                if summon.has_method("process_effect_durations"):
                    summon.process_effect_durations()
                summon.take_turn()
            if not player.is_alive:
                return

    # Single loop through entities
    for entity in _entity_snapshot:
        # Emergency brake
        if player and not player.is_alive:
            return

        # Skip checks
        if not entity.is_alive: continue
        if entity not in entities: continue  # Removed by death
        if "is_summon" in entity and entity.is_summon: continue

        # Chunk check (use snapshot, not live state)
        var current_chunk = ChunkManagerClass.world_to_chunk(entity.position)
        if entity.source_chunk != Vector2i(-999, -999) and not _is_chunk_active_snapshot(current_chunk):
            continue

        # Range check (20 tiles)
        var dist = abs(entity.position.x - player_pos.x) + abs(entity.position.y - player_pos.y)
        if dist > ENEMY_PROCESS_RANGE:
            continue

        # Process ALL effects for this entity in sequence
        if entity.has_method("process_dot_effects"):
            entity.process_dot_effects()

        if entity.has_method("process_effect_durations"):
            entity.process_effect_durations()

        # Take turn
        if entity is Enemy:
            (entity as Enemy).take_turn()
        elif entity.has_method("process_turn"):
            entity.process_turn()
```

**Result**: All entities processed in single pass, no chunk operations execute, no array modifications.

---

### Phase 3: Post-Turn (Cleanup)

**Location**: `TurnManager.advance_turn()` (lines 79-112)

**Changes**:
1. **KEEP line 81**: Player death check
2. **NEW (after line 83)**: Unfreeze and apply queued chunk operations
   ```gdscript
   ChunkManager.unfreeze_and_apply_queued_operations()
   ```
3. **KEEP lines 86-112**: Resources, farming, signals, autosave (no changes)

**Result**: Deferred chunk operations applied safely, world state updated, signals emitted.

---

## File-by-File Changes

### 1. `/autoload/turn_manager.gd`

**Add after line 11**:
```gdscript
# Snapshot for entity processing
var _entity_snapshot: Array[Entity] = []
var _active_chunks_snapshot: Dictionary = {}
```

**Modify advance_turn() (lines 46-112)**:
```gdscript
func advance_turn() -> void:
    print("[TurnManager] === Starting turn %d ===" % (current_turn + 1))

    # Player's turn is ending
    player_turn_ended.emit()
    current_turn += 1
    print("[TurnManager] Turn advanced to %d" % current_turn)

    _update_time_of_day()
    print("[TurnManager] Time of day updated")

    # Process player survival systems
    _process_player_survival()
    print("[TurnManager] Player survival processed")

    # Process ritual channeling
    _process_ritual_channeling()
    print("[TurnManager] Ritual channeling processed")

    # === PHASE 1: FREEZE WORLD STATE ===
    ChunkManager.freeze_chunk_operations()
    EntityManager.prepare_turn_snapshot()
    print("[TurnManager] Chunk operations frozen, snapshot prepared")

    # === PHASE 2: PROCESS ENTITIES (SINGLE LOOP) ===
    print("[TurnManager] Processing entity turns...")
    EntityManager.process_entity_turns()
    print("[TurnManager] Entity turns complete")

    # CRITICAL: If player died, stop immediately
    if EntityManager.player and not EntityManager.player.is_alive:
        ChunkManager.unfreeze_chunk_operations()
        print("[TurnManager] !!! PLAYER DIED - Stopping turn advancement !!!")
        return

    # === PHASE 3: UNFREEZE AND CLEANUP ===
    ChunkManager.unfreeze_and_apply_queued_operations()
    print("[TurnManager] Chunk operations unfrozen and applied")

    # Process world systems
    print("[TurnManager] Processing renewable resources...")
    HarvestSystem.process_renewable_resources()
    print("[TurnManager] Renewable resources complete")

    print("[TurnManager] Processing feature respawns...")
    FeatureManager.process_feature_respawns()
    print("[TurnManager] Feature respawns complete")

    print("[TurnManager] Processing farming systems...")
    FarmingSystem.process_crop_growth()
    FarmingSystem.process_tilled_soil_decay()
    print("[TurnManager] Farming systems complete")

    print("[TurnManager] Emitting turn_advanced signal")
    EventBus.turn_advanced.emit(current_turn)

    _process_autosave()

    is_player_turn = true
    player_turn_started.emit()
    print("[TurnManager] === Turn %d complete ===" % current_turn)
```

**DELETE lines 202-249**: Remove `_process_dot_effects()` and `_process_effect_durations()` methods entirely.

---

### 2. `/autoload/entity_manager.gd`

**Add after line 20** (after player reference):
```gdscript
# Turn processing snapshots (for chunk freeze safety)
var _entity_snapshot: Array[Entity] = []
var _active_chunks_snapshot: Dictionary = {}
```

**Add new method** (before process_entity_turns):
```gdscript
## Prepare snapshot for turn processing (called before chunk operations freeze)
func prepare_turn_snapshot() -> void:
    _entity_snapshot = entities.duplicate()
    _active_chunks_snapshot = {}
    for coords in ChunkManager.get_active_chunk_coords():
        _active_chunks_snapshot[coords] = true
    print("[EntityManager] Snapshot prepared: %d entities, %d active chunks" % [_entity_snapshot.size(), _active_chunks_snapshot.size()])

## Check if chunk is in snapshot (O(1) lookup)
func _is_chunk_active_snapshot(chunk_coords: Vector2i) -> bool:
    return chunk_coords in _active_chunks_snapshot
```

**REPLACE process_entity_turns()** (lines 363-450):
```gdscript
## Process all entity turns (CONSOLIDATED: DoTs + Effects + Turns in single loop)
func process_entity_turns() -> void:
    var player_pos = player.position if player else Vector2i.ZERO

    # Process player summons FIRST (maintains priority)
    if player:
        print("[EntityManager] Processing %d player summons..." % player.active_summons.size())
        for summon in player.active_summons.duplicate():
            if not summon.is_alive:
                continue

            # Tick duration (may dismiss summon)
            if summon.tick_duration():
                # Process all effects for this summon
                if summon.has_method("process_dot_effects"):
                    summon.process_dot_effects()

                if summon.has_method("process_effect_durations"):
                    summon.process_effect_durations()

                # Take turn
                summon.take_turn()

            # Emergency brake
            if not player.is_alive:
                print("[EntityManager] Player died during summon processing - stopping")
                return

    # CONSOLIDATED ENTITY LOOP (DoTs + Effects + Turns)
    print("[EntityManager] Processing %d entities from snapshot..." % _entity_snapshot.size())
    var processed_count = 0

    for entity in _entity_snapshot:
        # Emergency brake
        if player and not player.is_alive:
            print("[EntityManager] Player died during entity processing - stopping")
            return

        # Skip if dead
        if not entity.is_alive:
            continue

        # Skip if removed from entities array (death during this turn)
        if entity not in entities:
            continue

        # Skip summons (already processed)
        if "is_summon" in entity and entity.is_summon:
            continue

        # Check if entity's chunk is active (use snapshot, not live state)
        var current_chunk = ChunkManagerClass.world_to_chunk(entity.position)
        if entity.source_chunk != Vector2i(-999, -999) and not _is_chunk_active_snapshot(current_chunk):
            print("[EntityManager] Entity '%s' at %v (chunk %v) in unloaded chunk - skipping" % [entity.name, entity.position, current_chunk])
            continue

        # Range check: Only process entities within ENEMY_PROCESS_RANGE
        var dist = abs(entity.position.x - player_pos.x) + abs(entity.position.y - player_pos.y)
        if dist > ENEMY_PROCESS_RANGE:
            continue

        # PROCESS ALL EFFECTS FOR THIS ENTITY
        # 1. DoT effects (damage over time)
        if entity.has_method("process_dot_effects"):
            entity.process_dot_effects()

        # 2. Effect durations (expire effects)
        if entity.has_method("process_effect_durations"):
            entity.process_effect_durations()

        # 3. Take turn (AI action)
        if entity is Enemy:
            (entity as Enemy).take_turn()
            processed_count += 1
        elif entity.has_method("process_turn"):
            entity.process_turn()
            processed_count += 1

    print("[EntityManager] Processed %d entities" % processed_count)
```

**KEEP remaining methods** (register_entity, unregister_entity, etc.) - no changes.

---

### 3. `/autoload/chunk_manager.gd`

**Add after line 26** (after `_updating_chunks`):
```gdscript
# Chunk operation freezing (prevents chunk loading during entity processing)
var _chunk_ops_frozen: bool = false
var _queued_loads: Array[Vector2i] = []
var _queued_unloads: Array[Vector2i] = []
```

**Add new methods** (after `enable_chunk_mode()`):
```gdscript
## Freeze chunk loading/unloading (during entity processing)
func freeze_chunk_operations() -> void:
    _chunk_ops_frozen = true
    _queued_loads.clear()
    _queued_unloads.clear()
    print("[ChunkManager] Chunk operations FROZEN")

## Unfreeze and apply queued operations
func unfreeze_and_apply_queued_operations() -> void:
    _chunk_ops_frozen = false

    print("[ChunkManager] Unfreezing and applying %d loads, %d unloads" % [_queued_loads.size(), _queued_unloads.size()])

    # Unload first (frees memory)
    for coords in _queued_unloads:
        if coords in active_chunks:
            unload_chunk(coords)
    _queued_unloads.clear()

    # Load requested chunks
    for coords in _queued_loads:
        if coords not in active_chunks:
            load_chunk(coords)
    _queued_loads.clear()

    print("[ChunkManager] Chunk operations UNFROZEN")

## Check if operations are frozen (for external checks)
func is_frozen() -> bool:
    return _chunk_ops_frozen
```

**Modify load_chunk()** (add check at START of function, after line 72):
```gdscript
func load_chunk(chunk_coords: Vector2i) -> WorldChunk:
    # If frozen, queue the load and return cached chunk or null
    if _chunk_ops_frozen:
        if chunk_coords not in _queued_loads:
            _queued_loads.append(chunk_coords)
            print("[ChunkManager] Chunk load QUEUED: %v" % chunk_coords)

        # Return cached chunk if available
        if chunk_coords in chunk_cache:
            return chunk_cache[chunk_coords]

        # Return null - caller must handle gracefully
        return null

    # ... rest of existing load_chunk code
```

**Modify unload_chunk()** (add check at START of function, line 227):
```gdscript
func unload_chunk(chunk_coords: Vector2i) -> void:
    # If frozen, queue the unload
    if _chunk_ops_frozen:
        if chunk_coords not in _queued_unloads:
            _queued_unloads.append(chunk_coords)
            print("[ChunkManager] Chunk unload QUEUED: %v" % chunk_coords)
        return

    # ... rest of existing unload_chunk code
```

---

### 4. `/systems/ranged_combat_system.gd`

**Modify is_tile_transparent()** (line 335, replace function body):
```gdscript
## Check if a tile is transparent (doesn't block vision/projectiles)
static func is_tile_transparent(pos: Vector2i) -> bool:
    if not MapManager.current_map:
        return false

    var tile = null
    if MapManager.current_map.chunk_based:
        tile = ChunkManager.get_tile(pos)
    else:
        tile = MapManager.current_map.get_tile(pos)

    # If chunk not loaded (frozen operations), treat as opaque
    # This prevents cross-chunk LOF checks from forcing chunk loads
    if not tile:
        return false

    return tile.transparent
```

**Rationale**: When chunk operations are frozen, `get_tile()` returns null for unloaded chunks. Treating null tiles as opaque causes LOF checks to fail gracefully instead of forcing chunk loads.

---

### 5. `/entities/enemy.gd`

**No changes required** - enemy movement already respects chunk boundaries via MapManager checks.

---

## Data Structures Summary

### TurnManager
```gdscript
# No new data structures needed - chunk freezing handled by ChunkManager
```

### EntityManager
```gdscript
var _entity_snapshot: Array[Entity] = []        # Snapshot taken before turn processing
var _active_chunks_snapshot: Dictionary = {}     # chunk_coords -> true, O(1) lookup
```

### ChunkManager
```gdscript
var _chunk_ops_frozen: bool = false             # Flag prevents chunk load/unload
var _queued_loads: Array[Vector2i] = []         # Chunk loads to apply after unfreeze
var _queued_unloads: Array[Vector2i] = []       # Chunk unloads to apply after unfreeze
```

---

## Migration Strategy

### Step 1: Add Infrastructure (Non-Breaking)
1. Add snapshot fields to EntityManager
2. Add freeze flags and queues to ChunkManager
3. Add freeze/unfreeze methods (inactive)
4. Run tests - no changes in behavior yet

### Step 2: Add Safety Checks (Non-Breaking)
1. Update `is_tile_transparent()` to handle null tiles
2. Update `load_chunk()` and `unload_chunk()` to check freeze flag
3. Run tests - behavior unchanged (freeze never active)

### Step 3: Consolidate Entity Loop (Breaking)
1. Add `prepare_turn_snapshot()` method
2. Rewrite `process_entity_turns()` with consolidated loop
3. Remove `_process_dot_effects()` and `_process_effect_durations()` from TurnManager
4. Run tests - verify all effects still process

### Step 4: Activate Freezing (Final)
1. Add freeze/unfreeze calls to TurnManager.advance_turn()
2. Run tests - verify cross-chunk combat no longer freezes

---

## Testing Plan

### Primary Bug: Cross-Chunk Combat Freeze

**Setup**:
1. Create world with player in chunk (0, 0)
2. Spawn enemy in chunk (1, 0) (adjacent chunk)
3. Give player ranged weapon (bow + arrows)

**Test Cases**:
1. **Player shoots enemy in adjacent chunk**
   - Action: Shoot enemy at range 5-10 tiles
   - Expected: No freeze, attack resolves (hit or miss based on LOF)
   - Verify: Game continues, no infinite loop
   - Check: Chunk load queued, not executed during entity processing

2. **Enemy casts spell at player across chunks**
   - Setup: Spellcaster enemy in adjacent chunk
   - Action: Let enemy take turn
   - Expected: Spell cast fails or succeeds based on cached chunk data
   - Verify: No chunk loading during entity turn, no freeze

3. **Rapid chunk traversal during combat**
   - Setup: Sprint mode enabled, enemies in multiple chunks
   - Action: Sprint across chunk boundaries while enemies pursue
   - Expected: Smooth movement, no stutter
   - Verify: Chunk operations queued, applied after turn

### Functional Regression Tests

**Entity Processing Order**:
1. Verify summons act before enemies
2. Verify DoTs apply before effects expire
3. Verify effects expire before entity turns

**Effect Processing**:
1. Apply poison DoT to player and 3 enemies
2. Apply slow effect to player and 2 enemies
3. Advance turn
4. Verify: All DoTs tick, all effects tick duration, all entities act

**Player Death Stop**:
1. Set player HP to 5
2. Position enemy adjacent to player
3. Let enemy attack (should kill player)
4. Verify: Entity processing stops immediately
5. Verify: No resource/farming systems run

**Chunk Edge Cases**:
1. Player at chunk boundary (coordinates divisible by 32)
2. Move to adjacent chunk
3. Verify: Smooth transition, entities process correctly

### Performance Benchmarks

**Measure Before/After**:
- Turn processing time (average over 100 turns)
- Memory usage (entities array size)
- Chunk operation count per turn

**Expected Results**:
- Turn time: 10-30% faster (fewer duplicates, single loop)
- Memory: Slight increase (~1-2 KB per turn for snapshots)
- Chunk ops: Same count, but batched

**Baseline** (current system):
- ~50-200ms per turn (varies with entity count)
- 3× `entities.duplicate()` per turn
- Chunk ops can happen mid-turn (signal spam)

**Target** (new system):
- ~30-150ms per turn
- 1× `entities.duplicate()` per turn
- Chunk ops batched at end of turn

---

## Rollback Plan

If issues arise, rollback is straightforward:

1. **Remove freeze calls** from TurnManager.advance_turn()
2. **Restore** `_process_dot_effects()` and `_process_effect_durations()` methods
3. **Revert** EntityManager.process_entity_turns() to separate loops
4. **Keep** null tile handling in is_tile_transparent() (improves stability)

All infrastructure (freeze flags, snapshots) is passive when not activated.

---

## Success Criteria

✅ **Primary**: Cross-chunk combat no longer freezes game
✅ **Secondary**: Turn loop easier to understand (3 phases vs 15 steps)
✅ **Performance**: Turn processing 10-30% faster
✅ **Stability**: No regression in existing features (DoTs, effects, summons, death)

---

## Critical Files

- [autoload/turn_manager.gd](autoload/turn_manager.gd) - Main turn loop restructure
- [autoload/entity_manager.gd](autoload/entity_manager.gd) - Consolidated entity processing
- [autoload/chunk_manager.gd](autoload/chunk_manager.gd) - Chunk operation freezing
- [systems/ranged_combat_system.gd](systems/ranged_combat_system.gd) - Null tile handling
- [entities/enemy.gd](entities/enemy.gd) - Enemy AI (no changes needed)

---

## Implementation Estimate

- **Infrastructure setup**: 30 minutes
- **Entity loop consolidation**: 1 hour
- **Freeze mechanism**: 45 minutes
- **Testing and debugging**: 2 hours
- **Total**: ~4-5 hours

---

## CRITICAL REVIEW & ISSUES FOUND

### ⚠️ CRITICAL ISSUE 1: Player Effect Processing Missing

**Problem**: The plan removes `_process_dot_effects()` and `_process_effect_durations()` from TurnManager (lines 67-68, 71-72), but these methods process **PLAYER effects** first (current lines 207-208, 231-232). The consolidated EntityManager loop only processes entities from `_entity_snapshot`, **NOT the player**.

**Impact**: Player DoTs and magical effects would stop working entirely. **GAME BREAKING**.

**Required Fix** - Add to TurnManager.advance_turn() BEFORE calling EntityManager.process_entity_turns():
```gdscript
# Process PLAYER effects (player is not in entities array)
if EntityManager.player:
    if EntityManager.player.has_method("process_dot_effects"):
        EntityManager.player.process_dot_effects()
    if EntityManager.player.has_method("process_effect_durations"):
        EntityManager.player.process_effect_durations()

# Then process entity turns
EntityManager.process_entity_turns()
```

---

### ⚠️ CRITICAL ISSUE 2: get_tile() Returns Ocean, Not Null

**Problem**: When `load_chunk()` returns null (frozen), `ChunkManager.get_tile()` (line 316-334) has fallback code:
```gdscript
if chunk:
    return chunk.get_tile(local_pos)

# Fallback - return ocean tile
return GameTile.create("water")
```

This means `is_tile_transparent()` receives an **ocean tile** (which IS transparent), not null. The null check in the plan won't trigger!

**Impact**: LOF checks through unloaded chunks would treat them as water (transparent), allowing players to **see and shoot through walls** when chunks are frozen. **SEVERE BUG**.

**Required Fix** - Modify ChunkManager.get_tile() fallback:
```gdscript
func get_tile(world_pos: Vector2i) -> GameTile:
    var chunk_coords = world_to_chunk(world_pos)
    var chunk = active_chunks.get(chunk_coords)

    if not chunk:
        chunk = get_chunk(chunk_coords)

    if chunk:
        var local_pos = world_pos - (chunk_coords * WorldChunk.CHUNK_SIZE)
        local_pos.x = clampi(local_pos.x, 0, WorldChunk.CHUNK_SIZE - 1)
        local_pos.y = clampi(local_pos.y, 0, WorldChunk.CHUNK_SIZE - 1)
        return chunk.get_tile(local_pos)

    # NEW: If frozen and chunk not available, return null (caller handles gracefully)
    if _chunk_ops_frozen:
        return null

    # Outside island bounds - return ocean tile
    return GameTile.create("water")
```

---

### ⚠️ HIGH PRIORITY ISSUE 3: Snapshot Timing vs Player Systems

**Problem**: The plan calls `prepare_turn_snapshot()` AFTER `_process_player_survival()` and `_process_ritual_channeling()`. These systems might affect entities or trigger chunk access.

**Example**: Ritual with AOE effect damaging nearby entities would modify `entities` array before snapshot.

**Recommended Fix**: Move snapshot to very start of Phase 1:
```gdscript
func advance_turn() -> void:
    player_turn_ended.emit()
    current_turn += 1

    # FREEZE AND SNAPSHOT FIRST (before any processing that might modify state)
    ChunkManager.freeze_chunk_operations()
    EntityManager.prepare_turn_snapshot()

    # THEN process everything else
    _update_time_of_day()
    _process_player_survival()
    _process_ritual_channeling()
    # ... etc
```

---

### ⚠️ MEDIUM PRIORITY ISSUE 4: Still 2 Array Duplicates, Not 1

**Problem**: The plan claims "3N → N array copies" but actually:
1. `entities.duplicate()` in `prepare_turn_snapshot()` - **N entities**
2. `player.active_summons.duplicate()` in consolidated loop - **M summons**

That's still 2 duplicates (albeit smaller than before).

**Actual Savings**: 3N → (N + M), where M is typically 0-5. Still an improvement, but claim is overstated.

**Future Optimization**: Process summons from entity snapshot instead of separate list (requires sorting or priority flag).

---

### ⚠️ MEDIUM PRIORITY ISSUE 5: Chunk Queue Unbounded Growth

**Problem**: If many entities try to access unloaded chunks, `_queued_loads` could grow very large. No limit or circuit breaker.

**Risk**: With 100+ entities all pathfinding across unloaded chunks, queue could have 1000+ duplicate entries.

**Recommended Fix**:
```gdscript
const MAX_QUEUED_CHUNKS: int = 50

func freeze_chunk_operations() -> void:
    _chunk_ops_frozen = true
    _queued_loads.clear()
    _queued_unloads.clear()

# In load_chunk() when frozen:
if _chunk_ops_frozen:
    if _queued_loads.size() < MAX_QUEUED_CHUNKS and chunk_coords not in _queued_loads:
        _queued_loads.append(chunk_coords)
    elif _queued_loads.size() >= MAX_QUEUED_CHUNKS:
        push_warning("[ChunkManager] Queue full, ignoring load for %v" % chunk_coords)
    # ... return cached or null
```

**Better Optimization**: Use Dictionary instead of Array for automatic deduplication:
```gdscript
var _queued_loads: Dictionary = {}  # Vector2i -> true
var _queued_unloads: Dictionary = {}

# In load_chunk:
if _chunk_ops_frozen:
    _queued_loads[chunk_coords] = true  # Automatically deduplicates
```

---

### ⚠️ MEDIUM PRIORITY ISSUE 6: Signal Dependency Chain Unknown

**Problem**: The plan defers all `chunk_loaded`/`chunk_unloaded` signals to Phase 3. We don't know what systems depend on these signals firing immediately.

**Risk**: ASCIIRenderer, FeatureManager, HazardManager might expect chunks to be available right after load signal.

**Recommended Action**: Audit all signal connections BEFORE implementation:
```bash
grep -r "chunk_loaded.connect" --include="*.gd"
grep -r "chunk_unloaded.connect" --include="*.gd"
```

Document all listeners and verify deferred execution is safe for each one.

---

### ⚠️ LOW PRIORITY ISSUE 7: Print Statement Performance

**Problem**: The plan adds even MORE print statements to already verbose turn loop (10+ prints per turn).

**Impact**: Console spam makes debugging harder, and `print()` has measurable performance cost in Godot.

**Recommendation**: Use debug flag:
```gdscript
const DEBUG_TURN_VERBOSE: bool = false  # Disable for production

func advance_turn() -> void:
    if DEBUG_TURN_VERBOSE:
        print("[TurnManager] === Starting turn %d ===" % (current_turn + 1))
```

Or remove most prints, keep only errors/warnings.

---

### ⚠️ LOW PRIORITY ISSUE 8: No Max Iteration Safeguard

**Problem**: Plan keeps player death as only emergency brake. What if enemy AI has infinite loop bug?

**Example**: Enemy pathfinding gets stuck trying to access unloaded chunks repeatedly.

**Recommendation**: Add iteration limit:
```gdscript
func process_entity_turns() -> void:
    const MAX_ENTITIES_PER_TURN: int = 1000  # Sanity check
    var processed = 0

    for entity in _entity_snapshot:
        processed += 1
        if processed > MAX_ENTITIES_PER_TURN:
            push_error("[EntityManager] EMERGENCY BRAKE: Processed %d entities!" % processed)
            break
        # ... process entity
```

---

### ⚠️ LOW PRIORITY ISSUE 9: Cross-Chunk Feature Interactions Not Tested

**Problem**: Test plan focuses on combat, but other cross-chunk scenarios exist:
- Harvesting resource in adjacent chunk
- Opening chest in adjacent chunk
- Triggering trap in adjacent chunk
- AOE spell effect across chunk boundary
- Farming/planting in adjacent chunk

**Recommendation**: Expand test cases to cover all player actions that access chunks.

---

### ⚠️ LOW PRIORITY ISSUE 10: Rollback Plan Incomplete

**Problem**: Rollback says "restore methods" but doesn't mention:
- Removing new methods (prepare_turn_snapshot, freeze/unfreeze)
- Removing new fields (_entity_snapshot, _chunk_ops_frozen, etc.)
- Reverting get_tile() fallback behavior

**Recommendation**: Create git branch before implementation:
```bash
git checkout -b feature/game-loop-simplification
git checkout -b backup/pre-simplification  # Safety branch
```

---

## ADDITIONAL RECOMMENDATIONS

### 🔧 Recommendation 1: Profile Before Optimizing

Add profiling to measure actual improvement:
```gdscript
func advance_turn() -> void:
    var profile_start = Time.get_ticks_usec()

    # ... do turn processing

    var total_time = Time.get_ticks_usec() - profile_start
    if total_time > 10000:  # Log if >10ms
        print("[Profile] Turn %d: %.2fms" % [current_turn, total_time/1000.0])
```

Gather baseline data for 100 turns before/after.

---

### 🔧 Recommendation 2: Spatial Indexing for Range Checks

**Current**: Every entity calculates Manhattan distance to player (N operations per turn).

**Optimization**: Only process entities in active chunks (automatically within range if chunks are 32x32 and range is 20):
```gdscript
# Only process entities in active chunks
for entity in _entity_snapshot:
    var entity_chunk = ChunkManagerClass.world_to_chunk(entity.position)
    if not _is_chunk_active_snapshot(entity_chunk):
        continue  # Skip - too far away

    # No explicit distance check needed!
```

**Savings**: Eliminates N distance calculations per turn.

---

## REVISED RISK ASSESSMENT

| Risk | Severity | Likelihood | Mitigation Status |
|------|----------|------------|-------------------|
| Player effects stop working | **CRITICAL** | High | Fix required before implementation |
| LOF sees through unloaded chunks | **CRITICAL** | High | Fix required before implementation |
| Signal listeners break | HIGH | Medium | Audit required before implementation |
| Chunk queue overflow | MEDIUM | Medium | Use Dictionary for deduplication |
| Performance regression | MEDIUM | Low | Profile before/after |
| Stale snapshot issues | LOW | Low | Acceptable - refreshes next turn |

---

## REVISED IMPLEMENTATION ORDER

### Phase 1: Infrastructure & Profiling (No Breaking Changes)
1. Add profiling to current system (baseline measurements)
2. Add freeze flags and queues to ChunkManager (inactive)
3. Add snapshot fields to EntityManager (unused)
4. Run tests - verify no behavior change

### Phase 2: Safety Checks (Non-Breaking Enhancements)
1. Modify get_tile() to return null when frozen (**Critical Fix #2**)
2. Modify is_tile_transparent() to handle null (already in plan)
3. Add chunk queue deduplication (use Dictionary)
4. Run tests - verify graceful degradation

### Phase 3: Player Effect Processing (Critical Dependency)
1. Add player DoT/effect processing to TurnManager (**Critical Fix #1**)
2. Run tests - verify player effects still work

### Phase 4: Consolidate Entity Loop (Main Change)
1. Add prepare_turn_snapshot() method
2. Rewrite process_entity_turns() with consolidated loop
3. **Keep old methods commented out as backup**
4. Run tests - verify all effects process correctly

### Phase 5: Activate Freezing (Enable Feature)
1. Add freeze/unfreeze calls to TurnManager
2. Move snapshot to start of turn (before player systems)
3. Run tests - **verify cross-chunk combat no longer freezes**
4. Profile - compare before/after performance
5. If successful, remove commented-out old methods

---

## CONCLUSION & VERDICT

**Plan Assessment**: ✅ **VIABLE BUT REQUIRES CRITICAL FIXES**

**Critical Fixes Required**:
1. ❌ **Must add player effect processing** - without this, player DoTs/buffs/debuffs stop working
2. ❌ **Must fix get_tile() fallback** - without this, players can see through walls
3. ⚠️ **Should audit signal dependencies** - verify deferred signals don't break systems

**Performance Claims**: Partially accurate. Actual improvement: 3N → (N + M) array copies, not 3N → N. Still worthwhile.

**Architecture**: Excellent. The 3-phase structure with chunk freezing is elegant and solves the root cause cleanly.

**Estimated Success Rate**:
- **With critical fixes**: 85% success, 15% minor issues requiring adjustment
- **Without fixes**: 40% success, 60% game-breaking bugs

**Recommendation**: ✅ **PROCEED WITH IMPLEMENTATION** after incorporating Critical Fixes #1 and #2.

**Revised Time Estimate**:
- Infrastructure + profiling: 45 minutes
- Safety checks + critical fixes: 1.5 hours
- Entity loop consolidation: 1 hour
- Testing and debugging: 2-3 hours
- **Total**: 5-6 hours

---

## Notes

- Chunk freezing is the key innovation - prevents signal cascade during entity processing
- Consolidating entity loops improves performance AND simplifies code
- Null tile handling provides graceful degradation when chunks not loaded
- Emergency brake (player death check) remains active throughout
- **CRITICAL**: Must add player effect processing and fix get_tile() fallback before implementation
- All existing features preserved (no breaking changes to game mechanics if fixes applied)
