# Refactor 13: Game Rendering Orchestrator

**Risk Level**: High
**Estimated Changes**: 1 new file, 1 file significantly reduced
**Dependencies**: Must complete Plans 11 and 12 first

---

## Goal

Extract rendering orchestration from `game.gd` into a dedicated `RenderingOrchestrator` class.

This is the final plan to decompose game.gd. Focus on:
- All `_render_*` methods
- Visibility and FOV coordination
- Light source management
- Dirty flag management
- Chunk rendering coordination

---

## Current State

### scenes/game.gd Rendering Code (~800 lines)

**Render Methods:**
- `_render_all()` - Full scene render
- `_render_map()` / `_render_terrain()` - Terrain tiles
- `_render_entities()` / `_render_entity_at()` - All entities
- `_render_ground_items()` - Items on ground
- `_render_features()` - Doors, chests, etc.
- `_render_hazards()` - Traps, etc.
- `_render_player()` - Player character

**Visibility Methods:**
- `_update_visibility()` - FOV calculation coordination
- `_apply_fog_of_war()` - FOW rendering

**Light Source Methods:**
- `_initialize_light_sources_for_map()` - Setup light sources
- `_update_dynamic_light_sources()` - Torch, campfire updates
- `_rebuild_enemy_light_cache()` - Enemy visibility from lights

**Dirty Flag Management:**
- `_mark_terrain_dirty()`
- `_mark_entity_dirty()`
- `_request_full_render()`

---

## Implementation

### Step 1: Create systems/rendering_orchestrator.gd

```gdscript
class_name RenderingOrchestrator
extends RefCounted

## RenderingOrchestrator - Coordinates game rendering
##
## Manages rendering pipeline, visibility, and light sources.
## Extracted from game.gd to improve organization.

# Renderer reference
var renderer = null

# Game references
var player: Player = null
var current_map = null

# Dirty tracking
var _terrain_dirty: bool = true
var _entities_dirty: bool = true
var _items_dirty: bool = true
var _full_render_requested: bool = true

# Light source tracking
var _static_light_sources: Array = []
var _dynamic_light_sources: Array = []


func _init() -> void:
	pass


## Setup with renderer and player
func setup(rend, p: Player) -> void:
	renderer = rend
	player = p


## Set current map reference
func set_map(map) -> void:
	current_map = map
	_full_render_requested = true
	_initialize_light_sources()


# =============================================================================
# RENDER REQUESTS
# =============================================================================

## Request full render (map change, etc.)
func request_full_render() -> void:
	_full_render_requested = true


## Mark terrain as needing re-render
func mark_terrain_dirty(position: Vector2i = Vector2i(-1, -1)) -> void:
	_terrain_dirty = true
	if renderer and position != Vector2i(-1, -1):
		renderer.mark_terrain_dirty(position)


## Mark entities as needing re-render
func mark_entities_dirty() -> void:
	_entities_dirty = true


## Mark ground items as needing re-render
func mark_items_dirty() -> void:
	_items_dirty = true


# =============================================================================
# MAIN RENDER
# =============================================================================

## Perform render (called each frame or on demand)
func render() -> void:
	if renderer == null or current_map == null:
		return

	# Full render if requested
	if _full_render_requested:
		_render_all()
		_full_render_requested = false
		_terrain_dirty = false
		_entities_dirty = false
		_items_dirty = false
		return

	# Incremental render
	if _terrain_dirty:
		_render_terrain()
		_terrain_dirty = false

	if _items_dirty:
		_render_ground_items()
		_items_dirty = false

	if _entities_dirty:
		_render_entities()
		_entities_dirty = false


## Full scene render
func _render_all() -> void:
	_update_visibility()
	_render_terrain()
	_render_features()
	_render_hazards()
	_render_ground_items()
	_render_entities()
	_render_player()
	_apply_fog_of_war()


# =============================================================================
# TERRAIN RENDERING
# =============================================================================

## Render terrain tiles
func _render_terrain() -> void:
	if renderer == null or current_map == null:
		return

	renderer.clear_terrain_layer()

	# Get visible area
	var visible_tiles = _get_visible_tiles()

	for pos in visible_tiles:
		var tile = current_map.get_tile_at(pos)
		if tile:
			renderer.render_terrain_tile(pos, tile)


## Get tiles visible to player
func _get_visible_tiles() -> Array[Vector2i]:
	if player == null:
		return []

	return player.get_visible_tiles()


# =============================================================================
# ENTITY RENDERING
# =============================================================================

## Render all entities
func _render_entities() -> void:
	if renderer == null:
		return

	renderer.clear_entity_layer()

	var visible_tiles = _get_visible_tiles()

	# Render enemies and NPCs
	for entity in EntityManager.entities:
		if entity.position in visible_tiles:
			_render_entity(entity)

	# Render summons
	if player and player.has_method("get_summons"):
		for summon in player.get_summons():
			if summon.position in visible_tiles:
				_render_entity(summon)


## Render single entity
func _render_entity(entity: Entity) -> void:
	if renderer == null or entity == null:
		return

	var symbol = entity.symbol if "symbol" in entity else "?"
	var color = entity.color if "color" in entity else Color.WHITE

	# Modify color for status effects
	if "is_summoned" in entity and entity.is_summoned:
		color = color.lerp(Color.CYAN, 0.3)

	renderer.render_entity(entity.position, symbol, color)


## Render player
func _render_player() -> void:
	if renderer == null or player == null:
		return

	var color = Color.WHITE

	# Status-based color modifications
	if player.hp <= player.max_hp * 0.25:
		color = Color.RED
	elif player.hp <= player.max_hp * 0.5:
		color = Color.YELLOW

	renderer.render_entity(player.position, "@", color)


# =============================================================================
# ITEM RENDERING
# =============================================================================

## Render ground items
func _render_ground_items() -> void:
	if renderer == null or current_map == null:
		return

	renderer.clear_item_layer()

	var visible_tiles = _get_visible_tiles()

	for pos in visible_tiles:
		var items = current_map.get_items_at(pos)
		if items.size() > 0:
			_render_ground_item(pos, items)


## Render item pile at position
func _render_ground_item(position: Vector2i, items: Array) -> void:
	if renderer == null:
		return

	# Show top item or pile indicator
	if items.size() == 1:
		var item = items[0]
		var symbol = item.symbol if "symbol" in item else "!"
		var color = item.color if "color" in item else Color.WHITE
		renderer.render_item(position, symbol, color)
	else:
		# Multiple items - show pile
		renderer.render_item(position, "&", Color.YELLOW)


# =============================================================================
# FEATURE RENDERING
# =============================================================================

## Render features (doors, chests, etc.)
func _render_features() -> void:
	if renderer == null:
		return

	var visible_tiles = _get_visible_tiles()

	for pos in FeatureManager.placed_features:
		if pos in visible_tiles:
			var feature = FeatureManager.placed_features[pos]
			_render_feature(pos, feature)


## Render single feature
func _render_feature(position: Vector2i, feature) -> void:
	if renderer == null or feature == null:
		return

	var symbol = feature.get("symbol", "?")
	var color = feature.get("color", Color.WHITE)

	# State-based symbol changes
	if feature.get("is_open", false):
		symbol = feature.get("open_symbol", "'")
	if feature.get("is_locked", false):
		color = Color.YELLOW

	renderer.render_feature(position, symbol, color)


# =============================================================================
# HAZARD RENDERING
# =============================================================================

## Render hazards (traps)
func _render_hazards() -> void:
	if renderer == null:
		return

	var visible_tiles = _get_visible_tiles()

	for pos in HazardManager.active_hazards:
		if pos in visible_tiles:
			var hazard = HazardManager.active_hazards[pos]
			_render_hazard(pos, hazard)


## Render single hazard
func _render_hazard(position: Vector2i, hazard) -> void:
	if renderer == null or hazard == null:
		return

	# Only render if detected
	if not hazard.get("detected", false):
		return

	var symbol = hazard.get("symbol", "^")
	var color = hazard.get("color", Color.RED)

	renderer.render_hazard(position, symbol, color)


# =============================================================================
# VISIBILITY AND FOG OF WAR
# =============================================================================

## Update visibility (FOV calculation)
func _update_visibility() -> void:
	if player == null:
		return

	player.update_fov()


## Apply fog of war effect
func _apply_fog_of_war() -> void:
	if renderer == null or current_map == null or player == null:
		return

	# Get explored but not visible tiles
	var explored = current_map.explored_tiles if "explored_tiles" in current_map else []
	var visible = _get_visible_tiles()

	for pos in explored:
		if pos not in visible:
			renderer.apply_fog_of_war(pos)


# =============================================================================
# LIGHT SOURCES
# =============================================================================

## Initialize light sources for current map
func _initialize_light_sources() -> void:
	_static_light_sources.clear()
	_dynamic_light_sources.clear()

	if current_map == null:
		return

	# Find static light sources (torches on walls, etc.)
	for pos in FeatureManager.placed_features:
		var feature = FeatureManager.placed_features[pos]
		if feature.get("emits_light", false):
			_static_light_sources.append({
				"position": pos,
				"radius": feature.get("light_radius", 3),
				"color": feature.get("light_color", Color.ORANGE)
			})

	# Dynamic sources handled separately (player torch, campfires)


## Update dynamic light sources
func update_light_sources() -> void:
	_dynamic_light_sources.clear()

	# Player torch
	if player and player.has_method("has_light_source"):
		if player.has_light_source():
			_dynamic_light_sources.append({
				"position": player.position,
				"radius": player.get_light_radius(),
				"color": Color.ORANGE
			})

	# Active campfires
	for pos in StructureManager.placed_structures:
		var structure = StructureManager.placed_structures[pos]
		if structure.get("type") == "campfire" and structure.get("is_active", false):
			_dynamic_light_sources.append({
				"position": pos,
				"radius": 5,
				"color": Color.ORANGE
			})


## Get all light sources
func get_all_light_sources() -> Array:
	var all_sources = _static_light_sources.duplicate()
	all_sources.append_array(_dynamic_light_sources)
	return all_sources


## Check if position is lit
func is_position_lit(position: Vector2i) -> bool:
	for source in get_all_light_sources():
		var dist = position.distance_to(source.position)
		if dist <= source.radius:
			return true
	return false


# =============================================================================
# UTILITY
# =============================================================================

## Center view on player
func center_view_on_player() -> void:
	if renderer == null or player == null:
		return

	if renderer.has_method("center_on"):
		renderer.center_on(player.position)


## Get render statistics (for debugging)
func get_render_stats() -> Dictionary:
	return {
		"terrain_dirty": _terrain_dirty,
		"entities_dirty": _entities_dirty,
		"items_dirty": _items_dirty,
		"full_render_pending": _full_render_requested,
		"static_lights": _static_light_sources.size(),
		"dynamic_lights": _dynamic_light_sources.size(),
	}
```

---

### Step 2: Update scenes/game.gd

1. **Add RenderingOrchestrator instance**:
```gdscript
const RenderingOrchestratorClass = preload("res://systems/rendering_orchestrator.gd")

var render_orchestrator: RenderingOrchestrator = null
```

2. **Initialize in `_ready()`**:
```gdscript
func _ready() -> void:
	# ... existing initialization ...

	# Initialize rendering orchestrator
	render_orchestrator = RenderingOrchestratorClass.new()
	render_orchestrator.setup(renderer, player)
```

3. **Update map changes** to use orchestrator:
```gdscript
func _on_map_loaded(map) -> void:
	render_orchestrator.set_map(map)
```

4. **Simplify render calls**:
```gdscript
# Before:
func _render_all() -> void:
	_update_visibility()
	_render_terrain()
	_render_features()
	# ... 50+ lines

# After:
func _render_all() -> void:
	render_orchestrator.render()
```

5. **Update `_process()` or render triggers**:
```gdscript
func _process(delta: float) -> void:
	# ... other processing ...
	render_orchestrator.render()
```

6. **Update dirty marking**:
```gdscript
# Before (in event handlers):
_mark_terrain_dirty(pos)

# After:
render_orchestrator.mark_terrain_dirty(pos)
```

7. **Remove old render methods** - now in RenderingOrchestrator:
- `_render_all()`
- `_render_terrain()`
- `_render_entities()`
- `_render_ground_items()`
- `_render_features()`
- `_render_hazards()`
- `_render_player()`
- `_update_visibility()`
- `_apply_fog_of_war()`
- `_initialize_light_sources_for_map()`
- `_update_dynamic_light_sources()`
- Dirty flag variables and methods

---

## Files Summary

### New Files
- `systems/rendering_orchestrator.gd` (~400 lines)

### Modified Files
- `scenes/game.gd` - Reduced from original 3,337 lines to ~1,000 lines

---

## Final game.gd Structure

After all three plans (11, 12, 13), game.gd should contain only:
- Scene initialization and setup
- Node references
- High-level game state management
- Delegation to UICoordinator, GameEventHandlers, RenderingOrchestrator
- Game loop coordination
- Save/load triggers

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Terrain rendering
  - [ ] Walls, floors render correctly
  - [ ] Water, grass, trees render
  - [ ] Dungeon tiles render
- [ ] Entity rendering
  - [ ] Player (@) renders
  - [ ] Enemies render with correct symbols
  - [ ] NPCs render correctly
  - [ ] Summons render (if any)
- [ ] Item rendering
  - [ ] Single items show symbol
  - [ ] Item piles show (&)
- [ ] Feature rendering
  - [ ] Doors (+ and ')
  - [ ] Chests (= and _)
  - [ ] Stairs (< and >)
- [ ] Hazard rendering
  - [ ] Detected traps visible
  - [ ] Undetected traps hidden
- [ ] Visibility
  - [ ] FOV works correctly
  - [ ] Fog of war on explored tiles
- [ ] Light sources
  - [ ] Torch illumination
  - [ ] Campfire illumination
- [ ] Dirty flag optimization
  - [ ] Partial renders work
  - [ ] Full render on map change
- [ ] Performance acceptable
  - [ ] No lag during movement
  - [ ] Smooth chunk transitions
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- scenes/game.gd
rm systems/rendering_orchestrator.gd
```

Or revert entire commit:
```bash
git revert HEAD
```

---

## Summary: game.gd Decomposition Complete

After Plans 11, 12, and 13:

| File | Lines |
|------|-------|
| scenes/game.gd (original) | 3,337 |
| scenes/game.gd (final) | ~1,000 |
| systems/ui_coordinator.gd | ~300 |
| systems/game_event_handlers.gd | ~400 |
| systems/rendering_orchestrator.gd | ~400 |

Total extracted: ~2,300 lines
Reduction: 70%
