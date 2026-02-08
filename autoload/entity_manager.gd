extends Node

## EntityManager - Manages all entities in the game
##
## Keeps track of all entities (enemies, NPCs, items), handles spawning,
## and coordinates entity updates during turns.

const ChunkManagerClass = preload("res://autoload/chunk_manager.gd")
const ChunkCleanupHelper = preload("res://autoload/chunk_cleanup_helper.gd")

# All active entities (excluding player)
var entities: Array[Entity] = []

# Enemy definitions cache
var enemy_definitions: Dictionary = {}

# Base path for enemy data
const ENEMY_DATA_BASE_PATH: String = "res://data/enemies"

# Player reference (set by game scene)
var player: Player = null

# Turn processing snapshots (for chunk freeze safety)
var _entity_snapshot: Array[Entity] = []
var _active_chunks_snapshot: Dictionary = {}

func _ready() -> void:
	print("EntityManager initialized")
	_load_enemy_definitions()

	# Connect to chunk unload signal to clean up entities from unloaded chunks
	EventBus.chunk_unloaded.connect(_on_chunk_unloaded)

## Load all enemy definitions by recursively scanning folders
func _load_enemy_definitions() -> void:
	var files = JsonHelper.load_all_from_directory(ENEMY_DATA_BASE_PATH)
	for file_entry in files:
		_process_enemy_data(file_entry.path, file_entry.data)
	#print("EntityManager: Loaded %d enemy definitions" % enemy_definitions.size())


## Process loaded enemy data (handles both single and multi-enemy formats)
func _process_enemy_data(file_path: String, data) -> void:
	# Handle single enemy file (new format with "id" field)
	if data is Dictionary and "id" in data:
		var enemy_id = data.get("id", "")
		if enemy_id != "":
			enemy_definitions[enemy_id] = data
			print("Loaded enemy definition: ", enemy_id)
		else:
			push_warning("EntityManager: Enemy without ID in %s" % file_path)
	# Handle old multi-enemy format for backwards compatibility
	elif data is Dictionary and "enemies" in data:
		for enemy_data in data["enemies"]:
			var enemy_id = enemy_data.get("id", "")
			if enemy_id != "":
				enemy_definitions[enemy_id] = enemy_data
				print("Loaded enemy definition: ", enemy_id)
			else:
				push_warning("EntityManager: Enemy without ID in %s" % file_path)
	else:
		push_warning("EntityManager: Invalid enemy format in %s" % file_path)

## Check if an enemy ID exists
func has_enemy_definition(enemy_id: String) -> bool:
	return enemy_id in enemy_definitions

## Get enemy definition data by ID
func get_enemy_definition(enemy_id: String) -> Dictionary:
	return enemy_definitions.get(enemy_id, {})

## Get all enemy IDs
func get_all_enemy_ids() -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_definitions:
		result.append(enemy_id)
	return result

## Get all enemy IDs with a specific behavior type
func get_enemies_by_behavior(behavior: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_definitions:
		if enemy_definitions[enemy_id].get("behavior", "") == behavior:
			result.append(enemy_id)
	return result

## Get all enemy IDs that can spawn in a specific biome
## Only returns enemies with non-zero spawn_density_overworld
func get_enemies_for_biome(biome_id: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_definitions:
		var def = enemy_definitions[enemy_id]
		var spawn_biomes: Array = def.get("spawn_biomes", [])
		var spawn_density = def.get("spawn_density_overworld", 0)
		# Enemy can spawn if biome is in its spawn_biomes list and it has overworld spawn density
		if spawn_density > 0 and biome_id in spawn_biomes:
			result.append(enemy_id)
	return result

## Get all enemy IDs that can spawn in a specific dungeon type
## Only returns enemies with non-zero spawn_density_dungeon
func get_enemies_for_dungeon(dungeon_type: String) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_definitions:
		var def = enemy_definitions[enemy_id]
		var spawn_dungeons: Array = def.get("spawn_dungeons", [])
		var spawn_density = def.get("spawn_density_dungeon", 0)
		# Enemy can spawn if dungeon is in its spawn_dungeons list and it has dungeon spawn density
		if spawn_density > 0 and dungeon_type in spawn_dungeons:
			result.append(enemy_id)
	return result

## Get enemies valid for a specific dungeon type AND floor level (CR filtering)
## Uses min_spawn_level and max_spawn_level to filter by floor depth
func get_enemies_for_dungeon_floor(dungeon_type: String, floor_number: int) -> Array[String]:
	var result: Array[String] = []
	for enemy_id in enemy_definitions:
		var def = enemy_definitions[enemy_id]
		var spawn_dungeons: Array = def.get("spawn_dungeons", [])
		var spawn_density = def.get("spawn_density_dungeon", 0)
		var min_level = def.get("min_spawn_level", 1)
		var max_level = def.get("max_spawn_level", 999)

		# Check dungeon type, spawn density, and floor level range
		if spawn_density > 0 and dungeon_type in spawn_dungeons:
			if floor_number >= min_level and floor_number <= max_level:
				result.append(enemy_id)
	return result

## Get weighted enemy selection for spawning (considers spawn_density)
## Returns array of {enemy_id, weight} dictionaries
func get_weighted_enemies_for_dungeon_floor(dungeon_type: String, floor_number: int) -> Array:
	var result: Array = []
	var valid_enemies = get_enemies_for_dungeon_floor(dungeon_type, floor_number)

	for enemy_id in valid_enemies:
		var def = enemy_definitions[enemy_id]
		var spawn_density = def.get("spawn_density_dungeon", 100)
		# Lower density = more common (density is tiles per enemy)
		# So we invert it: weight = 1000 / density
		var weight = 1000.0 / max(spawn_density, 1)
		result.append({"enemy_id": enemy_id, "weight": weight})

	return result

## Get weighted enemy selection for overworld biome spawning
## Returns array of {enemy_id, weight, min_distance_from_town} dictionaries
func get_weighted_enemies_for_biome(biome_id: String) -> Array:
	var result: Array = []
	var valid_enemies = get_enemies_for_biome(biome_id)

	for enemy_id in valid_enemies:
		var def = enemy_definitions[enemy_id]
		var spawn_density = def.get("spawn_density_overworld", 100)
		var min_distance = def.get("min_distance_from_town", 0)
		# Lower density = more common
		var weight = 1000.0 / max(spawn_density, 1)
		result.append({
			"enemy_id": enemy_id,
			"weight": weight,
			"min_distance_from_town": min_distance
		})

	return result

## Spawn an enemy at a position
## Optional source_chunk parameter tracks which chunk spawned this enemy for cleanup
## Returns null if position is already occupied by another blocking entity
func spawn_enemy(enemy_id: String, pos: Vector2i, source_chunk: Vector2i = Vector2i(-999, -999)) -> Enemy:
	if not enemy_id in enemy_definitions:
		push_error("Unknown enemy ID: " + enemy_id)
		return null

	# Prevent spawning on occupied tiles
	if get_blocking_entity_at(pos):
		push_warning("[EntityManager] Cannot spawn %s at %v - position occupied" % [enemy_id, pos])
		return null

	var enemy = Enemy.create(enemy_definitions[enemy_id])
	enemy.position = pos
	enemy.source_chunk = source_chunk  # Track which chunk spawned this enemy

	entities.append(enemy)

	# Add to current map's entity list
	if MapManager.current_map:
		MapManager.current_map.entities.append(enemy)

	print("Spawned %s at %s" % [enemy.name, pos])
	return enemy

## Remove an entity (when it dies or is removed)
func remove_entity(entity: Entity) -> void:
	entities.erase(entity)

	if MapManager.current_map:
		MapManager.current_map.entities.erase(entity)

## Get all entities at a position
func get_entities_at(pos: Vector2i) -> Array[Entity]:
	var result: Array[Entity] = []

	for entity in entities:
		if entity.position == pos and entity.is_alive:
			result.append(entity)

	return result

## Get ground items at a position
func get_ground_items_at(pos: Vector2i) -> Array[GroundItem]:
	var result: Array[GroundItem] = []

	for entity in entities:
		if entity.position == pos and entity is GroundItem:
			result.append(entity as GroundItem)

	if result.size() > 0:
		print("[EntityManager] Found %d ground items at %v" % [result.size(), pos])
	
	return result

## Spawn a ground item at a position
func spawn_ground_item(item: Item, pos: Vector2i, despawn_turns: int = -1) -> GroundItem:
	var ground_item = GroundItem.create(item, pos, despawn_turns)
	entities.append(ground_item)

	if MapManager.current_map:
		MapManager.current_map.entities.append(ground_item)
	
	print("[EntityManager] Spawned ground item '%s' at %v (chunk-based: %s)" % [
		item.name if item else "Unknown",
		pos,
		MapManager.current_map.chunk_based if MapManager.current_map else "N/A"
	])

	return ground_item

## Spawn an NPC from spawn data
## spawn_data should contain: npc_id, position
## If npc_id matches an NPCManager definition, use that; otherwise use legacy spawn_data fields
func spawn_npc(spawn_data: Dictionary):
	var NPCClassRef = load("res://entities/npc.gd")
	var npc_id = spawn_data.get("npc_id", "npc")
	var position = JsonHelper.parse_vector2i(spawn_data.get("position", Vector2i.ZERO))

	# Check for duplicate NPC by ID - prevent double spawning
	for entity in entities:
		if entity is NPC and entity.entity_id == npc_id:
			# NPC already exists with this ID, skip spawning
			return entity

	# Try to get NPC definition from NPCManager
	var npc_def = NPCManager.get_npc_definition(npc_id)

	var npc: NPC
	if not npc_def.is_empty():
		# Use data-driven NPC definition
		npc = NPCClassRef.new(
			npc_id,
			position,
			npc_def.get("ascii_char", "@"),
			Color.html(npc_def.get("ascii_color", "#FFAA00")),
			true
		)
		npc.entity_type = "npc"
		npc.npc_type = npc_def.get("npc_type", "generic")
		npc.name = npc_def.get("name", npc_id)
		npc.gold = npc_def.get("gold", 0)
		npc.restock_interval = npc_def.get("restock_interval", 500)
		npc.last_restock_turn = 0
		npc.faction = npc_def.get("faction", "neutral")

		# Load dialogue from definition
		npc.dialogue = npc_def.get("dialogue", {}).duplicate()

		# Load trade inventory from definition (for any NPC that can trade)
		var trade_inv = npc_def.get("trade_inventory", [])
		npc.trade_inventory = []
		for item_data in trade_inv:
			npc.trade_inventory.append(item_data.duplicate())

		# Load recipes for sale from definition (for trainer NPCs)
		var recipes = npc_def.get("recipes_for_sale", [])
		npc.recipes_for_sale = []
		for recipe_data in recipes:
			npc.recipes_for_sale.append(recipe_data.duplicate())

		#print("[EntityManager] Spawned data-driven NPC: %s (%s) at %v" % [npc.name, npc_id, position])
	else:
		# Legacy fallback: use spawn_data fields directly
		npc = NPCClassRef.new(
			npc_id,
			position,
			"@",
			Color("#FFAA00"),
			true
		)
		npc.entity_type = "npc"
		npc.npc_type = spawn_data.get("npc_type", "generic")
		npc.name = spawn_data.get("name", "NPC")
		npc.gold = spawn_data.get("gold", 0)
		npc.restock_interval = spawn_data.get("restock_interval", 500)
		npc.last_restock_turn = 0

		# Set dialogue for shop NPCs
		if npc.npc_type == "shop":
			npc.dialogue = {
				"greeting": "Welcome to my shop, traveler! I have supplies for your journey.",
				"buy": "Take a look at my wares. Fair prices, I assure you!",
				"sell": "Let me see what you have. I'll pay a fair price.",
				"farewell": "Safe travels, friend! Watch out for those barrows..."
			}
			npc.load_shop_inventory()

		#print("[EntityManager] Spawned legacy NPC: %s at %v" % [npc.name, position])

	entities.append(npc)

	if MapManager.current_map:
		MapManager.current_map.entities.append(npc)

	return npc

## Get entity blocking movement at position (returns first blocking entity)
func get_blocking_entity_at(pos: Vector2i) -> Entity:
	for entity in entities:
		if entity.position == pos and entity.blocks_movement and entity.is_alive:
			return entity

	return null

## Prepare snapshot for turn processing (called before chunk operations freeze)
func prepare_turn_snapshot() -> void:
	_entity_snapshot = entities.duplicate()
	_active_chunks_snapshot = {}
	for coords in ChunkManager.get_active_chunk_coords():
		_active_chunks_snapshot[coords] = true
	#print("[EntityManager] Snapshot prepared: %d entities, %d active chunks" % [_entity_snapshot.size(), _active_chunks_snapshot.size()])

## Check if chunk is in snapshot (O(1) lookup)
func _is_chunk_active_snapshot(chunk_coords: Vector2i) -> bool:
	return chunk_coords in _active_chunks_snapshot

## Maximum distance from player to process enemy AI (performance optimization)
## Enemies beyond this range don't take turns - they're effectively "frozen"
const ENEMY_PROCESS_RANGE: int = 20

## Process all entity turns (CONSOLIDATED: DoTs + Effects + Turns in single loop)
func process_entity_turns() -> void:
	var start_time = Time.get_ticks_msec()
	var player_pos = player.position if player else Vector2i.ZERO
	var turn = TurnManager.current_turn if TurnManager else 0

	# Minimal logging - only when debugging is needed
	if turn % 10 == 0:  # Log every 10 turns instead of every turn
		#print("[EntityManager] Turn %d: %d entities in snapshot" % [turn, _entity_snapshot.size()])
		pass

	# CRITICAL: If player is dead at start of turn, stop processing immediately
	if player and not player.is_alive:
		#print("[EntityManager] PLAYER IS DEAD at turn start - Stopping entity turn processing")
		ChunkManager.emergency_unfreeze()
		return

	# First, process player's summons (process ALL effects inline)
	if player:
		#print("[EntityManager] Processing %d player summons..." % player.active_summons.size())
		for summon in player.active_summons.duplicate():
			if not summon.is_alive:
				continue

			# Tick duration first - may dismiss the summon
			if summon.tick_duration():
				# Process all effects for this summon inline
				if summon.has_method("process_dot_effects"):
					summon.process_dot_effects()

				if summon.has_method("process_effect_durations"):
					summon.process_effect_durations()

				# Take turn
				summon.take_turn()

			# Emergency brake
			if not player.is_alive:
				#print("[EntityManager] Player died during summon processing - stopping")
				ChunkManager.emergency_unfreeze()
				return

	# CONSOLIDATED ENTITY LOOP (DoTs + Effects + Turns in single pass)
	#print("[EntityManager] Processing %d entities from snapshot..." % _entity_snapshot.size())
	var entities_processed = 0
	var npcs_processed = 0
	var enemies_processed = 0
	var entity_index = 0
	const MAX_ENTITIES_PER_TURN: int = 1000  # Safety limit to prevent infinite loops

	for entity in _entity_snapshot:
		entity_index += 1

		# TIMEOUT SAFEGUARD: Check if processing is taking too long (10 seconds)
		var elapsed = Time.get_ticks_msec() - start_time
		if elapsed > 10000:
			push_error("[EntityManager] TIMEOUT: Entity processing exceeded 10 seconds at entity %d/%d! Forcing stop." % [entity_index, _entity_snapshot.size()])
			ChunkManager.emergency_unfreeze()
			return

		# MAX ITERATION SAFEGUARD: Prevent infinite loops
		if entity_index > MAX_ENTITIES_PER_TURN:
			push_error("[EntityManager] EMERGENCY BRAKE: Processed %d entities, exceeds max limit! Stopping." % entity_index)
			ChunkManager.emergency_unfreeze()
			return

		# EMERGENCY BRAKE: Check if player died
		if player and not player.is_alive:
			#print("[EntityManager] PLAYER DIED - Stopping entity processing at entity %d/%d" % [entity_index, _entity_snapshot.size()])
			ChunkManager.emergency_unfreeze()
			return

		# Safety check: skip dead entities (may have died during previous entity's turn)
		if not entity.is_alive:
			continue

		# Safety check: skip if removed from entities array (death during this turn)
		if entity not in entities:
			continue

		# Skip summons (already processed above)
		if "is_summon" in entity and entity.is_summon:
			continue

		# Check if entity's chunk is active (use snapshot, not live state)
		# NPCs have source_chunk = Vector2i(-999, -999) so they're persistent
		var current_chunk = ChunkManagerClass.world_to_chunk(entity.position)
		if entity.source_chunk != Vector2i(-999, -999) and not _is_chunk_active_snapshot(current_chunk):
			#print("[EntityManager] Entity '%s' at %v (chunk %v) in unloaded chunk - skipping" % [entity.name, entity.position, current_chunk])
			continue

		# Range check: Only process entities within ENEMY_PROCESS_RANGE
		var dist = abs(entity.position.x - player_pos.x) + abs(entity.position.y - player_pos.y)
		if dist > ENEMY_PROCESS_RANGE:
			continue

		# === PROCESS ALL EFFECTS FOR THIS ENTITY IN SEQUENCE ===
		# 1. DoT effects (damage over time)
		if entity.has_method("process_dot_effects"):
			entity.process_dot_effects()
			# Emergency brake: Check if player died from DoT
			if player and not player.is_alive:
				#print("[EntityManager] !!! PLAYER DIED from DoT effects - stopping entity processing !!!")
				ChunkManager.emergency_unfreeze()
				return

		# 2. Effect durations (expire effects)
		if entity.has_method("process_effect_durations"):
			entity.process_effect_durations()
			# Emergency brake: Check if player died from effect expiration
			if player and not player.is_alive:
				#print("[EntityManager] !!! PLAYER DIED from effect expiration - stopping entity processing !!!")
				ChunkManager.emergency_unfreeze()
				return

		# 3. Take turn (AI action)
		if entity is Enemy:
			entities_processed += 1
			enemies_processed += 1
			var enemy_start = Time.get_ticks_msec()
			(entity as Enemy).take_turn()
			var enemy_duration = Time.get_ticks_msec() - enemy_start

			# CRITICAL: Detect if a single enemy is taking too long (possible infinite loop)
			if enemy_duration > 1000:
				push_error("[EntityManager] !!! Enemy '%s' at %v took %dms - POSSIBLE INFINITE LOOP !!!" % [entity.name, entity.position, enemy_duration])
				ChunkManager.emergency_unfreeze()
				return

			# Check if player died from this enemy's action
			if player and not player.is_alive:
				#print("[EntityManager] !!! PLAYER DIED from enemy '%s' attack - stopping entity processing !!!" % entity.name)
				ChunkManager.emergency_unfreeze()
				return
		elif entity.has_method("process_turn"):
			entities_processed += 1
			npcs_processed += 1
			entity.process_turn()

	var total_duration = Time.get_ticks_msec() - start_time
	#print("[EntityManager] Turn %d: Processed %d entities (%d enemies, %d NPCs) in %dms" % [turn, entities_processed, enemies_processed, npcs_processed, total_duration])

	# Warn if processing took too long
	if total_duration > 5000:
		push_warning("[EntityManager] Entity processing took %dms - this is unusually long!" % total_duration)

## Clear all entities (for map transitions)
func clear_entities() -> void:
	entities.clear()
	# Also clear the current map's entity list to prevent ghost duplicates.
	# spawn_enemy() adds to both arrays, so both must be cleared together.
	if MapManager.current_map:
		MapManager.current_map.entities.clear()

## Get entities on current map
func get_current_map_entities() -> Array[Entity]:
	return entities.filter(func(e): return e.is_alive)

## Save current entity states to map metadata (for map transitions)
func save_entity_states_to_map(map: GameMap) -> void:
	if not map:
		return

	var saved_enemies: Array = []
	var saved_items: Array = []
	var saved_npcs: Array = []

	for entity in entities:
		if entity is Enemy and entity.is_alive:
			saved_enemies.append({
				"enemy_id": entity.entity_id,
				"position": entity.position,
				"current_health": entity.current_health,
				"max_health": entity.max_health
			})
		elif entity is NPC and entity.is_alive:
			saved_npcs.append({
				"npc_id": entity.entity_id,
				"name": entity.name,
				"position": entity.position,
				"npc_type": entity.npc_type,
				"ascii_char": entity.ascii_char,
				"color": entity.color.to_html(),
				"dialogue": entity.dialogue,
				"trade_inventory": entity.trade_inventory,
				"gold": entity.gold,
				"current_health": entity.current_health,
				"max_health": entity.max_health
			})
		elif entity is GroundItem:
			saved_items.append({
				"item_id": entity.item.id if entity.item else "",
				"item_count": entity.item.stack_size if entity.item else 1,
				"position": entity.position
			})

	map.metadata["saved_enemies"] = saved_enemies
	map.metadata["saved_items"] = saved_items
	map.metadata["saved_npcs"] = saved_npcs
	map.metadata["visited"] = true
	#print("EntityManager: Saved %d enemies, %d items, %d NPCs to map %s" % [saved_enemies.size(), saved_items.size(), saved_npcs.size(), map.map_id])

## Restore entity states from map metadata (for returning to visited maps)
func restore_entity_states_from_map(map: GameMap) -> bool:
	if not map:
		return false

	if not map.metadata.get("visited", false):
		return false  # Not visited before, use normal spawning

	# Restore enemies
	var saved_enemies = map.metadata.get("saved_enemies", [])
	for enemy_data in saved_enemies:
		var enemy_id = enemy_data.get("enemy_id", "")
		if enemy_id == "" or not has_enemy_definition(enemy_id):
			continue

		var enemy = spawn_enemy(enemy_id, JsonHelper.parse_vector2i(enemy_data.get("position", Vector2i.ZERO)))
		if enemy:
			enemy.current_health = enemy_data.get("current_health", enemy.max_health)

	# Restore NPCs
	var saved_npcs = map.metadata.get("saved_npcs", [])
	for npc_data in saved_npcs:
		var npc = spawn_npc(npc_data)
		if npc:
			npc.current_health = npc_data.get("current_health", npc.max_health)
			npc.gold = npc_data.get("gold", npc.gold)
			# Restore trade inventory if saved
			var saved_trade_inv = npc_data.get("trade_inventory", [])
			if saved_trade_inv.size() > 0:
				npc.trade_inventory = saved_trade_inv

	# Restore ground items
	var saved_items = map.metadata.get("saved_items", [])
	for item_data in saved_items:
		var item_id = item_data.get("item_id", "")
		if item_id == "":
			continue

		var item = ItemManager.create_item(item_id, item_data.get("item_count", 1))
		if item:
			spawn_ground_item(item, JsonHelper.parse_vector2i(item_data.get("position", Vector2i.ZERO)))

	#print("EntityManager: Restored %d enemies, %d items, %d NPCs from map %s" % [saved_enemies.size(), saved_items.size(), saved_npcs.size(), map.map_id])
	return true

## Called when a chunk is unloaded - removes entities that were spawned by that chunk
## This prevents entity accumulation as player explores the overworld
func _on_chunk_unloaded(chunk_coords: Vector2i) -> void:
	var removed = ChunkCleanupHelper.cleanup_array_by_chunk(entities, chunk_coords, "EntityManager")
	# Also remove from current map's entity list
	if MapManager.current_map and removed.size() > 0:
		for entity in removed:
			MapManager.current_map.entities.erase(entity)
