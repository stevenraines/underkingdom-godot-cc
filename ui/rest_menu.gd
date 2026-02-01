extends Control

## RestMenu - Rest/wait menu for resting multiple turns
##
## Allows player to rest until:
## - Fully rested (stamina restored)
## - Next time period (dawn, day, dusk, night)
## - Fully healed (only when on shelter tile)
## - Mana restored (only if player has mana pool)
## - Specific number of turns (always last option)

signal closed()
signal rest_requested(rest_type: String, turns: int)

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/Title
@onready var option_rested: Label = $Panel/MarginContainer/VBoxContainer/OptionsContainer/OptionRested
@onready var option_time: Label = $Panel/MarginContainer/VBoxContainer/OptionsContainer/OptionTime
@onready var option_healed: Label = $Panel/MarginContainer/VBoxContainer/OptionsContainer/OptionHealed
@onready var option_mana: Label = $Panel/MarginContainer/VBoxContainer/OptionsContainer/OptionMana
@onready var option_custom_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/OptionsContainer/OptionCustomContainer
@onready var option_custom_label: Label = $Panel/MarginContainer/VBoxContainer/OptionsContainer/OptionCustomContainer/OptionCustomLabel
@onready var turns_input: NumberInput = $Panel/MarginContainer/VBoxContainer/OptionsContainer/OptionCustomContainer/TurnsInput
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var footer_label: Label = $Panel/MarginContainer/VBoxContainer/Footer

var selected_index: int = 0
var player: Player = null
var is_on_shelter: bool = false  # Whether player is on a shelter tile
var has_mana: bool = false  # Whether player has a mana pool (magic user)

# Option types in display order (custom is always last)
enum OptionType { RESTED, TIME, HEALED, MANA, CUSTOM }

# Colors from UITheme autoload

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Connect NumberInput signals
	turns_input.value_submitted.connect(_on_turns_submitted)
	turns_input.cancelled.connect(_on_turns_cancelled)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var viewport = get_viewport()
		if not viewport:
			return

		var max_options = _get_max_options()

		# If the turns input is active, let it handle digit keys and most input
		if turns_input.is_active:
			# NumberInput handles Enter, Escape, digits, backspace
			if turns_input.handle_input(event):
				viewport.set_input_as_handled()
				return
			# For navigation keys, deactivate and fall through to normal handling
			if event.keycode in [KEY_UP, KEY_DOWN, KEY_TAB]:
				turns_input.deactivate()
			else:
				# Other keys not handled when input is active
				return

		match event.keycode:
			KEY_ESCAPE:
				_close()
				viewport.set_input_as_handled()
			KEY_UP:
				_navigate(-1, max_options)
				viewport.set_input_as_handled()
			KEY_DOWN:
				_navigate(1, max_options)
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
				_update_focus()
				viewport.set_input_as_handled()
			KEY_ENTER:
				_select_option(selected_index)
				viewport.set_input_as_handled()

		# Always consume keyboard input while rest menu is open
		viewport.set_input_as_handled()

func open(p: Player) -> void:
	player = p
	selected_index = 0
	is_on_shelter = _check_player_on_shelter()
	has_mana = _check_player_has_mana()
	_update_options()
	_update_selection()
	_update_status()
	_update_focus()  # Ensure NumberInput state matches selected_index
	show()
	get_tree().paused = true

func _close() -> void:
	turns_input.deactivate()  # Ensure clean state for next open
	hide()
	get_tree().paused = false
	closed.emit()

func _navigate(direction: int, max_options: int = 3) -> void:
	selected_index = clamp(selected_index + direction, 0, max_options - 1)
	_update_selection()
	_update_focus()

func _update_focus() -> void:
	# Custom turns is always the last option
	var custom_index = _get_max_options() - 1
	if selected_index == custom_index:
		turns_input.activate()
	else:
		turns_input.deactivate()

## Get the list of visible option types in order
func _get_visible_options() -> Array:
	var options = [OptionType.RESTED, OptionType.TIME]
	if is_on_shelter:
		options.append(OptionType.HEALED)
	if has_mana:
		options.append(OptionType.MANA)
	options.append(OptionType.CUSTOM)  # Always last
	return options

## Get the option type at a given index
func _get_option_at_index(index: int) -> int:
	var options = _get_visible_options()
	if index >= 0 and index < options.size():
		return options[index]
	return -1

func _update_selection() -> void:
	var options = _get_visible_options()

	# Update each option's highlight based on its position in visible options
	for i in range(options.size()):
		var is_selected = (i == selected_index)
		var color = UITheme.COLOR_SELECTED_GOLD if is_selected else UITheme.COLOR_NORMAL

		match options[i]:
			OptionType.RESTED:
				option_rested.modulate = color
			OptionType.TIME:
				option_time.modulate = color
			OptionType.HEALED:
				option_healed.modulate = color
			OptionType.MANA:
				option_mana.modulate = color
			OptionType.CUSTOM:
				option_custom_label.modulate = color
				turns_input.modulate = color
				# Also highlight the suffix label
				var suffix = option_custom_container.get_node("OptionCustomSuffix")
				if suffix:
					suffix.modulate = color

func _update_options() -> void:
	# Update option visibility
	option_healed.visible = is_on_shelter
	option_mana.visible = has_mana

	# Update time period text
	var next_period = _get_next_time_period()
	option_time.text = "Until %s" % next_period.capitalize()

func _update_status() -> void:
	if player and player.survival:
		var current_stamina = player.survival.stamina
		var max_stamina = player.survival.get_max_stamina()
		var status_text = "Stamina: %d/%d" % [int(current_stamina), int(max_stamina)]

		# Add mana info if player has mana
		if has_mana:
			var current_mana = player.survival.mana
			var max_mana = player.survival.get_max_mana()
			status_text += "  Mana: %d/%d" % [int(current_mana), int(max_mana)]

		status_label.text = status_text
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
	var option_type = _get_option_at_index(index)

	match option_type:
		OptionType.RESTED:
			var turns_needed = _calculate_turns_to_full_stamina()
			rest_requested.emit("stamina", turns_needed)
			_close()
		OptionType.TIME:
			var turns_needed = _get_turns_until_next_period()
			rest_requested.emit("time", turns_needed)
			_close()
		OptionType.HEALED:
			var turns_needed = _calculate_turns_to_full_health()
			rest_requested.emit("health", turns_needed)
			_close()
		OptionType.MANA:
			var turns_needed = _calculate_turns_to_full_mana()
			rest_requested.emit("mana", turns_needed)
			_close()
		OptionType.CUSTOM:
			_confirm_turns_input()

func _confirm_turns_input() -> void:
	var turns = turns_input.get_value()
	if turns > 0:
		rest_requested.emit("custom", turns)
		_close()

## Called when NumberInput submits a value (Enter pressed)
func _on_turns_submitted(value: int) -> void:
	if value > 0:
		rest_requested.emit("custom", value)
		_close()

## Called when NumberInput is cancelled (Escape pressed while input active)
func _on_turns_cancelled() -> void:
	turns_input.deactivate()
	_navigate(-1, _get_max_options())
	_update_selection()

## Helper to get current max options count
func _get_max_options() -> int:
	return _get_visible_options().size()

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

## Check if player has a mana pool (is a spellcaster)
func _check_player_has_mana() -> bool:
	if not player or not player.survival:
		return false
	# Player has mana if their max mana > 0
	return player.survival.get_max_mana() > 0

## Calculate turns needed to restore mana to full
func _calculate_turns_to_full_mana() -> int:
	if not player or not player.survival:
		return 10

	var current_mana = player.survival.mana
	var max_mana = player.survival.get_max_mana()
	var missing = max_mana - current_mana

	if missing <= 0:
		return 1  # Already full, just wait 1 turn

	# Check if player is in shelter for faster regen
	var regen_per_turn = player.survival.MANA_REGEN_PER_TURN
	if is_on_shelter:
		regen_per_turn *= player.survival.MANA_REGEN_SHELTER_MULTIPLIER

	var turns_needed = int(ceil(missing / regen_per_turn))
	return max(1, turns_needed)
