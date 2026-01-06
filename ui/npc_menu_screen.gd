extends Control

## NpcMenuScreen - Menu for choosing NPC interaction type
##
## Shows when an NPC offers multiple services (Trade, Train, etc.)
## Player selects which service to use.

signal closed()
signal trade_selected(npc, player)
signal train_selected(npc, player)

@onready var npc_name_label: Label = $Panel/MarginContainer/VBoxContainer/NpcNameLabel
@onready var greeting_label: Label = $Panel/MarginContainer/VBoxContainer/GreetingLabel
@onready var options_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/OptionsContainer

var player: Player = null
var current_npc: NPC = null
var selected_index: int = 0
var options: Array = []  # Array of {id, label}

# Colors
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

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
				_select_option()
				get_viewport().set_input_as_handled()

func open(p_player: Player, p_npc: NPC) -> void:
	player = p_player
	current_npc = p_npc
	selected_index = 0

	# Set NPC name
	npc_name_label.text = current_npc.name if current_npc.name else "NPC"

	# Set greeting
	var greeting = current_npc.dialogue.get("greeting", "How can I help you?")
	greeting_label.text = "\"%s\"" % greeting

	# Build options list
	_build_options()

	_refresh_display()
	show()
	get_tree().paused = true

func _close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()

func _build_options() -> void:
	options.clear()

	if not current_npc:
		return

	# Check for shop
	var has_shop = current_npc.npc_type == "shop" or current_npc.trade_inventory.size() > 0
	if has_shop:
		options.append({"id": "trade", "label": "Trade"})

	# Check for training
	var has_training = current_npc.recipes_for_sale.size() > 0
	if has_training:
		options.append({"id": "train", "label": "Learn"})

func _navigate(direction: int) -> void:
	if options.is_empty():
		return

	selected_index = clamp(selected_index + direction, 0, options.size() - 1)
	_refresh_display()

func _select_option() -> void:
	if options.is_empty() or selected_index >= options.size():
		return

	var option = options[selected_index]

	# Close this menu first
	hide()
	get_tree().paused = false

	# Emit appropriate signal
	match option.id:
		"trade":
			trade_selected.emit(current_npc, player)
		"train":
			train_selected.emit(current_npc, player)

func _refresh_display() -> void:
	# Clear options
	for child in options_container.get_children():
		child.queue_free()

	if options.is_empty():
		var no_options = Label.new()
		no_options.text = "No services available."
		no_options.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		no_options.add_theme_font_size_override("font_size", 14)
		no_options.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		options_container.add_child(no_options)
		return

	# Create option labels
	for i in range(options.size()):
		var option = options[i]
		var label = Label.new()

		# Add selection indicator
		var prefix = "► " if i == selected_index else "  "
		label.text = prefix + option.label

		label.add_theme_font_size_override("font_size", 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Color based on selection
		if i == selected_index:
			label.add_theme_color_override("font_color", COLOR_SELECTED)
		else:
			label.add_theme_color_override("font_color", COLOR_NORMAL)

		options_container.add_child(label)
