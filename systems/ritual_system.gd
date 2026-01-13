class_name RitualSystem
extends RefCounted

## RitualSystem - Handles ritual casting, channeling, and effects
##
## Rituals are multi-turn magical workings that require components,
## channeling time, and can be interrupted by combat or movement.

# Active ritual state
static var active_ritual: Ritual = null
static var ritual_caster = null  # Entity performing ritual
static var channeling_remaining: int = 0
static var consumed_components: Array = []


## Check if an entity can perform a ritual
static func can_perform_ritual(caster, ritual: Ritual) -> Dictionary:
	var result = {"can_perform": true, "reason": ""}

	# Check INT requirement
	var min_int = ritual.get_min_intelligence()
	var caster_int = 10
	if caster.has_method("get_effective_attribute"):
		caster_int = caster.get_effective_attribute("INT")
	elif "attributes" in caster:
		caster_int = caster.attributes.get("INT", 10)

	if caster_int < min_int:
		result.can_perform = false
		result.reason = "Requires %d Intelligence." % min_int
		return result

	# Check if already channeling
	if active_ritual != null:
		result.can_perform = false
		result.reason = "Already performing a ritual."
		return result

	# Check components
	if caster.has_method("get") and caster.get("inventory"):
		for component in ritual.components:
			var item_id = component.get("item_id", "")
			var quantity = component.get("quantity", 1)
			if not caster.inventory.has_item(item_id, quantity):
				var item_data = ItemManager.get_item_data(item_id)
				var item_name = item_data.get("name", item_id) if item_data else item_id
				result.can_perform = false
				result.reason = "Missing component: %dx %s" % [quantity, item_name]
				return result

	# Check special requirements
	if ritual.requires_altar():
		if not _is_near_altar(caster):
			result.can_perform = false
			result.reason = "Must be performed at an altar."
			return result

	if ritual.requires_night():
		var time_of_day = TurnManager.time_of_day if TurnManager else "day"
		if time_of_day not in ["night", "midnight"]:
			result.can_perform = false
			result.reason = "Can only be performed at night."
			return result

	return result


## Begin performing a ritual
static func begin_ritual(caster, ritual: Ritual) -> bool:
	var check = can_perform_ritual(caster, ritual)
	if not check.can_perform:
		EventBus.message_logged.emit(check.reason, Color.YELLOW)
		return false

	# Consume components
	consumed_components = []
	if caster.has_method("get") and caster.get("inventory"):
		for component in ritual.components:
			var item_id = component.get("item_id", "")
			var quantity = component.get("quantity", 1)
			caster.inventory.remove_item_by_id(item_id, quantity)
			consumed_components.append(component)

	# Start channeling
	active_ritual = ritual
	ritual_caster = caster
	channeling_remaining = ritual.channeling_turns

	EventBus.ritual_started.emit(caster, ritual)
	EventBus.message_logged.emit(
		"You begin the %s ritual... (%d turns to complete)" % [ritual.name, channeling_remaining],
		Color.MAGENTA
	)

	return true


## Process one turn of channeling
## Call this each turn while the player waits
static func process_channeling_turn() -> void:
	if active_ritual == null:
		return

	channeling_remaining -= 1

	# Progress message
	if channeling_remaining > 0:
		EventBus.ritual_progress.emit(ritual_caster, active_ritual, channeling_remaining)
		EventBus.message_logged.emit(
			"Channeling %s... %d turns remaining" % [active_ritual.name, channeling_remaining],
			Color.MAGENTA
		)
	else:
		# Ritual complete
		_complete_ritual()


## Interrupt the current ritual
static func interrupt_ritual(reason: String = "interrupted") -> void:
	if active_ritual == null:
		return

	EventBus.message_logged.emit(
		"The %s ritual is %s!" % [active_ritual.name, reason],
		Color.RED
	)

	# Apply failure effects
	_apply_failure_effects()

	EventBus.ritual_interrupted.emit(ritual_caster, active_ritual, reason)

	# Clear state
	_clear_ritual_state()


## Complete the ritual successfully
static func _complete_ritual() -> void:
	EventBus.message_logged.emit(
		"The %s ritual is complete!" % active_ritual.name,
		Color.CYAN
	)

	# Apply ritual effects
	var result = _apply_ritual_effects(ritual_caster, active_ritual)

	EventBus.ritual_completed.emit(ritual_caster, active_ritual, result)

	# Clear state
	_clear_ritual_state()


## Apply ritual effects on completion
static func _apply_ritual_effects(caster, ritual: Ritual) -> Dictionary:
	var result = {
		"success": true,
		"message": "",
		"effects_applied": []
	}

	var effects = ritual.effects

	# Handle different effect types
	if effects.has("enchant_item"):
		_apply_enchant_item(caster, effects.enchant_item, result)

	if effects.has("reveal_map"):
		_apply_reveal_map(caster, effects.reveal_map, result)

	if effects.has("resurrect"):
		_apply_resurrection(caster, effects.resurrect, result)

	if effects.has("summon"):
		_apply_summon(caster, effects.summon, result)

	if effects.has("bind_soul"):
		_apply_bind_soul(caster, effects.bind_soul, result)

	if effects.has("create_ward"):
		_apply_create_ward(caster, effects.create_ward, result)

	EventBus.ritual_effect_applied.emit(caster, ritual, effects)

	if result.message.is_empty():
		result.message = ritual.name + " completed successfully."
	return result


## Enchant Item - Apply random enchantment to equipped item
static func _apply_enchant_item(caster, effect_data: Dictionary, result: Dictionary) -> void:
	var enchantment_pool = effect_data.get("enchantment_pool", [])
	if enchantment_pool.is_empty():
		result.message = "No enchantments available."
		result.success = false
		return

	# Get equipped weapon or armor to enchant
	var target_item = null
	if caster.has_method("get") and caster.get("inventory"):
		# Try main hand first (weapon)
		target_item = caster.inventory.equipment.get("main_hand")
		if not target_item:
			# Try torso (armor)
			target_item = caster.inventory.equipment.get("torso")

	if not target_item:
		result.message = "No item to enchant. Equip a weapon or armor first."
		result.success = false
		return

	# Pick random enchantment
	var enchantment = enchantment_pool[randi() % enchantment_pool.size()]

	# Apply enchantment effects to item
	match enchantment:
		"sharpness":
			target_item.damage = int(target_item.damage * 1.25) if target_item.damage > 0 else 2
			target_item.name = "Sharp " + target_item.name if not target_item.name.begins_with("Sharp") else target_item.name
		"protection":
			target_item.armor = int(target_item.armor * 1.25) if target_item.armor > 0 else 2
			target_item.name = "Protective " + target_item.name if not target_item.name.begins_with("Protective") else target_item.name
		"mana_regen":
			if not "stat_bonuses" in target_item or not target_item.stat_bonuses:
				target_item.stat_bonuses = {}
			target_item.stat_bonuses["mana_regen"] = target_item.stat_bonuses.get("mana_regen", 0) + 0.5
			target_item.name = "Arcane " + target_item.name if not target_item.name.begins_with("Arcane") else target_item.name
		"health_regen":
			if not "stat_bonuses" in target_item or not target_item.stat_bonuses:
				target_item.stat_bonuses = {}
			target_item.stat_bonuses["health_regen"] = target_item.stat_bonuses.get("health_regen", 0) + 1
			target_item.name = "Vital " + target_item.name if not target_item.name.begins_with("Vital") else target_item.name

	result.message = "Your %s glows with the power of %s!" % [target_item.name, enchantment]
	result.effects_applied.append("enchant_item: " + enchantment)


## Reveal Map - Expand visibility to reveal area
static func _apply_reveal_map(caster, effect_data: Dictionary, result: Dictionary) -> void:
	var radius = effect_data.get("radius", 30)
	var reveals_enemies = effect_data.get("reveals_enemies", true)
	var reveals_items = effect_data.get("reveals_items", true)

	const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")

	# Reveal tiles in radius
	var center = caster.position
	var revealed_count = 0
	var map_id = MapManager.current_map.map_id if MapManager.current_map else "overworld"

	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var pos = center + Vector2i(dx, dy)
				FogOfWarSystemClass.mark_explored(map_id, pos)
				revealed_count += 1

	var messages: Array[String] = []
	messages.append("The veil parts, revealing %d tiles around you." % revealed_count)

	# Log enemies in range if reveals_enemies
	if reveals_enemies:
		var enemies_found = 0
		for entity in EntityManager.entities:
			if entity is Enemy and entity.is_alive:
				var dist = abs(entity.position.x - center.x) + abs(entity.position.y - center.y)
				if dist <= radius:
					enemies_found += 1
		if enemies_found > 0:
			messages.append("You sense %d enemies nearby." % enemies_found)

	# Log items in range if reveals_items
	if reveals_items:
		var items_found = 0
		for entity in EntityManager.entities:
			if entity is GroundItem:
				var dist = abs(entity.position.x - center.x) + abs(entity.position.y - center.y)
				if dist <= radius:
					items_found += 1
		if items_found > 0:
			messages.append("You sense %d items nearby." % items_found)

	result.message = " ".join(messages)
	result.effects_applied.append("reveal_map")


## Resurrection - Restore the caster to life (simplified since we don't have corpse system)
static func _apply_resurrection(caster, effect_data: Dictionary, result: Dictionary) -> void:
	var health_percent = effect_data.get("health_percent", 25) / 100.0
	var temporary_weakness = effect_data.get("temporary_weakness", false)
	var weakness_duration = effect_data.get("weakness_duration", 100)

	# In a full implementation this would resurrect a dead ally
	# For now, restore the caster's health as a powerful heal
	var heal_amount = int(caster.max_health * health_percent * 2)  # Double for self-use
	caster.current_health = mini(caster.current_health + heal_amount, caster.max_health)

	result.message = "Life force surges through you! Healed for %d HP." % heal_amount

	# Apply temporary weakness (stat reduction) if enabled
	if temporary_weakness:
		var weakness_effect = {
			"name": "Resurrection Weakness",
			"duration": weakness_duration,
			"stat_modifiers": {"STR": -2, "DEX": -2, "CON": -2}
		}
		if caster.has_method("apply_effect"):
			caster.apply_effect(weakness_effect)
			result.message += " You feel weakened temporarily."

	result.effects_applied.append("resurrection")


## Summon - Spawn a summoned creature
static func _apply_summon(caster, effect_data: Dictionary, result: Dictionary) -> void:
	var creature_id = effect_data.get("creature_id", "")
	var duration = effect_data.get("duration", 100)
	var behavior = effect_data.get("behavior", "follow")

	if creature_id.is_empty():
		result.message = "Summoning failed - no creature specified."
		result.success = false
		return

	# Find spawn position adjacent to caster
	var spawn_pos = _find_adjacent_walkable(caster.position)
	if spawn_pos == Vector2i(-999, -999):
		result.message = "No space to summon creature."
		result.success = false
		return

	# Check if SummonedCreature class exists
	const SummonedCreatureScript = preload("res://entities/summoned_creature.gd")
	var summoned = SummonedCreatureScript.new()
	summoned.initialize_from_enemy(creature_id, caster, duration)
	summoned.position = spawn_pos
	summoned.command_mode = behavior

	# Add to entity manager
	EntityManager.entities.append(summoned)

	EventBus.summon_created.emit(summoned, caster)

	result.message = "A %s materializes from the shadows to serve you!" % summoned.name
	result.effects_applied.append("summon: " + creature_id)


## Bind Soul - Kill a weak enemy and create a soul gem
static func _apply_bind_soul(caster, effect_data: Dictionary, result: Dictionary) -> void:
	var health_threshold = effect_data.get("health_threshold", 0.25)
	var creates_item = effect_data.get("creates_item", "soul_gem")

	# Find a valid target (adjacent enemy with low health)
	var target = _find_low_health_adjacent_enemy(caster.position, health_threshold)

	if not target:
		result.message = "No suitable target nearby. Target must be near death."
		result.success = false
		return

	# Kill the target
	var target_name = target.name
	target.take_damage(target.current_health + 10, "Soul Binding", "magical")

	# Create the soul gem
	var soul_gem = ItemManager.create_item(creates_item, 1)
	if soul_gem and caster.has_method("get") and caster.get("inventory"):
		if caster.inventory.add_item(soul_gem):
			result.message = "The soul of %s is bound to the gem!" % target_name
		else:
			# Inventory full - drop on ground
			EntityManager.spawn_ground_item(soul_gem, caster.position)
			result.message = "The soul of %s is bound! The gem falls to the ground." % target_name
	else:
		result.message = "The soul of %s is released..." % target_name

	result.effects_applied.append("bind_soul")


## Create Ward - Create a protective ward around an area
static func _apply_create_ward(caster, effect_data: Dictionary, result: Dictionary) -> void:
	var radius = effect_data.get("radius", 5)
	var duration = effect_data.get("duration", 500)
	var ward_effects = effect_data.get("effects", [])

	# For now, create a simple ward that applies a buff to the caster
	# In a full implementation this would create ward entities around the area
	var ward_buff = {
		"name": "Protective Ward",
		"duration": duration,
		"ward_radius": radius,
		"ward_effects": ward_effects,
		"stat_modifiers": {"armor_bonus": 5}
	}

	if caster.has_method("apply_effect"):
		caster.apply_effect(ward_buff)

	# Log what the ward does
	var ward_desc_parts: Array[String] = []
	for effect in ward_effects:
		match effect:
			"blocks_undead":
				ward_desc_parts.append("repels undead")
			"blocks_demons":
				ward_desc_parts.append("repels demons")
			"alarm_on_entry":
				ward_desc_parts.append("alerts on intrusion")

	var ward_desc = ", ".join(ward_desc_parts) if ward_desc_parts.size() > 0 else "provides protection"
	result.message = "A shimmering ward surrounds the area (%s) for %d turns." % [ward_desc, duration]
	result.effects_applied.append("create_ward")


## Find adjacent enemy with low health (for bind_soul)
static func _find_low_health_adjacent_enemy(pos: Vector2i, threshold: float) -> Entity:
	var offsets = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	for offset in offsets:
		var check_pos = pos + offset
		var entity = EntityManager.get_blocking_entity_at(check_pos)
		if entity and entity is Enemy and entity.is_alive:
			var health_ratio = float(entity.current_health) / float(entity.max_health)
			if health_ratio <= threshold:
				return entity

	return null


## Apply failure effects when ritual is interrupted
static func _apply_failure_effects() -> void:
	if active_ritual == null or active_ritual.failure_effects.is_empty():
		return

	const WildMagicClass = preload("res://systems/wild_magic.gd")

	# Determine failure type
	var roll = randi_range(1, 20)

	if roll <= 5:
		# Wild magic surge
		WildMagicClass.trigger_wild_magic(ritual_caster, null)
	elif roll <= 10:
		# Backfire - ritual effects target caster negatively
		EventBus.message_logged.emit("The ritual backfires!", Color.RED)
		_apply_backfire(ritual_caster, active_ritual)
	else:
		# Fizzle - components lost, nothing else happens
		EventBus.message_logged.emit("The ritual fizzles. Components are lost.", Color.YELLOW)


## Apply negative version of ritual effects to caster
static func _apply_backfire(caster, ritual: Ritual) -> void:
	var effects = ritual.effects

	# Apply negative versions of effects
	if "damage" in effects:
		var damage_data = effects.damage
		var damage = damage_data.get("base", 10) * 2
		if caster.has_method("take_damage"):
			caster.take_damage(damage, "Ritual Backfire", "magical")

	if "summon" in effects:
		# Summon hostile creature instead of friendly
		var summon_data = effects.summon
		var creature_id = summon_data.get("creature_id", "barrow_wight")
		var spawn_pos = _find_adjacent_walkable(caster.position)
		if spawn_pos != Vector2i(-999, -999):
			EntityManager.spawn_enemy(creature_id, spawn_pos)


## Clear ritual state
static func _clear_ritual_state() -> void:
	active_ritual = null
	ritual_caster = null
	channeling_remaining = 0
	consumed_components = []


## Check if entity is near an altar
static func _is_near_altar(entity) -> bool:
	if not MapManager.current_map:
		return false

	var offsets = [
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	for offset in offsets:
		var pos = entity.position + offset
		var tile = MapManager.current_map.get_tile(pos)
		if tile and tile.tile_type == "altar":
			return true

	return false


## Find an adjacent walkable position
static func _find_adjacent_walkable(pos: Vector2i) -> Vector2i:
	if not MapManager.current_map:
		return Vector2i(-999, -999)

	var offsets = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	for offset in offsets:
		var check_pos = pos + offset
		if MapManager.current_map.is_walkable(check_pos):
			if not EntityManager.get_blocking_entity_at(check_pos):
				return check_pos

	return Vector2i(-999, -999)


## Check if currently channeling a ritual
static func is_channeling() -> bool:
	return active_ritual != null


## Get current channeling progress
static func get_channeling_progress() -> Dictionary:
	if active_ritual == null:
		return {}
	return {
		"ritual": active_ritual,
		"remaining": channeling_remaining,
		"total": active_ritual.channeling_turns
	}


## Get the current ritual being channeled
static func get_active_ritual() -> Ritual:
	return active_ritual


## Get the caster of the current ritual
static func get_ritual_caster():
	return ritual_caster
