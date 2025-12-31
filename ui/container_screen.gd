extends Control

## ContainerScreen - UI for transferring items between player and container
##
## Shows player inventory on left, container inventory on right.

const Structure = preload("res://entities/structure.gd")

signal closed()

@onready var player_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/PlayerPanel/ScrollContainer/PlayerList
@onready var container_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/ContainerPanel/ScrollContainer/ContainerList
@onready var player_weight_label: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/PlayerPanel/PlayerTitle
@onready var container_weight_label: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/ContainerPanel/ContainerTitle
@onready var help_label: Label = $Panel/MarginContainer/VBoxContainer/HelpLabel

var player: Player = null
var container: Structure = null
var selected_index: int = 0
var is_player_focused: bool = true

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
			KEY_ESCAPE, KEY_E:
				_close()
				get_viewport().set_input_as_handled()
			KEY_UP:
				_navigate(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_navigate(1)
				get_viewport().set_input_as_handled()
			KEY_TAB:
				_toggle_focus()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				_transfer_selected()
				get_viewport().set_input_as_handled()

func open(p_player: Player, p_container: Structure) -> void:
	player = p_player
	container = p_container
	is_player_focused = true
	selected_index = 0
	_refresh_display()
	show()
	get_tree().paused = true
	EventBus.container_opened.emit(container)

func _close() -> void:
	hide()
	get_tree().paused = false
	EventBus.container_closed.emit(container)
	closed.emit()

func _navigate(direction: int) -> void:
	var max_index = _get_current_list_size() - 1
	if max_index < 0:
		return

	selected_index = clamp(selected_index + direction, 0, max_index)
	_refresh_display()

func _toggle_focus() -> void:
	is_player_focused = not is_player_focused
	selected_index = 0
	_refresh_display()

func _transfer_selected() -> void:
	if is_player_focused:
		_transfer_to_container()
	else:
		_transfer_to_player()

func _transfer_to_container() -> void:
	if not player or not container:
		return

	var items = player.inventory.items
	if selected_index >= items.size():
		return

	var item = items[selected_index]
	var container_comp = container.get_component("container")

	if not container_comp:
		return

	# Check if container has space
	if container_comp.is_full():
		print("Container is full!")
		return

	# Remove from player
	if player.inventory.remove_item(item):
		# Add to container
		if container_comp.add_item(item):
			print("Moved %s to container" % item.name)
			EventBus.inventory_changed.emit()
			_refresh_display()
		else:
			# Failed to add, put it back
			player.inventory.add_item(item)
			print("Failed to add item to container")

func _transfer_to_player() -> void:
	if not player or not container:
		return

	var container_comp = container.get_component("container")
	if not container_comp:
		return

	var items = container_comp.get_items()
	if selected_index >= items.size():
		return

	var item = items[selected_index]

	# Remove from container
	if container_comp.remove_item(item):
		# Add to player
		if player.inventory.add_item(item):
			print("Moved %s to player inventory" % item.name)
			EventBus.inventory_changed.emit()
			_refresh_display()
		else:
			# Failed to add, put it back
			container_comp.add_item(item)
			print("Failed to add item to player inventory (too heavy?)")

func _get_current_list_size() -> int:
	if is_player_focused:
		return player.inventory.items.size() if player else 0
	else:
		var container_comp = container.get_component("container") if container else null
		return container_comp.get_items().size() if container_comp else 0

func _refresh_display() -> void:
	# Clear lists
	for child in player_list.get_children():
		child.queue_free()
	for child in container_list.get_children():
		child.queue_free()

	if not player or not container:
		return

	# Update weight labels
	var player_weight = player.inventory.get_total_weight()
	var player_max = player.inventory.max_weight
	player_weight_label.text = "Player Inventory (%.1f/%.1f kg)" % [player_weight, player_max]

	var container_comp = container.get_component("container")
	if container_comp:
		var container_weight = container_comp.get_total_weight()
		var container_max = container_comp.max_weight
		container_weight_label.text = "%s (%.1f/%.1f kg)" % [container.name, container_weight, container_max]

	# Populate player inventory
	for i in range(player.inventory.items.size()):
		var item = player.inventory.items[i]
		var label = Label.new()
		label.text = "%s (%.1f kg)" % [item.name, item.get_total_weight()]
		if is_player_focused and i == selected_index:
			label.modulate = COLOR_SELECTED
		else:
			label.modulate = COLOR_NORMAL
		player_list.add_child(label)

	# Populate container inventory
	if container_comp:
		var items = container_comp.get_items()
		for i in range(items.size()):
			var item = items[i]
			var label = Label.new()
			label.text = "%s (%.1f kg)" % [item.name, item.get_total_weight()]
			if not is_player_focused and i == selected_index:
				label.modulate = COLOR_SELECTED
			else:
				label.modulate = COLOR_NORMAL
			container_list.add_child(label)
