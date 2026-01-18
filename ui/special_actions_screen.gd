extends Control

## SpecialActionsScreen - UI for using active class feats and racial traits
##
## Shows all active special abilities that can be used once per day,
## including class feats and racial abilities.

signal closed()
signal action_used(action_type: String, action_id: String)

@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var action_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/ActionListPanel/ScrollContainer/ActionList
@onready var action_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/ActionListPanel/ScrollContainer
@onready var action_list_title: Label = $Panel/MarginContainer/VBoxContainer/ContentContainer/ActionListPanel/ActionListTitle

# Detail panel elements
@onready var action_name_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/NameColumn/ActionName
@onready var action_desc_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/NameColumn/ActionDesc
@onready var stat_line_1: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine1
@onready var stat_line_2: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine2
@onready var stat_line_3: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/DetailColumns/StatsColumn/StatLine3
@onready var footer_label: Label = $Panel/MarginContainer/VBoxContainer/DetailPanel/DetailVBox/FooterRow/FooterLabel

var player: Player = null
var actions: Array = []  # Array of dictionaries: {type: "feat"/"trait", id, name, description, uses_remaining, max_uses, source}
var selected_index: int = 0

# Colors
const COLOR_SELECTED = Color(0.2, 0.4, 0.3, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_EMPTY = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.6, 1.0)
const COLOR_FEAT = Color(0.9, 0.7, 0.3, 1.0)  # Gold for class feats
const COLOR_TRAIT = Color(0.3, 0.8, 0.9, 1.0)  # Cyan for racial traits
const COLOR_USABLE = Color(0.5, 1.0, 0.5, 1.0)
const COLOR_EXHAUSTED = Color(1.0, 0.5, 0.5, 1.0)


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Escape always closes
		if event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
			return

		# Same key combo that opens it (A) - toggle close
		if event.keycode == KEY_A:
			_close()
			get_viewport().set_input_as_handled()
			return

		match event.keycode:
			KEY_UP:
				_navigate(-1)
			KEY_DOWN:
				_navigate(1)
			KEY_ENTER, KEY_SPACE:
				_use_selected_action()

		# Always consume keyboard input while screen is open
		get_viewport().set_input_as_handled()


func open(p: Player) -> void:
	player = p
	selected_index = 0

	if not player:
		hide()
		return

	_gather_actions()
	refresh()
	show()


func _close() -> void:
	hide()
	closed.emit()


func _gather_actions() -> void:
	actions.clear()

	if not player:
		return

	# Gather active class feats
	var class_feats = ClassManager.get_feats(player.class_id)
	for feat in class_feats:
		if feat.get("type", "passive") == "active":
			var feat_id = feat.get("id", "")
			var uses_remaining = player.get_class_feat_uses(feat_id)
			var max_uses = feat.get("uses_per_day", 1)
			actions.append({
				"type": "feat",
				"id": feat_id,
				"name": feat.get("name", "Unknown"),
				"description": feat.get("description", ""),
				"uses_remaining": uses_remaining,
				"max_uses": max_uses,
				"source": ClassManager.get_class_name(player.class_id),
				"effect": feat.get("effect", {})
			})

	# Gather active racial traits
	var racial_traits = RaceManager.get_traits(player.race_id)
	for trait_data in racial_traits:
		if trait_data.get("type", "passive") == "active":
			var trait_id = trait_data.get("id", "")
			var trait_state = player.racial_traits.get(trait_id, {})
			var uses_remaining = trait_state.get("uses_remaining", 0)
			var max_uses = trait_data.get("uses_per_day", 1)
			actions.append({
				"type": "trait",
				"id": trait_id,
				"name": trait_data.get("name", "Unknown"),
				"description": trait_data.get("description", ""),
				"uses_remaining": uses_remaining,
				"max_uses": max_uses,
				"source": RaceManager.get_race_name(player.race_id),
				"effect": trait_data.get("effect", {})
			})


func refresh() -> void:
	if not player:
		return

	_gather_actions()
	_update_action_list()
	_update_selection()


func _update_action_list() -> void:
	if not action_list:
		return

	# Clear existing
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.free()

	# Update title with count
	if action_list_title:
		var usable_count = 0
		for action in actions:
			if action.uses_remaining > 0 or action.uses_remaining == -1:
				usable_count += 1
		action_list_title.text = "══ SPECIAL ACTIONS (%d/%d available) ══" % [usable_count, actions.size()]

	# Reset scroll position
	if action_scroll:
		action_scroll.scroll_vertical = 0

	if actions.is_empty():
		var label = Label.new()
		label.text = "  (No special actions available)"
		label.add_theme_color_override("font_color", COLOR_EMPTY)
		label.add_theme_font_size_override("font_size", 13)
		action_list.add_child(label)
	else:
		for action in actions:
			var container = _create_action_row(action)
			action_list.add_child(container)


func _create_action_row(action: Dictionary) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 6)
	container.set_meta("action", action)

	# Type indicator (◆ for feats, ● for traits)
	var icon = Label.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(20, 0)
	icon.add_theme_font_size_override("font_size", 14)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if action.type == "feat":
		icon.text = "◆"
		icon.add_theme_color_override("font_color", COLOR_FEAT)
	else:
		icon.text = "●"
		icon.add_theme_color_override("font_color", COLOR_TRAIT)
	container.add_child(icon)

	# Name
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.text = action.name
	name_label.add_theme_color_override("font_color", COLOR_NORMAL)
	container.add_child(name_label)

	# Source (class/race)
	var source_label = Label.new()
	source_label.name = "Source"
	source_label.custom_minimum_size = Vector2(70, 0)
	source_label.add_theme_font_size_override("font_size", 12)
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_label.text = action.source
	if action.type == "feat":
		source_label.add_theme_color_override("font_color", COLOR_FEAT)
	else:
		source_label.add_theme_color_override("font_color", COLOR_TRAIT)
	container.add_child(source_label)

	# Uses remaining
	var uses_label = Label.new()
	uses_label.name = "Uses"
	uses_label.custom_minimum_size = Vector2(60, 0)
	uses_label.add_theme_font_size_override("font_size", 12)
	uses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if action.uses_remaining == -1:
		uses_label.text = "∞"
		uses_label.add_theme_color_override("font_color", COLOR_USABLE)
	else:
		uses_label.text = "%d/%d" % [action.uses_remaining, action.max_uses]
		if action.uses_remaining > 0:
			uses_label.add_theme_color_override("font_color", COLOR_USABLE)
		else:
			uses_label.add_theme_color_override("font_color", COLOR_EXHAUSTED)
	container.add_child(uses_label)

	return container


func _update_selection() -> void:
	# Reset all highlights
	for i in range(action_list.get_child_count()):
		var child = action_list.get_child(i)
		_set_row_highlight(child, false)

	# Highlight selected if we have actions
	if actions.size() > 0 and selected_index >= 0 and selected_index < action_list.get_child_count():
		var selected_row = action_list.get_child(selected_index)
		if selected_row is HBoxContainer:
			_set_row_highlight(selected_row, true)
			_scroll_to_action(selected_row)

	_update_detail_panel()


func _set_row_highlight(row: Control, highlighted: bool) -> void:
	if row is HBoxContainer:
		var name_node = row.get_node_or_null("Name")
		if name_node and name_node is Label:
			if highlighted:
				name_node.text = "► " + name_node.text.trim_prefix("► ")
				name_node.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
			else:
				name_node.text = name_node.text.trim_prefix("► ")
				name_node.add_theme_color_override("font_color", COLOR_NORMAL)


func _scroll_to_action(action_row: Control) -> void:
	if not action_scroll or not action_row or not is_instance_valid(action_row):
		return

	_scroll_to_action_deferred.call_deferred(action_row)


func _scroll_to_action_deferred(action_row: Control) -> void:
	if not action_scroll or not action_row or not is_instance_valid(action_row):
		return

	var item_top = action_row.position.y
	var item_bottom = item_top + action_row.size.y

	var scroll_top = action_scroll.scroll_vertical
	var scroll_bottom = scroll_top + action_scroll.size.y

	if item_top < scroll_top:
		action_scroll.scroll_vertical = int(item_top)
	elif item_bottom > scroll_bottom:
		action_scroll.scroll_vertical = int(item_bottom - action_scroll.size.y)


func _update_detail_panel() -> void:
	if actions.is_empty() or selected_index < 0 or selected_index >= actions.size():
		_clear_detail_panel()
		return

	var action = actions[selected_index]
	_populate_action_details(action)


func _clear_detail_panel() -> void:
	if action_name_label:
		action_name_label.text = "No action selected"
		action_name_label.add_theme_color_override("font_color", COLOR_EMPTY)
	if action_desc_label:
		action_desc_label.text = "Select an action to view details"
	if stat_line_1:
		stat_line_1.text = ""
	if stat_line_2:
		stat_line_2.text = ""
	if stat_line_3:
		stat_line_3.text = ""
	if footer_label:
		footer_label.text = "[Enter/Space] Use  [Esc/A] Close"


func _populate_action_details(action: Dictionary) -> void:
	# Name and description
	if action_name_label:
		action_name_label.text = action.name
		if action.type == "feat":
			action_name_label.add_theme_color_override("font_color", COLOR_FEAT)
		else:
			action_name_label.add_theme_color_override("font_color", COLOR_TRAIT)

	if action_desc_label:
		action_desc_label.text = action.description

	# Stats column
	if stat_line_1:
		var type_name = "Class Feat" if action.type == "feat" else "Racial Trait"
		stat_line_1.text = "Type: %s" % type_name
		if action.type == "feat":
			stat_line_1.add_theme_color_override("font_color", COLOR_FEAT)
		else:
			stat_line_1.add_theme_color_override("font_color", COLOR_TRAIT)

	if stat_line_2:
		stat_line_2.text = "Source: %s" % action.source
		stat_line_2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	if stat_line_3:
		if action.uses_remaining == -1:
			stat_line_3.text = "Uses: Unlimited"
			stat_line_3.add_theme_color_override("font_color", COLOR_USABLE)
		elif action.uses_remaining > 0:
			stat_line_3.text = "Uses: %d/%d per day" % [action.uses_remaining, action.max_uses]
			stat_line_3.add_theme_color_override("font_color", COLOR_USABLE)
		else:
			stat_line_3.text = "Exhausted (recharges at dawn)"
			stat_line_3.add_theme_color_override("font_color", COLOR_EXHAUSTED)

	# Footer
	if footer_label:
		if action.uses_remaining > 0 or action.uses_remaining == -1:
			footer_label.text = "[Enter/Space] Use  [Esc/A] Close"
		else:
			footer_label.text = "Cannot use (exhausted)  [Esc/A] Close"


func _navigate(direction: int) -> void:
	if actions.is_empty():
		return

	selected_index = clampi(selected_index + direction, 0, actions.size() - 1)
	_update_selection()


func _use_selected_action() -> void:
	if actions.is_empty() or selected_index < 0 or selected_index >= actions.size():
		return

	var action = actions[selected_index]

	# Check if action can be used
	if action.uses_remaining == 0:
		EventBus.message_logged.emit("[color=red]%s is exhausted! It will recharge at dawn.[/color]" % action.name)
		return

	# Execute the action based on type
	var success = false
	if action.type == "feat":
		success = _use_class_feat(action)
	else:
		success = _use_racial_trait(action)

	if success:
		# Refresh to update uses remaining
		refresh()
		action_used.emit(action.type, action.id)


func _use_class_feat(action: Dictionary) -> bool:
	var feat_id = action.id
	var effect = action.effect

	# Use the feat (decrements uses)
	if not player.use_class_feat(feat_id):
		EventBus.message_logged.emit("[color=red]Cannot use %s![/color]" % action.name)
		return false

	# Apply the effect based on feat type
	match feat_id:
		"second_wind":
			# Warrior: Heal 25% of max HP
			var heal_percent = effect.get("heal_percent", 25)
			@warning_ignore("integer_division")
			var heal_amount = player.max_health * heal_percent / 100
			player.heal(heal_amount)
			EventBus.message_logged.emit("[color=green]Second Wind! You recover %d HP![/color]" % heal_amount)
			return true

		"mana_surge":
			# Mage: Recover 50% of max mana
			var recovery_percent = effect.get("mana_recovery_percent", 50)
			if player.survival:
				var max_mana = player.survival.get_max_mana()
				var recovery = int(max_mana * recovery_percent / 100.0)
				player.survival.mana = min(player.survival.mana + recovery, max_mana)
				EventBus.message_logged.emit("[color=cyan]Mana Surge! You recover %d mana![/color]" % recovery)
			return true

		"vanish":
			# Rogue: Become undetectable for 1 turn
			var stealth_turns = effect.get("stealth_turns", 1)
			# Apply stealth effect
			player.add_magical_effect({
				"id": "vanish_stealth",
				"type": "buff",
				"remaining_duration": stealth_turns + 1,  # +1 because it ticks down immediately
				"modifiers": {}
			})
			EventBus.message_logged.emit("[color=gray]Vanish! You slip into the shadows...[/color]")
			return true

		"track_prey":
			# Ranger: Reveal all enemies within perception range
			var revealed_count = 0
			for entity in EntityManager.entities:
				if entity is Enemy and entity.is_alive:
					var distance = (entity.position - player.position).length()
					if distance <= player.perception_range * 2:
						# Mark enemy as tracked (could add a visual effect)
						revealed_count += 1
			EventBus.message_logged.emit("[color=green]Track Prey! You sense %d enemies nearby.[/color]" % revealed_count)
			return true

		"blessed_rest":
			# Cleric: Heal 10 HP instantly
			var heal_amount = effect.get("heal_amount", 10)
			# Apply with healing bonus
			player.heal_with_class_bonus(heal_amount)
			EventBus.message_logged.emit("[color=yellow]Blessed Rest! Divine energy heals you for %d HP![/color]" % heal_amount)
			return true

		"berserker_strike":
			# Barbarian: Next attack deals double damage
			player.add_magical_effect({
				"id": "berserker_strike",
				"type": "buff",
				"remaining_duration": 2,  # Lasts until next attack
				"modifiers": {}
			})
			EventBus.message_logged.emit("[color=red]Berserker Strike! Your next attack will deal double damage![/color]")
			return true

		_:
			EventBus.message_logged.emit("[color=yellow]%s activated![/color]" % action.name)
			return true


func _use_racial_trait(action: Dictionary) -> bool:
	var trait_id = action.id
	var effect = action.effect

	# Note: Some racial traits are reactive (Lucky, Relentless) and are used automatically
	# This handles ones that can be used manually

	match trait_id:
		"lucky":
			# Lucky is used automatically when missing an attack
			EventBus.message_logged.emit("[color=yellow]Lucky is used automatically when you miss an attack.[/color]")
			return false

		"relentless":
			# Relentless is used automatically when taking lethal damage
			EventBus.message_logged.emit("[color=yellow]Relentless Endurance activates automatically when you would die.[/color]")
			return false

		_:
			# For any other active traits that might be added
			if player.use_racial_ability(trait_id):
				EventBus.message_logged.emit("[color=cyan]%s activated![/color]" % action.name)
				return true
			return false
