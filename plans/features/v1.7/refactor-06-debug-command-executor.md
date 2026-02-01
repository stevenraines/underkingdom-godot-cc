# Refactor 06: Debug Command Executor

**Risk Level**: Low
**Estimated Changes**: 1 new file, 1 file significantly reduced

---

## Goal

Separate command execution logic from UI rendering in `debug_command_menu.gd` (2,203 lines).

Extract all `_do_*` methods (command execution) into a `DebugCommandExecutor` class, leaving the menu as pure UI.

---

## Current State

### debug_command_menu.gd
The file mixes:
- Tab container/menu UI management
- Navigation and input handling
- Command execution methods (`_do_give_gold()`, `_do_spawn_enemy()`, etc.)

### Methods to Extract
All methods that actually execute debug commands:
- `_do_give_gold(amount)`
- `_do_set_level(level)`
- `_do_set_health(hp, max_hp)`
- `_do_set_mana(mp, max_mp)`
- `_do_set_stamina(sp, max_sp)`
- `_do_modify_stat(stat_name, value)`
- `_do_modify_skill(skill_name, value)`
- `_do_spawn_enemy(enemy_id, position)`
- `_do_spawn_hazard(hazard_id, position)`
- `_do_spawn_feature(feature_id, position)`
- `_do_give_item(item_id, quantity)`
- `_do_teleport_to(position)`
- `_do_set_time(hour, minute)`
- `_do_set_date(day, month, year)`
- `_do_set_weather(weather_type)`
- `_do_set_season(season)`
- `_do_reveal_map()`
- `_do_toggle_god_mode()`
- And similar execution methods...

---

## Implementation

### Step 1: Create systems/debug_command_executor.gd

```gdscript
class_name DebugCommandExecutor
extends RefCounted

## DebugCommandExecutor - Executes debug commands
##
## Separated from DebugCommandMenu to isolate command logic from UI.
## All methods are static for easy access without needing an instance.


# =============================================================================
# CURRENCY AND RESOURCES
# =============================================================================

## Give gold to the player
static func give_gold(player: Player, amount: int) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	player.gold += amount
	EventBus.gold_changed.emit(player.gold)
	return {"success": true, "message": "Gave %d gold (total: %d)" % [amount, player.gold]}


## Set player gold to exact amount
static func set_gold(player: Player, amount: int) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	player.gold = amount
	EventBus.gold_changed.emit(player.gold)
	return {"success": true, "message": "Set gold to %d" % amount}


# =============================================================================
# PLAYER STATS
# =============================================================================

## Set player level
static func set_level(player: Player, level: int) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	level = clampi(level, 1, 50)
	player.level = level
	EventBus.player_leveled_up.emit(level)
	return {"success": true, "message": "Set level to %d" % level}


## Set player health
static func set_health(player: Player, current: int, maximum: int = -1) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	if maximum > 0:
		player.max_hp = maximum
	player.hp = mini(current, player.max_hp)
	EventBus.player_health_changed.emit(player.hp, player.max_hp)
	return {"success": true, "message": "Set HP to %d/%d" % [player.hp, player.max_hp]}


## Set player mana
static func set_mana(player: Player, current: int, maximum: int = -1) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	if maximum > 0:
		player.max_mp = maximum
	player.mp = mini(current, player.max_mp)
	EventBus.player_mana_changed.emit(player.mp, player.max_mp)
	return {"success": true, "message": "Set MP to %d/%d" % [player.mp, player.max_mp]}


## Set player stamina
static func set_stamina(player: Player, current: int, maximum: int = -1) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	if maximum > 0:
		player.max_stamina = maximum
	player.stamina = mini(current, player.max_stamina)
	EventBus.player_stamina_changed.emit(player.stamina, player.max_stamina)
	return {"success": true, "message": "Set Stamina to %d/%d" % [player.stamina, player.max_stamina]}


## Modify an attribute
static func modify_attribute(player: Player, attr_name: String, value: int) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	if not attr_name in player.attributes:
		return {"success": false, "message": "Unknown attribute: %s" % attr_name}

	player.attributes[attr_name] = value
	EventBus.player_stats_changed.emit()
	return {"success": true, "message": "Set %s to %d" % [attr_name, value]}


## Modify a skill
static func modify_skill(player: Player, skill_name: String, value: int) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	if not skill_name in player.skills:
		return {"success": false, "message": "Unknown skill: %s" % skill_name}

	player.skills[skill_name] = value
	EventBus.player_stats_changed.emit()
	return {"success": true, "message": "Set %s to %d" % [skill_name, value]}


# =============================================================================
# SPAWNING
# =============================================================================

## Spawn an enemy at position (or near player if position is ZERO)
static func spawn_enemy(enemy_id: String, position: Vector2i = Vector2i.ZERO) -> Dictionary:
	var definition = EntityManager.get_enemy_definition(enemy_id)
	if definition == null:
		return {"success": false, "message": "Unknown enemy: %s" % enemy_id}

	var spawn_pos = position
	if spawn_pos == Vector2i.ZERO:
		# Spawn near player
		var player = EntityManager.player
		if player:
			spawn_pos = _find_nearby_empty_position(player.position)

	if spawn_pos == Vector2i.ZERO:
		return {"success": false, "message": "No valid spawn position"}

	var enemy = EntityManager.spawn_enemy(enemy_id, spawn_pos)
	if enemy:
		return {"success": true, "message": "Spawned %s at %s" % [enemy_id, spawn_pos]}
	return {"success": false, "message": "Failed to spawn enemy"}


## Spawn a hazard at position
static func spawn_hazard(hazard_id: String, position: Vector2i) -> Dictionary:
	var result = HazardManager.place_hazard(hazard_id, position)
	if result:
		return {"success": true, "message": "Placed %s at %s" % [hazard_id, position]}
	return {"success": false, "message": "Failed to place hazard"}


## Spawn a feature at position
static func spawn_feature(feature_id: String, position: Vector2i) -> Dictionary:
	var result = FeatureManager.place_feature(feature_id, position)
	if result:
		return {"success": true, "message": "Placed %s at %s" % [feature_id, position]}
	return {"success": false, "message": "Failed to place feature"}


# =============================================================================
# ITEMS
# =============================================================================

## Give item to player
static func give_item(player: Player, item_id: String, quantity: int = 1) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	var item = ItemManager.create_item(item_id)
	if item == null:
		return {"success": false, "message": "Unknown item: %s" % item_id}

	if item.stackable:
		item.stack_count = quantity

	var added = player.inventory.add_item(item)
	if added:
		EventBus.inventory_changed.emit()
		return {"success": true, "message": "Gave %dx %s" % [quantity, item.display_name]}
	return {"success": false, "message": "Inventory full"}


## Clear player inventory
static func clear_inventory(player: Player) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	var count = player.inventory.items.size()
	player.inventory.items.clear()
	EventBus.inventory_changed.emit()
	return {"success": true, "message": "Cleared %d items" % count}


# =============================================================================
# TELEPORTATION
# =============================================================================

## Teleport player to position
static func teleport_to(player: Player, position: Vector2i) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	player.position = position
	EventBus.player_moved.emit(position)
	return {"success": true, "message": "Teleported to %s" % position}


## Teleport player to town
static func teleport_to_town(player: Player) -> Dictionary:
	var town_pos = TownManager.get_town_center()
	if town_pos == Vector2i.ZERO:
		return {"success": false, "message": "No town found"}
	return teleport_to(player, town_pos)


## Teleport player to dungeon entrance
static func teleport_to_dungeon(player: Player, dungeon_id: String = "") -> Dictionary:
	var entrance = DungeonManager.get_nearest_entrance(player.position if player else Vector2i.ZERO)
	if entrance == Vector2i.ZERO:
		return {"success": false, "message": "No dungeon entrance found"}
	return teleport_to(player, entrance)


# =============================================================================
# TIME AND WEATHER
# =============================================================================

## Set game time
static func set_time(hour: int, minute: int = 0) -> Dictionary:
	hour = clampi(hour, 0, 23)
	minute = clampi(minute, 0, 59)
	CalendarManager.set_time(hour, minute)
	return {"success": true, "message": "Set time to %02d:%02d" % [hour, minute]}


## Set game date
static func set_date(day: int, month: int, year: int) -> Dictionary:
	CalendarManager.set_date(day, month, year)
	return {"success": true, "message": "Set date to %d/%d/%d" % [day, month, year]}


## Set weather
static func set_weather(weather_type: String) -> Dictionary:
	WeatherManager.set_weather(weather_type)
	return {"success": true, "message": "Set weather to %s" % weather_type}


## Set season
static func set_season(season: String) -> Dictionary:
	CalendarManager.set_season(season)
	return {"success": true, "message": "Set season to %s" % season}


# =============================================================================
# MAP AND VISIBILITY
# =============================================================================

## Reveal entire map
static func reveal_map() -> Dictionary:
	if MapManager.current_map:
		MapManager.current_map.reveal_all()
		return {"success": true, "message": "Map revealed"}
	return {"success": false, "message": "No current map"}


## Toggle fog of war
static func toggle_fog_of_war(enabled: bool) -> Dictionary:
	GameConfig.fog_of_war_enabled = enabled
	return {"success": true, "message": "Fog of war %s" % ("enabled" if enabled else "disabled")}


# =============================================================================
# CHEAT MODES
# =============================================================================

## Toggle god mode (invincibility)
static func toggle_god_mode(player: Player) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	player.god_mode = not player.god_mode
	return {"success": true, "message": "God mode %s" % ("enabled" if player.god_mode else "disabled")}


## Toggle no-clip mode
static func toggle_noclip(player: Player) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	player.noclip = not player.noclip
	return {"success": true, "message": "No-clip %s" % ("enabled" if player.noclip else "disabled")}


## Full heal player
static func full_heal(player: Player) -> Dictionary:
	if player == null:
		return {"success": false, "message": "No player"}

	player.hp = player.max_hp
	player.mp = player.max_mp
	player.stamina = player.max_stamina
	EventBus.player_health_changed.emit(player.hp, player.max_hp)
	EventBus.player_mana_changed.emit(player.mp, player.max_mp)
	EventBus.player_stamina_changed.emit(player.stamina, player.max_stamina)
	return {"success": true, "message": "Fully healed"}


# =============================================================================
# HELPERS
# =============================================================================

## Find an empty position near the given position
static func _find_nearby_empty_position(center: Vector2i, max_radius: int = 5) -> Vector2i:
	var map = MapManager.current_map
	if map == null:
		return Vector2i.ZERO

	for radius in range(1, max_radius + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var pos = center + Vector2i(dx, dy)
				if map.is_walkable(pos) and not EntityManager.get_entity_at(pos):
					return pos

	return Vector2i.ZERO
```

---

### Step 2: Update ui/debug_command_menu.gd

1. **Add preload** at top:
```gdscript
const DebugCommandExecutorClass = preload("res://systems/debug_command_executor.gd")
```

2. **Replace `_do_*` method calls** with executor calls:

```gdscript
# Before:
func _on_give_gold_confirmed(amount: int) -> void:
	_do_give_gold(amount)
	_show_confirmation("Gave %d gold" % amount)

func _do_give_gold(amount: int) -> void:
	if player:
		player.gold += amount
		EventBus.gold_changed.emit(player.gold)

# After:
func _on_give_gold_confirmed(amount: int) -> void:
	var result = DebugCommandExecutorClass.give_gold(player, amount)
	_show_confirmation(result.message)
```

3. **Remove all `_do_*` methods** - they're now in the executor.

4. **Update all command handlers** to use the executor pattern.

---

## Files Summary

### New Files
- `systems/debug_command_executor.gd` (~300 lines)

### Modified Files
- `ui/debug_command_menu.gd` - Reduced from 2,203 to ~800 lines

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Open debug menu (F12)
- [ ] Test gold commands
  - [ ] Give gold
  - [ ] Set gold
- [ ] Test stat commands
  - [ ] Set level
  - [ ] Set HP/MP/Stamina
  - [ ] Modify attributes
  - [ ] Modify skills
- [ ] Test spawn commands
  - [ ] Spawn enemy
  - [ ] Spawn hazard
  - [ ] Spawn feature
- [ ] Test item commands
  - [ ] Give item
  - [ ] Clear inventory
- [ ] Test teleport commands
  - [ ] Teleport to position
  - [ ] Teleport to town
- [ ] Test time/weather commands
  - [ ] Set time
  - [ ] Set date
  - [ ] Set weather
  - [ ] Set season
- [ ] Test cheat modes
  - [ ] God mode toggle
  - [ ] Reveal map
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- ui/debug_command_menu.gd
rm systems/debug_command_executor.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
