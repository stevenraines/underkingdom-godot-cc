class_name RaceComponent
extends RefCounted

## RaceComponent - Manages racial traits and abilities
##
## Handles racial bonuses, trait application, ability usage, and cooldowns.
## State variables (race_id, racial_traits, racial_stat_modifiers, etc.)
## remain on the Player for backward compatibility with external callers.

var _owner = null


func _init(owner = null) -> void:
	_owner = owner


## Apply race bonuses to player attributes
## Should be called during character creation, after race is selected
func apply_race(new_race_id: String) -> void:
	_owner.race_id = new_race_id

	# Store racial stat modifiers (don't modify base attributes)
	_owner.racial_stat_modifiers = RaceManager.get_stat_modifiers(_owner.race_id).duplicate()
	print("[Player] Racial stat modifiers: %s" % _owner.racial_stat_modifiers)

	# Apply bonus stat points (e.g., Human Versatile trait)
	var bonus_points = RaceManager.get_bonus_stat_points(_owner.race_id)
	if bonus_points > 0:
		_owner.available_ability_points += bonus_points
		print("[Player] Granted %d bonus ability points from race" % bonus_points)

	# Apply trait effects
	var race_traits = RaceManager.get_traits(_owner.race_id)
	for race_trait in race_traits:
		_apply_racial_trait(race_trait)

	# Recalculate derived stats after attribute changes
	_owner._calculate_derived_stats()

	# Update perception based on effective WIS (includes racial modifier)
	_owner.perception_range = 5 + int(_owner.get_effective_attribute("WIS") / 2.0)

	# Apply racial color (optional - tint player)
	var race_color_str = RaceManager.get_race_color(_owner.race_id)
	if not race_color_str.is_empty():
		_owner.color = Color(race_color_str)

	print("[Player] Applied race '%s' - Stats: %s" % [_owner.race_id, RaceManager.format_stat_modifiers(_owner.race_id)])


## Apply a single racial trait
func _apply_racial_trait(trait_data: Dictionary) -> void:
	var trait_id = trait_data.get("id", "")
	var trait_type = trait_data.get("type", "passive")

	# Initialize trait state
	var uses_per_day = trait_data.get("uses_per_day", -1)  # -1 = unlimited
	_owner.racial_traits[trait_id] = {
		"uses_remaining": uses_per_day,
		"active": true
	}

	# Apply passive effects
	if trait_type == "passive":
		var effect = trait_data.get("effect", {})
		_apply_passive_trait_effect(effect)


## Apply passive trait effects (resistances, bonuses, etc.)
func _apply_passive_trait_effect(effect: Dictionary) -> void:
	# Elemental resistances (e.g., Dwarf poison resistance)
	if effect.has("elemental_resistance"):
		for element in effect.elemental_resistance:
			var value = effect.elemental_resistance[element]
			_owner.elemental_resistances[element] = _owner.elemental_resistances.get(element, 0) + value

	# Melee damage bonus (e.g., Half-Orc Aggressive)
	if effect.has("melee_damage_bonus"):
		_owner.base_damage += effect.melee_damage_bonus

	# Trap detection bonus (e.g., Elf Keen Senses)
	if effect.has("trap_detection_bonus"):
		_owner.trap_detection_bonus += effect.trap_detection_bonus

	# Crafting bonus (e.g., Gnome Tinkerer)
	if effect.has("crafting_bonus"):
		_owner.crafting_bonus += effect.crafting_bonus

	# Spell success bonus (e.g., Gnome Arcane Affinity)
	if effect.has("spell_success_bonus"):
		_owner.spell_success_bonus += effect.spell_success_bonus

	# Harvest bonuses (e.g., Dwarf Stonecunning)
	if effect.has("harvest_bonus"):
		for resource_type in effect.harvest_bonus:
			var value = effect.harvest_bonus[resource_type]
			_owner.harvest_bonuses[resource_type] = _owner.harvest_bonuses.get(resource_type, 0) + value


## Check if player has a specific racial trait
func has_racial_trait(trait_id: String) -> bool:
	return _owner.racial_traits.has(trait_id) and _owner.racial_traits[trait_id].active


## Use a racial ability (for active traits with limited uses)
## Returns true if ability was used successfully
func use_racial_ability(trait_id: String) -> bool:
	if not _owner.racial_traits.has(trait_id):
		return false

	var trait_state = _owner.racial_traits[trait_id]

	# Check if uses remaining (unlimited = -1)
	if trait_state.uses_remaining == 0:
		return false

	# Decrement uses if not unlimited
	if trait_state.uses_remaining > 0:
		trait_state.uses_remaining -= 1

	EventBus.racial_ability_used.emit(_owner, trait_id)
	return true


## Check if a racial ability has uses remaining
func can_use_racial_ability(trait_id: String) -> bool:
	if not _owner.racial_traits.has(trait_id):
		return false

	var trait_state = _owner.racial_traits[trait_id]
	return trait_state.uses_remaining != 0  # -1 (unlimited) or positive


## Reset racial ability uses (called at dawn each day)
func reset_racial_abilities() -> void:
	var all_traits = RaceManager.get_traits(_owner.race_id)
	for trait_data in all_traits:
		var tid = trait_data.get("id", "")
		if _owner.racial_traits.has(tid):
			var uses_per_day = trait_data.get("uses_per_day", -1)
			_owner.racial_traits[tid].uses_remaining = uses_per_day
			EventBus.racial_ability_recharged.emit(_owner, tid)


## Get effective perception range (with racial bonuses like darkvision)
func get_effective_perception_range() -> int:
	var base = _owner.perception_range

	# Apply darkvision bonus during night
	if has_racial_trait("darkvision"):
		var darkvision_trait = RaceManager.get_trait(_owner.race_id, "darkvision")
		var effect = darkvision_trait.get("effect", {})
		var dark_bonus = effect.get("perception_bonus_dark", 0)

		# Check if currently in darkness (night time)
		if TurnManager.time_of_day in ["night", "midnight"]:
			base += dark_bonus

	return base


## Get evasion bonus from racial traits (e.g., Halfling Nimble)
func get_racial_evasion_bonus() -> int:
	var bonus = 0

	if has_racial_trait("nimble"):
		var nimble_trait = RaceManager.get_trait(_owner.race_id, "nimble")
		var effect = nimble_trait.get("effect", {})
		bonus += effect.get("evasion_bonus", 0)

	return bonus


## Get XP bonus multiplier from racial traits (e.g., Human Ambitious)
func get_racial_xp_bonus() -> int:
	var bonus = 0

	if has_racial_trait("ambitious"):
		var ambitious_trait = RaceManager.get_trait(_owner.race_id, "ambitious")
		var effect = ambitious_trait.get("effect", {})
		bonus += effect.get("xp_bonus", 0)

	return bonus
