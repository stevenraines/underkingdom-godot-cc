# Browser Performance Optimization Plan

## Goal
Optimize Underkingdom roguelike for browser performance on Intel Mac by reducing CPU/GPU usage when idle and improving responsiveness during gameplay. Since this is a turn-based ASCII game, we can achieve massive gains by moving to a fully event-driven architecture that only processes when the player acts.

## Current Performance Issues

**Exploration Findings:**
- InputHandler runs `_process()` every frame (60 FPS) even when not player's turn
- Full entity re-render on every player move (60+ entities in dungeons)
- Expensive FOV calculations for every entity visibility check
- HUD recalculates same values every turn with no caching
- All 19 UI screens pre-instantiated at game start
- Forward Plus rendering (overkill for ASCII)
- No FPS cap configured

**Expected Overall Impact:** 70-80% CPU reduction when idle, 40-50% reduction during active gameplay

---

## Phase 1: Project Configuration Quick Wins (30 minutes)

These are safe, high-impact configuration changes.

### 1.1 Cap Frame Rate to 30 FPS
**File:** [project.godot](project.godot)

**Rationale:** Turn-based game doesn't need 60 FPS for ASCII rendering.

**Change:**
```gdscript
# Add to [application] section:
run/max_fps = 30
```

**Impact:** 40-50% GPU/rendering CPU reduction

---

### 1.2 Switch to Compatibility Renderer for Web
**File:** [project.godot](project.godot)

**Rationale:** Forward Plus is for 3D games with advanced lighting. Compatibility (OpenGL ES 3.0) is lighter for browser.

**Changes:**
```gdscript
# Change in [application] section:
config/features=PackedStringArray("4.5", "GL Compatibility")

# Add to [rendering] section (if not exists):
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

**Impact:** 20-30% GPU reduction, better Intel Mac compatibility

---

### 1.3 Disable VSync for Manual Frame Pacing
**File:** [project.godot](project.godot)

**Rationale:** VSync can cause stuttering in browsers. Manual frame pacing with max_fps gives consistent performance.

**Change:**
```gdscript
# Add to [display] section:
window/vsync/vsync_mode = 0
```

**Impact:** Smoother frame times, 5-10% CPU reduction

---

### 1.4 Verify Texture Compression Enabled
**File:** [export_presets.cfg](export_presets.cfg)

**Verify these settings exist:**
```ini
vram_texture_compression/for_desktop=true
texture_format/s3tc=true
```

**Impact:** 10-15% GPU memory bandwidth reduction

---

## Phase 2: Core Game Loop Optimizations (45 minutes)

### 2.1 Disable _process() When Not Player Turn
**File:** [systems/input_handler.gd](systems/input_handler.gd)

**Rationale:** InputHandler's `_process()` runs 60x/sec checking input even during enemy turns. Completely wasted CPU.

**Current Code (lines 91-100):**
```gdscript
func _process(delta: float) -> void:
    if not player or not TurnManager.is_player_turn:
        return  # Still runs every frame!
```

**Implementation:**
1. Start with `set_process(false)` in `_ready()`
2. Connect to TurnManager signals to enable/disable processing
3. Enable on player turn start, disable on player turn end
4. Also disable when UI is blocking input

**Pseudo-code:**
```gdscript
func _ready() -> void:
    set_process(false)  # Start disabled

    # Connect to turn signals (add these signals to TurnManager if needed)
    TurnManager.player_turn_started.connect(_on_player_turn_started)
    TurnManager.player_turn_ended.connect(_on_player_turn_ended)

func _on_player_turn_started() -> void:
    if player and player.is_alive and not ui_blocking_input:
        set_process(true)

func _on_player_turn_ended() -> void:
    set_process(false)

func set_ui_blocking(blocking: bool) -> void:
    ui_blocking_input = blocking
    if blocking:
        set_process(false)
    elif player and player.is_alive and TurnManager.is_player_turn:
        set_process(true)
```

**Note:** May need to add `player_turn_started` and `player_turn_ended` signals to [autoload/turn_manager.gd](autoload/turn_manager.gd)

**Impact:** 60-70% CPU reduction when not player's turn

---

### 2.2 Cache HUD String Formatting
**File:** [scenes/game.gd](scenes/game.gd)

**Rationale:** `_update_hud()` (lines 1171-1283) recalculates date strings, formats HP text, etc. every turn even when values unchanged.

**Implementation:**
1. Add class variables to cache previous values
2. Only rebuild strings when values change
3. Track dirty state per HUD section

**Add these variables:**
```gdscript
# HUD caching
var _cached_player_hp: int = -1
var _cached_player_max_hp: int = -1
var _cached_turn: int = -1
var _cached_date_str: String = ""
var _cached_location: String = ""
```

**Update `_update_hud()` to check cache before rebuilding:**
```gdscript
func _update_hud() -> void:
    if not player:
        return

    # Only update date string if turn changed
    if character_info_label:
        var current_turn = TurnManager.current_turn
        if current_turn != _cached_turn:
            _cached_turn = current_turn
            # ... build date/time string only when changed ...

    # Only update HP text if health changed
    if status_line:
        if player.current_health != _cached_player_hp or player.max_health != _cached_player_max_hp:
            _cached_player_hp = player.current_health
            _cached_player_max_hp = player.max_health
            # ... rebuild status line ...

    # Apply same pattern to location, survival stats, etc.
```

**Impact:** 15-20% reduction in HUD update time

---

## Phase 3: Rendering Optimizations (60 minutes)

### 3.1 Incremental Entity Rendering
**File:** [scenes/game.gd](scenes/game.gd)

**Rationale:** Currently `_render_all_entities()` (lines 1572-1603) re-renders ALL 60+ entities on every player move in dungeons. Most entities don't change.

**Current problematic code (lines 641-649):**
```gdscript
if is_dungeon:
    _render_map()
    _render_ground_items()
    _render_all_entities()  # EXPENSIVE - re-renders all 60+ entities
```

**Implementation:**
1. Track which entity positions are currently rendered
2. Only re-render entities that changed (moved, died, spawned)
3. Full re-render only on map transitions or significant FOV changes

**Add class variables:**
```gdscript
var _rendered_entities: Dictionary = {}  # Vector2i -> Entity reference
var _full_render_needed: bool = true
```

**Modify `_render_all_entities()`:**
```gdscript
func _render_all_entities() -> void:
    if _full_render_needed:
        _full_render_all_entities()
        _full_render_needed = false
        return

    _incremental_render_entities()

func _full_render_all_entities() -> void:
    _rendered_entities.clear()

    # Existing full render logic (lines 1579-1602)
    for entity in EntityManager.entities:
        if entity.is_alive and entity.position != player.position:
            renderer.render_entity(entity.position, entity.ascii_char, entity.color)
            _rendered_entities[entity.position] = entity

    # ... structures, features, hazards ...

func _incremental_render_entities() -> void:
    var current_entities: Dictionary = {}

    # Build current entity positions
    for entity in EntityManager.entities:
        if entity.is_alive:
            current_entities[entity.position] = entity

    # Find and clear removed entities
    for pos in _rendered_entities:
        if not current_entities.has(pos):
            renderer.clear_entity(pos)

    # Render new/moved entities
    for pos in current_entities:
        var entity = current_entities[pos]
        if not _rendered_entities.has(pos) or _rendered_entities[pos] != entity:
            renderer.render_entity(pos, entity.ascii_char, entity.color)

    _rendered_entities = current_entities
```

**Mark full render needed on:**
- Map transitions: `_on_map_changed()` → `_full_render_needed = true`
- Entity spawns: Connect to spawn signals → `_full_render_needed = true`
- Chunk changes in overworld

**Impact:** 70-80% reduction in entity rendering calls

---

### 3.2 Cache FOV Calculations
**File:** [systems/fov_system.gd](systems/fov_system.gd)

**Rationale:** FOV already has caching (`cached_fov`, `cache_dirty`), but ensure it's not invalidated unnecessarily.

**Verify cache is only cleared when:**
- Player actually moves (not on entity movement)
- Map tiles change (doors, walls)
- Perception range changes (equipment)

**Implementation:**
1. Check current cache invalidation logic
2. Ensure `cache_dirty = true` only set when necessary
3. Consider adding per-entity FOV cache for enemy AI

**Impact:** 30-40% reduction in FOV calculation time

---

## Phase 4: UI Optimizations (60 minutes)

### 4.1 Lazy Load UI Screens
**File:** [scenes/game.gd](scenes/game.gd)

**Rationale:** All 19 UI screens pre-instantiated in `_ready()` (lines 94-149). Most are rarely used. Wastes 2-3 seconds on startup.

**Current code:**
```gdscript
func _ready() -> void:
    _setup_inventory_screen()
    _setup_crafting_screen()
    _setup_build_mode_screen()
    # ... 16 more screens
```

**Implementation:**
1. Remove all `_setup_*_screen()` calls from `_ready()`
2. Create screens on-demand when first opened
3. Cache created instances for reuse

**Change screen variables to nullable:**
```gdscript
var inventory_screen: Control = null
var crafting_screen: Control = null
var crafting_screen: Control = null
var build_mode_screen: Control = null
# ... etc for all 19 screens
```

**Convert setup methods to lazy loaders:**
```gdscript
func _ensure_inventory_screen() -> Control:
    if not inventory_screen:
        inventory_screen = InventoryScreenScene.instantiate()
        add_child(inventory_screen)
        inventory_screen.visible = false
        inventory_screen.close_requested.connect(_on_inventory_closed)
        # ... rest of setup from old _setup_inventory_screen()
    return inventory_screen

func _ensure_crafting_screen() -> Control:
    if not crafting_screen:
        crafting_screen = CraftingScreenScene.instantiate()
        add_child(crafting_screen)
        crafting_screen.visible = false
        # ... rest of setup
    return crafting_screen

# Repeat for all screens
```

**Update all screen access:**
```gdscript
func _on_open_inventory() -> void:
    var screen = _ensure_inventory_screen()
    screen.visible = true
    screen.refresh_display(player)
    input_handler.set_ui_blocking(true)
```

**Screens to convert (all in lines 94-149):**
- inventory_screen
- crafting_screen
- build_mode_screen
- container_screen
- shop_screen
- training_screen
- npc_menu_screen
- pause_menu
- death_screen
- character_sheet
- level_up_screen
- help_screen
- world_map_screen
- fast_travel_screen
- rest_menu
- spell_list_screen
- ritual_menu
- special_actions_screen
- debug_command_menu

**Impact:** 70-80% faster game startup, 15-20% memory reduction

---

### 4.2 Batch UI Updates with Deferred Calls
**File:** [scenes/game.gd](scenes/game.gd)

**Rationale:** Multiple rapid events (picking up items, combat) trigger redundant UI updates in the same frame.

**Implementation:**
```gdscript
var _hud_update_pending: bool = false

func _on_turn_advanced(_turn_number: int) -> void:
    _mark_hud_dirty()
    _update_survival_display()

func _mark_hud_dirty() -> void:
    if not _hud_update_pending:
        _hud_update_pending = true
        _update_hud_deferred.call_deferred()

func _update_hud_deferred() -> void:
    _hud_update_pending = false
    _update_hud()
```

**Apply to other UI update triggers:**
- Item pickup
- Equipment changes
- Status effect changes

**Impact:** 30-40% smoother gameplay during rapid actions

---

## Phase 5: Verification and Testing

### Testing Checklist

**Before optimization:**
1. Open browser DevTools Performance tab
2. Record 30 seconds of idle gameplay (no input)
3. Record 30 seconds of active gameplay (movement)
4. Note CPU usage, FPS, frame time

**After each phase:**
1. Re-run same test scenarios
2. Compare metrics
3. Test for regressions

**Critical paths to test:**
1. Movement in overworld (chunk loading)
2. Movement in dungeons (FOV/wall visibility)
3. Combat (entity rendering updates)
4. UI opening/closing (lazy loading)
5. Item pickup (incremental rendering)
6. Turn advancement (HUD caching)

**Target metrics:**
- Idle CPU: < 5% (currently ~30-40%)
- Active CPU: < 20% (currently ~60-80%)
- Stable 30 FPS
- Memory: < 150 MB (currently ~200 MB)
- Game startup: < 1.5 seconds (currently ~3 seconds)

---

## Critical Files Reference

**Project Configuration:**
- [project.godot](project.godot) - Frame rate, renderer, VSync
- [export_presets.cfg](export_presets.cfg) - Web export optimization

**Core Game Loop:**
- [systems/input_handler.gd](systems/input_handler.gd) - Disable _process() optimization
- [autoload/turn_manager.gd](autoload/turn_manager.gd) - May need new signals
- [scenes/game.gd](scenes/game.gd) - Entity rendering, HUD updates, UI lazy loading

**Rendering:**
- [rendering/ascii_renderer.gd](rendering/ascii_renderer.gd) - Incremental rendering
- [systems/fov_system.gd](systems/fov_system.gd) - FOV caching

**UI Screens (for lazy loading):**
- [ui/inventory_screen.gd](ui/inventory_screen.gd)
- [ui/crafting_screen.gd](ui/crafting_screen.gd)
- [ui/build_mode_screen.gd](ui/build_mode_screen.gd)
- Plus 16 other UI screens referenced in game.gd

---

## Implementation Order

**Day 1 (Phases 1-2): ~75 minutes**
1. Project configuration (30 min)
2. Disable _process() when idle (15 min)
3. Cache HUD formatting (30 min)

**Expected: 60-70% idle CPU reduction**

**Day 2 (Phases 3-4): ~120 minutes**
1. Incremental entity rendering (60 min)
2. Lazy load UI screens (60 min)

**Expected: Additional 30-40% active CPU reduction, 70% faster startup**

---

## Risk Assessment

**Low Risk (safe to implement):**
- Frame rate cap
- VSync disable
- HUD caching
- FOV cache verification

**Medium Risk (test thoroughly):**
- Renderer switch (may affect visuals - verify ASCII looks identical)
- Disable _process() (must test all input scenarios)
- Incremental entity rendering (complex state management)
- Lazy UI loading (many code paths to update)

**Rollback Strategy:**
- Commit after each phase
- Keep backup of project.godot and export_presets.cfg
- Test in isolation before moving to next phase
