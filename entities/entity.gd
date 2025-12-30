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

# Visual
var ascii_char: String = "?"
var color: Color = Color.WHITE

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

# Components (composition pattern)
var components: Dictionary = {}  # component_name -> component instance

func _init(id: String = "", pos: Vector2i = Vector2i.ZERO, char: String = "?", entity_color: Color = Color.WHITE, blocks: bool = true) -> void:
	entity_id = id
	position = pos
	ascii_char = char
	color = entity_color
	blocks_movement = blocks
	_calculate_derived_stats()

## Calculate derived stats from attributes
func _calculate_derived_stats() -> void:
	# Health: Base 10 + (CON × 5)
	max_health = 10 + (attributes["CON"] * 5)
	current_health = max_health

## Take damage
func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	if current_health <= 0:
		die()

## Heal
func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)

## Handle death
func die() -> void:
	is_alive = false
	blocks_movement = false
	EventBus.entity_died.emit(self)

## Add a component
func add_component(component_name: String, component: Variant) -> void:
	components[component_name] = component

## Get a component
func get_component(component_name: String) -> Variant:
	return components.get(component_name, null)

## Check if has component
func has_component(component_name: String) -> bool:
	return component_name in components
