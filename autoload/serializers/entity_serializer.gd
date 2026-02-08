class_name EntitySerializer
extends RefCounted

## EntitySerializer - Handles entity (NPC/Enemy) serialization
##
## Extracted from SaveManager to separate entity serialization concerns.


## Serialize all entities (NPCs and enemies)
static func serialize_all(entities: Array) -> Dictionary:
	var npcs = []
	var enemies = []

	for entity in entities:
		if entity is NPC:
			npcs.append(_serialize_npc(entity))
		elif entity is Enemy:
			enemies.append(_serialize_enemy(entity))

	return {
		"npcs": npcs,
		"enemies": enemies,
		"dead_enemies": {}  # Future: track dead enemies with loot
	}


## Deserialize all entities (NPCs and enemies)
static func deserialize_all(entities_data: Dictionary) -> void:
	# Clear current NPCs and Enemies (they'll be respawned from save)
	var entities_to_remove = []
	for entity in EntityManager.entities:
		if entity is NPC or entity is Enemy:
			entities_to_remove.append(entity)

	for entity in entities_to_remove:
		EntityManager.entities.erase(entity)
		if MapManager.current_map:
			MapManager.current_map.entities.erase(entity)

	# Restore NPC states from save
	for npc_data in entities_data.npcs:
		# Convert position dictionary to Vector2i
		var spawn_data = npc_data.duplicate()
		var pos_dict = npc_data.position
		spawn_data.position = Vector2i(pos_dict.x, pos_dict.y)

		var npc = EntityManager.spawn_npc(spawn_data)

		# Restore saved state
		npc.gold = npc_data.gold
		npc.last_restock_turn = npc_data.last_restock_turn

		# Restore trade inventory
		npc.trade_inventory.clear()
		for item_data in npc_data.inventory:
			npc.trade_inventory.append(item_data.duplicate())

	# Restore Enemy states from save
	if entities_data.has("enemies"):
		for enemy_data in entities_data.enemies:
			# Spawn enemy at saved position
			var pos = Vector2i(enemy_data.position.x, enemy_data.position.y)
			var enemy = EntityManager.spawn_enemy(enemy_data.enemy_id, pos)

			if enemy:
				# Restore saved state
				enemy.current_health = enemy_data.current_health
				enemy.max_health = enemy_data.max_health
				enemy.is_aggressive = enemy_data.is_aggressive
				enemy.is_alerted = enemy_data.is_alerted
				enemy.target_position = Vector2i(enemy_data.target_position.x, enemy_data.target_position.y)
				enemy.last_known_player_pos = Vector2i(enemy_data.last_known_player_pos.x, enemy_data.last_known_player_pos.y)

	print("EntitySerializer: Entities deserialized")


## Serialize a single NPC
static func _serialize_npc(npc) -> Dictionary:
	return {
		"npc_id": npc.entity_id,
		"npc_type": npc.npc_type,
		"position": {"x": npc.position.x, "y": npc.position.y},
		"name": npc.name,
		"gold": npc.gold,
		"last_restock_turn": npc.last_restock_turn,
		"inventory": _serialize_npc_inventory(npc.trade_inventory)
	}


## Serialize NPC trade inventory
static func _serialize_npc_inventory(trade_inventory: Array) -> Array:
	var inventory = []
	for item_data in trade_inventory:
		inventory.append({
			"item_id": item_data.item_id,
			"count": item_data.count,
			"base_price": item_data.base_price
		})
	return inventory


## Serialize a single Enemy
static func _serialize_enemy(enemy: Enemy) -> Dictionary:
	return {
		"enemy_id": enemy.entity_id,
		"position": {"x": enemy.position.x, "y": enemy.position.y},
		"current_health": enemy.current_health,
		"max_health": enemy.max_health,
		"is_aggressive": enemy.is_aggressive,
		"is_alerted": enemy.is_alerted,
		"target_position": {"x": enemy.target_position.x, "y": enemy.target_position.y},
		"last_known_player_pos": {"x": enemy.last_known_player_pos.x, "y": enemy.last_known_player_pos.y}
	}
