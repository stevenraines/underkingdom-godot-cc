extends Node2D

## Game - Main game scene
##
## Initializes the game, creates player, manages rendering and updates.

var player: Player
var renderer: ASCIIRenderer
var input_handler: Node

@onready var hud: CanvasLayer = $HUD
@onready var character_info_label: Label = $HUD/TopBar/CharacterInfo
@onready var status_line: Label = $HUD/TopBar/StatusLine
@onready var location_label: Label = $HUD/RightSidebar/LocationLabel
@onready var message_log: RichTextLabel = $HUD/RightSidebar/MessageLog
@onready var active_effects_label: Label = $HUD/BottomBar/ActiveEffects

func _ready() -> void:
	# Get renderer reference
	renderer = $ASCIIRenderer

	# Get input handler
	input_handler = $InputHandler

	# Set UI colors
	_setup_ui_colors()

	# Start new game
	GameManager.start_new_game()

	# Generate overworld
	MapManager.transition_to_map("overworld")

	# Create player
	player = Player.new()
	player.position = _find_valid_spawn_position()
	MapManager.current_map.entities.append(player)

	# Set player reference in input handler and EntityManager
	input_handler.set_player(player)
	EntityManager.player = player

	# Spawn initial enemies
	_spawn_map_enemies()

	# Initial render
	_render_map()
	_render_all_entities()
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

	# Update HUD
	_update_hud()

	# Add welcome message
	_add_message("Welcome to the Underkingdom. Press ? for help.", Color(0.7, 0.9, 1.0))
	_add_message("WASD/Arrows: Move  >: Descend  <: Ascend", Color(0.8, 0.8, 0.8))

	print("Game scene initialized")

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
	renderer.render_entity(new_pos, "@", Color.YELLOW)
	renderer.center_camera(new_pos)

	# Update FOV
	var visible_tiles = FOVSystem.calculate_fov(new_pos, player.perception_range, MapManager.current_map)
	renderer.update_fov(visible_tiles)

	# Check if standing on stairs and update message
	_update_message()

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
		# Enemy died - remove from EntityManager
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
	if event is InputEventKey and event.pressed and not event.echo:
		# Restart game when R is pressed and player is dead
		if event.keycode == KEY_R and player and not player.is_alive:
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
		@warning_ignore("integer_division")
		character_info_label.text = "Player, Harvest Dawn %dth of Nivvum Ut" % (TurnManager.current_turn / 1000 + 6)

	# Update status line with all stats
	if status_line:
		# Health with color coding
		var hp_percent = float(player.current_health) / float(player.max_health)
		var hp_text = "HP: %d/%d" % [player.current_health, player.max_health]
		
		var level_text = "LVL: 1"
		var exp_text = "Exp: 0/220"
		var turn_text = "Turn: %d" % TurnManager.current_turn
		var time_text = TurnManager.time_of_day

		# Combat stats
		var acc_text = "Acc: %d%%" % CombatSystem.get_accuracy(player)
		var eva_text = "Eva: %d%%" % CombatSystem.get_evasion(player)
		var dmg_text = "Dmg: %d" % player.base_damage
		var arm_text = "Arm: %d" % player.armor

		status_line.text = "%s  %s  %s  %s  %s  %s  %s  %s  %s" % [
			hp_text, level_text, exp_text, turn_text, time_text,
			acc_text, eva_text, dmg_text, arm_text
		]
		
		# Color code based on health
		var hp_color: Color
		if hp_percent > 0.75:
			hp_color = Color(0.5, 1.0, 0.5)  # Green - healthy
		elif hp_percent > 0.5:
			hp_color = Color(1.0, 1.0, 0.3)  # Yellow - wounded
		elif hp_percent > 0.25:
			hp_color = Color(1.0, 0.6, 0.2)  # Orange - hurt
		else:
			hp_color = Color(1.0, 0.3, 0.3)  # Red - critical
		
		status_line.add_theme_color_override("font_color", hp_color)

	# Update location
	if location_label:
		var map_name = MapManager.current_map.map_id if MapManager.current_map else "Unknown"
		location_label.text = map_name.replace("_", " ").capitalize()
	
	# Update active effects with nearby enemy count
	if active_effects_label:
		var nearby_enemies = _count_nearby_enemies()
		if nearby_enemies > 0:
			active_effects_label.text = "DANGER: %d enem%s nearby!" % [
				nearby_enemies, "y" if nearby_enemies == 1 else "ies"
			]
			active_effects_label.add_theme_color_override("font_color", Color.RED)
		else:
			active_effects_label.text = "ACTIVE EFFECTS: None"
			active_effects_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))

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
	if not MapManager.current_map or not MapManager.current_map.has_meta("enemy_spawns"):
		return

	var enemy_spawns = MapManager.current_map.get_meta("enemy_spawns")

	for spawn_data in enemy_spawns:
		var enemy_id = spawn_data["enemy_id"]
		var spawn_pos = spawn_data["position"]
		EntityManager.spawn_enemy(enemy_id, spawn_pos)

## Render all entities on the current map
func _render_all_entities() -> void:
	for entity in EntityManager.entities:
		if entity.is_alive:
			renderer.render_entity(entity.position, entity.ascii_char, entity.color)

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
	if character_info_label:
		character_info_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	if status_line:
		status_line.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	if location_label:
		location_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	if active_effects_label:
		active_effects_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))

	# Set ability label color
	var ability1 = $HUD/BottomBar/Abilities/Ability1
	if ability1:
		ability1.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
