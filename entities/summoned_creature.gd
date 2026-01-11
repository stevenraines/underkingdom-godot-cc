class_name SummonedCreature
extends Enemy

## SummonedCreature - Extends Enemy for summoned allies
##
## Summoned creatures fight for the player with various behavior modes.
## They have a limited duration and count toward the summon limit.

# Summoner reference (usually player)
var summoner: Entity = null
var remaining_duration: int = -1  # -1 = permanent (until dismissed)
var is_summon: bool = true
# faction is inherited from Entity (set to "player" in create_summon)

# Behavior modes
enum BehaviorMode { FOLLOW, AGGRESSIVE, DEFENSIVE, STAY }
var behavior_mode: String = "follow"  # follow, aggressive, defensive, stay


## Initialize a summoned creature
static func create_summon(summoner_entity: Entity, creature_data: Dictionary, duration: int = -1):
	var script = load("res://entities/summoned_creature.gd")
	var summon = script.new()

	# Basic properties from data
	summon.entity_id = creature_data.get("id", "unknown_summon")
	summon.entity_type = "summon"
	summon.name = creature_data.get("name", "Summoned Creature")
	summon.ascii_char = creature_data.get("ascii_char", "s")

	# Parse color from hex string
	var ascii_color = creature_data.get("ascii_color", "#88AAFF")
	summon.color = Color(ascii_color)

	# Stats - summons use simpler stat format
	summon.max_health = creature_data.get("base_health", 20)
	summon.current_health = summon.max_health
	summon.base_damage = creature_data.get("base_damage", 5)
	summon.armor = creature_data.get("armor", 0)

	# Attributes
	var attributes = creature_data.get("attributes", {})
	summon.attributes["STR"] = attributes.get("STR", 10)
	summon.attributes["DEX"] = attributes.get("DEX", 10)
	summon.attributes["CON"] = attributes.get("CON", 10)
	summon.attributes["INT"] = attributes.get("INT", 4)
	summon.attributes["WIS"] = attributes.get("WIS", 10)
	summon.attributes["CHA"] = attributes.get("CHA", 6)

	# Summon-specific properties
	summon.summoner = summoner_entity
	summon.remaining_duration = duration
	summon.is_summon = true
	summon.faction = "player"
	summon.behavior_mode = "follow"

	# Summons have no loot
	summon.loot_table = ""
	summon.xp_value = 0

	return summon


## Scale summon stats based on caster level
func scale_for_caster_level(caster_level: int) -> void:
	# Health: +5 per caster level
	max_health += caster_level * 5
	current_health = max_health

	# Damage: +2 per caster level
	base_damage += caster_level * 2


## Override take_turn to use summon AI
func take_turn() -> void:
	if not is_alive:
		return

	# Execute behavior based on mode
	match behavior_mode:
		"follow":
			_follow_summoner()
		"aggressive":
			_pursue_nearest_enemy()
		"defensive":
			_defend_summoner()
		"stay":
			_hold_position()
		_:
			_follow_summoner()


## Follow behavior - stay adjacent to summoner, attack nearby threats
func _follow_summoner() -> void:
	if not summoner or not summoner.is_alive:
		# Summoner dead - become aggressive
		_pursue_nearest_enemy()
		return

	# Check if enemy is adjacent - attack if so
	if _attack_adjacent_enemy():
		return

	# Otherwise, follow summoner (stay within 2 tiles)
	var distance = _distance_to(summoner.position)
	if distance > 2:
		_move_toward_target(summoner.position)


## Aggressive behavior - actively hunt nearest enemy
func _pursue_nearest_enemy() -> void:
	var nearest = _find_nearest_enemy()
	if nearest:
		if CombatSystem.are_cardinally_adjacent(position, nearest.position):
			CombatSystem.attempt_attack(self, nearest)
		else:
			_move_toward_target(nearest.position)
	else:
		# No enemies found, follow summoner
		if summoner and summoner.is_alive:
			var distance = _distance_to(summoner.position)
			if distance > 2:
				_move_toward_target(summoner.position)


## Defensive behavior - only attack if summoner was attacked recently
func _defend_summoner() -> void:
	if not summoner:
		return

	# First, attack any adjacent enemy
	if _attack_adjacent_enemy():
		return

	# Otherwise stay near summoner
	var distance = _distance_to(summoner.position)
	if distance > 3:
		_move_toward_target(summoner.position)


## Stay behavior - hold position and attack adjacent enemies only
func _hold_position() -> void:
	_attack_adjacent_enemy()
	# Don't move


## Attack any adjacent enemy entity
## Returns true if an attack was made
func _attack_adjacent_enemy() -> bool:
	# Look for adjacent enemy entities (not player, not other summons)
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	for dir in directions:
		var check_pos = position + dir
		var entity = EntityManager.get_blocking_entity_at(check_pos)
		if entity and entity is Enemy and not (entity is SummonedCreature):
			CombatSystem.attempt_attack(self, entity)
			return true

	return false


## Find the nearest enemy (non-summon)
func _find_nearest_enemy() -> Enemy:
	var nearest: Enemy = null
	var nearest_distance = 999

	for entity in EntityManager.entities:
		if entity is Enemy and not (entity is SummonedCreature) and entity.is_alive:
			var distance = _distance_to(entity.position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = entity

	return nearest


## Tick duration and check if summon should dismiss
## Returns true if still active, false if expired
func tick_duration() -> bool:
	if remaining_duration == -1:
		return true  # Permanent until dismissed

	remaining_duration -= 1
	if remaining_duration <= 0:
		dismiss()
		return false

	return true


## Dismiss the summon (voluntary or duration expired)
func dismiss() -> void:
	EventBus.message_logged.emit("%s vanishes!" % name, Color.GRAY)
	EventBus.summon_dismissed.emit(self)

	# Remove from summoner's list
	if summoner and summoner.has_method("remove_summon"):
		summoner.remove_summon(self)

	# Remove from entity manager
	die()


## Override die to handle summon death cleanup
func die() -> void:
	if not is_alive:
		return

	is_alive = false
	blocks_movement = false

	# Remove from summoner's list
	if summoner and summoner.has_method("remove_summon"):
		summoner.remove_summon(self)

	EventBus.summon_died.emit(self)
	EventBus.entity_died.emit(self)


## Set behavior mode
func set_behavior(mode: String) -> void:
	behavior_mode = mode
	EventBus.summon_command_changed.emit(self, mode)
	EventBus.message_logged.emit("%s will now %s." % [name, _get_behavior_description()], Color.CYAN)


## Get description of current behavior
func _get_behavior_description() -> String:
	match behavior_mode:
		"follow":
			return "follow you"
		"aggressive":
			return "aggressively pursue enemies"
		"defensive":
			return "defend you"
		"stay":
			return "hold position"
		_:
			return "follow you"


## Serialize for save/load
func serialize() -> Dictionary:
	return {
		"entity_id": entity_id,
		"name": name,
		"position": {"x": position.x, "y": position.y},
		"current_health": current_health,
		"max_health": max_health,
		"base_damage": base_damage,
		"remaining_duration": remaining_duration,
		"behavior_mode": behavior_mode,
		"ascii_char": ascii_char,
		"ascii_color": "#" + color.to_html(false)
	}
