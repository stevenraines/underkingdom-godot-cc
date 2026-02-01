class_name Player
extends Entity

## Player - The player character entity
##
## Handles player movement, interactions, and dungeon navigation.

# Preload systems to ensure they're available
const _CombatSystem = preload("res://systems/combat_system.gd")
const _SurvivalSystem = preload("res://systems/survival_system.gd")
const _Inventory = preload("res://systems/inventory_system.gd")
const _CraftingSystem = preload("res://systems/crafting_system.gd")
const _HarvestSystem = preload("res://systems/harvest_system.gd")
const _FarmingSystem = preload("res://systems/farming_system.gd")
const _FOVSystem = preload("res://systems/fov_system.gd")
const _LockSystem = preload("res://systems/lock_system.gd")
const _RitualSystem = preload("res://systems/ritual_system.gd")
const _ItemFactory = preload("res://items/item_factory.gd")
# Note: ClassManager is accessed as an autoload singleton (registered in project.godot)

var perception_range: int = 10
var survival: SurvivalSystem = null
var inventory: Inventory = null
var known_recipes: Array[String] = []  # Array of recipe IDs the player has discovered
var known_spells: Array[String] = []  # Array of spell IDs the player has learned
var known_rituals: Array[String] = []  # Array of ritual IDs the player has learned
var gold: int = 25  # Player's gold currency

# Experience and Leveling
var experience: int = 0
var level: int = 0
var experience_to_next_level: int = 100

# Concentration (for maintained spells)
var concentration_spell: String = ""  # ID of current concentration spell

# Summoning
var active_summons: Array = []  # Array of SummonedCreature references
const MAX_SUMMONS = 3

# =============================================================================
# SUMMONING SYSTEM
# =============================================================================

## Add a summon to the player's active summons
## Enforces MAX_SUMMONS limit by dismissing the oldest summon
func add_summon(summon) -> bool:
	# Enforce limit - dismiss oldest if at max
	if active_summons.size() >= MAX_SUMMONS:
		var oldest = active_summons[0]
		oldest.dismiss()
		# Note: dismiss() calls remove_summon()

	active_summons.append(summon)
	EventBus.summon_created.emit(summon, self)
	return true

## Remove a summon from the active list
func remove_summon(summon) -> void:
	active_summons.erase(summon)

## Set behavior mode for a summon by index
func set_summon_behavior(index: int, mode: String) -> void:
	if index >= 0 and index < active_summons.size():
		active_summons[index].set_behavior(mode)

## Dismiss a specific summon by index
func dismiss_summon(index: int) -> void:
	if index >= 0 and index < active_summons.size():
		active_summons[index].dismiss()

## Dismiss all active summons
func dismiss_all_summons() -> void:
	# Iterate copy since dismiss modifies the array
	for summon in active_summons.duplicate():
		summon.dismiss()

## Get active summon count
func get_summon_count() -> int:
	return active_summons.size()

# =============================================================================
# CONCENTRATION SYSTEM
# =============================================================================

## Start concentrating on a spell
## Ends any previous concentration spell
func start_concentration(spell_id: String) -> void:
	# End previous concentration if any
	if concentration_spell != "":
		end_concentration()

	concentration_spell = spell_id
	EventBus.concentration_started.emit(self, spell_id)

## End concentration, removing the maintained effect
func end_concentration() -> void:
	if concentration_spell != "":
		# Remove the concentration effect from active effects
		remove_magical_effect(concentration_spell + "_effect")
		EventBus.concentration_ended.emit(self, concentration_spell)
		concentration_spell = ""

## Check if concentration is maintained after taking damage
## Concentration check: d20 + CON modifier vs DC 10 + damage/2 (minimum DC 10)
## Returns true if concentration maintained, false if broken
func check_concentration(damage_taken: int) -> bool:
	if concentration_spell == "":
		return true  # No concentration to break

	# Roll d20 + CON modifier
	var roll = randi_range(1, 20)
	var con_mod = (get_effective_attribute("CON") - 10) / 2
	var total = roll + con_mod

	# DC is 10 or half the damage, whichever is higher
	var dc = max(10, 10 + (damage_taken / 2))

	var success = total >= dc
	EventBus.concentration_check.emit(self, damage_taken, success)

	if not success:
		var spell_name = concentration_spell.replace("_", " ").capitalize()
		EventBus.message_logged.emit("Your concentration on %s is broken!" % spell_name, Color.RED)
		end_concentration()
		return false

	return true

# =============================================================================
# RITUAL SYSTEM
# =============================================================================

## Learn a ritual
## Returns true if successfully learned, false if already known
func learn_ritual(ritual_id: String) -> bool:
	if ritual_id in known_rituals:
		return false

	known_rituals.append(ritual_id)
	EventBus.ritual_learned.emit(self, ritual_id)
	return true


## Check if player knows a ritual
func knows_ritual(ritual_id: String) -> bool:
	return ritual_id in known_rituals


## Get all known rituals
func get_known_rituals() -> Array[String]:
	return known_rituals

# Skill points
var available_skill_points: int = 0
var available_ability_points: int = 0  # For ability score increases every 4th level

# Skills (0-level cap, initialized from SkillManager)
var skills: Dictionary = {}

# Death tracking
var death_cause: String = ""  # What killed the player (enemy name, "Starvation", etc.)
var death_method: String = ""  # Weapon/method used (if applicable)
var death_location: String = ""  # Where death occurred

# Movement tracking for encumbrance
var _last_move_turn: int = -1  # Turn when player last moved (for overburdened slowdown)

# Race system
var race_id: String = "human"  # Selected race ID
var racial_traits: Dictionary = {}  # Trait state: {trait_id: {uses_remaining: int, active: bool}}
var racial_stat_modifiers: Dictionary = {}  # Racial stat bonuses: {stat_name: modifier}

# Racial trait bonuses (applied from passive traits)
var trap_detection_bonus: int = 0  # Keen Senses (Elf)
var crafting_bonus: int = 0  # Tinkerer (Gnome)
var spell_success_bonus: int = 0  # Arcane Affinity (Gnome)
var harvest_bonuses: Dictionary = {}  # Stonecunning (Dwarf) - {resource_type: bonus}

# Class system
var class_id: String = "adventurer"  # Selected class ID
var class_feats: Dictionary = {}  # Feat state: {feat_id: {uses_remaining: int, active: bool}}
var class_stat_modifiers: Dictionary = {}  # Class stat bonuses: {stat_name: modifier}
var class_skill_bonuses: Dictionary = {}  # Class skill bonuses: {skill_id: bonus}

# Class passive bonuses (applied from passive feats)
var max_health_bonus: int = 0  # Battle Hardened (Warrior)
var max_mana_bonus: int = 0  # Arcane Mind (Mage)
var crit_damage_bonus: int = 0  # Shadow Strike (Rogue)
var ranged_damage_bonus: int = 0  # Hunter's Mark (Ranger)
var healing_received_bonus: float = 0.0  # Divine Favor (Cleric)
var low_hp_melee_bonus: int = 0  # Rage (Barbarian)
var bonus_skill_points_per_level: int = 0  # Jack of All Trades (Adventurer)

func _init() -> void:
	super("player", Vector2i(10, 10), "@", Color(1.0, 1.0, 0.0), true)
	_setup_player()

## Setup player-specific properties
func _setup_player() -> void:
	entity_type = "player"
	name = "Player"
	base_damage = 2  # Unarmed combat damage
	armor = 0  # No armor initially

	# Player starts with base attributes (defined in Entity)
	# Perception range calculated from WIS: Base 5 + (WIS / 2)
	perception_range = 5 + int(attributes["WIS"] / 2.0)

	# Initialize skills from SkillManager
	_setup_skills()

	# Initialize survival system
	survival = _SurvivalSystem.new(self)

	# Initialize inventory system
	inventory = _Inventory.new(self)


## Initialize skills dictionary from SkillManager definitions
## Called during setup and again when loading a game if skills are empty
func _setup_skills() -> void:
	skills.clear()
	# Use Engine.get_main_loop() to access autoloads safely
	var tree = Engine.get_main_loop()
	if tree and tree.root.has_node("SkillManager"):
		var skill_manager = tree.root.get_node("SkillManager")
		for skill_id in skill_manager.get_all_skill_ids():
			skills[skill_id] = 0

	# Connect to equipment change signals
	EventBus.item_equipped.connect(_on_item_equipped)
	EventBus.item_unequipped.connect(_on_item_unequipped)


## Called when an item is equipped
func _on_item_equipped(_item, _slot: String) -> void:
	_recalculate_effect_modifiers()


## Called when an item is unequipped
func _on_item_unequipped(_item, _slot: String) -> void:
	_recalculate_effect_modifiers()


# =============================================================================
# RACE SYSTEM
# =============================================================================

## Apply race bonuses to player attributes
## Should be called during character creation, after race is selected
func apply_race(new_race_id: String) -> void:
	race_id = new_race_id

	# Store racial stat modifiers (don't modify base attributes)
	racial_stat_modifiers = RaceManager.get_stat_modifiers(race_id).duplicate()
	print("[Player] Racial stat modifiers: %s" % racial_stat_modifiers)

	# Apply bonus stat points (e.g., Human Versatile trait)
	var bonus_points = RaceManager.get_bonus_stat_points(race_id)
	if bonus_points > 0:
		available_ability_points += bonus_points
		print("[Player] Granted %d bonus ability points from race" % bonus_points)

	# Apply trait effects
	var race_traits = RaceManager.get_traits(race_id)
	for race_trait in race_traits:
		_apply_racial_trait(race_trait)

	# Recalculate derived stats after attribute changes
	_calculate_derived_stats()

	# Update perception based on effective WIS (includes racial modifier)
	perception_range = 5 + int(get_effective_attribute("WIS") / 2.0)

	# Apply racial color (optional - tint player)
	var race_color_str = RaceManager.get_race_color(race_id)
	if not race_color_str.is_empty():
		color = Color(race_color_str)

	print("[Player] Applied race '%s' - Stats: %s" % [race_id, RaceManager.format_stat_modifiers(race_id)])


## Apply a single racial trait
func _apply_racial_trait(trait_data: Dictionary) -> void:
	var trait_id = trait_data.get("id", "")
	var trait_type = trait_data.get("type", "passive")

	# Initialize trait state
	var uses_per_day = trait_data.get("uses_per_day", -1)  # -1 = unlimited
	racial_traits[trait_id] = {
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
			elemental_resistances[element] = elemental_resistances.get(element, 0) + value

	# Melee damage bonus (e.g., Half-Orc Aggressive)
	if effect.has("melee_damage_bonus"):
		base_damage += effect.melee_damage_bonus

	# Trap detection bonus (e.g., Elf Keen Senses)
	if effect.has("trap_detection_bonus"):
		trap_detection_bonus += effect.trap_detection_bonus

	# Crafting bonus (e.g., Gnome Tinkerer)
	if effect.has("crafting_bonus"):
		crafting_bonus += effect.crafting_bonus

	# Spell success bonus (e.g., Gnome Arcane Affinity)
	if effect.has("spell_success_bonus"):
		spell_success_bonus += effect.spell_success_bonus

	# Harvest bonuses (e.g., Dwarf Stonecunning)
	if effect.has("harvest_bonus"):
		for resource_type in effect.harvest_bonus:
			var value = effect.harvest_bonus[resource_type]
			harvest_bonuses[resource_type] = harvest_bonuses.get(resource_type, 0) + value


## Check if player has a specific racial trait
func has_racial_trait(trait_id: String) -> bool:
	return racial_traits.has(trait_id) and racial_traits[trait_id].active


## Use a racial ability (for active traits with limited uses)
## Returns true if ability was used successfully
func use_racial_ability(trait_id: String) -> bool:
	if not racial_traits.has(trait_id):
		return false

	var trait_state = racial_traits[trait_id]

	# Check if uses remaining (unlimited = -1)
	if trait_state.uses_remaining == 0:
		return false

	# Decrement uses if not unlimited
	if trait_state.uses_remaining > 0:
		trait_state.uses_remaining -= 1

	EventBus.racial_ability_used.emit(self, trait_id)
	return true


## Check if a racial ability has uses remaining
func can_use_racial_ability(trait_id: String) -> bool:
	if not racial_traits.has(trait_id):
		return false

	var trait_state = racial_traits[trait_id]
	return trait_state.uses_remaining != 0  # -1 (unlimited) or positive


## Reset racial ability uses (called at dawn each day)
func reset_racial_abilities() -> void:
	var all_traits = RaceManager.get_traits(race_id)
	for trait_data in all_traits:
		var tid = trait_data.get("id", "")
		if racial_traits.has(tid):
			var uses_per_day = trait_data.get("uses_per_day", -1)
			racial_traits[tid].uses_remaining = uses_per_day
			EventBus.racial_ability_recharged.emit(self, tid)


## Override to include racial and class stat modifiers in effective attribute calculation
func get_effective_attribute(attr_name: String) -> int:
	var base_value = attributes.get(attr_name, 10)
	var racial_mod = racial_stat_modifiers.get(attr_name, 0)
	var class_mod = class_stat_modifiers.get(attr_name, 0)
	var temp_mod = stat_modifiers.get(attr_name, 0)
	return max(1, base_value + racial_mod + class_mod + temp_mod)


## Get effective perception range (with racial bonuses like darkvision)
func get_effective_perception_range() -> int:
	var base = perception_range

	# Apply darkvision bonus during night
	if has_racial_trait("darkvision"):
		var darkvision_trait = RaceManager.get_trait(race_id, "darkvision")
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
		var nimble_trait = RaceManager.get_trait(race_id, "nimble")
		var effect = nimble_trait.get("effect", {})
		bonus += effect.get("evasion_bonus", 0)

	return bonus


## Get XP bonus multiplier from racial traits (e.g., Human Ambitious)
func get_racial_xp_bonus() -> int:
	var bonus = 0

	if has_racial_trait("ambitious"):
		var ambitious_trait = RaceManager.get_trait(race_id, "ambitious")
		var effect = ambitious_trait.get("effect", {})
		bonus += effect.get("xp_bonus", 0)

	return bonus


# =============================================================================
# CLASS SYSTEM
# =============================================================================

## Apply class bonuses to player attributes and skills
## Should be called during character creation, after class is selected
func apply_class(new_class_id: String) -> void:
	class_id = new_class_id

	# Store class stat modifiers (don't modify base attributes)
	class_stat_modifiers = ClassManager.get_stat_modifiers(class_id).duplicate()
	print("[Player] Class stat modifiers: %s" % class_stat_modifiers)

	# Store class skill bonuses
	class_skill_bonuses = ClassManager.get_skill_bonuses(class_id).duplicate()
	print("[Player] Class skill bonuses: %s" % class_skill_bonuses)

	# Apply skill bonuses to skills
	for skill_id in class_skill_bonuses:
		if skills.has(skill_id):
			skills[skill_id] += class_skill_bonuses[skill_id]

	# Apply class feats
	var feats = ClassManager.get_feats(class_id)
	for feat in feats:
		_apply_class_feat(feat)

	# Recalculate derived stats after attribute changes
	_calculate_derived_stats()

	# Update perception based on effective WIS (includes class modifier)
	perception_range = 5 + int(get_effective_attribute("WIS") / 2.0)

	print("[Player] Applied class '%s' - Stats: %s, Skills: %s" % [
		class_id,
		ClassManager.format_stat_modifiers(class_id),
		ClassManager.format_skill_bonuses(class_id)
	])


## Apply a single class feat
func _apply_class_feat(feat_data: Dictionary) -> void:
	var feat_id = feat_data.get("id", "")
	var feat_type = feat_data.get("type", "passive")

	# Initialize feat state
	var uses_per_day = feat_data.get("uses_per_day", -1)  # -1 = unlimited (passive)
	class_feats[feat_id] = {
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
		max_health_bonus += effect.max_health_bonus
		max_health += effect.max_health_bonus
		current_health += effect.max_health_bonus

	# Max mana bonus (e.g., Mage Arcane Mind)
	if effect.has("max_mana_bonus"):
		max_mana_bonus += effect.max_mana_bonus
		if survival:
			survival.base_max_mana += effect.max_mana_bonus
			survival.mana += effect.max_mana_bonus

	# Critical hit damage bonus (e.g., Rogue Shadow Strike)
	if effect.has("crit_damage_bonus"):
		crit_damage_bonus += effect.crit_damage_bonus

	# Ranged damage bonus (e.g., Ranger Hunter's Mark)
	if effect.has("ranged_damage_bonus"):
		ranged_damage_bonus += effect.ranged_damage_bonus

	# Healing received bonus (e.g., Cleric Divine Favor)
	if effect.has("healing_received_bonus"):
		healing_received_bonus += effect.healing_received_bonus

	# Low HP melee bonus (e.g., Barbarian Rage)
	if effect.has("low_hp_melee_bonus"):
		low_hp_melee_bonus += effect.low_hp_melee_bonus

	# Bonus skill points per level (e.g., Adventurer Jack of All Trades)
	if effect.has("bonus_skill_points_per_level"):
		bonus_skill_points_per_level += effect.bonus_skill_points_per_level


## Check if player has a specific class feat
func has_class_feat(feat_id: String) -> bool:
	return class_feats.has(feat_id) and class_feats[feat_id].active


## Use a class feat (for active feats with limited uses)
## Returns true if feat was used successfully
func use_class_feat(feat_id: String) -> bool:
	if not class_feats.has(feat_id):
		return false

	var feat_state = class_feats[feat_id]

	# Check if uses remaining (unlimited = -1 for passives)
	if feat_state.uses_remaining == 0:
		return false

	# Decrement uses if not unlimited
	if feat_state.uses_remaining > 0:
		feat_state.uses_remaining -= 1

	EventBus.class_feat_used.emit(self, feat_id)
	return true


## Check if a class feat has uses remaining
func can_use_class_feat(feat_id: String) -> bool:
	if not class_feats.has(feat_id):
		return false

	var feat_state = class_feats[feat_id]
	return feat_state.uses_remaining != 0  # -1 (unlimited) or positive


## Get remaining uses for a class feat
func get_class_feat_uses(feat_id: String) -> int:
	if not class_feats.has(feat_id):
		return 0
	return class_feats[feat_id].uses_remaining


## Reset class feat uses (called at dawn each day)
func reset_class_feats() -> void:
	var feats = ClassManager.get_feats(class_id)
	for feat in feats:
		var feat_id = feat.get("id", "")
		if class_feats.has(feat_id):
			var uses_per_day = feat.get("uses_per_day", -1)
			class_feats[feat_id].uses_remaining = uses_per_day
			EventBus.class_feat_recharged.emit(self, feat_id)


## Get melee damage bonus from class feats (e.g., Barbarian Rage when low HP)
func get_class_melee_bonus() -> int:
	var bonus = 0

	# Rage: bonus damage when below threshold HP
	if has_class_feat("rage"):
		var feat = ClassManager.get_feat(class_id, "rage")
		var effect = feat.get("effect", {})
		var threshold = effect.get("low_hp_threshold", 0.5)
		if float(current_health) / float(max_health) <= threshold:
			bonus += effect.get("low_hp_melee_bonus", 0)

	return bonus


## Get ranged damage bonus from class feats
func get_class_ranged_bonus() -> int:
	return ranged_damage_bonus


## Get crit damage bonus from class feats
func get_class_crit_bonus() -> int:
	return crit_damage_bonus


## Apply healing with class bonus (e.g., Cleric Divine Favor)
func heal_with_class_bonus(amount: int) -> void:
	var bonus_amount = int(amount * healing_received_bonus)
	heal(amount + bonus_amount)


## Attempt to attack a target entity
func attack(target: Entity) -> Dictionary:
	# Interrupt ritual channeling if player attacks
	if _RitualSystem.is_channeling():
		_RitualSystem.interrupt_ritual("interrupted by combat")

	# Consume stamina for attack
	if survival and not survival.consume_stamina(survival.STAMINA_COST_ATTACK):
		return {"hit": false, "no_stamina": true}
	return _CombatSystem.attempt_attack(self, target)

## Attempt to move in a direction
func move(direction: Vector2i) -> bool:
	var new_pos = position + direction

	# Check encumbrance - may block or slow movement
	if inventory:
		var penalty = inventory.get_encumbrance_penalty()
		if not penalty.can_move:
			EventBus.message_logged.emit("You are too overburdened to move! Drop some items.")
			return false
		if penalty.movement_cost > 1:
			# Overburdened: can only move every N turns
			# If not enough turns have passed, struggle (consume turn but don't move)
			if _last_move_turn >= 0 and TurnManager.current_turn - _last_move_turn < penalty.movement_cost:
				var turns_remaining = penalty.movement_cost - (TurnManager.current_turn - _last_move_turn)
				EventBus.message_logged.emit("You struggle under the weight... (%d more turn%s)" % [turns_remaining, "" if turns_remaining == 1 else "s"])
				return true  # Return true to consume the turn (player "rests" while struggling)

	# Interrupt ritual channeling if player moves
	if _RitualSystem.is_channeling():
		_RitualSystem.interrupt_ritual("interrupted by movement")

	# Check for blocking features (chests, altars, etc.) - interact instead of moving
	# Must check this before is_walkable since blocking features make tiles non-walkable
	if FeatureManager.has_blocking_feature(new_pos):
		_interact_with_feature_at(new_pos)
		return true  # Action taken, but didn't move

	# Check for closed door - open it if auto-open is enabled
	var tile = MapManager.current_map.get_tile(new_pos) if MapManager.current_map else null
	if tile and tile.tile_type == "door" and not tile.is_open:
		# Check if auto-open doors is enabled
		if GameManager.auto_open_doors:
			var opened = _open_door(new_pos)
			return opened  # Only consume turn if door was actually opened
		else:
			return false  # Can't move through closed door when auto-open is off

	# Check if new position is walkable
	if not MapManager.current_map or not MapManager.current_map.is_walkable(new_pos):
		# Notify player why they can't move
		_notify_blocked_by_tile(new_pos)
		return false

	# Consume stamina for movement (allow move even if depleted, just add fatigue)
	if survival:
		if not survival.consume_stamina(survival.STAMINA_COST_MOVE):
			# Out of stamina - still allow movement but warn player
			pass

	var old_pos = position
	position = new_pos
	_last_move_turn = TurnManager.current_turn  # Track for encumbrance slowdown
	EventBus.player_moved.emit(old_pos, new_pos)

	# Check for hazards at new position
	_check_hazards_at_position(new_pos)

	# Check for crop trampling at new position
	_FarmingSystem.check_trample(self, new_pos)

	# Check for non-blocking interactable features at new position (like inscriptions)
	if FeatureManager.has_interactable_feature(new_pos):
		var feature = FeatureManager.get_feature_at(new_pos)
		var feature_def = feature.get("definition", {})
		if not feature_def.get("blocking", false):
			# For harvestable features (flora), respect auto_pickup setting
			if feature_def.get("harvestable", false):
				if GameManager.auto_pickup_enabled:
					_interact_with_feature_at(new_pos)
				# else: player must manually gather with H key
			else:
				# Non-harvestable features (inscriptions, etc.) always auto-interact
				_interact_with_feature_at(new_pos)

	return true


## Notify player when blocked by a non-walkable tile, entity, feature, or structure
func _notify_blocked_by_tile(pos: Vector2i) -> void:
	# Check for blocking entities at this position (fixes #103 - "blocked by stone floor" bug)
	# This catches entities that weren't found by EntityManager.get_blocking_entity_at()
	# (e.g., entities in map.entities but not EntityManager.entities, or edge cases)
	if MapManager.current_map:
		for entity in MapManager.current_map.entities:
			if entity.position == pos and entity.blocks_movement:
				EventBus.message_logged.emit("Your path is blocked by %s." % entity.name.to_lower())
				return

	# Check for blocking features at this position
	if FeatureManager.has_blocking_feature(pos):
		var feature = FeatureManager.get_feature_at(pos)
		if feature:
			var feature_name = feature.get("definition", {}).get("name", "an obstacle")
			EventBus.message_logged.emit("Your path is blocked by %s." % feature_name.to_lower())
			return

	# Check for blocking structures at this position
	if MapManager.current_map:
		var structures = StructureManager.get_structures_at(pos, MapManager.current_map.map_id)
		for structure in structures:
			if structure.blocks_movement:
				EventBus.message_logged.emit("Your path is blocked by %s." % structure.name.to_lower())
				return

	# Fall back to tile-based blocking message
	var tile = MapManager.current_map.get_tile(pos) if MapManager.current_map else null
	if not tile:
		return

	# Get a human-readable name for the blocking tile
	var tile_name = _get_tile_display_name(tile)
	EventBus.message_logged.emit("Your path is blocked by %s." % tile_name)


## Get a human-readable display name for a tile type
## Uses TileTypeManager for data-driven display names
func _get_tile_display_name(tile) -> String:
	# First check by ascii character for special structures/features
	# This catches wells, shrines, and resources on floor tiles
	var char_name = TileTypeManager.get_display_name_by_ascii_char(tile.ascii_char)
	if not char_name.is_empty():
		return char_name

	# Handle doors with state-specific display names
	if tile.tile_type == "door":
		if tile.is_locked:
			return TileTypeManager.get_display_name("door", "locked")
		elif not tile.is_open:
			return TileTypeManager.get_display_name("door", "closed")
		else:
			return TileTypeManager.get_display_name("door", "open")

	# Try to get display name from TileTypeManager
	var display_name = TileTypeManager.get_display_name(tile.tile_type)
	if display_name != "an obstacle":
		return display_name

	# For floor tiles that are blocking, check remaining ascii characters
	if tile.tile_type == "floor" and not tile.walkable:
		return "an obstacle"

	# Fallback for unknown types
	if tile.tile_type != "" and tile.tile_type != "floor":
		return "a " + tile.tile_type.replace("_", " ")
	return "an obstacle"


## Check for hazards at the given position
func _check_hazards_at_position(pos: Vector2i) -> void:
	# First try to detect hidden hazards based on perception
	var perception_check = 5 + int(attributes["WIS"] / 2.0)
	HazardManager.try_detect_hazard(pos, perception_check)

	# Check if hazard triggers
	var hazard_result = HazardManager.check_hazard_trigger(pos, self)
	if hazard_result.get("triggered", false):
		_apply_hazard_damage(hazard_result)

	# Also check proximity hazards (1 tile radius)
	var proximity_results = HazardManager.check_proximity_hazards(pos, 1, self)
	for result in proximity_results:
		_apply_hazard_damage(result)


## Apply hazard damage and effects to player
func _apply_hazard_damage(hazard_result: Dictionary) -> void:
	print("[Player] Applying hazard damage: %s" % str(hazard_result))
	var damage: int = hazard_result.get("damage", 0)
	var hazard_id: String = hazard_result.get("hazard_id", "trap")
	var damage_type: String = hazard_result.get("damage_type", "physical")

	# Format hazard name for display (replace underscores with spaces)
	var hazard_display_name = hazard_id.replace("_", " ")

	# Apply damage if any
	if damage > 0:
		# Apply armor reduction for physical damage
		var actual_damage = damage
		if damage_type == "physical":
			actual_damage = max(1, damage - get_total_armor())

		take_damage(actual_damage)
		EventBus.combat_message.emit("You trigger a %s! (%d damage)" % [hazard_display_name, actual_damage], Color.ORANGE_RED)
	else:
		# No damage but still stepped into the hazard - notify player
		EventBus.combat_message.emit("You step into a %s!" % hazard_display_name, Color.ORANGE)

	# Apply status effects from hazard
	var effects = hazard_result.get("effects", [])
	for effect in effects:
		var effect_type = effect.get("type", "")
		@warning_ignore("unused_variable")
		var duration = effect.get("duration", 100)
		match effect_type:
			"poison":
				EventBus.combat_message.emit("You are poisoned!", Color.LIME_GREEN)
				# TODO: Apply poison status effect
			"slow":
				EventBus.combat_message.emit("You are slowed!", Color.DARK_BLUE)
				# TODO: Apply slow status effect
			"curse":
				EventBus.combat_message.emit("You are cursed!", Color.PURPLE)
				# TODO: Apply curse status effect
			"stat_drain":
				EventBus.combat_message.emit("You feel your strength draining away!", Color.PURPLE)
				# TODO: Apply stat drain status effect
			_:
				EventBus.combat_message.emit("You are affected by %s!" % effect_type, Color.ORANGE)


## Interact with a feature at the player's current position
func interact_with_feature() -> Dictionary:
	return _interact_with_feature_at(position)


## Interact with a feature at a specific position
func _interact_with_feature_at(pos: Vector2i) -> Dictionary:
	print("[Player] Attempting to interact with feature at %v" % pos)
	# Check if there's an interactable feature at position
	if not FeatureManager.has_interactable_feature(pos):
		print("[Player] No interactable feature at %v" % pos)
		return {"success": false, "message": "Nothing to interact with here."}

	var result = FeatureManager.interact_with_feature(pos)

	# Show message to player
	if result.has("message"):
		EventBus.combat_message.emit(result.message, Color.GOLD)

	# Process effects
	if result.get("success", false):
		for effect in result.get("effects", []):
			match effect.get("type"):
				"loot":
					_collect_feature_loot(effect.get("items", []))
				"harvest":
					_collect_feature_loot(effect.get("items", []))
				"summon_enemy":
					# Enemy spawning handled by EntityManager via signal
					pass
				"blessing":
					var amount = effect.get("amount", 10)
					heal(amount)
					EventBus.combat_message.emit("You feel blessed! (+%d HP)" % amount, Color.GOLD)
				"hint":
					EventBus.message_logged.emit(effect.get("text", ""))

	return result


## Collect loot from a feature
## Supports variant items via variant_name field
func _collect_feature_loot(items: Array) -> void:
	for item_data in items:
		var item_id = item_data.get("item_id", "")
		var count = item_data.get("count", 1)
		var variant_name = item_data.get("variant_name", "")

		if item_id == "gold_coin":
			gold += count
			EventBus.message_logged.emit("Found %d gold!" % count)
		else:
			var item: Item = null

			# Create item with variant if specified
			if not variant_name.is_empty():
				# Determine variant type from item_id (mushroom -> mushroom_species, etc.)
				var variant_type = _get_variant_type_for_item(item_id)
				if not variant_type.is_empty():
					item = _ItemFactory.create_item(item_id, {variant_type: variant_name}, count)
				else:
					# Fallback to regular item creation
					item = ItemManager.create_item(item_id, count)
			else:
				item = ItemManager.create_item(item_id, count)

			if item and inventory:
				if inventory.add_item(item):
					EventBus.item_picked_up.emit(item)
				else:
					# Inventory full - drop on ground
					EntityManager.spawn_ground_item(item, position)
					EventBus.message_logged.emit("Inventory full! Item dropped.")


## Get the variant type for a base item ID
## Maps item IDs to their corresponding variant types
func _get_variant_type_for_item(item_id: String) -> String:
	match item_id:
		"mushroom":
			return "mushroom_species"
		"flower":
			return "flower_species"
		"herb":
			return "herb_species"
		"fish":
			return "fish_species"
		_:
			return ""

## Process survival systems for a turn
func process_survival_turn(turn_number: int) -> Dictionary:
	if not survival:
		return {}

	# Update temperature based on current location, time, and player position
	var map_id = MapManager.current_map.map_id if MapManager.current_map else "overworld"
	survival.update_temperature(map_id, TurnManager.time_of_day, position)

	# Process survival effects
	var effects = survival.process_turn(turn_number)
	
	# Apply stat modifiers from survival
	apply_stat_modifiers(survival.get_stat_modifiers())
	
	# Update perception range based on survival effects
	var survival_effects = survival._calculate_survival_effects()
	var base_perception = 5 + int(attributes["WIS"] / 2.0)
	perception_range = max(2, base_perception + survival_effects.perception_modifier)
	
	return effects

## Regenerate stamina (called when waiting/not acting)
func regenerate_stamina() -> void:
	if survival:
		var effects = survival._calculate_survival_effects()
		survival.regenerate_stamina(effects.stamina_regen_modifier)

## Regenerate mana (called each turn, faster in shelter)
func regenerate_mana(shelter_multiplier: float = 1.0) -> void:
	if survival:
		survival.regenerate_mana(shelter_multiplier)

## Interact with the tile the player is standing on
func interact_with_tile() -> void:
	if not MapManager.current_map:
		return

	var tile = MapManager.current_map.get_tile(position)

	if tile.tile_type == "stairs_down":
		_descend_stairs()
	elif tile.tile_type == "stairs_up":
		_ascend_stairs()

## Descend stairs to next floor
func _descend_stairs() -> void:
	print("Player descending stairs...")
	MapManager.descend_dungeon()

	# Find stairs up on new floor and position player there
	_find_and_move_to_stairs("stairs_up")

## Ascend stairs to previous floor
func _ascend_stairs() -> void:
	print("Player ascending stairs...")
	MapManager.ascend_dungeon()

	# Find stairs down on new floor and position player there
	# (works for both overworld entrance and dungeon floors)
	_find_and_move_to_stairs("stairs_down")

## Find stairs of given type and move player there
func _find_and_move_to_stairs(stairs_type: String) -> void:
	if not MapManager.current_map:
		return

	var old_pos = position

	# For chunk-based maps, use stored positions
	if MapManager.current_map.chunk_based:
		if stairs_type == "stairs_down":
			# Returning to overworld - use saved position
			if GameManager.last_overworld_position != Vector2i.ZERO:
				position = GameManager.last_overworld_position
				print("Player positioned at saved overworld location: ", position)
				EventBus.player_moved.emit(old_pos, position)
				return
			# New game: spawn at player spawn position (just outside town)
			elif MapManager.current_map.has_meta("player_spawn"):
				position = MapManager.current_map.get_meta("player_spawn")
				print("Player positioned at spawn location: ", position)
				EventBus.player_moved.emit(old_pos, position)
				return
			# Fallback: get dungeon entrance position from metadata (old saves)
			elif MapManager.current_map.has_meta("dungeon_entrance"):
				position = MapManager.current_map.get_meta("dungeon_entrance")
				print("Player positioned at ", stairs_type, ": ", position)
				EventBus.player_moved.emit(old_pos, position)
				return
		# For stairs_up in dungeons, search tiles normally (handled below)

	# For non-chunk-based maps (dungeons), check metadata first for stairs position
	if MapManager.current_map.metadata.has(stairs_type):
		position = _parse_vector2i(MapManager.current_map.metadata[stairs_type])
		print("Player positioned at ", stairs_type, " from metadata: ", position)
		EventBus.player_moved.emit(old_pos, position)
		return

	# Fallback: search the tiles
	# Limit search to actual map bounds
	var search_width = min(MapManager.current_map.width, 100)
	var search_height = min(MapManager.current_map.height, 100)

	for y in range(search_height):
		for x in range(search_width):
			var pos = Vector2i(x, y)
			var tile = MapManager.current_map.get_tile(pos)
			if tile.tile_type == stairs_type:
				position = pos
				print("Player positioned at ", stairs_type, ": ", position)
				EventBus.player_moved.emit(old_pos, position)
				return

	# Fallback to center if stairs not found
	@warning_ignore("integer_division")
	position = Vector2i(search_width / 2, search_height / 2)
	push_warning("Could not find ", stairs_type, ", positioning at center")
	EventBus.player_moved.emit(old_pos, position)

## Harvest a resource in a given direction (generic method)
## Also handles harvesting crops from the farming system
func harvest_resource(direction: Vector2i) -> Dictionary:
	if not MapManager.current_map:
		return {"success": false, "message": "No map loaded"}

	var target_pos = position + direction
	var map_id = MapManager.current_map.map_id

	# First check for crops at the target position
	var crop = _FarmingSystem.get_crop_at(map_id, target_pos)
	if crop:
		var result = _FarmingSystem.harvest_crop(self, target_pos)
		# Add harvest_complete flag for compatibility with input handler
		result["harvest_complete"] = result.get("success", false)
		return result

	# Otherwise check for harvestable tiles
	var tile = MapManager.current_map.get_tile(target_pos)

	if not tile or tile.harvestable_resource_id.is_empty():
		return {"success": false, "message": "Nothing to harvest there"}

	# Delegate to HarvestSystem
	return _HarvestSystem.harvest(self, target_pos, tile.harvestable_resource_id)

## Get total weapon damage (rolled if weapon has range, otherwise base + bonus)
func get_weapon_damage() -> int:
	if inventory:
		# If weapon has a damage range, roll it (weapon damage replaces base damage)
		if inventory.has_weapon_damage_range():
			return inventory.roll_weapon_damage()
		# Legacy: flat bonus added to base damage
		return base_damage + inventory.get_weapon_damage_bonus()
	return base_damage

## Get total armor value from all equipped items
func get_total_armor() -> int:
	if inventory:
		return armor + inventory.get_total_armor()
	return armor

## Pick up a ground item
func pickup_item(ground_item: GroundItem) -> bool:
	if not ground_item or not ground_item.item:
		print("[Player] pickup_item failed: ground_item or item is null")
		return false

	if not inventory:
		print("[Player] pickup_item failed: no inventory")
		return false

	# Check encumbrance before picking up
	var new_weight = inventory.get_total_weight() + ground_item.item.get_total_weight()
	if new_weight / inventory.max_weight > 1.25:
		# Would be too heavy to move at all
		print("[Player] pickup_item failed: too heavy (weight: %.1f / %.1f)" % [new_weight, inventory.max_weight])
		return false

	var item = ground_item.item

	# Handle gold coins specially - add directly to gold count
	if item.id == "gold_coin":
		var count = item.stack_size
		gold += count
		EventBus.message_logged.emit("Found %d gold!" % count)
		EventBus.item_picked_up.emit(item)
		return true

	# Auto-equip lit light sources to off-hand if available
	if item.provides_light and item.is_lit and item.can_equip_to_slot("off_hand"):
		var off_hand = inventory.get_equipped("off_hand")
		var main_hand = inventory.get_equipped("main_hand")
		# Check if off-hand is free (and not blocked by two-handed weapon)
		if off_hand == null and (main_hand == null or not main_hand.is_two_handed()):
			# Directly equip to off-hand
			inventory.equipment["off_hand"] = item
			EventBus.item_picked_up.emit(item)
			EventBus.item_equipped.emit(item, "off_hand")
			return true

	if inventory.add_item(item):
		EventBus.item_picked_up.emit(item)
		return true

	print("[Player] pickup_item failed: inventory.add_item returned false (likely full)")
	return false

## Drop an item from inventory
func drop_item(item: Item) -> GroundItem:
	if not item or not inventory:
		return null
	
	if inventory.remove_item(item):
		var drop_pos = _find_drop_position()
		var ground_item = GroundItem.create(item, drop_pos)
		EventBus.item_dropped.emit(item, drop_pos)
		return ground_item
	
	return null

## Find an empty adjacent position to drop an item
func _find_drop_position() -> Vector2i:
	# Check adjacent tiles in order: cardinal directions first, then diagonals
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1),  # Up
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(1, -1),  # Up-right
		Vector2i(-1, -1)  # Up-left
	]
	
	for dir in directions:
		var check_pos = position + dir
		if _is_valid_drop_position(check_pos):
			return check_pos
	
	# If no empty adjacent space, drop at player position as fallback
	return position

## Check if a position is valid for dropping an item
func _is_valid_drop_position(pos: Vector2i) -> bool:
	if not MapManager.current_map:
		return false
	
	# Must be walkable terrain
	if not MapManager.current_map.is_walkable(pos):
		return false
	
	# Check for blocking entities (enemies, other players)
	var blocking = EntityManager.get_blocking_entity_at(pos)
	if blocking:
		return false
	
	return true

## Use an item from inventory
func use_item(item: Item) -> Dictionary:
	if not item or not inventory:
		return {"success": false, "message": "No item"}
	
	return inventory.use_item(item)

## Equip an item (returns array of unequipped items, if any)
func equip_item(item: Item, target_slot: String = "") -> Array[Item]:
	if not item or not inventory:
		return []
	
	return inventory.equip_item(item, target_slot)

## Apply item effects (called by Item.use())
func apply_item_effects(effects: Dictionary) -> void:
	if "hunger" in effects and survival:
		survival.eat(effects.hunger)
	if "thirst" in effects and survival:
		survival.drink(effects.thirst)
	if "health" in effects:
		heal(effects.health)
	if "stamina" in effects and survival:
		survival.stamina = min(survival.get_max_stamina(), survival.stamina + effects.stamina)
	if "fatigue" in effects and survival:
		survival.rest(effects.fatigue)
	if "mana" in effects and survival:
		survival.restore_mana(effects.mana)
	if "cure_dot" in effects:
		# Cure a specific type of DoT effect (e.g., "poison")
		cure_dot_type(effects.cure_dot)

## Check if player knows a recipe
func knows_recipe(recipe_id: String) -> bool:
	return recipe_id in known_recipes

## Learn a new recipe
func learn_recipe(recipe_id: String) -> void:
	if not knows_recipe(recipe_id):
		known_recipes.append(recipe_id)
		print("Player learned recipe: ", recipe_id)

## Check if player is near a fire source for crafting
func is_near_fire() -> bool:
	return _CraftingSystem.is_near_fire(position)

## Get all recipes the player knows
func get_known_recipes() -> Array:
	var result: Array = []
	for recipe_id in known_recipes:
		var recipe = RecipeManager.get_recipe(recipe_id)
		if recipe:
			result.append(recipe)
	return result

## Get recipes player can currently craft (knows recipe + has ingredients)
func get_craftable_recipes() -> Array:
	var result: Array = []
	var near_fire = _CraftingSystem.is_near_fire(position)

	for recipe_id in known_recipes:
		var recipe = RecipeManager.get_recipe(recipe_id)
		if recipe and recipe.has_requirements(inventory, near_fire):
			result.append(recipe)

	return result

# =============================================================================
# SPELLBOOK & SPELL LEARNING
# =============================================================================

## Check if player has a spellbook in inventory
func has_spellbook() -> bool:
	if not inventory:
		return false
	return inventory.has_item_with_flag("spellbook")


## Check if player has a holy symbol (Token of Faith) in inventory
func has_holy_symbol() -> bool:
	if not inventory:
		return false
	return inventory.has_item_with_flag("holy_symbol")


## Get the magic types this player's class can cast
func get_magic_types() -> Array:
	return ClassManager.get_magic_types(class_id)


## Check if player can cast a specific magic type
func can_cast_magic_type(magic_type: String) -> bool:
	return ClassManager.can_cast_magic_type(class_id, magic_type)


## Check if player has the required focus item for a spell
## Arcane spells require a spellbook, Divine spells require a holy symbol
## Returns dictionary with: valid (bool), message (String)
func has_focus_for_spell(spell) -> Dictionary:
	var spell_types = spell.get_magic_types()
	var player_types = get_magic_types()

	# Check if player's class can cast any of the spell's magic types
	var can_cast_type = false
	for spell_type in spell_types:
		if spell_type in player_types:
			can_cast_type = true
			break

	if not can_cast_type:
		return {"valid": false, "message": "Your class cannot cast this type of magic."}

	# Check if player has required focus for the spell types they can cast
	# If spell is both arcane AND divine, player only needs one matching focus
	for spell_type in spell_types:
		if spell_type in player_types:
			match spell_type:
				"arcane":
					if has_spellbook():
						return {"valid": true, "message": ""}
				"divine":
					if has_holy_symbol():
						return {"valid": true, "message": ""}

	# Player's class can cast the magic type but lacks the focus
	var missing_items: Array[String] = []
	for spell_type in spell_types:
		if spell_type in player_types:
			match spell_type:
				"arcane":
					if not has_spellbook():
						missing_items.append("spellbook")
				"divine":
					if not has_holy_symbol():
						missing_items.append("Token of Faith")

	if missing_items.size() == 1:
		return {"valid": false, "message": "You need a %s to cast this spell." % missing_items[0]}
	else:
		return {"valid": false, "message": "You need a %s to cast this spell." % " or ".join(missing_items)}


## Check if player knows a specific spell
func knows_spell(spell_id: String) -> bool:
	return spell_id in known_spells

## Learn a new spell (requires appropriate magic focus)
## Arcane spells require spellbook, Divine spells require holy symbol
## Returns true if spell was successfully learned
func learn_spell(spell_id: String) -> bool:
	if knows_spell(spell_id):
		return false
	var spell = SpellManager.get_spell(spell_id)
	if spell == null:
		return false

	# Check if player has appropriate focus for this spell
	var focus_check = has_focus_for_spell(spell)
	if not focus_check.valid:
		print("Player cannot learn spell %s: %s" % [spell_id, focus_check.message])
		return false

	known_spells.append(spell_id)
	EventBus.spell_learned.emit(spell_id)
	print("Player learned spell: ", spell_id)
	return true

## Get all spells the player knows
func get_known_spells() -> Array:
	var result: Array = []
	for spell_id in known_spells:
		var spell = SpellManager.get_spell(spell_id)
		if spell:
			result.append(spell)
	return result

## Get spells the player can currently cast (knows spell + meets requirements)
func get_castable_spells() -> Array:
	var result: Array = []
	for spell_id in known_spells:
		var spell = SpellManager.get_spell(spell_id)
		if spell and SpellManager.can_cast(self, spell).can_cast:
			result.append(spell)
	return result


## Attempt to transcribe a spell from a scroll into the spellbook
## Returns a dictionary with success status and message
func attempt_transcription(scroll: Item) -> Dictionary:
	if not has_spellbook():
		return {"success": false, "consumed": false, "message": "You need a spellbook to transcribe spells."}

	var spell = SpellManager.get_spell(scroll.casts_spell)
	if spell == null:
		return {"success": false, "consumed": false, "message": "This scroll contains corrupted magic."}

	# Check if already known
	if knows_spell(spell.id):
		return {"success": false, "consumed": false, "message": "You already know this spell."}

	# Check INT requirement
	var player_int = get_effective_attribute("INT")
	if player_int < spell.requirements.get("intelligence", 8):
		return {"success": false, "consumed": false, "message": "This spell is too complex for you to understand."}

	# Check level requirement
	if level < spell.requirements.get("character_level", 1):
		return {"success": false, "consumed": false, "message": "You lack the experience to comprehend this magic."}

	# Calculate success chance
	var success_chance = calculate_transcription_chance(spell)

	# Roll for success
	var roll = randf() * 100.0
	var success = roll < success_chance

	if success:
		learn_spell(spell.id)
		EventBus.transcription_attempted.emit(scroll, spell, true)
		return {
			"success": true,
			"consumed": true,
			"message": "You successfully transcribe %s into your spellbook!" % spell.name
		}
	else:
		EventBus.transcription_attempted.emit(scroll, spell, false)
		return {
			"success": false,
			"consumed": true,
			"message": "The arcane symbols blur and fade. The scroll crumbles to dust."
		}


## Calculate the chance of successfully transcribing a spell
## Returns percentage (0-100)
func calculate_transcription_chance(spell) -> float:
	var level_diff = level - spell.level
	var base_chance: float

	# Base chance from level difference
	if level_diff <= 0:
		base_chance = 50.0
	elif level_diff == 1:
		base_chance = 65.0
	elif level_diff == 2:
		base_chance = 75.0
	elif level_diff == 3:
		base_chance = 85.0
	else:
		base_chance = 95.0

	# INT bonus: +2% per INT above requirement
	var int_above_req = get_effective_attribute("INT") - spell.requirements.get("intelligence", 8)
	base_chance += int_above_req * 2.0

	return clampf(base_chance, 10.0, 98.0)


## Get total casting bonuses from equipped items (staves, etc.)
## Returns dictionary with: success_modifier, school_affinity, school_damage_bonus, mana_cost_modifier
func get_casting_bonuses() -> Dictionary:
	var bonuses: Dictionary = {
		"success_modifier": 0,
		"mana_cost_modifier": 0,
		"school_bonuses": {}  # school_name -> damage_bonus
	}

	if not inventory:
		return bonuses

	# Check main hand for casting focus
	var main_hand = inventory.get_equipped("main_hand")
	if main_hand and main_hand.has_method("is_casting_focus") and main_hand.is_casting_focus():
		var item_bonuses = main_hand.get_casting_bonuses()
		bonuses.success_modifier += item_bonuses.get("success_modifier", 0)
		bonuses.mana_cost_modifier += item_bonuses.get("mana_cost_modifier", 0)

		# Handle school affinity bonuses
		var school = item_bonuses.get("school_affinity", "")
		if school != "":
			var school_bonus = item_bonuses.get("school_damage_bonus", 0)
			bonuses.school_bonuses[school] = bonuses.school_bonuses.get(school, 0) + school_bonus

	return bonuses


## Get total passive effects from all equipped items
## Returns dictionary with stat bonuses, resistances, etc.
func get_equipment_passive_effects() -> Dictionary:
	var total_effects: Dictionary = {
		"stat_bonuses": {},  # {STR: +1, INT: +2, etc.}
		"armor_bonus": 0,
		"max_mana_bonus": 0,
		"max_health_bonus": 0,
		"mana_regen_bonus": 0,
		"health_regen_bonus": 0,
		"resistances": {}  # {fire: 50, ice: 50, etc.}
	}

	if not inventory:
		return total_effects

	# Check all equipment slots for passive effects
	for slot in inventory.equipment:
		var item = inventory.equipment[slot]
		if item and item.has_method("has_passive_effects") and item.has_passive_effects():
			var effects = item.get_passive_effects()

			# Stat bonuses
			if effects.has("stat_bonuses"):
				for stat in effects.stat_bonuses:
					total_effects.stat_bonuses[stat] = total_effects.stat_bonuses.get(stat, 0) + effects.stat_bonuses[stat]

			# Direct stat bonuses (alternative format)
			for stat in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
				if effects.has(stat):
					total_effects.stat_bonuses[stat] = total_effects.stat_bonuses.get(stat, 0) + effects[stat]

			# Armor bonus
			if effects.has("armor_bonus"):
				total_effects.armor_bonus += effects.armor_bonus

			# Max mana bonus
			if effects.has("max_mana_bonus"):
				total_effects.max_mana_bonus += effects.max_mana_bonus

			# Max health bonus
			if effects.has("max_health_bonus"):
				total_effects.max_health_bonus += effects.max_health_bonus

			# Mana regen bonus
			if effects.has("mana_regen_bonus"):
				total_effects.mana_regen_bonus += effects.mana_regen_bonus

			# Health regen bonus
			if effects.has("health_regen_bonus"):
				total_effects.health_regen_bonus += effects.health_regen_bonus

			# Resistances (stacking with diminishing returns)
			if effects.has("resistances"):
				for resist_type in effects.resistances:
					var current = total_effects.resistances.get(resist_type, 0)
					var added = effects.resistances[resist_type]
					# Diminishing returns: 50 + 50 = 75, not 100
					total_effects.resistances[resist_type] = current + (100 - current) * added / 100.0

	return total_effects


## Override to include equipment passive effects in stat calculation
func _recalculate_effect_modifiers() -> void:
	# Reset stat modifiers
	for stat in stat_modifiers:
		stat_modifiers[stat] = 0

	# Reset armor modifier
	armor_modifier = 0

	# Apply magical effect modifiers (buffs/debuffs)
	for effect in active_effects:
		if effect.has("modifiers"):
			for stat in effect.modifiers:
				if stat in stat_modifiers:
					stat_modifiers[stat] += effect.modifiers[stat]
		if effect.has("armor_bonus"):
			armor_modifier += effect.armor_bonus

	# Apply equipment passive effects
	var equip_effects = get_equipment_passive_effects()
	for stat in equip_effects.stat_bonuses:
		if stat in stat_modifiers:
			stat_modifiers[stat] += equip_effects.stat_bonuses[stat]
	armor_modifier += equip_effects.armor_bonus


## Open a door at the given position
## If locked, attempts to unlock with key first (auto-unlock feature)
## Returns true if the door was opened, false if still locked or couldn't open
func _open_door(pos: Vector2i) -> bool:
	print("[DEBUG] _open_door called for pos: %v" % pos)
	if not MapManager.current_map:
		print("[DEBUG] _open_door: MapManager.current_map is null")
		return false

	var tile = MapManager.current_map.get_tile(pos)
	print("[DEBUG] _open_door: tile = %s, tile_type = %s" % [tile, tile.tile_type if tile else "null"])
	if not tile or tile.tile_type != "door":
		print("[DEBUG] _open_door: Not a door tile")
		return false

	# Check if the door is locked
	print("[DEBUG] _open_door: tile.is_locked = %s" % tile.is_locked)
	if tile.is_locked:
		# Try to unlock with a key (auto-unlock)
		var key_result = _LockSystem.try_unlock_with_key(tile.lock_id, tile.lock_level, inventory)
		if key_result.success:
			tile.unlock()
			EventBus.combat_message.emit(key_result.message, Color.GREEN)
			EventBus.lock_opened.emit(pos, "key")
			# Now open the door
			if tile.open_door():
				EventBus.combat_message.emit("You open the door.", Color.WHITE)
				_FOVSystem.invalidate_cache()
				EventBus.tile_changed.emit(pos)
				return true
		else:
			print("[DEBUG] _open_door: Door is locked, emitting combat_message signal")
			EventBus.combat_message.emit("The door is locked. Press Y to pick the lock.", Color.YELLOW)
			print("[DEBUG] _open_door: combat_message signal emitted")
		return false

	# Door is not locked, just open it
	if tile.open_door():
		EventBus.combat_message.emit("You open the door.", Color.WHITE)
		_FOVSystem.invalidate_cache()
		EventBus.tile_changed.emit(pos)
		return true

	return false

## Toggle a door in the given direction from player (open if closed, close if open)
## Returns true if door was toggled, false otherwise
## Note: For locked doors, use try_pick_lock() instead
func toggle_door(direction: Vector2i) -> bool:
	if not MapManager.current_map:
		return false

	var door_pos = position + direction
	var tile = MapManager.current_map.get_tile(door_pos)

	# Check if there's a door at the position
	if not tile or tile.tile_type != "door":
		return false

	if tile.is_open:
		# Try to close the door
		# Check if position is occupied by an entity
		if EntityManager.get_blocking_entity_at(door_pos):
			EventBus.combat_message.emit("Something is in the way.", Color.YELLOW)
			return false

		if tile.close_door():
			EventBus.combat_message.emit("You close the door.", Color.WHITE)
			_FOVSystem.invalidate_cache()
			EventBus.tile_changed.emit(door_pos)
			return true
	else:
		# Check if locked
		if tile.is_locked:
			# Try to unlock with key first (auto-unlock)
			var key_result = _LockSystem.try_unlock_with_key(tile.lock_id, tile.lock_level, inventory)
			if key_result.success:
				tile.unlock()
				EventBus.combat_message.emit(key_result.message, Color.GREEN)
				EventBus.lock_opened.emit(door_pos, "key")
				# Now open the door
				if tile.open_door():
					EventBus.combat_message.emit("You open the door.", Color.WHITE)
					_FOVSystem.invalidate_cache()
					EventBus.tile_changed.emit(door_pos)
					return true
			else:
				EventBus.combat_message.emit("The door is locked. Press Y to pick the lock.", Color.YELLOW)
				return false

		# Open the door
		if tile.open_door():
			EventBus.combat_message.emit("You open the door.", Color.WHITE)
			_FOVSystem.invalidate_cache()
			EventBus.tile_changed.emit(door_pos)
			return true

	return false

## Try to toggle any adjacent door (open or close)
## Returns true if a door was toggled
func try_toggle_adjacent_door() -> bool:
	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, 0),   # Right
	]

	for dir in directions:
		if toggle_door(dir):
			return true

	EventBus.combat_message.emit("No door nearby.", Color.GRAY)
	return false

## =========================================================================
## LEVELING SYSTEM
## =========================================================================

## Calculate XP needed to reach a specific level
## Formula: Fibonacci-like sequence (sum of prior two levels) * xp_multiplier
## Level 0: 0, Level 1: 100, Level 2: 200, Level 3+: (prev + prev_prev) * multiplier
static func calculate_xp_for_level(target_level: int) -> int:
	if target_level <= 0:
		return 0
	if target_level == 1:
		return 100
	if target_level == 2:
		return 200

	# For level 3+, use Fibonacci-like formula with configurable multiplier
	var prev_prev = 100  # Level 1
	var prev = 200       # Level 2
	var current = 0

	for i in range(3, target_level + 1):
		# Sum of previous two levels, multiplied by config
		var base_xp = prev + prev_prev
		current = int(base_xp * GameConfig.xp_multiplier)
		prev_prev = prev
		prev = current

	return current

## Calculate skill points earned for reaching a level
## Formula: ceil(level / skill_points_divisor)
static func calculate_skill_points_for_level(target_level: int) -> int:
	if target_level <= 0:
		return 0
	return int(ceil(float(target_level) / GameConfig.skill_points_divisor))

## Check if player qualifies for ability score increase
## Every N levels grants +1 to any ability score (N from GameConfig)
static func grants_ability_point(target_level: int) -> bool:
	return target_level > 0 and target_level % GameConfig.ability_point_interval == 0

## Gain experience and check for level-up
func gain_experience(amount: int) -> void:
	if amount <= 0:
		return

	# Apply racial XP bonus (e.g., Human Ambitious +10%)
	var xp_bonus = get_racial_xp_bonus()
	if xp_bonus > 0:
		amount = int(amount * (100.0 + xp_bonus) / 100.0)

	experience += amount

	# Check for level-up(s)
	while experience >= experience_to_next_level:
		_level_up()

## Handle level-up
func _level_up() -> void:
	level += 1

	# Calculate skill points for this level
	var skill_points = calculate_skill_points_for_level(level)
	available_skill_points += skill_points

	# Check for ability point
	if grants_ability_point(level):
		available_ability_points += 1

	# Update XP requirement for next level
	experience_to_next_level = calculate_xp_for_level(level + 1)

	# Emit level-up event
	EventBus.player_leveled_up.emit(level, skill_points, grants_ability_point(level))

## Spend a skill point on a specific skill
## Returns true if successful, false if invalid
func spend_skill_point(skill_name: String) -> bool:
	# Validation
	if not skills.has(skill_name):
		return false
	if available_skill_points <= 0:
		return false

	# Get max level from SkillManager (default to 20 if not available)
	var skill_max_level: int = 20
	var tree = Engine.get_main_loop()
	if tree and tree.root.has_node("SkillManager"):
		var skill_manager = tree.root.get_node("SkillManager")
		skill_max_level = skill_manager.get_skill_max_level(skill_name)

	# Cap at player level or skill's max_level (whichever is lower)
	var cap = mini(level, skill_max_level)
	if skills[skill_name] >= cap:
		return false

	# Spend the point
	available_skill_points -= 1
	skills[skill_name] += 1

	EventBus.skill_increased.emit(skill_name, skills[skill_name])
	return true


## Get the effective bonus for a skill
## Returns: skill_level (flat bonus system - +1 per level)
func get_skill_bonus(skill_id: String) -> int:
	return skills.get(skill_id, 0)


## Get weapon skill bonus for currently equipped weapon
## Returns the skill bonus for the weapon's type (e.g., Swords skill for swords)
func get_weapon_skill_bonus() -> int:
	if not inventory or not inventory.equipment:
		return 0

	var weapon = inventory.equipment.get("main_hand")
	if not weapon:
		return 0

	# Get the skill that applies to this weapon from SkillManager
	var tree = Engine.get_main_loop()
	if not tree or not tree.root.has_node("SkillManager"):
		return 0

	var skill_manager = tree.root.get_node("SkillManager")
	var skill_def = skill_manager.get_weapon_skill_for_weapon(weapon)
	if skill_def:
		return get_skill_bonus(skill_def.id)

	return 0

## Increase an ability score (from ability point)
## Returns true if successful, false if invalid
func increase_ability(ability_name: String) -> bool:
	# Validation
	if not attributes.has(ability_name):
		return false
	if available_ability_points <= 0:
		return false

	# Increase the ability
	available_ability_points -= 1
	attributes[ability_name] += 1

	# Recalculate derived stats
	_recalculate_derived_stats()

	EventBus.ability_increased.emit(ability_name, attributes[ability_name])
	return true

## Recalculate stats that depend on attributes
func _recalculate_derived_stats() -> void:
	# Update max health (10 + CON × 5)
	var old_max = max_health
	max_health = 10 + attributes["CON"] * 5

	# Adjust current health proportionally
	if old_max > 0:
		var health_ratio = float(current_health) / float(old_max)
		current_health = int(max_health * health_ratio)
	else:
		current_health = max_health

	# Update perception range (5 + WIS / 2)
	perception_range = 5 + int(attributes["WIS"] / 2.0)

	# Update survival system's base max stamina if it exists
	if survival:
		var old_base_stamina = survival.base_max_stamina
		survival.base_max_stamina = 50.0 + attributes["CON"] * 10.0

		# Adjust current stamina proportionally
		if old_base_stamina > 0:
			var stamina_ratio = survival.stamina / old_base_stamina
			survival.stamina = min(survival.base_max_stamina, survival.base_max_stamina * stamina_ratio)

	# Update inventory max weight if it exists
	if inventory:
		inventory.max_weight = 20.0 + attributes["STR"] * 5.0

## Get current skill level for a specific skill
func get_skill_level(skill_name: String) -> int:
	return skills.get(skill_name, 0)

## =========================================================================
## DEATH TRACKING
## =========================================================================

## Record death details
func record_death(cause: String, method: String = "", location: String = "") -> void:
	death_cause = cause
	death_method = method
	death_location = location if location != "" else _get_current_location()

## Get current location description
func _get_current_location() -> String:
	if not MapManager.current_map:
		return "an Unknown Location"

	var map_id = MapManager.current_map.map_id

	# Check if in dungeon (format: "<dungeon_type>_floor_<number>")
	if "_floor_" in map_id:
		var floor_idx = map_id.find("_floor_")
		var dungeon_type = map_id.substr(0, floor_idx)  # e.g., "sewers", "burial_barrow"
		var floor_num = map_id.substr(floor_idx + 7)  # Get number after "_floor_"

		# Format dungeon name nicely
		var dungeon_name = dungeon_type.replace("_", " ").capitalize()
		return "%s Floor %s" % [dungeon_name, floor_num]

	# Check if in town
	if map_id.begins_with("town_"):
		# Format: "town_<name>"
		var town_name = map_id.substr(5).replace("_", " ").capitalize()
		return "the Town of %s" % town_name

	# Otherwise, in wilderness - get terrain description
	elif map_id == "overworld":
		# Get tile type for terrain description
		var tile = MapManager.current_map.get_tile(position)
		if tile:
			match tile.tile_type:
				"grass":
					return "the Grasslands"
				"tree":
					return "the Forest"
				"water":
					return "the Waterside"
				"wheat":
					return "the Farmlands"
				"dirt", "path":
					return "the Wilderness"
				_:
					return "the Wilderness"
		return "the Wilderness"

	return "an Unknown Location"

## Override take_damage to track death source and check concentration
func take_damage(amount: int, source: String = "Unknown", method: String = "") -> void:
	# Check if this damage will kill us BEFORE applying it
	var will_die = (current_health - amount) <= 0

	# Check for Relentless Endurance (Half-Orc trait) before lethal damage
	if will_die and has_racial_trait("relentless") and can_use_racial_ability("relentless"):
		# Survive with 1 HP
		var blocked_damage = current_health - 1
		amount = blocked_damage if blocked_damage > 0 else 0
		use_racial_ability("relentless")
		EventBus.message_logged.emit("Relentless Endurance! You refuse to fall, surviving with 1 HP!")
		will_die = false

	# Record death cause BEFORE calling super, because super.take_damage() calls die()
	# which emits entity_died signal synchronously - game.gd reads death_cause immediately
	if will_die:
		record_death(source, method)

	super.take_damage(amount, source, method)

	# Check concentration after taking damage (if still alive)
	if is_alive and concentration_spell != "":
		check_concentration(amount)

## Get death summary for death screen
func get_death_summary() -> String:
	if death_cause == "":
		return "You died."

	var summary = "You were killed by [color=#ff8888]%s[/color]" % death_cause

	if death_method != "":
		summary += " with [color=#ffaa66]%s[/color]" % death_method

	if death_location != "":
		summary += " in [color=#88ccff]%s[/color]" % death_location

	summary += "."
	return summary


## Parse Vector2i from string format (handles save data serialization)
## Strings are in format "(x, y)" from JSON serialization
func _parse_vector2i(value) -> Vector2i:
	# Already a Vector2i - return as is
	if value is Vector2i:
		return value

	# String format - parse it
	if value is String:
		var cleaned = value.strip_edges().replace("(", "").replace(")", "")
		var parts = cleaned.split(",")
		if parts.size() != 2:
			push_warning("[Player] Invalid Vector2i string format: %s" % value)
			return Vector2i.ZERO
		return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))

	# Dictionary format (alternative serialization)
	if value is Dictionary:
		return Vector2i(value.get("x", 0), value.get("y", 0))

	push_warning("[Player] Cannot parse Vector2i from type: %s" % typeof(value))
	return Vector2i.ZERO
