class_name WildMagic
extends RefCounted

## WildMagic - Handles random magical effects from spell failures
##
## When a spell fails catastrophically, wild magic can surge,
## causing unpredictable magical effects.

const WILD_MAGIC_TABLE = [
	{id = "mana_surge", weight = 5, effect = "Caster gains 20 mana"},
	{id = "mana_drain", weight = 5, effect = "Caster loses all mana"},
	{id = "random_teleport", weight = 5, effect = "Caster teleports randomly"},
	{id = "target_teleport", weight = 3, effect = "Target teleports randomly"},
	{id = "heal_all", weight = 3, effect = "All nearby creatures healed 10 HP"},
	{id = "damage_all", weight = 3, effect = "All nearby creatures take 10 damage"},
	{id = "summon_creature", weight = 3, effect = "Random creature summoned"},
	{id = "polymorph_caster", weight = 2, effect = "Caster polymorphed into animal"},
	{id = "time_slow", weight = 3, effect = "Extra turn gained"},
	{id = "time_skip", weight = 3, effect = "Lose next turn"},
	{id = "invisibility", weight = 3, effect = "Caster becomes invisible"},
	{id = "light_burst", weight = 4, effect = "Blinding flash in area"},
	{id = "gravity_flip", weight = 2, effect = "Items in area scattered"},
	{id = "spell_echo", weight = 3, effect = "Spell casts twice"},
	{id = "spell_reflect", weight = 2, effect = "Spell affects caster instead"},
	{id = "random_buff", weight = 4, effect = "Random buff applied"},
	{id = "random_debuff", weight = 4, effect = "Random debuff applied"},
	{id = "gold_rain", weight = 2, effect = "Gold coins appear nearby"},
	{id = "fire_burst", weight = 3, effect = "Fire erupts at location"},
	{id = "nothing", weight = 5, effect = "Nothing happens"}
]

## Trigger a wild magic effect
## caster: The entity who triggered wild magic
## original_spell: The spell that failed (can be null)
## Returns a dictionary with the effect details
static func trigger_wild_magic(caster, original_spell = null) -> Dictionary:
	var effect = _select_random_effect()

	EventBus.wild_magic_triggered.emit(caster, effect)
	EventBus.message_logged.emit("Wild magic surges! " + effect.effect, Color.MAGENTA)

	return _apply_wild_effect(caster, effect, original_spell)


## Select a random effect from the wild magic table based on weights
static func _select_random_effect() -> Dictionary:
	var total_weight = 0
	for entry in WILD_MAGIC_TABLE:
		total_weight += entry.weight

	var roll = randf() * total_weight
	var current = 0

	for entry in WILD_MAGIC_TABLE:
		current += entry.weight
		if roll <= current:
			return entry

	return WILD_MAGIC_TABLE[-1]  # Fallback


## Apply the selected wild magic effect
static func _apply_wild_effect(caster, effect: Dictionary, original_spell) -> Dictionary:
	var result = {success = true, message = effect.effect, effect_id = effect.id}

	match effect.id:
		"mana_surge":
			if caster.has_method("get") and caster.get("survival"):
				var survival = caster.survival
				survival.mana = mini(survival.mana + 20, survival.max_mana)
				EventBus.message_logged.emit("Magical energy floods into you!", Color.CYAN)

		"mana_drain":
			if caster.has_method("get") and caster.get("survival"):
				caster.survival.mana = 0
				EventBus.message_logged.emit("Your magical energy is drained away!", Color.RED)

		"random_teleport":
			_teleport_randomly(caster)

		"target_teleport":
			# Teleport a random nearby enemy
			var enemies = _get_nearby_enemies(caster.position, 5)
			if enemies.size() > 0:
				_teleport_randomly(enemies[randi() % enemies.size()])

		"heal_all":
			_heal_all_nearby(caster, 10)

		"damage_all":
			_damage_all_nearby(caster, 10)

		"summon_creature":
			_summon_random_creature(caster)

		"polymorph_caster":
			# Apply a temporary animal form (stat debuffs)
			caster.add_magical_effect({
				id = "wild_polymorph",
				type = "debuff",
				modifiers = {"STR": -3, "INT": -5},
				remaining_duration = 20
			})
			EventBus.message_logged.emit("You feel yourself transforming...", Color.YELLOW)

		"time_slow":
			# Grant an extra turn
			if caster.has_method("get"):
				caster.extra_turns = caster.get("extra_turns", 0) + 1
				EventBus.message_logged.emit("Time seems to slow around you...", Color.CYAN)

		"time_skip":
			# Skip next turn
			if caster.has_method("get"):
				caster.skip_next_turn = true
				EventBus.message_logged.emit("Time lurches forward...", Color.YELLOW)

		"invisibility":
			caster.add_magical_effect({
				id = "wild_invisibility",
				type = "buff",
				modifiers = {},
				stealth_bonus = 100,
				remaining_duration = 20
			})
			EventBus.message_logged.emit("You fade from sight!", Color.CYAN)

		"light_burst":
			# Flash of light in area
			_create_light_burst(caster.position)
			EventBus.message_logged.emit("A blinding flash of light erupts!", Color.YELLOW)

		"gravity_flip":
			# Scatter items in area
			_scatter_items(caster.position, 5)
			EventBus.message_logged.emit("Gravity warps and twists!", Color.MAGENTA)

		"spell_echo":
			# Cast original spell again if available
			if original_spell:
				const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")
				# Re-cast without triggering another wild magic
				EventBus.message_logged.emit("The spell echoes...", Color.CYAN)

		"spell_reflect":
			# Nothing special to do here - the original cast already failed
			EventBus.message_logged.emit("The magical energy rebounds!", Color.MAGENTA)

		"random_buff":
			_apply_random_buff(caster)

		"random_debuff":
			_apply_random_debuff(caster)

		"gold_rain":
			_spawn_gold_nearby(caster, randi_range(5, 20))

		"fire_burst":
			_create_fire_burst(caster.position, 2)

		"nothing":
			EventBus.message_logged.emit("The wild magic dissipates harmlessly.", Color.GRAY)

	return result


## Teleport an entity to a random walkable position
static func _teleport_randomly(entity) -> void:
	if not MapManager.current_map:
		return

	var valid_positions = []
	for x in range(-10, 11):
		for y in range(-10, 11):
			var pos = entity.position + Vector2i(x, y)
			if MapManager.current_map.is_walkable(pos):
				valid_positions.append(pos)

	if valid_positions.size() > 0:
		var old_pos = entity.position
		var new_pos = valid_positions[randi() % valid_positions.size()]
		entity.position = new_pos
		EventBus.entity_moved.emit(entity, old_pos, new_pos)
		EventBus.message_logged.emit("%s teleports!" % entity.name, Color.MAGENTA)


## Heal all creatures nearby
static func _heal_all_nearby(caster, amount: int) -> void:
	var entities = _get_all_entities_nearby(caster.position, 5)
	for entity in entities:
		if entity.has_method("heal"):
			entity.heal(amount)
	EventBus.message_logged.emit("A wave of healing energy spreads!", Color.GREEN)


## Damage all creatures nearby
static func _damage_all_nearby(caster, amount: int) -> void:
	var entities = _get_all_entities_nearby(caster.position, 5)
	for entity in entities:
		if entity.has_method("take_damage"):
			entity.take_damage(amount, "Wild Magic", "wild_magic")
	EventBus.message_logged.emit("Wild energy damages everything nearby!", Color.RED)


## Summon a random creature
static func _summon_random_creature(caster) -> void:
	var creatures = ["summoned_wolf", "summoned_skeleton"]
	var creature_id = creatures[randi() % creatures.size()]

	var pos = _get_adjacent_walkable_position(caster.position)
	if pos != Vector2i(-999, -999):
		EntityManager.spawn_enemy(creature_id, pos)
		EventBus.message_logged.emit("Something appears from thin air!", Color.MAGENTA)


## Get a random adjacent walkable position
static func _get_adjacent_walkable_position(center: Vector2i) -> Vector2i:
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	directions.shuffle()

	for dir in directions:
		var pos = center + dir
		if MapManager.current_map and MapManager.current_map.is_walkable(pos):
			return pos

	return Vector2i(-999, -999)


## Apply a random buff to an entity
static func _apply_random_buff(entity) -> void:
	var buffs = [
		{id = "wild_strength", type = "buff", modifiers = {"STR": 3}, remaining_duration = 30},
		{id = "wild_speed", type = "buff", modifiers = {"DEX": 3}, remaining_duration = 30},
		{id = "wild_vitality", type = "buff", modifiers = {"CON": 3}, remaining_duration = 30},
		{id = "wild_armor", type = "buff", armor_bonus = 3, remaining_duration = 30}
	]
	var buff = buffs[randi() % buffs.size()]
	entity.add_magical_effect(buff)
	EventBus.message_logged.emit("A magical buff surrounds you!", Color.CYAN)


## Apply a random debuff to an entity
static func _apply_random_debuff(entity) -> void:
	var debuffs = [
		{id = "wild_weakness", type = "debuff", modifiers = {"STR": -3}, remaining_duration = 30},
		{id = "wild_slowness", type = "debuff", modifiers = {"DEX": -3}, remaining_duration = 30},
		{id = "wild_frailty", type = "debuff", modifiers = {"CON": -3}, remaining_duration = 30}
	]
	var debuff = debuffs[randi() % debuffs.size()]
	entity.add_magical_effect(debuff)
	EventBus.message_logged.emit("A magical curse afflicts you!", Color.RED)


## Spawn gold coins nearby
static func _spawn_gold_nearby(caster, amount: int) -> void:
	var pos = _get_adjacent_walkable_position(caster.position)
	if pos != Vector2i(-999, -999):
		var gold = ItemManager.create_item("gold", amount)
		if gold:
			EntityManager.spawn_ground_item(gold, pos)
	EventBus.message_logged.emit("Gold coins rain down!", Color.YELLOW)


## Create a fire burst at a position
static func _create_fire_burst(center: Vector2i, radius: int) -> void:
	var entities = _get_all_entities_nearby(center, radius)
	for entity in entities:
		if entity.has_method("take_damage"):
			entity.take_damage(8, "Wild Magic Fire", "fire")
	EventBus.message_logged.emit("Fire erupts from nowhere!", Color.ORANGE)


## Create a light burst
static func _create_light_burst(center: Vector2i) -> void:
	# Could implement actual blinding effect, for now just visual
	pass


## Scatter items in an area
static func _scatter_items(center: Vector2i, radius: int) -> void:
	# Could implement actual item scattering, for now just visual effect
	pass


## Get nearby enemies
static func _get_nearby_enemies(center: Vector2i, radius: int) -> Array:
	var enemies = []
	var all_entities = EntityManager.get_all_entities()
	for entity in all_entities:
		if entity.entity_type == "enemy":
			var distance = abs(entity.position.x - center.x) + abs(entity.position.y - center.y)
			if distance <= radius:
				enemies.append(entity)
	return enemies


## Get all entities nearby (enemies and player)
static func _get_all_entities_nearby(center: Vector2i, radius: int) -> Array:
	var entities = []

	# Add player if in range
	if EntityManager.player:
		var player_dist = abs(EntityManager.player.position.x - center.x) + abs(EntityManager.player.position.y - center.y)
		if player_dist <= radius:
			entities.append(EntityManager.player)

	# Add enemies in range
	var all_entities = EntityManager.get_all_entities()
	for entity in all_entities:
		if entity.entity_type == "enemy":
			var distance = abs(entity.position.x - center.x) + abs(entity.position.y - center.y)
			if distance <= radius:
				entities.append(entity)

	return entities
