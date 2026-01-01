extends Node
class_name HarvestSystem

# Harvest behaviors
enum HarvestBehavior {
	DESTROY_PERMANENT,  # Resource destroyed, never respawns (trees, rocks)
	DESTROY_RENEWABLE,  # Resource destroyed, respawns after time (wheat, berries)
	NON_CONSUMABLE      # Resource never consumed (water sources)
}

# Resource definition structure
class HarvestableResource:
	var id: String
	var name: String
	var required_tools: Array[String] = []
	var tool_must_be_equipped: bool = true  # Whether tool must be equipped (vs in inventory)
	var harvest_behavior: HarvestBehavior
	var stamina_cost: int = 10
	var respawn_turns: int = 0  # Only for renewable resources
	var yields: Array[Dictionary] = []
	var replacement_tile: String = ""
	var harvest_message: String = ""

	func _init(data: Dictionary):
		id = data.get("id", "")
		name = data.get("name", "")
		required_tools.assign(data.get("required_tools", []))
		tool_must_be_equipped = data.get("tool_must_be_equipped", true)
		stamina_cost = data.get("stamina_cost", 10)
		respawn_turns = data.get("respawn_turns", 0)
		yields.assign(data.get("yields", []))
		replacement_tile = data.get("replacement_tile", "")
		harvest_message = data.get("harvest_message", "Harvested %resource%")

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

# Static data
static var _resource_definitions: Dictionary = {}
static var _renewable_resources: Array[RenewableResourceInstance] = []

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
static func has_required_tool(player: Player, resource: HarvestableResource) -> Dictionary:
	if resource.required_tools.is_empty():
		return {"has_tool": true, "tool_name": "hands", "tool_item": null}

	for tool_id in resource.required_tools:
		# Check equipped items first (always valid)
		if player.inventory.equipment.main_hand and player.inventory.equipment.main_hand.id == tool_id:
			return {"has_tool": true, "tool_name": player.inventory.equipment.main_hand.name, "tool_item": player.inventory.equipment.main_hand}
		if player.inventory.equipment.off_hand and player.inventory.equipment.off_hand.id == tool_id:
			return {"has_tool": true, "tool_name": player.inventory.equipment.off_hand.name, "tool_item": player.inventory.equipment.off_hand}

		# Only check inventory if tool doesn't need to be equipped
		if not resource.tool_must_be_equipped:
			for item in player.inventory.items:
				if item.id == tool_id:
					return {"has_tool": true, "tool_name": item.name, "tool_item": item}

	return {"has_tool": false, "tool_name": "", "tool_item": null}

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
		for tool_id in resource.required_tools:
			var item_data = ItemManager.get_item_data(tool_id)
			if not item_data.is_empty():
				tool_names.append(item_data.get("name", tool_id))
			else:
				tool_names.append(tool_id)
		var tool_list = ", ".join(tool_names)
		return {"success": false, "message": "Need a %s" % tool_list}

	# Check stamina
	if player.survival and not player.survival.consume_stamina(resource.stamina_cost):
		return {"success": false, "message": "Too tired to harvest"}

	# Store the tool used for potential consumption (e.g., waterskin_empty -> waterskin_full)
	var tool_used_item: Item = null
	if tool_check.has("tool_item"):
		tool_used_item = tool_check.tool_item

	# Generate yields
	var total_yields: Dictionary = {}  # item_id -> count
	var yield_messages: Array[String] = []

	for yield_data in resource.yields:
		var item_id = yield_data.get("item_id", "")
		var min_count = int(yield_data.get("min_count", 1))
		var max_count = int(yield_data.get("max_count", 1))
		var chance = yield_data.get("chance", 1.0)

		# Check if we get this yield (probability)
		if randf() > chance:
			continue

		# Generate random count
		var range_size = max_count - min_count + 1
		var count = min_count + (randi() % range_size)
		if count > 0:
			if item_id in total_yields:
				total_yields[item_id] += count
			else:
				total_yields[item_id] = count

	# Handle tool consumption for resources that transform the tool (e.g., waterskin_empty -> waterskin_full)
	# For these resources, the yield IS the transformed tool, so consume the original tool
	var tool_consumed = false
	if tool_used_item and not resource.required_tools.is_empty():
		# Check if the yield matches a transformation (e.g., yielding waterskin_full when using waterskin_empty)
		for item_id in total_yields:
			# If we're producing the tool back (transformation), consume the original tool
			if tool_used_item.id in resource.required_tools:
				# Remove the consumed tool from inventory
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

			# Remove from ResourceSpawner tracking
			ResourceSpawner.remove_resource_at(MapManager.current_map, target_pos)

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

			# Also update ResourceSpawner for renewable resources
			var spawned_resource = ResourceSpawner.get_resource_at(MapManager.current_map, target_pos)
			if spawned_resource:
				ResourceSpawner.schedule_respawn(MapManager.current_map, spawned_resource, resource.respawn_turns)

		HarvestBehavior.NON_CONSUMABLE:
			# Don't change the tile at all
			pass

	# Format message
	var yield_str = ", ".join(yield_messages) if not yield_messages.is_empty() else "nothing"
	var message = resource.harvest_message.replace("%tool%", tool_check.tool_name).replace("%yield%", yield_str)

	return {"success": true, "message": message}

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
