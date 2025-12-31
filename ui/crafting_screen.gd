extends Control

## CraftingScreen - UI for crafting recipes
##
## Displays known recipes and allows crafting attempts.

@onready var recipe_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/RecipeList
@onready var fire_label: Label = $Panel/MarginContainer/VBoxContainer/FireStatus
@onready var message_label: Label = $Panel/MarginContainer/VBoxContainer/MessagePanel/MessageMargin/Message

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
		no_recipes.text = "No recipes known yet.\nExperiment by combining items to discover recipes!"
		no_recipes.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
		no_recipes.add_theme_font_size_override("font_size", 14)
		no_recipes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_recipes.autowrap_mode = TextServer.AUTOWRAP_WORD
		recipe_list.add_child(no_recipes)
	else:
		# Add each recipe
		for i in range(known_recipes.size()):
			var recipe = known_recipes[i]
			var recipe_label = _create_recipe_label(recipe, i == selected_recipe_index)
			recipe_list.add_child(recipe_label)

	message_label.text = " "

## Create a label for a recipe
func _create_recipe_label(recipe: Recipe, is_selected: bool) -> Label:
	var label = Label.new()

	# Check if can craft
	var can_craft = recipe.has_requirements(player.inventory, near_fire)
	var missing = recipe.get_missing_requirements(player.inventory, near_fire)

	# Build text
	var text = ""
	if is_selected:
		text += "▶ "
	else:
		text += "   "

	text += recipe.get_display_name()

	# Show status
	if can_craft:
		text += " [CAN CRAFT]"
	elif not missing.is_empty():
		text += " [MISSING]"

	text += "\n   Ingredients: "
	text += recipe.get_ingredient_list()

	# Tool requirement
	if recipe.tool_required != "":
		text += "\n   Tool: " + recipe.tool_required.capitalize()

	# Fire requirement
	if recipe.fire_required:
		text += "\n   Requires: Fire (within 3 tiles)"

	# Success chance
	var success_chance = CraftingSystem.get_success_chance_string(recipe.difficulty, player.attributes["INT"])
	text += "\n   Success: " + success_chance

	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 13)

	# Color based on availability
	if is_selected:
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5, 1))
	elif can_craft:
		label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1))
	else:
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))

	return label

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
