extends Node
class_name HarvestSystem

# Harvest behaviors
enum HarvestBehavior {
	DESTROY_PERMANENT,  # Resource destroyed, never respawns (trees, rocks)
	DESTROY_RENEWABLE,  # Resource destroyed, respawns after time (wheat, berries)
	NON_CONSUMABLE      # Resource never consumed (water sources)
}

# Tool requirement with optional bonuses
class ToolRequirement:
	var tool_id: String
	var action_reduction: int = 0  # Reduces number of harvest actions required
	var yield_bonus: int = 0  # Adds to the randomly generated yield count

	func _init(data):
		# Support both string format (backwards compatible) and object format
		if data is String:
			tool_id = data
		elif data is Dictionary:
			tool_id = data.get("tool_id", "")
			action_reduction = int(data.get("action_reduction", 0))
			yield_bonus = int(data.get("yield_bonus", 0))

# Resource definition structure
class HarvestableResource:
	var id: String
	var name: String
	var required_tools: Array[ToolRequirement] = []
	var tool_must_be_equipped: bool = true  # Whether tool must be equipped (vs in inventory)
	var harvest_behavior: HarvestBehavior
	var stamina_cost: int = 10
	var respawn_turns: int = 0  # Only for renewable resources
	var harvest_actions: int = 1  # Number of harvest actions required (default: 1)
	var yields: Array[Dictionary] = []
	var replacement_tile: String = ""
	var harvest_message: String = ""
	var progress_message: String = ""  # Message shown during multi-turn harvesting

	func _init(data: Dictionary):
		id = data.get("id", "")
		name = data.get("name", "")
		# Parse required_tools - supports both string array and object array
		var tools_data = data.get("required_tools", [])
		for tool_data in tools_data:
			required_tools.append(ToolRequirement.new(tool_data))
		tool_must_be_equipped = data.get("tool_must_be_equipped", true)
		stamina_cost = data.get("stamina_cost", 10)
		respawn_turns = data.get("respawn_turns", 0)
		harvest_actions = data.get("harvest_actions", 1)
		yields.assign(data.get("yields", []))
		replacement_tile = data.get("replacement_tile", "")
		harvest_message = data.get("harvest_message", "Harvested %resource%")
		progress_message = data.get("progress_message", "Harvesting %resource%... (%current%/%total%)")

		# Parse harvest behavior
		var behavior_str = data.get("harvest_behavior", "destroy_permanent")
		match behavior_str:
			"destroy_permanent":
				harvest_behavior = HarvestBehavior.DESTROY_PERMANENT
			"destroy_renewable":
				harvest_behavior = HarvestBehavior.DESTROY_RENEWABLE
			"non_consumable":
				harvest_behavior = HarvestBehavior.NON_CONSUMABLE
			_:
				harvest_behavior = HarvestBehavior.DESTROY_PERMANENT

# Respawn tracking for renewable resources
class RenewableResourceInstance:
	var map_id: String
	var position: Vector2i
	var resource_id: String
	var respawn_turn: int

	func _init(m: String, p: Vector2i, r: String, rt: int):
		map_id = m
		position = p
		resource_id = r
		respawn_turn = rt

# Harvest progress tracking for multi-turn harvesting
class HarvestProgressInstance:
	var map_id: String
	var position: Vector2i
	var resource_id: String
	var current_actions: int  # Number of harvest actions performed so far

	func _init(m: String, p: Vector2i, r: String, ca: int = 0):
		map_id = m
		position = p
		resource_id = r
		current_actions = ca

# Static data
static var _resource_definitions: Dictionary = {}
static var _renewable_resources: Array[RenewableResourceInstance] = []
# Tracks harvest progress per position - key is "map_id:x,y"
static var _harvest_progress: Dictionary = {}

# Base path for resource data
const RESOURCE_DATA_BASE_PATH: String = "res://data/resources"

# Load resource definitions from JSON files
static func load_resources() -> void:
	_resource_definitions.clear()
	_load_resources_from_folder(RESOURCE_DATA_BASE_PATH)
	print("Loaded %d harvestable resource definitions" % _resource_definitions.size())

# Recursively load resources from a folder and all subfolders
static func _load_resources_from_folder(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("HarvestSystem: Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + "/" + file_name

		if dir.current_is_dir():
			# Skip hidden folders and navigate into subfolders
			if not file_name.begins_with("."):
				_load_resources_from_folder(full_path)
		elif file_name.ends_with(".json"):
			# Load JSON file as resource data
			_load_resource_from_file(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

# Load a single resource from a JSON file
static func _load_resource_from_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("HarvestSystem: Resource file not found: %s" % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("HarvestSystem: Could not open file: %s" % path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("HarvestSystem: JSON parse error in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()
		])
		return

	var data = json.data

	# Handle single resource file
	if data is Dictionary and "id" in data:
		var resource_id = data.get("id", "")
		if resource_id != "":
			_resource_definitions[resource_id] = HarvestableResource.new(data)
		else:
			push_warning("HarvestSystem: Resource without ID in %s" % path)
	else:
		push_warning("HarvestSystem: Invalid resource format in %s" % path)

# Get resource definition by ID
static func get_resource(resource_id: String) -> HarvestableResource:
	return _resource_definitions.get(resource_id, null)

# Check if player has required tool for harvesting
# Returns: {has_tool, tool_name, tool_item, action_reduction, yield_bonus}
# Matching priority: exact item ID > specific variant ID > tool_type > template_id
static func has_required_tool(player: Player, resource: HarvestableResource) -> Dictionary:
	if resource.required_tools.is_empty():
		return {"has_tool": true, "tool_name": "hands", "tool_item": null, "action_reduction": 0, "yield_bonus": 0}

	# Get equipped items
	var equipped_items: Array[Item] = []
	if player.inventory.equipment.main_hand:
		equipped_items.append(player.inventory.equipment.main_hand)
	if player.inventory.equipment.off_hand:
		equipped_items.append(player.inventory.equipment.off_hand)

	# Get inventory items if tool doesn't need to be equipped
	var inventory_items: Array[Item] = []
	if not resource.tool_must_be_equipped:
		for item in player.inventory.items:
			inventory_items.append(item)

	# Combine all available tools
	var all_items = equipped_items + inventory_items

	# Find the best matching tool requirement for each item
	# Priority: exact ID match > tool_type/template_id match
	var best_match: Dictionary = {"has_tool": false, "tool_name": "", "tool_item": null, "action_reduction": 0, "yield_bonus": 0}
	var best_priority = -1  # Higher is better: 2=exact ID, 1=tool_type/template match

	for item in all_items:
		for tool_req in resource.required_tools:
			var tool_id = tool_req.tool_id
			var match_priority = _get_match_priority(item, tool_id)

			if match_priority > 0 and match_priority > best_priority:
				best_priority = match_priority
				best_match = {
					"has_tool": true,
					"tool_name": item.name,
					"tool_item": item,
					"action_reduction": tool_req.action_reduction,
					"yield_bonus": tool_req.yield_bonus
				}
			elif match_priority > 0 and match_priority == best_priority:
				# Same priority - prefer higher bonuses
				var total_bonus = tool_req.action_reduction + tool_req.yield_bonus
				var best_bonus = best_match.action_reduction + best_match.yield_bonus
				if total_bonus > best_bonus:
					best_match = {
						"has_tool": true,
						"tool_name": item.name,
						"tool_item": item,
						"action_reduction": tool_req.action_reduction,
						"yield_bonus": tool_req.yield_bonus
					}

	return best_match

# Get match priority for an item against a tool requirement
# Returns: 3 = exact ID match, 2 = template_id match, 1 = tool_type match, 0 = no match
static func _get_match_priority(item: Item, tool_id: String) -> int:
	# Exact ID match (highest priority - e.g., "iron_hatchet" matches "iron_hatchet")
	if item.id == tool_id:
		return 3
	# Match by template_id (e.g., "iron_hatchet" has template_id "hatchet" -> matches "hatchet")
	if item.is_templated and item.template_id == tool_id:
		return 2
	# Match by tool_type (lowest priority - e.g., "iron_hatchet" has tool_type "axe" -> matches "axe")
	if item.tool_type != "" and item.tool_type == tool_id:
		return 1
	return 0

# Check if an item matches a tool requirement
# Matches by item.id OR item.tool_type (for template-based items)
static func _item_matches_tool(item: Item, tool_id: String) -> bool:
	return _get_match_priority(item, tool_id) > 0

# Generate a unique key for tracking harvest progress at a position
static func _get_progress_key(map_id: String, pos: Vector2i) -> String:
	return "%s:%d,%d" % [map_id, pos.x, pos.y]

# Get current harvest progress at a position (returns 0 if none)
static func get_harvest_progress(map_id: String, pos: Vector2i) -> int:
	var key = _get_progress_key(map_id, pos)
	if key in _harvest_progress:
		return _harvest_progress[key].current_actions
	return 0

# Clear harvest progress at a position
static func _clear_harvest_progress(map_id: String, pos: Vector2i) -> void:
	var key = _get_progress_key(map_id, pos)
	if key in _harvest_progress:
		_harvest_progress.erase(key)

# Attempt to harvest a resource
static func harvest(player: Player, target_pos: Vector2i, resource_id: String) -> Dictionary:
	var resource = get_resource(resource_id)
	if not resource:
		return {"success": false, "message": "Unknown resource type"}

	# Check for required tool
	var tool_check = has_required_tool(player, resource)
	if not tool_check.has_tool:
		# Convert tool IDs to names for better message
		var tool_names: Array[String] = []
		for tool_req in resource.required_tools:
			var item_data = ItemManager.get_item_data(tool_req.tool_id)
			if not item_data.is_empty():
				tool_names.append(item_data.get("name", tool_req.tool_id))
			else:
				tool_names.append(tool_req.tool_id)
		var tool_list = ", ".join(tool_names)
		return {"success": false, "message": "Need a %s" % tool_list}

	# Check stamina
	if player.survival and not player.survival.consume_stamina(resource.stamina_cost):
		return {"success": false, "message": "Too tired to harvest"}

	# Handle multi-turn harvesting
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var progress_key = _get_progress_key(map_id, target_pos)
	var current_actions = 1  # This harvest attempt counts as action 1

	# Check if there's existing progress
	if progress_key in _harvest_progress:
		var progress = _harvest_progress[progress_key]
		# Verify the resource hasn't changed
		if progress.resource_id == resource_id:
			current_actions = progress.current_actions + 1
		# If resource changed, start fresh (current_actions stays at 1)

	# Calculate effective harvest actions (base - tool's action_reduction, minimum 1)
	var effective_actions = max(1, resource.harvest_actions - tool_check.action_reduction)

	# Format progress message (used for both in-progress and completion)
	var progress_msg = resource.progress_message
	progress_msg = progress_msg.replace("%resource%", resource.name)
	progress_msg = progress_msg.replace("%current%", str(current_actions))
	progress_msg = progress_msg.replace("%total%", str(effective_actions))
	progress_msg = progress_msg.replace("%tool%", tool_check.tool_name)

	# Check if we've completed all required actions
	if current_actions < effective_actions:
		# Not yet complete - update progress and return progress message
		if progress_key in _harvest_progress:
			_harvest_progress[progress_key].current_actions = current_actions
		else:
			_harvest_progress[progress_key] = HarvestProgressInstance.new(
				map_id, target_pos, resource_id, current_actions
			)

		return {"success": true, "message": progress_msg, "in_progress": true}

	# Harvest complete - clear progress tracking
	_clear_harvest_progress(map_id, target_pos)

	# Store the final progress message to display before the harvest message
	var final_progress_msg = progress_msg if effective_actions > 1 else ""

	# Store the tool used for potential consumption (e.g., waterskin_empty -> waterskin_full)
	var tool_used_item: Item = null
	if tool_check.has("tool_item"):
		tool_used_item = tool_check.tool_item

	# Generate yields
	var total_yields: Dictionary = {}  # item_id -> count
	var yield_messages: Array[String] = []
	var yield_bonus = tool_check.yield_bonus  # Bonus from preferred tool

	for yield_data in resource.yields:
		var item_id = yield_data.get("item_id", "")
		var min_count = int(yield_data.get("min_count", 1))
		var max_count = int(yield_data.get("max_count", 1))
		var chance = yield_data.get("chance", 1.0)

		# Check if we get this yield (probability)
		if randf() > chance:
			continue

		# Generate random count + tool's yield bonus
		var range_size = max_count - min_count + 1
		var count = min_count + (randi() % range_size) + yield_bonus
		if count > 0:
			if item_id in total_yields:
				total_yields[item_id] += count
			else:
				total_yields[item_id] = count

	# Handle tool consumption for resources that transform the tool (e.g., waterskin_empty -> waterskin_full)
	# For these resources, the yield IS the transformed tool, so consume the original tool
	var tool_consumed = false
	if tool_used_item and not resource.required_tools.is_empty():
		# Check if the tool used is one of the required tools (for transformation check)
		var tool_is_required = false
		for tool_req in resource.required_tools:
			if _item_matches_tool(tool_used_item, tool_req.tool_id):
				tool_is_required = true
				break
		# Check if the yield matches a transformation (e.g., yielding waterskin_full when using waterskin_empty)
		if tool_is_required:
			for item_id in total_yields:
				# If we're producing the tool back (transformation), consume the original tool
				player.inventory.remove_item(tool_used_item)
				tool_consumed = true
				break

	# Create items - add directly to inventory if tool was consumed, otherwise drop at harvest position
	for item_id in total_yields:
		var count = total_yields[item_id]
		var item = ItemManager.create_item(item_id, count)
		if item:
			if tool_consumed:
				# Add directly to inventory (tool transformation case)
				player.inventory.add_item(item)
			else:
				# Drop at harvest position (normal harvesting)
				var ground_item = GroundItem.new()
				ground_item.item = item
				ground_item.position = target_pos
				ground_item.ascii_char = item.ascii_char
				ground_item.color = item.get_color()
				MapManager.current_map.entities.append(ground_item)
			yield_messages.append("%d %s" % [count, item.name])

	# Handle tile changes based on behavior
	match resource.harvest_behavior:
		HarvestBehavior.DESTROY_PERMANENT:
			# Replace with different tile (e.g., tree -> floor)
			if resource.replacement_tile:
				var new_tile = GameTile.create(resource.replacement_tile)
				MapManager.current_map.set_tile(target_pos, new_tile)

			# TODO: Integrate with ResourceSpawner when chunk-based resource system is complete
			# ResourceSpawner.remove_resource_at(MapManager.current_map, target_pos)

		HarvestBehavior.DESTROY_RENEWABLE:
			# Replace tile and track for respawn
			if resource.replacement_tile:
				var new_tile = GameTile.create(resource.replacement_tile)
				MapManager.current_map.set_tile(target_pos, new_tile)

			# Track for respawn
			var respawn_turn = TurnManager.current_turn + resource.respawn_turns
			var renewable = RenewableResourceInstance.new(
				MapManager.current_map.map_id,
				target_pos,
				resource_id,
				respawn_turn
			)
			_renewable_resources.append(renewable)

			# TODO: Integrate with ResourceSpawner when chunk-based resource system is complete
			# var spawned_resource = ResourceSpawner.get_resource_at(MapManager.current_map, target_pos)
			# if spawned_resource:
			#	ResourceSpawner.schedule_respawn(MapManager.current_map, spawned_resource, resource.respawn_turns)

		HarvestBehavior.NON_CONSUMABLE:
			# Don't change the tile at all
			pass

	# Invalidate FOV cache if tiles were modified (transparency may have changed)
	if resource.harvest_behavior == HarvestBehavior.DESTROY_PERMANENT or resource.harvest_behavior == HarvestBehavior.DESTROY_RENEWABLE:
		FOVSystem.invalidate_cache()

	# Format message
	var yield_str = ", ".join(yield_messages) if not yield_messages.is_empty() else "nothing"
	var message = resource.harvest_message.replace("%tool%", tool_check.tool_name).replace("%yield%", yield_str).replace("%resource%", resource.name)

	# Include both the final progress message (e.g., "3/3") and the harvest message
	return {"success": true, "message": message, "progress_message": final_progress_msg}

# Check and respawn renewable resources (called each turn)
static func process_renewable_resources() -> void:
	var current_turn = TurnManager.current_turn
	var to_remove: Array[int] = []

	for i in range(_renewable_resources.size() - 1, -1, -1):
		var renewable = _renewable_resources[i]

		# Check if it's time to respawn
		if current_turn >= renewable.respawn_turn:
			# Only respawn if we're on the correct map
			if MapManager.current_map and MapManager.current_map.map_id == renewable.map_id:
				# Restore the resource tile
				var tile = GameTile.create(renewable.resource_id)
				MapManager.current_map.set_tile(renewable.position, tile)

			# Remove from tracking (respawned)
			_renewable_resources.remove_at(i)

# Serialize renewable resources for saving
static func serialize_renewable_resources() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for renewable in _renewable_resources:
		data.append({
			"map_id": renewable.map_id,
			"position": {"x": renewable.position.x, "y": renewable.position.y},
			"resource_id": renewable.resource_id,
			"respawn_turn": renewable.respawn_turn
		})
	return data

# Deserialize renewable resources from save data
static func deserialize_renewable_resources(data: Array) -> void:
	_renewable_resources.clear()
	for item_data in data:
		if typeof(item_data) != TYPE_DICTIONARY:
			continue

		var map_id = item_data.get("map_id", "")
		var pos_data = item_data.get("position", {})
		var position = Vector2i(pos_data.get("x", 0), pos_data.get("y", 0))
		var resource_id = item_data.get("resource_id", "")
		var respawn_turn = item_data.get("respawn_turn", 0)

		var renewable = RenewableResourceInstance.new(map_id, position, resource_id, respawn_turn)
		_renewable_resources.append(renewable)

# Serialize harvest progress for saving
static func serialize_harvest_progress() -> Array[Dictionary]:
	var data: Array[Dictionary] = []
	for key in _harvest_progress:
		var progress: HarvestProgressInstance = _harvest_progress[key]
		data.append({
			"map_id": progress.map_id,
			"position": {"x": progress.position.x, "y": progress.position.y},
			"resource_id": progress.resource_id,
			"current_actions": progress.current_actions
		})
	return data

# Deserialize harvest progress from save data
static func deserialize_harvest_progress(data: Array) -> void:
	_harvest_progress.clear()
	for item_data in data:
		if typeof(item_data) != TYPE_DICTIONARY:
			continue

		var map_id = item_data.get("map_id", "")
		var pos_data = item_data.get("position", {})
		var position = Vector2i(pos_data.get("x", 0), pos_data.get("y", 0))
		var resource_id = item_data.get("resource_id", "")
		var current_actions = item_data.get("current_actions", 0)

		var progress = HarvestProgressInstance.new(map_id, position, resource_id, current_actions)
		var key = _get_progress_key(map_id, position)
		_harvest_progress[key] = progress

# Clear all harvest progress (called on new game)
static func clear_harvest_progress() -> void:
	_harvest_progress.clear()
