class_name Recipe
extends RefCounted

## Recipe - Represents a crafting recipe
##
## Defines ingredients, requirements (tools, fire), and result of crafting.
## Supports seeded_ingredients for world-seed-based dynamic recipes.
## seeded_ingredients can be a single config or an array of configs, allowing
## recipes to require multiple ingredient types (e.g., 1 mushroom + 2 herbs).
##
## Ingredients can be specified by:
##   - item: Specific item ID (e.g., {"item": "raw_meat", "count": 1})
##   - flag: Any item with the flag (e.g., {"flag": "fish", "count": 1, "display_name": "Any Fish"})

var id: String = ""                         # Unique identifier (e.g., "leather_armor")
var result_item_id: String = ""             # Item ID to create
var result_count: int = 1                   # How many items produced
var ingredients: Array[Dictionary] = []     # [{item: String, count: int}] or [{flag: String, count: int, display_name: String}]
var tool_required: String = ""              # Tool type needed ("knife", "hammer", "")
var fire_required: bool = false             # Must be near fire? (legacy, use workstation_required: "forge" instead)
var workstation_required: String = ""       # Workstation needed ("forge", "anvil", "")
var difficulty: int = 1                     # Base difficulty (1-5)
var discovery_hint: String = ""             # INT-based hint text

# Seeded ingredients - dynamically determined by world seed
# Can be a single config dict or an array of configs:
# Single: {count, template, variant_type, seed_offset}
# Array: [{count, template, variant_type, seed_offset}, ...]
var seeded_ingredients = null               # Dictionary or Array

## Create recipe from JSON data
static func create_from_data(data: Dictionary) -> Recipe:
	var recipe = Recipe.new()

	recipe.id = data.get("id", "")
	recipe.result_item_id = data.get("result", "")
	recipe.result_count = data.get("result_count", 1)
	recipe.tool_required = data.get("tool_required", "")
	recipe.fire_required = data.get("fire_required", false)
	recipe.workstation_required = data.get("workstation_required", "")
	recipe.difficulty = data.get("difficulty", 1)
	recipe.discovery_hint = data.get("discovery_hint", "")

	# Parse ingredients array (supports both item-based and flag-based)
	var ingredient_data = data.get("ingredients", [])
	for ingredient in ingredient_data:
		if ingredient.has("flag"):
			# Flag-based ingredient: matches any item with the specified flag
			recipe.ingredients.append({
				"flag": ingredient.get("flag", ""),
				"count": ingredient.get("count", 1),
				"display_name": ingredient.get("display_name", "Any " + ingredient.get("flag", "").capitalize())
			})
		else:
			# Item-based ingredient: matches specific item ID
			recipe.ingredients.append({
				"item": ingredient.get("item", ""),
				"count": ingredient.get("count", 1)
			})

	# Parse seeded ingredients (for dynamic recipes)
	# Can be a single dict or an array of dicts
	var raw_seeded = data.get("seeded_ingredients", null)
	if raw_seeded != null:
		if raw_seeded is Array:
			recipe.seeded_ingredients = raw_seeded
		elif raw_seeded is Dictionary and not raw_seeded.is_empty():
			# Convert single config to array for uniform handling
			recipe.seeded_ingredients = [raw_seeded]

	return recipe


## Check if this recipe has seeded (dynamic) ingredients
func has_seeded_ingredients() -> bool:
	return seeded_ingredients != null and seeded_ingredients is Array and not seeded_ingredients.is_empty()


## Get normalized seeded ingredient configs as array
func _get_seeded_configs() -> Array:
	if seeded_ingredients == null:
		return []
	if seeded_ingredients is Array:
		return seeded_ingredients
	return []


## Get the specific variant item IDs required based on world seed
## Returns array of item IDs like ["chamomile_herb", "mint_herb", "button_mushroom"]
func get_seeded_ingredient_ids(world_seed: int) -> Array[String]:
	var result: Array[String] = []
	var configs = _get_seeded_configs()

	for config in configs:
		var ids = _get_seeded_ids_for_config(config, world_seed)
		for item_id in ids:
			result.append(item_id)

	return result


## Get item IDs for a single seeded config
func _get_seeded_ids_for_config(config: Dictionary, world_seed: int) -> Array[String]:
	var count = config.get("count", 3)
	var template = config.get("template", "herb")
	var variant_type = config.get("variant_type", "herb_species")
	var seed_offset = config.get("seed_offset", 0)

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
	var names: Array[String] = []
	var configs = _get_seeded_configs()

	for config in configs:
		var config_names = _get_seeded_names_for_config(config, world_seed)
		for name in config_names:
			names.append(name)

	return names


## Get display names for a single seeded config
func _get_seeded_names_for_config(config: Dictionary, world_seed: int) -> Array[String]:
	var variant_type = config.get("variant_type", "herb_species")
	var item_ids = _get_seeded_ids_for_config(config, world_seed)
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
## workstation_info: Dictionary with "near_forge" and "near_anvil" bools, or null to skip workstation check
func has_requirements(inventory: Inventory, near_fire: bool, workstation_info: Dictionary = {}) -> bool:
	# Check regular ingredients (item-based or flag-based)
	for ingredient in ingredients:
		if ingredient.has("flag"):
			# Flag-based ingredient
			if inventory.get_item_count_with_flag(ingredient["flag"]) < ingredient["count"]:
				return false
		else:
			# Item-based ingredient
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

	# Check fire requirement (legacy - forge also provides fire)
	if fire_required and not near_fire:
		# If we require fire and there's a forge nearby, that counts as fire
		if not workstation_info.get("near_forge", false):
			return false

	# Check workstation requirement
	if workstation_required != "":
		match workstation_required:
			"forge":
				if not workstation_info.get("near_forge", false):
					return false
			"anvil":
				if not workstation_info.get("near_anvil", false):
					return false

	return true

## Get list of missing requirements (for UI display)
func get_missing_requirements(inventory: Inventory, near_fire: bool, workstation_info: Dictionary = {}) -> Array[String]:
	var missing: Array[String] = []

	# Check regular ingredients (item-based or flag-based)
	for ingredient in ingredients:
		var needed = ingredient["count"]
		if ingredient.has("flag"):
			# Flag-based ingredient
			var have = inventory.get_item_count_with_flag(ingredient["flag"])
			if have < needed:
				var display_name = ingredient.get("display_name", "Any " + ingredient["flag"].capitalize())
				missing.append("%s (need %d, have %d)" % [display_name, needed, have])
		else:
			# Item-based ingredient
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

	# Check fire (legacy - forge also provides fire)
	if fire_required and not near_fire:
		if not workstation_info.get("near_forge", false):
			missing.append("Fire source (within 3 tiles)")

	# Check workstation
	if workstation_required != "":
		match workstation_required:
			"forge":
				if not workstation_info.get("near_forge", false):
					missing.append("Forge (within 3 tiles)")
			"anvil":
				if not workstation_info.get("near_anvil", false):
					missing.append("Anvil (within 3 tiles)")

	return missing

## Consume ingredients from inventory (returns true if successful)
func consume_ingredients(inventory: Inventory) -> bool:
	# First check we have everything (safety check)
	for ingredient in ingredients:
		if ingredient.has("flag"):
			# Flag-based ingredient
			if inventory.get_item_count_with_flag(ingredient["flag"]) < ingredient["count"]:
				push_error("Recipe.consume_ingredients: Missing flag-based ingredient %s" % ingredient["flag"])
				return false
		else:
			# Item-based ingredient
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

	# Remove all regular ingredients (item-based or flag-based)
	for ingredient in ingredients:
		if ingredient.has("flag"):
			# Flag-based ingredient
			var removed = inventory.remove_item_with_flag(ingredient["flag"], ingredient["count"])
			if removed != ingredient["count"]:
				push_error("Recipe.consume_ingredients: Failed to remove flag-based %s" % ingredient["flag"])
				return false
		else:
			# Item-based ingredient
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

	# Regular ingredients (item-based or flag-based)
	for ingredient in ingredients:
		var count = ingredient["count"]
		var item_name: String
		if ingredient.has("flag"):
			# Flag-based ingredient
			item_name = ingredient.get("display_name", "Any " + ingredient["flag"].capitalize())
		else:
			# Item-based ingredient
			var item_data = ItemManager.get_item_data(ingredient["item"])
			item_name = item_data.get("name", ingredient["item"])
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
