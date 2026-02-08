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
const FarmingSystemClass = preload("res://systems/farming_system.gd")
const ChunkManagerClass = preload("res://autoload/chunk_manager.gd")

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
var ritual_menu: Control = null
var special_actions_screen: Control = null
var debug_command_menu: Control = null
var perf_overlay: Label = null
var ui_coordinator = null
var event_handlers = null
var render_orchestrator = null
var perf_overlay_enabled: bool = false
# Performance tracking
var _perf_last_update_time: float = 0.0
var _perf_entity_process_time: float = 0.0
var _perf_chunk_operations: int = 0
# auto_pickup_enabled moved to GameManager for global access

# Spell casting state (targeting handled by TargetingSystem)

# Rest system state
var is_resting: bool = false
var rest_turns_remaining: int = 0
var rest_type: String = ""  # "stamina", "time", or "custom"
var rest_turns_elapsed: int = 0  # Track turns for shelter HP restoration
var rest_hp_restored: int = 0  # Track total HP restored during rest for summary
var build_mode_active: bool = false
var selected_structure_id: String = ""
var build_cursor_offset: Vector2i = Vector2i(1, 0)  # Offset from player for placement cursor

# Performance optimization: Cache HUD string values to avoid rebuilding unchanged text
var _cached_player_hp: int = -1
var _cached_player_max_hp: int = -1
var _cached_turn: int = -1
var _cached_status_turn: int = -1  # Separate tracking for status line updates
var _cached_player_level: int = -1
var _cached_player_xp: int = -1
var _cached_player_gold: int = -1
var _cached_stamina: float = -1
var _cached_max_stamina: float = -1
var _cached_mana: float = -1
var _cached_max_mana: float = -1
var _cached_evasion: int = -1
var _cached_armor: int = -1

var _cached_temperature: float = -999
var _cached_env_temperature: float = -999
var _cached_location: String = ""
var _cached_biome_name: String = ""
var _cached_light_lit: bool = false
var _cached_has_light: bool = false

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
const RitualMenuScene = preload("res://ui/ritual_menu.tscn")
const SpecialActionsScreenScene = preload("res://ui/special_actions_screen.tscn")
const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")
const UICoordinatorClass = preload("res://systems/ui_coordinator.gd")
const GameEventHandlersClass = preload("res://systems/game_event_handlers.gd")
const RenderingOrchestratorClass = preload("res://systems/rendering_orchestrator.gd")

func _ready() -> void:
	# Get renderer reference
	renderer = $ASCIIRenderer

	# Get input handler
	input_handler = $InputHandler

	# Set UI colors
	_setup_ui_colors()
	
	# Setup all UI screens via coordinator
	_setup_ui_screens()

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

		# Apply selected race and class from GameManager
		player.apply_race(GameManager.player_race)
		player.apply_class(GameManager.player_class)

		# Apply rolled abilities from character creation (if any)
		# Note: bonus racial ability points are already included in these values
		# (distributed during character creation), so zero out available_ability_points
		if not GameManager.player_abilities.is_empty():
			for ability in GameManager.player_abilities:
				player.attributes[ability] = GameManager.player_abilities[ability]
			# Clear after applying
			GameManager.player_abilities.clear()
			# Racial bonus points were spent during character creation
			player.available_ability_points = 0
			# Recalculate derived stats (HP, stamina, etc.)
			player._calculate_derived_stats()

		# Apply distributed skill points from character creation (if any)
		if not GameManager.player_skill_points.is_empty():
			for skill_id in GameManager.player_skill_points:
				var points = GameManager.player_skill_points[skill_id]
				if player.skills.has(skill_id):
					player.skills[skill_id] += points
			# Clear after applying
			GameManager.player_skill_points.clear()

		# Give player some starter items (includes class starting equipment)
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

	# Setup fog of war and map info BEFORE rendering (required for visibility checks)
	var map_id = MapManager.current_map.map_id if MapManager.current_map else ""
	var chunk_based = MapManager.current_map.chunk_based if MapManager.current_map else false
	renderer.set_map_info(map_id, chunk_based, MapManager.current_map)
	renderer.set_fow_enabled(true)

	# Load initial chunks for overworld
	if MapManager.current_map and MapManager.current_map.chunk_based:
		ChunkManager.update_active_chunks(player.position)

	# Initialize rendering orchestrator
	render_orchestrator = RenderingOrchestratorClass.new()
	render_orchestrator.setup(renderer, player, input_handler)

	# Initial render
	render_orchestrator.render_map()
	render_orchestrator.render_ground_items()  # Render loot first so creatures appear on top
	render_orchestrator.render_all_entities()
	renderer.render_entity(player.position, "@", Color.YELLOW)
	renderer.center_camera(player.position)

	# Ensure the tree is not paused after loading/new game initialization
	var _tree = get_tree()
	if _tree:
		_tree.paused = false

	# Ensure input is enabled after initialization
	if input_handler:
		input_handler.set_ui_blocking(false)

	# Initialize light sources and calculate initial visibility via orchestrator
	render_orchestrator.initialize_light_sources_for_map()
	render_orchestrator.update_visibility()

	# Initialize event handlers (EventBus signal subscriptions)
	event_handlers = GameEventHandlersClass.new()
	event_handlers.setup(self)
	event_handlers.connect_signals()

	# Update HUD
	_update_hud()

	# Initial welcome message (controls are now shown in sidebar)
	_add_message("Welcome to the Underkingdom!", Color(0.6, 0.9, 0.6))

	print("Game scene initialized")

func _exit_tree() -> void:
	if event_handlers:
		event_handlers.disconnect_signals()

## Update performance overlay every frame
func _process(_delta: float) -> void:
	if perf_overlay_enabled and perf_overlay:
		_update_perf_overlay()

## Update performance overlay with current metrics
func _update_perf_overlay() -> void:
	if not perf_overlay:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var update_interval = current_time - _perf_last_update_time

	# Get current metrics
	var turn = TurnManager.current_turn if TurnManager else 0
	var active_chunks = ChunkManager.active_chunks.size() if ChunkManager else 0
	var cached_chunks = ChunkManager.chunk_cache.size() if ChunkManager else 0
	var active_features = FeatureManager.active_features.size() if FeatureManager else 0
	var active_hazards = HazardManager.active_hazards.size() if HazardManager else 0
	var chunk_ops = ChunkManager._chunk_ops_this_turn if ChunkManager else 0

	# Count entities by type
	var total_entities = 0
	var enemies = 0
	var npcs = 0
	var structures = 0
	var ground_items = 0
	var crops = 0

	var entity_start_time = Time.get_ticks_msec() / 1000.0
	if EntityManager:
		for entity in EntityManager.entities:
			total_entities += 1
			if entity is Enemy:
				enemies += 1
			elif entity.has_method("process_turn"):  # NPC
				npcs += 1
			elif entity is Structure:
				structures += 1
			elif entity is GroundItemClass:
				ground_items += 1
			elif "is_crop" in entity and entity.is_crop:
				crops += 1
	_perf_entity_process_time = (Time.get_ticks_msec() / 1000.0) - entity_start_time

	# Get player position and chunk
	var player_pos = Vector2i.ZERO
	var player_chunk = Vector2i.ZERO
	if player:
		player_pos = player.position
		if MapManager.current_map and MapManager.current_map.chunk_based:
			player_chunk = ChunkManagerClass.world_to_chunk(player_pos)

	# Frame time
	var fps = Engine.get_frames_per_second()
	var frame_time = 1000.0 / fps if fps > 0 else 0.0

	# Build overlay text
	var text = "=== PERFORMANCE OVERLAY ===\n"
	text += "Turn: %d | FPS: %d (%.1fms)\n" % [turn, fps, frame_time]
	text += "Update interval: %.3fs\n" % update_interval
	text += "\n"
	text += "CHUNKS:\n"
	text += "  Active: %d | Cached: %d\n" % [active_chunks, cached_chunks]
	text += "  Player Chunk: %v\n" % player_chunk
	text += "  Chunk ops this turn: %d / %d\n" % [chunk_ops, ChunkManager.MAX_CHUNK_OPS_PER_TURN if ChunkManager else 0]
	if chunk_ops > 10:
		text += "  WARNING: High chunk activity!\n"
	text += "\n"
	text += "ENTITIES: %d total (%.3fms scan)\n" % [total_entities, _perf_entity_process_time * 1000.0]
	text += "  Enemies: %d | NPCs: %d\n" % [enemies, npcs]
	text += "  Structures: %d | Ground Items: %d\n" % [structures, ground_items]
	text += "  Crops: %d\n" % crops
	text += "\n"
	text += "FEATURES & HAZARDS:\n"
	text += "  Features: %d | Hazards: %d\n" % [active_features, active_hazards]
	if active_features > 300:
		text += "  WARNING: High feature count!\n"
	text += "\n"
	text += "PLAYER:\n"
	text += "  Position: %v\n" % player_pos
	if player:
		text += "  HP: %d/%d | Alive: %s\n" % [player.current_health, player.max_health, player.is_alive]

	perf_overlay.text = text
	_perf_last_update_time = current_time

## Setup all UI screens via UICoordinator
func _setup_ui_screens() -> void:
	ui_coordinator = UICoordinatorClass.new(hud, input_handler)

	# Preloaded screens
	inventory_screen = ui_coordinator.setup_preloaded("inventory", InventoryScreenScene)
	crafting_screen = ui_coordinator.setup_preloaded("crafting", CraftingScreenScene)
	build_mode_screen = ui_coordinator.setup_preloaded("build_mode", BuildModeScreenScene)
	container_screen = ui_coordinator.setup_preloaded("container", ContainerScreenScene)
	shop_screen = ui_coordinator.setup_preloaded("shop", ShopScreenScene)
	training_screen = ui_coordinator.setup_preloaded("training", TrainingScreenScene)
	npc_menu_screen = ui_coordinator.setup_preloaded("npc_menu", NpcMenuScreenScene)
	pause_menu = ui_coordinator.setup_preloaded("pause_menu", PauseMenuScene)
	death_screen = ui_coordinator.setup_preloaded("death", DeathScreenScene)
	spell_list_screen = ui_coordinator.setup_preloaded("spell_list", SpellListScreenScene)
	ritual_menu = ui_coordinator.setup_preloaded("ritual", RitualMenuScene)
	special_actions_screen = ui_coordinator.setup_preloaded("special_actions", SpecialActionsScreenScene)

	# Dynamically loaded screens
	character_sheet = ui_coordinator.setup_loaded("character_sheet", "res://ui/character_sheet.tscn", "CharacterSheet")
	level_up_screen = ui_coordinator.setup_loaded("level_up", "res://ui/level_up_screen.tscn", "LevelUpScreen")
	help_screen = ui_coordinator.setup_loaded("help", "res://ui/help_screen.tscn", "HelpScreen")
	world_map_screen = ui_coordinator.setup_loaded("world_map", "res://ui/world_map_screen.tscn", "WorldMapScreen")
	fast_travel_screen = ui_coordinator.setup_loaded("fast_travel", "res://ui/fast_travel_screen.tscn", "FastTravelScreen")
	rest_menu = ui_coordinator.setup_loaded("rest_menu", "res://ui/rest_menu.tscn", "RestMenu")
	debug_command_menu = ui_coordinator.setup_loaded("debug_menu", "res://ui/debug_command_menu.tscn", "DebugCommandMenu")

	# Connect custom signals (beyond "closed") on screens that have them
	if build_mode_screen:
		build_mode_screen.structure_selected.connect(_on_structure_selected)
	if shop_screen:
		shop_screen.switch_to_training.connect(_on_shop_switch_to_training)
	if training_screen:
		training_screen.switch_to_trade.connect(_on_training_switch_to_trade)
	if npc_menu_screen:
		npc_menu_screen.trade_selected.connect(_on_npc_menu_trade_selected)
		npc_menu_screen.train_selected.connect(_on_npc_menu_train_selected)
	if death_screen:
		death_screen.load_save_requested.connect(_on_death_screen_load_save)
		death_screen.restore_checkpoint_requested.connect(_on_death_screen_restore_checkpoint)
		death_screen.return_to_menu_requested.connect(_on_death_screen_return_to_menu)
	if rest_menu and rest_menu.has_signal("rest_requested"):
		rest_menu.rest_requested.connect(_on_rest_requested)
	if spell_list_screen and spell_list_screen.has_signal("spell_cast_requested"):
		spell_list_screen.spell_cast_requested.connect(_on_spell_cast_requested)
	if ritual_menu and ritual_menu.has_signal("ritual_started"):
		ritual_menu.ritual_started.connect(_on_ritual_started)
	if special_actions_screen and special_actions_screen.has_signal("action_used"):
		special_actions_screen.action_used.connect(_on_special_action_used)
	if debug_command_menu and debug_command_menu.has_signal("action_completed"):
		debug_command_menu.action_completed.connect(_on_debug_action_completed)

	# Connect unified close handler
	ui_coordinator.screen_closed.connect(_on_ui_screen_closed)

	# Setup performance overlay (not a screen - custom widget)
	_setup_perf_overlay()


## Setup performance overlay
func _setup_perf_overlay() -> void:
	perf_overlay = Label.new()
	perf_overlay.name = "PerformanceOverlay"
	perf_overlay.position = Vector2(10, 10)
	perf_overlay.size = Vector2(400, 300)
	perf_overlay.z_index = 1000
	perf_overlay.add_theme_font_size_override("font_size", 12)
	perf_overlay.modulate = Color(1.0, 1.0, 0.0, 0.9)
	perf_overlay.visible = false
	hud.add_child(perf_overlay)

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

	# Give class starting equipment
	var class_equipment = ClassManager.get_starting_equipment(GameManager.player_class)
	for equip_data in class_equipment:
		var item_id = equip_data.get("item_id", "")
		var count = int(equip_data.get("count", 1))
		if item_id != "":
			var item = item_mgr.create_item(item_id, count)
			if item:
				player.inventory.add_item(item)
				# Auto-equip weapons from class starting equipment
				if item.is_equippable() and item.item_type == "weapon":
					player.equip_item(item)

	# Teach class starting spells (requires spellbook in inventory)
	var starting_spells = ClassManager.get_starting_spells(GameManager.player_class)
	for spell_id in starting_spells:
		player.learn_spell(spell_id)

	# Give player some starter recipes for testing
	player.learn_recipe("bandage")
	player.learn_recipe("flint_knife")
	player.learn_recipe("cooked_meat")

## Toggle auto-pickup on/off
func toggle_auto_pickup() -> void:
	GameManager.auto_pickup_enabled = not GameManager.auto_pickup_enabled
	var status = "ON" if GameManager.auto_pickup_enabled else "OFF"
	_add_message("Auto-pickup: %s" % status, Color(0.8, 0.8, 0.6))
	_update_toggles_display()

## Toggle auto-open doors on/off
func toggle_auto_open_doors() -> void:
	GameManager.auto_open_doors = not GameManager.auto_open_doors
	var status = "ON" if GameManager.auto_open_doors else "OFF"
	_add_message("Auto-open doors: %s" % status, Color(0.8, 0.8, 0.6))
	_update_toggles_display()

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

## Handle checkpoint restore from death screen
func _on_death_screen_restore_checkpoint() -> void:
	# Load the auto-save checkpoint
	var success = SaveManager.load_autosave()
	if success:
		# Indicate we're loading a save so _ready applies pending save data
		GameManager.is_loading_save = true
		# Reload the game scene to reset everything
		get_tree().reload_current_scene()
	else:
		_add_message("Failed to load checkpoint!", Color.RED)

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
					input_handler.set_ui_blocking(false)  # Re-enable player movement
					_add_message("Cancelled building", Color(0.7, 0.7, 0.7))
					render_orchestrator.full_render_needed = true  # render_map() clears entity layer
					render_orchestrator.render_map()  # Clear cursor
					render_orchestrator.render_all_entities()
					get_viewport().set_input_as_handled()
		# ESC to cancel build mode (if we somehow get here without structure selected)
		elif event.keycode == KEY_ESCAPE and build_mode_active:
			build_mode_active = false
			selected_structure_id = ""
			build_cursor_offset = Vector2i(1, 0)
			input_handler.set_ui_blocking(false)  # Re-enable player movement
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
	# Skip HUD updates if player is dead (death screen handles display)
	if not player or not player.is_alive:
		return

	# Update character info line with calendar data and weather (only if turn changed)
	if character_info_label:
		var current_turn = TurnManager.current_turn
		if current_turn != _cached_turn:
			_cached_turn = current_turn
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

	# Update status line with health and survival (only if values changed)
	if status_line:
		var needs_update = false

		# Check if turn changed (force update every turn)
		var current_turn = TurnManager.current_turn
		if current_turn != _cached_status_turn:
			_cached_status_turn = current_turn
			needs_update = true

		# Check if any values changed
		if player.current_health != _cached_player_hp or player.max_health != _cached_player_max_hp:
			_cached_player_hp = player.current_health
			_cached_player_max_hp = player.max_health
			needs_update = true

		# Check survival stats
		if player.survival:
			var s = player.survival
			var stam = s.stamina
			var max_stam = s.get_max_stamina()
			var mana = s.mana
			var max_mana = s.get_max_mana()
			var evasion = CombatSystem.get_evasion(player)
			var armor = player.get_total_armor() if player.has_method("get_total_armor") else player.armor
			var env_temp = s.get_environmental_temperature()
			var player_temp = s.temperature

			if stam != _cached_stamina or max_stam != _cached_max_stamina or \
			   mana != _cached_mana or max_mana != _cached_max_mana or \
			   evasion != _cached_evasion or armor != _cached_armor or \
			   abs(env_temp - _cached_env_temperature) > 0.5 or \
			   abs(player_temp - _cached_temperature) > 0.5:
				_cached_stamina = stam
				_cached_max_stamina = max_stam
				_cached_mana = mana
				_cached_max_mana = max_mana
				_cached_evasion = evasion
				_cached_armor = armor
				_cached_env_temperature = env_temp
				_cached_temperature = player_temp
				needs_update = true

		# Check light source
		var has_light = false
		var light_lit = false
		if player.inventory:
			var light_item = _get_equipped_light_source()
			if light_item:
				has_light = true
				light_lit = light_item.is_lit

		if has_light != _cached_has_light or light_lit != _cached_light_lit:
			_cached_has_light = has_light
			_cached_light_lit = light_lit
			needs_update = true

		# Only rebuild text if something changed
		if needs_update:
			var hp_text = "HP: %d/%d" % [_cached_player_hp, _cached_player_max_hp]
			var turn_text = "Turn: %d" % TurnManager.current_turn

			# Survival stats (if available)
			var survival_text = ""
			if player.survival:
				var stam_text = "Stam: %d/%d" % [int(_cached_stamina), int(_cached_max_stamina)]
				var mana_text = "Mana: %d/%d" % [int(_cached_mana), int(_cached_max_mana)]
				var evasion_text = "Eva: %d%%" % _cached_evasion
				var armor_text = "Arm: %d" % _cached_armor
				var env_temp = roundi(_cached_env_temperature)
				var player_temp = roundi(_cached_temperature)
				var temp_text = "Tmp: %d→%d°F" % [env_temp, player_temp]
				survival_text = "  %s  %s  %s  %s  %s" % [stam_text, mana_text, evasion_text, armor_text, temp_text]

			# Light source indicator
			var light_text = ""
			if _cached_has_light:
				if _cached_light_lit:
					light_text = "  [Torch: LIT]"
				else:
					light_text = "  [Torch: OUT]"

			status_line.text = "%s%s%s  %s" % [hp_text, survival_text, light_text, turn_text]

			# Color code based on most critical state
			var status_color = _get_status_color()
			status_line.add_theme_color_override("font_color", status_color)

	# Update XP label if present (only if values changed)
	if xp_label and player:
		var cur_level = player.level if "level" in player else 0
		var cur_xp = player.experience if "experience" in player else 0
		if cur_level != _cached_player_level or cur_xp != _cached_player_xp:
			_cached_player_level = cur_level
			_cached_player_xp = cur_xp
			var next_xp = player.experience_to_next_level if "experience_to_next_level" in player else 100
			xp_label.text = "Lvl %d | Exp: %d/%d" % [cur_level, cur_xp, next_xp]

	# Update gold label if present (only if value changed)
	if gold_label and player:
		if player.gold != _cached_player_gold:
			_cached_player_gold = player.gold
			gold_label.text = "Gold: %d" % player.gold

	# Update location (only if map or biome changed)
	if location_label:
		var map_name = MapManager.current_map.map_id if MapManager.current_map else "Unknown"

		# Check for overworld biome changes
		var current_biome = ""
		if MapManager.current_map and MapManager.current_map.map_id == "overworld" and player:
			var biome_data = BiomeGenerator.get_biome_at(player.position.x, player.position.y, GameManager.world_seed)
			current_biome = biome_data.get("biome_name", "Unknown")

		# Only update if location or biome changed
		if map_name != _cached_location or current_biome != _cached_biome_name:
			_cached_location = map_name
			_cached_biome_name = current_biome

			var formatted_name = map_name.replace("_", " ").capitalize()
			var location_text = "◆ %s ◆" % formatted_name.to_upper()

			# Add biome and ground type for overworld
			if MapManager.current_map and MapManager.current_map.map_id == "overworld" and player:
				var biome_name = current_biome.replace("_", " ").capitalize()

				# Get ground character name
				var tile = MapManager.current_map.get_tile(player.position)
				var ground_char = tile.ascii_char
				var ground_name = _get_terrain_name(ground_char, current_biome)

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
	if s.fatigue >= 50:
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
		var autopickup_status = "[G] Auto-pickup: %s" % ("ON" if GameManager.auto_pickup_enabled else "OFF")
		var autopickup_color = Color(0.5, 0.9, 0.5) if GameManager.auto_pickup_enabled else Color(0.6, 0.6, 0.6)
		ability1.text = autopickup_status
		ability1.add_theme_color_override("font_color", autopickup_color)

	var ability2 = $HUD/BottomBar/Abilities/Ability2
	if ability2:
		var autodoor_status = "[O] Auto-door: %s" % ("ON" if GameManager.auto_open_doors else "OFF")
		var autodoor_color = Color(0.5, 0.9, 0.5) if GameManager.auto_open_doors else Color(0.6, 0.6, 0.6)
		ability2.text = autodoor_status
		ability2.add_theme_color_override("font_color", autodoor_color)

	# Harvesting/Sprint mode indicator
	var ability3 = $HUD/BottomBar/Abilities/Ability3
	if ability3:
		var is_harvesting = input_handler and input_handler.is_harvesting()
		var is_sprinting = input_handler and input_handler.is_sprinting()
		if is_harvesting:
			ability3.text = "HARVESTING"
			ability3.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # Gold/yellow
			ability3.visible = true
		elif is_sprinting:
			ability3.text = "SPRINTING"
			ability3.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))  # Bright yellow
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


## Hide targeting UI and clear highlight when targeting ends
func hide_targeting_ui() -> void:
	if renderer:
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

	# Don't spawn inside buildings (shops, etc.)
	var tile = MapManager.current_map.get_tile(pos)
	if tile and tile.is_interior:
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

## Toggle inventory screen visibility (called from input handler)
func toggle_inventory_screen() -> void:
	if inventory_screen:
		if inventory_screen.visible:
			inventory_screen.hide()
			input_handler.set_ui_blocking(false)
		else:
			ui_coordinator.open("inventory", [player])

## Open crafting screen (called from input handler)
func open_crafting_screen() -> void:
	if crafting_screen and player:
		ui_coordinator.open("crafting", [player])
		render_orchestrator.render_ground_items()
		_update_hud()
		get_viewport().set_input_as_handled()


## Unified close handler for all UI screens (via UICoordinator.screen_closed signal).
## The coordinator already called set_ui_blocking(false) before emitting this signal.
func _on_ui_screen_closed(screen_name: String) -> void:
	match screen_name:
		"build_mode":
			if selected_structure_id == "":
				build_mode_active = false
				render_orchestrator.update_visibility()
				_update_hud()
			else:
				# Re-block input - we're still in structure placement mode
				input_handler.set_ui_blocking(true)
		"level_up":
			render_orchestrator.update_visibility()
			_update_hud()
			# Reopen character sheet (it was hidden when level-up opened)
			if character_sheet and player:
				ui_coordinator.open("character_sheet", [player])
		_:
			render_orchestrator.update_visibility()
			_update_hud()

## Toggle build mode (called from input handler)
func toggle_build_mode() -> void:
	if build_mode_screen:
		if build_mode_screen.visible:
			build_mode_screen.hide()
			build_mode_active = false
			selected_structure_id = ""
			input_handler.set_ui_blocking(false)
		else:
			ui_coordinator.open("build_mode", [player])

## Toggle world map (called from input handler)
func toggle_world_map() -> void:
	if world_map_screen:
		if world_map_screen.visible:
			world_map_screen.close()
			input_handler.set_ui_blocking(false)
		else:
			ui_coordinator.open("world_map")

## Toggle spell list (called from input handler via Shift+M)
func toggle_spell_list() -> void:
	if spell_list_screen and player:
		if spell_list_screen.visible:
			spell_list_screen.hide()
			input_handler.set_ui_blocking(false)
		else:
			ui_coordinator.open("spell_list", [player])

## Open container screen (called from input handler)
func open_container_screen(structure: Structure) -> void:
	if container_screen and player:
		ui_coordinator.open("container", [player, structure])

## Open pause menu (called from ESC key)
func _open_pause_menu() -> void:
	if pause_menu:
		ui_coordinator.open("pause_menu", [true])

## Open character sheet (called from P key)
func open_character_sheet() -> void:
	if character_sheet and player:
		ui_coordinator.open("character_sheet", [player])

## Open help screen (called from ? or F1 key)
func open_help_screen() -> void:
	if help_screen:
		ui_coordinator.open("help")

## Toggle debug command menu (called from F12 key)
func toggle_debug_menu() -> void:
	if debug_command_menu:
		if debug_command_menu.visible:
			debug_command_menu.close()
			input_handler.set_ui_blocking(false)
		else:
			ui_coordinator.open("debug_menu", [player])


## Called when a structure is selected from build mode
func _on_structure_selected(structure_id: String) -> void:
	selected_structure_id = structure_id
	build_mode_active = true
	build_cursor_offset = Vector2i(1, 0)  # Reset cursor to right of player
	input_handler.set_ui_blocking(true)  # Block player movement during placement
	var structure_name = StructureManager.structure_definitions[structure_id].get("name", structure_id) if StructureManager.structure_definitions.has(structure_id) else structure_id
	_add_message("BUILD MODE: %s - Arrow keys to move cursor, ENTER to place, ESC to cancel" % structure_name, Color(1.0, 1.0, 0.6))
	# Show initial cursor
	_update_build_cursor()


## Called when shop screen requests switch to training
func _on_shop_switch_to_training(npc: NPC, switch_player: Player) -> void:
	if training_screen and switch_player:
		ui_coordinator.open("training", [switch_player, npc])

## Called when training screen requests switch to trade
func _on_training_switch_to_trade(npc: NPC, switch_player: Player) -> void:
	if shop_screen and switch_player:
		ui_coordinator.open("shop", [switch_player, npc])

## Called when trade is selected from NPC menu
func _on_npc_menu_trade_selected(menu_npc: NPC, menu_player: Player) -> void:
	if shop_screen and menu_player:
		ui_coordinator.open("shop", [menu_player, menu_npc])

## Called when train is selected from NPC menu
func _on_npc_menu_train_selected(menu_npc: NPC, menu_player: Player) -> void:
	if training_screen and menu_player:
		ui_coordinator.open("training", [menu_player, menu_npc])

## Called when a debug action is completed (spawning, etc.)
func _on_debug_action_completed() -> void:
	input_handler.set_ui_blocking(false)
	# Refresh rendering to show spawned entities/items and tile changes
	render_orchestrator.full_render_needed = true
	render_orchestrator.render_map()
	render_orchestrator.render_ground_items()
	render_orchestrator.render_all_entities()
	renderer.render_entity(player.position, "@", Color.YELLOW)
	render_orchestrator.update_visibility()

## Called when player requests to cast a spell from the spell list
func _on_spell_cast_requested(spell_id: String) -> void:
	input_handler.set_ui_blocking(false)

	if not player or not spell_id:
		return

	var spell = SpellManager.get_spell(spell_id)
	if not spell:
		_add_message("Unknown spell.", Color(1.0, 0.5, 0.5))
		return

	var targeting_mode = spell.get_targeting_mode()

	if targeting_mode == "self":
		# Self-targeting spells cast immediately
		_cast_spell_on_target(spell, player)
	elif targeting_mode in ["ranged", "touch"]:
		# Ranged spells need target selection via TargetingSystem
		if not input_handler.targeting_system:
			_add_message("Targeting system not available.", Color(1.0, 0.5, 0.5))
			return

		# Start spell targeting (TargetingSystem handles valid targets)
		if input_handler.targeting_system.start_spell_targeting(player, spell):
			input_handler.set_ui_blocking(true)
			_add_message(input_handler.targeting_system.get_status_text(), Color(0.5, 0.8, 1.0))
			_add_message(input_handler.targeting_system.get_help_text(), Color(0.7, 0.7, 0.7))
			# Show visual highlight on the initial target
			var initial_target = input_handler.targeting_system.get_current_target()
			if initial_target:
				update_target_highlight(initial_target)
		else:
			_add_message("No valid targets in range.", Color(1.0, 0.8, 0.3))
	else:
		_add_message("Unsupported targeting mode: %s" % targeting_mode, Color(1.0, 0.5, 0.5))


## Cast a spell on a specific target
func _cast_spell_on_target(spell, target) -> void:
	var result = SpellCastingSystemClass.cast_spell(player, spell, target)

	if result.success:
		_add_message(result.message, Color(0.5, 0.8, 1.0))
		TurnManager.advance_turn()
	elif result.failed:
		_add_message(result.message, Color(1.0, 0.8, 0.3))
		TurnManager.advance_turn()  # Still costs a turn
	else:
		_add_message(result.message, Color(1.0, 0.5, 0.5))

	# Update HUD to show mana change
	_update_hud()
	# Refresh rendering, then apply FOW (order matters - render first, then FOW hides non-visible)
	render_orchestrator.render_ground_items()
	render_orchestrator.render_all_entities()
	render_orchestrator.update_visibility()


## Called when player begins a ritual from the ritual menu
func _on_ritual_started(ritual_id: String) -> void:
	input_handler.set_ui_blocking(false)
	_add_message("Ritual channeling has begun. Continue waiting to complete it.", Color.MAGENTA)

## Called when a special action is used
func _on_special_action_used(_action_type: String, _action_id: String) -> void:
	# Action was used, advance turn
	TurnManager.advance_turn()


## Toggle special actions screen (called from input handler)
func toggle_special_actions() -> void:
	if special_actions_screen and player:
		if special_actions_screen.visible:
			special_actions_screen.hide()
			input_handler.set_ui_blocking(false)
		else:
			ui_coordinator.open("special_actions", [player])

## Toggle fast travel screen (called from input handler)
func toggle_fast_travel() -> void:
	if fast_travel_screen:
		if fast_travel_screen.visible:
			fast_travel_screen.close()
			input_handler.set_ui_blocking(false)
		else:
			ui_coordinator.open("fast_travel")


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
		render_orchestrator.full_render_needed = true  # render_map() clears entity layer
		render_orchestrator.render_map()
		render_orchestrator.render_ground_items()
		render_orchestrator.render_all_entities()
		renderer.render_entity(player.position, "@", Color.YELLOW)
	else:
		_add_message(result.message, Color(0.9, 0.5, 0.5))

## Update the build cursor visualization
func _update_build_cursor() -> void:
	if not player or not MapManager.current_map:
		return

	# Re-render map to clear old cursor
	render_orchestrator.full_render_needed = true  # render_map() clears entity layer
	render_orchestrator.render_map()
	render_orchestrator.render_ground_items()
	render_orchestrator.render_all_entities()
	renderer.render_entity(player.position, "@", Color.YELLOW)

	# Render cursor at new position
	var cursor_pos = player.position + build_cursor_offset
	renderer.render_entity(cursor_pos, "X", Color(1.0, 1.0, 0.0, 0.8))


## Open rest menu (called from input handler)
func open_rest_menu() -> void:
	if rest_menu and player:
		ui_coordinator.open("rest_menu", [player])


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

	# Safety check: Prevent infinite loops with a maximum turn limit
	const MAX_REST_TURNS = 5000
	if rest_turns_elapsed >= MAX_REST_TURNS:
		_interrupt_rest("Rested for too long without reaching goal.")
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

	# For health rest, verify player can actually be healed in shelter
	if rest_type == "health" and player:
		if not _is_player_in_healing_shelter():
			_interrupt_rest("You must rest on a shelter that can restore health.")
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

## Check if player is on a shelter tile that can heal them
func _is_player_in_healing_shelter() -> bool:
	if not player or not MapManager.current_map:
		return false

	var map_id = MapManager.current_map.map_id
	var structures = StructureManager.get_structures_on_map(map_id)

	for structure in structures:
		if structure.has_component("shelter"):
			var shelter = structure.get_component("shelter")
			# Player must be ON the shelter tile for HP restoration
			if shelter.is_inside_shelter(structure.position, player.position):
				# Verify shelter can actually restore HP
				if shelter.hp_restore_turns > 0 and shelter.hp_restore_amount > 0:
					return true

	return false

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
					var hp_to_restore = shelter.hp_restore_amount + player.level
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
