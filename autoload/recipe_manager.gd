extends Node

## RecipeManager - Manages all crafting recipes
##
## Loads recipe definitions from JSON, provides recipe lookup and discovery.

# Preload Recipe class
const RecipeClass = preload("res://crafting/recipe.gd")

# All recipes indexed by recipe ID
var all_recipes: Dictionary = {}

# Recipes indexed by result item ID (for lookup by item)
var recipes_by_result: Dictionary = {}

# Base path for recipe data
const RECIPE_DATA_BASE_PATH: String = "res://data/recipes"

func _ready() -> void:
	print("RecipeManager initialized")
	_load_all_recipes()

## Load all recipes by recursively scanning folders
func _load_all_recipes() -> void:
	var files = JsonHelper.load_all_from_directory(RECIPE_DATA_BASE_PATH)
	for file_entry in files:
		_process_recipe_data(file_entry.path, file_entry.data)
	print("RecipeManager: Loaded %d recipes" % all_recipes.size())


## Process loaded recipe data
func _process_recipe_data(file_path: String, data) -> void:
	if data is Dictionary and "id" in data:
		var recipe = RecipeClass.create_from_data(data)
		all_recipes[recipe.id] = recipe

		# Index by result item
		if recipe.result_item_id not in recipes_by_result:
			recipes_by_result[recipe.result_item_id] = []
		recipes_by_result[recipe.result_item_id].append(recipe)

		print("Loaded recipe: ", recipe.id)
	else:
		push_warning("RecipeManager: Invalid recipe file format in %s" % file_path)

## Get recipe by ID
func get_recipe(recipe_id: String) -> Recipe:
	return all_recipes.get(recipe_id, null)

## Get all recipes that produce a specific item
func get_recipes_for_item(item_id: String) -> Array[Recipe]:
	var result: Array[Recipe] = []
	if item_id in recipes_by_result:
		result.assign(recipes_by_result[item_id])
	return result

## Find recipe that matches ingredient combination (for experimentation)
## Returns null if no match found
func find_recipe_by_ingredients(ingredient_ids: Array[String]) -> Recipe:
	# Sort ingredient IDs for comparison
	var sorted_ingredients = ingredient_ids.duplicate()
	sorted_ingredients.sort()

	# Check each recipe
	for recipe_id in all_recipes:
		var recipe: Recipe = all_recipes[recipe_id]

		# Build sorted list of this recipe's ingredients
		var recipe_ingredients: Array[String] = []
		for ingredient in recipe.ingredients:
			for i in range(ingredient["count"]):
				recipe_ingredients.append(ingredient["item"])
		recipe_ingredients.sort()

		# Compare
		if recipe_ingredients == sorted_ingredients:
			return recipe

	return null

## Get all recipe IDs
func get_all_recipe_ids() -> Array[String]:
	var result: Array[String] = []
	for recipe_id in all_recipes:
		result.append(recipe_id)
	return result

## Get all recipes (for debugging/admin)
func get_all_recipes() -> Array[Recipe]:
	var result: Array[Recipe] = []
	for recipe_id in all_recipes:
		result.append(all_recipes[recipe_id])
	return result
