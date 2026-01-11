extends Control

## DeathScreen - UI shown when player dies
##
## Displays death message, stats, and options to load save or return to main menu.

signal load_save_requested(slot: int)
signal return_to_menu_requested()

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var stats_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/ContentContainer/StatsPanel/StatsLabel
@onready var save_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/SavesPanel/SaveList
@onready var button_panel: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ButtonPanel

var selected_save_index: int = 0
var available_saves: Array[Dictionary] = []
var save_buttons: Array[Button] = []

# Colors
const COLOR_SELECTED = Color(1.0, 1.0, 0.6, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.6, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				_navigate(-1)
				var _vp = get_viewport()
				if _vp:
					_vp.set_input_as_handled()
			KEY_DOWN:
				_navigate(1)
				var _vp = get_viewport()
				if _vp:
					_vp.set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				_load_selected_save()
				var _vp = get_viewport()
				if _vp:
					_vp.set_input_as_handled()
			KEY_ESCAPE, KEY_M:
				_return_to_menu()
				var _vp = get_viewport()
				if _vp:
					_vp.set_input_as_handled()
			KEY_1, KEY_2, KEY_3:
				var slot = event.keycode - KEY_1
				if slot >= 0 and slot < available_saves.size():
					selected_save_index = slot
					_load_selected_save()
				var _vp = get_viewport()
				if _vp:
					_vp.set_input_as_handled()

func open(player_stats: Dictionary) -> void:
	# Ensure the control is visible and defer populating UI until the node
	# has been added to the scene tree so child controls are available.
	show()
	call_deferred("_deferred_open", player_stats)

func _display_death_stats(stats: Dictionary) -> void:
	# Attempt to resolve the stats_label if onready didn't initialize it
	if not stats_label:
		stats_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/StatsPanel/StatsLabel")
		if not stats_label:
			push_warning("DeathScreen: stats_label not found, cannot display death stats yet")
			return

	var text = "[center][color=#ff8888][b]*** YOU HAVE DIED ***[/b][/color][/center]\n\n"

	# Show cause of death if available
	var death_cause = stats.get("death_cause", "")
	var death_method = stats.get("death_method", "")
	var death_location = stats.get("death_location", "")

	if death_cause != "":
		text += "[center][color=#ff6666]"

		# Format the death message based on what information we have
		if death_method != "" and death_method != "survival":
			text += "Killed by [b]%s[/b]" % death_cause
			text += " with %s" % death_method
		else:
			text += "Killed by [b]%s[/b]" % death_cause

		if death_location != "":
			text += "\nin %s" % death_location

		text += "[/color][/center]\n\n"
	else:
		text += "[color=#cccccc]Your journey has ended...[/color]\n\n"

	# Display key stats
	text += "[color=#9acc9a][b]Final Statistics:[/b][/color]\n"
	text += "  [color=#ffaa66]⚬ Turns Survived:[/color] %d\n" % stats.get("turns", 0)
	text += "  [color=#ffdd88]⚬ Days Survived:[/color] %d\n" % int(stats.get("turns", 0) / 1000.0)
	text += "  [color=#88ff88]⚬ Experience:[/color] %d XP\n" % stats.get("experience", 0)

	if stats.has("kills"):
		text += "  [color=#ff8888]⚬ Enemies Defeated:[/color] %d\n" % stats.get("kills", 0)

	if stats.has("gold"):
		text += "  [color=#ddaa66]⚬ Gold Collected:[/color] %d\n" % stats.get("gold", 0)

	if stats.has("structures_built"):
		text += "  [color=#aaddff]⚬ Structures Built:[/color] %d\n" % stats.get("structures_built", 0)

	if stats.has("recipes_discovered"):
		text += "  [color=#ccaaff]⚬ Recipes Discovered:[/color] %d\n" % stats.get("recipes_discovered", 0)

	stats_label.text = text

func _refresh_save_list() -> void:
	if not save_list:
		return

	# Clear existing buttons
	for button in save_buttons:
		button.queue_free()
	save_buttons.clear()
	available_saves.clear()

	# Get available saves
	for slot in range(1, 4):
		var save_info = SaveManager.get_save_slot_info(slot)
		# Store as dictionary for easier access
		available_saves.append({
			"exists": save_info.exists,
			"slot": slot,
			"world_name": save_info.world_name,
			"playtime_turns": save_info.playtime_turns,
			"save_name": save_info.save_name
		})

	# Create buttons for each save slot
	for i in range(available_saves.size()):
		var save_data = available_saves[i]
		var button = Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 13)

		if save_data.get("exists", false):
			var world_name = save_data.get("world_name", "Unknown World")
			var turn = save_data.get("playtime_turns", 0)
			var day = int(turn / 1000.0)
			var time_portion = turn % 1000
			var time_of_day = "Night"
			if time_portion >= 0 and time_portion < 150:
				time_of_day = "Dawn"
			elif time_portion >= 150 and time_portion < 700:
				time_of_day = "Day"
			elif time_portion >= 700 and time_portion < 850:
				time_of_day = "Dusk"

			button.text = "[%d] %s - Day %d (%s)" % [i + 1, world_name, day, time_of_day]
			button.modulate = COLOR_NORMAL
		else:
			button.text = "[%d] <Empty Slot>" % (i + 1)
			button.modulate = Color(0.4, 0.4, 0.4, 1.0)
			button.disabled = true

		button.pressed.connect(func(): _on_save_button_pressed(i))
		save_list.add_child(button)
		save_buttons.append(button)

	_update_selection()

func _navigate(direction: int) -> void:
	# Only navigate through non-empty saves
	if available_saves.size() == 0:
		return

	var start_index = selected_save_index
	var attempts = 0
	while attempts < available_saves.size():
		selected_save_index = (selected_save_index + direction) % available_saves.size()
		if selected_save_index < 0:
			selected_save_index = available_saves.size() - 1

		if available_saves[selected_save_index].get("exists", false):
			break

		attempts += 1

	# If no valid saves found, revert to start_index
	if available_saves.size() == 0 or not available_saves[selected_save_index].get("exists", false):
		selected_save_index = start_index

	_update_selection()

func _update_selection() -> void:
	for i in range(save_buttons.size()):
		# Ensure we have corresponding available_saves entry before accessing
		var has_save_info = i < available_saves.size()
		var exists = false
		if has_save_info:
			exists = available_saves[i].get("exists", false)

		if i == selected_save_index and exists:
			save_buttons[i].text = "► " + save_buttons[i].text.trim_prefix("► ")
			save_buttons[i].modulate = COLOR_SELECTED
		else:
			save_buttons[i].text = save_buttons[i].text.trim_prefix("► ")
			if exists:
				save_buttons[i].modulate = COLOR_NORMAL

func _on_save_button_pressed(index: int) -> void:
	if index >= 0 and index < available_saves.size() and available_saves[index].get("exists", false):
		selected_save_index = index
		_load_selected_save()

func _load_selected_save() -> void:
	if selected_save_index >= 0 and selected_save_index < available_saves.size():
		if available_saves[selected_save_index].get("exists", false):
			var slot = available_saves[selected_save_index].get("slot", 1)
			load_save_requested.emit(slot)
			hide()
			var _tree = get_tree()
			if _tree:
				_tree.paused = false

func _return_to_menu() -> void:
	return_to_menu_requested.emit()
	hide()
	var _tree = get_tree()
	if _tree:
		_tree.paused = false

## Deferred open handler to populate UI after entering scene tree
func _deferred_open(player_stats: Dictionary) -> void:
	# Try to resolve common UI nodes if they weren't ready earlier
	if not stats_label:
		stats_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/StatsPanel/StatsLabel")
	if not save_list:
		save_list = get_node_or_null("Panel/MarginContainer/VBoxContainer/SavesPanel/SaveList")

	_display_death_stats(player_stats)
	_refresh_save_list()

	# Pause the game once the UI is populated (guard tree may be null)
	var _tree = get_tree()
	if _tree:
		_tree.paused = true
