class_name Recipe
extends RefCounted

## Recipe - Represents a crafting recipe
##
## Defines ingredients, requirements (tools, fire), and result of crafting.
## Supports seeded_ingredients for world-seed-based dynamic recipes.

var id: String = ""                         # Unique identifier (e.g., "leather_armor")
var result_item_id: String = ""             # Item ID to create
var result_count: int = 1                   # How many items produced
var ingredients: Array[Dictionary] = []     # [{item: String, count: int}]
var tool_required: String = ""              # Tool type needed ("knife", "hammer", "")
var fire_required: bool = false             # Must be near fire?
var difficulty: int = 1                     # Base difficulty (1-5)
var discovery_hint: String = ""             # INT-based hint text

# Seeded ingredients - dynamically determined by world seed
var seeded_ingredients: Dictionary = {}     # {count, template, variant_type, seed_offset}

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

	# Parse seeded ingredients (for dynamic recipes)
	recipe.seeded_ingredients = data.get("seeded_ingredients", {})

	return recipe


## Check if this recipe has seeded (dynamic) ingredients
func has_seeded_ingredients() -> bool:
	return not seeded_ingredients.is_empty()


## Get the specific variant item IDs required based on world seed
## Returns array of item IDs like ["chamomile_herb", "mint_herb", "sage_herb"]
func get_seeded_ingredient_ids(world_seed: int) -> Array[String]:
	if seeded_ingredients.is_empty():
		return []

	var count = seeded_ingredients.get("count", 3)
	var template = seeded_ingredients.get("template", "herb")
	var variant_type = seeded_ingredients.get("variant_type", "herb_species")
	var seed_offset = seeded_ingredients.get("seed_offset", 0)

	# Get all variants of this type
	var all_variants = VariantManager.get_variants_of_type(variant_type)
	if all_variants.is_empty():
		return []

	# Create shuffled list using seeded random
	var variant_names: Array[String] = []
	for variant_name in all_variants:
		variant_names.append(variant_name)

	# Use SeededRandom to deterministically select variants
	var rng = SeededRandom.new(world_seed + seed_offset)
	rng.shuffle_array(variant_names)

	# Take first 'count' variants and create item IDs
	var result: Array[String] = []
	for i in range(mini(count, variant_names.size())):
		# Item ID format: variant_template (e.g., "chamomile_herb")
		result.append(variant_names[i] + "_" + template)

	return result


## Get the display names of seeded ingredients
func get_seeded_ingredient_names(world_seed: int) -> Array[String]:
	if seeded_ingredients.is_empty():
		return []

	var variant_type = seeded_ingredients.get("variant_type", "herb_species")
	var item_ids = get_seeded_ingredient_ids(world_seed)
	var names: Array[String] = []

	for item_id in item_ids:
		# Extract variant name from item_id (e.g., "chamomile" from "chamomile_herb")
		var parts = item_id.rsplit("_", true, 1)
		if parts.size() > 0:
			var variant_name = parts[0]
			var variant_data = VariantManager.get_variant(variant_type, variant_name)
			var display_name = variant_data.get("name_override", variant_name.capitalize())
			names.append(display_name)

	return names

## Check if player has all requirements to craft this recipe
## For seeded recipes, uses GameManager.world_seed
func has_requirements(inventory: Inventory, near_fire: bool) -> bool:
	# Check regular ingredients
	for ingredient in ingredients:
		if not inventory.has_item(ingredient["item"], ingredient["count"]):
			return false

	# Check seeded ingredients
	if has_seeded_ingredients():
		var world_seed = GameManager.world_seed if GameManager else 0
		var seeded_item_ids = get_seeded_ingredient_ids(world_seed)
		for item_id in seeded_item_ids:
			if not inventory.has_item(item_id, 1):
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

	# Check regular ingredients
	for ingredient in ingredients:
		var needed = ingredient["count"]
		var have = inventory.get_item_count(ingredient["item"])
		if have < needed:
			var item_name = ItemManager.get_item_data(ingredient["item"]).get("name", ingredient["item"])
			missing.append("%s (need %d, have %d)" % [item_name, needed, have])

	# Check seeded ingredients
	if has_seeded_ingredients():
		var world_seed = GameManager.world_seed if GameManager else 0
		var seeded_item_ids = get_seeded_ingredient_ids(world_seed)
		var seeded_names = get_seeded_ingredient_names(world_seed)
		for i in range(seeded_item_ids.size()):
			var item_id = seeded_item_ids[i]
			var have = inventory.get_item_count(item_id)
			if have < 1:
				var item_name = seeded_names[i] if i < seeded_names.size() else item_id
				missing.append("%s (need 1, have %d)" % [item_name, have])

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

	# Check seeded ingredients
	var seeded_item_ids: Array[String] = []
	if has_seeded_ingredients():
		var world_seed = GameManager.world_seed if GameManager else 0
		seeded_item_ids = get_seeded_ingredient_ids(world_seed)
		for item_id in seeded_item_ids:
			if not inventory.has_item(item_id, 1):
				push_error("Recipe.consume_ingredients: Missing seeded ingredient %s" % item_id)
				return false

	# Remove all regular ingredients
	for ingredient in ingredients:
		var removed = inventory.remove_item_by_id(ingredient["item"], ingredient["count"])
		if removed != ingredient["count"]:
			push_error("Recipe.consume_ingredients: Failed to remove %s" % ingredient["item"])
			return false

	# Remove seeded ingredients
	for item_id in seeded_item_ids:
		var removed = inventory.remove_item_by_id(item_id, 1)
		if removed != 1:
			push_error("Recipe.consume_ingredients: Failed to remove seeded ingredient %s" % item_id)
			return false

	return true

## Get display name for recipe (uses result item name)
func get_display_name() -> String:
	var item_data = ItemManager.get_item_data(result_item_id)
	return item_data.get("name", result_item_id)

## Get formatted ingredient list for display
func get_ingredient_list() -> String:
	var parts: Array[String] = []

	# Regular ingredients
	for ingredient in ingredients:
		var item_data = ItemManager.get_item_data(ingredient["item"])
		var item_name = item_data.get("name", ingredient["item"])
		var count = ingredient["count"]
		if count > 1:
			parts.append("%s x%d" % [item_name, count])
		else:
			parts.append(item_name)

	# Seeded ingredients
	if has_seeded_ingredients():
		var world_seed = GameManager.world_seed if GameManager else 0
		var seeded_names = get_seeded_ingredient_names(world_seed)
		for name in seeded_names:
			parts.append(name)

	return ", ".join(parts)
