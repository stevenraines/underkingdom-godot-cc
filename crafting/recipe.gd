class_name Recipe
extends RefCounted

## Recipe - Represents a crafting recipe
##
## Defines ingredients, requirements (tools, fire), and result of crafting.

var id: String = ""                         # Unique identifier (e.g., "leather_armor")
var result_item_id: String = ""             # Item ID to create
var result_count: int = 1                   # How many items produced
var ingredients: Array[Dictionary] = []     # [{item: String, count: int}]
var tool_required: String = ""              # Tool type needed ("knife", "hammer", "")
var fire_required: bool = false             # Must be near fire?
var difficulty: int = 1                     # Base difficulty (1-5)
var discovery_hint: String = ""             # INT-based hint text

## Create recipe from JSON data
static func create_from_data(data: Dictionary) -> Recipe:
	var recipe = Recipe.new()

	recipe.id = data.get("id", "")
	recipe.result_item_id = data.get("result", "")
	recipe.result_count = data.get("result_count", 1)
	recipe.tool_required = data.get("tool_required", "")
	recipe.fire_required = data.get("fire_required", false)
	recipe.difficulty = data.get("difficulty", 1)
	recipe.discovery_hint = data.get("discovery_hint", "")

	# Parse ingredients array
	var ingredient_data = data.get("ingredients", [])
	for ingredient in ingredient_data:
		recipe.ingredients.append({
			"item": ingredient.get("item", ""),
			"count": ingredient.get("count", 1)
		})

	return recipe

## Check if player has all requirements to craft this recipe
func has_requirements(inventory: Inventory, near_fire: bool) -> bool:
	# Check ingredients
	for ingredient in ingredients:
		if not inventory.has_item(ingredient["item"], ingredient["count"]):
			return false

	# Check tool requirement
	if tool_required != "" and not inventory.has_tool(tool_required):
		return false

	# Check fire requirement
	if fire_required and not near_fire:
		return false

	return true

## Get list of missing requirements (for UI display)
func get_missing_requirements(inventory: Inventory, near_fire: bool) -> Array[String]:
	var missing: Array[String] = []

	# Check ingredients
	for ingredient in ingredients:
		var needed = ingredient["count"]
		var have = inventory.get_item_count(ingredient["item"])
		if have < needed:
			var item_name = ItemManager.get_item_data(ingredient["item"]).get("name", ingredient["item"])
			missing.append("%s (need %d, have %d)" % [item_name, needed, have])

	# Check tool
	if tool_required != "" and not inventory.has_tool(tool_required):
		missing.append("Tool: %s" % tool_required.capitalize())

	# Check fire
	if fire_required and not near_fire:
		missing.append("Fire source (within 3 tiles)")

	return missing

## Consume ingredients from inventory (returns true if successful)
func consume_ingredients(inventory: Inventory) -> bool:
	# First check we have everything (safety check)
	for ingredient in ingredients:
		if not inventory.has_item(ingredient["item"], ingredient["count"]):
			push_error("Recipe.consume_ingredients: Missing ingredient %s" % ingredient["item"])
			return false

	# Remove all ingredients
	for ingredient in ingredients:
		var removed = inventory.remove_item_by_id(ingredient["item"], ingredient["count"])
		if removed != ingredient["count"]:
			push_error("Recipe.consume_ingredients: Failed to remove %s" % ingredient["item"])
			return false

	return true

## Get display name for recipe (uses result item name)
func get_display_name() -> String:
	var item_data = ItemManager.get_item_data(result_item_id)
	return item_data.get("name", result_item_id)

## Get formatted ingredient list for display
func get_ingredient_list() -> String:
	var parts: Array[String] = []
	for ingredient in ingredients:
		var item_data = ItemManager.get_item_data(ingredient["item"])
		var item_name = item_data.get("name", ingredient["item"])
		var count = ingredient["count"]
		if count > 1:
			parts.append("%s x%d" % [item_name, count])
		else:
			parts.append(item_name)
	return ", ".join(parts)
