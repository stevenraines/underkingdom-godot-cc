class_name StructurePlacement
extends RefCounted

## StructurePlacement - Handles validation and placement of structures
##
## Validates placement positions and consumes resources from player inventory.

## Check if a structure can be placed at the given position
## Returns: {valid: bool, reason: String}
static func can_place_structure(structure_id: String, pos: Vector2i, player: Player, current_map: GameMap) -> Dictionary:
	var result = {
		"valid": false,
		"reason": ""
	}

	# Get structure definition
	if not StructureManager.structure_definitions.has(structure_id):
		result.reason = "Unknown structure type"
		return result

	var structure_data = StructureManager.structure_definitions[structure_id]

	# Cannot place in dungeons (only overworld)
	if current_map.map_id.begins_with("dungeon_"):
		result.reason = "Cannot build structures in dungeons"
		return result

	# Cannot build while enemies are nearby
	if _are_enemies_nearby(player.position):
		result.reason = "Cannot build while enemies are nearby"
		return result

	# Player must be adjacent to placement position (within 1 tile, including diagonals)
	var dx = abs(pos.x - player.position.x)
	var dy = abs(pos.y - player.position.y)
	var distance = max(dx, dy)  # Chebyshev distance (allows diagonals)
	if distance > 1:
		result.reason = "Too far away to build here"
		return result

	# Check if position is walkable
	var tile = current_map.get_tile(pos)
	if not tile or not tile.walkable:
		result.reason = "Cannot build on unwalkable terrain"
		return result

	# If structure blocks movement, check for entities at position
	var blocks_movement = structure_data.get("blocks_movement", false)
	if blocks_movement:
		# Check for blocking entities
		for entity in EntityManager.entities:
			if entity.position == pos and entity.blocks_movement and entity.is_alive:
				result.reason = "Position is blocked"
				return result

		# Check for existing structures
		var existing = StructureManager.get_structures_at(pos, current_map.map_id)
		for structure in existing:
			if structure.blocks_movement:
				result.reason = "Another structure is already here"
				return result

	# Check if player has required materials
	var build_reqs = structure_data.get("build_requirements", [])
	for req in build_reqs:
		var item_id = req.get("item", "")
		var count = req.get("count", 1)

		if player.inventory.get_item_count(item_id) < count:
			result.reason = "Missing materials: %s x%d" % [item_id, count]
			return result

	# Check if player has required tool
	var build_tool = structure_data.get("build_tool", "")
	if build_tool != "":
		var has_tool = false

		# Check if tool is equipped or in inventory
		for item in player.inventory.items:
			if item.item_type == "tool" and item.subtype == build_tool:
				has_tool = true
				break

		# Check equipped items
		if not has_tool:
			for slot in player.inventory.equipment:
				var equipped = player.inventory.equipment[slot]
				if equipped and equipped.item_type == "tool" and equipped.subtype == build_tool:
					has_tool = true
					break

		# Also check if we have the actual item with the tool name
		if not has_tool and player.inventory.get_item_count(build_tool) > 0:
			has_tool = true

		if not has_tool:
			result.reason = "Requires tool: %s" % build_tool
			return result

	# All checks passed
	result.valid = true
	result.reason = "Can place structure"
	return result

## Place a structure on the map
## Returns: {success: bool, structure: Structure, message: String}
static func place_structure(structure_id: String, pos: Vector2i, player: Player, current_map: GameMap) -> Dictionary:
	var result = {
		"success": false,
		"structure": null,
		"message": ""
	}

	# Validate placement
	var validation = can_place_structure(structure_id, pos, player, current_map)
	if not validation.valid:
		result.message = validation.reason
		return result

	# Get structure definition
	var structure_data = StructureManager.structure_definitions[structure_id]

	# Consume materials from player inventory
	var build_reqs = structure_data.get("build_requirements", [])
	for req in build_reqs:
		var item_id = req.get("item", "")
		var count = req.get("count", 1)

		if not player.inventory.remove_item_by_id(item_id, count):
			result.message = "Failed to consume materials: %s" % item_id
			push_error("StructurePlacement: Failed to remove %s x%d from player inventory" % [item_id, count])
			return result

	# Create structure instance
	var structure = StructureManager.create_structure(structure_id, pos)
	if not structure:
		result.message = "Failed to create structure"
		return result

	# Add to StructureManager
	StructureManager.place_structure(current_map.map_id, structure)

	# Success
	result.success = true
	result.structure = structure
	result.message = "Built %s" % structure.name

	EventBus.inventory_changed.emit()
	EventBus.structure_placed.emit(structure)

	return result

## Remove a structure (future: for demolition)
static func remove_structure(structure: Structure, current_map: GameMap) -> bool:
	StructureManager.remove_structure(current_map.map_id, structure)
	return true

## Check if there are enemies nearby (within specified range)
## Returns true if enemies are too close to build safely
static func _are_enemies_nearby(player_pos: Vector2i, danger_range: int = 5) -> bool:
	for entity in EntityManager.entities:
		if entity is Enemy and entity.is_alive:
			var distance = abs(entity.position.x - player_pos.x) + abs(entity.position.y - player_pos.y)
			if distance <= danger_range:
				return true
	return false
