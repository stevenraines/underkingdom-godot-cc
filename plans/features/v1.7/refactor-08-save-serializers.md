# Refactor 08: Save Serializers

**Risk Level**: Medium
**Estimated Changes**: 4 new files, 1 file significantly reduced

---

## Goal

Extract domain-specific serialization from `save_manager.gd` (1,117 lines) into separate serializer classes:
- PlayerSerializer
- EntitySerializer
- MapSerializer
- InventorySerializer

SaveManager becomes a coordinator that orchestrates the serializers.

---

## Current State

### autoload/save_manager.gd
Contains 14+ `_serialize_*` and `_deserialize_*` method pairs:
- `_serialize_player()` / `_deserialize_player()`
- `_serialize_survival()` / `_deserialize_survival()`
- `_serialize_inventory()` / `_deserialize_inventory()`
- `_serialize_equipment()` / `_deserialize_equipment()`
- `_serialize_entities()` / `_deserialize_entities()`
- `_serialize_enemy()` / `_deserialize_enemy()`
- `_serialize_npc()` / `_deserialize_npc()`
- `_serialize_map_state()` / `_deserialize_map_state()`
- `_serialize_features()` / `_deserialize_features()`
- `_serialize_hazards()` / `_deserialize_hazards()`
- `_serialize_ground_items()` / `_deserialize_ground_items()`
- And more...

---

## Implementation

### Step 1: Create autoload/serializers/ Directory

```bash
mkdir -p autoload/serializers
```

---

### Step 2: Create autoload/serializers/player_serializer.gd

```gdscript
class_name PlayerSerializer
extends RefCounted

## PlayerSerializer - Handles player state serialization
##
## Serializes/deserializes player attributes, stats, skills, spells, rituals, etc.


## Serialize complete player state to dictionary
static func serialize(player: Player) -> Dictionary:
	if player == null:
		return {}

	return {
		"position": {"x": player.position.x, "y": player.position.y},
		"level": player.level,
		"experience": player.experience,
		"gold": player.gold,
		"hp": player.hp,
		"max_hp": player.max_hp,
		"mp": player.mp,
		"max_mp": player.max_mp,
		"stamina": player.stamina,
		"max_stamina": player.max_stamina,
		"attributes": player.attributes.duplicate(),
		"attribute_bonuses": player.attribute_bonuses.duplicate(),
		"skills": player.skills.duplicate(),
		"known_spells": player.known_spells.duplicate(),
		"known_rituals": player.known_rituals.duplicate(),
		"known_recipes": player.known_recipes.duplicate(),
		"racial_abilities": player.racial_abilities.duplicate() if player.racial_abilities else [],
		"class_feats": player.class_feats.duplicate() if player.class_feats else [],
		"race_id": player.race_id,
		"class_id": player.class_id,
		"god_mode": player.god_mode if "god_mode" in player else false,
		"death_count": player.death_count if "death_count" in player else 0,
		"survival": _serialize_survival(player),
		"active_effects": _serialize_active_effects(player),
		"concentration": _serialize_concentration(player),
		"summons": _serialize_summons(player),
	}


## Deserialize player state from dictionary
static func deserialize(player: Player, data: Dictionary) -> void:
	if player == null or data.is_empty():
		return

	# Position
	if "position" in data:
		player.position = Vector2i(data.position.x, data.position.y)

	# Core stats
	player.level = data.get("level", 1)
	player.experience = data.get("experience", 0)
	player.gold = data.get("gold", 0)
	player.hp = data.get("hp", player.max_hp)
	player.max_hp = data.get("max_hp", 100)
	player.mp = data.get("mp", player.max_mp)
	player.max_mp = data.get("max_mp", 50)
	player.stamina = data.get("stamina", player.max_stamina)
	player.max_stamina = data.get("max_stamina", 100)

	# Attributes and skills
	if "attributes" in data:
		player.attributes = data.attributes.duplicate()
	if "attribute_bonuses" in data:
		player.attribute_bonuses = data.attribute_bonuses.duplicate()
	if "skills" in data:
		player.skills = data.skills.duplicate()

	# Knowledge
	if "known_spells" in data:
		player.known_spells = data.known_spells.duplicate()
	if "known_rituals" in data:
		player.known_rituals = data.known_rituals.duplicate()
	if "known_recipes" in data:
		player.known_recipes = data.known_recipes.duplicate()

	# Race and class
	player.race_id = data.get("race_id", "")
	player.class_id = data.get("class_id", "")
	if "racial_abilities" in data:
		player.racial_abilities = data.racial_abilities.duplicate()
	if "class_feats" in data:
		player.class_feats = data.class_feats.duplicate()

	# Misc
	if "god_mode" in data:
		player.god_mode = data.god_mode
	if "death_count" in data:
		player.death_count = data.death_count

	# Survival
	if "survival" in data:
		_deserialize_survival(player, data.survival)

	# Active effects
	if "active_effects" in data:
		_deserialize_active_effects(player, data.active_effects)

	# Concentration
	if "concentration" in data:
		_deserialize_concentration(player, data.concentration)

	# Summons
	if "summons" in data:
		_deserialize_summons(player, data.summons)


## Serialize survival state
static func _serialize_survival(player: Player) -> Dictionary:
	return {
		"hunger": player.hunger if "hunger" in player else 0,
		"thirst": player.thirst if "thirst" in player else 0,
		"temperature": player.temperature if "temperature" in player else 20.0,
		"wetness": player.wetness if "wetness" in player else 0.0,
	}


## Deserialize survival state
static func _deserialize_survival(player: Player, data: Dictionary) -> void:
	if "hunger" in data and "hunger" in player:
		player.hunger = data.hunger
	if "thirst" in data and "thirst" in player:
		player.thirst = data.thirst
	if "temperature" in data and "temperature" in player:
		player.temperature = data.temperature
	if "wetness" in data and "wetness" in player:
		player.wetness = data.wetness


## Serialize active effects/buffs
static func _serialize_active_effects(player: Player) -> Array:
	var effects: Array = []
	if player.has_method("get_active_effects"):
		for effect in player.get_active_effects():
			effects.append({
				"id": effect.id,
				"duration": effect.duration,
				"strength": effect.strength if "strength" in effect else 1,
			})
	return effects


## Deserialize active effects
static func _deserialize_active_effects(player: Player, data: Array) -> void:
	if not player.has_method("add_effect"):
		return
	for effect_data in data:
		player.add_effect(effect_data.id, effect_data.get("duration", 0), effect_data.get("strength", 1))


## Serialize concentration state
static func _serialize_concentration(player: Player) -> Dictionary:
	if not "concentration_spell" in player or player.concentration_spell == null:
		return {}
	return {
		"spell_id": player.concentration_spell.id if player.concentration_spell else "",
		"target_position": {
			"x": player.concentration_target.x,
			"y": player.concentration_target.y
		} if player.concentration_target else null,
	}


## Deserialize concentration state
static func _deserialize_concentration(player: Player, data: Dictionary) -> void:
	if data.is_empty():
		return
	# Concentration is typically restored through spell re-casting on load
	# Just store the spell ID for reference
	if "spell_id" in data and data.spell_id != "":
		player._pending_concentration_restore = data


## Serialize summons
static func _serialize_summons(player: Player) -> Array:
	var summons: Array = []
	if player.has_method("get_summons"):
		for summon in player.get_summons():
			summons.append({
				"enemy_id": summon.enemy_id,
				"position": {"x": summon.position.x, "y": summon.position.y},
				"hp": summon.hp,
				"max_hp": summon.max_hp,
			})
	return summons


## Deserialize summons
static func _deserialize_summons(player: Player, data: Array) -> void:
	if not player.has_method("add_summon"):
		return
	for summon_data in data:
		var summon = EntityManager.spawn_enemy(summon_data.enemy_id, Vector2i(summon_data.position.x, summon_data.position.y))
		if summon:
			summon.hp = summon_data.get("hp", summon.max_hp)
			player.add_summon(summon)
```

---

### Step 3: Create autoload/serializers/inventory_serializer.gd

```gdscript
class_name InventorySerializer
extends RefCounted

## InventorySerializer - Handles inventory and equipment serialization


## Serialize complete inventory state
static func serialize(inventory: Inventory) -> Dictionary:
	if inventory == null:
		return {}

	return {
		"items": _serialize_items(inventory.items),
		"equipment": _serialize_equipment(inventory.equipment),
		"max_weight": inventory.max_weight,
	}


## Deserialize inventory state
static func deserialize(inventory: Inventory, data: Dictionary) -> void:
	if inventory == null or data.is_empty():
		return

	# Clear existing
	inventory.items.clear()
	for slot in inventory.equipment:
		inventory.equipment[slot] = null

	# Load items
	if "items" in data:
		for item_data in data.items:
			var item = _deserialize_item(item_data)
			if item:
				inventory.items.append(item)

	# Load equipment
	if "equipment" in data:
		for slot in data.equipment:
			var item_data = data.equipment[slot]
			if item_data:
				var item = _deserialize_item(item_data)
				if item:
					inventory.equipment[slot] = item

	# Max weight
	if "max_weight" in data:
		inventory.max_weight = data.max_weight


## Serialize array of items
static func _serialize_items(items: Array) -> Array:
	var result: Array = []
	for item in items:
		result.append(_serialize_item(item))
	return result


## Serialize single item
static func _serialize_item(item: Item) -> Dictionary:
	if item == null:
		return {}

	var data = {
		"id": item.id,
		"display_name": item.display_name,
		"item_type": item.item_type,
		"stack_count": item.stack_count,
		"identified": item.identified,
		"inscription": item.inscription if item.inscription else "",
	}

	# Equipment stats
	if item.is_equippable():
		data["damage"] = item.damage
		data["armor"] = item.armor
		data["stat_bonuses"] = item.stat_bonuses.duplicate() if item.stat_bonuses else {}

	# Consumable properties
	if item.item_type in ["consumable", "food", "potion"]:
		data["healing"] = item.healing
		data["mana_restore"] = item.mana_restore
		data["nutrition"] = item.nutrition
		data["hydration"] = item.hydration

	# Wand charges
	if item.item_type == "wand":
		data["charges"] = item.charges
		data["max_charges"] = item.max_charges
		data["spell_id"] = item.spell_id

	# Modifiers
	if item.modifiers and not item.modifiers.is_empty():
		data["modifiers"] = item.modifiers.duplicate()

	return data


## Deserialize single item
static func _deserialize_item(data: Dictionary) -> Item:
	if data.is_empty() or not "id" in data:
		return null

	var item = ItemManager.create_item(data.id)
	if item == null:
		# Try creating generic item if ID not found
		item = Item.new()
		item.id = data.id

	# Apply saved properties
	item.display_name = data.get("display_name", item.display_name)
	item.item_type = data.get("item_type", item.item_type)
	item.stack_count = data.get("stack_count", 1)
	item.identified = data.get("identified", true)
	item.inscription = data.get("inscription", "")

	# Equipment stats
	if "damage" in data:
		item.damage = data.damage
	if "armor" in data:
		item.armor = data.armor
	if "stat_bonuses" in data:
		item.stat_bonuses = data.stat_bonuses.duplicate()

	# Consumable properties
	if "healing" in data:
		item.healing = data.healing
	if "mana_restore" in data:
		item.mana_restore = data.mana_restore
	if "nutrition" in data:
		item.nutrition = data.nutrition
	if "hydration" in data:
		item.hydration = data.hydration

	# Wand
	if "charges" in data:
		item.charges = data.charges
	if "max_charges" in data:
		item.max_charges = data.max_charges
	if "spell_id" in data:
		item.spell_id = data.spell_id

	# Modifiers
	if "modifiers" in data:
		item.modifiers = data.modifiers.duplicate()

	return item


## Serialize equipment dictionary
static func _serialize_equipment(equipment: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot in equipment:
		if equipment[slot]:
			result[slot] = _serialize_item(equipment[slot])
		else:
			result[slot] = null
	return result
```

---

### Step 4: Create autoload/serializers/entity_serializer.gd

```gdscript
class_name EntitySerializer
extends RefCounted

## EntitySerializer - Handles entity (enemy/NPC) serialization


## Serialize all entities
static func serialize_all(entities: Array) -> Array:
	var result: Array = []
	for entity in entities:
		if entity is Enemy:
			result.append(serialize_enemy(entity))
		elif "is_npc" in entity and entity.is_npc:
			result.append(serialize_npc(entity))
	return result


## Deserialize all entities
static func deserialize_all(data: Array) -> void:
	for entity_data in data:
		if entity_data.get("type") == "enemy":
			deserialize_enemy(entity_data)
		elif entity_data.get("type") == "npc":
			deserialize_npc(entity_data)


## Serialize single enemy
static func serialize_enemy(enemy: Enemy) -> Dictionary:
	return {
		"type": "enemy",
		"enemy_id": enemy.enemy_id,
		"position": {"x": enemy.position.x, "y": enemy.position.y},
		"hp": enemy.hp,
		"max_hp": enemy.max_hp,
		"is_aware": enemy.is_aware if "is_aware" in enemy else false,
		"source_chunk": {"x": enemy.source_chunk.x, "y": enemy.source_chunk.y} if enemy.source_chunk else null,
	}


## Deserialize enemy
static func deserialize_enemy(data: Dictionary) -> Enemy:
	var pos = Vector2i(data.position.x, data.position.y)
	var enemy = EntityManager.spawn_enemy(data.enemy_id, pos)
	if enemy:
		enemy.hp = data.get("hp", enemy.max_hp)
		enemy.is_aware = data.get("is_aware", false)
		if "source_chunk" in data and data.source_chunk:
			enemy.source_chunk = Vector2i(data.source_chunk.x, data.source_chunk.y)
	return enemy


## Serialize NPC
static func serialize_npc(npc) -> Dictionary:
	return {
		"type": "npc",
		"npc_id": npc.npc_id if "npc_id" in npc else "",
		"position": {"x": npc.position.x, "y": npc.position.y},
		"shop_inventory": _serialize_shop_inventory(npc) if npc.has_method("get_shop_inventory") else [],
	}


## Deserialize NPC
static func deserialize_npc(data: Dictionary) -> void:
	var pos = Vector2i(data.position.x, data.position.y)
	var npc = NPCManager.spawn_npc(data.npc_id, pos)
	if npc and "shop_inventory" in data:
		_deserialize_shop_inventory(npc, data.shop_inventory)


## Serialize shop inventory
static func _serialize_shop_inventory(npc) -> Array:
	var result: Array = []
	if npc.has_method("get_shop_inventory"):
		for item in npc.get_shop_inventory():
			result.append(InventorySerializer._serialize_item(item))
	return result


## Deserialize shop inventory
static func _deserialize_shop_inventory(npc, data: Array) -> void:
	if not npc.has_method("set_shop_inventory"):
		return
	var items: Array = []
	for item_data in data:
		var item = InventorySerializer._deserialize_item(item_data)
		if item:
			items.append(item)
	npc.set_shop_inventory(items)
```

---

### Step 5: Create autoload/serializers/map_serializer.gd

```gdscript
class_name MapSerializer
extends RefCounted

## MapSerializer - Handles map state serialization


## Serialize map state
static func serialize(map) -> Dictionary:
	if map == null:
		return {}

	return {
		"explored_tiles": _serialize_positions(map.explored_tiles if "explored_tiles" in map else []),
		"ground_items": _serialize_ground_items(map),
		"modified_tiles": _serialize_modified_tiles(map),
		"features": _serialize_features(map),
		"hazards": _serialize_hazards(),
	}


## Deserialize map state
static func deserialize(map, data: Dictionary) -> void:
	if map == null or data.is_empty():
		return

	# Explored tiles
	if "explored_tiles" in data:
		map.explored_tiles = _deserialize_positions(data.explored_tiles)

	# Ground items
	if "ground_items" in data:
		_deserialize_ground_items(map, data.ground_items)

	# Modified tiles
	if "modified_tiles" in data:
		_deserialize_modified_tiles(map, data.modified_tiles)

	# Features
	if "features" in data:
		_deserialize_features(data.features)

	# Hazards
	if "hazards" in data:
		_deserialize_hazards(data.hazards)


## Serialize positions array
static func _serialize_positions(positions) -> Array:
	var result: Array = []
	for pos in positions:
		result.append({"x": pos.x, "y": pos.y})
	return result


## Deserialize positions array
static func _deserialize_positions(data: Array) -> Array:
	var result: Array = []
	for pos_data in data:
		result.append(Vector2i(pos_data.x, pos_data.y))
	return result


## Serialize ground items
static func _serialize_ground_items(map) -> Array:
	var result: Array = []
	if not map.has_method("get_all_ground_items"):
		return result

	for entry in map.get_all_ground_items():
		result.append({
			"position": {"x": entry.position.x, "y": entry.position.y},
			"item": InventorySerializer._serialize_item(entry.item),
		})
	return result


## Deserialize ground items
static func _deserialize_ground_items(map, data: Array) -> void:
	for entry in data:
		var pos = Vector2i(entry.position.x, entry.position.y)
		var item = InventorySerializer._deserialize_item(entry.item)
		if item and map.has_method("add_item_at"):
			map.add_item_at(pos, item)


## Serialize modified tiles (doors opened, walls broken, etc.)
static func _serialize_modified_tiles(map) -> Array:
	var result: Array = []
	if not "modified_tiles" in map:
		return result

	for pos in map.modified_tiles:
		var tile = map.modified_tiles[pos]
		result.append({
			"position": {"x": pos.x, "y": pos.y},
			"tile_type": tile.tile_type if "tile_type" in tile else "",
			"walkable": tile.walkable if "walkable" in tile else true,
		})
	return result


## Deserialize modified tiles
static func _deserialize_modified_tiles(map, data: Array) -> void:
	if not "modified_tiles" in map:
		return

	for entry in data:
		var pos = Vector2i(entry.position.x, entry.position.y)
		map.modified_tiles[pos] = {
			"tile_type": entry.get("tile_type", ""),
			"walkable": entry.get("walkable", true),
		}


## Serialize placed features
static func _serialize_features(map) -> Array:
	var result: Array = []
	for pos in FeatureManager.placed_features:
		var feature = FeatureManager.placed_features[pos]
		result.append({
			"position": {"x": pos.x, "y": pos.y},
			"feature_id": feature.feature_id if "feature_id" in feature else "",
			"state": feature.state if "state" in feature else {},
		})
	return result


## Deserialize features
static func _deserialize_features(data: Array) -> void:
	for entry in data:
		var pos = Vector2i(entry.position.x, entry.position.y)
		FeatureManager.place_feature(entry.feature_id, pos, entry.get("state", {}))


## Serialize hazards
static func _serialize_hazards() -> Array:
	var result: Array = []
	for pos in HazardManager.active_hazards:
		var hazard = HazardManager.active_hazards[pos]
		result.append({
			"position": {"x": pos.x, "y": pos.y},
			"hazard_id": hazard.hazard_id if "hazard_id" in hazard else "",
			"detected": hazard.detected if "detected" in hazard else false,
		})
	return result


## Deserialize hazards
static func _deserialize_hazards(data: Array) -> void:
	for entry in data:
		var pos = Vector2i(entry.position.x, entry.position.y)
		HazardManager.place_hazard(entry.hazard_id, pos, entry.get("detected", false))
```

---

### Step 6: Update autoload/save_manager.gd

1. **Add preloads**:
```gdscript
const PlayerSerializerClass = preload("res://autoload/serializers/player_serializer.gd")
const InventorySerializerClass = preload("res://autoload/serializers/inventory_serializer.gd")
const EntitySerializerClass = preload("res://autoload/serializers/entity_serializer.gd")
const MapSerializerClass = preload("res://autoload/serializers/map_serializer.gd")
```

2. **Simplify save_game()**:
```gdscript
func save_game(slot: int) -> bool:
	var save_data = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"world_seed": GameManager.world_seed,
		"player": PlayerSerializerClass.serialize(EntityManager.player),
		"inventory": InventorySerializerClass.serialize(EntityManager.player.inventory),
		"entities": EntitySerializerClass.serialize_all(EntityManager.entities),
		"map": MapSerializerClass.serialize(MapManager.current_map),
		"calendar": _serialize_calendar(),
		"weather": _serialize_weather(),
	}

	return _write_save_file(slot, save_data)
```

3. **Simplify load_game()**:
```gdscript
func load_game(slot: int) -> bool:
	var save_data = _read_save_file(slot)
	if save_data.is_empty():
		return false

	# Restore world
	GameManager.world_seed = save_data.get("world_seed", 0)

	# Restore player
	PlayerSerializerClass.deserialize(EntityManager.player, save_data.get("player", {}))
	InventorySerializerClass.deserialize(EntityManager.player.inventory, save_data.get("inventory", {}))

	# Restore entities
	EntityManager.entities.clear()
	EntitySerializerClass.deserialize_all(save_data.get("entities", []))

	# Restore map
	MapSerializerClass.deserialize(MapManager.current_map, save_data.get("map", {}))

	# Restore time/weather
	_deserialize_calendar(save_data.get("calendar", {}))
	_deserialize_weather(save_data.get("weather", {}))

	return true
```

4. **Remove old `_serialize_*` and `_deserialize_*` methods** that are now in serializers.

---

## Files Summary

### New Files
- `autoload/serializers/player_serializer.gd` (~200 lines)
- `autoload/serializers/inventory_serializer.gd` (~150 lines)
- `autoload/serializers/entity_serializer.gd` (~100 lines)
- `autoload/serializers/map_serializer.gd` (~150 lines)

### Modified Files
- `autoload/save_manager.gd` - Reduced from 1,117 to ~400 lines

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Start new game, play for a bit
- [ ] Save game to slot 1
- [ ] Load game from slot 1
  - [ ] Player position correct
  - [ ] Player stats correct (HP, MP, Stamina)
  - [ ] Inventory items present
  - [ ] Equipment slots correct
  - [ ] Gold amount correct
  - [ ] Level/experience correct
- [ ] Save game to slot 2
- [ ] Start new game
- [ ] Load slot 1 - state restored
- [ ] Load slot 2 - state restored
- [ ] Autosave works correctly
- [ ] Enemies restored at correct positions
- [ ] Ground items restored
- [ ] Map exploration state restored
- [ ] Features (doors, chests) restored
- [ ] Hazards restored
- [ ] Time/date/weather restored
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
rm -rf autoload/serializers/
git checkout HEAD -- autoload/save_manager.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
