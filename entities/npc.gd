extends Entity
class_name NPC
## Non-Player Character base class
##
## NPCs are stationary entities that provide services like trading,
## quests, or information. They block movement but are non-hostile.

# NPC-specific properties
var npc_type: String = "generic"  ## Type: "shop", "quest", "guard", etc.
var dialogue: Dictionary = {}  ## Dialogue lines for different contexts
var schedule: Array = []  ## Future: time-based behavior patterns
var faction: String = "neutral"  ## Faction affiliation
var trade_inventory: Array = []  ## Items available for purchase
var gold: int = 0  ## NPC's gold for transactions
var last_restock_turn: int = 0  ## Last turn when shop inventory restocked
var restock_interval: int = 500  ## Turns between restocks

func _init():
	super()
	blocking = true  # NPCs always block movement
	ascii_char = "@"
	ascii_color = Color("#FFAA00")  # Golden color for NPCs

	# Default stats for NPCs
	stats = {
		"str": 10,
		"dex": 10,
		"con": 10,
		"int": 10,
		"wis": 10,
		"cha": 10
	}

func process_turn():
	## NPCs don't move or take actions in Phase 1
	## Future: schedule-based movement and behavior

	# Check if shop needs restocking
	if npc_type == "shop" and should_restock():
		restock_shop()

func should_restock() -> bool:
	return TurnManager.current_turn - last_restock_turn >= restock_interval

func restock_shop():
	## Restocks shop inventory from default data
	load_shop_inventory()
	last_restock_turn = TurnManager.current_turn
	EventBus.emit_signal("shop_restocked", self)
	EventBus.emit_signal("message_logged", "%s has restocked their shop." % name if name else "Shop restocked.")

func interact(player: Player):
	## Called when player interacts with this NPC
	EventBus.emit_signal("npc_interacted", self, player)

	# Default interaction
	if npc_type == "shop":
		open_shop(player)
	else:
		speak_greeting()

func open_shop(player: Player):
	## Opens shop interface for trading
	EventBus.emit_signal("shop_opened", self, player)

func speak_greeting():
	## Displays greeting dialogue
	var greeting = dialogue.get("greeting", "Hello, traveler.")
	EventBus.emit_signal("message_logged", "%s: %s" % [name if name else "NPC", greeting])

func load_shop_inventory():
	## Loads default shop inventory
	## This should be overridden when creating specific NPCs
	## or loaded from JSON data in the future

	# Phase 1 default shop inventory
	if npc_type == "shop":
		trade_inventory = [
			{"item_id": "raw_meat", "count": 10, "base_price": 5},
			{"item_id": "cooked_meat", "count": 5, "base_price": 8},
			{"item_id": "waterskin_empty", "count": 5, "base_price": 10},
			{"item_id": "torch", "count": 20, "base_price": 3},
			{"item_id": "bandage", "count": 8, "base_price": 12},
			{"item_id": "cord", "count": 15, "base_price": 2},
			{"item_id": "cloth", "count": 10, "base_price": 3},
			{"item_id": "flint", "count": 8, "base_price": 5}
		]

func get_shop_item(item_id: String) -> Dictionary:
	## Returns shop item data if available
	for item_data in trade_inventory:
		if item_data.item_id == item_id:
			return item_data
	return {}

func add_shop_item(item_id: String, count: int, base_price: int):
	## Adds or updates item in shop inventory
	var existing = get_shop_item(item_id)
	if existing:
		existing.count += count
	else:
		trade_inventory.append({
			"item_id": item_id,
			"count": count,
			"base_price": base_price
		})

func remove_shop_item(item_id: String, count: int) -> bool:
	## Removes count of item from shop inventory
	## Returns true if successful
	var item_data = get_shop_item(item_id)
	if not item_data:
		return false

	if item_data.count < count:
		return false

	item_data.count -= count

	# Remove entry if count reaches 0
	if item_data.count == 0:
		trade_inventory.erase(item_data)

	return true

func to_dict() -> Dictionary:
	## Serializes NPC data for saving
	var data = super.to_dict()
	data["npc_type"] = npc_type
	data["dialogue"] = dialogue.duplicate()
	data["faction"] = faction
	data["gold"] = gold
	data["last_restock_turn"] = last_restock_turn
	data["restock_interval"] = restock_interval

	# Serialize trade inventory
	data["trade_inventory"] = []
	for item_data in trade_inventory:
		data["trade_inventory"].append(item_data.duplicate())

	return data

func from_dict(data: Dictionary):
	## Deserializes NPC data from saved game
	super.from_dict(data)
	npc_type = data.get("npc_type", "generic")
	dialogue = data.get("dialogue", {})
	faction = data.get("faction", "neutral")
	gold = data.get("gold", 0)
	last_restock_turn = data.get("last_restock_turn", 0)
	restock_interval = data.get("restock_interval", 500)

	# Deserialize trade inventory
	trade_inventory = []
	for item_data in data.get("trade_inventory", []):
		trade_inventory.append(item_data.duplicate())
