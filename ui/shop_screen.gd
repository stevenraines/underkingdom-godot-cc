extends Control

## ShopScreen - UI for buying and selling items with NPCs
##
## Shows shop inventory on left (for buying), player inventory on right (for selling).
## Prices are affected by player's Charisma stat.

const ShopSystem = preload("res://systems/shop_system.gd")

signal closed()
signal switch_to_training(npc, player)  # Signal to switch to training screen

@onready var shop_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/ShopPanel/ScrollContainer
@onready var shop_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/ShopPanel/ScrollContainer/ShopList
@onready var player_scroll: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/PlayerPanel/ScrollContainer
@onready var player_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ContentContainer/PlayerPanel/ScrollContainer/PlayerList
@onready var shop_title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleContainer/ShopTitle
@onready var shopkeeper_label: Label = $Panel/MarginContainer/VBoxContainer/TitleContainer/ShopKeeperLabel
@onready var gold_label: Label = $Panel/MarginContainer/VBoxContainer/TitleContainer/GoldLabel
@onready var buy_button: Button = $Panel/MarginContainer/VBoxContainer/ActionsContainer/BuyButton
@onready var sell_button: Button = $Panel/MarginContainer/VBoxContainer/ActionsContainer/SellButton
@onready var help_label: Label = $Panel/MarginContainer/VBoxContainer/HelpLabel

var player: Player = null
var shop_npc: NPC = null
var selected_index: int = 0
var is_shop_focused: bool = true  # true = buying from shop, false = selling to shop
var quantity: int = 1  # How many to buy/sell

# Shop system reference
var shop_system: ShopSystem = null

# Filter state (independent for each panel)
var shop_filter: Inventory.FilterType = Inventory.FilterType.ALL
var player_filter: Inventory.FilterType = Inventory.FilterType.ALL

# Colors
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_GOLD = Color(0.9, 0.7, 0.2, 1.0)
const COLOR_AFFORDABLE = Color(0.6, 0.9, 0.6, 1.0)
const COLOR_EXPENSIVE = Color(0.9, 0.5, 0.5, 1.0)

# Filter hotkeys (shared with inventory screen)
const FILTER_HOTKEYS = {
	KEY_1: Inventory.FilterType.ALL,
	KEY_2: Inventory.FilterType.WEAPONS,
	KEY_3: Inventory.FilterType.ARMOR,
	KEY_4: Inventory.FilterType.TOOLS,
	KEY_5: Inventory.FilterType.CONSUMABLES,
	KEY_6: Inventory.FilterType.MATERIALS,
	KEY_7: Inventory.FilterType.AMMUNITION,
	KEY_8: Inventory.FilterType.BOOKS,
	KEY_9: Inventory.FilterType.SEEDS,
	KEY_0: Inventory.FilterType.MISC
}

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	shop_system = ShopSystem.new()

	# Connect button signals
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Handle filter hotkeys (number keys 1-0) - applies to focused panel
		if FILTER_HOTKEYS.has(event.keycode):
			if is_shop_focused:
				shop_filter = FILTER_HOTKEYS[event.keycode]
			else:
				player_filter = FILTER_HOTKEYS[event.keycode]
			selected_index = 0
			_refresh_display()
			get_viewport().set_input_as_handled()
			return

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
			KEY_TAB:
				_toggle_focus()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				if is_shop_focused:
					_buy_selected()
				get_viewport().set_input_as_handled()
			KEY_S:
				if not is_shop_focused:
					_sell_selected()
				get_viewport().set_input_as_handled()
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
				_adjust_quantity(1)
				get_viewport().set_input_as_handled()
			KEY_MINUS, KEY_KP_SUBTRACT:
				_adjust_quantity(-1)
				get_viewport().set_input_as_handled()
			KEY_L:
				# Switch to Learn Recipes if NPC has training
				_switch_to_training()
				get_viewport().set_input_as_handled()

func _switch_to_training() -> void:
	if shop_npc and shop_npc.recipes_for_sale.size() > 0:
		hide()
		get_tree().paused = false
		switch_to_training.emit(shop_npc, player)

func has_training_available() -> bool:
	return shop_npc and shop_npc.recipes_for_sale.size() > 0

func open(p_player: Player, p_shop_npc: NPC) -> void:
	player = p_player
	shop_npc = p_shop_npc
	is_shop_focused = true
	selected_index = 0
	quantity = 1

	# Display shop keeper greeting
	var greeting = shop_npc.dialogue.get("greeting", "Welcome to my shop!")
	shopkeeper_label.text = "%s: \"%s\"" % [shop_npc.name, greeting]

	_refresh_display()
	show()
	get_tree().paused = true

func _close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()

func _navigate(direction: int) -> void:
	var max_index = _get_current_list_size() - 1
	if max_index < 0:
		selected_index = 0
		quantity = 1
		_refresh_display()
		return

	selected_index = clamp(selected_index + direction, 0, max_index)
	quantity = 1  # Reset quantity when navigating
	_refresh_display()

func _toggle_focus() -> void:
	is_shop_focused = not is_shop_focused
	selected_index = 0
	quantity = 1
	_refresh_display()

func _adjust_quantity(delta: int) -> void:
	var max_quantity = _get_max_quantity()
	quantity = clamp(quantity + delta, 1, max_quantity)
	_refresh_display()

func _get_max_quantity() -> int:
	if is_shop_focused:
		# Buying: limited by shop stock and player gold/weight
		if shop_npc.trade_inventory.size() == 0 or selected_index >= shop_npc.trade_inventory.size():
			return 1

		var item_data = shop_npc.trade_inventory[selected_index]
		var available = item_data.count

		# Calculate how many player can afford
		var unit_price = shop_system.calculate_buy_price(item_data.base_price, player.attributes["CHA"])
		var can_afford = int(player.gold / unit_price) if unit_price > 0 else available

		# Calculate how many player can carry
		var item_template = ItemManager.get_item_data(item_data.item_id)
		if item_template:
			var item_weight = item_template.get("weight", 0.0)
			var remaining_capacity = player.inventory.max_weight - player.inventory.get_total_weight()
			var can_carry = int(remaining_capacity / item_weight) if item_weight > 0 else available
			return min(available, can_afford, can_carry)

		return min(available, can_afford)
	else:
		# Selling: limited by player inventory and shop gold
		var player_items = _get_filtered_player_items()
		if player_items.size() == 0 or selected_index >= player_items.size():
			return 1

		var item = player_items[selected_index]
		# Player inventory stores Item instances (RefCounted). Use stack_size for quantity.
		var available = item.stack_size if item is Item else item.count

		# Calculate how many shop can afford
		var unit_price = shop_system.calculate_sell_price(item.value, player.attributes["CHA"])
		var can_afford = int(shop_npc.gold / unit_price) if unit_price > 0 else available

		return min(available, can_afford)

func _get_current_list_size() -> int:
	if is_shop_focused:
		return shop_npc.trade_inventory.size() if shop_npc else 0
	else:
		return _get_filtered_player_items().size()

func _on_buy_pressed() -> void:
	_buy_selected()

func _on_sell_pressed() -> void:
	_sell_selected()

func _buy_selected() -> void:
	if not is_shop_focused or not shop_npc or not player:
		return

	if shop_npc.trade_inventory.size() == 0 or selected_index >= shop_npc.trade_inventory.size():
		return

	var item_data = shop_npc.trade_inventory[selected_index]
	var success = shop_system.attempt_purchase(shop_npc, item_data.item_id, quantity, player)

	if success:
		# Reset quantity after successful purchase
		quantity = 1
		_refresh_display()

func _sell_selected() -> void:
	if is_shop_focused or not shop_npc or not player:
		return

	var player_items = _get_filtered_player_items()
	if player_items.size() == 0 or selected_index >= player_items.size():
		return

	var item = player_items[selected_index]
	var success = shop_system.attempt_sell(shop_npc, item, quantity, player)

	if success:
		# Reset quantity after successful sale
		quantity = 1

		# Adjust selected_index if we're now past the end
		var new_size = _get_filtered_player_items().size()
		if selected_index >= new_size:
			selected_index = max(0, new_size - 1)

		_refresh_display()

func _refresh_display() -> void:
	# Clear lists
	for child in shop_list.get_children():
		child.queue_free()
	for child in player_list.get_children():
		child.queue_free()

	if not player or not shop_npc:
		return

	# Update gold label
	gold_label.text = "Your Gold: %d" % player.gold
	gold_label.modulate = COLOR_GOLD

	# Populate shop inventory
	for i in range(shop_npc.trade_inventory.size()):
		var item_data = shop_npc.trade_inventory[i]
		var item_template = ItemManager.get_item_data(item_data.item_id)
		if not item_template:
			continue

		var item_name = item_template.get("name", item_data.item_id)
		var unit_price = shop_system.calculate_buy_price(item_data.base_price, player.attributes["CHA"])
		var total_price = unit_price * (quantity if is_shop_focused and i == selected_index else 1)

		var label = Label.new()
		label.add_theme_font_size_override("font_size", 13)

		var qty_text = ""
		if is_shop_focused and i == selected_index and quantity > 1:
			qty_text = " x%d = %dg" % [quantity, total_price]
		else:
			qty_text = " (%dg)" % unit_price

		# Add selection triangle
		var prefix = "► " if (is_shop_focused and i == selected_index) else "  "
		label.text = "%s%s x%d%s" % [prefix, item_name, item_data.count, qty_text]

		# Color based on selection and affordability
		if is_shop_focused and i == selected_index:
			label.modulate = COLOR_SELECTED
			if player.gold < total_price:
				label.modulate = COLOR_EXPENSIVE
		else:
			label.modulate = COLOR_NORMAL

		shop_list.add_child(label)

	# Populate player inventory (filtered and sorted)
	var player_items = player.inventory.get_items_by_filter(player_filter)
	for i in range(player_items.size()):
		var item = player_items[i]
		var unit_price = shop_system.calculate_sell_price(item.value, player.attributes["CHA"])
		var total_price = unit_price * (quantity if not is_shop_focused and i == selected_index else 1)

		var label = Label.new()
		label.add_theme_font_size_override("font_size", 13)

		var qty_text = ""
		if not is_shop_focused and i == selected_index and quantity > 1:
			qty_text = " x%d = %dg" % [quantity, total_price]
		else:
			qty_text = " (%dg)" % unit_price

		# Use stack_size for Item instances, else fallback to count for legacy/data objects
		var display_count = item.stack_size if item is Item else item.count

		# Add selection triangle
		var prefix = "► " if (not is_shop_focused and i == selected_index) else "  "
		label.text = "%s%s x%d%s" % [prefix, item.name, display_count, qty_text]

		# Color based on selection and shop's ability to afford
		if not is_shop_focused and i == selected_index:
			label.modulate = COLOR_SELECTED
			if shop_npc.gold < total_price:
				label.modulate = COLOR_EXPENSIVE
		else:
			label.modulate = COLOR_NORMAL

		player_list.add_child(label)

	# Update button states
	buy_button.disabled = not is_shop_focused or shop_npc.trade_inventory.size() == 0
	sell_button.disabled = is_shop_focused or player_items.size() == 0

	# Update help label to show [L] Learn if training available
	if has_training_available():
		help_label.text = "[Tab] Switch  |  [+/-] Qty  |  [Enter] Buy  |  [S] Sell  |  [L] Learn  |  [Esc] Close"
	else:
		help_label.text = "[Tab] Switch  |  [+/-] Quantity  |  [Enter] Buy  |  [S] Sell  |  [Esc] Close"

	# Scroll to selected item after the frame updates
	_scroll_to_selected.call_deferred()

func _scroll_to_selected() -> void:
	var scroll: ScrollContainer
	var list: VBoxContainer

	if is_shop_focused:
		scroll = shop_scroll
		list = shop_list
	else:
		scroll = player_scroll
		list = player_list

	if not scroll or not list:
		return

	if selected_index < 0 or selected_index >= list.get_child_count():
		return

	var selected_label = list.get_child(selected_index) as Control
	if not selected_label:
		return

	# Get the position and size of the selected item relative to the list
	var item_top = selected_label.position.y
	var item_bottom = item_top + selected_label.size.y
	var visible_top = scroll.scroll_vertical
	var visible_bottom = visible_top + scroll.size.y

	# Scroll up if item is above visible area
	if item_top < visible_top:
		scroll.scroll_vertical = int(item_top)
	# Scroll down if item is below visible area
	elif item_bottom > visible_bottom:
		scroll.scroll_vertical = int(item_bottom - scroll.size.y)

## Get filtered player items for display
func _get_filtered_player_items() -> Array[Item]:
	if not player or not player.inventory:
		return []
	return player.inventory.get_items_by_filter(player_filter)

## Get the unfiltered item from player inventory by filtered index
func _get_player_item_at_filtered_index(index: int) -> Item:
	var filtered_items = _get_filtered_player_items()
	if index >= 0 and index < filtered_items.size():
		return filtered_items[index]
	return null
