extends Node
## ShopSystem - Handles buy/sell transactions with CHA-based pricing
##
## Manages all shop interactions, price calculations, and inventory updates.
## Prices are affected by player's Charisma stat.

const CHARISMA_PRICE_MODIFIER = 0.05  ## 5% price change per CHA point from 10
const SHOP_BUY_RATIO = 0.5  ## Shops buy items at 50% of base value

## Calculates price when player is buying from shop
## Higher CHA = lower price for player
func calculate_buy_price(base_price: int, player_cha: int) -> int:
	var modifier = 1.0 - ((player_cha - 10) * CHARISMA_PRICE_MODIFIER)
	modifier = clamp(modifier, 0.5, 1.5)  # Range: 50%-150% of base price
	return max(1, int(base_price * modifier))  # Minimum price of 1

## Calculates price when player is selling to shop
## Higher CHA = higher price for player
func calculate_sell_price(base_price: int, player_cha: int) -> int:
	var base_sell = base_price * SHOP_BUY_RATIO  # Shops buy at 50% base value
	var modifier = 1.0 + ((player_cha - 10) * CHARISMA_PRICE_MODIFIER)
	modifier = clamp(modifier, 0.5, 1.5)
	return max(1, int(base_sell * modifier))  # Minimum price of 1

## Attempts to purchase item from shop
## Returns true if successful
func attempt_purchase(shop_npc, item_id: String, count: int, player) -> bool:
	# Validate shop has the item
	var item_data = shop_npc.get_shop_item(item_id)
	if not item_data:
		EventBus.emit_signal("message_logged", "Shop doesn't sell that item.")
		return false

	if item_data.count < count:
		EventBus.emit_signal("message_logged", "Shop only has %d %s available." % [item_data.count, item_id])
		return false

	# Calculate total price
	var unit_price = calculate_buy_price(item_data.base_price, player.attributes["CHA"])
	var total_price = unit_price * count

	# Check if player can afford it
	if player.gold < total_price:
		EventBus.emit_signal("message_logged", "Not enough gold. Need %d gold." % total_price)
		return false

	# Check if player can carry it
	var item_template = ItemManager.get_item_data(item_id)
	if not item_template:
		EventBus.emit_signal("message_logged", "Item data not found.")
		return false

	var item_weight = item_template.get("weight", 0.0) * count
	if player.inventory.get_total_weight() + item_weight > player.inventory.max_weight:
		EventBus.emit_signal("message_logged", "Too heavy to carry.")
		return false

	# Execute transaction
	player.gold -= total_price
	shop_npc.gold += total_price
	shop_npc.remove_shop_item(item_id, count)

	var item = ItemManager.create_item(item_id, count)

	# Items purchased from shops are automatically identified
	if item.unidentified:
		IdentificationManager.identify_item(item.id)
		item.unidentified = false

	player.inventory.add_item(item)

	EventBus.emit_signal("item_purchased", item, total_price)
	EventBus.emit_signal("message_logged", "Purchased %dx %s for %d gold." % [count, item.name, total_price])
	EventBus.emit_signal("inventory_changed")

	return true

## Attempts to sell item to shop
## Returns true if successful
func attempt_sell(shop_npc, item, count: int, player) -> bool:
	# Validate player has the item
	if not player.inventory.has_item(item.id, count):
		EventBus.emit_signal("message_logged", "You don't have enough %s." % item.name)
		return false

	# Calculate sell price
	var unit_price = calculate_sell_price(item.value, player.attributes["CHA"])
	var total_price = unit_price * count

	# Check if shop can afford it
	if shop_npc.gold < total_price:
		EventBus.emit_signal("message_logged", "Shop doesn't have enough gold.")
		return false

	# Execute transaction
	player.gold += total_price
	shop_npc.gold -= total_price
	player.inventory.remove_item_by_id(item.id, count)

	# Add to shop inventory
	shop_npc.add_shop_item(item.id, count, item.value)

	EventBus.emit_signal("item_sold", item, total_price)
	EventBus.emit_signal("message_logged", "Sold %dx %s for %d gold." % [count, item.name, total_price])
	EventBus.emit_signal("inventory_changed")

	return true

## Gets formatted price string with CHA modifier display
func get_price_display(base_price: int, player_cha: int, is_buying: bool) -> String:
	var final_price = calculate_buy_price(base_price, player_cha) if is_buying else calculate_sell_price(base_price, player_cha)

	if final_price == base_price:
		return "%dg" % final_price
	elif final_price < base_price:
		return "%dg (-%d%%)" % [final_price, int((1.0 - float(final_price) / base_price) * 100)]
	else:
		return "%dg (+%d%%)" % [final_price, int((float(final_price) / base_price - 1.0) * 100)]
