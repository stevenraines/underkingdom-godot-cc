class_name PlayerSerializer
extends RefCounted

## PlayerSerializer - Handles player state serialization
##
## Serializes/deserializes player attributes, stats, race, class, survival,
## inventory, equipment, spells, effects, and skills.

const InventorySerializerClass = preload("res://autoload/serializers/inventory_serializer.gd")


## Serialize complete player state to dictionary
static func serialize(player) -> Dictionary:
	if not player:
		push_error("PlayerSerializer: No player to serialize")
		return {}

	return {
		"position": {"x": player.position.x, "y": player.position.y},
		"race_id": player.race_id,
		"racial_traits": player.racial_traits.duplicate(true),
		"racial_stat_modifiers": player.racial_stat_modifiers.duplicate(),
		"racial_bonuses": {
			"trap_detection_bonus": player.trap_detection_bonus,
			"crafting_bonus": player.crafting_bonus,
			"spell_success_bonus": player.spell_success_bonus,
			"harvest_bonuses": player.harvest_bonuses.duplicate()
		},
		"class_id": player.class_id,
		"class_feats": player.class_feats.duplicate(true),
		"class_stat_modifiers": player.class_stat_modifiers.duplicate(),
		"class_skill_bonuses": player.class_skill_bonuses.duplicate(),
		"class_bonuses": {
			"max_health_bonus": player.max_health_bonus,
			"max_mana_bonus": player.max_mana_bonus,
			"crit_damage_bonus": player.crit_damage_bonus,
			"ranged_damage_bonus": player.ranged_damage_bonus,
			"healing_received_bonus": player.healing_received_bonus,
			"low_hp_melee_bonus": player.low_hp_melee_bonus,
			"bonus_skill_points_per_level": player.bonus_skill_points_per_level
		},
		"attributes": {
			"STR": player.attributes["STR"],
			"DEX": player.attributes["DEX"],
			"CON": player.attributes["CON"],
			"INT": player.attributes["INT"],
			"WIS": player.attributes["WIS"],
			"CHA": player.attributes["CHA"]
		},
		"health": {
			"current": player.current_health,
			"max": player.max_health
		},
		"survival": _serialize_survival(player.survival),
		"inventory": InventorySerializerClass.serialize_inventory(player.inventory),
		"equipment": InventorySerializerClass.serialize_equipment(player.inventory.equipment),
		"gold": player.gold,
		"experience": player.experience,
		"level": player.level,
		"experience_to_next_level": player.experience_to_next_level,
		"available_skill_points": player.available_skill_points,
		"available_ability_points": player.available_ability_points,
		"skills": player.skills.duplicate(),
		"known_recipes": player.known_recipes.duplicate(),
		"known_spells": player.known_spells.duplicate(),
		"concentration_spell": player.concentration_spell,
		"active_effects": _serialize_active_effects(player.active_effects)
	}


## Deserialize player state from dictionary
static func deserialize(player, player_data: Dictionary) -> void:
	if not player:
		push_error("PlayerSerializer: No player to deserialize into")
		return

	# Position
	player.position = Vector2i(player_data.position.x, player_data.position.y)

	# Race (with backwards compatibility - default to human for old saves)
	var old_save_detected = false
	player.race_id = player_data.get("race_id", "human")
	if player_data.has("racial_traits"):
		player.racial_traits = player_data.racial_traits.duplicate(true)
	else:
		# Old save detected - will re-apply race after loading
		old_save_detected = true
		player.racial_traits = {}

	# Racial stat modifiers (with backwards compatibility for old saves)
	if player_data.has("racial_stat_modifiers"):
		player.racial_stat_modifiers = player_data.racial_stat_modifiers.duplicate()
	else:
		# Re-apply from race manager for old saves without this field
		player.racial_stat_modifiers = RaceManager.get_stat_modifiers(player.race_id).duplicate()

	# Racial bonuses (with backwards compatibility for old saves)
	if player_data.has("racial_bonuses"):
		var bonuses = player_data.racial_bonuses
		player.trap_detection_bonus = bonuses.get("trap_detection_bonus", 0)
		player.crafting_bonus = bonuses.get("crafting_bonus", 0)
		player.spell_success_bonus = bonuses.get("spell_success_bonus", 0)
		player.harvest_bonuses = bonuses.get("harvest_bonuses", {}).duplicate()
	else:
		# Old save - re-apply race effects to set bonuses
		player.trap_detection_bonus = 0
		player.crafting_bonus = 0
		player.spell_success_bonus = 0
		player.harvest_bonuses = {}

	# Class (with backwards compatibility - default to adventurer for old saves)
	player.class_id = player_data.get("class_id", "adventurer")
	# Support both old (class_abilities) and new (class_feats) save format
	if player_data.has("class_feats"):
		player.class_feats = player_data.class_feats.duplicate(true)
	elif player_data.has("class_abilities"):
		# Backwards compatibility: rename old key
		player.class_feats = player_data.class_abilities.duplicate(true)
	else:
		# Old save detected - will re-apply class after loading
		old_save_detected = true
		player.class_feats = {}

	# Class stat modifiers (with backwards compatibility for old saves)
	if player_data.has("class_stat_modifiers"):
		player.class_stat_modifiers = player_data.class_stat_modifiers.duplicate()
	else:
		# Re-apply from class manager for old saves without this field
		player.class_stat_modifiers = ClassManager.get_stat_modifiers(player.class_id).duplicate()

	# Class skill bonuses (with backwards compatibility for old saves)
	if player_data.has("class_skill_bonuses"):
		player.class_skill_bonuses = player_data.class_skill_bonuses.duplicate()
	else:
		player.class_skill_bonuses = ClassManager.get_skill_bonuses(player.class_id).duplicate()

	# Class bonuses (with backwards compatibility for old saves)
	if player_data.has("class_bonuses"):
		var cls_bonuses = player_data.class_bonuses
		player.max_health_bonus = cls_bonuses.get("max_health_bonus", 0)
		player.max_mana_bonus = cls_bonuses.get("max_mana_bonus", 0)
		player.crit_damage_bonus = cls_bonuses.get("crit_damage_bonus", 0)
		player.ranged_damage_bonus = cls_bonuses.get("ranged_damage_bonus", 0)
		player.healing_received_bonus = cls_bonuses.get("healing_received_bonus", 0.0)
		player.low_hp_melee_bonus = cls_bonuses.get("low_hp_melee_bonus", 0)
		player.bonus_skill_points_per_level = cls_bonuses.get("bonus_skill_points_per_level", 0)
	else:
		# Old save - set defaults (adventurer has no bonuses)
		player.max_health_bonus = 0
		player.max_mana_bonus = 0
		player.crit_damage_bonus = 0
		player.ranged_damage_bonus = 0
		player.healing_received_bonus = 0.0
		player.low_hp_melee_bonus = 0
		player.bonus_skill_points_per_level = 0

	# Attributes
	for attr in player_data.attributes.keys():
		player.attributes[attr] = player_data.attributes[attr]

	# Recalculate derived stats after attributes are set
	player._calculate_derived_stats()

	# Health
	player.current_health = player_data.health.current
	player.max_health = player_data.health.max

	# Survival
	_deserialize_survival(player.survival, player_data.survival)

	# Inventory
	InventorySerializerClass.deserialize_inventory(player.inventory, player_data.inventory)

	# Equipment
	InventorySerializerClass.deserialize_equipment(player.inventory, player_data.equipment)

	# Misc
	player.gold = player_data.gold
	player.experience = player_data.experience
	player.level = player_data.get("level", 0)  # Default to 0 for old saves
	player.experience_to_next_level = player_data.experience_to_next_level
	player.available_skill_points = player_data.get("available_skill_points", 0)
	player.available_ability_points = player_data.get("available_ability_points", 0)

	# Restore skills (merge with defaults, migrate old skill names)
	if player_data.has("skills"):
		for skill_name in player_data.skills:
			# Try direct match first
			if player.skills.has(skill_name):
				player.skills[skill_name] = player_data.skills[skill_name]
			else:
				# Try migrating old skill names to new IDs
				var migrated_id = _migrate_skill_name(skill_name)
				if migrated_id != "" and player.skills.has(migrated_id):
					player.skills[migrated_id] = player_data.skills[skill_name]

	# Restore known recipes (clear and append to maintain Array[String] type)
	player.known_recipes.clear()
	for recipe_id in player_data.known_recipes:
		player.known_recipes.append(recipe_id)

	# Restore known spells (clear and append to maintain Array[String] type)
	player.known_spells.clear()
	if player_data.has("known_spells"):
		for spell_id in player_data.known_spells:
			player.known_spells.append(spell_id)

	# Restore concentration spell
	player.concentration_spell = player_data.get("concentration_spell", "")

	# Restore active effects (buffs, debuffs, DoTs)
	player.active_effects.clear()
	if player_data.has("active_effects"):
		for effect_data in player_data.active_effects:
			player.active_effects.append(effect_data.duplicate(true))

	# Recalculate stat modifiers from effects and equipment after full restore
	player._recalculate_effect_modifiers()

	# Re-apply race and class for old saves that didn't have these systems
	if old_save_detected:
		print("PlayerSerializer: Old save detected - applying default race (human) and class (adventurer)")
		# Apply race (defaults to human)
		if player.has_method("apply_race"):
			player.apply_race(player.race_id)
		# Apply class (defaults to adventurer)
		if player.has_method("apply_class"):
			player.apply_class(player.class_id)

	print("PlayerSerializer: Player deserialized")


## Serialize survival stats
static func _serialize_survival(survival: SurvivalSystem) -> Dictionary:
	if not survival:
		return {}

	return {
		"hunger": survival.hunger,
		"thirst": survival.thirst,
		"temperature": survival.temperature,
		"stamina": survival.stamina,
		"base_max_stamina": survival.base_max_stamina,
		"fatigue": survival.fatigue,
		"mana": survival.mana,
		"base_max_mana": survival.base_max_mana
	}


## Deserialize survival state
static func _deserialize_survival(survival: SurvivalSystem, survival_data: Dictionary) -> void:
	if not survival or survival_data.is_empty():
		return

	survival.hunger = survival_data.hunger
	survival.thirst = survival_data.thirst
	survival.temperature = survival_data.temperature
	survival.stamina = survival_data.stamina
	survival.base_max_stamina = survival_data.base_max_stamina
	survival.fatigue = survival_data.fatigue
	# Mana (with backwards compatibility for older saves)
	survival.mana = survival_data.get("mana", survival.get_max_mana())
	survival.base_max_mana = survival_data.get("base_max_mana", 30.0)


## Serialize active magical effects (buffs, debuffs, DoTs)
static func _serialize_active_effects(effects: Array) -> Array:
	var serialized = []
	for effect in effects:
		# Create a copy of the effect, excluding non-serializable references
		var effect_data = {
			"id": effect.get("id", ""),
			"type": effect.get("type", ""),
			"remaining_duration": effect.get("remaining_duration", 0)
		}
		# Copy optional fields
		if effect.has("name"):
			effect_data["name"] = effect.name
		if effect.has("modifiers"):
			effect_data["modifiers"] = effect.modifiers.duplicate()
		if effect.has("armor_bonus"):
			effect_data["armor_bonus"] = effect.armor_bonus
		if effect.has("source_spell"):
			effect_data["source_spell"] = effect.source_spell
		# DoT specific fields
		if effect.has("dot_type"):
			effect_data["dot_type"] = effect.dot_type
		if effect.has("damage_per_turn"):
			effect_data["damage_per_turn"] = effect.damage_per_turn
		serialized.append(effect_data)
	return serialized


## Migrate old skill names to new skill IDs
## Returns empty string if no migration available
static func _migrate_skill_name(old_name: String) -> String:
	# Map old skill names to new lowercase IDs
	var migration_map = {
		# Old D&D-style skills to new action skills
		"Crafting": "crafting",
		"Sleight of Hand": "lockpicking",  # Closest match
		"Survival": "harvesting",  # Closest match
		# Old names that might be capitalized
		"Lockpicking": "lockpicking",
		"Harvesting": "harvesting",
		"Traps": "traps",
		# Weapon skills (in case of capitalization issues)
		"Swords": "swords",
		"Axes": "axes",
		"Maces": "maces",
		"Daggers": "daggers",
		"Bows": "bows",
		"Crossbows": "crossbows",
		"Thrown": "thrown"
	}
	return migration_map.get(old_name, "")
