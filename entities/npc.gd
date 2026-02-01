extends Entity
class_name NPC
## Non-Player Character base class
##
## NPCs are stationary entities that provide services like trading,
## quests, or information. They block movement but are non-hostile.

# NPC-specific properties
var npc_type: String = "generic"  ## Type: "shop", "quest", "guard", "trainer", etc.
var dialogue: Dictionary = {}  ## Dialogue lines for different contexts
var schedule: Array = []  ## Future: time-based behavior patterns
# faction is inherited from Entity
var trade_inventory: Array = []  ## Items available for purchase
var recipes_for_sale: Array = []  ## Recipes available for training [{recipe_id, base_price}]
var gold: int = 0  ## NPC's gold for transactions
var last_restock_turn: int = 0  ## Last turn when shop inventory restocked
var restock_interval: int = 500  ## Turns between restocks

func _init(id: String = "", pos: Vector2i = Vector2i.ZERO, char: String = "@", entity_color: Color = Color("#FFAA00"), blocks: bool = true):
	super(id, pos, char, entity_color, blocks)
	blocks_movement = true  # NPCs always block movement

	# Default attributes for NPCs (already set in Entity, but can override if needed)
	# attributes dictionary is inherited from Entity

func process_turn():
	## NPCs don't move or take actions in Phase 1
	## Future: schedule-based movement and behavior

	# Check if shop needs restocking
	if npc_type == "shop" and should_restock():
		restock_shop()

func should_restock() -> bool:
	return TurnManager.current_turn - last_restock_turn >= restock_interval

func restock_shop():
	## Restocks shop inventory from NPC definition data
	var npc_def = NPCManager.get_npc_definition(entity_id)
	if not npc_def.is_empty() and npc_def.has("trade_inventory"):
		trade_inventory = []
		for item_data in npc_def.get("trade_inventory", []):
			trade_inventory.append(item_data.duplicate())
	else:
		# No trade_inventory defined in JSON - NPC has no shop items
		push_warning("[NPC] No trade_inventory found for NPC: %s" % entity_id)
		trade_inventory = []
	last_restock_turn = TurnManager.current_turn
	EventBus.emit_signal("shop_restocked", self)

func interact(player: Player):
	## Called when player interacts with this NPC
	EventBus.emit_signal("npc_interacted", self, player)

	# Check what services this NPC offers
	var has_shop = npc_type == "shop" or trade_inventory.size() > 0
	var has_training = recipes_for_sale.size() > 0

	if has_shop and has_training:
		# Show menu to choose between services
		EventBus.emit_signal("npc_menu_opened", self, player)
	elif has_shop:
		open_shop(player)
	elif has_training:
		open_training(player)
	else:
		speak_greeting()

func open_shop(player: Player):
	## Opens shop interface for trading
	EventBus.emit_signal("shop_opened", self, player)

func open_training(player: Player):
	## Opens training interface for learning recipes
	EventBus.emit_signal("training_opened", self, player)

func speak_greeting():
	## Displays greeting dialogue
	var greeting = dialogue.get("greeting", "Hello, traveler.")
	EventBus.emit_signal("message_logged", "%s: %s" % [name if name else "NPC", greeting])

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

## Check if NPC has recipes available for training
func has_recipes_for_sale() -> bool:
	return recipes_for_sale.size() > 0

## Get recipe training data by recipe ID
func get_recipe_for_sale(recipe_id: String) -> Dictionary:
	for recipe_data in recipes_for_sale:
		if recipe_data.recipe_id == recipe_id:
			return recipe_data
	return {}

## Remove a recipe from training list (after player learns it)
func remove_recipe_for_sale(recipe_id: String) -> bool:
	for i in range(recipes_for_sale.size()):
		if recipes_for_sale[i].recipe_id == recipe_id:
			recipes_for_sale.remove_at(i)
			return true
	return false

## Serializes NPC data for saving (future use)
func to_dict() -> Dictionary:
	var data = {}
	data["entity_id"] = entity_id
	data["entity_type"] = entity_type
	data["name"] = name
	data["position"] = {"x": position.x, "y": position.y}
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

	# Serialize recipes for sale
	data["recipes_for_sale"] = []
	for recipe_data in recipes_for_sale:
		data["recipes_for_sale"].append(recipe_data.duplicate())

	return data

## Deserializes NPC data from saved game (future use)
func from_dict(data: Dictionary):
	entity_id = data.get("entity_id", "")
	entity_type = data.get("entity_type", "npc")
	name = data.get("name", "NPC")
	var pos = data.get("position", {"x": 0, "y": 0})
	position = Vector2i(pos.x, pos.y)
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

	# Deserialize recipes for sale
	recipes_for_sale = []
	for recipe_data in data.get("recipes_for_sale", []):
		recipes_for_sale.append(recipe_data.duplicate())
