extends Control

## TrainingScreen - UI for learning recipes from NPCs
##
## Shows available recipes the NPC can teach and their details.
## Does NOT show ingredients (player must discover those).

const TrainingSystem = preload("res://systems/training_system.gd")

signal closed()
signal switch_to_trade(npc, player)  # Signal to switch to shop screen

@onready var recipe_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/RecipePanel/ScrollContainer
@onready var recipe_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/RecipePanel/ScrollContainer/RecipeList
@onready var details_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/DetailsPanel/ScrollContainer/DetailsContainer
@onready var trainer_label: Label = $Panel/MarginContainer/VBoxContainer/TitleContainer/TrainerLabel
@onready var gold_label: Label = $Panel/MarginContainer/VBoxContainer/TitleContainer/GoldLabel
@onready var learn_button: Button = $Panel/MarginContainer/VBoxContainer/ActionsContainer/LearnButton
@onready var help_label: Label = $Panel/MarginContainer/VBoxContainer/HelpLabel

var player: Player = null
var trainer_npc: NPC = null
var selected_index: int = 0
var available_recipes: Array = []  # Array of {recipe_id, base_price, recipe}

# Training system reference
var training_system: TrainingSystem = null

# Colors
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_GOLD = Color(0.9, 0.7, 0.2, 1.0)
const COLOR_AFFORDABLE = Color(0.6, 0.9, 0.6, 1.0)
const COLOR_EXPENSIVE = Color(0.9, 0.5, 0.5, 1.0)
const COLOR_PURPLE = Color(0.6, 0.4, 0.8, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	training_system = TrainingSystem.new()

	# Connect button signal
	learn_button.pressed.connect(_on_learn_pressed)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_close()
				get_viewport().set_input_as_handled()
			KEY_UP:
				_navigate(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_navigate(1)
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				_learn_selected()
				get_viewport().set_input_as_handled()
			KEY_T:
				# Switch to Trade if NPC has shop
				_switch_to_trade()
				get_viewport().set_input_as_handled()

func open(p_player: Player, p_trainer_npc: NPC) -> void:
	player = p_player
	trainer_npc = p_trainer_npc
	selected_index = 0

	# Build available recipes list
	_build_recipe_list()

	# Display trainer greeting
	var greeting = trainer_npc.dialogue.get("training", trainer_npc.dialogue.get("greeting", "I can teach you:"))
	trainer_label.text = "%s: \"%s\"" % [trainer_npc.name, greeting]

	_refresh_display()
	show()
	get_tree().paused = true

func _close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()

func _switch_to_trade() -> void:
	if trainer_npc and has_trade_available():
		hide()
		get_tree().paused = false
		switch_to_trade.emit(trainer_npc, player)

func has_trade_available() -> bool:
	return trainer_npc and (trainer_npc.npc_type == "shop" or trainer_npc.trade_inventory.size() > 0)

func _build_recipe_list() -> void:
	available_recipes.clear()

	if not trainer_npc or not player:
		return

	for recipe_data in trainer_npc.recipes_for_sale:
		var recipe_id = recipe_data.get("recipe_id", "")
		var base_price = recipe_data.get("base_price", 100)
		var recipe = RecipeManager.get_recipe(recipe_id)

		if recipe:
			# Check if player already knows this recipe
			var already_known = player.knows_recipe(recipe_id)
			available_recipes.append({
				"recipe_id": recipe_id,
				"base_price": base_price,
				"recipe": recipe,
				"known": already_known
			})

func _navigate(direction: int) -> void:
	if available_recipes.is_empty():
		return

	selected_index = clamp(selected_index + direction, 0, available_recipes.size() - 1)
	_refresh_display()

func _on_learn_pressed() -> void:
	_learn_selected()

func _learn_selected() -> void:
	if available_recipes.is_empty() or selected_index >= available_recipes.size():
		return

	var recipe_data = available_recipes[selected_index]

	# Can't buy recipes we already know
	if recipe_data.get("known", false):
		EventBus.message_logged.emit("You already know how to craft %s." % recipe_data.recipe.get_display_name())
		return

	var success = training_system.attempt_purchase_training(trainer_npc, recipe_data.recipe_id, player)

	if success:
		# Rebuild list to update known status
		_build_recipe_list()
		if selected_index >= available_recipes.size():
			selected_index = max(0, available_recipes.size() - 1)
		_refresh_display()

func _refresh_display() -> void:
	# Clear lists
	for child in recipe_list.get_children():
		child.queue_free()
	for child in details_container.get_children():
		child.queue_free()

	if not player or not trainer_npc:
		return

	# Update gold label
	gold_label.text = "Your Gold: %d" % player.gold
	gold_label.modulate = COLOR_GOLD

	# Check if no recipes available
	if available_recipes.is_empty():
		var no_recipes = Label.new()
		no_recipes.text = "No recipes available for training."
		no_recipes.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		no_recipes.add_theme_font_size_override("font_size", 13)
		recipe_list.add_child(no_recipes)
		learn_button.disabled = true
		return

	# Populate recipe list
	for i in range(available_recipes.size()):
		var data = available_recipes[i]
		var recipe = data.recipe
		var is_known = data.get("known", false)
		var price = training_system.calculate_training_price(data.base_price, recipe.difficulty, player.attributes["CHA"])

		var label = Label.new()
		label.add_theme_font_size_override("font_size", 13)

		# Add selection triangle and known indicator
		var prefix = "► " if i == selected_index else "  "
		if is_known:
			label.text = "%s%s [KNOWN]" % [prefix, recipe.get_display_name()]
		else:
			label.text = "%s%s (%dg)" % [prefix, recipe.get_display_name(), price]

		# Color based on selection, known status, and affordability
		if is_known:
			# Gray out known recipes
			label.modulate = Color(0.5, 0.5, 0.5, 1.0)
		elif i == selected_index:
			if player.gold >= price:
				label.modulate = COLOR_SELECTED
			else:
				label.modulate = COLOR_EXPENSIVE
		else:
			label.modulate = COLOR_NORMAL

		recipe_list.add_child(label)

	# Update details panel for selected recipe
	if selected_index < available_recipes.size():
		_update_details_panel(available_recipes[selected_index])

	# Update button state - disable if no recipes or selected recipe is already known
	if available_recipes.is_empty():
		learn_button.disabled = true
		learn_button.text = "Learn Recipe"
	elif selected_index < available_recipes.size() and available_recipes[selected_index].get("known", false):
		learn_button.disabled = true
		learn_button.text = "Already Known"
	else:
		learn_button.disabled = false
		learn_button.text = "Learn Recipe"

	# Update help label to show [T] Trade if shop available
	if has_trade_available():
		help_label.text = "[Enter] Learn  |  [T] Trade  |  [Esc] Close"
	else:
		help_label.text = "[Enter] Learn  |  [Esc] Close"

	# Scroll to selected item after the frame updates
	_scroll_to_selected.call_deferred()

func _scroll_to_selected() -> void:
	if not recipe_scroll or not recipe_list:
		return

	if selected_index < 0 or selected_index >= recipe_list.get_child_count():
		return

	var selected_label = recipe_list.get_child(selected_index) as Control
	if not selected_label:
		return

	# Get the position and size of the selected item relative to the list
	var item_top = selected_label.position.y
	var item_bottom = item_top + selected_label.size.y
	var visible_top = recipe_scroll.scroll_vertical
	var visible_bottom = visible_top + recipe_scroll.size.y

	# Scroll up if item is above visible area
	if item_top < visible_top:
		recipe_scroll.scroll_vertical = int(item_top)
	# Scroll down if item is below visible area
	elif item_bottom > visible_bottom:
		recipe_scroll.scroll_vertical = int(item_bottom - recipe_scroll.size.y)

func _update_details_panel(data: Dictionary) -> void:
	var recipe = data.recipe
	var is_known = data.get("known", false)
	var price = training_system.calculate_training_price(data.base_price, recipe.difficulty, player.attributes["CHA"])

	# Recipe name
	var name_label = Label.new()
	name_label.text = recipe.get_display_name()
	name_label.add_theme_font_size_override("font_size", 16)
	if is_known:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	else:
		name_label.add_theme_color_override("font_color", COLOR_PURPLE)
	details_container.add_child(name_label)

	# Show "Already Known" indicator
	if is_known:
		var known_label = Label.new()
		known_label.text = "✓ You already know this recipe"
		known_label.add_theme_font_size_override("font_size", 13)
		known_label.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4, 1))
		details_container.add_child(known_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	details_container.add_child(spacer)

	# Result item info
	var result_item_data = ItemManager.get_item_data(recipe.result_item_id)
	if not result_item_data.is_empty():
		var result_label = Label.new()
		result_label.text = "Creates: %s" % result_item_data.get("name", recipe.result_item_id)
		result_label.add_theme_font_size_override("font_size", 13)
		result_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
		details_container.add_child(result_label)

		# Item description
		var desc = result_item_data.get("description", "")
		if desc != "":
			var desc_label = Label.new()
			desc_label.text = desc
			desc_label.add_theme_font_size_override("font_size", 12)
			desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			details_container.add_child(desc_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	details_container.add_child(spacer2)

	# Difficulty
	var diff_label = Label.new()
	diff_label.text = "Difficulty: %s" % training_system.get_difficulty_display(recipe.difficulty)
	diff_label.add_theme_font_size_override("font_size", 13)
	diff_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	details_container.add_child(diff_label)

	# Price (only show if not already known)
	if not is_known:
		var price_label = Label.new()
		price_label.text = "Cost: %s" % training_system.get_price_display(data.base_price, recipe.difficulty, player.attributes["CHA"])
		price_label.add_theme_font_size_override("font_size", 13)
		if player.gold >= price:
			price_label.add_theme_color_override("font_color", COLOR_AFFORDABLE)
		else:
			price_label.add_theme_color_override("font_color", COLOR_EXPENSIVE)
		details_container.add_child(price_label)

	# Note about ingredients (only show for unknown recipes)
	if not is_known:
		var spacer3 = Control.new()
		spacer3.custom_minimum_size = Vector2(0, 16)
		details_container.add_child(spacer3)

		var note_label = Label.new()
		note_label.text = "(Ingredients will be revealed when you learn this recipe)"
		note_label.add_theme_font_size_override("font_size", 11)
		note_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		details_container.add_child(note_label)
