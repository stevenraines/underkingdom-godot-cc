extends Node2D

## Game - Main game scene
##
## Initializes the game, creates player, manages rendering and updates.

const ItemClass = preload("res://items/item.gd")
const GroundItemClass = preload("res://entities/ground_item.gd")
const ItemManagerScript = preload("res://autoload/item_manager.gd")
const JsonHelperScript = preload("res://autoload/json_helper.gd")
const Structure = preload("res://entities/structure.gd")
const StructurePlacement = preload("res://systems/structure_placement.gd")

var player: Player
var renderer: ASCIIRenderer
var input_handler: Node
var inventory_screen: Control = null
var crafting_screen: Control = null
var build_mode_screen: Control = null
var container_screen: Control = null
var shop_screen: Control = null
var auto_pickup_enabled: bool = true  # Toggle for automatic item pickup
var build_mode_active: bool = false
var selected_structure_id: String = ""
var build_cursor_offset: Vector2i = Vector2i(1, 0)  # Offset from player for placement cursor

@onready var hud: CanvasLayer = $HUD
@onready var character_info_label: Label = $HUD/TopBar/CharacterInfo
@onready var status_line: Label = $HUD/TopBar/StatusLine
@onready var location_label: Label = $HUD/RightSidebar/LocationLabel
@onready var message_log: RichTextLabel = $HUD/RightSidebar/MessageLog
@onready var active_effects_label: Label = $HUD/BottomBar/ActiveEffects
@onready var xp_label: Label = $HUD/TopBar/XPLabel

const InventoryScreenScene = preload("res://ui/inventory_screen.tscn")
const CraftingScreenScene = preload("res://ui/crafting_screen.tscn")
const BuildModeScreenScene = preload("res://ui/build_mode_screen.tscn")
const ContainerScreenScene = preload("res://ui/container_screen.tscn")
const ShopScreenScene = preload("res://ui/shop_screen.tscn")

func _ready() -> void:
	# Get renderer reference
	renderer = $ASCIIRenderer

	# Get input handler
	input_handler = $InputHandler

	# Set UI colors
	_setup_ui_colors()
	
	# Create inventory screen
	_setup_inventory_screen()

	# Create crafting screen
	_setup_crafting_screen()

	# Create build mode screen
	_setup_build_mode_screen()

	# Create container screen
	_setup_container_screen()

	# Create shop screen
	_setup_shop_screen()

	# Start new game
	GameManager.start_new_game()

	# Generate overworld
	MapManager.transition_to_map("overworld")

	# Create player
	player = Player.new()
	player.position = _find_valid_spawn_position()
	MapManager.current_map.entities.append(player)
	
	# Give player some starter items
	_give_starter_items()

	# Set player reference in input handler and EntityManager
	input_handler.set_player(player)
	EntityManager.player = player

	# Spawn initial enemies
	_spawn_map_enemies()

	# Initial render
	_render_map()
	_render_all_entities()
	_render_ground_items()
	renderer.render_entity(player.position, "@", Color.YELLOW)
	renderer.center_camera(player.position)

	# Calculate initial FOV
	var visible_tiles = FOVSystem.calculate_fov(player.position, player.perception_range, MapManager.current_map)
	renderer.update_fov(visible_tiles)

	# Connect signals
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.turn_advanced.connect(_on_turn_advanced)
	EventBus.entity_moved.connect(_on_entity_moved)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.attack_performed.connect(_on_attack_performed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.survival_warning.connect(_on_survival_warning)
	EventBus.stamina_depleted.connect(_on_stamina_depleted)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_dropped.connect(_on_item_dropped)
	EventBus.message_logged.connect(_on_message_logged)
	EventBus.structure_placed.connect(_on_structure_placed)
	EventBus.shop_opened.connect(_on_shop_opened)

	# Update HUD
	_update_hud()

	# Initial welcome message (controls are now shown in sidebar)
	_add_message("Welcome to the Underkingdom!", Color(0.6, 0.9, 0.6))

	print("Game scene initialized")

## Setup inventory screen
func _setup_inventory_screen() -> void:
	inventory_screen = InventoryScreenScene.instantiate()
	hud.add_child(inventory_screen)
	inventory_screen.closed.connect(_on_inventory_closed)

## Setup crafting screen
func _setup_crafting_screen() -> void:
	crafting_screen = CraftingScreenScene.instantiate()
	hud.add_child(crafting_screen)
	# Ensure crafting screen blocks player input while open
	if crafting_screen.has_signal("closed"):
		crafting_screen.closed.connect(_on_crafting_closed)

## Setup build mode screen
func _setup_build_mode_screen() -> void:
	build_mode_screen = BuildModeScreenScene.instantiate()
	hud.add_child(build_mode_screen)
	build_mode_screen.closed.connect(_on_build_mode_closed)
	build_mode_screen.structure_selected.connect(_on_structure_selected)

## Setup container screen
func _setup_container_screen() -> void:
	container_screen = ContainerScreenScene.instantiate()
	hud.add_child(container_screen)
	container_screen.closed.connect(_on_container_closed)

## Setup shop screen
func _setup_shop_screen() -> void:
	shop_screen = ShopScreenScene.instantiate()
	hud.add_child(shop_screen)
	shop_screen.closed.connect(_on_shop_closed)

## Give player some starter items
func _give_starter_items() -> void:
	if not player or not player.inventory:
		return

	# Load starter items from configuration JSON (falls back to empty)
	var starter_path: String = "res://data/configuration/starter_items.json"
	var items_data: Array = JsonHelper.load_json_file(starter_path)
	if typeof(items_data) != TYPE_ARRAY:
		push_warning("Game: starter_items.json did not return an array, using empty list")
		items_data = []

	var item_mgr = get_node("/root/ItemManager")
	for item_data in items_data:
		var item_id = item_data.get("id", "")
		var count = int(item_data.get("count", 1))
		if item_id == "":
			continue
		var stacks = item_mgr.create_item_stacks(item_id, count)
		for it in stacks:
			if it:
				player.inventory.add_item(it)

	# Give player some starter recipes for testing
	player.learn_recipe("bandage")
	player.learn_recipe("flint_knife")
	player.learn_recipe("cooked_meat")

## Render the entire current map
func _render_map() -> void:
	if not MapManager.current_map:
		return

	renderer.clear_all()

	# For dungeons, calculate which walls should be visible (only those adjacent to accessible areas)
	var visible_walls: Dictionary = {}
	var is_dungeon = MapManager.current_map.map_id.begins_with("dungeon_")

	if is_dungeon and player:
		visible_walls = MapManager.current_map.get_visible_walls(player.position)

	for y in range(MapManager.current_map.height):
		for x in range(MapManager.current_map.width):
			var pos = Vector2i(x, y)
			var tile = MapManager.current_map.get_tile(pos)

			# Skip inaccessible walls in dungeons
			if is_dungeon and tile.tile_type == "wall":
				if pos not in visible_walls:
					continue  # Don't render this wall

			renderer.render_tile(pos, tile.ascii_char)

## Called when player moves
func _on_player_moved(old_pos: Vector2i, new_pos: Vector2i) -> void:
	# In dungeons, wall visibility depends on player position
	# So we need to re-render the entire map when player moves
	var is_dungeon = MapManager.current_map and MapManager.current_map.map_id.begins_with("dungeon_")

	if is_dungeon:
		# Re-render entire map with updated wall visibility
		_render_map()
		_render_all_entities()

	# Clear old player position and render at new position
	renderer.clear_entity(old_pos)
	
	# Re-render any ground item at old position that was hidden under player
	_render_ground_item_at(old_pos)
	
	renderer.render_entity(new_pos, "@", Color.YELLOW)
	renderer.center_camera(new_pos)

	# Update FOV
	var visible_tiles = FOVSystem.calculate_fov(new_pos, player.perception_range, MapManager.current_map)
	renderer.update_fov(visible_tiles)

	# Auto-pickup items at new position
	_auto_pickup_items()

	# Check if standing on stairs and update message
	_update_message()

## Render a ground item or structure at a specific position if one exists
func _render_ground_item_at(pos: Vector2i) -> void:
	# Check for structures first (they should be rendered above ground items)
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_at(pos, map_id)
	if structures.size() > 0:
		var structure = structures[0]
		renderer.render_entity(pos, structure.ascii_char, structure.color)
		return

	# If no structure, check for ground items
	var ground_items = EntityManager.get_ground_items_at(pos)
	if ground_items.size() > 0:
		var item = ground_items[0]
		renderer.render_entity(pos, item.ascii_char, item.color)

## Auto-pickup items at the player's position
func _auto_pickup_items() -> void:
	if not player or not auto_pickup_enabled:
		return
	
	var ground_items = EntityManager.get_ground_items_at(player.position)
	for ground_item in ground_items:
		if player.pickup_item(ground_item):
			EntityManager.remove_entity(ground_item)

## Toggle auto-pickup on/off
func toggle_auto_pickup() -> void:
	auto_pickup_enabled = not auto_pickup_enabled
	var status = "ON" if auto_pickup_enabled else "OFF"
	_add_message("Auto-pickup: %s" % status, Color(0.8, 0.8, 0.6))
	_update_toggles_display()

## Called when map changes (dungeon transitions, etc.)
func _on_map_changed(map_id: String) -> void:
	print("Map changed to: ", map_id)

	# Clear existing entities from EntityManager
	EntityManager.clear_entities()

	# Spawn enemies for the new map
	_spawn_map_enemies()

	# Render map and entities
	_render_map()
	_render_all_entities()

	# Re-render player at new position
	renderer.render_entity(player.position, "@", Color.YELLOW)
	renderer.center_camera(player.position)

	# Update FOV
	var visible_tiles = FOVSystem.calculate_fov(player.position, player.perception_range, MapManager.current_map)
	renderer.update_fov(visible_tiles)

	# Update message
	_update_message()

## Called when turn advances
func _on_turn_advanced(_turn_number: int) -> void:
	_update_hud()
	_update_survival_display()

## Called when a survival warning is triggered
func _on_survival_warning(message: String, severity: String) -> void:
	var color: Color
	match severity:
		"critical":
			color = Color.RED
		"severe":
			color = Color(1.0, 0.4, 0.2)  # Orange-red
		"warning":
			color = Color(1.0, 0.7, 0.2)  # Orange
		_:
			color = Color(0.8, 0.8, 0.5)  # Dim yellow
	
	_add_message(message, color)

## Called when stamina is depleted
func _on_stamina_depleted() -> void:
	_add_message("You are out of stamina!", Color(1.0, 0.5, 0.5))

## Called when any entity moves
func _on_entity_moved(entity: Entity, old_pos: Vector2i, new_pos: Vector2i) -> void:
	renderer.clear_entity(old_pos)
	renderer.render_entity(new_pos, entity.ascii_char, entity.color)

## Called when an entity dies
func _on_entity_died(entity: Entity) -> void:
	renderer.clear_entity(entity.position)
	
	# Check if it's the player
	if entity == player:
		EventBus.player_died.emit()
	else:
		# If the entity defines yields, generate drops similar to harvesting
		var drop_messages: Array[String] = []
		if entity and entity is Enemy and entity.yields.size() > 0:
			# Use yields array (array of dicts with item_id, min_count, max_count, chance)
			print("[DEBUG] Entity died: ", entity.entity_id, " at ", entity.position)
			print("[DEBUG] yields array: ", entity.yields)
			var total_yields: Dictionary = {}
			for yield_data in entity.yields:
				var item_id = yield_data.get("item_id", "")
				var min_count = int(yield_data.get("min_count", 1))
				var max_count = int(yield_data.get("max_count", 1))
				var chance = float(yield_data.get("chance", 1.0))
				if randf() > chance:
					continue
				var range_size = max_count - min_count + 1
				var count = min_count + (randi() % max(1, range_size))
				if count > 0:
					if item_id in total_yields:
						total_yields[item_id] += count
					else:
						total_yields[item_id] = count
			print("[DEBUG] total_yields computed: ", total_yields)
			# Create and spawn items as ground items
			for item_id in total_yields:
				var count = total_yields[item_id]
				# Create stacks as needed
				var stacks = ItemManager.create_item_stacks(item_id, count)
				for it in stacks:
					print("[DEBUG] Spawning ground item stack: ", item_id, " count ", it.stack_size)
					EntityManager.spawn_ground_item(it, entity.position)
				drop_messages.append("%d %s" % [count, ItemManager.get_item_data(item_id).get("name", item_id)])
			if drop_messages.size() > 0:
				_add_message("Dropped: %s" % ", ".join(drop_messages), Color(0.8, 0.8, 0.6))
				# Ensure dropped ground items are rendered immediately
				_render_ground_item_at(entity.position)

		# Remove entity from managers
		EntityManager.remove_entity(entity)

## Called when an attack is performed
func _on_attack_performed(attacker: Entity, _defender: Entity, result: Dictionary) -> void:
	var is_player_attacker = (attacker == player)
	var message = CombatSystem.get_attack_message(result, is_player_attacker)
	
	# Determine message color
	var color: Color
	if result.hit:
		if result.defender_died:
			color = Color.RED
		elif is_player_attacker:
			color = Color(1.0, 0.6, 0.2)  # Orange - player dealing damage
		else:
			color = Color(1.0, 0.4, 0.4)  # Light red - taking damage
	else:
		color = Color(0.6, 0.6, 0.6)  # Gray for misses
	
	_add_message(message, color)
	
	# Update HUD to show health changes
	# If player killed an enemy, award XP
	if result.defender_died and is_player_attacker and _defender and _defender is Enemy:
		var xp_gain = _defender.xp_value if "xp_value" in _defender else 0
		player.experience += xp_gain
		_add_message("Gained %d XP." % xp_gain, Color(0.6, 0.9, 0.6))

	_update_hud()

## Called when player dies
func _on_player_died() -> void:
	_add_message("", Color.WHITE)  # Blank line
	_add_message("*** YOU HAVE DIED ***", Color.RED)
	_add_message("Press R to restart or ESC for main menu.", Color(0.7, 0.7, 0.7))
	
	# Disable input (handled in input_handler via is_alive check)
	# Show game over state
	_show_game_over()

## Show game over overlay
func _show_game_over() -> void:
	# For now, just change the HUD to show game over state
	# A proper overlay can be added later
	if status_line:
		status_line.text = "GAME OVER - Press R to restart"
		status_line.add_theme_color_override("font_color", Color.RED)

## Handle unhandled input (for game-wide controls)
func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse clicks for structure placement in build mode
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if build_mode_active and selected_structure_id != "":
			_try_place_structure_at_screen(event.position)
			get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and not event.echo:
		# Handle build mode controls
		if build_mode_active and selected_structure_id != "":
			match event.keycode:
				KEY_UP, KEY_W:
					build_cursor_offset.y = max(-1, build_cursor_offset.y - 1)
					_update_build_cursor()
					get_viewport().set_input_as_handled()
				KEY_DOWN, KEY_S:
					build_cursor_offset.y = min(1, build_cursor_offset.y + 1)
					_update_build_cursor()
					get_viewport().set_input_as_handled()
				KEY_LEFT, KEY_A:
					build_cursor_offset.x = max(-1, build_cursor_offset.x - 1)
					_update_build_cursor()
					get_viewport().set_input_as_handled()
				KEY_RIGHT, KEY_D:
					build_cursor_offset.x = min(1, build_cursor_offset.x + 1)
					_update_build_cursor()
					get_viewport().set_input_as_handled()
				KEY_ENTER, KEY_SPACE:
					_try_place_structure_at_cursor()
					get_viewport().set_input_as_handled()
				KEY_ESCAPE:
					build_mode_active = false
					selected_structure_id = ""
					build_cursor_offset = Vector2i(1, 0)
					input_handler.ui_blocking_input = false  # Re-enable player movement
					_add_message("Cancelled building", Color(0.7, 0.7, 0.7))
					_render_map()  # Clear cursor
					_render_all_entities()
					get_viewport().set_input_as_handled()
		# ESC to cancel build mode (if we somehow get here without structure selected)
		elif event.keycode == KEY_ESCAPE and build_mode_active:
			build_mode_active = false
			selected_structure_id = ""
			build_cursor_offset = Vector2i(1, 0)
			input_handler.ui_blocking_input = false  # Re-enable player movement
			_add_message("Cancelled building", Color(0.7, 0.7, 0.7))
			get_viewport().set_input_as_handled()
		# Restart game when R is pressed and player is dead
		elif event.keycode == KEY_R and player and not player.is_alive:
			_restart_game()
		# Return to main menu on ESC when player is dead
		elif event.keycode == KEY_ESCAPE and player and not player.is_alive:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

## Restart the game
func _restart_game() -> void:
	# Clear entities
	EntityManager.clear_entities()
	EntityManager.player = null
	
	# Reset turn manager
	TurnManager.current_turn = 0
	TurnManager.is_player_turn = true
	
	# Reload the scene
	get_tree().reload_current_scene()

## Update HUD display
func _update_hud() -> void:
	if not player:
		return

	# Update character info line
	if character_info_label:
		var day_suffix = _get_day_suffix(TurnManager.current_day)
		character_info_label.text = "Day %d%s - %s" % [TurnManager.current_day, day_suffix, TurnManager.time_of_day.capitalize()]

	# Update status line with health and survival
	if status_line:
		# Health with color coding
		var hp_text = "HP: %d/%d" % [player.current_health, player.max_health]
		var turn_text = "Turn: %d" % TurnManager.current_turn
		var time_text = TurnManager.time_of_day.capitalize()
		
		# Survival stats (if available)
		var survival_text = ""
		if player.survival:
			var s = player.survival
			var stam_text = "Stam: %d/%d" % [int(s.stamina), int(s.get_max_stamina())]
			var hunger_text = "Hun: %d%%" % int(s.hunger)
			var thirst_text = "Thr: %d%%" % int(s.thirst)
			var temp_text = "Tmp: %d°F" % int(s.temperature)
			survival_text = "  %s  %s  %s  %s" % [stam_text, hunger_text, thirst_text, temp_text]

		status_line.text = "%s%s  %s  %s" % [hp_text, survival_text, turn_text, time_text]

	# Update XP label if present
	if xp_label and player:
		var cur_xp = player.experience if "experience" in player else 0
		var next_xp = player.experience_to_next_level if "experience_to_next_level" in player else 100
		xp_label.text = "Exp: %d/%d" % [cur_xp, next_xp]
		
		# Color code based on most critical state
		var status_color = _get_status_color()
		status_line.add_theme_color_override("font_color", status_color)

	# Update location
	if location_label:
		var map_name = MapManager.current_map.map_id if MapManager.current_map else "Unknown"
		var formatted_name = map_name.replace("_", " ").capitalize()
		location_label.text = "◆ %s ◆" % formatted_name.to_upper()

## Get status line color based on player state
func _get_status_color() -> Color:
	if not player:
		return Color(0.7, 0.85, 0.7)  # Default green
	
	var hp_percent = float(player.current_health) / float(player.max_health)
	
	# Check survival critical states
	if player.survival:
		var s = player.survival
		# Temperature thresholds in Fahrenheit: freezing < 32°F, hyperthermia > 104°F
		if s.hunger <= 0 or s.thirst <= 0 or s.temperature < 32 or s.temperature > 104:
			return Color(1.0, 0.3, 0.3)  # Critical survival - red
		if s.hunger <= 25 or s.thirst <= 25:
			return Color(1.0, 0.5, 0.3)  # Severe survival - orange
	
	# Health-based colors
	if hp_percent > 0.75:
		return Color(0.7, 0.85, 0.7)  # Green - healthy
	elif hp_percent > 0.5:
		return Color(0.9, 0.9, 0.4)  # Yellow - wounded
	elif hp_percent > 0.25:
		return Color(1.0, 0.7, 0.3)  # Orange - hurt
	else:
		return Color(1.0, 0.4, 0.4)  # Red - critical

## Update survival-specific display elements
func _update_survival_display() -> void:
	if not player or not player.survival or not active_effects_label:
		return
	
	var s = player.survival
	var effects_list: Array[String] = []
	
	# Check for survival effects
	if s.hunger <= 50:
		effects_list.append(s.get_hunger_state().capitalize())
	if s.thirst <= 50:
		effects_list.append(s.get_thirst_state().capitalize())
	if s.temperature < 15 or s.temperature > 25:
		effects_list.append(s.get_temperature_state().capitalize())
	if s.fatigue >= 25:
		effects_list.append(s.get_fatigue_state().capitalize())
	
	# Check for nearby enemies
	var nearby_enemies = _count_nearby_enemies()
	if nearby_enemies > 0:
		effects_list.append("⚠ %d enem%s nearby" % [nearby_enemies, "y" if nearby_enemies == 1 else "ies"])
	
	# Update display
	if effects_list.size() > 0:
		active_effects_label.text = "EFFECTS: " + ", ".join(effects_list)
		# Color based on severity (temperature thresholds in °F: cold < 50, hot > 86)
		if s.hunger <= 25 or s.thirst <= 25 or s.temperature < 50 or s.temperature > 86 or nearby_enemies > 0:
			active_effects_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		else:
			active_effects_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	else:
		active_effects_label.text = "EFFECTS: None"
		active_effects_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	
	# Update abilities/toggles bar
	_update_toggles_display()

## Update the bottom bar toggles display
func _update_toggles_display() -> void:
	var ability1 = $HUD/BottomBar/Abilities/Ability1
	if ability1:
		var autopickup_status = "[G] Auto-pickup: %s" % ("ON" if auto_pickup_enabled else "OFF")
		var autopickup_color = Color(0.5, 0.9, 0.5) if auto_pickup_enabled else Color(0.6, 0.6, 0.6)
		ability1.text = autopickup_status
		ability1.add_theme_color_override("font_color", autopickup_color)

## Count enemies within aggro range of player
func _count_nearby_enemies() -> int:
	if not player:
		return 0
	
	var count = 0
	for entity in EntityManager.entities:
		if entity.is_alive and entity is Enemy:
			var distance = abs(entity.position.x - player.position.x) + abs(entity.position.y - player.position.y)
			if distance <= player.perception_range:
				count += 1
	
	return count

## Get ordinal suffix for a day number (1st, 2nd, 3rd, etc.)
func _get_day_suffix(day: int) -> String:
	if day >= 11 and day <= 13:
		return "th"
	match day % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
		_: return "th"

## Update message based on player position
func _update_message() -> void:
	if not message_log or not player or not MapManager.current_map:
		return

	var tile = MapManager.current_map.get_tile(player.position)

	if tile.tile_type == "stairs_down":
		_add_message("Standing on stairs (>) - Press > to descend", Color.CYAN)
	elif tile.tile_type == "stairs_up":
		_add_message("Standing on stairs (<) - Press < to ascend", Color.CYAN)

## Add a message to the message log
func _add_message(text: String, color: Color = Color.WHITE) -> void:
	if not message_log:
		return

	var color_hex = color.to_html(false)
	var formatted_message = "[color=#%s]%s[/color]\n" % [color_hex, text]
	message_log.append_text(formatted_message)

## Spawn enemies from map metadata
func _spawn_map_enemies() -> void:
	if not MapManager.current_map:
		return

	# Spawn enemies from metadata
	if MapManager.current_map.has_meta("enemy_spawns"):
		var enemy_spawns = MapManager.current_map.get_meta("enemy_spawns")
		for spawn_data in enemy_spawns:
			var enemy_id = spawn_data["enemy_id"]
			var spawn_pos = spawn_data["position"]
			EntityManager.spawn_enemy(enemy_id, spawn_pos)

	# Spawn NPCs from metadata
	if MapManager.current_map.has_meta("npc_spawns"):
		var npc_spawns = MapManager.current_map.get_meta("npc_spawns")
		for spawn_data in npc_spawns:
			EntityManager.spawn_npc(spawn_data)

## Render all entities on the current map
func _render_all_entities() -> void:
	for entity in EntityManager.entities:
		if entity.is_alive:
			renderer.render_entity(entity.position, entity.ascii_char, entity.color)

	# Render structures
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_on_map(map_id)
	for structure in structures:
		renderer.render_entity(structure.position, structure.ascii_char, structure.color)

## Find a valid spawn position for the player (walkable, not occupied)
func _find_valid_spawn_position() -> Vector2i:
	if not MapManager.current_map:
		return Vector2i(10, 10)  # Fallback

	@warning_ignore("integer_division")
	var center = Vector2i(MapManager.current_map.width / 2, MapManager.current_map.height / 2)

	# Try to find a position with open space around it (not just a single walkable tile)
	# Search in expanding rings from center
	var max_radius = max(MapManager.current_map.width, MapManager.current_map.height)

	for radius in range(0, max_radius):
		for angle in range(0, 360, 15):  # Check every 15 degrees
			var rad = deg_to_rad(angle)
			var offset = Vector2i(int(cos(rad) * radius), int(sin(rad) * radius))
			var pos = center + offset

			# Check if this position AND at least 3 adjacent tiles are walkable
			if _is_open_spawn_position(pos):
				return pos

	# Fallback: find ANY position with at least 1 walkable neighbor
	for y in range(MapManager.current_map.height):
		for x in range(MapManager.current_map.width):
			var pos = Vector2i(x, y)
			if _is_valid_spawn_position(pos):
				return pos

	# Absolute fallback
	push_warning("Could not find valid spawn position, using center anyway")
	return center

## Check if a position is open enough for player spawn (has walkable neighbors)
func _is_open_spawn_position(pos: Vector2i) -> bool:
	if not _is_valid_spawn_position(pos):
		return false

	# Count walkable adjacent tiles
	var walkable_neighbors = 0
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	for dir in directions:
		var neighbor_pos = pos + dir
		if MapManager.current_map.is_walkable(neighbor_pos):
			walkable_neighbors += 1

	# Require at least 2 walkable neighbors to ensure player isn't trapped
	return walkable_neighbors >= 2

## Check if a position is valid for player spawn
func _is_valid_spawn_position(pos: Vector2i) -> bool:
	if not MapManager.current_map:
		return false

	# Check bounds
	if pos.x < 0 or pos.x >= MapManager.current_map.width:
		return false
	if pos.y < 0 or pos.y >= MapManager.current_map.height:
		return false

	# Check if walkable
	if not MapManager.current_map.is_walkable(pos):
		return false

	# Check not occupied by enemy
	var blocking_entity = EntityManager.get_blocking_entity_at(pos)
	if blocking_entity != null:
		return false

	return true

## Setup UI element colors
func _setup_ui_colors() -> void:
	# Colors are now set in the .tscn file to match inventory/crafting screen style
	pass

## Render all ground items on the map (except under player)
func _render_ground_items() -> void:
	for entity in EntityManager.entities:
		if entity is GroundItemClass:
			# Don't render items under the player - player renders on top
			if player and entity.position == player.position:
				continue
			renderer.render_entity(entity.position, entity.ascii_char, entity.color)

## Called when inventory contents change - only refresh if already open
func _on_inventory_changed() -> void:
	if inventory_screen and inventory_screen.visible:
		inventory_screen.refresh()

## Toggle inventory screen visibility (called from input handler)
func toggle_inventory_screen() -> void:
	if inventory_screen:
		if inventory_screen.visible:
			inventory_screen.hide()
			input_handler.ui_blocking_input = false
		else:
			inventory_screen.open(player)
			input_handler.ui_blocking_input = true

## Open crafting screen (called from input handler)
func open_crafting_screen() -> void:
	if crafting_screen and player:
		crafting_screen.open(player)
		# Block player movement while crafting UI is open
		if input_handler:
			input_handler.ui_blocking_input = true
		# Center HUD focus if necessary
		_render_ground_items()
		_update_hud()
		get_viewport().set_input_as_handled()


func _on_crafting_closed() -> void:
	# Called when crafting screen closes to re-enable player input
	if input_handler:
		input_handler.ui_blocking_input = false

## Toggle build mode (called from input handler)
func toggle_build_mode() -> void:
	if build_mode_screen:
		if build_mode_screen.visible:
			build_mode_screen.hide()
			build_mode_active = false
			selected_structure_id = ""
			input_handler.ui_blocking_input = false
		else:
			build_mode_screen.open(player)
			input_handler.ui_blocking_input = true

## Open container screen (called from input handler)
func open_container_screen(structure: Structure) -> void:
	if container_screen and player:
		container_screen.open(player, structure)
		input_handler.ui_blocking_input = true

## Called when inventory screen is closed
func _on_inventory_closed() -> void:
	# Resume normal gameplay
	input_handler.ui_blocking_input = false

## Called when build mode screen is closed
func _on_build_mode_closed() -> void:
	# Only clear if we're not in placement mode
	if selected_structure_id == "":
		build_mode_active = false
		input_handler.ui_blocking_input = false

## Called when a structure is selected from build mode
func _on_structure_selected(structure_id: String) -> void:
	selected_structure_id = structure_id
	build_mode_active = true
	build_cursor_offset = Vector2i(1, 0)  # Reset cursor to right of player
	input_handler.ui_blocking_input = true  # Block player movement during placement
	var structure_name = StructureManager.structure_definitions[structure_id].get("name", structure_id) if StructureManager.structure_definitions.has(structure_id) else structure_id
	_add_message("BUILD MODE: %s - Arrow keys to move cursor, ENTER to place, ESC to cancel" % structure_name, Color(1.0, 1.0, 0.6))
	# Show initial cursor
	_update_build_cursor()

## Called when container screen is closed
func _on_container_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when shop is opened
func _on_shop_opened(shop_npc: NPC, shop_player: Player) -> void:
	if shop_screen and shop_player:
		shop_screen.open(shop_player, shop_npc)
		input_handler.ui_blocking_input = true

## Called when shop screen is closed
func _on_shop_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when an item is picked up
func _on_item_picked_up(item) -> void:
	_add_message("Picked up: %s" % item.name, Color(0.6, 0.9, 0.6))
	# Re-render to update ground items
	_render_ground_items()

## Called when an item is dropped
func _on_item_dropped(item, pos: Vector2i) -> void:
	_add_message("Dropped: %s" % item.name, Color(0.7, 0.7, 0.7))
	# Re-render to show dropped item
	renderer.render_entity(pos, item.ascii_char, item.get_color())
	_update_hud()

## Called when a message is logged from any system
func _on_message_logged(message: String) -> void:
	_add_message(message, Color.WHITE)

## Called when a structure is placed
func _on_structure_placed(structure: Structure) -> void:
	_add_message("Built: %s" % structure.name, Color(0.6, 0.9, 0.6))
	# Clear build mode state
	build_mode_active = false
	selected_structure_id = ""
	build_cursor_offset = Vector2i(1, 0)
	input_handler.ui_blocking_input = false  # Re-enable player movement
	# Re-render map to clear cursor and show the new structure
	_render_map()
	_render_all_entities()
	_render_ground_items()
	renderer.render_entity(player.position, "@", Color.YELLOW)

## Try to place a structure at the clicked screen position
func _try_place_structure_at_screen(screen_pos: Vector2) -> void:
	if not player or not MapManager.current_map:
		return

	# Convert screen position to tile position
	var tile_pos = renderer.screen_to_tile(screen_pos)

	# Attempt to place the structure
	var result = StructurePlacement.place_structure(selected_structure_id, tile_pos, player, MapManager.current_map)

	if result.success:
		_add_message(result.message, Color(0.6, 0.9, 0.6))
		_update_hud()  # Update inventory display
	else:
		_add_message(result.message, Color(0.9, 0.5, 0.5))

## Try to place a structure at the cursor position (keyboard mode)
func _try_place_structure_at_cursor() -> void:
	if not player or not MapManager.current_map:
		return

	var tile_pos = player.position + build_cursor_offset

	# Attempt to place the structure
	var result = StructurePlacement.place_structure(selected_structure_id, tile_pos, player, MapManager.current_map)

	if result.success:
		_add_message(result.message, Color(0.6, 0.9, 0.6))
		_update_hud()  # Update inventory display
		# Clear cursor after successful placement
		_render_map()
		_render_all_entities()
		_render_ground_items()
		renderer.render_entity(player.position, "@", Color.YELLOW)
	else:
		_add_message(result.message, Color(0.9, 0.5, 0.5))

## Update the build cursor visualization
func _update_build_cursor() -> void:
	if not player or not MapManager.current_map:
		return

	# Re-render map to clear old cursor
	_render_map()
	_render_all_entities()
	_render_ground_items()
	renderer.render_entity(player.position, "@", Color.YELLOW)

	# Render cursor at new position
	var cursor_pos = player.position + build_cursor_offset
	renderer.render_entity(cursor_pos, "X", Color(1.0, 1.0, 0.0, 0.8))
