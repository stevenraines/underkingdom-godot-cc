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
@warning_ignore("unused_signal")
signal day_changed(day: int)  # New calendar day

# Player signals
@warning_ignore("unused_signal")
signal player_moved(old_pos: Vector2i, new_pos: Vector2i)

# Leveling signals
@warning_ignore("unused_signal")
signal player_leveled_up(new_level: int, skill_points_gained: int, gained_ability_point: bool)
@warning_ignore("unused_signal")
signal skill_increased(skill_name: String, new_value: int)
@warning_ignore("unused_signal")
signal ability_increased(ability_name: String, new_value: int)

# Map signals
@warning_ignore("unused_signal")
signal map_changed(map_id: String)
@warning_ignore("unused_signal")
signal tile_changed(position: Vector2i)  # Single tile updated (door opened/closed, etc.)
@warning_ignore("unused_signal")
signal chunk_loaded(chunk_coords: Vector2i)
@warning_ignore("unused_signal")
signal chunk_unloaded(chunk_coords: Vector2i)

# Entity signals
@warning_ignore("unused_signal")
signal entity_died(entity: Entity)
@warning_ignore("unused_signal")
signal entity_moved(entity: Entity, old_pos: Vector2i, new_pos: Vector2i)
@warning_ignore("unused_signal")
signal entity_visual_changed(position: Vector2i)  # Entity's visual (char/color) changed

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

# Mana signals (magic system)
@warning_ignore("unused_signal")
signal mana_changed(old_value: float, new_value: float, max_value: float)
@warning_ignore("unused_signal")
signal mana_depleted()

# Spell signals (magic system)
@warning_ignore("unused_signal")
signal spell_learned(spell_id: String)
@warning_ignore("unused_signal")
signal spell_cast(caster, spell, targets: Array, result: Dictionary)
@warning_ignore("unused_signal")
signal enemy_spell_cast(enemy, spell, target, result: Dictionary)
@warning_ignore("unused_signal")
signal wild_magic_triggered(caster, effect: Dictionary)
@warning_ignore("unused_signal")
signal cantrip_cast(caster, spell)

# Racial ability signals
@warning_ignore("unused_signal")
signal racial_ability_used(entity: Entity, trait_id: String)
@warning_ignore("unused_signal")
signal racial_ability_recharged(entity: Entity, trait_id: String)

# Class feat signals
@warning_ignore("unused_signal")
signal class_feat_used(entity: Entity, feat_id: String)
@warning_ignore("unused_signal")
signal class_feat_recharged(entity: Entity, feat_id: String)

# Magical effect signals (buffs/debuffs)
@warning_ignore("unused_signal")
signal effect_applied(entity: Entity, effect: Dictionary)
@warning_ignore("unused_signal")
signal effect_removed(entity: Entity, effect: Dictionary)
@warning_ignore("unused_signal")
signal effect_expired(entity: Entity, effect_name: String)

# DoT (Damage over Time) signals
@warning_ignore("unused_signal")
signal dot_damage_tick(entity: Entity, dot_type: String, damage: int)

# Elemental damage signals
@warning_ignore("unused_signal")
signal elemental_damage_applied(target: Entity, element: String, damage: int, resisted: bool)
@warning_ignore("unused_signal")
signal environmental_combo_triggered(position: Vector2i, element: String, effect: String)
@warning_ignore("unused_signal")
signal resistance_changed(entity: Entity, element: String, new_value: int)

# Curse signals
@warning_ignore("unused_signal")
signal curse_revealed(item)  # Item
@warning_ignore("unused_signal")
signal curse_removed(item)  # Item
@warning_ignore("unused_signal")
signal cursed_scroll_used(player, effect: String)  # Entity, effect description

# Ritual signals
@warning_ignore("unused_signal")
signal ritual_started(caster, ritual)  # Entity, Ritual
@warning_ignore("unused_signal")
signal ritual_completed(caster, ritual, result: Dictionary)  # Entity, Ritual
@warning_ignore("unused_signal")
signal ritual_interrupted(caster, ritual, reason: String)  # Entity, Ritual
@warning_ignore("unused_signal")
signal ritual_progress(caster, ritual, turns_remaining: int)  # Entity, Ritual
@warning_ignore("unused_signal")
signal ritual_learned(entity, ritual_id: String)  # Entity
@warning_ignore("unused_signal")
signal ritual_menu_requested()
@warning_ignore("unused_signal")
signal ritual_effect_applied(caster, ritual, effects: Dictionary)  # Entity, Ritual

# Concentration signals
@warning_ignore("unused_signal")
signal concentration_started(caster, spell_id: String)
@warning_ignore("unused_signal")
signal concentration_ended(caster, spell_id: String)
@warning_ignore("unused_signal")
signal concentration_check(caster, damage: int, success: bool)

# Summoning signals
@warning_ignore("unused_signal")
signal summon_created(summon, summoner)  # SummonedCreature, Entity
@warning_ignore("unused_signal")
signal summon_dismissed(summon)  # SummonedCreature
@warning_ignore("unused_signal")
signal summon_died(summon)  # SummonedCreature
@warning_ignore("unused_signal")
signal summon_menu_requested()
@warning_ignore("unused_signal")
signal summon_command_changed(summon, mode: String)  # SummonedCreature

# AOE and Terrain signals
@warning_ignore("unused_signal")
signal aoe_cursor_moved(position: Vector2i)
@warning_ignore("unused_signal")
signal terrain_changed(position: Vector2i, new_type: String)

# Scroll signals
@warning_ignore("unused_signal")
signal scroll_targeting_started(scroll, spell)  # Item, Spell
@warning_ignore("unused_signal")
signal transcription_attempted(scroll, spell, success: bool)  # Item, Spell

# Wand signals
@warning_ignore("unused_signal")
signal wand_targeting_started(wand, spell)  # Item, Spell
@warning_ignore("unused_signal")
signal wand_used(wand, spell, charges_remaining: int)  # Item, Spell

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
signal item_identified(item_id: String)  # When an unidentified item is revealed
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

# NPC Training signals
@warning_ignore("unused_signal")
signal npc_menu_opened(npc, player)  # NPC, Player - for NPCs with multiple services
@warning_ignore("unused_signal")
signal training_opened(npc, player)  # NPC, Player
@warning_ignore("unused_signal")
signal recipe_trained(recipe_id: String, price: int)  # Recipe learned from NPC

# Save/Load signals
@warning_ignore("unused_signal")
signal game_started()
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

# Rest/wait signals
@warning_ignore("unused_signal")
signal rest_started(turns: int)
@warning_ignore("unused_signal")
signal rest_interrupted(reason: String)
@warning_ignore("unused_signal")
signal rest_completed(turns_rested: int)

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

# Lock signals
@warning_ignore("unused_signal")
signal lock_picked(position: Vector2i, success: bool)
@warning_ignore("unused_signal")
signal lock_opened(position: Vector2i, method: String)  # method: "key", "skeleton_key", "picked"
@warning_ignore("unused_signal")
signal lockpick_broken(position: Vector2i)

# Harvesting mode signals
@warning_ignore("unused_signal")
signal harvesting_mode_changed(is_active: bool)

# Sprint mode signals
@warning_ignore("unused_signal")
signal sprint_mode_changed(is_active: bool)

# Fast travel signals
@warning_ignore("unused_signal")
signal location_discovered(location_id: String, location_name: String)

# Weather signals
@warning_ignore("unused_signal")
signal weather_changed(old_weather: String, new_weather: String, message: String)
@warning_ignore("unused_signal")
signal exposure_warning(message: String, severity: String)
@warning_ignore("unused_signal")
signal exposure_damage(amount: int)
@warning_ignore("unused_signal")
signal special_weather_event(event_id: String, started: bool)

func _ready() -> void:
	print("EventBus initialized")
