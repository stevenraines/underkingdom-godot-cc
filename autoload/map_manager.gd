extends Node

## MapManager - Manages multiple maps, handles transitions, caching
##
## Keeps track of loaded maps and provides methods for generating
## and transitioning between maps.

var loaded_maps: Dictionary = {}  # map_id -> GameMap
var current_map: GameMap = null
var current_dungeon_floor: int = 0  # Track which dungeon floor player is on (0 = overworld)
var current_dungeon_type: String = ""  # Track current dungeon type (e.g., "burial_barrow")

func _ready() -> void:
	print("MapManager initialized")

## Get or generate a map by ID
func get_or_generate_map(map_id: String, world_seed: int) -> GameMap:
	# Check cache first
	if map_id in loaded_maps:
		var cached_map = loaded_maps[map_id]
		#print("Loading cached map: %s (internal map_id=%s, tiles=%d)" % [map_id, cached_map.map_id, cached_map.tiles.size()])
		return cached_map

	# Generate new map
	var map = _generate_map(map_id, world_seed)
	#print("Generated new map: %s (internal map_id=%s, tiles=%d)" % [map_id, map.map_id, map.tiles.size()])
	loaded_maps[map_id] = map
	return map

## Transition to a different map
func transition_to_map(map_id: String) -> void:
	current_map = get_or_generate_map(map_id, GameManager.world_seed)
	GameManager.set_current_map(map_id)

	# Enable chunk mode for overworld
	if map_id == "overworld":
		current_map.chunk_based = true
		ChunkManager.enable_chunk_mode(map_id, GameManager.world_seed)
	else:
		current_map.chunk_based = false
		ChunkManager.enable_chunk_mode(map_id, GameManager.world_seed)

	# Load features and hazards into their managers for dungeon maps
	# Map IDs follow format: dungeon_id_floor_N (e.g., burial_barrow_floor_1)
	var is_dungeon = "_floor_" in map_id or current_map.metadata.has("floor_number")
	if is_dungeon:
		_load_features_and_hazards(current_map)

	EventBus.map_changed.emit(map_id)
	#print("Transitioned to map: ", map_id)


## Load features and hazards from map metadata into managers
func _load_features_and_hazards(map: GameMap) -> void:
	#print("[MapManager] Loading features/hazards for: %s" % map.map_id)
	#print("[MapManager] Map metadata keys: %s" % str(map.metadata.keys()))
	#print("[MapManager] pending_features: %d" % map.metadata.get("pending_features", []).size())
	#print("[MapManager] pending_hazards: %d" % map.metadata.get("pending_hazards", []).size())

	# Load dungeon hints from dungeon definition
	var dungeon_id: String = map.metadata.get("dungeon_id", "")
	if not dungeon_id.is_empty():
		var hints: Array = _load_dungeon_hints(dungeon_id)
		FeatureManager.set_dungeon_hints(hints)

	FeatureManager.load_features_from_map(map)
	HazardManager.load_hazards_from_map(map)
	#print("[MapManager] After loading - active_features: %d, active_hazards: %d" % [FeatureManager.active_features.size(), HazardManager.active_hazards.size()])


## Load hints from a dungeon definition file
func _load_dungeon_hints(dungeon_id: String) -> Array:
	var file_path = "res://data/dungeons/%s.json" % dungeon_id
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[MapManager] Failed to load dungeon definition: %s" % file_path)
		return []

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_warning("[MapManager] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return []

	var data: Dictionary = json.data
	return data.get("hints", [])

## Generate a map based on its ID
func _generate_map(map_id: String, world_seed: int) -> GameMap:
	if map_id == "overworld":
		# For overworld, create empty map shell - chunks generated on demand
		#print("[MapManager] Creating chunk-based overworld map")
		var map = GameMap.new("overworld", 10000, 10000, world_seed)  # Virtually infinite bounds
		map.chunk_based = true

		# Note: Terrain generation happens in ChunkManager on demand
		# Use SpecialFeaturePlacer to find suitable biome-based locations for special features

		# Clear any previously placed towns from TownManager
		TownManager.clear_placed_towns()

		# Place all towns based on town definitions
		var town_definitions = TownManager.town_definitions
		var towns = SpecialFeaturePlacer.place_all_towns(world_seed, town_definitions)

		# Get primary town position (first town, usually starter_town)
		var primary_town_pos = towns[0].position if towns.size() > 0 else Vector2i(400, 400)

		# Place all dungeon entrances based on dungeon definitions
		var dungeon_entrances = SpecialFeaturePlacer.place_all_dungeon_entrances(world_seed, primary_town_pos)

		# Get first wilderness dungeon for player spawn calculation
		var first_wilderness_entrance = Vector2i(primary_town_pos.x + 15, primary_town_pos.y)
		for entrance in dungeon_entrances:
			var dungeon_def = DungeonManager.get_dungeon(entrance.dungeon_type)
			if dungeon_def.get("placement", "wilderness") == "wilderness":
				first_wilderness_entrance = entrance.position
				break

		# Place player spawn just outside primary town (10 tiles away, opposite from first dungeon)
		var player_spawn = SpecialFeaturePlacer.place_player_spawn(primary_town_pos, first_wilderness_entrance, world_seed)

		# Store special positions in map metadata
		# ChunkManager will check these and place actual tiles when chunks load
		map.set_meta("town_center", primary_town_pos)  # Legacy compatibility
		map.set_meta("player_spawn", player_spawn)
		map.set_meta("dungeon_entrances", dungeon_entrances)

		# Store all towns in metadata for multi-town support
		map.metadata["towns"] = towns

		# Generate inter-town road paths (stored in metadata, tiles placed when chunks load)
		var road_paths = _generate_inter_town_road_paths(towns, world_seed)
		map.metadata["road_paths"] = road_paths

		# Initialize empty NPC spawns array (will be populated when town chunks generate)
		map.metadata["npc_spawns"] = []

		#print("[MapManager] Special features placed: %d towns, %d dungeons, %d road paths, spawn=%v" % [towns.size(), dungeon_entrances.size(), road_paths.size(), player_spawn])
		for town in towns:
			#print("[MapManager]   - %s at %v" % [town.name, town.position])
			pass

		return map

	elif "_floor_" in map_id:
		# Generic dungeon floor handling: dungeon_type_floor_N
		# Extract dungeon type and floor number
		var floor_idx = map_id.find("_floor_")
		var dungeon_type = map_id.substr(0, floor_idx)
		var floor_str = map_id.substr(floor_idx + 7)  # Skip "_floor_"
		var floor_number = int(floor_str)

		#print("[MapManager] Generating %s floor %d" % [dungeon_type, floor_number])

		# Use DungeonManager to generate the floor with the correct generator
		return DungeonManager.generate_floor(dungeon_type, floor_number, world_seed)
	else:
		push_error("Unknown map ID: " + map_id)
		# Return empty map as fallback
		return GameMap.new(map_id, 50, 50, world_seed)

## Enter a dungeon from its entrance
## dungeon_type: e.g., "burial_barrow", "sewers", "natural_cave"
func enter_dungeon(dungeon_type: String) -> void:
	current_dungeon_type = dungeon_type
	current_dungeon_floor = 1
	var map_id = "%s_floor_%d" % [dungeon_type, current_dungeon_floor]
	transition_to_map(map_id)

## Descend to next dungeon floor
func descend_dungeon() -> void:
	current_dungeon_floor += 1
	var map_id = "%s_floor_%d" % [current_dungeon_type, current_dungeon_floor]
	transition_to_map(map_id)

## Ascend to previous dungeon floor or overworld
func ascend_dungeon() -> void:
	current_dungeon_floor -= 1

	if current_dungeon_floor >= 1:
		var map_id = "%s_floor_%d" % [current_dungeon_type, current_dungeon_floor]
		transition_to_map(map_id)
	else:
		# Return to overworld (floor 0 or below means overworld)
		current_dungeon_floor = 0  # Reset to 0 when on overworld
		current_dungeon_type = ""  # Clear dungeon type
		transition_to_map("overworld")

## Get dungeon entrance info at a position, or null if no entrance there
func get_dungeon_entrance_at(pos: Vector2i) -> Variant:
	if not current_map:
		return null
	var entrances = current_map.get_meta("dungeon_entrances", [])
	for entrance in entrances:
		if entrance.position == pos:
			return entrance
	return null

## Clear map cache (useful for testing regeneration)
func clear_cache() -> void:
	loaded_maps.clear()
	print("Map cache cleared")


## Generate road paths between connected towns
## Returns array of road path dictionaries with positions and road types
func _generate_inter_town_road_paths(towns: Array, world_seed: int) -> Array:
	var road_paths: Array = []

	# Filter towns that want road connections
	var connected_towns: Array = []
	for town in towns:
		if town.get("roads_connected", false):
			connected_towns.append(town)

	if connected_towns.size() < 2:
		return road_paths

	# Track connections to avoid duplicates
	var connections_made: Array = []

	for town in connected_towns:
		var town_pos = town.get("position", Vector2i(0, 0))
		var town_id = town.get("town_id", "")

		# Find nearest 2 towns
		var nearest = _find_nearest_towns(town, connected_towns, 2)

		for other_town in nearest:
			var other_id = other_town.get("town_id", "")

			# Check if connection already made
			var connection_key = [town_id, other_id]
			connection_key.sort()
			if connection_key in connections_made:
				continue

			connections_made.append(connection_key)

			# Generate road path
			var other_pos = other_town.get("position", Vector2i(0, 0))
			var path = _generate_road_path_between_towns(town_pos, other_pos, world_seed)
			road_paths.append(path)

	#print("[MapManager] Generated %d inter-town road paths" % road_paths.size())
	return road_paths


## Find the N nearest towns to a given town
func _find_nearest_towns(town: Dictionary, all_towns: Array, count: int) -> Array:
	var town_pos = town.get("position", Vector2i(0, 0))
	var town_id = town.get("town_id", "")

	var distances: Array = []
	for other in all_towns:
		var other_id = other.get("town_id", "")
		if other_id == town_id:
			continue

		var other_pos = other.get("position", Vector2i(0, 0))
		var dist = (other_pos - town_pos).length()
		distances.append({"town": other, "distance": dist})

	# Sort by distance
	distances.sort_custom(func(a, b): return a.distance < b.distance)

	# Return top N
	var result: Array = []
	for i in range(min(count, distances.size())):
		result.append(distances[i].town)

	return result


## Generate a road path between two towns with material transitions
## Returns dictionary with path points and their road types
## Roads are 2 tiles wide for better visibility and traversal
func _generate_road_path_between_towns(from_pos: Vector2i, to_pos: Vector2i, world_seed: int) -> Dictionary:
	var rng = SeededRandom.new(world_seed + from_pos.x * 1000 + from_pos.y + to_pos.x * 100 + to_pos.y)

	var total_dist = (to_pos - from_pos).length()

	# Transition thresholds
	var cobblestone_threshold = 0.15
	var gravel_threshold = 0.30

	# Generate meandering center path
	var center_path = _generate_meandering_path(from_pos, to_pos, rng, total_dist)

	# Expand path to 2 tiles wide by adding perpendicular neighbor
	var path_data: Array = []
	var added_positions: Dictionary = {}  # Track positions to avoid duplicates

	for i in range(center_path.size()):
		var pos = center_path[i]

		# Calculate perpendicular direction based on path direction
		var perpendicular: Vector2i
		if i < center_path.size() - 1:
			var next_pos = center_path[i + 1]
			var direction = Vector2(next_pos - pos).normalized()
			# Perpendicular is 90 degrees rotated
			perpendicular = Vector2i(int(-direction.y), int(direction.x))
			if perpendicular == Vector2i.ZERO:
				perpendicular = Vector2i(1, 0)  # Default if direction is zero
		elif i > 0:
			var prev_pos = center_path[i - 1]
			var direction = Vector2(pos - prev_pos).normalized()
			perpendicular = Vector2i(int(-direction.y), int(direction.x))
			if perpendicular == Vector2i.ZERO:
				perpendicular = Vector2i(1, 0)
		else:
			perpendicular = Vector2i(1, 0)  # Default for single point

		# Calculate road type based on distance
		var dist_from_start = (pos - from_pos).length()
		var dist_from_end = (pos - to_pos).length()
		var min_dist = min(dist_from_start, dist_from_end)
		var dist_ratio = min_dist / total_dist if total_dist > 0 else 0

		var road_type: String
		if dist_ratio < cobblestone_threshold:
			road_type = "road_cobblestone"
		elif dist_ratio < gravel_threshold:
			road_type = "road_gravel"
		else:
			road_type = "road_dirt"

		# Add center tile
		if pos not in added_positions:
			path_data.append({"pos": pos, "type": road_type})
			added_positions[pos] = true

		# Add perpendicular neighbor for 2-tile width
		var neighbor_pos = pos + perpendicular
		if neighbor_pos not in added_positions:
			path_data.append({"pos": neighbor_pos, "type": road_type})
			added_positions[neighbor_pos] = true

	return {
		"from": from_pos,
		"to": to_pos,
		"points": path_data
	}


## Generate a slightly meandering path between two points
func _generate_meandering_path(from_pos: Vector2i, to_pos: Vector2i, rng: SeededRandom, total_dist: float) -> Array[Vector2i]:
	var path: Array[Vector2i] = []

	if total_dist < 30:
		return _generate_straight_path(from_pos, to_pos)

	var num_segments = int(total_dist / 20) + 1
	var waypoints: Array[Vector2i] = [from_pos]

	for i in range(1, num_segments):
		var t = float(i) / num_segments
		var base_pos = from_pos + Vector2i(
			int((to_pos.x - from_pos.x) * t),
			int((to_pos.y - from_pos.y) * t)
		)

		var perpendicular = Vector2(-(to_pos.y - from_pos.y), to_pos.x - from_pos.x).normalized()
		var deviation = rng.randf_range(-8.0, 8.0)
		var waypoint = base_pos + Vector2i(int(perpendicular.x * deviation), int(perpendicular.y * deviation))
		waypoints.append(waypoint)

	waypoints.append(to_pos)

	for i in range(waypoints.size() - 1):
		var segment = _generate_straight_path(waypoints[i], waypoints[i + 1])
		for pos in segment:
			if pos not in path:
				path.append(pos)

	return path


## Generate a straight path between two points (Bresenham-like)
func _generate_straight_path(from_pos: Vector2i, to_pos: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = from_pos

	var dx = abs(to_pos.x - from_pos.x)
	var dy = abs(to_pos.y - from_pos.y)
	var sx = 1 if from_pos.x < to_pos.x else -1
	var sy = 1 if from_pos.y < to_pos.y else -1
	var err = dx - dy

	while true:
		path.append(current)

		if current == to_pos:
			break

		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			current.x += sx
		if e2 < dx:
			err += dx
			current.y += sy

	return path
