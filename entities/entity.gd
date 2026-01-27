class_name Entity

## Entity - Base class for all game entities
##
## Represents any entity in the game: player, enemies, NPCs, items.
## Uses component-based architecture for extensibility.

# Core identity
var entity_id: String = ""
var entity_type: String = ""  # "player", "enemy", "npc", "item"
var name: String = ""

# Spatial
var position: Vector2i = Vector2i.ZERO
var blocks_movement: bool = true
var source_chunk: Vector2i = Vector2i(-999, -999)  # Chunk that spawned this entity (-999 = not chunk-spawned)

# Visual
var ascii_char: String = "?"
var color: Color = Color.WHITE

# Special properties
var is_fire_source: bool = false  # Used for proximity crafting (campfires, torches)

# Stats (for entities that have them - enemies, player)
var attributes: Dictionary = {
	"STR": 10,
	"DEX": 10,
	"CON": 10,
	"INT": 10,
	"WIS": 10,
	"CHA": 10
}

# Combat stats
var max_health: int = 0
var current_health: int = 0
var is_alive: bool = true
var base_damage: int = 1  # Unarmed/natural weapon damage
var armor: int = 0  # Damage reduction

# Creature type for mind control immunity and damage resistances
var creature_type: String = "humanoid"
var element_subtype: String = ""  # Optional subtype (fire, ice, earth, air) for elementals
var faction: String = "neutral"  # player, enemy, neutral, hostile_to_all
var ai_state: String = "normal"  # normal, fleeing, berserk, idle

# Stat modifiers from survival/effects (applied on top of base attributes)
var stat_modifiers: Dictionary = {
	"STR": 0,
	"DEX": 0,
	"CON": 0,
	"INT": 0,
	"WIS": 0,
	"CHA": 0
}

# Armor modifier (from buffs)
var armor_modifier: int = 0

# Damage resistances: -100 (immune) to 0 (normal) to +100 (vulnerable)
# Negative = resistance, Positive = vulnerability
# Applies to all damage types: physical, elemental, and magic
var elemental_resistances: Dictionary = {
	# Physical damage types
	"slashing": 0,
	"piercing": 0,
	"bludgeoning": 0,
	# Elemental damage types
	"fire": 0,
	"ice": 0,
	"lightning": 0,
	"poison": 0,
	"acid": 0,
	# Magic damage types
	"necrotic": 0,
	"radiant": 0
}

# Active magical effects (buffs/debuffs with duration)
# Each effect: {id, type, modifiers, remaining_duration, source_spell, armor_bonus}
var active_effects: Array[Dictionary] = []

# Components (composition pattern)
var components: Dictionary = {}  # component_name -> component instance

func _init(id: String = "", pos: Vector2i = Vector2i.ZERO, display_char: String = "?", entity_color: Color = Color.WHITE, blocks: bool = true) -> void:
	entity_id = id
	position = pos
	ascii_char = display_char
	color = entity_color
	blocks_movement = blocks
	_calculate_derived_stats()

## Calculate derived stats from attributes
func _calculate_derived_stats() -> void:
	# Health: Base 10 + (CON × 5)
	max_health = 10 + (attributes["CON"] * 5)
	current_health = max_health

## Take damage
## source: What caused the damage (e.g., enemy name, "Starvation", "Dehydration")
## method: How the damage was dealt (e.g., weapon name, "survival")
func take_damage(amount: int, source: String = "Unknown", method: String = "") -> void:
	# Check for god mode (only applies to player)
	if name == "Player" and GameManager.debug_god_mode:
		return  # No damage in god mode

	var old_hp = current_health
	current_health = max(0, current_health - amount)
	print("[Entity] %s took %d damage from %s (HP: %d -> %d)" % [name, amount, source, old_hp, current_health])

	if current_health <= 0:
		print("[Entity] %s HP reached 0 - calling die()" % name)
		die()

## Heal
func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)

## Handle death
func die() -> void:
	print("[Entity] die() called for %s - setting is_alive=false and emitting entity_died" % name)
	is_alive = false
	blocks_movement = false
	EventBus.entity_died.emit(self)
	print("[Entity] entity_died signal emitted for %s" % name)

## Get effective attribute value (base + modifiers)
func get_effective_attribute(attr_name: String) -> int:
	var base_value = attributes.get(attr_name, 10)
	var modifier = stat_modifiers.get(attr_name, 0)
	return max(1, base_value + modifier)

## Apply stat modifiers (from survival, effects, etc.)
func apply_stat_modifiers(modifiers: Dictionary) -> void:
	for stat_name in modifiers:
		if stat_name in stat_modifiers:
			stat_modifiers[stat_name] = modifiers[stat_name]

## Clear all stat modifiers
func clear_stat_modifiers() -> void:
	for stat_name in stat_modifiers:
		stat_modifiers[stat_name] = 0

## Add a component
func add_component(component_name: String, component: Variant) -> void:
	components[component_name] = component

## Get a component
func get_component(component_name: String) -> Variant:
	return components.get(component_name, null)

## Check if has component
func has_component(component_name: String) -> bool:
	return component_name in components


## Add a magical effect (buff or debuff)
## If the same effect already exists, refresh its duration instead of stacking
func add_magical_effect(effect: Dictionary) -> void:
	# Check if effect already exists (refresh duration)
	for existing in active_effects:
		if existing.id == effect.id:
			existing.remaining_duration = effect.remaining_duration
			_recalculate_effect_modifiers()
			return

	active_effects.append(effect)
	_recalculate_effect_modifiers()
	EventBus.effect_applied.emit(self, effect)


## Remove a magical effect by ID
func remove_magical_effect(effect_id: String) -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		if active_effects[i].id == effect_id:
			var effect = active_effects[i]
			# Handle mind effect state restoration
			_handle_mind_effect_expiration(effect)
			active_effects.remove_at(i)
			EventBus.effect_removed.emit(self, effect)
	_recalculate_effect_modifiers()


## Get a specific active effect by ID
func get_active_effect(effect_id: String) -> Dictionary:
	for effect in active_effects:
		if effect.id == effect_id:
			return effect
	return {}


## Check if entity has a specific effect active
func has_active_effect(effect_id: String) -> bool:
	for effect in active_effects:
		if effect.id == effect_id:
			return true
	return false


## Get all active buff effects
func get_active_buffs() -> Array[Dictionary]:
	var buffs: Array[Dictionary] = []
	for effect in active_effects:
		if effect.get("type", "") == "buff":
			buffs.append(effect)
	return buffs


## Get all active debuff effects
func get_active_debuffs() -> Array[Dictionary]:
	var debuffs: Array[Dictionary] = []
	for effect in active_effects:
		if effect.get("type", "") == "debuff":
			debuffs.append(effect)
	return debuffs


## Process effect durations (call each turn)
func process_effect_durations() -> void:
	var expired: Array[String] = []

	for effect in active_effects:
		effect.remaining_duration -= 1
		if effect.remaining_duration <= 0:
			expired.append(effect.id)

	for effect_id in expired:
		# Get the effect name before removing
		var effect_name = effect_id.replace("_buff", "").replace("_debuff", "").replace("_dot", "")
		remove_magical_effect(effect_id)
		EventBus.message_logged.emit("The effect of %s has worn off." % effect_name, Color.GRAY)


## Process DoT (Damage over Time) effects
## Call this each turn BEFORE process_effect_durations
## Returns total DoT damage dealt this turn
func process_dot_effects() -> int:
	var total_damage = 0

	for effect in active_effects:
		if effect.get("type") == "dot":
			var damage = effect.get("damage_per_turn", 0)
			if damage > 0:
				total_damage += damage
				# Visual feedback via signal
				var dot_type = effect.get("dot_type", "unknown")
				EventBus.dot_damage_tick.emit(self, dot_type, damage)

	if total_damage > 0:
		# Apply damage (bypass armor for DoT effects)
		take_damage(total_damage, "DoT effects", "dot")
		EventBus.message_logged.emit(
			"%s takes %d damage from effects." % [name, total_damage],
			Color.DARK_RED
		)

	return total_damage


## Remove all DoT effects of a specific type (for curing)
func cure_dot_type(dot_type: String) -> int:
	var cured_count = 0
	var to_remove: Array[String] = []

	for effect in active_effects:
		if effect.get("type") == "dot" and effect.get("dot_type") == dot_type:
			to_remove.append(effect.id)

	for effect_id in to_remove:
		remove_magical_effect(effect_id)
		cured_count += 1

	if cured_count > 0:
		EventBus.message_logged.emit("%s is cured of %s!" % [name, dot_type], Color.GREEN)

	return cured_count


## Recalculate stat modifiers from all sources (effects, survival, etc.)
func _recalculate_effect_modifiers() -> void:
	# Reset stat modifiers
	for stat in stat_modifiers:
		stat_modifiers[stat] = 0

	# Reset armor modifier
	armor_modifier = 0

	# Apply magical effect modifiers
	for effect in active_effects:
		if effect.has("modifiers"):
			for stat in effect.modifiers:
				if stat in stat_modifiers:
					stat_modifiers[stat] += effect.modifiers[stat]
		if effect.has("armor_bonus"):
			armor_modifier += effect.armor_bonus


## Get effective armor (base + modifier)
func get_effective_armor() -> int:
	return armor + armor_modifier


## Get light radius bonus from active effects (for Light spell, etc.)
func get_light_radius_bonus() -> int:
	var bonus = 0
	for effect in active_effects:
		if effect.has("light_radius_bonus"):
			bonus += effect.light_radius_bonus
	return bonus


## Get elemental resistance for a specific element
## Returns value from -100 (immune) to +100 (vulnerable), 0 is normal
func get_elemental_resistance(element: String) -> int:
	var base = elemental_resistances.get(element, 0)

	# Add buff/debuff modifiers
	for effect in active_effects:
		if effect.get("type") == "elemental_resistance" and effect.get("element") == element:
			base += effect.get("modifier", 0)

	# Clamp to valid range
	return clampi(base, -100, 100)


## Set elemental resistance for a specific element
func set_elemental_resistance(element: String, value: int) -> void:
	elemental_resistances[element] = clampi(value, -100, 100)


## Clear all active effects
func clear_active_effects() -> void:
	active_effects.clear()
	_recalculate_effect_modifiers()


## Check if entity can be mind controlled
## Constructs are immune, low INT creatures are immune
func can_be_mind_controlled() -> bool:
	# Constructs are always immune
	if creature_type == "construct":
		return false

	# Low INT creatures (< 3) are immune
	if get_effective_attribute("INT") < 3:
		return false

	return true


## Get modifier for mind control saves based on creature type
func get_mind_save_modifier() -> int:
	match creature_type:
		"undead":
			return 5  # Undead resist mind control
		"animal":
			return -2  # Animals are more susceptible
		_:
			return 0


## Handle mind effect expiration
func _handle_mind_effect_expiration(effect: Dictionary) -> void:
	match effect.get("type", ""):
		"charm", "calm":
			# Restore original faction
			faction = effect.get("original_faction", "enemy")
			ai_state = "normal"
		"fear":
			ai_state = "normal"
		"enrage":
			faction = effect.get("original_faction", "enemy")
			ai_state = "normal"
