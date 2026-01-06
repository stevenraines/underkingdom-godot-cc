extends Node
## TrainingSystem - Handles recipe training purchases from NPCs
##
## Manages recipe training transactions with price calculations.
## Prices are affected by recipe difficulty and player's Charisma stat.

const CHARISMA_PRICE_MODIFIER = 0.05  ## 5% price change per CHA point from 10
const DIFFICULTY_PRICE_BONUS = 25     ## Gold added per difficulty level

## Calculates training price for a recipe
## Price = base_price + (difficulty * DIFFICULTY_PRICE_BONUS), modified by CHA
func calculate_training_price(base_price: int, difficulty: int, player_cha: int) -> int:
	var total_base = base_price + (difficulty * DIFFICULTY_PRICE_BONUS)
	var modifier = 1.0 - ((player_cha - 10) * CHARISMA_PRICE_MODIFIER)
	modifier = clamp(modifier, 0.5, 1.5)  # Range: 50%-150% of base price
	return max(1, int(total_base * modifier))

## Attempts to purchase recipe training from NPC
## Returns true if successful
func attempt_purchase_training(npc, recipe_id: String, player) -> bool:
	# Validate NPC has the recipe for sale
	var recipe_data = npc.get_recipe_for_sale(recipe_id)
	if recipe_data.is_empty():
		EventBus.emit_signal("message_logged", "%s doesn't teach that recipe." % npc.name)
		return false

	# Get the recipe definition
	var recipe = RecipeManager.get_recipe(recipe_id)
	if not recipe:
		EventBus.emit_signal("message_logged", "Recipe not found.")
		return false

	# Check if player already knows the recipe
	if player.knows_recipe(recipe_id):
		EventBus.emit_signal("message_logged", "You already know how to craft %s." % recipe.get_display_name())
		return false

	# Calculate price
	var base_price = recipe_data.get("base_price", 100)
	var price = calculate_training_price(base_price, recipe.difficulty, player.attributes["CHA"])

	# Check if player can afford it
	if player.gold < price:
		EventBus.emit_signal("message_logged", "Not enough gold. Need %d gold." % price)
		return false

	# Execute transaction
	player.gold -= price
	npc.gold += price
	player.learn_recipe(recipe_id)
	npc.remove_recipe_for_sale(recipe_id)

	EventBus.emit_signal("recipe_trained", recipe_id, price)
	EventBus.emit_signal("message_logged", "%s teaches you how to craft %s for %d gold." % [npc.name, recipe.get_display_name(), price])
	EventBus.recipe_discovered.emit(recipe)

	return true

## Gets formatted price string with CHA modifier display
func get_price_display(base_price: int, difficulty: int, player_cha: int) -> String:
	var final_price = calculate_training_price(base_price, difficulty, player_cha)
	var base_total = base_price + (difficulty * DIFFICULTY_PRICE_BONUS)

	if final_price == base_total:
		return "%dg" % final_price
	elif final_price < base_total:
		return "%dg (-%d%%)" % [final_price, int((1.0 - float(final_price) / base_total) * 100)]
	else:
		return "%dg (+%d%%)" % [final_price, int((float(final_price) / base_total - 1.0) * 100)]

## Get difficulty display as stars or text
func get_difficulty_display(difficulty: int) -> String:
	match difficulty:
		1: return "Easy"
		2: return "Simple"
		3: return "Moderate"
		4: return "Difficult"
		5: return "Expert"
		_: return "Unknown"
