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
				"effect": feat.get("effect", {}),
				"activation_pattern": feat.get("activation_pattern", "direct_effect")
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
		label.add_theme_color_override("font_color", UITheme.COLOR_EMPTY)
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
		icon.add_theme_color_override("font_color", UITheme.COLOR_FEAT)
	else:
		icon.text = "●"
		icon.add_theme_color_override("font_color", UITheme.COLOR_TRAIT)
	container.add_child(icon)

	# Name
	var name_label = Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.text = action.name
	name_label.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)
	container.add_child(name_label)

	# Source (class/race)
	var source_label = Label.new()
	source_label.name = "Source"
	source_label.custom_minimum_size = Vector2(70, 0)
	source_label.add_theme_font_size_override("font_size", 12)
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	source_label.text = action.source
	if action.type == "feat":
		source_label.add_theme_color_override("font_color", UITheme.COLOR_FEAT)
	else:
		source_label.add_theme_color_override("font_color", UITheme.COLOR_TRAIT)
	container.add_child(source_label)

	# Uses remaining
	var uses_label = Label.new()
	uses_label.name = "Uses"
	uses_label.custom_minimum_size = Vector2(60, 0)
	uses_label.add_theme_font_size_override("font_size", 12)
	uses_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if action.uses_remaining == -1:
		uses_label.text = "∞"
		uses_label.add_theme_color_override("font_color", UITheme.COLOR_USABLE)
	else:
		uses_label.text = "%d/%d" % [action.uses_remaining, action.max_uses]
		if action.uses_remaining > 0:
			uses_label.add_theme_color_override("font_color", UITheme.COLOR_USABLE)
		else:
			uses_label.add_theme_color_override("font_color", UITheme.COLOR_EXHAUSTED)
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
				name_node.add_theme_color_override("font_color", UITheme.COLOR_HIGHLIGHT)
			else:
				name_node.text = name_node.text.trim_prefix("► ")
				name_node.add_theme_color_override("font_color", UITheme.COLOR_NORMAL)


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
		action_name_label.add_theme_color_override("font_color", UITheme.COLOR_EMPTY)
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
			action_name_label.add_theme_color_override("font_color", UITheme.COLOR_FEAT)
		else:
			action_name_label.add_theme_color_override("font_color", UITheme.COLOR_TRAIT)

	if action_desc_label:
		action_desc_label.text = action.description

	# Stats column
	if stat_line_1:
		var type_name = "Class Feat" if action.type == "feat" else "Racial Trait"
		stat_line_1.text = "Type: %s" % type_name
		if action.type == "feat":
			stat_line_1.add_theme_color_override("font_color", UITheme.COLOR_FEAT)
		else:
			stat_line_1.add_theme_color_override("font_color", UITheme.COLOR_TRAIT)

	if stat_line_2:
		stat_line_2.text = "Source: %s" % action.source
		stat_line_2.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	if stat_line_3:
		if action.uses_remaining == -1:
			stat_line_3.text = "Uses: Unlimited"
			stat_line_3.add_theme_color_override("font_color", UITheme.COLOR_USABLE)
		elif action.uses_remaining > 0:
			stat_line_3.text = "Uses: %d/%d per day" % [action.uses_remaining, action.max_uses]
			stat_line_3.add_theme_color_override("font_color", UITheme.COLOR_USABLE)
		else:
			stat_line_3.text = "Exhausted (recharges at dawn)"
			stat_line_3.add_theme_color_override("font_color", UITheme.COLOR_EXHAUSTED)

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
	var pattern = action.get("activation_pattern", "direct_effect")

	match pattern:
		"proactive_buff":
			return _handle_proactive_buff(action, false)  # false = is class feat
		"direct_effect":
			return _handle_direct_effect(action, false)
		"aoe_undead_effect":
			return _handle_aoe_undead_effect(action)
		"reactive_automatic":
			EventBus.message_logged.emit("[color=yellow]%s activates automatically.[/color]" % action.name)
			return false
		_:
			push_error("Unknown activation pattern for class feat: %s" % pattern)
			return false


func _use_racial_trait(action: Dictionary) -> bool:
	var pattern = action.get("activation_pattern", "direct_effect")

	match pattern:
		"proactive_buff":
			return _handle_proactive_buff(action, true)  # true = is racial
		"direct_effect":
			return _handle_direct_effect(action, true)
		"reactive_automatic":
			EventBus.message_logged.emit("[color=yellow]%s activates automatically.[/color]" % action.name)
			return false
		_:
			push_error("Unknown activation pattern for racial trait: %s" % pattern)
			return false


## Generic handler for proactive buff abilities (activate now, trigger later)
func _handle_proactive_buff(action: Dictionary, is_racial: bool) -> bool:
	var action_id = action.id
	var effect = action.effect

	# Use the ability (decrements uses)
	var success = false
	if is_racial:
		success = player.use_racial_ability(action_id)
	else:
		success = player.use_class_feat(action_id)

	if not success:
		EventBus.message_logged.emit("[color=red]Cannot use %s![/color]" % action.name)
		return false

	# Create and apply the buff
	var buff = {
		"id": effect.get("buff_id", action_id + "_active"),
		"type": "buff",
		"name": effect.get("buff_name", action.name + " (Active)"),
		"modifiers": {},
		"remaining_duration": effect.get("buff_duration", 999),
		"source_spell": "",
		"trigger_on": effect.get("trigger_on", ""),
		"trigger_effect": effect.get("trigger_effect", ""),
		"damage_multiplier": effect.get("damage_multiplier", 1.0),
		"self_damage": effect.get("self_damage", 0)
	}
	player.add_magical_effect(buff)

	# Show activation message
	var msg = effect.get("activation_message", "%s activated!" % action.name)
	EventBus.message_logged.emit("[color=yellow]%s[/color]" % msg)
	return true


## Generic handler for direct effect abilities (instant result)
func _handle_direct_effect(action: Dictionary, is_racial: bool) -> bool:
	var action_id = action.id
	var effect = action.effect

	# Use the ability (decrements uses)
	var success = false
	if is_racial:
		success = player.use_racial_ability(action_id)
	else:
		success = player.use_class_feat(action_id)

	if not success:
		EventBus.message_logged.emit("[color=red]Cannot use %s![/color]" % action.name)
		return false

	# Apply direct effects based on what's in the effect dictionary

	# Healing (percent or fixed amount)
	if effect.has("heal_percent"):
		var heal_amount = int(player.max_health * effect.heal_percent)
		if player.has_method("heal_with_class_bonus"):
			player.heal_with_class_bonus(heal_amount)
		else:
			player.heal(heal_amount)
	elif effect.has("heal_amount"):
		var heal_amount = effect.heal_amount
		if player.has_method("heal_with_class_bonus"):
			player.heal_with_class_bonus(heal_amount)
		else:
			player.heal(heal_amount)

	# Mana recovery (percent)
	if effect.has("mana_percent"):
		if player.survival:
			var max_mana = player.survival.get_max_mana()
			var recovery = int(max_mana * effect.mana_percent)
			player.survival.mana = min(player.survival.mana + recovery, max_mana)

	# Apply a temporary buff
	if effect.has("apply_buff"):
		var buff_data = effect.apply_buff
		var buff = {
			"id": buff_data.get("buff_id", action_id + "_buff"),
			"type": buff_data.get("buff_type", "buff"),
			"name": buff_data.get("buff_name", action.name),
			"modifiers": {},
			"remaining_duration": buff_data.get("buff_duration", 1),
			"source_spell": ""
		}
		player.add_magical_effect(buff)

	# Reveal enemies (Ranger Track Prey)
	if effect.get("reveal_enemies", false):
		var revealed_count = 0
		for entity in EntityManager.entities:
			if entity is Enemy and entity.is_alive:
				var distance = (entity.position - player.position).length()
				if distance <= player.perception_range * 2:
					revealed_count += 1
		# Message will be shown by activation_message

	# Show activation message
	var msg = effect.get("activation_message", "%s activated!" % action.name)
	EventBus.message_logged.emit("[color=yellow]%s[/color]" % msg)
	return true


## Handle AOE undead effect abilities (Turn Undead)
func _handle_aoe_undead_effect(action: Dictionary) -> bool:
	const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")
	const ElementalSystemClass = preload("res://systems/elemental_system.gd")

	var action_id = action.id
	var effect = action.effect

	# Calculate radius based on player level
	var base_radius = effect.get("base_radius", 3)
	var radius_per_levels = effect.get("radius_per_levels", 4)
	var bonus_radius = player.level / radius_per_levels
	var final_radius = base_radius + bonus_radius

	# Get all entities in AOE
	var entities_in_range = SpellCastingSystemClass.get_entities_in_aoe(player.position, final_radius, "circle")

	# Filter to target creature type only
	var target_type = effect.get("target_creature_type", "undead")
	var valid_targets: Array = []
	for entity in entities_in_range:
		if entity == player:
			continue
		if entity.creature_type == target_type and entity.is_alive:
			valid_targets.append(entity)

	if valid_targets.is_empty():
		EventBus.message_logged.emit("[color=yellow]No %s in range.[/color]" % target_type)
		return false

	# Use the ability (decrements uses) - only after we confirm there are targets
	if not player.use_class_feat(action_id):
		EventBus.message_logged.emit("[color=red]Cannot use %s![/color]" % action.name)
		return false

	# Show activation message
	var msg = effect.get("activation_message", "%s activated!" % action.name)
	EventBus.message_logged.emit("[color=gold]%s[/color]" % msg)

	# Apply damage and fear to each target
	# Total damage is spread across all targets (divided evenly)
	var total_base_damage = effect.get("base_damage", 12)
	var damage_type = effect.get("damage_type", "radiant")
	var fear_duration = effect.get("fear_duration", 4)

	# Divide damage among all targets (minimum 1 per target)
	var damage_per_target = maxi(1, total_base_damage / valid_targets.size())

	var total_damage_dealt = 0
	var enemies_affected = 0
	var enemies_killed = 0

	for target in valid_targets:
		# Calculate and apply radiant damage (ElementalSystem handles vulnerability)
		var damage_result = ElementalSystemClass.calculate_elemental_damage(damage_per_target, damage_type, target, player)
		var final_damage = damage_result.get("final_damage", damage_per_target)

		if final_damage > 0:
			target.take_damage(final_damage, player.name, "Turn Undead")
			total_damage_dealt += final_damage
			# Show per-target damage message
			EventBus.message_logged.emit("[color=gold]%s takes %d radiant damage![/color]" % [target.name, final_damage])

		# Check if target died from damage
		if not target.is_alive:
			enemies_killed += 1
			enemies_affected += 1
			continue

		# Apply fear effect to surviving targets
		_apply_turn_undead_fear(target, fear_duration)
		enemies_affected += 1

	# Log results
	if enemies_killed > 0:
		EventBus.message_logged.emit("[color=gold]Turn Undead destroys %d undead![/color]" % enemies_killed)
	if enemies_affected - enemies_killed > 0:
		EventBus.message_logged.emit("[color=gold]%d undead flee in terror![/color]" % (enemies_affected - enemies_killed))

	EventBus.message_logged.emit("[color=yellow]Dealt %d radiant damage to %d undead.[/color]" % [total_damage_dealt, enemies_affected])

	# Close the special actions screen
	_close()

	return true


## Apply fear effect from Turn Undead
func _apply_turn_undead_fear(target, duration: int) -> void:
	var fear_effect = {
		"id": "turn_undead_fear",
		"type": "fear",
		"flee_from": player.position,
		"remaining_duration": duration,
		"source_spell": "turn_undead"
	}

	target.ai_state = "fleeing"
	target.add_magical_effect(fear_effect)
