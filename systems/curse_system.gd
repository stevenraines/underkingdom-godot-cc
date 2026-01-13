class_name CurseSystem
extends RefCounted

## CurseSystem - Handles cursed scroll effects and curse removal
##
## Cursed scrolls trigger random negative effects on use.
## Cursed equipment cannot be unequipped without Remove Curse.

# Cursed scroll effect definitions
const CURSED_SCROLL_EFFECTS = [
	{
		"id": "curse_blindness",
		"name": "Blindness",
		"message": "You are blinded!",
		"duration": 20
	},
	{
		"id": "curse_weakness",
		"name": "Weakness",
		"message": "Your strength fades!",
		"duration": 50,
		"stat": "STR",
		"modifier": -3
	},
	{
		"id": "curse_confusion",
		"name": "Confusion",
		"message": "Your mind reels in confusion!",
		"duration": 15
	},
	{
		"id": "curse_mana_drain",
		"name": "Mana Drain",
		"message": "Your magical energy is drained!"
	},
	{
		"id": "curse_summon_enemy",
		"name": "Summon Enemy",
		"message": "Something emerges from the shadows!"
	},
	{
		"id": "curse_teleport",
		"name": "Teleport",
		"message": "You are teleported away!"
	},
	{
		"id": "curse_hunger",
		"name": "Hunger",
		"message": "Terrible hunger gnaws at you!",
		"hunger_drain": 50
	},
	{
		"id": "curse_aging",
		"name": "Aging",
		"message": "You feel your life force drain away...",
		"permanent": true
	}
]


## Use a cursed scroll, triggering a random curse effect
static func use_cursed_scroll(player, scroll) -> Dictionary:
	var result = {
		"success": true,
		"consumed": true,
		"message": ""
	}

	# Select random effect
	var effect = CURSED_SCROLL_EFFECTS[randi() % CURSED_SCROLL_EFFECTS.size()]

	EventBus.message_logged.emit("The scroll crumbles to dust! A curse takes hold!", Color.DARK_RED)

	# Apply the effect
	match effect.id:
		"curse_blindness":
			_apply_blindness(player, effect)
		"curse_weakness":
			_apply_weakness(player, effect)
		"curse_confusion":
			_apply_confusion(player, effect)
		"curse_mana_drain":
			_apply_mana_drain(player, effect)
		"curse_summon_enemy":
			_apply_summon_enemy(player, effect)
		"curse_teleport":
			_apply_teleport(player, effect)
		"curse_hunger":
			_apply_hunger(player, effect)
		"curse_aging":
			_apply_aging(player, effect)

	EventBus.message_logged.emit(effect.message, Color.RED)
	EventBus.cursed_scroll_used.emit(player, effect.name)

	return result


## Apply blindness curse (reduces vision range)
static func _apply_blindness(player, effect: Dictionary) -> void:
	var curse_effect = {
		"id": "curse_blindness",
		"type": "debuff",
		"remaining_duration": effect.duration,
		"modifiers": {"vision_range": -10}
	}
	if player.has_method("add_magical_effect"):
		player.add_magical_effect(curse_effect)


## Apply weakness curse (reduces STR)
static func _apply_weakness(player, effect: Dictionary) -> void:
	var curse_effect = {
		"id": "curse_weakness",
		"type": "debuff",
		"remaining_duration": effect.duration,
		"modifiers": {effect.stat: effect.modifier}
	}
	if player.has_method("add_magical_effect"):
		player.add_magical_effect(curse_effect)


## Apply confusion curse (randomizes movement)
static func _apply_confusion(player, effect: Dictionary) -> void:
	var curse_effect = {
		"id": "curse_confusion",
		"type": "confusion",
		"remaining_duration": effect.duration,
		"modifiers": {}
	}
	if player.has_method("add_magical_effect"):
		player.add_magical_effect(curse_effect)


## Apply mana drain curse (empties mana)
static func _apply_mana_drain(player, _effect: Dictionary) -> void:
	if player.get("survival"):
		player.survival.mana = 0
		EventBus.mana_changed.emit(player.survival.mana, 0, player.survival.max_mana)


## Apply enemy summon curse (spawns hostile creature)
static func _apply_summon_enemy(player, _effect: Dictionary) -> void:
	# Find adjacent walkable position
	var offsets = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	for offset in offsets:
		var spawn_pos = player.position + offset
		if MapManager.current_map and MapManager.current_map.is_walkable(spawn_pos):
			if not EntityManager.get_blocking_entity_at(spawn_pos):
				EntityManager.spawn_enemy("barrow_wight", spawn_pos)
				break


## Apply teleport curse (moves player to random location)
static func _apply_teleport(player, _effect: Dictionary) -> void:
	if not MapManager.current_map:
		return

	# Find walkable positions within range
	var positions: Array[Vector2i] = []
	var map = MapManager.current_map
	var center = player.position

	for x in range(center.x - 20, center.x + 21):
		for y in range(center.y - 20, center.y + 21):
			var pos = Vector2i(x, y)
			if map.is_walkable(pos) and not EntityManager.get_blocking_entity_at(pos):
				positions.append(pos)

	if positions.size() > 0:
		var old_pos = player.position
		player.position = positions[randi() % positions.size()]
		EventBus.player_moved.emit(old_pos, player.position)


## Apply hunger curse (drains hunger stat)
static func _apply_hunger(player, effect: Dictionary) -> void:
	if player.get("survival"):
		player.survival.hunger = maxf(player.survival.hunger - effect.hunger_drain, 0)


## Apply aging curse (permanently reduces CON)
static func _apply_aging(player, _effect: Dictionary) -> void:
	if "attributes" in player:
		player.attributes["CON"] = max(1, player.attributes["CON"] - 1)
		if player.has_method("_calculate_derived_stats"):
			player._calculate_derived_stats()


## Remove curse from equipped item at slot
## Returns true if curse was removed
static func remove_curse_from_slot(player, slot: String) -> bool:
	if not player.has_method("get") or not player.get("inventory"):
		return false

	var equipment = player.inventory.equipment
	var item = equipment.get(slot)

	if not item or not item.is_cursed:
		return false

	item.remove_curse()
	EventBus.message_logged.emit("The curse is lifted from the %s!" % item.name, Color.GOLD)
	return true


## Remove all curses from player (spell effect)
static func remove_all_curses(player) -> int:
	var curses_removed = 0

	# Remove curse debuffs from active effects
	if player.has_method("get") and "active_effects" in player:
		var to_remove: Array[String] = []
		for effect in player.active_effects:
			if effect.id.begins_with("curse_"):
				to_remove.append(effect.id)

		for effect_id in to_remove:
			if player.has_method("remove_magical_effect"):
				player.remove_magical_effect(effect_id)
				curses_removed += 1

	# Remove curses from equipped items
	if player.has_method("get") and player.get("inventory"):
		var equipment = player.inventory.equipment
		for slot in equipment:
			var item = equipment[slot]
			if item and item.is_cursed:
				item.remove_curse()
				curses_removed += 1

	return curses_removed


## Check if player can unequip item (returns false if binding curse)
static func can_unequip(item) -> bool:
	if not item:
		return true
	return not item.has_binding_curse()
