# Refactor 10: Player Components

**Risk Level**: Medium-High
**Estimated Changes**: 4 new files, 1 file significantly reduced

---

## Goal

Decompose the `player.gd` god object (1,970 lines) into focused components using composition:
- SummonComponent - Handles summoned creature management
- RaceComponent - Handles racial traits and abilities
- ClassComponent - Handles class feats and progression
- ConcentrationComponent - Handles concentration spell mechanics

---

## Current State

### entities/player.gd (1,970 lines)
The Player class handles too many responsibilities:
- Core entity state (position, HP, attributes) - Keep in Player
- Summon management (~200 lines) - Extract
- Concentration mechanics (~150 lines) - Extract
- Racial traits and abilities (~100 lines) - Extract
- Class feats and mechanics (~100 lines) - Extract
- Inventory/equipment - Delegates to Inventory class
- Combat - Delegates to CombatSystem
- Survival - Delegates to SurvivalSystem

---

## Implementation

### Step 1: Create entities/components/ Directory

```bash
mkdir -p entities/components
```

---

### Step 2: Create entities/components/summon_component.gd

```gdscript
class_name SummonComponent
extends RefCounted

## SummonComponent - Manages summoned creatures for player
##
## Handles adding, removing, commanding, and updating summons.

signal summon_added(summon: Entity)
signal summon_removed(summon: Entity)
signal summons_cleared()

# Maximum number of active summons
const MAX_SUMMONS: int = 3

# Active summons
var summons: Array[Entity] = []

# Owner reference
var _owner: Entity = null


func _init(owner: Entity = null) -> void:
	_owner = owner


func set_owner(owner: Entity) -> void:
	_owner = owner


## Add a summon to the player's control
func add_summon(summon: Entity) -> bool:
	if summon == null:
		return false

	if summons.size() >= MAX_SUMMONS:
		EventBus.message_logged.emit("You cannot control any more summons.")
		return false

	if summon in summons:
		return false

	summons.append(summon)
	summon.is_summoned = true
	summon.summoner = _owner

	# Mark as friendly
	if "faction" in summon:
		summon.faction = "player"

	summon_added.emit(summon)
	EventBus.message_logged.emit("You gain control of %s." % summon.display_name)
	return true


## Remove a summon from control
func remove_summon(summon: Entity) -> void:
	if summon == null or summon not in summons:
		return

	summons.erase(summon)
	summon.is_summoned = false
	summon.summoner = null

	summon_removed.emit(summon)


## Dismiss a summon (remove and despawn)
func dismiss_summon(summon: Entity) -> void:
	if summon == null or summon not in summons:
		return

	remove_summon(summon)

	# Remove from game
	EntityManager.remove_entity(summon)
	EventBus.message_logged.emit("%s fades away." % summon.display_name)


## Dismiss all summons
func dismiss_all_summons() -> void:
	var summons_to_dismiss = summons.duplicate()
	for summon in summons_to_dismiss:
		dismiss_summon(summon)
	summons_cleared.emit()


## Get all active summons
func get_summons() -> Array[Entity]:
	return summons


## Get summon count
func get_summon_count() -> int:
	return summons.size()


## Check if at summon capacity
func is_at_capacity() -> bool:
	return summons.size() >= MAX_SUMMONS


## Check if entity is a summon of this player
func is_my_summon(entity: Entity) -> bool:
	return entity in summons


## Process summon turns (called during turn processing)
func process_summon_turns() -> void:
	for summon in summons:
		if summon.hp <= 0:
			# Summon died
			remove_summon(summon)
			continue

		# Summons follow player by default
		if summon.has_method("take_turn"):
			_command_summon_follow(summon)
			summon.take_turn()


## Command summon to follow player
func _command_summon_follow(summon: Entity) -> void:
	if _owner == null:
		return

	# Set target to move near player
	var target_pos = _find_position_near_owner()
	if summon.has_method("set_move_target"):
		summon.set_move_target(target_pos)


## Find empty position near owner
func _find_position_near_owner() -> Vector2i:
	if _owner == null:
		return Vector2i.ZERO

	var map = MapManager.current_map
	if map == null:
		return _owner.position

	# Check adjacent positions
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1),
	]

	for dir in directions:
		var pos = _owner.position + dir
		if map.is_walkable(pos) and not EntityManager.get_entity_at(pos):
			return pos

	return _owner.position


## Handle summon death
func on_summon_died(summon: Entity) -> void:
	if summon in summons:
		remove_summon(summon)
		EventBus.message_logged.emit("%s has been destroyed." % summon.display_name)


## Serialize summon state
func serialize() -> Array:
	var result: Array = []
	for summon in summons:
		result.append({
			"enemy_id": summon.enemy_id if "enemy_id" in summon else "",
			"position": {"x": summon.position.x, "y": summon.position.y},
			"hp": summon.hp,
			"max_hp": summon.max_hp,
		})
	return result


## Deserialize summon state
func deserialize(data: Array) -> void:
	dismiss_all_summons()

	for summon_data in data:
		if summon_data.enemy_id.is_empty():
			continue

		var pos = Vector2i(summon_data.position.x, summon_data.position.y)
		var summon = EntityManager.spawn_enemy(summon_data.enemy_id, pos)
		if summon:
			summon.hp = summon_data.get("hp", summon.max_hp)
			add_summon(summon)
```

---

### Step 3: Create entities/components/concentration_component.gd

```gdscript
class_name ConcentrationComponent
extends RefCounted

## ConcentrationComponent - Manages concentration spell mechanics
##
## Tracks active concentration spells and handles interruption.

signal concentration_started(spell)
signal concentration_ended(spell)
signal concentration_broken(spell, reason: String)

# Currently concentrating spell
var active_spell = null
var spell_target: Vector2i = Vector2i.ZERO
var duration_remaining: int = 0

# Owner reference
var _owner: Entity = null


func _init(owner: Entity = null) -> void:
	_owner = owner


func set_owner(owner: Entity) -> void:
	_owner = owner


## Start concentrating on a spell
func start_concentration(spell, target: Vector2i, duration: int) -> bool:
	if spell == null:
		return false

	# Break existing concentration
	if active_spell != null:
		break_concentration("Started new concentration spell")

	active_spell = spell
	spell_target = target
	duration_remaining = duration

	concentration_started.emit(spell)
	EventBus.message_logged.emit("You begin concentrating on %s." % spell.name)
	return true


## End concentration normally (spell completed or dismissed)
func end_concentration() -> void:
	if active_spell == null:
		return

	var spell = active_spell
	active_spell = null
	spell_target = Vector2i.ZERO
	duration_remaining = 0

	concentration_ended.emit(spell)
	EventBus.message_logged.emit("You stop concentrating on %s." % spell.name)


## Break concentration (interrupted by damage, movement, etc.)
func break_concentration(reason: String = "Interrupted") -> void:
	if active_spell == null:
		return

	var spell = active_spell
	active_spell = null
	spell_target = Vector2i.ZERO
	duration_remaining = 0

	concentration_broken.emit(spell, reason)
	EventBus.message_logged.emit("Your concentration on %s is broken! (%s)" % [spell.name, reason])

	# Handle spell end effects
	_on_spell_broken(spell)


## Check if currently concentrating
func is_concentrating() -> bool:
	return active_spell != null


## Get current concentration spell
func get_active_spell():
	return active_spell


## Get concentration target position
func get_target() -> Vector2i:
	return spell_target


## Process turn (reduce duration, maintain effects)
func process_turn() -> void:
	if active_spell == null:
		return

	duration_remaining -= 1

	if duration_remaining <= 0:
		EventBus.message_logged.emit("%s spell duration expired." % active_spell.name)
		end_concentration()
		return

	# Maintain spell effects
	_maintain_spell_effects()


## Called when damage is taken - may break concentration
func on_damage_taken(damage: int) -> bool:
	if active_spell == null:
		return false

	# Concentration check: CON save vs 10 or half damage (whichever higher)
	var dc = maxi(10, damage / 2)
	var con_mod = 0
	if _owner and "attributes" in _owner:
		con_mod = (_owner.attributes.get("CON", 10) - 10) / 2

	var roll = randi() % 20 + 1 + con_mod

	if roll < dc:
		break_concentration("Took %d damage (failed CON save %d vs DC %d)" % [damage, roll, dc])
		return true

	return false


## Maintain ongoing spell effects
func _maintain_spell_effects() -> void:
	if active_spell == null or _owner == null:
		return

	# Different spells have different maintenance effects
	# This would be expanded based on spell definitions
	pass


## Handle spell being broken
func _on_spell_broken(spell) -> void:
	# Clean up any ongoing effects
	# E.g., dismiss summoned creatures, end buffs, etc.

	if spell.has("summon_on_break"):
		# Remove summoned creatures when concentration breaks
		if _owner and _owner.has_method("dismiss_all_summons"):
			_owner.dismiss_all_summons()


## Serialize concentration state
func serialize() -> Dictionary:
	if active_spell == null:
		return {}

	return {
		"spell_id": active_spell.id if "id" in active_spell else "",
		"target": {"x": spell_target.x, "y": spell_target.y},
		"duration": duration_remaining,
	}


## Deserialize concentration state (just stores data, actual restoration happens later)
func deserialize(data: Dictionary) -> void:
	# Concentration is complex to restore - store pending data
	if data.is_empty():
		return

	# This would need to re-cast the spell on load
	# For now, just note that concentration was active
	if "spell_id" in data and not data.spell_id.is_empty():
		EventBus.message_logged.emit("(Concentration spell was active before save)")
```

---

### Step 4: Create entities/components/race_component.gd

```gdscript
class_name RaceComponent
extends RefCounted

## RaceComponent - Manages racial traits and abilities
##
## Handles racial bonuses, abilities, and special mechanics.

signal ability_used(ability_id: String)
signal ability_cooldown_ended(ability_id: String)

# Race ID
var race_id: String = ""

# Racial abilities (list of ability IDs)
var abilities: Array[String] = []

# Ability cooldowns (ability_id -> turns remaining)
var cooldowns: Dictionary = {}

# Owner reference
var _owner: Entity = null


func _init(owner: Entity = null) -> void:
	_owner = owner


func set_owner(owner: Entity) -> void:
	_owner = owner


## Set race and apply initial bonuses
func set_race(id: String) -> void:
	race_id = id

	var race_data = RaceManager.get_race(id)
	if race_data == null:
		push_warning("RaceComponent: Unknown race ID: %s" % id)
		return

	# Get racial abilities
	abilities = race_data.get("abilities", []).duplicate()

	# Apply attribute bonuses
	if _owner and "attributes" in _owner:
		var bonuses = race_data.get("attribute_bonuses", {})
		for attr in bonuses:
			if attr in _owner.attributes:
				_owner.attributes[attr] += bonuses[attr]


## Get list of racial abilities
func get_abilities() -> Array[String]:
	return abilities


## Check if has a specific ability
func has_ability(ability_id: String) -> bool:
	return ability_id in abilities


## Use a racial ability
func use_ability(ability_id: String) -> Dictionary:
	if not has_ability(ability_id):
		return {"success": false, "message": "You don't have that ability"}

	if is_on_cooldown(ability_id):
		var remaining = cooldowns.get(ability_id, 0)
		return {"success": false, "message": "Ability on cooldown (%d turns)" % remaining}

	var ability_data = RaceManager.get_ability(ability_id)
	if ability_data == null:
		return {"success": false, "message": "Unknown ability"}

	# Execute ability
	var result = _execute_ability(ability_id, ability_data)

	if result.success:
		# Set cooldown
		var cooldown = ability_data.get("cooldown", 0)
		if cooldown > 0:
			cooldowns[ability_id] = cooldown

		ability_used.emit(ability_id)

	return result


## Check if ability is on cooldown
func is_on_cooldown(ability_id: String) -> bool:
	return cooldowns.get(ability_id, 0) > 0


## Get remaining cooldown for ability
func get_cooldown(ability_id: String) -> int:
	return cooldowns.get(ability_id, 0)


## Process turn (reduce cooldowns)
func process_turn() -> void:
	var expired: Array[String] = []

	for ability_id in cooldowns:
		cooldowns[ability_id] -= 1
		if cooldowns[ability_id] <= 0:
			expired.append(ability_id)

	for ability_id in expired:
		cooldowns.erase(ability_id)
		ability_cooldown_ended.emit(ability_id)


## Execute a racial ability
func _execute_ability(ability_id: String, data: Dictionary) -> Dictionary:
	var ability_type = data.get("type", "")

	match ability_type:
		"heal":
			return _execute_heal_ability(data)
		"buff":
			return _execute_buff_ability(data)
		"damage":
			return _execute_damage_ability(data)
		"utility":
			return _execute_utility_ability(ability_id, data)
		_:
			return {"success": false, "message": "Unknown ability type"}


func _execute_heal_ability(data: Dictionary) -> Dictionary:
	if _owner == null:
		return {"success": false, "message": "No owner"}

	var amount = data.get("amount", 10)
	var healed = mini(amount, _owner.max_hp - _owner.hp)
	_owner.hp += healed

	EventBus.player_health_changed.emit(_owner.hp, _owner.max_hp)
	return {"success": true, "message": "Healed %d HP" % healed}


func _execute_buff_ability(data: Dictionary) -> Dictionary:
	if _owner == null or not _owner.has_method("add_buff"):
		return {"success": false, "message": "Cannot apply buff"}

	var buff_id = data.get("buff_id", "")
	var duration = data.get("duration", 10)
	_owner.add_buff(buff_id, {"duration": duration})

	return {"success": true, "message": "Activated %s" % data.get("name", "ability")}


func _execute_damage_ability(data: Dictionary) -> Dictionary:
	# Would need target selection
	return {"success": false, "message": "Damage abilities need targeting"}


func _execute_utility_ability(ability_id: String, data: Dictionary) -> Dictionary:
	# Handle specific utility abilities
	match ability_id:
		"darkvision":
			# Toggle darkvision
			return {"success": true, "message": "Your eyes adjust to the darkness"}
		"detect_traps":
			# Reveal nearby traps
			return _detect_nearby_traps()
		_:
			return {"success": true, "message": "Used %s" % data.get("name", ability_id)}


func _detect_nearby_traps() -> Dictionary:
	if _owner == null:
		return {"success": false, "message": "No owner"}

	var detected = HazardManager.reveal_hazards_near(_owner.position, 5)
	if detected > 0:
		return {"success": true, "message": "Detected %d hidden traps!" % detected}
	return {"success": true, "message": "No traps detected nearby"}


## Serialize race state
func serialize() -> Dictionary:
	return {
		"race_id": race_id,
		"abilities": abilities.duplicate(),
		"cooldowns": cooldowns.duplicate(),
	}


## Deserialize race state
func deserialize(data: Dictionary) -> void:
	race_id = data.get("race_id", "")
	abilities = data.get("abilities", []).duplicate()
	cooldowns = data.get("cooldowns", {}).duplicate()
```

---

### Step 5: Create entities/components/class_component.gd

```gdscript
class_name ClassComponent
extends RefCounted

## ClassComponent - Manages class feats and progression
##
## Handles class-specific abilities, feat unlocking, and specialization.

signal feat_unlocked(feat_id: String)
signal feat_used(feat_id: String)

# Class ID
var class_id: String = ""

# Unlocked feats
var feats: Array[String] = []

# Feat cooldowns
var cooldowns: Dictionary = {}

# Specialization (if applicable)
var specialization: String = ""

# Owner reference
var _owner: Entity = null


func _init(owner: Entity = null) -> void:
	_owner = owner


func set_owner(owner: Entity) -> void:
	_owner = owner


## Set class and apply initial feats
func set_class(id: String) -> void:
	class_id = id

	var class_data = ClassManager.get_class(id)
	if class_data == null:
		push_warning("ClassComponent: Unknown class ID: %s" % id)
		return

	# Get starting feats
	feats = class_data.get("starting_feats", []).duplicate()


## Get list of unlocked feats
func get_feats() -> Array[String]:
	return feats


## Check if has a specific feat
func has_feat(feat_id: String) -> bool:
	return feat_id in feats


## Unlock a new feat (from leveling)
func unlock_feat(feat_id: String) -> bool:
	if feat_id in feats:
		return false  # Already have it

	var feat_data = ClassManager.get_feat(feat_id)
	if feat_data == null:
		return false

	# Check prerequisites
	if not _meets_feat_prerequisites(feat_data):
		return false

	feats.append(feat_id)
	feat_unlocked.emit(feat_id)
	EventBus.message_logged.emit("Unlocked feat: %s" % feat_data.get("name", feat_id))
	return true


## Use a class feat
func use_feat(feat_id: String) -> Dictionary:
	if not has_feat(feat_id):
		return {"success": false, "message": "You don't have that feat"}

	if is_on_cooldown(feat_id):
		var remaining = cooldowns.get(feat_id, 0)
		return {"success": false, "message": "Feat on cooldown (%d turns)" % remaining}

	var feat_data = ClassManager.get_feat(feat_id)
	if feat_data == null:
		return {"success": false, "message": "Unknown feat"}

	# Check resource cost
	var cost = feat_data.get("stamina_cost", 0)
	if cost > 0 and _owner and _owner.stamina < cost:
		return {"success": false, "message": "Not enough stamina (%d required)" % cost}

	# Execute feat
	var result = _execute_feat(feat_id, feat_data)

	if result.success:
		# Pay cost
		if cost > 0 and _owner:
			_owner.stamina -= cost
			EventBus.player_stamina_changed.emit(_owner.stamina, _owner.max_stamina)

		# Set cooldown
		var cooldown = feat_data.get("cooldown", 0)
		if cooldown > 0:
			cooldowns[feat_id] = cooldown

		feat_used.emit(feat_id)

	return result


## Check if feat is on cooldown
func is_on_cooldown(feat_id: String) -> bool:
	return cooldowns.get(feat_id, 0) > 0


## Process turn (reduce cooldowns)
func process_turn() -> void:
	var expired: Array[String] = []

	for feat_id in cooldowns:
		cooldowns[feat_id] -= 1
		if cooldowns[feat_id] <= 0:
			expired.append(feat_id)

	for feat_id in expired:
		cooldowns.erase(feat_id)


## Get feats available at a given level
func get_feats_for_level(level: int) -> Array[String]:
	var class_data = ClassManager.get_class(class_id)
	if class_data == null:
		return []

	var available: Array[String] = []
	var feat_progression = class_data.get("feat_progression", {})

	for lvl in feat_progression:
		if int(lvl) <= level:
			for feat_id in feat_progression[lvl]:
				if feat_id not in feats:
					available.append(feat_id)

	return available


## Check if prerequisites are met for a feat
func _meets_feat_prerequisites(feat_data: Dictionary) -> bool:
	var prereqs = feat_data.get("prerequisites", {})

	# Level requirement
	if "level" in prereqs:
		if _owner == null or _owner.level < prereqs.level:
			return false

	# Required feats
	if "feats" in prereqs:
		for required_feat in prereqs.feats:
			if required_feat not in feats:
				return false

	# Stat requirements
	if "attributes" in prereqs and _owner:
		for attr in prereqs.attributes:
			if _owner.attributes.get(attr, 0) < prereqs.attributes[attr]:
				return false

	return true


## Execute a class feat
func _execute_feat(feat_id: String, data: Dictionary) -> Dictionary:
	var feat_type = data.get("type", "")

	match feat_type:
		"attack":
			return _execute_attack_feat(data)
		"buff":
			return _execute_buff_feat(data)
		"passive":
			return {"success": true, "message": "Passive feat active"}
		_:
			return {"success": true, "message": "Used %s" % data.get("name", feat_id)}


func _execute_attack_feat(data: Dictionary) -> Dictionary:
	# Would need target selection and combat integration
	var damage_bonus = data.get("damage_bonus", 0)
	return {"success": true, "message": "Next attack deals +%d damage" % damage_bonus, "damage_bonus": damage_bonus}


func _execute_buff_feat(data: Dictionary) -> Dictionary:
	if _owner == null or not _owner.has_method("add_buff"):
		return {"success": false, "message": "Cannot apply buff"}

	var buff_id = data.get("buff_id", "")
	var duration = data.get("duration", 5)
	_owner.add_buff(buff_id, {"duration": duration})

	return {"success": true, "message": "Activated %s" % data.get("name", "feat")}


## Serialize class state
func serialize() -> Dictionary:
	return {
		"class_id": class_id,
		"feats": feats.duplicate(),
		"cooldowns": cooldowns.duplicate(),
		"specialization": specialization,
	}


## Deserialize class state
func deserialize(data: Dictionary) -> void:
	class_id = data.get("class_id", "")
	feats = data.get("feats", []).duplicate()
	cooldowns = data.get("cooldowns", {}).duplicate()
	specialization = data.get("specialization", "")
```

---

### Step 6: Update entities/player.gd

1. **Add preloads and component instances**:
```gdscript
const SummonComponentClass = preload("res://entities/components/summon_component.gd")
const ConcentrationComponentClass = preload("res://entities/components/concentration_component.gd")
const RaceComponentClass = preload("res://entities/components/race_component.gd")
const ClassComponentClass = preload("res://entities/components/class_component.gd")

# Components
var summon_component: SummonComponent = null
var concentration_component: ConcentrationComponent = null
var race_component: RaceComponent = null
var class_component: ClassComponent = null
```

2. **Initialize components in `_init()`**:
```gdscript
func _init() -> void:
	summon_component = SummonComponentClass.new(self)
	concentration_component = ConcentrationComponentClass.new(self)
	race_component = RaceComponentClass.new(self)
	class_component = ClassComponentClass.new(self)
```

3. **Delegate methods to components**:
```gdscript
# Summons
func add_summon(summon: Entity) -> bool:
	return summon_component.add_summon(summon)

func dismiss_summon(summon: Entity) -> void:
	summon_component.dismiss_summon(summon)

func get_summons() -> Array[Entity]:
	return summon_component.get_summons()

# Concentration
func start_concentration(spell, target: Vector2i, duration: int) -> bool:
	return concentration_component.start_concentration(spell, target, duration)

func is_concentrating() -> bool:
	return concentration_component.is_concentrating()

# Race
func set_race(id: String) -> void:
	race_component.set_race(id)
	race_id = id

func use_racial_ability(ability_id: String) -> Dictionary:
	return race_component.use_ability(ability_id)

# Class
func set_class(id: String) -> void:
	class_component.set_class(id)
	class_id = id

func use_class_feat(feat_id: String) -> Dictionary:
	return class_component.use_feat(feat_id)
```

4. **Update `process_turn()`** to use components:
```gdscript
func process_turn() -> void:
	# ... existing code ...

	# Process component turns
	race_component.process_turn()
	class_component.process_turn()
	concentration_component.process_turn()
	summon_component.process_summon_turns()
```

5. **Remove old implementation code** for:
- Summon management methods
- Concentration methods
- Racial ability methods
- Class feat methods

---

## Files Summary

### New Files
- `entities/components/summon_component.gd` (~200 lines)
- `entities/components/concentration_component.gd` (~180 lines)
- `entities/components/race_component.gd` (~200 lines)
- `entities/components/class_component.gd` (~220 lines)

### Modified Files
- `entities/player.gd` - Reduced from 1,970 to ~800 lines

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Create new character
  - [ ] Select race - bonuses apply
  - [ ] Select class - starting feats granted
- [ ] Racial abilities
  - [ ] View racial abilities in character sheet
  - [ ] Use racial ability
  - [ ] Cooldown applies and counts down
- [ ] Class feats
  - [ ] View class feats in character sheet
  - [ ] Use class feat
  - [ ] Cooldown applies
  - [ ] Level up unlocks new feats
- [ ] Summons (if implemented)
  - [ ] Cast summoning spell
  - [ ] Summon follows player
  - [ ] Summon attacks enemies
  - [ ] Dismiss summon
- [ ] Concentration
  - [ ] Cast concentration spell
  - [ ] Effect maintained
  - [ ] Taking damage may break concentration
  - [ ] Manual end concentration
- [ ] Save and load
  - [ ] All component state preserved
  - [ ] Cooldowns persist
  - [ ] Summons restored (if saved)
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
rm -rf entities/components/
git checkout HEAD -- entities/player.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
