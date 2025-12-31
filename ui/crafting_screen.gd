extends Control

## CraftingScreen - UI for crafting recipes
##
## Displays known recipes and allows crafting attempts.

@onready var recipe_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/LeftPanel/ScrollContainer/RecipeList
@onready var fire_label: Label = $Panel/MarginContainer/VBoxContainer/FireStatus
@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/MessagePanel/MessageMargin/Message
@onready var recipe_name_label: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/RightPanel/RecipeNameLabel
@onready var details_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/RightPanel/DetailsScroll/DetailsContainer

var player: Player = null
var near_fire: bool = false
var selected_recipe_index: int = 0
var known_recipes: Array = []  # Array of Recipe objects (RecipeManager provides them)

func _ready() -> void:
	hide()

## Open crafting screen for player
func open(p: Player) -> void:
	player = p
	if not player:
		return

	# Check if near fire
	near_fire = CraftingSystem.is_near_fire(player.position)

	# Get known recipes
	known_recipes = player.get_known_recipes()
	selected_recipe_index = 0

	# Update UI
	_update_display()
	show()

## Close crafting screen
func close() -> void:
	hide()
	player = null

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_select_previous()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_select_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_attempt_craft_selected()
		get_viewport().set_input_as_handled()

## Update the display with current recipes
func _update_display() -> void:
	# Update fire status
	if near_fire:
		fire_label.text = "🔥 Near Fire: YES"
		fire_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		fire_label.text = "Near Fire: NO"
		fire_label.add_theme_color_override("font_color", Color.GRAY)

	# Clear recipe list
	for child in recipe_list.get_children():
		child.queue_free()

	# Show recipes or "no recipes" message
	if known_recipes.is_empty():
		var no_recipes = Label.new()
		no_recipes.text = "No recipes known yet.\nExperiment by combining items\nto discover recipes!"
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

	message_label.text = " "

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
			var have_count = player.inventory.count_item_by_id(ingredient["item"])
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
	if known_recipes.is_empty():
		return
	selected_recipe_index = (selected_recipe_index - 1 + known_recipes.size()) % known_recipes.size()
	_update_display()

## Select next recipe
func _select_next() -> void:
	if known_recipes.is_empty():
		return
	selected_recipe_index = (selected_recipe_index + 1) % known_recipes.size()
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
