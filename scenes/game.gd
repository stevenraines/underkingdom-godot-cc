extends Node2D

## Game - Main game scene
##
## Initializes the game, creates player, manages rendering and updates.

const ItemClass = preload("res://items/item.gd")
const ItemFactory = preload("res://items/item_factory.gd")
const GroundItemClass = preload("res://entities/ground_item.gd")
const ItemManagerScript = preload("res://autoload/item_manager.gd")
const JsonHelperScript = preload("res://autoload/json_helper.gd")
const Structure = preload("res://entities/structure.gd")
const StructurePlacement = preload("res://systems/structure_placement.gd")
const LightingSystemClass = preload("res://systems/lighting_system.gd")
const FogOfWarSystemClass = preload("res://systems/fog_of_war_system.gd")
const FOVSystemClass = preload("res://systems/fov_system.gd")
const FarmingSystemClass = preload("res://systems/farming_system.gd")

var player: Player
var renderer: ASCIIRenderer
var input_handler: Node
var inventory_screen: Control = null
var crafting_screen: Control = null
var build_mode_screen: Control = null
var container_screen: Control = null
var shop_screen: Control = null
var training_screen: Control = null
var npc_menu_screen: Control = null
var pause_menu: Control = null
var death_screen: Control = null
var character_sheet: Control = null
var level_up_screen: Control = null
var help_screen: Control = null
var world_map_screen: Control = null
var fast_travel_screen: Control = null
var rest_menu: Control = null
var spell_list_screen: Control = null
var auto_pickup_enabled: bool = true  # Toggle for automatic item pickup

# Rest system state
var is_resting: bool = false
var rest_turns_remaining: int = 0
var rest_type: String = ""  # "stamina", "time", or "custom"
var rest_turns_elapsed: int = 0  # Track turns for shelter HP restoration
var rest_hp_restored: int = 0  # Track total HP restored during rest for summary
var build_mode_active: bool = false
var selected_structure_id: String = ""
var build_cursor_offset: Vector2i = Vector2i(1, 0)  # Offset from player for placement cursor

# Performance optimization: Cache enemy light source positions
# Updated when enemies move, avoids scanning all entities every frame
var _enemy_light_cache: Array[Vector2i] = []
var _enemy_light_cache_dirty: bool = true

@onready var hud: CanvasLayer = $HUD
@onready var character_info_label: Label = $HUD/TopBar/CharacterInfo
@onready var status_line: Label = $HUD/TopBar/StatusLine
@onready var location_label: Label = $HUD/RightSidebar/LocationLabel
@onready var message_log: RichTextLabel = $HUD/RightSidebar/MessageLog
@onready var active_effects_label: Label = $HUD/BottomBar/ActiveEffects
@onready var xp_label: Label = $HUD/TopBar/XPLabel
@onready var gold_label: Label = $HUD/TopBar/GoldLabel
@onready var debug_info_label: Label = $HUD/BottomBar/DebugInfo

const InventoryScreenScene = preload("res://ui/inventory_screen.tscn")
const CraftingScreenScene = preload("res://ui/crafting_screen.tscn")
const BuildModeScreenScene = preload("res://ui/build_mode_screen.tscn")
const ContainerScreenScene = preload("res://ui/container_screen.tscn")
const ShopScreenScene = preload("res://ui/shop_screen.tscn")
const TrainingScreenScene = preload("res://ui/training_screen.tscn")
const NpcMenuScreenScene = preload("res://ui/npc_menu_screen.tscn")
const PauseMenuScene = preload("res://ui/pause_menu.tscn")
const DeathScreenScene = preload("res://ui/death_screen.tscn")
const SpellListScreenScene = preload("res://ui/spell_list_screen.tscn")

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

	# Create training screen
	_setup_training_screen()

	# Create NPC menu screen
	_setup_npc_menu_screen()

	# Create pause menu
	_setup_pause_menu()

	# Create death screen
	_setup_death_screen()

	# Create character sheet
	_setup_character_sheet()

	# Create level-up screen
	_setup_level_up_screen()

	# Create help screen
	_setup_help_screen()

	# Create world map screen
	_setup_world_map_screen()

	# Create fast travel screen
	_setup_fast_travel_screen()

	# Create rest menu
	_setup_rest_menu()

	# Create spell list screen
	_setup_spell_list_screen()

	# Only initialize new game if not loading from save
	if not GameManager.is_loading_save:
		print("[Game] New game initialization - world_seed: %d, world_name: '%s'" % [GameManager.world_seed, GameManager.world_name])

		# Start new game (only if not already started from main menu)
		if GameManager.world_seed == 0:
			print("[Game] World seed is 0, calling start_new_game()")
			GameManager.start_new_game()
		else:
			print("[Game] World seed already set, skipping start_new_game()")

		# Generate overworld
		print("[Game] Calling transition_to_map with seed: %d" % GameManager.world_seed)
		MapManager.transition_to_map("overworld")

		# Mark all towns as visited (available for fast travel from game start)
		GameManager.mark_all_towns_visited()

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
	else:
		# Loading from save - apply pending save data
		GameManager.is_loading_save = false

		# Create temporary player first (will be overwritten by save data)
		player = Player.new()
		input_handler.set_player(player)
		EntityManager.player = player

		# Apply the pending save data
		SaveManager.apply_pending_save()

		# Get the loaded player reference
		player = EntityManager.player
		input_handler.set_player(player)

	# Load initial chunks for overworld
	if MapManager.current_map and MapManager.current_map.chunk_based:
		ChunkManager.update_active_chunks(player.position)

	# Initial render
	_render_map()
	_render_all_entities()
	_render_ground_items()
	renderer.render_entity(player.position, "@", Color.YELLOW)
	renderer.center_camera(player.position)

	# Ensure the tree is not paused after loading/new game initialization
	var _tree = get_tree()
	if _tree:
		_tree.paused = false

	# Setup fog of war
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var chunk_based = MapManager.current_map.chunk_based if MapManager.current_map else false
	renderer.set_map_info(map_id, chunk_based, MapManager.current_map)
	renderer.set_fow_enabled(true)

	# Register light sources from structures
	_register_light_sources()

	# Calculate initial visibility (FOV + lighting)
	var player_light_radius = player.inventory.get_equipped_light_radius() if player.inventory else 0
	var visible_tiles = FOVSystemClass.calculate_visibility(player.position, player.perception_range, player_light_radius, MapManager.current_map)
	renderer.update_fov(visible_tiles, player.position)

	# Connect signals
	EventBus.player_moved.connect(_on_player_moved)
	EventBus.map_changed.connect(_on_map_changed)
	EventBus.tile_changed.connect(_on_tile_changed)
	EventBus.turn_advanced.connect(_on_turn_advanced)
	EventBus.entity_moved.connect(_on_entity_moved)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.attack_performed.connect(_on_attack_performed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_leveled_up.connect(_on_player_leveled_up)
	EventBus.survival_warning.connect(_on_survival_warning)
	EventBus.stamina_depleted.connect(_on_stamina_depleted)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.item_used.connect(_on_item_used)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_dropped.connect(_on_item_dropped)
	EventBus.message_logged.connect(_on_message_logged)
	EventBus.structure_placed.connect(_on_structure_placed)
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.training_opened.connect(_on_training_opened)
	EventBus.npc_menu_opened.connect(_on_npc_menu_opened)
	EventBus.combat_message.connect(_on_combat_message)
	EventBus.time_of_day_changed.connect(_on_time_of_day_changed)
	EventBus.harvesting_mode_changed.connect(_on_harvesting_mode_changed)
	EventBus.item_equipped.connect(_on_item_equipped)
	EventBus.item_unequipped.connect(_on_item_unequipped)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.entity_visual_changed.connect(_on_entity_visual_changed)
	FeatureManager.feature_spawned_enemy.connect(_on_feature_spawned_enemy)

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
	shop_screen.switch_to_training.connect(_on_shop_switch_to_training)

## Setup training screen
func _setup_training_screen() -> void:
	training_screen = TrainingScreenScene.instantiate()
	hud.add_child(training_screen)
	training_screen.closed.connect(_on_training_closed)
	training_screen.switch_to_trade.connect(_on_training_switch_to_trade)

## Setup NPC menu screen
func _setup_npc_menu_screen() -> void:
	npc_menu_screen = NpcMenuScreenScene.instantiate()
	hud.add_child(npc_menu_screen)
	npc_menu_screen.closed.connect(_on_npc_menu_closed)
	npc_menu_screen.trade_selected.connect(_on_npc_menu_trade_selected)
	npc_menu_screen.train_selected.connect(_on_npc_menu_train_selected)

## Setup pause menu
func _setup_pause_menu() -> void:
	pause_menu = PauseMenuScene.instantiate()
	hud.add_child(pause_menu)
	pause_menu.closed.connect(_on_pause_menu_closed)

## Setup death screen
func _setup_death_screen() -> void:
	death_screen = DeathScreenScene.instantiate()
	hud.add_child(death_screen)
	death_screen.load_save_requested.connect(_on_death_screen_load_save)
	death_screen.return_to_menu_requested.connect(_on_death_screen_return_to_menu)

## Setup character sheet
func _setup_character_sheet() -> void:
	print("[Game] Setting up character sheet from scene...")
	var CharacterSheetScene = load("res://ui/character_sheet.tscn")
	if CharacterSheetScene:
		character_sheet = CharacterSheetScene.instantiate()
		character_sheet.name = "CharacterSheet"
		hud.add_child(character_sheet)
		if character_sheet.has_signal("closed"):
			character_sheet.closed.connect(_on_character_sheet_closed)
		print("[Game] Character sheet scene instantiated and added to HUD")
	else:
		print("[Game] ERROR: Could not load character_sheet.tscn scene")

## Setup level-up screen
func _setup_level_up_screen() -> void:
	print("[Game] Setting up level-up screen from scene...")
	var LevelUpScreenScene = load("res://ui/level_up_screen.tscn")
	if LevelUpScreenScene:
		level_up_screen = LevelUpScreenScene.instantiate()
		level_up_screen.name = "LevelUpScreen"
		hud.add_child(level_up_screen)
		if level_up_screen.has_signal("closed"):
			level_up_screen.closed.connect(_on_level_up_screen_closed)
		print("[Game] Level-up screen scene instantiated and added to HUD")
	else:
		print("[Game] ERROR: Could not load level_up_screen.tscn scene")

## Setup help screen
func _setup_help_screen() -> void:
	print("[Game] Setting up help screen from scene...")
	var HelpScreenScene = load("res://ui/help_screen.tscn")
	if HelpScreenScene:
		help_screen = HelpScreenScene.instantiate()
		help_screen.name = "HelpScreen"
		hud.add_child(help_screen)
		if help_screen.has_signal("closed"):
			help_screen.closed.connect(_on_help_screen_closed)
		print("[Game] Help screen scene instantiated and added to HUD")
	else:
		print("[Game] ERROR: Could not load help_screen.tscn scene")

## Setup world map screen
func _setup_world_map_screen() -> void:
	print("[Game] Setting up world map screen from scene...")
	var WorldMapScreenScene = load("res://ui/world_map_screen.tscn")
	if WorldMapScreenScene:
		world_map_screen = WorldMapScreenScene.instantiate()
		world_map_screen.name = "WorldMapScreen"
		hud.add_child(world_map_screen)
		if world_map_screen.has_signal("closed"):
			world_map_screen.closed.connect(_on_world_map_closed)
		print("[Game] World map screen scene instantiated and added to HUD")
	else:
		print("[Game] ERROR: Could not load world_map_screen.tscn scene")

## Setup fast travel screen
func _setup_fast_travel_screen() -> void:
	print("[Game] Setting up fast travel screen from scene...")
	var FastTravelScreenScene = load("res://ui/fast_travel_screen.tscn")
	if FastTravelScreenScene:
		fast_travel_screen = FastTravelScreenScene.instantiate()
		fast_travel_screen.name = "FastTravelScreen"
		hud.add_child(fast_travel_screen)
		if fast_travel_screen.has_signal("closed"):
			fast_travel_screen.closed.connect(_on_fast_travel_closed)
		print("[Game] Fast travel screen scene instantiated and added to HUD")
	else:
		print("[Game] ERROR: Could not load fast_travel_screen.tscn scene")

## Setup rest menu
func _setup_rest_menu() -> void:
	print("[Game] Setting up rest menu from scene...")
	var RestMenuScene = load("res://ui/rest_menu.tscn")
	if RestMenuScene:
		rest_menu = RestMenuScene.instantiate()
		rest_menu.name = "RestMenu"
		hud.add_child(rest_menu)
		if rest_menu.has_signal("closed"):
			rest_menu.closed.connect(_on_rest_menu_closed)
		if rest_menu.has_signal("rest_requested"):
			rest_menu.rest_requested.connect(_on_rest_requested)
		print("[Game] Rest menu scene instantiated and added to HUD")
	else:
		print("[Game] ERROR: Could not load rest_menu.tscn scene")

## Setup spell list screen
func _setup_spell_list_screen() -> void:
	print("[Game] Setting up spell list screen from scene...")
	if SpellListScreenScene:
		spell_list_screen = SpellListScreenScene.instantiate()
		spell_list_screen.name = "SpellListScreen"
		hud.add_child(spell_list_screen)
		if spell_list_screen.has_signal("closed"):
			spell_list_screen.closed.connect(_on_spell_list_closed)
		print("[Game] Spell list screen scene instantiated and added to HUD")
	else:
		print("[Game] ERROR: Could not load spell_list_screen.tscn scene")

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
		var count = int(item_data.get("count", 1))
		var should_equip = item_data.get("equip", false)
		var item: Item = null

		# Support both formats:
		# 1. Template-based: {"template_id": "knife", "variants": {"material": "flint"}, "count": 1}
		# 2. Legacy/ID-based: {"id": "flint_knife", "count": 1}
		if item_data.has("template_id"):
			var template_id = item_data.get("template_id", "")
			var variants = item_data.get("variants", {})
			if template_id != "":
				item = ItemFactory.create_item(template_id, variants, count)
		else:
			var item_id = item_data.get("id", "")
			if item_id != "":
				var stacks = item_mgr.create_item_stacks(item_id, count)
				for it in stacks:
					if it:
						player.inventory.add_item(it)
						# Auto-equip first item of stack if flagged
						if should_equip and it == stacks[0] and it.is_equippable():
							player.equip_item(it)
				continue  # Already added via stacks

		if item:
			player.inventory.add_item(item)
			# Auto-equip if flagged
			if should_equip and item.is_equippable():
				player.equip_item(item)

	# Give player some starter recipes for testing
	player.learn_recipe("bandage")
	player.learn_recipe("flint_knife")
	player.learn_recipe("cooked_meat")

## Render the entire current map
func _render_map() -> void:
	if not MapManager.current_map:
		return

	renderer.clear_all()

	# Chunk-based rendering for overworld
	if MapManager.current_map.chunk_based:
		# Only render active chunks
		var active_chunk_coords = ChunkManager.get_active_chunk_coords()
		for chunk_coords in active_chunk_coords:
			var chunk = ChunkManager.get_chunk(chunk_coords)
			if chunk and chunk.is_loaded:
				renderer.render_chunk(chunk)
		return

	# Check if this is a dungeon map (has floor number in metadata or map_id contains "_floor_")
	var is_dungeon = MapManager.current_map.metadata.has("floor_number") or "_floor_" in MapManager.current_map.map_id

	# For dungeons, only render tiles that exist in the dictionary
	if is_dungeon:
		for pos in MapManager.current_map.tiles.keys():
			var tile = MapManager.current_map.tiles[pos]

			# Skip walls that aren't adjacent to any walkable tile
			if not tile.walkable and not tile.transparent:
				if not _is_wall_adjacent_to_walkable(pos):
					continue  # Don't render this wall

			renderer.render_tile(pos, tile.ascii_char)
	else:
		# Traditional rendering for non-dungeon, non-chunk maps
		for y in range(MapManager.current_map.height):
			for x in range(MapManager.current_map.width):
				var pos = Vector2i(x, y)
				var tile = MapManager.current_map.get_tile(pos)
				renderer.render_tile(pos, tile.ascii_char)


## Check if a wall position is adjacent to any walkable tile
func _is_wall_adjacent_to_walkable(pos: Vector2i) -> bool:
	var neighbors = [
		Vector2i(pos.x - 1, pos.y - 1), Vector2i(pos.x, pos.y - 1), Vector2i(pos.x + 1, pos.y - 1),
		Vector2i(pos.x - 1, pos.y),                                 Vector2i(pos.x + 1, pos.y),
		Vector2i(pos.x - 1, pos.y + 1), Vector2i(pos.x, pos.y + 1), Vector2i(pos.x + 1, pos.y + 1)
	]

	for neighbor in neighbors:
		if neighbor in MapManager.current_map.tiles:
			var neighbor_tile = MapManager.current_map.tiles[neighbor]
			if neighbor_tile.walkable:
				return true

	return false

## Called when player moves
func _on_player_moved(old_pos: Vector2i, new_pos: Vector2i) -> void:
	# Update chunk loading for overworld
	if MapManager.current_map and MapManager.current_map.chunk_based:
		ChunkManager.update_active_chunks(new_pos)

		# Re-render map for chunk-based worlds (new chunks may have loaded)
		# Only re-render if player crossed chunk boundary
		var old_chunk = ChunkManager.world_to_chunk(old_pos)
		var new_chunk = ChunkManager.world_to_chunk(new_pos)
		if old_chunk != new_chunk:
			_render_map()
			_render_all_entities()
			_render_ground_items()

	# In dungeons, wall visibility depends on player position
	# So we need to re-render the entire map when player moves
	var is_dungeon = MapManager.current_map and ("_floor_" in MapManager.current_map.map_id or MapManager.current_map.metadata.has("floor_number"))

	if is_dungeon:
		# Re-render entire map with updated wall visibility
		_render_map()
		_render_all_entities()

	# Clear old player position and render at new position
	renderer.clear_entity(old_pos)

	# Re-render any entity at old position that was hidden under player
	_render_entity_at(old_pos)

	# Re-render any ground item at old position that was hidden under player
	_render_ground_item_at(old_pos)

	# Re-render any feature at old position that was hidden under player
	_render_feature_at(old_pos)

	# Re-render any hazard at old position that was hidden under player
	_render_hazard_at(old_pos)

	renderer.render_entity(new_pos, "@", Color.YELLOW)
	renderer.center_camera(new_pos)

	# Update visibility (FOV + lighting)
	_update_visibility()

	# Auto-pickup items at new position
	_auto_pickup_items()

	# If player stepped onto a structure, show a contextual message
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_at(new_pos, map_id)
	if structures.size() > 0:
		# Show only the first structure's message to avoid spamming
		var structure = structures[0]
		# Use "in" for shelters (player is inside), "near" for other structures
		var preposition = "in" if structure.has_component("shelter") else "near"
		var entry_msg = "You are %s %s." % [preposition, structure.name]
		if structure.has_component("fire"):
			var fire = structure.get_component("fire")
			var lit_text = "lit" if fire.is_lit else "unlit"
			entry_msg += " The fire is %s." % lit_text
		_add_message(entry_msg, Color(0.9, 0.8, 0.6))

	# Check if standing on stairs and update message
	_update_message()

## Render any non-blocking entity at a specific position (crops, etc.)
## Skips rendering if player is at the position (player renders on top)
func _render_entity_at(pos: Vector2i) -> void:
	# Don't render entities under the player - player renders on top
	if player and player.position == pos:
		return

	for entity in EntityManager.entities:
		if entity.is_alive and entity.position == pos and not entity.blocks_movement:
			renderer.render_entity(pos, entity.ascii_char, entity.color)
			return  # Only render the first entity at this position


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


## Render a feature at a specific position if one exists
func _render_feature_at(pos: Vector2i) -> void:
	if FeatureManager.active_features.has(pos):
		var feature: Dictionary = FeatureManager.active_features[pos]
		var definition: Dictionary = feature.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "?")
		var color: Color = definition.get("color", Color.WHITE)
		renderer.render_entity(pos, ascii_char, color)


## Render a hazard at a specific position if one exists and is visible
func _render_hazard_at(pos: Vector2i) -> void:
	if HazardManager.has_visible_hazard(pos):
		var hazard: Dictionary = HazardManager.active_hazards[pos]
		var definition: Dictionary = hazard.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "^")
		var color: Color = definition.get("color", Color.RED)
		renderer.render_entity(pos, ascii_char, color)


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

## Toggle auto-open doors on/off
func toggle_auto_open_doors() -> void:
	GameManager.auto_open_doors = not GameManager.auto_open_doors
	var status = "ON" if GameManager.auto_open_doors else "OFF"
	_add_message("Auto-open doors: %s" % status, Color(0.8, 0.8, 0.6))
	_update_toggles_display()

## Called when map changes (dungeon transitions, etc.)
func _on_map_changed(map_id: String) -> void:
	print("[Game] === Map change START: %s ===" % map_id)

	# Skip entity handling during save load (SaveManager handles entities separately)
	if SaveManager.is_deserializing:
		print("[Game] Skipping entity handling during deserialization")
		# Still need to render the map
		if MapManager.current_map and MapManager.current_map.chunk_based and player:
			ChunkManager.update_active_chunks(player.position)
		_render_map()
		if player:
			renderer.center_camera(player.position)
		print("[Game] === Map change COMPLETE (deserializing) ===")
		return

	# Invalidate FOV cache since map changed
	print("[Game] 1/8 Invalidating FOV cache")
	FOVSystemClass.invalidate_cache()

	# Mark enemy light cache as dirty (new map has different enemies)
	_enemy_light_cache_dirty = true

	# Clear existing entities from EntityManager
	print("[Game] 2/8 Clearing entities")
	EntityManager.clear_entities()

	# Spawn or restore enemies for the new map
	print("[Game] 3/8 Spawning/restoring enemies")
	# Try to restore from saved state first (for visited maps)
	if not EntityManager.restore_entity_states_from_map(MapManager.current_map):
		# First visit - spawn from metadata
		_spawn_map_enemies()

	# Load chunks at current player position before rendering
	# Player position has been set before map transition in input_handler
	if MapManager.current_map and MapManager.current_map.chunk_based and player:
		print("[Game] 4/8 Loading chunks at player position %v" % player.position)
		ChunkManager.update_active_chunks(player.position)
		print("[Game] 4/8 Chunks loaded, active count: %d" % ChunkManager.active_chunks.size())

	# Render map and entities
	print("[Game] 5/8 Rendering map")
	_render_map()
	print("[Game] 6/8 Rendering entities")
	_render_all_entities()

	# Re-render player at new position
	print("[Game] 7/8 Rendering player")
	renderer.render_entity(player.position, "@", Color.YELLOW)
	renderer.center_camera(player.position)

	# Setup fog of war for new map
	var fow_map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var fow_chunk_based = MapManager.current_map.chunk_based if MapManager.current_map else false
	renderer.set_map_info(fow_map_id, fow_chunk_based, MapManager.current_map)

	# Update visibility (FOV + lighting)
	print("[Game] 8/8 Calculating visibility")
	_update_visibility()

	# Update message
	_update_message()
	print("[Game] === Map change COMPLETE ===")

## Called when a single tile changes (door opened/closed, etc.)
func _on_tile_changed(pos: Vector2i) -> void:
	if not MapManager.current_map:
		return

	# Re-render the changed tile (e.g., door opened/closed)
	var tile = MapManager.current_map.get_tile(pos)
	if tile:
		# Pass tile's color if it has one set (e.g., from biome data)
		if tile.color != Color.WHITE:
			renderer.render_tile(pos, tile.ascii_char, 0, tile.color)
		else:
			renderer.render_tile(pos, tile.ascii_char)

	# Recalculate visibility when tiles change (doors open/close affects LOS)
	_update_visibility()

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

	# Mark enemy light cache as dirty if an enemy moved (performance optimization)
	if entity is Enemy:
		_enemy_light_cache_dirty = true

	# Update target highlight if this entity is the current target
	if input_handler:
		var current_target = input_handler.get_current_target()
		if current_target and entity == current_target:
			update_target_highlight(current_target)

## Called when an entity's visual (char/color) changes (e.g., crop growth stage)
func _on_entity_visual_changed(pos: Vector2i) -> void:
	# Clear existing entity rendering at position
	renderer.clear_entity(pos)

	# Re-render the terrain tile first (e.g., tilled soil after harvest)
	if MapManager.current_map:
		var tile = MapManager.current_map.get_tile(pos)
		if tile:
			if tile.color != Color.WHITE:
				renderer.render_tile(pos, tile.ascii_char, 0, tile.color)
			else:
				renderer.render_tile(pos, tile.ascii_char)

	# If player is at this position, render player on top (not the entity)
	if player and player.position == pos:
		renderer.render_entity(pos, "@", Color.YELLOW)
		return

	# Re-render any entity at this position (will hide terrain underneath)
	_render_entity_at(pos)

	# Also handle ground items that might be at this position
	_render_ground_item_at(pos)


## Called when an entity dies
func _on_entity_died(entity: Entity) -> void:
	renderer.clear_entity(entity.position)

	# Check if it's the player
	if entity == player:
		EventBus.player_died.emit()
	else:
		var drop_messages: Array[String] = []
		var total_yields: Dictionary = {}

		if entity and entity is Enemy:
			# Process yields array (direct item drops defined on enemy)
			if entity.yields.size() > 0:
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

			# Process loot table (referenced loot table for additional drops)
			if entity.loot_table != "":
				var loot_drops = LootTableManager.generate_loot(entity.loot_table)
				for drop in loot_drops:
					var item_id = drop.get("item_id", "")
					var count = drop.get("count", 1)
					if item_id != "" and count > 0:
						if item_id in total_yields:
							total_yields[item_id] += count
						else:
							total_yields[item_id] = count

			# Create and spawn items as ground items
			for item_id in total_yields:
				var count = total_yields[item_id]
				var stacks = ItemManager.create_item_stacks(item_id, count)
				for it in stacks:
					EntityManager.spawn_ground_item(it, entity.position)
				var item_data = ItemManager.get_item_data(item_id)
				if item_data:
					drop_messages.append("%d %s" % [count, item_data.get("name", item_id)])

			if drop_messages.size() > 0:
				_add_message("Dropped: %s" % ", ".join(drop_messages), Color(0.8, 0.8, 0.6))
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
		player.gain_experience(xp_gain)
		_add_message("Gained %d XP." % xp_gain, Color(0.6, 0.9, 0.6))

	_update_hud()

## Called when a combat message is emitted (hazards, traps, etc.)
func _on_combat_message(message: String, color: Color) -> void:
	print("[DEBUG] _on_combat_message received: '%s'" % message)
	_add_message(message, color)


## Called when a feature spawns an enemy (e.g., sarcophagus releasing a skeleton)
func _on_feature_spawned_enemy(enemy_id: String, spawn_position: Vector2i) -> void:
	print("[Game] Feature spawned enemy: %s at %v" % [enemy_id, spawn_position])
	# Find a valid spawn position near the feature (not on the feature itself)
	var spawn_pos = _find_nearby_spawn_position(spawn_position)
	if spawn_pos != Vector2i(-1, -1):
		var enemy = EntityManager.spawn_enemy(enemy_id, spawn_pos)
		if enemy:
			_add_message("A %s emerges!" % enemy.name, Color.ORANGE_RED)
			_render_all_entities()
	else:
		push_warning("[Game] Could not find spawn position for feature enemy near %v" % spawn_position)


## Find a valid spawn position near a given position
func _find_nearby_spawn_position(center: Vector2i) -> Vector2i:
	# Check adjacent tiles for valid spawn position
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]
	for dir in directions:
		var pos = center + dir
		if MapManager.current_map and MapManager.current_map.is_walkable(pos):
			# Make sure no blocking entity is already there (player is not in entities array)
			if not EntityManager.get_blocking_entity_at(pos) and player.position != pos:
				return pos
	return Vector2i(-1, -1)


## Called when player dies
func _on_player_died() -> void:
	_add_message("", Color.WHITE)  # Blank line
	_add_message("*** YOU HAVE DIED ***", Color.RED)

	# Collect player stats for death screen
	var player_stats = {
		"turns": TurnManager.current_turn,
		"experience": player.experience if player else 0,
		"gold": player.gold if player else 0,
		"recipes_discovered": player.known_recipes.size() if player else 0,
		"structures_built": 0,  # TODO: Track this if needed
		"death_cause": player.death_cause if player else "",
		"death_method": player.death_method if player else "",
		"death_location": player.death_location if player else ""
	}

	# Show death screen with stats
	if death_screen:
		death_screen.open(player_stats)

## Called when player levels up
func _on_player_leveled_up(new_level: int, skill_points_gained: int, gained_ability_point: bool) -> void:
	# Display congratulatory message with banner-style formatting
	_add_message("", Color.WHITE)  # Blank line
	_add_message("*** LEVEL UP! ***", Color(1.0, 0.85, 0.3))  # Gold
	_add_message("You have reached Level %d!" % new_level, Color(0.7, 0.95, 0.7))  # Light green
	_add_message("Gained %d skill point%s." % [skill_points_gained, "s" if skill_points_gained != 1 else ""], Color(0.7, 0.85, 0.95))  # Light blue

	if gained_ability_point:
		_add_message("You may increase one ability score!", Color(0.95, 0.7, 0.85))  # Light pink

	_add_message("Open Character Screen (P) to spend points.", Color.WHITE)
	_add_message("", Color.WHITE)  # Blank line

	_update_hud()

## Handle load save request from death screen
func _on_death_screen_load_save(slot: int) -> void:
	# Load the save
	var success = SaveManager.load_game(slot)
	if success:
		# Indicate we're loading a save so _ready applies pending save data
		GameManager.is_loading_save = true
		# Reload the game scene to reset everything
		get_tree().reload_current_scene()
	else:
		_add_message("Failed to load save!", Color.RED)

## Handle return to menu from death screen
func _on_death_screen_return_to_menu() -> void:
	# Ensure game is unpaused before transitioning to main menu
	get_tree().paused = false
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

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
		# Open pause menu on ESC when player is alive and no other UI is open
		elif event.keycode == KEY_ESCAPE and player and player.is_alive:
			if not input_handler.ui_blocking_input and pause_menu and not pause_menu.visible:
				_open_pause_menu()
				get_viewport().set_input_as_handled()

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

	# Update character info line with calendar data and weather
	if character_info_label:
		# Format: "Moonday, 15th Bloom - Dawn (Year 342) | ☀ Clear"
		var date_str = CalendarManager.get_short_date_string()
		var time_str = TurnManager.time_of_day.capitalize()
		var year_str = "Year %d" % CalendarManager.current_year

		# Add weather info if on overworld
		var weather_text = ""
		if WeatherManager.should_apply_weather_effects():
			var weather_char = WeatherManager.get_current_weather_char()
			var weather_name = WeatherManager.get_current_weather_name()
			weather_text = " | %s %s" % [weather_char, weather_name]

		character_info_label.text = "%s - %s (%s)%s" % [date_str, time_str, year_str, weather_text]

	# Update status line with health and survival
	if status_line:
		# Health with color coding
		var hp_text = "HP: %d/%d" % [player.current_health, player.max_health]
		var turn_text = "Turn: %d" % TurnManager.current_turn

		# Survival stats (if available)
		var survival_text = ""
		if player.survival:
			var s = player.survival
			var stam_text = "Stam: %d/%d" % [int(s.stamina), int(s.get_max_stamina())]
			var mana_text = "Mana: %d/%d" % [int(s.mana), int(s.get_max_mana())]
			var hunger_text = "Hun: %d%%" % int(s.hunger)
			var thirst_text = "Thr: %d%%" % int(s.thirst)
			# Show outside temp → player temp (with warmth adjustment)
			# Use roundi() to match character sheet display (%.0f rounds)
			var env_temp = roundi(s.get_environmental_temperature())
			var player_temp = roundi(s.temperature)
			var temp_text = "Tmp: %d→%d°F" % [env_temp, player_temp]
			survival_text = "  %s  %s  %s  %s  %s" % [stam_text, mana_text, hunger_text, thirst_text, temp_text]

		# Light source indicator
		var light_text = ""
		if player.inventory:
			var light_item = _get_equipped_light_source()
			if light_item:
				if light_item.is_lit:
					light_text = "  [Torch: LIT]"
				else:
					light_text = "  [Torch: OUT]"

		status_line.text = "%s%s%s  %s" % [hp_text, survival_text, light_text, turn_text]

	# Update XP label if present
	if xp_label and player:
		var cur_level = player.level if "level" in player else 0
		var cur_xp = player.experience if "experience" in player else 0
		var next_xp = player.experience_to_next_level if "experience_to_next_level" in player else 100
		xp_label.text = "Lvl %d | Exp: %d/%d" % [cur_level, cur_xp, next_xp]

	# Update gold label if present
	if gold_label and player:
		gold_label.text = "Gold: %d" % player.gold

		# Color code based on most critical state
		var status_color = _get_status_color()
		status_line.add_theme_color_override("font_color", status_color)

	# Update location
	if location_label:
		var map_name = MapManager.current_map.map_id if MapManager.current_map else "Unknown"
		var formatted_name = map_name.replace("_", " ").capitalize()
		var location_text = "◆ %s ◆" % formatted_name.to_upper()

		# Add biome and ground type for overworld
		if MapManager.current_map and MapManager.current_map.map_id == "overworld" and player:
			# Get biome at player position
			var biome_data = BiomeGenerator.get_biome_at(player.position.x, player.position.y, GameManager.world_seed)
			var biome_name = biome_data.get("biome_name", "Unknown")
			var biome_id = biome_data.get("biome_name", "")
			biome_name = biome_name.replace("_", " ").capitalize()

			# Get ground character name
			var tile = MapManager.current_map.get_tile(player.position)
			var ground_char = tile.ascii_char
			var ground_name = _get_terrain_name(ground_char, biome_id)

			# Format as "Biome, Ground"
			location_text += "\n%s, %s" % [biome_name, ground_name]

		location_label.text = location_text

	# Update debug info
	if debug_info_label and player:
		# Calculate chunk position
		const WorldChunk = preload("res://maps/world_chunk.gd")
		var chunk_size = WorldChunk.CHUNK_SIZE
		var chunk_pos = Vector2i(
			floor(float(player.position.x) / chunk_size),
			floor(float(player.position.y) / chunk_size)
		)

		# Get screen position of player (camera center)
		var screen_pos = Vector2i(0, 0)
		if renderer and renderer.camera:
			var viewport_pos = renderer.camera.get_screen_center_position()
			screen_pos = Vector2i(int(viewport_pos.x), int(viewport_pos.y))

		debug_info_label.text = "Chunk: (%d,%d) | Tile: (%d,%d) | Screen Y: %d" % [
			chunk_pos.x, chunk_pos.y,
			player.position.x, player.position.y,
			screen_pos.y
		]

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

## Get the equipped light source item (torch, lantern, etc.)
## Returns null if no light source is equipped
func _get_equipped_light_source() -> Item:
	if not player or not player.inventory:
		return null

	# Check off-hand first (typical light source slot)
	var off_hand = player.inventory.get_equipped("off_hand")
	if off_hand and off_hand.provides_light:
		return off_hand

	# Check main hand
	var main_hand = player.inventory.get_equipped("main_hand")
	if main_hand and main_hand.provides_light:
		return main_hand

	return null

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
	
	# Check for nearby enemies and show target info
	var nearby_enemies = _count_nearby_enemies()
	var target_info = _get_target_info()
	if target_info != "":
		effects_list.append(target_info)
	elif nearby_enemies > 0:
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

	var ability2 = $HUD/BottomBar/Abilities/Ability2
	if ability2:
		var autodoor_status = "[O] Auto-door: %s" % ("ON" if GameManager.auto_open_doors else "OFF")
		var autodoor_color = Color(0.5, 0.9, 0.5) if GameManager.auto_open_doors else Color(0.6, 0.6, 0.6)
		ability2.text = autodoor_status
		ability2.add_theme_color_override("font_color", autodoor_color)

	# Harvesting mode indicator
	var ability3 = $HUD/BottomBar/Abilities/Ability3
	if ability3:
		var is_harvesting = input_handler and input_handler.is_harvesting()
		if is_harvesting:
			ability3.text = "HARVESTING"
			ability3.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # Gold/yellow
			ability3.visible = true
		else:
			ability3.visible = false

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


## Get info string for the currently targeted enemy
func _get_target_info() -> String:
	if not input_handler:
		return ""

	var target = input_handler.get_current_target()
	if not target or not is_instance_valid(target) or not target.is_alive:
		return ""

	var distance = abs(target.position.x - player.position.x) + abs(target.position.y - player.position.y)
	var hp_percent = int((float(target.current_health) / float(target.max_health)) * 100)

	return "🎯 %s (HP:%d%% Dist:%d)" % [target.name, hp_percent, distance]


## Update target highlight on the map
func update_target_highlight(target: Entity) -> void:
	# Use border highlight for targeting
	if renderer:
		if target and is_instance_valid(target) and target.is_alive:
			# Render a red border around the target
			renderer.render_highlight_border(target.position, Color(1.0, 0.3, 0.3))  # Red for target
		else:
			# Clear highlight if no valid target
			renderer.clear_highlight()

	# Update HUD to show target info
	_update_hud()


## Update look mode highlight on the map
func update_look_highlight(look_pos: Vector2i) -> void:
	# Use border highlight for look mode
	if renderer:
		if look_pos.x >= 0 and look_pos.y >= 0:
			# Render a cyan border at the look position
			renderer.render_highlight_border(look_pos, Color(0.4, 1.0, 1.0))  # Cyan for look
		else:
			# Clear highlight when exiting look mode
			renderer.clear_highlight()


## Get ordinal suffix for a day number (1st, 2nd, 3rd, etc.)
func _get_day_suffix(day: int) -> String:
	if day >= 11 and day <= 13:
		return "th"
	match day % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
		_: return "th"

## Get display name for terrain character
func _get_terrain_name(terrain_char: String, biome_id: String = "") -> String:
	# For floor tiles, use biome-specific names
	if terrain_char == ".":
		var biome_floor_names = {
			"beach": "Sand",
			"snow": "Snow",
			"snow_mountains": "Snow",
			"tundra": "Tundra",
			"barren_rock": "Rock",
			"ocean": "Water",
			"deep_ocean": "Water",
			"swamp": "Mud",
			"marsh": "Mud"
		}
		return biome_floor_names.get(biome_id, "Dirt")

	# Standard terrain names
	var terrain_names = {
		"#": "Wall",
		"░": "Dirt Road",
		"T": "Tree",
		"\"": "Grass",
		",": "Grass",
		"^": "Rocky",
		"*": "Snow",
		"·": "Gravel Road",
		"~": "Water",
		"≈": "Deep Water",
		"▲": "Mountain",
		"◆": "Rock",
		"◊": "Iron Ore",
		">": "Stairs Down",
		"<": "Stairs Up",
		"+": "Door",
		"▪": "Cobblestone Road",
		"=": "Wooden Bridge",
		"≡": "Stone Bridge"
	}
	return terrain_names.get(terrain_char, "Unknown")

## Update message based on player position
func _update_message() -> void:
	if not message_log or not player or not MapManager.current_map:
		return

	var tile = MapManager.current_map.get_tile(player.position)

	if tile.tile_type == "stairs_down":
		_add_message("Standing on stairs (>) - Press > to descend", Color.CYAN)
	elif tile.tile_type == "stairs_up":
		_add_message("Standing on stairs (<) - Press < to ascend", Color.CYAN)
	elif tile.tile_type == "dungeon_entrance":
		var dungeon_name = tile.get_meta("dungeon_name", "Dungeon")
		_add_message("Standing on %s entrance - Press > to enter" % dungeon_name, Color.CYAN)

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

	# Spawn enemies from metadata dictionary (used by dungeon generators)
	if MapManager.current_map.metadata.has("enemy_spawns"):
		var enemy_spawns = MapManager.current_map.metadata["enemy_spawns"]
		for spawn_data in enemy_spawns:
			var enemy_id = spawn_data["enemy_id"]
			var spawn_pos = spawn_data["position"]
			EntityManager.spawn_enemy(enemy_id, spawn_pos)
	# Fallback: check Node meta (used by older overworld generation)
	elif MapManager.current_map.has_meta("enemy_spawns"):
		var enemy_spawns = MapManager.current_map.get_meta("enemy_spawns")
		for spawn_data in enemy_spawns:
			var enemy_id = spawn_data["enemy_id"]
			var spawn_pos = spawn_data["position"]
			EntityManager.spawn_enemy(enemy_id, spawn_pos)

	# Spawn NPCs from metadata dictionary (used by dungeon/town generators)
	if MapManager.current_map.metadata.has("npc_spawns"):
		var npc_spawns = MapManager.current_map.metadata["npc_spawns"]
		for spawn_data in npc_spawns:
			EntityManager.spawn_npc(spawn_data)
	# Fallback: check Node meta (used by older generation)
	elif MapManager.current_map.has_meta("npc_spawns"):
		var npc_spawns = MapManager.current_map.get_meta("npc_spawns")
		for spawn_data in npc_spawns:
			EntityManager.spawn_npc(spawn_data)

## Render all entities on the current map
func _render_all_entities() -> void:
	# Get current target for highlighting
	var current_target = input_handler.get_current_target() if input_handler else null

	# Get player position to skip rendering entities at player's tile
	var player_pos = player.position if player else Vector2i(-1, -1)

	for entity in EntityManager.entities:
		if entity.is_alive:
			# Skip entities at player's position - player renders on top
			if entity.position == player_pos:
				continue
			var render_color = entity.color
			# Highlight targeted enemy with a distinct color
			if entity == current_target:
				# Use a bright cyan/white pulsing effect by brightening the color
				render_color = Color(1.0, 0.4, 0.4)  # Red tint for targeted enemy
			renderer.render_entity(entity.position, entity.ascii_char, render_color)

	# Render structures (skip player position)
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var structures = StructureManager.get_structures_on_map(map_id)
	for structure in structures:
		if structure.position != player_pos:
			renderer.render_entity(structure.position, structure.ascii_char, structure.color)

	# Render dungeon features (skip player position)
	_render_features(player_pos)

	# Render dungeon hazards (visible ones only, skip player position)
	_render_hazards(player_pos)


## Render dungeon features (chests, altars, etc.)
func _render_features(skip_pos: Vector2i = Vector2i(-1, -1)) -> void:
	for pos in FeatureManager.active_features:
		# Skip rendering at player position
		if pos == skip_pos:
			continue
		var feature: Dictionary = FeatureManager.active_features[pos]
		var definition: Dictionary = feature.get("definition", {})
		var ascii_char: String = definition.get("ascii_char", "?")
		var color: Color = definition.get("color", Color.WHITE)
		renderer.render_entity(pos, ascii_char, color)


## Render dungeon hazards (only visible/detected ones)
func _render_hazards(skip_pos: Vector2i = Vector2i(-1, -1)) -> void:
	for pos in HazardManager.active_hazards:
		# Skip rendering at player position
		if pos == skip_pos:
			continue
		# Only render if hazard is visible (detected or not hidden)
		if HazardManager.has_visible_hazard(pos):
			var hazard: Dictionary = HazardManager.active_hazards[pos]
			var definition: Dictionary = hazard.get("definition", {})
			var ascii_char: String = definition.get("ascii_char", "^")
			var color: Color = definition.get("color", Color.RED)
			renderer.render_entity(pos, ascii_char, color)


## Find a valid spawn position for the player (walkable, not occupied)
func _find_valid_spawn_position() -> Vector2i:
	if not MapManager.current_map:
		return Vector2i(10, 10)  # Fallback

	@warning_ignore("integer_division")
	var center: Vector2i
	if MapManager.current_map.chunk_based:
		# For chunk-based maps, use player_spawn metadata if available
		if MapManager.current_map.has_meta("player_spawn"):
			var spawn_pos = MapManager.current_map.get_meta("player_spawn")
			print("[Game] Player spawn metadata: %v" % spawn_pos)

			# IMPORTANT: Load the chunk first so town structures are generated
			ChunkManager.update_active_chunks(spawn_pos)

			# Verify the spawn position is walkable after town generation
			# If not, search for a nearby valid position
			if _is_valid_spawn_position(spawn_pos):
				print("[Game] Spawn position valid: %v" % spawn_pos)
				return spawn_pos
			else:
				print("[Game] Spawn position invalid (blocked), searching nearby...")
				# Search in expanding rings around the intended spawn
				for radius in range(1, 20):
					for angle in range(0, 360, 30):
						var rad = deg_to_rad(angle)
						var offset = Vector2i(int(cos(rad) * radius), int(sin(rad) * radius))
						var test_pos = spawn_pos + offset
						if _is_open_spawn_position(test_pos):
							print("[Game] Found valid spawn at: %v (offset %v from intended)" % [test_pos, offset])
							return test_pos
				# If still no valid position, continue to normal search below
				print("[Game] No valid position near spawn metadata, using fallback search")
				center = spawn_pos
		else:
			# Fallback: start in chunk 5,5 (center area near town)
			center = Vector2i(5 * 32 + 10, 5 * 32 + 10)
	else:
		center = Vector2i(MapManager.current_map.width / 2, MapManager.current_map.height / 2)

	# Try to find a position with open space around it (not just a single walkable tile)
	# Search in expanding rings from center
	# Use reasonable radius for chunk-based maps (don't search the entire 10000x10000 world!)
	var max_radius = 50 if MapManager.current_map.chunk_based else max(MapManager.current_map.width, MapManager.current_map.height)

	for radius in range(0, max_radius):
		for angle in range(0, 360, 15):  # Check every 15 degrees
			var rad = deg_to_rad(angle)
			var offset = Vector2i(int(cos(rad) * radius), int(sin(rad) * radius))
			var pos = center + offset

			# Check if this position AND at least 3 adjacent tiles are walkable
			if _is_open_spawn_position(pos):
				return pos

	# Fallback: search a limited area for chunk-based maps
	if MapManager.current_map.chunk_based:
		# Search a 100x100 area around center
		for dy in range(-50, 50):
			for dx in range(-50, 50):
				var pos = center + Vector2i(dx, dy)
				if _is_valid_spawn_position(pos):
					return pos
	else:
		# For dungeons, search entire map
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
			# Lit light sources get a bright orange/yellow color
			var render_color = entity.color
			if entity.item and entity.item.provides_light and entity.item.is_lit:
				render_color = Color(1.0, 0.7, 0.2)  # Bright orange-yellow for lit torches
			renderer.render_entity(entity.position, entity.ascii_char, render_color)

## Called when inventory contents change - only refresh if already open
func _on_inventory_changed() -> void:
	if inventory_screen and inventory_screen.visible:
		inventory_screen.refresh()

## Called when an item is used (consumed) - update HUD immediately
func _on_item_used(_item, _result: Dictionary) -> void:
	_update_hud()

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

## Toggle world map (called from input handler)
func toggle_world_map() -> void:
	if world_map_screen:
		if world_map_screen.visible:
			world_map_screen.close()
			input_handler.ui_blocking_input = false
		else:
			world_map_screen.open()
			input_handler.ui_blocking_input = true

## Toggle spell list (called from input handler via Shift+M)
func toggle_spell_list() -> void:
	if spell_list_screen and player:
		if spell_list_screen.visible:
			spell_list_screen.hide()
			input_handler.ui_blocking_input = false
		else:
			spell_list_screen.open(player)
			input_handler.ui_blocking_input = true

## Open container screen (called from input handler)
func open_container_screen(structure: Structure) -> void:
	if container_screen and player:
		container_screen.open(player, structure)
		input_handler.ui_blocking_input = true

## Open pause menu (called from ESC key)
func _open_pause_menu() -> void:
	if pause_menu:
		pause_menu.open(true)  # true = save mode
		input_handler.ui_blocking_input = true

## Open character sheet (called from P key)
func open_character_sheet() -> void:
	print("[Game] open_character_sheet called - character_sheet: ", character_sheet, " player: ", player)
	if character_sheet and player:
		print("[Game] Opening character sheet UI")
		character_sheet.open(player)
		input_handler.ui_blocking_input = true
	else:
		print("[Game] ERROR: character_sheet or player is null")

## Open help screen (called from ? or F1 key)
func open_help_screen() -> void:
	print("[Game] open_help_screen called - help_screen: ", help_screen)
	if help_screen:
		print("[Game] Opening help screen UI")
		help_screen.open()
		input_handler.ui_blocking_input = true
	else:
		print("[Game] ERROR: help_screen is null")

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

## Called when training is opened
func _on_training_opened(trainer_npc: NPC, train_player: Player) -> void:
	if training_screen and train_player:
		training_screen.open(train_player, trainer_npc)
		input_handler.ui_blocking_input = true

## Called when training screen is closed
func _on_training_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when shop screen requests switch to training
func _on_shop_switch_to_training(npc: NPC, switch_player: Player) -> void:
	if training_screen and switch_player:
		training_screen.open(switch_player, npc)
		input_handler.ui_blocking_input = true

## Called when training screen requests switch to trade
func _on_training_switch_to_trade(npc: NPC, switch_player: Player) -> void:
	if shop_screen and switch_player:
		shop_screen.open(switch_player, npc)
		input_handler.ui_blocking_input = true

## Called when NPC menu is opened (NPC with multiple services)
func _on_npc_menu_opened(menu_npc: NPC, menu_player: Player) -> void:
	if npc_menu_screen and menu_player:
		npc_menu_screen.open(menu_player, menu_npc)
		input_handler.ui_blocking_input = true

## Called when NPC menu screen is closed
func _on_npc_menu_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when trade is selected from NPC menu
func _on_npc_menu_trade_selected(menu_npc: NPC, menu_player: Player) -> void:
	# Open shop screen
	if shop_screen and menu_player:
		shop_screen.open(menu_player, menu_npc)
		input_handler.ui_blocking_input = true

## Called when train is selected from NPC menu
func _on_npc_menu_train_selected(menu_npc: NPC, menu_player: Player) -> void:
	# Open training screen
	if training_screen and menu_player:
		training_screen.open(menu_player, menu_npc)
		input_handler.ui_blocking_input = true

## Called when harvesting mode changes
func _on_harvesting_mode_changed(is_active: bool) -> void:
	_update_toggles_display()
	if is_active:
		_add_message("Entered harvesting mode - keep pressing direction to continue", Color(0.6, 0.9, 0.6))


## Called when weather changes
func _on_weather_changed(_old_weather: String, _new_weather: String, message: String) -> void:
	if message != "":
		# Get weather color for the message
		var weather_color = WeatherManager.get_current_weather_color()
		_add_message(message, weather_color)

## Called when time of day changes - refresh FOV/lighting and handle shop door locking
func _on_time_of_day_changed(new_time: String) -> void:
	# Refresh FOV and lighting since sun position affects visibility
	if player and MapManager.current_map:
		var player_light_radius = player.inventory.get_equipped_light_radius() if player.inventory else 0
		var visible_tiles = FOVSystemClass.calculate_visibility(player.position, player.perception_range, player_light_radius, MapManager.current_map)
		renderer.update_fov(visible_tiles, player.position)

	# Handle shop door locking on overworld
	if not MapManager.current_map or MapManager.current_map.map_id != "overworld":
		return

	var town_center = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	if town_center == Vector2i(-1, -1):
		return

	# Shop door position: shop is 5x5 centered on town_center, door at x=2, y=4 of shop
	# shop_start = town_center - Vector2i(2, 2)
	# door at shop_start + Vector2i(2, 4) = town_center + Vector2i(0, 2)
	var shop_door_pos = town_center + Vector2i(0, 2)

	if new_time == "night" or new_time == "midnight":
		_lock_shop_door_if_player_outside(shop_door_pos, town_center)
	elif new_time == "dawn":
		_unlock_shop_door(shop_door_pos)

## Lock shop door at night if player is outside
func _lock_shop_door_if_player_outside(door_pos: Vector2i, town_center: Vector2i) -> void:
	var tile = ChunkManager.get_tile(door_pos)
	if not tile or tile.tile_type != "door":
		return

	# Check if player is inside the shop (5x5 area centered on town_center)
	if player:
		var shop_start = town_center - Vector2i(2, 2)
		var shop_end = shop_start + Vector2i(4, 4)  # Inclusive bounds
		var player_inside = (player.position.x >= shop_start.x and player.position.x <= shop_end.x and
							 player.position.y >= shop_start.y and player.position.y <= shop_end.y)

		if player_inside:
			# Player is inside shop, don't lock them in
			return

	# Lock the door
	if not tile.is_locked:
		tile.is_locked = true
		tile.lock_id = "shop_door"
		tile.lock_level = 3  # Moderate difficulty
		# Close the door if open
		if tile.is_open:
			tile.close_door()
		EventBus.tile_changed.emit(door_pos)
		_add_message("The shop door locks for the night.", Color.GRAY)

## Unlock shop door at dawn
func _unlock_shop_door(door_pos: Vector2i) -> void:
	var tile = ChunkManager.get_tile(door_pos)
	if not tile or tile.tile_type != "door":
		return

	if tile.is_locked and tile.lock_id == "shop_door":
		tile.is_locked = false
		EventBus.tile_changed.emit(door_pos)
		_add_message("The shop door unlocks at dawn.", Color.GRAY)

## Called when pause menu is closed
func _on_pause_menu_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when character sheet is closed
func _on_character_sheet_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when level-up screen is closed
func _on_level_up_screen_closed() -> void:
	input_handler.ui_blocking_input = false
	# Reopen character sheet (it was hidden when level-up opened)
	if character_sheet and player:
		character_sheet.open(player)
	# Refresh HUD
	_update_hud()

## Called when help screen is closed
func _on_help_screen_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when world map is closed
func _on_world_map_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when spell list is closed
func _on_spell_list_closed() -> void:
	input_handler.ui_blocking_input = false

## Toggle fast travel screen (called from input handler)
func toggle_fast_travel() -> void:
	if fast_travel_screen:
		if fast_travel_screen.visible:
			fast_travel_screen.close()
			input_handler.ui_blocking_input = false
		else:
			fast_travel_screen.open()
			input_handler.ui_blocking_input = true

## Called when fast travel screen is closed
func _on_fast_travel_closed() -> void:
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
	var render_color = item.get_color()
	# Lit light sources get a bright orange/yellow color
	if item.provides_light and item.is_lit:
		render_color = Color(1.0, 0.7, 0.2)
		# Update visibility since we dropped a light source
		_update_visibility()
	renderer.render_entity(pos, item.ascii_char, render_color)
	_update_hud()

## Called when an item is equipped
func _on_item_equipped(item, _slot: String) -> void:
	# Auto-light torches and other burnable light sources when equipped
	if item.provides_light and item.burns_per_turn > 0 and not item.is_lit:
		item.is_lit = true
		_add_message("You light the %s." % item.name, Color(1.0, 0.8, 0.4))
		# Update visibility since we now have a light source
		_update_visibility()

## Called when an item is unequipped
func _on_item_unequipped(item, _slot: String) -> void:
	# When a lit torch is unequipped (but not dropped), it stays lit
	# The light source will be recalculated on next visibility update
	if item.provides_light and item.is_lit:
		_update_visibility()

## Called when a message is logged from any system
func _on_message_logged(message: String) -> void:
	_add_message(message, Color.WHITE)

## Called when a structure is placed
func _on_structure_placed(_structure: Structure) -> void:
	# Note: Message is already logged via result.message in _try_place_structure/_try_place_structure_at_cursor
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


## Register light sources from structures on the current map
func _register_light_sources() -> void:
	# Clear existing light sources
	LightingSystemClass.clear_light_sources()

	if not MapManager.current_map:
		return

	var map_id = MapManager.current_map.map_id

	# Register light sources from structures (campfires, etc.)
	var structures = StructureManager.get_structures_on_map(map_id)
	for structure in structures:
		if structure.has_component("fire"):
			var fire_comp = structure.get_component("fire")
			if fire_comp.is_lit:
				LightingSystemClass.add_light_source(structure.position, LightingSystemClass.LightType.CAMPFIRE)

	# Register light sources from dungeon features (braziers, glowing moss, etc.)
	for pos in FeatureManager.active_features:
		var feature = FeatureManager.active_features[pos]
		var definition = feature.get("definition", {})
		# Check if feature provides light
		if definition.get("provides_light", false):
			var light_type_str = definition.get("light_type", "torch")
			var light_type = _get_light_type_from_string(light_type_str)
			LightingSystemClass.add_light_source(pos, light_type)

	# Register town lights (lampposts) on overworld
	if map_id == "overworld":
		_register_town_lights()

	# Only scan entities for light sources during night/dusk (performance optimization)
	# During day, enemies don't need torches and lit ground items are rare
	var is_dark = TurnManager.time_of_day == "night" or TurnManager.time_of_day == "dusk"
	if is_dark:
		# Rebuild enemy light cache only when dirty (enemies moved or map changed)
		if _enemy_light_cache_dirty:
			_rebuild_enemy_light_cache()

		# Register light sources from cached enemy positions
		for enemy_pos in _enemy_light_cache:
			LightingSystemClass.add_light_source(enemy_pos, LightingSystemClass.LightType.TORCH)

		# Register light sources from lit ground items (dropped torches, lanterns)
		# Only scan GroundItems, not all entities
		for entity in EntityManager.entities:
			if entity is GroundItem:
				var item = entity.item
				if item and item.provides_light and item.is_lit:
					LightingSystemClass.add_light_source(entity.position, LightingSystemClass.LightType.TORCH, item.light_radius)


## Rebuild the enemy light source cache (only intelligent enemies carry torches)
## Called only when cache is dirty (enemy moved or map changed)
func _rebuild_enemy_light_cache() -> void:
	_enemy_light_cache.clear()
	for entity in EntityManager.entities:
		if entity is Enemy and entity.is_alive:
			# Only intelligent enemies (INT >= 5) carry torches
			var enemy_int = entity.attributes.get("INT", 1)
			if enemy_int >= 5:
				_enemy_light_cache.append(entity.position)
	_enemy_light_cache_dirty = false


## Register town lights (lampposts) at night
func _register_town_lights() -> void:
	# Get town center from map metadata
	var town_center = MapManager.current_map.get_meta("town_center", Vector2i(-1, -1))
	if town_center == Vector2i(-1, -1):
		return

	# Get town size (default 20x20)
	var town_size = MapManager.current_map.get_meta("town_size", Vector2i(20, 20))
	var half_size = town_size / 2

	# Place lamppost lights at corners and center of town
	var lamppost_positions = [
		town_center,  # Town center
		town_center + Vector2i(-half_size.x / 2, -half_size.y / 2),  # NW quadrant
		town_center + Vector2i(half_size.x / 2, -half_size.y / 2),   # NE quadrant
		town_center + Vector2i(-half_size.x / 2, half_size.y / 2),   # SW quadrant
		town_center + Vector2i(half_size.x / 2, half_size.y / 2),    # SE quadrant
	]

	for pos in lamppost_positions:
		LightingSystemClass.add_light_source(pos, LightingSystemClass.LightType.LANTERN)


## Convert light type string to LightType enum
func _get_light_type_from_string(type_str: String) -> int:
	match type_str.to_lower():
		"torch": return LightingSystemClass.LightType.TORCH
		"lantern": return LightingSystemClass.LightType.LANTERN
		"campfire": return LightingSystemClass.LightType.CAMPFIRE
		"brazier": return LightingSystemClass.LightType.BRAZIER
		"glowing_moss": return LightingSystemClass.LightType.GLOWING_MOSS
		"magical": return LightingSystemClass.LightType.MAGICAL
		"candle": return LightingSystemClass.LightType.CANDLE
		_: return LightingSystemClass.LightType.TORCH


## Update visibility after player moves or light sources change
func _update_visibility() -> void:
	if not player or not MapManager.current_map:
		return

	# Re-register light sources (enemy positions may have changed)
	_register_light_sources()

	# Calculate visibility (LOS-based, for entities)
	var player_light_radius = player.inventory.get_equipped_light_radius() if player.inventory else 0
	var visible_tiles = FOVSystemClass.calculate_visibility(player.position, player.perception_range, player_light_radius, MapManager.current_map)

	# Update FOV - terrain visibility for daytime outdoors is handled in the renderer
	renderer.update_fov(visible_tiles, player.position)


## Open rest menu (called from input handler)
func open_rest_menu() -> void:
	if rest_menu and player:
		rest_menu.open(player)
		input_handler.ui_blocking_input = true

## Called when rest menu is closed
func _on_rest_menu_closed() -> void:
	input_handler.ui_blocking_input = false

## Called when player requests rest from menu
func _on_rest_requested(type: String, turns: int) -> void:
	rest_type = type
	rest_turns_remaining = turns
	rest_turns_elapsed = 0  # Reset HP restoration counter
	rest_hp_restored = 0  # Reset HP restored counter
	is_resting = true

	# Connect to message_logged to detect interruptions
	if not EventBus.message_logged.is_connected(_on_rest_interrupted_by_message):
		EventBus.message_logged.connect(_on_rest_interrupted_by_message)

	EventBus.rest_started.emit(turns)
	_add_message("You begin resting...", Color(0.6, 0.8, 0.9))

	# Start the rest loop
	_process_rest_turn()

## Process a single rest turn
func _process_rest_turn() -> void:
	if not is_resting:
		_end_rest()
		return

	# For non-stamina and non-health rest types, check if we've run out of turns
	if rest_type != "stamina" and rest_type != "health" and rest_turns_remaining <= 0:
		_end_rest()
		return

	# Check if stamina rest condition is already met (before resting)
	if rest_type == "stamina" and player and player.survival:
		if player.survival.stamina >= player.survival.get_max_stamina():
			_end_rest("You are fully rested.")
			return

	# Check if health rest condition is already met (before resting)
	if rest_type == "health" and player:
		if player.current_health >= player.max_health:
			_end_rest("You are fully healed.")
			return

	# Perform wait action (bonus stamina regen)
	if player.survival:
		player.regenerate_stamina()
		player.regenerate_stamina()
		# Reduce fatigue while resting (1 fatigue per 10 rest turns)
		if rest_turns_elapsed % 10 == 0:
			player.survival.rest(1.0)

	rest_turns_remaining -= 1
	rest_turns_elapsed += 1
	TurnManager.advance_turn()

	# Check for shelter HP restoration
	_check_shelter_hp_restoration()

	# Update HUD during rest
	_update_hud()

	# Check if stamina rest condition is now met (after resting)
	if rest_type == "stamina" and player and player.survival:
		if player.survival.stamina >= player.survival.get_max_stamina():
			_end_rest("You are fully rested.")
			return

	# Check if health rest condition is now met (after resting)
	if rest_type == "health" and player:
		if player.current_health >= player.max_health:
			_end_rest("You are fully healed.")
			return

	# Schedule next rest turn (using call_deferred to allow event processing)
	if is_resting:
		if rest_type == "stamina":
			# For stamina rest, keep going until full (checked above)
			call_deferred("_process_rest_turn")
		elif rest_type == "health":
			# For health rest, keep going until full HP (checked above)
			call_deferred("_process_rest_turn")
		elif rest_turns_remaining > 0:
			call_deferred("_process_rest_turn")
		else:
			_end_rest()

## Check if player is in a shelter and restore HP based on shelter settings
## Player must be on the same tile as the shelter for HP restoration
func _check_shelter_hp_restoration() -> void:
	if not player or not MapManager.current_map:
		return

	var map_id = MapManager.current_map.map_id
	var structures = StructureManager.get_structures_on_map(map_id)

	for structure in structures:
		if structure.has_component("shelter"):
			var shelter = structure.get_component("shelter")
			# Player must be ON the shelter tile for HP restoration
			if shelter.is_inside_shelter(structure.position, player.position):
				# Check if enough turns have passed for HP restoration
				if shelter.hp_restore_turns > 0 and rest_turns_elapsed % shelter.hp_restore_turns == 0:
					var hp_to_restore = shelter.hp_restore_amount
					if player.current_health < player.max_health:
						var old_hp = player.current_health
						player.current_health = min(player.max_health, player.current_health + hp_to_restore)
						var hp_gained = player.current_health - old_hp
						if hp_gained > 0:
							rest_hp_restored += hp_gained  # Track for summary, don't spam messages
				return  # Only check first shelter player is in

## Called when a message is logged during rest - interrupts resting
func _on_rest_interrupted_by_message(message: String) -> void:
	if not is_resting:
		return

	# Ignore certain messages that shouldn't interrupt rest
	var ignore_patterns = [
		"You begin resting",
		"Resting complete",
		"You are fully rested",
		"You are fully healed"
	]

	for pattern in ignore_patterns:
		if message.begins_with(pattern):
			return

	# Interrupt rest
	_interrupt_rest(message)

## Interrupt rest due to an event
func _interrupt_rest(reason: String) -> void:
	if not is_resting:
		return

	is_resting = false
	rest_turns_remaining = 0
	rest_type = ""

	# Disconnect message listener
	if EventBus.message_logged.is_connected(_on_rest_interrupted_by_message):
		EventBus.message_logged.disconnect(_on_rest_interrupted_by_message)

	EventBus.rest_interrupted.emit(reason)
	_add_message("Rest interrupted: %s" % reason, Color(1.0, 0.7, 0.4))

## End rest normally
func _end_rest(message: String = "") -> void:
	if not is_resting:
		return

	is_resting = false
	var final_turns = rest_turns_remaining
	var hp_restored = rest_hp_restored
	var turns_rested = rest_turns_elapsed
	rest_turns_remaining = 0
	rest_type = ""
	rest_hp_restored = 0

	# Disconnect message listener
	if EventBus.message_logged.is_connected(_on_rest_interrupted_by_message):
		EventBus.message_logged.disconnect(_on_rest_interrupted_by_message)

	EventBus.rest_completed.emit(final_turns)

	# Build summary message
	var summary = message if message != "" else "Resting complete."
	if hp_restored > 0:
		summary += " Restored %d HP." % hp_restored
	if turns_rested > 0:
		summary += " (%d turns)" % turns_rested
	_add_message(summary, Color(0.6, 0.9, 0.6))
