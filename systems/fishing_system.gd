extends Node
class_name FishingSystem

## FishingSystem - Handles fishing mechanics
##
## Players can fish when adjacent to a body of water with 8+ contiguous water tiles.
## Requires a fishing rod (with bait) or a fishing net.

const ItemFactoryClass = preload("res://items/item_factory.gd")

# Static configuration
const MIN_WATER_BODY_SIZE: int = 8  # Minimum contiguous water tiles required
const MAX_FISHING_TURNS: int = 10  # Maximum turns before fish stop biting
const NIBBLE_LOSS_CHANCE: float = 0.1  # 10% chance to lose bait each turn without catch

# Fish species with catch chances (loaded from variants)
static var _fish_species: Array[Dictionary] = []

# Fishing session state
static var _fishing_sessions: Dictionary = {}  # Player ref -> session data

# Session data structure
class FishingSession:
	var turns_fished: int = 0
	var fishing_direction: Vector2i = Vector2i.ZERO
	var tool_type: String = ""  # "fishing_rod" or "fishing_net"

	func _init():
		turns_fished = 0
		fishing_direction = Vector2i.ZERO
		tool_type = ""

## Load fish species from variant data
static func load_fish_definitions() -> void:
	_fish_species.clear()

	# Get fish species variants
	var fish_variants = VariantManager.get_variants_of_type("fish_species")
	for species_name in fish_variants:
		var variant_data = fish_variants[species_name]
		# Get catch_chance from the override modifier
		var catch_chance = 0.15  # Default
		var modifiers = variant_data.get("modifiers", {})
		if modifiers.has("catch_chance"):
			var catch_mod = modifiers.get("catch_chance", {})
			if catch_mod.get("type", "") == "override":
				catch_chance = catch_mod.get("value", 0.15)

		_fish_species.append({
			"species": species_name,
			"catch_chance": catch_chance,
			"tier": variant_data.get("tier", 1)
		})

	# Sort by catch_chance (higher chance = more common, checked first)
	_fish_species.sort_custom(func(a, b):
		return a.catch_chance > b.catch_chance
	)

	print("[FishingSystem] Loaded %d fish species" % _fish_species.size())

## Check if player can fish in a given direction
## Returns: {can_fish, message, tool_type, requires_bait, water_position}
static func can_fish(player: Player, direction: Vector2i) -> Dictionary:
	if not player:
		return {"can_fish": false, "message": "Invalid player"}

	# Check if player is on overworld (no fishing in dungeons)
	if MapManager.current_map and not MapManager.current_map.chunk_based:
		return {"can_fish": false, "message": "Cannot fish in dungeons."}

	# Get target position
	var target_pos = player.position + direction
	var tile = MapManager.current_map.get_tile(target_pos) if MapManager.current_map else null

	if not tile or tile.tile_type != "water":
		return {"can_fish": false, "message": "No water in that direction."}

	# Check for fishing equipment
	var fishing_tool = _get_fishing_tool(player)
	if not fishing_tool.has_tool:
		return {"can_fish": false, "message": "Need a fishing rod or net to fish."}

	# Check for bait if using a rod
	if fishing_tool.requires_bait:
		var has_bait = _has_bait(player)
		if not has_bait:
			return {"can_fish": false, "message": "Need bait to fish with a rod."}

	# Check water body size
	var water_size = _count_contiguous_water(target_pos)
	if water_size < MIN_WATER_BODY_SIZE:
		return {"can_fish": false, "message": "Water body too small. Need at least %d connected water tiles." % MIN_WATER_BODY_SIZE}

	return {
		"can_fish": true,
		"message": "Ready to fish.",
		"tool_type": fishing_tool.tool_type,
		"requires_bait": fishing_tool.requires_bait,
		"water_position": target_pos
	}

## Start or continue a fishing session
## Returns: {success, message, caught_fish, bait_lost, session_ended}
static func fish(player: Player, direction: Vector2i) -> Dictionary:
	var can_fish_result = can_fish(player, direction)
	if not can_fish_result.can_fish:
		return {"success": false, "message": can_fish_result.message}

	# Get or create session
	var session = _get_or_create_session(player, direction, can_fish_result.tool_type)
	session.turns_fished += 1

	# Check if fish are no longer biting
	if session.turns_fished > MAX_FISHING_TURNS:
		_end_session(player)
		return {
			"success": true,
			"message": "The fish aren't biting today.",
			"caught_fish": null,
			"bait_lost": false,
			"session_ended": true
		}

	# Roll for catch based on fish rarity
	var caught_species = _roll_for_catch()

	if caught_species != "":
		# Consume bait if using rod
		if can_fish_result.requires_bait:
			_consume_bait(player)

		# Create fish item using ItemFactory
		var fish_item = ItemFactoryClass.create_item("fish", {"fish_species": caught_species}, 1)
		if fish_item:
			player.inventory.add_item(fish_item)

			# End session on successful catch
			_end_session(player)

			return {
				"success": true,
				"message": "You caught a %s!" % fish_item.name,
				"caught_fish": fish_item,
				"bait_lost": false,
				"session_ended": true
			}
		else:
			push_error("[FishingSystem] Failed to create fish item for species: %s" % caught_species)

	# No catch - check for bait nibble loss
	var bait_lost = false
	if can_fish_result.requires_bait and randf() < NIBBLE_LOSS_CHANCE:
		_consume_bait(player)
		bait_lost = true

	var message = "You fish patiently... (%d/%d)" % [session.turns_fished, MAX_FISHING_TURNS]
	if bait_lost:
		message = "Something nibbled off your bait! (%d/%d)" % [session.turns_fished, MAX_FISHING_TURNS]

	return {
		"success": true,
		"message": message,
		"caught_fish": null,
		"bait_lost": bait_lost,
		"session_ended": false
	}

## Check if player has a fishing session active
static func has_active_session(player: Player) -> bool:
	return player in _fishing_sessions

## End the current fishing session
static func _end_session(player: Player) -> void:
	if player in _fishing_sessions:
		_fishing_sessions.erase(player)

## Cancel a fishing session
static func cancel_session(player: Player) -> void:
	_end_session(player)

## Get or create a fishing session
static func _get_or_create_session(player: Player, direction: Vector2i, tool_type: String) -> FishingSession:
	if player in _fishing_sessions:
		return _fishing_sessions[player]

	var session = FishingSession.new()
	session.fishing_direction = direction
	session.tool_type = tool_type
	_fishing_sessions[player] = session
	return session

## Get the player's equipped or inventory fishing tool
## Returns: {has_tool, tool_type, requires_bait, tool_item}
static func _get_fishing_tool(player: Player) -> Dictionary:
	if not player or not player.inventory:
		return {"has_tool": false}

	# Check main hand first
	var main_hand = player.inventory.equipment.get("main_hand")
	if main_hand:
		if main_hand.id == "fishing_rod" or main_hand.tool_type == "fishing_rod":
			return {
				"has_tool": true,
				"tool_type": "fishing_rod",
				"requires_bait": true,
				"tool_item": main_hand
			}
		if main_hand.id == "fishing_net" or main_hand.tool_type == "fishing_net":
			return {
				"has_tool": true,
				"tool_type": "fishing_net",
				"requires_bait": false,
				"tool_item": main_hand
			}

	# Check off hand
	var off_hand = player.inventory.equipment.get("off_hand")
	if off_hand:
		if off_hand.id == "fishing_rod" or off_hand.tool_type == "fishing_rod":
			return {
				"has_tool": true,
				"tool_type": "fishing_rod",
				"requires_bait": true,
				"tool_item": off_hand
			}
		if off_hand.id == "fishing_net" or off_hand.tool_type == "fishing_net":
			return {
				"has_tool": true,
				"tool_type": "fishing_net",
				"requires_bait": false,
				"tool_item": off_hand
			}

	return {"has_tool": false}

## Check if player has bait in inventory
static func _has_bait(player: Player) -> bool:
	if not player or not player.inventory:
		return false

	for item in player.inventory.items:
		if item.id == "bait":
			return true

	return false

## Consume one bait from inventory
static func _consume_bait(player: Player) -> void:
	if not player or not player.inventory:
		return

	for item in player.inventory.items:
		if item.id == "bait":
			item.remove_from_stack(1)
			if item.is_empty():
				player.inventory.remove_item(item)
			return

## Count contiguous water tiles using flood fill
static func _count_contiguous_water(start_pos: Vector2i) -> int:
	if not MapManager.current_map:
		return 0

	var visited: Dictionary = {}
	var to_visit: Array[Vector2i] = [start_pos]
	var count = 0

	# Limit search to reasonable size to prevent performance issues
	var max_search = 100

	while to_visit.size() > 0 and count < max_search:
		var pos = to_visit.pop_front()

		if pos in visited:
			continue

		visited[pos] = true

		var tile = MapManager.current_map.get_tile(pos)
		if not tile or tile.tile_type != "water":
			continue

		count += 1

		# Add cardinal neighbors
		var neighbors = [
			pos + Vector2i(0, -1),  # North
			pos + Vector2i(0, 1),   # South
			pos + Vector2i(-1, 0),  # West
			pos + Vector2i(1, 0)    # East
		]

		for neighbor in neighbors:
			if neighbor not in visited:
				to_visit.append(neighbor)

	return count

## Roll for a fish catch based on fish catch chances
## Returns the species name or empty string
static func _roll_for_catch() -> String:
	if _fish_species.is_empty():
		load_fish_definitions()

	if _fish_species.is_empty():
		push_warning("[FishingSystem] No fish species loaded")
		return ""

	var roll = randf()

	for species_data in _fish_species:
		var catch_chance = species_data.get("catch_chance", 0.0)
		if roll < catch_chance:
			return species_data.get("species", "")
		roll -= catch_chance

	return ""  # No catch

## Check if a direction has water adjacent to player
static func has_adjacent_water(player: Player, direction: Vector2i) -> bool:
	if not player or not MapManager.current_map:
		return false

	var target_pos = player.position + direction
	var tile = MapManager.current_map.get_tile(target_pos)
	return tile != null and tile.tile_type == "water"

## Check if player is adjacent to any water
static func is_adjacent_to_water(player: Player) -> bool:
	var directions = [
		Vector2i(0, -1),  # North
		Vector2i(0, 1),   # South
		Vector2i(-1, 0),  # West
		Vector2i(1, 0)    # East
	]

	for dir in directions:
		if has_adjacent_water(player, dir):
			return true

	return false

## Serialize fishing sessions for save
static func serialize() -> Array[Dictionary]:
	# Sessions are transient and not saved
	return []

## Deserialize fishing sessions from save
static func deserialize(_data: Array) -> void:
	# Clear sessions on load
	_fishing_sessions.clear()
