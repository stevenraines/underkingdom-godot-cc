class_name CraftingSystem
extends RefCounted

## CraftingSystem - Handles crafting attempts, success/failure, and discovery
##
## Static class that provides crafting functionality with discovery mechanics.

## Attempt to craft a recipe
## Returns: {success: bool, result_item: Item, message: String, recipe_learned: bool}
static func attempt_craft(player: Player, recipe: Recipe, near_fire: bool, workstation_info: Dictionary = {}) -> Dictionary:
	var result = {
		"success": false,
		"result_item": null,
		"message": "",
		"recipe_learned": false
	}

	# Check if enemies are nearby - can't craft in danger
	if are_enemies_nearby(player.position):
		result.message = "You can't craft while enemies are nearby!"
		return result

	# Get workstation info if not provided
	if workstation_info.is_empty() and MapManager.current_map:
		workstation_info = StructureManager.get_workstation_info(
			player.position, MapManager.current_map.map_id, player.inventory
		)

	# Check workstation tool requirements
	if recipe.workstation_required != "":
		var tool_check = _check_workstation_tool(recipe.workstation_required, workstation_info, player.inventory)
		if not tool_check.ok:
			result.message = tool_check.message
			return result

	# Check if has all ingredients
	if not recipe.has_requirements(player.inventory, near_fire, workstation_info):
		var missing = recipe.get_missing_requirements(player.inventory, near_fire, workstation_info)
		result.message = "Missing requirements: " + ", ".join(missing)
		return result

	# D&D-style skill check: d20 + INT modifier + crafting skill + racial bonus vs DC
	var crafting_skill = player.skills.get("crafting", 0)
	var int_val = player.get_effective_attribute("INT") if player.has_method("get_effective_attribute") else player.attributes.get("INT", 10)
	var int_modifier: int = int((int_val - 10) / 2.0)
	var dc: int = recipe.difficulty * 2 + 8  # DC scales with difficulty

	# Get racial crafting bonus (e.g., Gnome Tinkerer)
	var racial_bonus: int = 0
	if "crafting_bonus" in player:
		racial_bonus = player.crafting_bonus

	var dice_roll: int = randi_range(1, 20)
	var total_roll: int = dice_roll + int_modifier + crafting_skill + racial_bonus
	var success: bool = total_roll >= dc

	# Build roll breakdown string for messages
	var roll_info = _format_d20_roll(dice_roll, int_modifier, "INT", crafting_skill + racial_bonus, total_roll, dc)

	# Consume ingredients (regardless of success/failure)
	if not recipe.consume_ingredients(player.inventory):
		result.message = "Failed to consume ingredients"
		push_error("CraftingSystem: Failed to consume ingredients for " + recipe.id)
		return result

	EventBus.inventory_changed.emit()

	if success:
		# Create result item
		result.result_item = ItemManager.create_item(recipe.result_item_id, recipe.result_count)

		if result.result_item:
			# Add to player inventory
			player.inventory.add_item(result.result_item)

			# Consume workstation tool durability
			if recipe.workstation_required != "":
				_consume_workstation_tool_durability(recipe.workstation_required, player.inventory)

			# Learn recipe if not already known
			if not player.knows_recipe(recipe.id):
				player.learn_recipe(recipe.id)
				result.recipe_learned = true
				EventBus.recipe_discovered.emit(recipe)

			result.success = true
			result.message = "Successfully crafted %s! %s" % [recipe.get_display_name(), roll_info]

			EventBus.craft_succeeded.emit(recipe, result.result_item)
		else:
			result.message = "Error: Could not create item " + recipe.result_item_id
			push_error("CraftingSystem: ItemManager failed to create " + recipe.result_item_id)
	else:
		# Failed craft
		result.message = "Failed to craft %s. %s Components were consumed." % [recipe.get_display_name(), roll_info]
		EventBus.craft_failed.emit(recipe)

	EventBus.craft_attempted.emit(recipe, success)

	return result

## Attempt to craft from ingredient selection (experimentation)
## Returns same dictionary as attempt_craft()
static func attempt_experiment(player: Player, ingredient_ids: Array[String], near_fire: bool, workstation_info: Dictionary = {}) -> Dictionary:
	var result = {
		"success": false,
		"result_item": null,
		"message": "",
		"recipe_learned": false
	}

	# Check if enemies are nearby - can't experiment in danger
	if are_enemies_nearby(player.position):
		result.message = "You can't craft while enemies are nearby!"
		return result

	if ingredient_ids.size() < 2 or ingredient_ids.size() > 4:
		result.message = "Select 2-4 ingredients to experiment"
		return result

	# Get workstation info if not provided
	if workstation_info.is_empty() and MapManager.current_map:
		workstation_info = StructureManager.get_workstation_info(
			player.position, MapManager.current_map.map_id, player.inventory
		)

	# Find matching recipe
	var recipe = RecipeManager.find_recipe_by_ingredients(ingredient_ids)

	if recipe:
		# Found a recipe! Attempt to craft it
		var craft_result = attempt_craft(player, recipe, near_fire, workstation_info)

		# Add experiment-specific messaging
		if craft_result.success:
			if craft_result.recipe_learned:
				craft_result.message = "Discovery! You learned how to craft %s." % recipe.get_display_name()
			else:
				craft_result.message = "You crafted %s." % recipe.get_display_name()

		return craft_result
	else:
		# No matching recipe - show hint based on INT
		var hint = get_experiment_hint(ingredient_ids, player.attributes["INT"])

		# Partially consume ingredients (50% chance each) on failed experiment
		var consumed_count = 0
		for item_id in ingredient_ids:
			if randf() < 0.5:
				player.inventory.remove_item_by_id(item_id, 1)
				consumed_count += 1

		EventBus.inventory_changed.emit()

		# Add consumption info to hint message
		if consumed_count == 0:
			result.message = hint + " Luckily, no materials were lost."
		elif consumed_count == ingredient_ids.size():
			result.message = hint + " All materials were lost."
		else:
			result.message = hint + " Some materials were lost."

		return result

## Get hint for failed experiment based on INT
static func get_experiment_hint(ingredient_ids: Array[String], intelligence: int) -> String:
	if intelligence >= 14:
		return "These materials don't seem compatible. Experiment failed, components lost."
	elif intelligence >= 10:
		return "You're not sure what these could make. Experiment failed."
	else:
		return "The experiment failed. Components were wasted."

## Get discovery hint for a recipe based on INT
static func get_discovery_hint(recipe: Recipe, intelligence: int) -> String:
	if intelligence >= 12:
		return recipe.discovery_hint
	elif intelligence >= 8:
		return "These materials might make something useful..."
	else:
		return "You're not sure what these could make."

## Calculate success chance for crafting
## Base success = 100% - (difficulty - 1) * 10%
## INT bonus = (INT - 10) * 5%
## Crafting skill bonus = crafting_skill * 1%
## Clamped to 50%-100%
static func calculate_success_chance(difficulty: int, intelligence: int, crafting_skill: int = 0) -> float:
	var base_success = 1.0 - (difficulty - 1) * 0.10
	var int_bonus = (intelligence - 10) * 0.05
	var skill_bonus = crafting_skill * 0.01  # +1% per skill level
	var final_success = base_success + int_bonus + skill_bonus
	return clampf(final_success, 0.5, 1.0)

## Check if there are enemies nearby (within specified range)
## Returns true if enemies are too close to craft safely
static func are_enemies_nearby(player_pos: Vector2i, danger_range: int = 5) -> bool:
	for entity in EntityManager.entities:
		if entity is Enemy and entity.is_alive:
			var distance = abs(entity.position.x - player_pos.x) + abs(entity.position.y - player_pos.y)
			if distance <= danger_range:
				return true
	return false

## Check if player is near a fire source (within 3 tiles)
static func is_near_fire(player_pos: Vector2i) -> bool:
	var fire_range = 3

	for offset_x in range(-fire_range, fire_range + 1):
		for offset_y in range(-fire_range, fire_range + 1):
			var check_pos = player_pos + Vector2i(offset_x, offset_y)

			# Check tiles for fire sources
			if MapManager.current_map:
				var tile = MapManager.current_map.get_tile(check_pos)
				if tile and "is_fire_source" in tile and tile.is_fire_source:
					return true

			# Check entities for fire sources
			var entities = EntityManager.get_entities_at(check_pos)
			for entity in entities:
				if "is_fire_source" in entity and entity.is_fire_source:
					return true

			# Check structures for fire sources (campfires)
			if MapManager.current_map:
				var map_id = MapManager.current_map.map_id
				var structures = StructureManager.get_structures_at(check_pos, map_id)
				for structure in structures:
					var fire_comp = structure.get_component("fire")
					if fire_comp and fire_comp.is_lit:
						return true

	return false

## Get success chance percentage as string (for UI display)
static func get_success_chance_string(difficulty: int, intelligence: int) -> String:
	var chance = calculate_success_chance(difficulty, intelligence)
	return "%d%%" % int(chance * 100)

## Check if player has required tool for workstation
## Returns: {ok: bool, message: String}
static func _check_workstation_tool(workstation_type: String, workstation_info: Dictionary, _inventory: Inventory) -> Dictionary:
	var result = {"ok": true, "message": ""}

	match workstation_type:
		"forge":
			if not workstation_info.get("near_forge", false):
				result.ok = false
				result.message = "You need to be near a forge."
			elif not workstation_info.get("forge_tool_ok", false):
				var tool_name = workstation_info.get("forge_tool_required", "tongs")
				result.ok = false
				result.message = "You need %s to use the forge." % tool_name
		"anvil":
			if not workstation_info.get("near_anvil", false):
				result.ok = false
				result.message = "You need to be near an anvil."
			elif not workstation_info.get("anvil_tool_ok", false):
				var tool_name = workstation_info.get("anvil_tool_required", "hammer")
				result.ok = false
				result.message = "You need a %s to use the anvil." % tool_name

	return result

## Get workstation info for a position (convenience method)
static func get_workstation_info(player_pos: Vector2i) -> Dictionary:
	if not MapManager.current_map:
		return {}
	# Note: This requires player inventory which we don't have here
	# Use StructureManager.get_workstation_info directly when you have the inventory
	return StructureManager.get_workstation_info(player_pos, MapManager.current_map.map_id, null)

## Consume workstation tool durability after successful craft
static func _consume_workstation_tool_durability(workstation_type: String, inventory: Inventory) -> void:
	var tool_type = ""
	match workstation_type:
		"forge":
			tool_type = "tongs"
		"anvil":
			tool_type = "hammer"

	if tool_type == "":
		return

	# Find the tool and reduce durability
	for item in inventory.items:
		if item.tool_type == tool_type:
			if "durability" in item and item.durability > 0:
				item.durability -= 1
				if item.durability <= 0:
					EventBus.message_log.emit("Your %s broke!" % item.name)
					inventory.remove_item(item)
				return
			elif item.durability == -1:
				# Infinite durability
				return


## Format d20 roll breakdown for display (grey colored)
## Returns: "[X (Roll) +Y (ATTR) +Z (Skill) = total vs DC N]"
static func _format_d20_roll(dice_roll: int, modifier: int, attr_name: String, skill: int, total: int, dc: int) -> String:
	var parts: Array[String] = ["%d (Roll)" % dice_roll]
	parts.append("%+d (%s)" % [modifier, attr_name])
	if skill > 0:
		parts.append("+%d (Skill)" % skill)
	parts.append("= %d vs DC %d" % [total, dc])
	return "[color=gray][%s][/color]" % " ".join(parts)
