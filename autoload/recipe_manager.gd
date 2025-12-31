extends Node

## RecipeManager - Manages all crafting recipes
##
## Loads recipe definitions from JSON, provides recipe lookup and discovery.

# Preload Recipe class
const Recipe = preload("res://crafting/recipe.gd")

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
	_load_recipes_from_folder(RECIPE_DATA_BASE_PATH)
	print("RecipeManager: Loaded %d recipes" % all_recipes.size())

## Recursively load recipes from a folder and all subfolders
func _load_recipes_from_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("RecipeManager: Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name

		if dir.current_is_dir():
			# Skip hidden folders and navigate into subfolders
			if not file_name.begins_with("."):
				_load_recipes_from_folder(full_path)
		elif file_name.ends_with(".json"):
			# Load JSON file as recipe data
			_load_recipe_from_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

## Load a single recipe from a JSON file
func _load_recipe_from_file(file_path: String) -> void:
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_error("RecipeManager: Failed to load recipe file: " + file_path)
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		push_error("RecipeManager: Failed to parse recipe JSON: %s at line %d" % [file_path, json.get_error_line()])
		return

	var data = json.data

	if data is Dictionary and "id" in data:
		var recipe = Recipe.create_from_data(data)
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
