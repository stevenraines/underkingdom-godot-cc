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

# Stat modifiers from survival/effects (applied on top of base attributes)
var stat_modifiers: Dictionary = {
	"STR": 0,
	"DEX": 0,
	"CON": 0,
	"INT": 0,
	"WIS": 0,
	"CHA": 0
}

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
