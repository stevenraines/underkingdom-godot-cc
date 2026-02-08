# Refactor 12: Game Event Handlers

**Risk Level**: High
**Estimated Changes**: 1 new file, 1 file partially reduced
**Dependency**: Must complete Plan 11 first

---

## Goal

Extract EventBus signal handlers from `game.gd` into a dedicated `GameEventHandlers` class.

This is the second of three plans to decompose game.gd. Focus on:
- All `_on_*` signal handlers connected to EventBus
- Signal subscription management
- Event routing and response logic

---

## Current State

### scenes/game.gd EventBus Connections

game.gd connects to 60+ EventBus signals in `_ready()`:

```gdscript
EventBus.player_moved.connect(_on_player_moved)
EventBus.entity_moved.connect(_on_entity_moved)
EventBus.entity_died.connect(_on_entity_died)
EventBus.attack_performed.connect(_on_attack_performed)
EventBus.item_picked_up.connect(_on_item_picked_up)
EventBus.item_dropped.connect(_on_item_dropped)
EventBus.inventory_changed.connect(_on_inventory_changed)
EventBus.player_health_changed.connect(_on_player_health_changed)
EventBus.player_mana_changed.connect(_on_player_mana_changed)
EventBus.player_stamina_changed.connect(_on_player_stamina_changed)
EventBus.survival_warning.connect(_on_survival_warning)
EventBus.message_logged.connect(_on_message_logged)
EventBus.turn_advanced.connect(_on_turn_advanced)
EventBus.level_up_available.connect(_on_level_up_available)
# ... and 40+ more
```

Each connection has a corresponding handler method (~15-50 lines each).

---

## Implementation

### Step 1: Create systems/game_event_handlers.gd

```gdscript
class_name GameEventHandlers
extends RefCounted

## GameEventHandlers - Manages EventBus signal subscriptions for game scene
##
## Centralizes event handling logic extracted from game.gd.
## Provides cleaner separation between event routing and game logic.

# Callbacks to game.gd for actions that need scene access
signal request_render_update()
signal request_hud_update()
signal request_message_display(text: String)
signal request_full_render()

# Game references
var game_scene = null
var player: Player = null
var renderer = null


func _init() -> void:
	pass


## Initialize with game scene reference
func setup(scene, p: Player, rend) -> void:
	game_scene = scene
	player = p
	renderer = rend


## Connect all EventBus signals
func connect_signals() -> void:
	# Movement
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.entity_moved.connect(_on_entity_moved)

	# Combat
	EventBus.attack_performed.connect(_on_attack_performed)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.damage_dealt.connect(_on_damage_dealt)

	# Items
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_dropped.connect(_on_item_dropped)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.item_equipped.connect(_on_item_equipped)
	EventBus.item_unequipped.connect(_on_item_unequipped)

	# Player stats
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_mana_changed.connect(_on_player_mana_changed)
	EventBus.player_stamina_changed.connect(_on_player_stamina_changed)
	EventBus.player_stats_changed.connect(_on_player_stats_changed)
	EventBus.gold_changed.connect(_on_gold_changed)

	# Survival
	EventBus.survival_warning.connect(_on_survival_warning)
	EventBus.hunger_changed.connect(_on_hunger_changed)
	EventBus.thirst_changed.connect(_on_thirst_changed)
	EventBus.temperature_changed.connect(_on_temperature_changed)

	# Turn and time
	EventBus.turn_advanced.connect(_on_turn_advanced)
	EventBus.time_changed.connect(_on_time_changed)
	EventBus.day_changed.connect(_on_day_changed)

	# Map and world
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.tile_changed.connect(_on_tile_changed)
	EventBus.chunk_loaded.connect(_on_chunk_loaded)
	EventBus.chunk_unloaded.connect(_on_chunk_unloaded)

	# Features and hazards
	EventBus.feature_interacted.connect(_on_feature_interacted)
	EventBus.hazard_triggered.connect(_on_hazard_triggered)
	EventBus.trap_detected.connect(_on_trap_detected)

	# UI and feedback
	EventBus.message_logged.connect(_on_message_logged)
	EventBus.level_up_available.connect(_on_level_up_available)

	# Magic
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.ritual_performed.connect(_on_ritual_performed)
	EventBus.concentration_broken.connect(_on_concentration_broken)

	# Weather
	EventBus.weather_changed.connect(_on_weather_changed)


## Disconnect all signals (for cleanup)
func disconnect_signals() -> void:
	# Movement
	if EventBus.player_moved.is_connected(_on_player_moved):
		EventBus.player_moved.disconnect(_on_player_moved)
	# ... repeat for all signals


# =============================================================================
# MOVEMENT HANDLERS
# =============================================================================

func _on_player_moved(new_position: Vector2i) -> void:
	# Update FOV
	if player:
		player.update_fov()

	# Request render update
	request_render_update.emit()
	request_hud_update.emit()


func _on_entity_moved(entity: Entity, old_pos: Vector2i, new_pos: Vector2i) -> void:
	# Mark tiles dirty for rendering
	if renderer:
		renderer.mark_entity_dirty(old_pos)
		renderer.mark_entity_dirty(new_pos)


# =============================================================================
# COMBAT HANDLERS
# =============================================================================

func _on_attack_performed(attacker: Entity, defender: Entity, damage: int, hit: bool) -> void:
	if not hit:
		request_message_display.emit("%s misses %s!" % [attacker.display_name, defender.display_name])
		return

	var msg = "%s hits %s for %d damage!" % [attacker.display_name, defender.display_name, damage]
	request_message_display.emit(msg)

	# Flash effect could be triggered here
	if renderer and defender:
		renderer.flash_tile(defender.position, Color.RED)


func _on_entity_died(entity: Entity, killer: Entity) -> void:
	var msg = "%s has been slain" % entity.display_name
	if killer:
		msg += " by %s" % killer.display_name
	msg += "!"

	request_message_display.emit(msg)

	# Grant XP if player killed it
	if killer == player and entity is Enemy:
		var xp = entity.xp_value if "xp_value" in entity else 10
		player.gain_experience(xp)
		request_message_display.emit("Gained %d XP" % xp)

	request_render_update.emit()


func _on_damage_dealt(source: Entity, target: Entity, amount: int, damage_type: String) -> void:
	# Could show floating damage numbers, play sounds, etc.
	pass


# =============================================================================
# ITEM HANDLERS
# =============================================================================

func _on_item_picked_up(item: Item, entity: Entity) -> void:
	if entity == player:
		var msg = "Picked up %s" % item.display_name
		if item.stack_count > 1:
			msg += " (x%d)" % item.stack_count
		request_message_display.emit(msg)

	request_render_update.emit()


func _on_item_dropped(item: Item, position: Vector2i) -> void:
	request_message_display.emit("Dropped %s" % item.display_name)
	request_render_update.emit()


func _on_inventory_changed() -> void:
	request_hud_update.emit()


func _on_item_equipped(item: Item, slot: String) -> void:
	request_message_display.emit("Equipped %s" % item.display_name)
	request_hud_update.emit()


func _on_item_unequipped(item: Item, slot: String) -> void:
	request_message_display.emit("Unequipped %s" % item.display_name)
	request_hud_update.emit()


# =============================================================================
# PLAYER STAT HANDLERS
# =============================================================================

func _on_player_health_changed(current: int, maximum: int) -> void:
	request_hud_update.emit()

	# Low health warning
	if current <= maximum * 0.25:
		request_message_display.emit("Warning: Health critical!")


func _on_player_mana_changed(current: int, maximum: int) -> void:
	request_hud_update.emit()


func _on_player_stamina_changed(current: int, maximum: int) -> void:
	request_hud_update.emit()

	if current <= 10:
		request_message_display.emit("You're exhausted!")


func _on_player_stats_changed() -> void:
	request_hud_update.emit()


func _on_gold_changed(new_amount: int) -> void:
	request_hud_update.emit()


# =============================================================================
# SURVIVAL HANDLERS
# =============================================================================

func _on_survival_warning(warning_type: String, severity: String) -> void:
	var messages = {
		"hunger_mild": "You're getting hungry.",
		"hunger_moderate": "You're very hungry!",
		"hunger_severe": "You're starving!",
		"thirst_mild": "You're getting thirsty.",
		"thirst_moderate": "You're very thirsty!",
		"thirst_severe": "You're dying of thirst!",
		"cold_mild": "You're getting cold.",
		"cold_severe": "You're freezing!",
		"heat_mild": "You're getting hot.",
		"heat_severe": "You're overheating!",
	}

	var key = "%s_%s" % [warning_type, severity]
	if key in messages:
		request_message_display.emit(messages[key])


func _on_hunger_changed(value: float) -> void:
	request_hud_update.emit()


func _on_thirst_changed(value: float) -> void:
	request_hud_update.emit()


func _on_temperature_changed(value: float) -> void:
	request_hud_update.emit()


# =============================================================================
# TURN AND TIME HANDLERS
# =============================================================================

func _on_turn_advanced(turn_number: int) -> void:
	# Update any turn-based displays
	request_hud_update.emit()


func _on_time_changed(hour: int, minute: int) -> void:
	request_hud_update.emit()


func _on_day_changed(day: int) -> void:
	request_message_display.emit("A new day begins.")


# =============================================================================
# MAP HANDLERS
# =============================================================================

func _on_map_changed(new_map) -> void:
	request_full_render.emit()


func _on_tile_changed(position: Vector2i) -> void:
	if renderer:
		renderer.mark_terrain_dirty(position)


func _on_chunk_loaded(chunk_coords: Vector2i) -> void:
	request_render_update.emit()


func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
	# Cleanup handled by managers
	pass


# =============================================================================
# FEATURE AND HAZARD HANDLERS
# =============================================================================

func _on_feature_interacted(feature, entity: Entity) -> void:
	# Log interaction
	if feature and "name" in feature:
		request_message_display.emit("Interacted with %s" % feature.name)


func _on_hazard_triggered(hazard, entity: Entity, damage: int) -> void:
	if entity == player:
		var hazard_name = hazard.name if hazard and "name" in hazard else "trap"
		request_message_display.emit("You triggered a %s! (%d damage)" % [hazard_name, damage])


func _on_trap_detected(position: Vector2i, hazard_id: String) -> void:
	request_message_display.emit("You notice a trap!")
	if renderer:
		renderer.mark_terrain_dirty(position)


# =============================================================================
# UI HANDLERS
# =============================================================================

func _on_message_logged(text: String) -> void:
	request_message_display.emit(text)


func _on_level_up_available() -> void:
	request_message_display.emit("Level up available! Press 'L' to level up.")


# =============================================================================
# MAGIC HANDLERS
# =============================================================================

func _on_spell_cast(caster: Entity, spell, target) -> void:
	if caster == player:
		request_message_display.emit("Cast %s" % spell.name)
	request_render_update.emit()


func _on_ritual_performed(performer: Entity, ritual) -> void:
	if performer == player:
		request_message_display.emit("Performed ritual: %s" % ritual.name)


func _on_concentration_broken(entity: Entity, spell, reason: String) -> void:
	if entity == player:
		request_message_display.emit("Concentration broken: %s" % reason)


# =============================================================================
# WEATHER HANDLERS
# =============================================================================

func _on_weather_changed(weather_type: String) -> void:
	var weather_messages = {
		"clear": "The weather clears up.",
		"rain": "It starts to rain.",
		"storm": "A storm rolls in!",
		"snow": "Snow begins to fall.",
		"fog": "A thick fog settles in.",
	}

	if weather_type in weather_messages:
		request_message_display.emit(weather_messages[weather_type])

	request_render_update.emit()
```

---

### Step 2: Update scenes/game.gd

1. **Add GameEventHandlers instance**:
```gdscript
const GameEventHandlersClass = preload("res://systems/game_event_handlers.gd")

var event_handlers: GameEventHandlers = null
```

2. **Initialize in `_ready()`**:
```gdscript
func _ready() -> void:
	# ... existing initialization ...

	# Initialize event handlers
	event_handlers = GameEventHandlersClass.new()
	event_handlers.setup(self, player, renderer)

	# Connect handler signals to game methods
	event_handlers.request_render_update.connect(_on_request_render_update)
	event_handlers.request_hud_update.connect(_on_request_hud_update)
	event_handlers.request_message_display.connect(_on_request_message_display)
	event_handlers.request_full_render.connect(_on_request_full_render)

	# Connect EventBus signals
	event_handlers.connect_signals()
```

3. **Add thin wrapper methods**:
```gdscript
func _on_request_render_update() -> void:
	_render_entities()
	_render_ground_items()

func _on_request_hud_update() -> void:
	_update_hud()

func _on_request_message_display(text: String) -> void:
	_add_message(text)

func _on_request_full_render() -> void:
	_render_all()
```

4. **Remove old `_on_*` EventBus handlers** - now in GameEventHandlers.

---

## Files Summary

### New Files
- `systems/game_event_handlers.gd` (~400 lines)

### Modified Files
- `scenes/game.gd` - Reduced by ~800 lines

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Movement events
  - [ ] Player movement updates view
  - [ ] FOV updates on movement
- [ ] Combat events
  - [ ] Attack messages display
  - [ ] Death messages display
  - [ ] XP gain messages
- [ ] Item events
  - [ ] Pickup messages
  - [ ] Drop messages
  - [ ] Equip/unequip messages
- [ ] Stat changes
  - [ ] Health changes update HUD
  - [ ] Low health warning appears
  - [ ] Stamina exhaustion warning
- [ ] Survival events
  - [ ] Hunger warnings
  - [ ] Thirst warnings
  - [ ] Temperature warnings
- [ ] Turn/time events
  - [ ] Day change message
  - [ ] HUD updates on turn
- [ ] Map events
  - [ ] Map transition renders correctly
  - [ ] Chunk loading works
- [ ] Magic events
  - [ ] Spell cast messages
  - [ ] Concentration broken messages
- [ ] Weather events
  - [ ] Weather change messages
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- scenes/game.gd
rm systems/game_event_handlers.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
