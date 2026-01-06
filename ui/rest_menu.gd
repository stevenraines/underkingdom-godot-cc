extends Control

## RestMenu - Rest/wait menu for resting multiple turns
##
## Allows player to rest until:
## 1. Fully rested (stamina restored)
## 2. Next time period (dawn, day, dusk, night)
## 3. Specific number of turns
## 4. Fully healed (only when on shelter tile)

signal closed()
signal rest_requested(rest_type: String, turns: int)

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Title
@onready var option1_label: Label = $Panel/MarginContainer/VBoxContainer/OptionsContainer/Option1
@onready var option2_label: Label = $Panel/MarginContainer/VBoxContainer/OptionsContainer/Option2
@onready var turns_input: LineEdit = $Panel/MarginContainer/VBoxContainer/OptionsContainer/Option3Container/TurnsInput
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var option4_label: Label = $Panel/MarginContainer/VBoxContainer/OptionsContainer/Option4

var selected_index: int = 0
var player: Player = null
var is_on_shelter: bool = false  # Whether player is on a shelter tile

# Colors
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure LineEdit can receive focus when game is paused
	# Note: @onready vars are set before _ready is called
	turns_input.process_mode = Node.PROCESS_MODE_ALWAYS
	turns_input.focus_mode = Control.FOCUS_ALL

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		# If the turns input has focus, let it handle digit keys and most input
		if turns_input.has_focus():
			match event.keycode:
				KEY_ESCAPE:
					turns_input.release_focus()
					viewport.set_input_as_handled()
				KEY_ENTER:
					_confirm_turns_input()
					viewport.set_input_as_handled()
				KEY_UP:
					turns_input.release_focus()
					_navigate(-1)
					viewport.set_input_as_handled()
				KEY_TAB:
					turns_input.release_focus()
					# Tab from option 3: forward goes to option 4 (if shelter) or wraps to 0
					# Shift+Tab goes back to option 2
					if event.shift_pressed:
						selected_index = 1
					else:
						if is_on_shelter:
							selected_index = 3  # Go to "Until fully healed"
						else:
							selected_index = 0  # Wrap to first option
					_update_selection()
					viewport.set_input_as_handled()
				_:
					# Let other keys (digits, backspace, etc.) pass through to LineEdit
					pass
			return

		var max_options = 4 if is_on_shelter else 3
		match event.keycode:
			KEY_ESCAPE:
				_close()
				viewport.set_input_as_handled()
			KEY_1:
				_select_option(0)
				viewport.set_input_as_handled()
			KEY_2:
				_select_option(1)
				viewport.set_input_as_handled()
			KEY_3:
				# Focus on turns input
				selected_index = 2
				_update_selection()
				turns_input.call_deferred("grab_focus")
				viewport.set_input_as_handled()
			KEY_4:
				# Until fully healed (only if on shelter)
				if is_on_shelter:
					_select_option(3)
				viewport.set_input_as_handled()
			KEY_UP, KEY_DOWN:
				# Consume arrow keys to prevent them from doing anything
				viewport.set_input_as_handled()
			KEY_TAB:
				# Tab wraps around, Shift+Tab goes backwards
				if event.shift_pressed:
					selected_index = (selected_index - 1) % max_options
					if selected_index < 0:
						selected_index = max_options - 1
				else:
					selected_index = (selected_index + 1) % max_options
				_update_selection()
				if selected_index == 2:
					turns_input.call_deferred("grab_focus")
				else:
					turns_input.release_focus()
				viewport.set_input_as_handled()
			KEY_ENTER:
				_select_option(selected_index)
				viewport.set_input_as_handled()

func open(p: Player) -> void:
	player = p
	selected_index = 0
	is_on_shelter = _check_player_on_shelter()
	_update_options()
	_update_selection()
	_update_status()
	show()
	get_tree().paused = true

func _close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()

func _navigate(direction: int) -> void:
	selected_index = clamp(selected_index + direction, 0, 2)
	_update_selection()
	_update_focus()

func _navigate_wrap(direction: int) -> void:
	# Navigate with wrapping (for Tab key)
	selected_index = (selected_index + direction) % 3
	if selected_index < 0:
		selected_index = 2
	_update_selection()
	_update_focus()

func _update_focus() -> void:
	# If selecting option 3, focus on input
	if selected_index == 2:
		# Grab focus immediately - the issue was likely something else
		turns_input.grab_focus()
	else:
		turns_input.release_focus()

func _update_selection() -> void:
	option1_label.modulate = COLOR_SELECTED if selected_index == 0 else COLOR_NORMAL
	option2_label.modulate = COLOR_SELECTED if selected_index == 1 else COLOR_NORMAL

	# Option 3 container highlighting
	var opt3_container = $Panel/MarginContainer/VBoxContainer/OptionsContainer/Option3Container
	for child in opt3_container.get_children():
		if child is Label:
			child.modulate = COLOR_SELECTED if selected_index == 2 else COLOR_NORMAL

	# Option 4 highlighting (only visible when on shelter)
	if option4_label:
		option4_label.modulate = COLOR_SELECTED if selected_index == 3 else COLOR_NORMAL

func _update_options() -> void:
	# Update option 2 with the next time period
	var next_period = _get_next_time_period()
	option2_label.text = "2. Until %s" % next_period.capitalize()

	# Show/hide option 4 based on shelter status
	if option4_label:
		option4_label.visible = is_on_shelter

func _update_status() -> void:
	if player and player.survival:
		var current_stamina = player.survival.stamina
		var max_stamina = player.survival.get_max_stamina()
		status_label.text = "Stamina: %d/%d" % [int(current_stamina), int(max_stamina)]
	else:
		status_label.text = ""

func _get_next_time_period() -> String:
	var turns_per_day = CalendarManager.get_turns_per_day()
	var current_turn = TurnManager.current_turn
	var turn_in_day = current_turn % turns_per_day

	# Get time periods from calendar manager (these have start/end times)
	var periods = CalendarManager.get_time_periods()

	# Find current period by turn position
	var current_period_idx = -1
	for i in range(periods.size()):
		var period = periods[i]
		if turn_in_day >= period.get("start", 0) and turn_in_day < period.get("end", 0):
			current_period_idx = i
			break

	# Find the next DIFFERENT period that is valid for rest menu
	if current_period_idx >= 0:
		var current_id = periods[current_period_idx].get("id", "")
		var next_idx = current_period_idx + 1

		# Keep advancing until we find a different period ID that shows in rest menu
		while next_idx < periods.size():
			var period = periods[next_idx]
			if period.get("id", "") != current_id and period.get("show_in_rest_menu", true):
				return period.get("id", "dawn")
			next_idx += 1

		# Wrapped around to start of next day - find first valid period
		for period in periods:
			if period.get("id", "") != current_id and period.get("show_in_rest_menu", true):
				return period.get("id", "dawn")

	return "dawn"  # Default fallback

func _get_turns_until_next_period() -> int:
	var turns_per_day = CalendarManager.get_turns_per_day()
	var current_turn = TurnManager.current_turn
	var turn_in_day = current_turn % turns_per_day

	# Get time periods from calendar manager
	var periods = CalendarManager.get_time_periods()

	# Find current period by turn position
	var current_period_idx = -1
	for i in range(periods.size()):
		var period = periods[i]
		if turn_in_day >= period.get("start", 0) and turn_in_day < period.get("end", 0):
			current_period_idx = i
			break

	if current_period_idx < 0:
		return 10  # Fallback

	var current_id = periods[current_period_idx].get("id", "")

	# Find the next DIFFERENT period that shows in rest menu
	var next_idx = current_period_idx + 1
	while next_idx < periods.size():
		var period = periods[next_idx]
		if period.get("id", "") != current_id and period.get("show_in_rest_menu", true):
			var next_start = period.get("start", 0)
			return next_start - turn_in_day
		next_idx += 1

	# Wrapped around to start of next day - find first valid period
	for period in periods:
		if period.get("id", "") != current_id and period.get("show_in_rest_menu", true):
			var next_start = period.get("start", 0)
			return (turns_per_day - turn_in_day) + next_start

	return 10  # Fallback

func _select_option(index: int) -> void:
	match index:
		0:
			# Until fully rested (stamina restored)
			var turns_needed = _calculate_turns_to_full_stamina()
			rest_requested.emit("stamina", turns_needed)
			_close()
		1:
			# Until next time period
			var turns_needed = _get_turns_until_next_period()
			rest_requested.emit("time", turns_needed)
			_close()
		2:
			# Custom turns - validate input
			_confirm_turns_input()
		3:
			# Until fully healed (only available on shelter)
			if is_on_shelter:
				var turns_needed = _calculate_turns_to_full_health()
				rest_requested.emit("health", turns_needed)
				_close()

func _confirm_turns_input() -> void:
	var text = turns_input.text.strip_edges()
	if text.is_valid_int():
		var turns = int(text)
		if turns > 0 and turns <= 10000:
			rest_requested.emit("custom", turns)
			_close()

func _calculate_turns_to_full_stamina() -> int:
	if not player or not player.survival:
		return 10

	var current = player.survival.stamina
	var max_sta = player.survival.get_max_stamina()
	var missing = max_sta - current

	if missing <= 0:
		return 1  # Already full, just wait 1 turn

	# Base regen is 1.0 per turn, waiting grants 2x (so 2.0 per turn)
	var regen_per_turn = 2.0
	var turns_needed = int(ceil(missing / regen_per_turn))
	return max(1, turns_needed)

func _calculate_turns_to_full_health() -> int:
	if not player:
		return 100

	var missing_hp = player.max_health - player.current_health
	if missing_hp <= 0:
		return 1  # Already full

	# Get shelter HP restore rate from the shelter player is on
	var shelter_data = _get_player_shelter_data()
	if shelter_data:
		var hp_per_interval = shelter_data.get("hp_restore_amount", 1)
		var turns_per_restore = shelter_data.get("hp_restore_turns", 10)
		# Calculate turns needed: (missing_hp / hp_per_interval) * turns_per_restore
		var intervals_needed = int(ceil(float(missing_hp) / float(hp_per_interval)))
		return intervals_needed * turns_per_restore

	# Fallback if no shelter data
	return missing_hp * 10

## Check if player is standing on a shelter tile
func _check_player_on_shelter() -> bool:
	if not player or not MapManager.current_map:
		return false

	var map_id = MapManager.current_map.map_id
	var structures = StructureManager.get_structures_on_map(map_id)

	for structure in structures:
		if structure.has_component("shelter"):
			var shelter = structure.get_component("shelter")
			if shelter.is_inside_shelter(structure.position, player.position):
				return true

	return false

## Get the shelter data for the shelter the player is standing on
func _get_player_shelter_data() -> Dictionary:
	if not player or not MapManager.current_map:
		return {}

	var map_id = MapManager.current_map.map_id
	var structures = StructureManager.get_structures_on_map(map_id)

	for structure in structures:
		if structure.has_component("shelter"):
			var shelter = structure.get_component("shelter")
			if shelter.is_inside_shelter(structure.position, player.position):
				return {
					"hp_restore_turns": shelter.hp_restore_turns,
					"hp_restore_amount": shelter.hp_restore_amount
				}

	return {}
