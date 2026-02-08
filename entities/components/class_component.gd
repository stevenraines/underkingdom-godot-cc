class_name ClassComponent
extends RefCounted

## ClassComponent - Manages class feats and progression
##
## Handles class-specific abilities, feat application, and combat bonuses.
## State variables (class_id, class_feats, class_stat_modifiers, etc.)
## remain on the Player for backward compatibility with external callers.

var _owner = null


func _init(owner = null) -> void:
	_owner = owner


## Apply class bonuses to player attributes and skills
## Should be called during character creation, after class is selected
func apply_class(new_class_id: String) -> void:
	_owner.class_id = new_class_id

	# Store class stat modifiers (don't modify base attributes)
	_owner.class_stat_modifiers = ClassManager.get_stat_modifiers(_owner.class_id).duplicate()
	print("[Player] Class stat modifiers: %s" % _owner.class_stat_modifiers)

	# Store class skill bonuses
	_owner.class_skill_bonuses = ClassManager.get_skill_bonuses(_owner.class_id).duplicate()
	print("[Player] Class skill bonuses: %s" % _owner.class_skill_bonuses)

	# Apply skill bonuses to skills
	for skill_id in _owner.class_skill_bonuses:
		if _owner.skills.has(skill_id):
			_owner.skills[skill_id] += _owner.class_skill_bonuses[skill_id]

	# Apply class feats
	var feats = ClassManager.get_feats(_owner.class_id)
	for feat in feats:
		_apply_class_feat(feat)

	# Recalculate derived stats after attribute changes
	_owner._calculate_derived_stats()

	# Update perception based on effective WIS (includes class modifier)
	_owner.perception_range = 5 + int(_owner.get_effective_attribute("WIS") / 2.0)

	print("[Player] Applied class '%s' - Stats: %s, Skills: %s" % [
		_owner.class_id,
		ClassManager.format_stat_modifiers(_owner.class_id),
		ClassManager.format_skill_bonuses(_owner.class_id)
	])


## Apply a single class feat
func _apply_class_feat(feat_data: Dictionary) -> void:
	var feat_id = feat_data.get("id", "")
	var feat_type = feat_data.get("type", "passive")

	# Initialize feat state
	var uses_per_day = feat_data.get("uses_per_day", -1)  # -1 = unlimited (passive)
	_owner.class_feats[feat_id] = {
		"uses_remaining": uses_per_day,
		"active": true
	}

	# Apply passive effects immediately
	if feat_type == "passive":
		var effect = feat_data.get("effect", {})
		_apply_passive_feat_effect(effect)


## Apply passive feat effects (stat bonuses, etc.)
func _apply_passive_feat_effect(effect: Dictionary) -> void:
	# Max health bonus (e.g., Warrior Battle Hardened)
	if effect.has("max_health_bonus"):
		_owner.max_health_bonus += effect.max_health_bonus
		_owner.max_health += effect.max_health_bonus
		_owner.current_health += effect.max_health_bonus

	# Max mana bonus (e.g., Mage Arcane Mind)
	if effect.has("max_mana_bonus"):
		_owner.max_mana_bonus += effect.max_mana_bonus
		if _owner.survival:
			_owner.survival.base_max_mana += effect.max_mana_bonus
			_owner.survival.mana += effect.max_mana_bonus

	# Critical hit damage bonus (e.g., Rogue Shadow Strike)
	if effect.has("crit_damage_bonus"):
		_owner.crit_damage_bonus += effect.crit_damage_bonus

	# Ranged damage bonus (e.g., Ranger Hunter's Mark)
	if effect.has("ranged_damage_bonus"):
		_owner.ranged_damage_bonus += effect.ranged_damage_bonus

	# Healing received bonus (e.g., Cleric Divine Favor)
	if effect.has("healing_received_bonus"):
		_owner.healing_received_bonus += effect.healing_received_bonus

	# Low HP melee bonus (e.g., Barbarian Rage)
	if effect.has("low_hp_melee_bonus"):
		_owner.low_hp_melee_bonus += effect.low_hp_melee_bonus

	# Bonus skill points per level (e.g., Adventurer Jack of All Trades)
	if effect.has("bonus_skill_points_per_level"):
		_owner.bonus_skill_points_per_level += effect.bonus_skill_points_per_level


## Check if player has a specific class feat
func has_class_feat(feat_id: String) -> bool:
	return _owner.class_feats.has(feat_id) and _owner.class_feats[feat_id].active


## Use a class feat (for active feats with limited uses)
## Returns true if feat was used successfully
func use_class_feat(feat_id: String) -> bool:
	if not _owner.class_feats.has(feat_id):
		return false

	var feat_state = _owner.class_feats[feat_id]

	# Check if uses remaining (unlimited = -1 for passives)
	if feat_state.uses_remaining == 0:
		return false

	# Decrement uses if not unlimited
	if feat_state.uses_remaining > 0:
		feat_state.uses_remaining -= 1

	EventBus.class_feat_used.emit(_owner, feat_id)
	return true


## Check if a class feat has uses remaining
func can_use_class_feat(feat_id: String) -> bool:
	if not _owner.class_feats.has(feat_id):
		return false

	var feat_state = _owner.class_feats[feat_id]
	return feat_state.uses_remaining != 0  # -1 (unlimited) or positive


## Get remaining uses for a class feat
func get_class_feat_uses(feat_id: String) -> int:
	if not _owner.class_feats.has(feat_id):
		return 0
	return _owner.class_feats[feat_id].uses_remaining


## Reset class feat uses (called at dawn each day)
func reset_class_feats() -> void:
	var feats = ClassManager.get_feats(_owner.class_id)
	for feat in feats:
		var feat_id = feat.get("id", "")
		if _owner.class_feats.has(feat_id):
			var uses_per_day = feat.get("uses_per_day", -1)
			_owner.class_feats[feat_id].uses_remaining = uses_per_day
			EventBus.class_feat_recharged.emit(_owner, feat_id)


## Get melee damage bonus from class feats (e.g., Barbarian Rage when low HP)
func get_class_melee_bonus() -> int:
	var bonus = 0

	# Rage: bonus damage when below threshold HP
	if has_class_feat("rage"):
		var feat = ClassManager.get_feat(_owner.class_id, "rage")
		var effect = feat.get("effect", {})
		var threshold = effect.get("low_hp_threshold", 0.5)
		if float(_owner.current_health) / float(_owner.max_health) <= threshold:
			bonus += effect.get("low_hp_melee_bonus", 0)

	return bonus


## Get ranged damage bonus from class feats
func get_class_ranged_bonus() -> int:
	return _owner.ranged_damage_bonus


## Get crit damage bonus from class feats
func get_class_crit_bonus() -> int:
	return _owner.crit_damage_bonus


## Apply healing with class bonus (e.g., Cleric Divine Favor)
func heal_with_class_bonus(amount: int) -> void:
	var bonus_amount = int(amount * _owner.healing_received_bonus)
	_owner.heal(amount + bonus_amount)
