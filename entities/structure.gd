class_name Structure
extends Entity

## Structure - Base class for all placeable structures
##
## Represents player-built structures like campfires, shelters, and containers.
## Uses component pattern for behavior (fire, shelter, storage).

# Preload components
const FireComponent = preload("res://systems/components/fire_component.gd")
const ShelterComponent = preload("res://systems/components/shelter_component.gd")
const ContainerComponent = preload("res://systems/components/container_component.gd")

# Structure properties
var structure_type: String = ""  # "campfire", "lean_to", "chest"
var durability: int = -1  # -1 = indestructible, otherwise current durability
var max_durability: int = -1  # Maximum durability
var is_active: bool = true  # Can be toggled (e.g., campfire lit/unlit)
var owner_id: String = ""  # Future: multiplayer/NPC ownership

# Build requirements (for UI display)
var build_requirements: Array[Dictionary] = []  # [{"item": "wood", "count": 3}, ...]
var build_tool: String = ""  # Required tool (e.g., "knife", "hammer")

func _init(id: String = "", pos: Vector2i = Vector2i.ZERO, type: String = "") -> void:
	structure_type = type
	entity_id = id
	entity_type = "structure"
	position = pos
	blocks_movement = false  # Default, can be overridden
	is_alive = true
	super._init(id, pos, "?", Color.WHITE, false)

## Create structure from JSON data
static func create_from_data(data: Dictionary, pos: Vector2i) -> Structure:
	var structure = Structure.new(data.get("id", ""), pos, data.get("structure_type", ""))

	# Basic properties
	structure.name = data.get("name", "Unknown Structure")
	structure.ascii_char = data.get("ascii_char", "?")
	structure.color = Color(data.get("ascii_color", "#FFFFFF"))
	structure.blocks_movement = data.get("blocks_movement", false)

	# Durability
	structure.max_durability = data.get("durability", -1)
	structure.durability = structure.max_durability

	# Build requirements
	if data.has("build_requirements"):
		for req in data.build_requirements:
			structure.build_requirements.append(req)

	structure.build_tool = data.get("build_tool", "")

	# Create components
	if data.has("components"):
		var components_data = data.components

		# Fire component
		if components_data.has("fire"):
			var fire_data = components_data.fire
			var fire_comp = FireComponent.new()
			fire_comp.heat_radius = fire_data.get("heat_radius", 3)
			fire_comp.temperature_bonus = fire_data.get("temperature_bonus", 15.0)
			fire_comp.light_radius = fire_data.get("light_radius", 5)
			structure.add_component("fire", fire_comp)
			structure.is_fire_source = true  # Enable for crafting system

		# Shelter component
		if components_data.has("shelter"):
			var shelter_data = components_data.shelter
			var shelter_comp = ShelterComponent.new()
			shelter_comp.shelter_radius = shelter_data.get("shelter_radius", 2)
			shelter_comp.temperature_bonus = shelter_data.get("temperature_bonus", 5.0)
			shelter_comp.blocks_rain = shelter_data.get("blocks_rain", true)
			shelter_comp.hp_restore_turns = shelter_data.get("hp_restore_turns", 10)
			shelter_comp.hp_restore_amount = shelter_data.get("hp_restore_amount", 1)
			structure.add_component("shelter", shelter_comp)

		# Container component
		if components_data.has("container"):
			var container_data = components_data.container
			var container_comp = ContainerComponent.new(container_data.get("max_weight", 50.0))
			structure.add_component("container", container_comp)

	return structure

## Interact with the structure
func interact(player: Player) -> Dictionary:
	var result = {
		"success": false,
		"message": "",
		"action": ""  # "open_container", "toggle_fire", "none"
	}

	match structure_type:
		"container":
			result.success = true
			result.action = "open_container"
			result.message = "Opening %s" % name
		"campfire":
			if has_component("fire"):
				var fire = get_component("fire")
				fire.is_lit = not fire.is_lit
				is_active = fire.is_lit
				is_fire_source = fire.is_lit
				result.success = true
				result.action = "toggle_fire"
				result.message = "%s %s" % [name, "lit" if fire.is_lit else "extinguished"]
		_:
			result.message = "Cannot interact with %s" % name

	return result

## Serialize structure for save system
func serialize() -> Dictionary:
	var data = {
		"id": entity_id,
		"structure_type": structure_type,
		"position": {"x": position.x, "y": position.y},
		"durability": durability,
		"is_active": is_active,
		"owner_id": owner_id,
		"components": {}
	}

	# Serialize components
	if has_component("container"):
		var container = get_component("container")
		data.components["container"] = container.serialize()

	if has_component("fire"):
		var fire = get_component("fire")
		data.components["fire"] = {"is_lit": fire.is_lit}

	if has_component("shelter"):
		# Shelter has no dynamic state, just static data
		pass

	return data

## Deserialize structure from save data
static func deserialize(data: Dictionary, structure_definitions: Dictionary) -> Structure:
	var structure_id = data.get("id", "")
	var pos = Vector2i(data.position.x, data.position.y)

	# Look up definition to recreate structure
	if not structure_definitions.has(structure_id):
		push_error("Structure deserialize: Unknown structure ID %s" % structure_id)
		return null

	var definition = structure_definitions[structure_id]
	var structure = Structure.create_from_data(definition, pos)

	# Restore dynamic state
	structure.durability = data.get("durability", structure.max_durability)
	structure.is_active = data.get("is_active", true)
	structure.owner_id = data.get("owner_id", "")

	# Restore component state
	if data.has("components"):
		var comp_data = data.components

		if comp_data.has("container") and structure.has_component("container"):
			var container = structure.get_component("container")
			container.deserialize(comp_data.container)

		if comp_data.has("fire") and structure.has_component("fire"):
			var fire = structure.get_component("fire")
			fire.is_lit = comp_data.fire.get("is_lit", true)
			structure.is_active = fire.is_lit
			structure.is_fire_source = fire.is_lit

	return structure
