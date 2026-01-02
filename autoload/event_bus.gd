extends Node

## EventBus - Central signal hub for loose coupling between systems
##
## This autoload provides a central location for game-wide signals,
## allowing systems to communicate without direct dependencies.

# Turn and time signals
@warning_ignore("unused_signal")
signal turn_advanced(turn_number: int)
@warning_ignore("unused_signal")
signal time_of_day_changed(period: String)  # "dawn", "day", "dusk", "night"

# Player signals
@warning_ignore("unused_signal")
signal player_moved(old_pos: Vector2i, new_pos: Vector2i)

# Map signals
@warning_ignore("unused_signal")
signal map_changed(map_id: String)
@warning_ignore("unused_signal")
signal chunk_loaded(chunk_coords: Vector2i)
@warning_ignore("unused_signal")
signal chunk_unloaded(chunk_coords: Vector2i)

# Entity signals
@warning_ignore("unused_signal")
signal entity_died(entity: Entity)
@warning_ignore("unused_signal")
signal entity_moved(entity: Entity, old_pos: Vector2i, new_pos: Vector2i)

# Combat signals
@warning_ignore("unused_signal")
signal attack_performed(attacker: Entity, defender: Entity, result: Dictionary)
@warning_ignore("unused_signal")
signal combat_message(message: String, color: Color)
@warning_ignore("unused_signal")
signal player_died()

# Survival signals
@warning_ignore("unused_signal")
signal survival_stat_changed(stat_name: String, old_value: float, new_value: float)
@warning_ignore("unused_signal")
signal survival_warning(message: String, severity: String)
@warning_ignore("unused_signal")
signal stamina_depleted()

# Inventory signals
@warning_ignore("unused_signal")
signal item_picked_up(item)  # Item
@warning_ignore("unused_signal")
signal item_dropped(item, position: Vector2i)  # Item
@warning_ignore("unused_signal")
signal item_used(item, result: Dictionary)  # Item
@warning_ignore("unused_signal")
signal item_equipped(item, slot: String)  # Item
@warning_ignore("unused_signal")
signal item_unequipped(item, slot: String)  # Item
@warning_ignore("unused_signal")
signal inventory_changed()
@warning_ignore("unused_signal")
signal encumbrance_changed(ratio: float)

# Crafting signals
@warning_ignore("unused_signal")
signal craft_attempted(recipe, success: bool)  # Recipe
@warning_ignore("unused_signal")
signal craft_succeeded(recipe, result)  # Recipe, Item
@warning_ignore("unused_signal")
signal craft_failed(recipe)  # Recipe
@warning_ignore("unused_signal")
signal recipe_discovered(recipe)  # Recipe

# Structure signals
@warning_ignore("unused_signal")
signal structure_placed(structure)  # Structure
@warning_ignore("unused_signal")
signal structure_removed(structure)  # Structure
@warning_ignore("unused_signal")
signal structure_interacted(structure, player)  # Structure, Player
@warning_ignore("unused_signal")
signal container_opened(structure)  # Structure
@warning_ignore("unused_signal")
signal container_closed(structure)  # Structure
@warning_ignore("unused_signal")
signal fire_toggled(structure, is_lit: bool)  # Structure

# NPC & Shop signals
@warning_ignore("unused_signal")
signal npc_interacted(npc, player)  # NPC, Player
@warning_ignore("unused_signal")
signal shop_opened(npc, player)  # NPC, Player
@warning_ignore("unused_signal")
signal item_purchased(item, price: int)  # Item
@warning_ignore("unused_signal")
signal item_sold(item, price: int)  # Item
@warning_ignore("unused_signal")
signal shop_restocked(npc)  # NPC

# Save/Load signals
@warning_ignore("unused_signal")
signal game_saved(slot: int)
@warning_ignore("unused_signal")
signal game_loaded(slot: int)
@warning_ignore("unused_signal")
signal save_failed(error: String)
@warning_ignore("unused_signal")
signal load_failed(error: String)

# UI signals
@warning_ignore("unused_signal")
signal message_logged(message: String)

# Feature signals
@warning_ignore("unused_signal")
signal feature_interacted(feature_id: String, position: Vector2i, result: Dictionary)
@warning_ignore("unused_signal")
signal feature_spawned_enemy(enemy_id: String, position: Vector2i)

# Hazard signals
@warning_ignore("unused_signal")
signal hazard_triggered(hazard_id: String, position: Vector2i, target, damage: int)
@warning_ignore("unused_signal")
signal hazard_detected(hazard_id: String, position: Vector2i)
@warning_ignore("unused_signal")
signal hazard_disarmed(hazard_id: String, position: Vector2i)

func _ready() -> void:
	print("EventBus initialized")
