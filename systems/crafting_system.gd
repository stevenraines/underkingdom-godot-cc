class_name CraftingSystem
extends RefCounted

## CraftingSystem - Handles crafting attempts, success/failure, and discovery
##
## Static class that provides crafting functionality with discovery mechanics.

## Attempt to craft a recipe
## Returns: {success: bool, result_item: Item, message: String, recipe_learned: bool}
static func attempt_craft(player: Player, recipe: Recipe, near_fire: bool) -> Dictionary:
	var result = {
		"success": false,
		"result_item": null,
		"message": "",
		"recipe_learned": false
	}

	# Check if has all ingredients
	if not recipe.has_requirements(player.inventory, near_fire):
		var missing = recipe.get_missing_requirements(player.inventory, near_fire)
		result.message = "Missing requirements: " + ", ".join(missing)
		return result

	# Calculate success chance
	var success_chance = calculate_success_chance(recipe.difficulty, player.attributes["INT"])

	# Roll for success
	var roll = randf()
	var success = roll <= success_chance

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

			# Learn recipe if not already known
			if not player.knows_recipe(recipe.id):
				player.learn_recipe(recipe.id)
				result.recipe_learned = true
				EventBus.recipe_discovered.emit(recipe)

			result.success = true
			result.message = "Successfully crafted %s!" % recipe.get_display_name()

			EventBus.craft_succeeded.emit(recipe, result.result_item)
		else:
			result.message = "Error: Could not create item " + recipe.result_item_id
			push_error("CraftingSystem: ItemManager failed to create " + recipe.result_item_id)
	else:
		# Failed craft
		result.message = "Failed to craft %s. Components were consumed." % recipe.get_display_name()
		EventBus.craft_failed.emit(recipe)

	EventBus.craft_attempted.emit(recipe, success)

	return result

## Attempt to craft from ingredient selection (experimentation)
## Returns same dictionary as attempt_craft()
static func attempt_experiment(player: Player, ingredient_ids: Array[String], near_fire: bool) -> Dictionary:
	var result = {
		"success": false,
		"result_item": null,
		"message": "",
		"recipe_learned": false
	}

	if ingredient_ids.size() < 2 or ingredient_ids.size() > 4:
		result.message = "Select 2-4 ingredients to experiment"
		return result

	# Find matching recipe
	var recipe = RecipeManager.find_recipe_by_ingredients(ingredient_ids)

	if recipe:
		# Found a recipe! Attempt to craft it
		var craft_result = attempt_craft(player, recipe, near_fire)

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

		# Consume ingredients anyway (failed experiment)
		for item_id in ingredient_ids:
			player.inventory.remove_item_by_id(item_id, 1)

		EventBus.inventory_changed.emit()

		result.message = hint
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
## Clamped to 50%-100%
static func calculate_success_chance(difficulty: int, intelligence: int) -> float:
	var base_success = 1.0 - (difficulty - 1) * 0.10
	var int_bonus = (intelligence - 10) * 0.05
	var final_success = base_success + int_bonus
	return clampf(final_success, 0.5, 1.0)

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
