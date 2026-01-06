extends Control

signal closed

## CraftingScreen - UI for crafting recipes and experimentation
##
## Displays known recipes and allows crafting attempts.
## Tab toggles between Recipe mode and Experiment mode.

enum CraftingMode { RECIPES, EXPERIMENT }

@onready var recipe_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/LeftPanel/ScrollContainer/RecipeList
@onready var fire_label: Label = $Panel/MarginContainer/VBoxContainer/FireStatus
@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/MessagePanel/MessageMargin/Message
@onready var recipe_name_label: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/RightPanel/RecipeNameLabel
@onready var details_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/RightPanel/DetailsScroll/DetailsContainer
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var left_panel_label: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/LeftPanel/RecipeListLabel

var player: Player = null
var near_fire: bool = false
var selected_recipe_index: int = 0
var known_recipes: Array = []  # Array of Recipe objects (RecipeManager provides them)

# Experiment mode variables
var current_mode: CraftingMode = CraftingMode.RECIPES
var experiment_materials: Array = []  # Available materials from inventory
var selected_material_index: int = 0
var selected_ingredients: Array[String] = []  # Item IDs selected for experiment (2-4)

func _ready() -> void:
	hide()

## Open crafting screen for player
func open(p: Player) -> void:
	player = p
	if not player:
		return

	# Reset to recipes mode
	current_mode = CraftingMode.RECIPES
	selected_recipe_index = 0
	selected_material_index = 0
	selected_ingredients.clear()

	# Check if near fire
	near_fire = CraftingSystem.is_near_fire(player.position)

	# Get known recipes
	known_recipes = player.get_known_recipes()

	# Build materials list for experiment mode
	_build_materials_list()

	# Update UI
	_update_display()
	show()

## Close crafting screen
func close() -> void:
	hide()
	player = null
	emit_signal("closed")

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_toggle_mode()
				get_viewport().set_input_as_handled()
			KEY_UP:
				_select_previous()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_select_next()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				_handle_accept()
				get_viewport().set_input_as_handled()
			KEY_BACKSPACE:
				if current_mode == CraftingMode.EXPERIMENT:
					_remove_last_ingredient()
					get_viewport().set_input_as_handled()
			KEY_C:
				if current_mode == CraftingMode.EXPERIMENT and selected_ingredients.size() >= 2:
					_attempt_experiment()
					get_viewport().set_input_as_handled()

func _toggle_mode() -> void:
	if current_mode == CraftingMode.RECIPES:
		current_mode = CraftingMode.EXPERIMENT
		selected_material_index = 0
		selected_ingredients.clear()
		_build_materials_list()
	else:
		current_mode = CraftingMode.RECIPES
		selected_recipe_index = 0
	_update_display()

func _handle_accept() -> void:
	if current_mode == CraftingMode.RECIPES:
		_attempt_craft_selected()
	else:
		# In experiment mode, Enter adds ingredient or combines if enough
		if selected_ingredients.size() >= 2 and selected_ingredients.size() < 4:
			# If we have 2-3 ingredients, Enter can combine or add
			_add_selected_ingredient()
		elif selected_ingredients.size() >= 4:
			# Max ingredients, attempt combine
			_attempt_experiment()
		else:
			_add_selected_ingredient()

func _build_materials_list() -> void:
	experiment_materials.clear()
	if not player:
		return

	# Get all items that could be used in crafting
	for item in player.inventory.items:
		# Include materials and consumables
		if item.item_type in ["material", "consumable"] or item.is_crafting_material():
			experiment_materials.append({
				"id": item.id,
				"name": item.name,
				"count": item.stack_size
			})

## Update the display with current recipes
func _update_display() -> void:
	# Update title based on mode
	if title_label:
		if current_mode == CraftingMode.RECIPES:
			title_label.text = "◆ CRAFTING - Recipes ◆  [Tab to Experiment]"
		else:
			title_label.text = "◆ CRAFTING - Experiment ◆  [Tab to Recipes]"

	# Update fire status
	if near_fire:
		fire_label.text = "Near Fire: YES"
		fire_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		fire_label.text = "Near Fire: NO"
		fire_label.add_theme_color_override("font_color", Color.GRAY)

	if current_mode == CraftingMode.RECIPES:
		_update_recipes_display()
	else:
		_update_experiment_display()

func _update_recipes_display() -> void:
	# Update left panel label
	if left_panel_label:
		left_panel_label.text = "Known Recipes"

	# Clear recipe list
	for child in recipe_list.get_children():
		child.queue_free()

	# Show recipes or "no recipes" message
	if known_recipes.is_empty():
		var no_recipes = Label.new()
		no_recipes.text = "No recipes known yet.\nPress Tab to experiment\nwith materials!"
		no_recipes.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		no_recipes.add_theme_font_size_override("font_size", 13)
		no_recipes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_recipes.autowrap_mode = TextServer.AUTOWRAP_WORD
		recipe_list.add_child(no_recipes)

		# Clear details panel
		recipe_name_label.text = "Select a recipe"
		_clear_details()
	else:
		# Add each recipe to left panel
		for i in range(known_recipes.size()):
			var recipe = known_recipes[i]
			var recipe_label = _create_recipe_list_item(recipe, i == selected_recipe_index)
			recipe_list.add_child(recipe_label)

		# Update details panel for selected recipe
		if selected_recipe_index < known_recipes.size():
			_update_details_panel(known_recipes[selected_recipe_index])

	message_label.text = "[Enter] Craft  |  [Tab] Experiment Mode"

func _update_experiment_display() -> void:
	# Update left panel label
	if left_panel_label:
		left_panel_label.text = "Your Materials"

	# Clear recipe list (used for materials in experiment mode)
	for child in recipe_list.get_children():
		child.queue_free()

	# Show materials
	if experiment_materials.is_empty():
		var no_materials = Label.new()
		no_materials.text = "No materials available\nfor experimentation."
		no_materials.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		no_materials.add_theme_font_size_override("font_size", 13)
		no_materials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_materials.autowrap_mode = TextServer.AUTOWRAP_WORD
		recipe_list.add_child(no_materials)
	else:
		for i in range(experiment_materials.size()):
			var mat = experiment_materials[i]
			var label = Label.new()

			var prefix = "► " if i == selected_material_index else "  "
			label.text = "%s%s (x%d)" % [prefix, mat.name, mat.count]
			label.add_theme_font_size_override("font_size", 13)

			if i == selected_material_index:
				label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5, 1))
			else:
				label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))

			recipe_list.add_child(label)

	# Update right panel with selected ingredients
	_update_experiment_details()

	# Update message
	if selected_ingredients.size() < 2:
		message_label.text = "Select 2-4 ingredients  |  [Enter] Add  |  [Tab] Recipe Mode"
	else:
		message_label.text = "[C] Combine  |  [Enter] Add more  |  [Backspace] Remove  |  [Tab] Recipes"

func _update_experiment_details() -> void:
	recipe_name_label.text = "Experiment"
	recipe_name_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.9, 1))

	_clear_details()

	# Header
	var header = Label.new()
	header.text = "Selected Ingredients (%d/4):" % selected_ingredients.size()
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	details_container.add_child(header)

	# Show selected ingredients
	for i in range(4):
		var slot_label = Label.new()
		slot_label.add_theme_font_size_override("font_size", 13)

		if i < selected_ingredients.size():
			var item_id = selected_ingredients[i]
			var item_data = ItemManager.get_item_data(item_id)
			var item_name = item_data.get("name", item_id) if not item_data.is_empty() else item_id
			slot_label.text = "  %d. %s" % [i + 1, item_name]
			slot_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
		else:
			slot_label.text = "  %d. -" % [i + 1]
			slot_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))

		details_container.add_child(slot_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	details_container.add_child(spacer)

	# Instructions
	var inst = Label.new()
	inst.text = "Combine items to discover\nnew recipes!"
	inst.add_theme_font_size_override("font_size", 12)
	inst.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	inst.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_container.add_child(inst)

	# Warning about partial consumption
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	details_container.add_child(spacer2)

	var warning = Label.new()
	warning.text = "Warning: Failed experiments\nmay partially consume\ningredients (50% chance each)"
	warning.add_theme_font_size_override("font_size", 11)
	warning.add_theme_color_override("font_color", Color(0.9, 0.6, 0.4, 1))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_container.add_child(warning)

func _add_selected_ingredient() -> void:
	if selected_ingredients.size() >= 4:
		message_label.text = "Maximum 4 ingredients! Press [C] to combine."
		message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))
		return

	if experiment_materials.is_empty() or selected_material_index >= experiment_materials.size():
		return

	var mat = experiment_materials[selected_material_index]

	# Check if we have enough of this material
	var already_selected_count = selected_ingredients.count(mat.id)
	if already_selected_count >= mat.count:
		message_label.text = "Not enough %s available!" % mat.name
		message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))
		return

	selected_ingredients.append(mat.id)
	_update_display()

func _remove_last_ingredient() -> void:
	if selected_ingredients.size() > 0:
		selected_ingredients.pop_back()
		_update_display()

func _attempt_experiment() -> void:
	if selected_ingredients.size() < 2:
		message_label.text = "Need at least 2 ingredients to experiment!"
		message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))
		return

	# Convert to typed array for CraftingSystem
	var ingredients: Array[String] = []
	for ing in selected_ingredients:
		ingredients.append(ing)

	var result = CraftingSystem.attempt_experiment(player, ingredients, near_fire)

	# Show result message
	message_label.text = result.message
	if result.success:
		message_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
		# Refresh known recipes if we learned something
		if result.recipe_learned:
			known_recipes = player.get_known_recipes()
	else:
		message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))

	# Clear selected ingredients and refresh materials
	selected_ingredients.clear()
	_build_materials_list()
	_update_display()

	# Advance turn
	TurnManager.advance_turn()

## Create a simple label for recipe list (left panel)
func _create_recipe_list_item(recipe: Recipe, is_selected: bool) -> Label:
	var label = Label.new()

	# Check if can craft
	var can_craft = recipe.has_requirements(player.inventory, near_fire)

	# Get the item color
	var item_data = ItemManager.get_item_data(recipe.result_item_id)
	var item_color = Color.WHITE
	if not item_data.is_empty() and "ascii_color" in item_data:
		item_color = Color.from_string(item_data["ascii_color"], Color.WHITE)

	# Build text
	var text = ""
	if is_selected:
		text += "▶ "
	else:
		text += "  "

	text += recipe.get_display_name()

	label.text = text
	label.add_theme_font_size_override("font_size", 14)

	# Color: item color if craftable, grayscale if not
	if can_craft:
		label.add_theme_color_override("font_color", item_color)
	else:
		# Convert to grayscale
		var gray = (item_color.r + item_color.g + item_color.b) / 3.0
		label.add_theme_color_override("font_color", Color(gray, gray, gray, 1.0))

	return label

## Update the details panel on the right
func _update_details_panel(recipe: Recipe) -> void:
	# Update recipe name
	var item_data = ItemManager.get_item_data(recipe.result_item_id)
	recipe_name_label.text = recipe.get_display_name()
	if not item_data.is_empty() and "ascii_color" in item_data:
		var item_color = Color.from_string(item_data["ascii_color"], Color.WHITE)
		recipe_name_label.add_theme_color_override("font_color", item_color)

	# Clear previous details
	_clear_details()

	# Add ingredients section
	var ingredients_label = Label.new()
	ingredients_label.text = "Ingredients:"
	ingredients_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	ingredients_label.add_theme_font_size_override("font_size", 14)
	details_container.add_child(ingredients_label)

	# Show each ingredient with count
	for ingredient in recipe.ingredients:
		var ingredient_item_data = ItemManager.get_item_data(ingredient["item"])
		if not ingredient_item_data.is_empty():
			var have_count = player.inventory.get_item_count(ingredient["item"])
			var need_count = ingredient["count"]

			var ingredient_label = Label.new()
			ingredient_label.text = "  %s: %d/%d" % [
				ingredient_item_data.get("name", "Unknown"),
				have_count,
				need_count
			]
			ingredient_label.add_theme_font_size_override("font_size", 13)

			# Color: green if have enough, red if not
			if have_count >= need_count:
				ingredient_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
			else:
				ingredient_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))

			details_container.add_child(ingredient_label)

	# Tool requirement
	if recipe.tool_required != "":
		var tool_label = Label.new()
		var has_tool = player.inventory.has_tool(recipe.tool_required)
		tool_label.text = "Tool: %s %s" % [
			recipe.tool_required.capitalize(),
			"✓" if has_tool else "✗"
		]
		tool_label.add_theme_font_size_override("font_size", 13)
		if has_tool:
			tool_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
		else:
			tool_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))
		details_container.add_child(tool_label)

	# Fire requirement
	if recipe.fire_required:
		var fire_req_label = Label.new()
		fire_req_label.text = "Requires: Fire (within 3 tiles) %s" % ["✓" if near_fire else "✗"]
		fire_req_label.add_theme_font_size_override("font_size", 13)
		if near_fire:
			fire_req_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
		else:
			fire_req_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))
		details_container.add_child(fire_req_label)

	# Success chance
	var success_label = Label.new()
	var success_chance = CraftingSystem.get_success_chance_string(recipe.difficulty, player.attributes["INT"])
	success_label.text = "Success Chance: %s" % success_chance
	success_label.add_theme_font_size_override("font_size", 13)
	success_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	details_container.add_child(success_label)

	# Result
	var result_label = Label.new()
	result_label.text = "\nResult: %s (×%d)" % [recipe.get_display_name(), recipe.result_count]
	result_label.add_theme_font_size_override("font_size", 13)
	if not item_data.is_empty() and "ascii_color" in item_data:
		var result_color = Color.from_string(item_data["ascii_color"], Color.WHITE)
		result_label.add_theme_color_override("font_color", result_color)
	details_container.add_child(result_label)

## Clear details panel
func _clear_details() -> void:
	for child in details_container.get_children():
		child.queue_free()

## Select previous recipe
func _select_previous() -> void:
	if current_mode == CraftingMode.RECIPES:
		if known_recipes.is_empty():
			return
		selected_recipe_index = (selected_recipe_index - 1 + known_recipes.size()) % known_recipes.size()
	else:
		if experiment_materials.is_empty():
			return
		selected_material_index = (selected_material_index - 1 + experiment_materials.size()) % experiment_materials.size()
	_update_display()

## Select next recipe
func _select_next() -> void:
	if current_mode == CraftingMode.RECIPES:
		if known_recipes.is_empty():
			return
		selected_recipe_index = (selected_recipe_index + 1) % known_recipes.size()
	else:
		if experiment_materials.is_empty():
			return
		selected_material_index = (selected_material_index + 1) % experiment_materials.size()
	_update_display()

## Attempt to craft the selected recipe
func _attempt_craft_selected() -> void:
	if known_recipes.is_empty():
		return

	var recipe = known_recipes[selected_recipe_index]

	# Attempt craft
	var result = CraftingSystem.attempt_craft(player, recipe, near_fire)

	# Show result message
	message_label.text = result.message
	if result.success:
		message_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
	else:
		message_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1))

	# Refresh display (ingredients may have changed)
	_update_display()

	# Advance turn (crafting takes time)
	if result.success or "consumed" in result.message.to_lower():
		TurnManager.advance_turn()
