class_name Player
extends Entity

## Player - The player character entity
##
## Handles player movement, interactions, and dungeon navigation.

# Preload systems to ensure they're available
const _CombatSystem = preload("res://systems/combat_system.gd")
const _SurvivalSystem = preload("res://systems/survival_system.gd")
const _Inventory = preload("res://systems/inventory_system.gd")
const _CraftingSystem = preload("res://systems/crafting_system.gd")
const _HarvestSystem = preload("res://systems/harvest_system.gd")
const _FarmingSystem = preload("res://systems/farming_system.gd")
const _FOVSystem = preload("res://systems/fov_system.gd")
const _LockSystem = preload("res://systems/lock_system.gd")

var perception_range: int = 10
var survival: SurvivalSystem = null
var inventory: Inventory = null
var known_recipes: Array[String] = []  # Array of recipe IDs the player has discovered
var gold: int = 25  # Player's gold currency

# Experience
var experience: int = 0
var experience_to_next_level: int = 100

func _init() -> void:
	super("player", Vector2i(10, 10), "@", Color(1.0, 1.0, 0.0), true)
	_setup_player()

## Setup player-specific properties
func _setup_player() -> void:
	entity_type = "player"
	name = "Player"
	base_damage = 2  # Unarmed combat damage
	armor = 0  # No armor initially

	# Player starts with base attributes (defined in Entity)
	# Perception range calculated from WIS: Base 5 + (WIS / 2)
	perception_range = 5 + int(attributes["WIS"] / 2.0)
	
	# Initialize survival system
	survival = _SurvivalSystem.new(self)
	
	# Initialize inventory system
	inventory = _Inventory.new(self)

## Attempt to attack a target entity
func attack(target: Entity) -> Dictionary:
	# Consume stamina for attack
	if survival and not survival.consume_stamina(survival.STAMINA_COST_ATTACK):
		return {"hit": false, "no_stamina": true}
	return _CombatSystem.attempt_attack(self, target)

## Attempt to move in a direction
func move(direction: Vector2i) -> bool:
	var new_pos = position + direction

	# Check for blocking features (chests, altars, etc.) - interact instead of moving
	# Must check this before is_walkable since blocking features make tiles non-walkable
	if FeatureManager.has_blocking_feature(new_pos):
		_interact_with_feature_at(new_pos)
		return true  # Action taken, but didn't move

	# Check for closed door - open it if auto-open is enabled
	var tile = MapManager.current_map.get_tile(new_pos) if MapManager.current_map else null
	if tile and tile.tile_type == "door" and not tile.is_open:
		# Check if auto-open doors is enabled
		if GameManager.auto_open_doors:
			var opened = _open_door(new_pos)
			return opened  # Only consume turn if door was actually opened
		else:
			return false  # Can't move through closed door when auto-open is off

	# Check if new position is walkable
	if not MapManager.current_map or not MapManager.current_map.is_walkable(new_pos):
		# Notify player why they can't move
		_notify_blocked_by_tile(new_pos)
		return false

	# Consume stamina for movement (allow move even if depleted, just add fatigue)
	if survival:
		if not survival.consume_stamina(survival.STAMINA_COST_MOVE):
			# Out of stamina - still allow movement but warn player
			pass

	var old_pos = position
	position = new_pos
	EventBus.player_moved.emit(old_pos, new_pos)

	# Check for hazards at new position
	_check_hazards_at_position(new_pos)

	# Check for crop trampling at new position
	_FarmingSystem.check_trample(self, new_pos)

	# Check for non-blocking interactable features at new position (like inscriptions)
	if FeatureManager.has_interactable_feature(new_pos):
		var feature = FeatureManager.get_feature_at(new_pos)
		if not feature.get("definition", {}).get("blocking", false):
			_interact_with_feature_at(new_pos)

	return true


## Notify player when blocked by a non-walkable tile or structure
func _notify_blocked_by_tile(pos: Vector2i) -> void:
	# First check for blocking structures at this position
	if MapManager.current_map:
		var structures = StructureManager.get_structures_at(pos, MapManager.current_map.map_id)
		for structure in structures:
			if structure.blocks_movement:
				EventBus.message_logged.emit("Your path is blocked by %s." % structure.name.to_lower())
				return

	var tile = MapManager.current_map.get_tile(pos) if MapManager.current_map else null
	if not tile:
		return

	# Get a human-readable name for the blocking tile
	var tile_name = _get_tile_display_name(tile)
	EventBus.message_logged.emit("Your path is blocked by %s." % tile_name)


## Get a human-readable display name for a tile type
## Uses TileTypeManager for data-driven display names
func _get_tile_display_name(tile) -> String:
	# First check by ascii character for special structures/features
	# This catches wells, shrines, and resources on floor tiles
	var char_name = TileTypeManager.get_display_name_by_ascii_char(tile.ascii_char)
	if not char_name.is_empty():
		return char_name

	# Handle doors with state-specific display names
	if tile.tile_type == "door":
		if tile.is_locked:
			return TileTypeManager.get_display_name("door", "locked")
		elif not tile.is_open:
			return TileTypeManager.get_display_name("door", "closed")
		else:
			return TileTypeManager.get_display_name("door", "open")

	# Try to get display name from TileTypeManager
	var display_name = TileTypeManager.get_display_name(tile.tile_type)
	if display_name != "an obstacle":
		return display_name

	# For floor tiles that are blocking, check remaining ascii characters
	if tile.tile_type == "floor" and not tile.walkable:
		return "an obstacle"

	# Fallback for unknown types
	if tile.tile_type != "" and tile.tile_type != "floor":
		return "a " + tile.tile_type.replace("_", " ")
	return "an obstacle"


## Check for hazards at the given position
func _check_hazards_at_position(pos: Vector2i) -> void:
	# First try to detect hidden hazards based on perception
	var perception_check = 5 + int(attributes["WIS"] / 2.0)
	HazardManager.try_detect_hazard(pos, perception_check)

	# Check if hazard triggers
	var hazard_result = HazardManager.check_hazard_trigger(pos, self)
	if hazard_result.get("triggered", false):
		_apply_hazard_damage(hazard_result)

	# Also check proximity hazards (1 tile radius)
	var proximity_results = HazardManager.check_proximity_hazards(pos, 1, self)
	for result in proximity_results:
		_apply_hazard_damage(result)


## Apply hazard damage and effects to player
func _apply_hazard_damage(hazard_result: Dictionary) -> void:
	print("[Player] Applying hazard damage: %s" % str(hazard_result))
	var damage: int = hazard_result.get("damage", 0)
	var hazard_id: String = hazard_result.get("hazard_id", "trap")
	var damage_type: String = hazard_result.get("damage_type", "physical")

	# Format hazard name for display (replace underscores with spaces)
	var hazard_display_name = hazard_id.replace("_", " ")

	# Apply damage if any
	if damage > 0:
		# Apply armor reduction for physical damage
		var actual_damage = damage
		if damage_type == "physical":
			actual_damage = max(1, damage - get_total_armor())

		take_damage(actual_damage)
		EventBus.combat_message.emit("You trigger a %s! (%d damage)" % [hazard_display_name, actual_damage], Color.ORANGE_RED)
	else:
		# No damage but still stepped into the hazard - notify player
		EventBus.combat_message.emit("You step into a %s!" % hazard_display_name, Color.ORANGE)

	# Apply status effects from hazard
	var effects = hazard_result.get("effects", [])
	for effect in effects:
		var effect_type = effect.get("type", "")
		@warning_ignore("unused_variable")
		var duration = effect.get("duration", 100)
		match effect_type:
			"poison":
				EventBus.combat_message.emit("You are poisoned!", Color.LIME_GREEN)
				# TODO: Apply poison status effect
			"slow":
				EventBus.combat_message.emit("You are slowed!", Color.DARK_BLUE)
				# TODO: Apply slow status effect
			"curse":
				EventBus.combat_message.emit("You are cursed!", Color.PURPLE)
				# TODO: Apply curse status effect
			"stat_drain":
				EventBus.combat_message.emit("You feel your strength draining away!", Color.PURPLE)
				# TODO: Apply stat drain status effect
			_:
				EventBus.combat_message.emit("You are affected by %s!" % effect_type, Color.ORANGE)


## Interact with a feature at the player's current position
func interact_with_feature() -> Dictionary:
	return _interact_with_feature_at(position)


## Interact with a feature at a specific position
func _interact_with_feature_at(pos: Vector2i) -> Dictionary:
	print("[Player] Attempting to interact with feature at %v" % pos)
	# Check if there's an interactable feature at position
	if not FeatureManager.has_interactable_feature(pos):
		print("[Player] No interactable feature at %v" % pos)
		return {"success": false, "message": "Nothing to interact with here."}

	var result = FeatureManager.interact_with_feature(pos)

	# Show message to player
	if result.has("message"):
		EventBus.combat_message.emit(result.message, Color.GOLD)

	# Process effects
	if result.get("success", false):
		for effect in result.get("effects", []):
			match effect.get("type"):
				"loot":
					_collect_feature_loot(effect.get("items", []))
				"harvest":
					_collect_feature_loot(effect.get("items", []))
				"summon_enemy":
					# Enemy spawning handled by EntityManager via signal
					pass
				"blessing":
					var amount = effect.get("amount", 10)
					heal(amount)
					EventBus.combat_message.emit("You feel blessed! (+%d HP)" % amount, Color.GOLD)
				"hint":
					EventBus.message_logged.emit(effect.get("text", ""))

	return result


## Collect loot from a feature
func _collect_feature_loot(items: Array) -> void:
	for item_data in items:
		var item_id = item_data.get("item_id", "")
		var count = item_data.get("count", 1)

		if item_id == "gold_coin":
			gold += count
			EventBus.message_logged.emit("Found %d gold!" % count)
		else:
			var item = ItemManager.create_item(item_id, count)
			if item and inventory:
				if inventory.add_item(item):
					EventBus.item_picked_up.emit(item)
				else:
					# Inventory full - drop on ground
					EntityManager.spawn_ground_item(item, position)
					EventBus.message_logged.emit("Inventory full! Item dropped.")

## Process survival systems for a turn
func process_survival_turn(turn_number: int) -> Dictionary:
	if not survival:
		return {}

	# Update temperature based on current location, time, and player position
	var map_id = MapManager.current_map.map_id if MapManager.current_map else "overworld"
	survival.update_temperature(map_id, TurnManager.time_of_day, position)

	# Process survival effects
	var effects = survival.process_turn(turn_number)
	
	# Apply stat modifiers from survival
	apply_stat_modifiers(survival.get_stat_modifiers())
	
	# Update perception range based on survival effects
	var survival_effects = survival._calculate_survival_effects()
	var base_perception = 5 + int(attributes["WIS"] / 2.0)
	perception_range = max(2, base_perception + survival_effects.perception_modifier)
	
	return effects

## Regenerate stamina (called when waiting/not acting)
func regenerate_stamina() -> void:
	if survival:
		var effects = survival._calculate_survival_effects()
		survival.regenerate_stamina(effects.stamina_regen_modifier)

## Interact with the tile the player is standing on
func interact_with_tile() -> void:
	if not MapManager.current_map:
		return

	var tile = MapManager.current_map.get_tile(position)

	if tile.tile_type == "stairs_down":
		_descend_stairs()
	elif tile.tile_type == "stairs_up":
		_ascend_stairs()

## Descend stairs to next floor
func _descend_stairs() -> void:
	print("Player descending stairs...")
	MapManager.descend_dungeon()

	# Find stairs up on new floor and position player there
	_find_and_move_to_stairs("stairs_up")

## Ascend stairs to previous floor
func _ascend_stairs() -> void:
	print("Player ascending stairs...")
	MapManager.ascend_dungeon()

	# Find stairs down on new floor and position player there
	# (works for both overworld entrance and dungeon floors)
	_find_and_move_to_stairs("stairs_down")

## Find stairs of given type and move player there
func _find_and_move_to_stairs(stairs_type: String) -> void:
	if not MapManager.current_map:
		return

	var old_pos = position

	# For chunk-based maps, use stored positions
	if MapManager.current_map.chunk_based:
		if stairs_type == "stairs_down":
			# Returning to overworld - use saved position
			if GameManager.last_overworld_position != Vector2i.ZERO:
				position = GameManager.last_overworld_position
				print("Player positioned at saved overworld location: ", position)
				EventBus.player_moved.emit(old_pos, position)
				return
			# New game: spawn at player spawn position (just outside town)
			elif MapManager.current_map.has_meta("player_spawn"):
				position = MapManager.current_map.get_meta("player_spawn")
				print("Player positioned at spawn location: ", position)
				EventBus.player_moved.emit(old_pos, position)
				return
			# Fallback: get dungeon entrance position from metadata (old saves)
			elif MapManager.current_map.has_meta("dungeon_entrance"):
				position = MapManager.current_map.get_meta("dungeon_entrance")
				print("Player positioned at ", stairs_type, ": ", position)
				EventBus.player_moved.emit(old_pos, position)
				return
		# For stairs_up in dungeons, search tiles normally (handled below)

	# For non-chunk-based maps (dungeons), check metadata first for stairs position
	if MapManager.current_map.metadata.has(stairs_type):
		position = MapManager.current_map.metadata[stairs_type]
		print("Player positioned at ", stairs_type, " from metadata: ", position)
		EventBus.player_moved.emit(old_pos, position)
		return

	# Fallback: search the tiles
	# Limit search to actual map bounds
	var search_width = min(MapManager.current_map.width, 100)
	var search_height = min(MapManager.current_map.height, 100)

	for y in range(search_height):
		for x in range(search_width):
			var pos = Vector2i(x, y)
			var tile = MapManager.current_map.get_tile(pos)
			if tile.tile_type == stairs_type:
				position = pos
				print("Player positioned at ", stairs_type, ": ", position)
				EventBus.player_moved.emit(old_pos, position)
				return

	# Fallback to center if stairs not found
	@warning_ignore("integer_division")
	position = Vector2i(search_width / 2, search_height / 2)
	push_warning("Could not find ", stairs_type, ", positioning at center")
	EventBus.player_moved.emit(old_pos, position)

## Harvest a resource in a given direction (generic method)
## Also handles harvesting crops from the farming system
func harvest_resource(direction: Vector2i) -> Dictionary:
	if not MapManager.current_map:
		return {"success": false, "message": "No map loaded"}

	var target_pos = position + direction
	var map_id = MapManager.current_map.map_id

	# First check for crops at the target position
	var crop = _FarmingSystem.get_crop_at(map_id, target_pos)
	if crop:
		var result = _FarmingSystem.harvest_crop(self, target_pos)
		# Add harvest_complete flag for compatibility with input handler
		result["harvest_complete"] = result.get("success", false)
		return result

	# Otherwise check for harvestable tiles
	var tile = MapManager.current_map.get_tile(target_pos)

	if not tile or tile.harvestable_resource_id.is_empty():
		return {"success": false, "message": "Nothing to harvest there"}

	# Delegate to HarvestSystem
	return _HarvestSystem.harvest(self, target_pos, tile.harvestable_resource_id)

## Get total weapon damage (base + equipped weapon bonus)
func get_weapon_damage() -> int:
	if inventory:
		return base_damage + inventory.get_weapon_damage_bonus()
	return base_damage

## Get total armor value from all equipped items
func get_total_armor() -> int:
	if inventory:
		return armor + inventory.get_total_armor()
	return armor

## Pick up a ground item
func pickup_item(ground_item: GroundItem) -> bool:
	if not ground_item or not ground_item.item:
		return false

	if not inventory:
		return false

	# Check encumbrance before picking up
	var new_weight = inventory.get_total_weight() + ground_item.item.get_total_weight()
	if new_weight / inventory.max_weight > 1.25:
		# Would be too heavy to move at all
		return false

	var item = ground_item.item

	# Auto-equip lit light sources to off-hand if available
	if item.provides_light and item.is_lit and item.can_equip_to_slot("off_hand"):
		var off_hand = inventory.get_equipped("off_hand")
		var main_hand = inventory.get_equipped("main_hand")
		# Check if off-hand is free (and not blocked by two-handed weapon)
		if off_hand == null and (main_hand == null or not main_hand.is_two_handed()):
			# Directly equip to off-hand
			inventory.equipment["off_hand"] = item
			EventBus.item_picked_up.emit(item)
			EventBus.item_equipped.emit(item, "off_hand")
			return true

	if inventory.add_item(item):
		EventBus.item_picked_up.emit(item)
		return true

	return false

## Drop an item from inventory
func drop_item(item: Item) -> GroundItem:
	if not item or not inventory:
		return null
	
	if inventory.remove_item(item):
		var drop_pos = _find_drop_position()
		var ground_item = GroundItem.create(item, drop_pos)
		EventBus.item_dropped.emit(item, drop_pos)
		return ground_item
	
	return null

## Find an empty adjacent position to drop an item
func _find_drop_position() -> Vector2i:
	# Check adjacent tiles in order: cardinal directions first, then diagonals
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1),  # Up
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(1, -1),  # Up-right
		Vector2i(-1, -1)  # Up-left
	]
	
	for dir in directions:
		var check_pos = position + dir
		if _is_valid_drop_position(check_pos):
			return check_pos
	
	# If no empty adjacent space, drop at player position as fallback
	return position

## Check if a position is valid for dropping an item
func _is_valid_drop_position(pos: Vector2i) -> bool:
	if not MapManager.current_map:
		return false
	
	# Must be walkable terrain
	if not MapManager.current_map.is_walkable(pos):
		return false
	
	# Check for blocking entities (enemies, other players)
	var blocking = EntityManager.get_blocking_entity_at(pos)
	if blocking:
		return false
	
	return true

## Use an item from inventory
func use_item(item: Item) -> Dictionary:
	if not item or not inventory:
		return {"success": false, "message": "No item"}
	
	return inventory.use_item(item)

## Equip an item (returns array of unequipped items, if any)
func equip_item(item: Item, target_slot: String = "") -> Array[Item]:
	if not item or not inventory:
		return []
	
	return inventory.equip_item(item, target_slot)

## Apply item effects (called by Item.use())
func apply_item_effects(effects: Dictionary) -> void:
	if "hunger" in effects and survival:
		survival.eat(effects.hunger)
	if "thirst" in effects and survival:
		survival.drink(effects.thirst)
	if "health" in effects:
		heal(effects.health)
	if "stamina" in effects and survival:
		survival.stamina = min(survival.get_max_stamina(), survival.stamina + effects.stamina)
	if "fatigue" in effects and survival:
		survival.rest(effects.fatigue)

## Check if player knows a recipe
func knows_recipe(recipe_id: String) -> bool:
	return recipe_id in known_recipes

## Learn a new recipe
func learn_recipe(recipe_id: String) -> void:
	if not knows_recipe(recipe_id):
		known_recipes.append(recipe_id)
		print("Player learned recipe: ", recipe_id)

## Check if player is near a fire source for crafting
func is_near_fire() -> bool:
	return _CraftingSystem.is_near_fire(position)

## Get all recipes the player knows
func get_known_recipes() -> Array:
	var result: Array = []
	for recipe_id in known_recipes:
		var recipe = RecipeManager.get_recipe(recipe_id)
		if recipe:
			result.append(recipe)
	return result

## Get recipes player can currently craft (knows recipe + has ingredients)
func get_craftable_recipes() -> Array:
	var result: Array = []
	var near_fire = _CraftingSystem.is_near_fire(position)

	for recipe_id in known_recipes:
		var recipe = RecipeManager.get_recipe(recipe_id)
		if recipe and recipe.has_requirements(inventory, near_fire):
			result.append(recipe)

	return result

## Open a door at the given position
## If locked, attempts to unlock with key first (auto-unlock feature)
## Returns true if the door was opened, false if still locked or couldn't open
func _open_door(pos: Vector2i) -> bool:
	print("[DEBUG] _open_door called for pos: %v" % pos)
	if not MapManager.current_map:
		print("[DEBUG] _open_door: MapManager.current_map is null")
		return false

	var tile = MapManager.current_map.get_tile(pos)
	print("[DEBUG] _open_door: tile = %s, tile_type = %s" % [tile, tile.tile_type if tile else "null"])
	if not tile or tile.tile_type != "door":
		print("[DEBUG] _open_door: Not a door tile")
		return false

	# Check if the door is locked
	print("[DEBUG] _open_door: tile.is_locked = %s" % tile.is_locked)
	if tile.is_locked:
		# Try to unlock with a key (auto-unlock)
		var key_result = _LockSystem.try_unlock_with_key(tile.lock_id, tile.lock_level, inventory)
		if key_result.success:
			tile.unlock()
			EventBus.combat_message.emit(key_result.message, Color.GREEN)
			EventBus.lock_opened.emit(pos, "key")
			# Now open the door
			if tile.open_door():
				EventBus.combat_message.emit("You open the door.", Color.WHITE)
				_FOVSystem.invalidate_cache()
				EventBus.tile_changed.emit(pos)
				return true
		else:
			print("[DEBUG] _open_door: Door is locked, emitting combat_message signal")
			EventBus.combat_message.emit("The door is locked. Press Y to pick the lock.", Color.YELLOW)
			print("[DEBUG] _open_door: combat_message signal emitted")
		return false

	# Door is not locked, just open it
	if tile.open_door():
		EventBus.combat_message.emit("You open the door.", Color.WHITE)
		_FOVSystem.invalidate_cache()
		EventBus.tile_changed.emit(pos)
		return true

	return false

## Toggle a door in the given direction from player (open if closed, close if open)
## Returns true if door was toggled, false otherwise
## Note: For locked doors, use try_pick_lock() instead
func toggle_door(direction: Vector2i) -> bool:
	if not MapManager.current_map:
		return false

	var door_pos = position + direction
	var tile = MapManager.current_map.get_tile(door_pos)

	# Check if there's a door at the position
	if not tile or tile.tile_type != "door":
		return false

	if tile.is_open:
		# Try to close the door
		# Check if position is occupied by an entity
		if EntityManager.get_blocking_entity_at(door_pos):
			EventBus.combat_message.emit("Something is in the way.", Color.YELLOW)
			return false

		if tile.close_door():
			EventBus.combat_message.emit("You close the door.", Color.WHITE)
			_FOVSystem.invalidate_cache()
			EventBus.tile_changed.emit(door_pos)
			return true
	else:
		# Check if locked
		if tile.is_locked:
			# Try to unlock with key first (auto-unlock)
			var key_result = _LockSystem.try_unlock_with_key(tile.lock_id, tile.lock_level, inventory)
			if key_result.success:
				tile.unlock()
				EventBus.combat_message.emit(key_result.message, Color.GREEN)
				EventBus.lock_opened.emit(door_pos, "key")
				# Now open the door
				if tile.open_door():
					EventBus.combat_message.emit("You open the door.", Color.WHITE)
					_FOVSystem.invalidate_cache()
					EventBus.tile_changed.emit(door_pos)
					return true
			else:
				EventBus.combat_message.emit("The door is locked. Press Y to pick the lock.", Color.YELLOW)
				return false

		# Open the door
		if tile.open_door():
			EventBus.combat_message.emit("You open the door.", Color.WHITE)
			_FOVSystem.invalidate_cache()
			EventBus.tile_changed.emit(door_pos)
			return true

	return false

## Try to toggle any adjacent door (open or close)
## Returns true if a door was toggled
func try_toggle_adjacent_door() -> bool:
	var directions = [
		Vector2i(0, -1),  # Up
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, 0),   # Right
	]

	for dir in directions:
		if toggle_door(dir):
			return true

	EventBus.combat_message.emit("No door nearby.", Color.GRAY)
	return false
