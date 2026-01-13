class_name ElementalSystem
extends RefCounted

## ElementalSystem - Handles elemental damage types, resistances, and environmental combos
##
## Elements: fire, ice, lightning, poison, necrotic, holy, physical
## Resistances: -100 (immune) to 0 (normal) to +100 (vulnerable)

enum Element { FIRE, ICE, LIGHTNING, POISON, NECROTIC, HOLY, PHYSICAL }

# Elemental interaction rules
const ELEMENT_INTERACTIONS = {
	"fire": {
		"strong_vs": ["ice"],
		"weak_vs": [],
		"melts_ice": true
	},
	"ice": {
		"strong_vs": [],
		"weak_vs": ["fire"],
		"freezes_water": true
	},
	"lightning": {
		"strong_vs": [],
		"weak_vs": [],
		"conducts_in_water": true
	},
	"poison": {
		"strong_vs": [],
		"weak_vs": [],
		"living_only": true  # No effect on undead/constructs
	},
	"necrotic": {
		"strong_vs": [],
		"weak_vs": ["holy"],
		"heals_undead": true
	},
	"holy": {
		"strong_vs": ["necrotic"],
		"weak_vs": [],
		"bonus_vs_undead": true
	}
}


## Get element enum from string name
static func get_element_from_string(element_name: String) -> Element:
	match element_name.to_lower():
		"fire": return Element.FIRE
		"ice", "cold": return Element.ICE
		"lightning", "electric": return Element.LIGHTNING
		"poison": return Element.POISON
		"necrotic", "dark": return Element.NECROTIC
		"holy", "radiant": return Element.HOLY
		_: return Element.PHYSICAL


## Get element string from enum
static func get_element_name(element: Element) -> String:
	match element:
		Element.FIRE: return "fire"
		Element.ICE: return "ice"
		Element.LIGHTNING: return "lightning"
		Element.POISON: return "poison"
		Element.NECROTIC: return "necrotic"
		Element.HOLY: return "holy"
		_: return "physical"


## Calculate final damage after applying resistances
## base_damage: Raw damage before resistance
## element: Damage type (string)
## target: Entity receiving damage
## source: Entity dealing damage (can be null)
## Returns: Final damage after modifiers
static func calculate_elemental_damage(base_damage: int, element: String, target, source = null) -> Dictionary:
	var result = {
		"final_damage": base_damage,
		"resisted": false,
		"immune": false,
		"vulnerable": false,
		"healed": false,
		"message": ""
	}

	if not target:
		return result

	# Get resistance value (negative = resistance, positive = vulnerability)
	var resistance = _get_entity_resistance(target, element)

	# Special creature type interactions
	var creature_type = target.creature_type if "creature_type" in target else "humanoid"

	# Poison immunity for undead/constructs
	if element == "poison" and creature_type in ["undead", "construct"]:
		result.final_damage = 0
		result.immune = true
		result.message = "%s is immune to poison!" % target.name
		return result

	# Necrotic heals undead
	if element == "necrotic" and creature_type == "undead":
		result.final_damage = 0
		result.healed = true
		if target.has_method("heal"):
			target.heal(base_damage)
		result.message = "%s absorbs the necrotic energy!" % target.name
		return result

	# Holy bonus vs undead
	var holy_bonus = 0
	if element == "holy" and creature_type == "undead":
		holy_bonus = int(base_damage * 0.5)

	# Calculate resistance modifier
	# -100 = immune (0%), 0 = normal (100%), +100 = double (200%)
	var modifier = 1.0 + (resistance / 100.0)
	var final_damage = int((base_damage + holy_bonus) * modifier)
	final_damage = max(0, final_damage)

	result.final_damage = final_damage

	if resistance <= -100:
		result.immune = true
		result.final_damage = 0
		result.message = "%s is immune to %s!" % [target.name, element]
	elif resistance <= -50:
		result.resisted = true
		result.message = "%s resists the %s!" % [target.name, element]
	elif resistance >= 50:
		result.vulnerable = true
		result.message = "%s is vulnerable to %s!" % [target.name, element]

	return result


## Get an entity's resistance to an element
static func _get_entity_resistance(entity, element: String) -> int:
	var base = 0

	# Check elemental_resistances dictionary
	if "elemental_resistances" in entity:
		base = entity.elemental_resistances.get(element, 0)

	# Add equipment bonuses (if the entity has equipment)
	if "equipment" in entity and entity.equipment:
		for slot in entity.equipment:
			var item = entity.equipment[slot]
			if item and "elemental_resistance" in item:
				if element in item.elemental_resistance:
					base += item.elemental_resistance[element]

	# Add buff/debuff modifiers
	if entity.has_method("get_active_effects"):
		for effect in entity.get_active_effects():
			if effect.get("type") == "elemental_resistance" and effect.get("element") == element:
				base += effect.get("modifier", 0)

	# Clamp to valid range
	return clampi(base, -100, 100)


## Check for environmental combos when elemental damage hits a tile
static func check_environmental_combo(damage_position: Vector2i, element: String) -> Dictionary:
	var combo_result = {
		"triggered": false,
		"effect": "",
		"bonus_damage": 0,
		"aoe_tiles": [],
		"creates_hazard": "",
		"changes_tile_to": ""
	}

	if not MapManager.current_map:
		return combo_result

	var tile = MapManager.current_map.get_tile(damage_position)
	if not tile:
		return combo_result

	match element:
		"lightning":
			if tile.tile_type == "water":
				combo_result.triggered = true
				combo_result.effect = "conducted"
				combo_result.bonus_damage = 10
				combo_result.aoe_tiles = _get_connected_water_tiles(damage_position)
		"fire":
			if tile.tile_type == "ice":
				combo_result.triggered = true
				combo_result.effect = "melted"
				combo_result.changes_tile_to = "water"
		"ice":
			if tile.tile_type == "water":
				combo_result.triggered = true
				combo_result.effect = "frozen"
				combo_result.changes_tile_to = "ice"
				combo_result.creates_hazard = "slippery"

	return combo_result


## Apply environmental combo effects
static func apply_environmental_combo(position: Vector2i, element: String, source = null) -> void:
	var combo = check_environmental_combo(position, element)

	if not combo.triggered:
		return

	EventBus.message_logged.emit("The %s is %s!" % [element, combo.effect], Color.CYAN)

	# Apply bonus damage to entities in affected area
	if combo.bonus_damage > 0:
		for tile_pos in combo.aoe_tiles:
			var entity = EntityManager.get_entity_at(tile_pos)
			if entity and entity.has_method("take_damage"):
				entity.take_damage(combo.bonus_damage, source.name if source else "Environment", element)

	# Change tile type if needed
	if combo.changes_tile_to != "":
		MapManager.current_map.set_tile_type(position, combo.changes_tile_to)
		EventBus.tile_changed.emit(position)


## Get connected water tiles (for lightning conduction)
static func _get_connected_water_tiles(start_pos: Vector2i) -> Array:
	var water_tiles = [start_pos]
	var checked = {start_pos: true}
	var to_check = [start_pos]

	while to_check.size() > 0:
		var pos = to_check.pop_front()

		for dir in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var neighbor = pos + dir
			if neighbor in checked:
				continue
			checked[neighbor] = true

			var tile = MapManager.current_map.get_tile(neighbor)
			if tile and tile.tile_type == "water":
				water_tiles.append(neighbor)
				to_check.append(neighbor)

				# Limit spread to prevent infinite loops
				if water_tiles.size() >= 20:
					return water_tiles

	return water_tiles


## Get the color associated with an element (for visual feedback)
static func get_element_color(element: String) -> Color:
	match element:
		"fire": return Color.ORANGE_RED
		"ice", "cold": return Color.CYAN
		"lightning", "electric": return Color.YELLOW
		"poison": return Color.GREEN
		"necrotic", "dark": return Color.PURPLE
		"holy", "radiant": return Color.GOLD
		_: return Color.WHITE


## Apply elemental damage to an entity (convenience function)
static func apply_elemental_damage(base_damage: int, element: String, target, source = null) -> int:
	var result = calculate_elemental_damage(base_damage, element, target, source)

	if result.message != "":
		EventBus.message_logged.emit(result.message, get_element_color(element))

	if result.final_damage > 0 and target.has_method("take_damage"):
		target.take_damage(result.final_damage, source.name if source else "Unknown", element)

	return result.final_damage
