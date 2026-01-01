class_name ResourceSpawner

## ResourceSpawner - Procedurally spawn harvestable resources based on biome
##
## Spawns trees, rocks, and other resources with density determined by biome type.
## Resources are stored as metadata on the map for dynamic loading/unloading.

## ResourceInstance - Represents a spawned resource in the world
class ResourceInstance:
	var resource_id: String  # "tree", "rock", "iron_ore", etc.
	var position: Vector2i  # World position
	var chunk_coords: Vector2i  # Parent chunk coordinates (for future chunking)
	var despawn_turn: int  # For renewable resources (0 = permanent)
	var is_active: bool  # Currently loaded/rendered

	func _init(id: String, pos: Vector2i, chunk: Vector2i = Vector2i.ZERO, turns: int = 0) -> void:
		resource_id = id
		position = pos
		chunk_coords = chunk
		despawn_turn = turns
		is_active = true

	## Serialize to dictionary for saving
	func to_dict() -> Dictionary:
		return {
			"resource_id": resource_id,
			"position": [position.x, position.y],
			"chunk_coords": [chunk_coords.x, chunk_coords.y],
			"despawn_turn": despawn_turn,
			"is_active": is_active
		}

	## Deserialize from dictionary
	static func from_dict(data: Dictionary) -> ResourceInstance:
		var pos_array = data.get("position", [0, 0])
		var chunk_array = data.get("chunk_coords", [0, 0])
		var instance = ResourceInstance.new(
			data.get("resource_id", ""),
			Vector2i(pos_array[0], pos_array[1]),
			Vector2i(chunk_array[0], chunk_array[1]),
			data.get("despawn_turn", 0)
		)
		instance.is_active = data.get("is_active", true)
		return instance

## Spawn resources across entire map based on biome densities
static func spawn_resources(map: GameMap, seed_value: int) -> void:
	print("[ResourceSpawner] Spawning resources for map: %s" % map.map_id)

	var resources: Array[ResourceInstance] = []
	var rng = SeededRandom.new(seed_value + 5000)  # Different seed offset for resources

	# Iterate through all tiles and spawn resources based on biome
	for y in range(map.height):
		for x in range(map.width):
			var pos = Vector2i(x, y)
			var tile = map.get_tile(pos)

			# Only spawn resources on walkable floor tiles
			if not tile.walkable or tile.tile_type != "floor":
				continue

			# Get biome at this position
			var biome = BiomeGenerator.get_biome_at(x, y, seed_value)

			# Try to spawn tree based on biome density
			if rng.randf() < biome.tree_density:
				var chunk_coords = Vector2i(x / 32, y / 32)  # Calculate chunk for future use
				resources.append(ResourceInstance.new("tree", pos, chunk_coords))

				# Mark tile as non-walkable (tree blocks movement)
				tile.walkable = false
				tile.transparent = false
				tile.ascii_char = "T"
				tile.harvestable_resource_id = "tree"
				continue  # Don't spawn rock in same spot

			# Try to spawn rock based on biome density
			if rng.randf() < biome.rock_density:
				var chunk_coords = Vector2i(x / 32, y / 32)
				resources.append(ResourceInstance.new("rock", pos, chunk_coords))

				# Mark tile as non-walkable (rock blocks movement)
				tile.walkable = false
				tile.transparent = false
				tile.ascii_char = "◆"
				tile.harvestable_resource_id = "rock"

	# Store resources in map metadata
	map.set_meta("resources", resources)
	print("[ResourceSpawner] Spawned %d resources" % resources.size())

## Get resource at specific position
static func get_resource_at(map: GameMap, position: Vector2i) -> ResourceInstance:
	if not map.has_meta("resources"):
		return null

	var resources: Array = map.get_meta("resources")
	for resource in resources:
		if resource is ResourceInstance and resource.position == position:
			return resource

	return null

## Remove resource at position (when harvested)
static func remove_resource_at(map: GameMap, position: Vector2i) -> bool:
	if not map.has_meta("resources"):
		return false

	var resources: Array = map.get_meta("resources")
	for i in range(resources.size()):
		var resource = resources[i]
		if resource is ResourceInstance and resource.position == position:
			resources.remove_at(i)
			map.set_meta("resources", resources)
			return true

	return false

## Add renewable resource to respawn tracking
static func schedule_respawn(map: GameMap, resource: ResourceInstance, respawn_turns: int) -> void:
	resource.despawn_turn = TurnManager.current_turn + respawn_turns
	resource.is_active = false

	# Keep resource in array but mark as inactive
	# It will respawn when despawn_turn is reached

## Process renewable resource respawns (called by TurnManager)
static func process_respawns(map: GameMap) -> void:
	if not map.has_meta("resources"):
		return

	var resources: Array = map.get_meta("resources")
	var current_turn = TurnManager.current_turn

	for resource in resources:
		if resource is ResourceInstance and not resource.is_active:
			if current_turn >= resource.despawn_turn:
				# Respawn this resource
				resource.is_active = true

				# Re-mark tile as non-walkable
				var tile = map.get_tile(resource.position)
				if tile:
					tile.walkable = false
					tile.transparent = false
					if resource.resource_id == "tree":
						tile.ascii_char = "T"
					elif resource.resource_id == "rock":
						tile.ascii_char = "◆"
					tile.harvestable_resource_id = resource.resource_id

				print("[ResourceSpawner] Respawned %s at %v" % [resource.resource_id, resource.position])
