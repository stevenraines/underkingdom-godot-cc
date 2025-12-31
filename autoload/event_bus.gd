extends Node

## EventBus - Central signal hub for loose coupling between systems
##
## This autoload provides a central location for game-wide signals,
## allowing systems to communicate without direct dependencies.

# Turn and time signals
signal turn_advanced(turn_number: int)
signal time_of_day_changed(period: String)  # "dawn", "day", "dusk", "night"

# Player signals
signal player_moved(old_pos: Vector2i, new_pos: Vector2i)

# Map signals
signal map_changed(map_id: String)

# Entity signals
signal entity_died(entity: Entity)
signal entity_moved(entity: Entity, old_pos: Vector2i, new_pos: Vector2i)

# Combat signals
signal attack_performed(attacker: Entity, defender: Entity, result: Dictionary)
signal combat_message(message: String, color: Color)
signal player_died()

# Survival signals
signal survival_stat_changed(stat_name: String, old_value: float, new_value: float)
signal survival_warning(message: String, severity: String)
signal stamina_depleted()

# Inventory signals
signal item_picked_up(item)  # Item
signal item_dropped(item, position: Vector2i)  # Item
signal item_used(item, result: Dictionary)  # Item
signal item_equipped(item, slot: String)  # Item
signal item_unequipped(item, slot: String)  # Item
signal inventory_changed()
signal encumbrance_changed(ratio: float)

# Crafting signals
signal craft_attempted(recipe, success: bool)  # Recipe
signal craft_succeeded(recipe, result)  # Recipe, Item
signal craft_failed(recipe)  # Recipe
signal recipe_discovered(recipe)  # Recipe

# Structure signals
signal structure_placed(structure)  # Structure
signal structure_removed(structure)  # Structure
signal structure_interacted(structure, player)  # Structure, Player
signal container_opened(structure)  # Structure
signal container_closed(structure)  # Structure
signal fire_toggled(structure, is_lit: bool)  # Structure

func _ready() -> void:
	print("EventBus initialized")
