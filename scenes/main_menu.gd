extends Control

## MainMenu - Simple main menu scene
##
## Provides options to start a new game or quit.

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var version_label: Label = $VersionLabel
@onready var version_notice: Button = $VBoxContainer/VersionNotice

# Version tracking
const LAST_VERSION_PATH = "user://last_played_version.txt"
var current_version: String = ""

var buttons: Array = []
var selected_index: int = 0
const SELECT_COLOR: Color = Color(0.6, 0.9, 0.6, 1)
const UNSELECT_COLOR: Color = Color(0.7, 0.7, 0.7, 1)

# Character creation state
var pending_character_name: String = ""
var pending_race_id: String = ""
var pending_abilities: Dictionary = {}  # Store rolled/assigned abilities
var pending_skill_points: Dictionary = {}  # Store distributed skill points

func _ready() -> void:
	print("Main menu loaded")
	# Ensure game is not paused (in case we came from death screen or other paused state)
	get_tree().paused = false

	# Load and display version from config file
	_load_version()

	# Check for version update and show notice if newer
	_check_version_update()

	# Load ASCII art from file into Title RichTextLabel
	var logo_path := "res://ui/underkingdom_logo.txt"
	if FileAccess.file_exists(logo_path):
		var f := FileAccess.open(logo_path, FileAccess.READ)
		if f:
			var txt := f.get_as_text()
			f.close()
			var title: RichTextLabel = $VBoxContainer/Title
			title.text = txt.strip_edges(false, true)
	

	# collect buttons in visual order using @onready references
	buttons = [continue_button, start_button, load_button, quit_button]

	for i in range(buttons.size()):
		var b = buttons[i]
		if b:
			b.connect("mouse_entered", Callable(self, "_on_button_mouse_entered").bind(i))
			# Disable automatic focus navigation to prevent conflicts
			b.focus_mode = Control.FOCUS_NONE

	# Hide Continue button if there is no auto-save
	if not SaveManager.has_autosave():
		continue_button.visible = false
		# remove it from navigation
		buttons.erase(continue_button)

	# Hide Quit button on web exports (browser can't be quit from the game)
	if OS.get_name() == "Web":
		quit_button.visible = false
		buttons.erase(quit_button)

	# default selection to first visible button
	selected_index = 0
	update_selection()

	# Setup world name dialog
	var WorldNameDialogScene = load("res://ui/world_name_dialog.tscn")
	var world_name_dialog = WorldNameDialogScene.instantiate()
	add_child(world_name_dialog)
	world_name_dialog.world_name_entered.connect(_on_world_name_entered)
	world_name_dialog.cancelled.connect(_on_world_name_cancelled)

	# Setup race selection dialog
	var RaceSelectionDialogScene = load("res://ui/race_selection_dialog.tscn")
	var race_selection_dialog = RaceSelectionDialogScene.instantiate()
	add_child(race_selection_dialog)
	race_selection_dialog.race_selected.connect(_on_race_selected)
	race_selection_dialog.cancelled.connect(_on_race_cancelled)

	# Setup class selection dialog
	var ClassSelectionDialogScene = load("res://ui/class_selection_dialog.tscn")
	var class_selection_dialog = ClassSelectionDialogScene.instantiate()
	add_child(class_selection_dialog)
	class_selection_dialog.class_selected.connect(_on_class_selected)
	class_selection_dialog.cancelled.connect(_on_class_cancelled)

	# Setup ability roll screen
	var AbilityRollScreenScene = load("res://ui/ability_roll_screen.tscn")
	var ability_roll_screen = AbilityRollScreenScene.instantiate()
	add_child(ability_roll_screen)
	ability_roll_screen.confirmed.connect(_on_abilities_confirmed)
	ability_roll_screen.cancelled.connect(_on_abilities_cancelled)

	# Setup bonus points screen (for racial bonus ability points)
	var BonusPointsScreenScene = load("res://ui/bonus_points_screen.tscn")
	var bonus_points_screen = BonusPointsScreenScene.instantiate()
	add_child(bonus_points_screen)
	bonus_points_screen.confirmed.connect(_on_bonus_points_confirmed)
	bonus_points_screen.cancelled.connect(_on_bonus_points_cancelled)

	# Setup skill allocation screen
	var SkillAllocationScreenScene = load("res://ui/skill_allocation_screen.tscn")
	var skill_allocation_screen = SkillAllocationScreenScene.instantiate()
	add_child(skill_allocation_screen)
	skill_allocation_screen.confirmed.connect(_on_skills_confirmed)
	skill_allocation_screen.cancelled.connect(_on_skills_cancelled)

func _on_button_mouse_entered(idx: int) -> void:
	selected_index = idx
	update_selection()

func update_selection() -> void:
	for i in range(buttons.size()):
		if buttons[i]:  # Null check
			if i == selected_index:
				buttons[i].add_theme_color_override("font_color", SELECT_COLOR)
			else:
				buttons[i].add_theme_color_override("font_color", UNSELECT_COLOR)

func _input(event) -> void:
	# Don't process input if world name dialog is visible
	var dialog = get_node_or_null("WorldNameDialog")
	if dialog and dialog.visible:
		return

	# Don't process input if race selection dialog is visible
	var race_dialog = get_node_or_null("RaceSelectionDialog")
	if race_dialog and race_dialog.visible:
		return

	# Don't process input if class selection dialog is visible
	var class_dialog = get_node_or_null("ClassSelectionDialog")
	if class_dialog and class_dialog.visible:
		return

	# Don't process input if ability roll screen is visible
	var ability_screen = get_node_or_null("AbilityRollScreen")
	if ability_screen and ability_screen.visible:
		return

	# Don't process input if bonus points screen is visible
	var bonus_screen = get_node_or_null("BonusPointsScreen")
	if bonus_screen and bonus_screen.visible:
		return

	# Don't process input if skill allocation screen is visible
	var skill_screen = get_node_or_null("SkillAllocationScreen")
	if skill_screen and skill_screen.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP:
			selected_index -= 1
			if selected_index < 0:
				selected_index = buttons.size() - 1
			update_selection()
		elif event.keycode == KEY_DOWN:
			selected_index = (selected_index + 1) % buttons.size()
			update_selection()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			# activate the selected button
			if selected_index >= 0 and selected_index < buttons.size() and buttons[selected_index]:
				buttons[selected_index].emit_signal("pressed")

func _on_start_button_pressed() -> void:
	print("Opening world name dialog...")
	# Open the world name dialog
	var dialog = get_node("WorldNameDialog")
	if dialog:
		dialog.open()

func _on_world_name_entered(character_name: String) -> void:
	print("Character name entered: '%s' - Opening race selection..." % character_name)
	# Store character name temporarily, then open race selection
	pending_character_name = character_name
	var race_dialog = get_node("RaceSelectionDialog")
	if race_dialog:
		race_dialog.open()

func _on_world_name_cancelled() -> void:
	print("World name dialog cancelled")
	# Just return to main menu, nothing to do

func _on_race_selected(race_id: String) -> void:
	print("Race selected: '%s' - Opening class selection..." % race_id)
	# Store race temporarily, then open class selection
	pending_race_id = race_id
	var class_dialog = get_node("ClassSelectionDialog")
	if class_dialog:
		class_dialog.open()

func _on_race_cancelled() -> void:
	print("Race selection cancelled - returning to character name dialog")
	# Return to character name dialog
	var dialog = get_node("WorldNameDialog")
	if dialog:
		dialog.open()

func _on_class_selected(class_id: String) -> void:
	print("Class selected: '%s' - Opening ability roll screen..." % class_id)
	# Store class ID and open ability roll screen
	GameManager.player_class = class_id

	# Create temporary player to preview racial/class modifiers
	var temp_player = Player.new()
	temp_player.apply_race(pending_race_id)
	temp_player.apply_class(class_id)

	# Open ability roll screen
	var ability_screen = get_node("AbilityRollScreen")
	if ability_screen:
		ability_screen.open(temp_player)

func _on_class_cancelled() -> void:
	print("Class selection cancelled - returning to race selection")
	# Return to race selection dialog
	var race_dialog = get_node("RaceSelectionDialog")
	if race_dialog:
		race_dialog.open()

func _on_abilities_confirmed(assigned_abilities: Dictionary) -> void:
	print("Abilities confirmed: %s" % str(assigned_abilities))
	# Store assigned abilities
	pending_abilities = assigned_abilities

	# Check if race grants bonus ability points
	var bonus_points = RaceManager.get_bonus_stat_points(pending_race_id)
	if bonus_points > 0:
		print("Race '%s' grants %d bonus points - Opening bonus points screen..." % [pending_race_id, bonus_points])
		# Create temporary player for preview
		var temp_player = Player.new()
		temp_player.apply_race(pending_race_id)
		temp_player.apply_class(GameManager.player_class)

		var bonus_screen = get_node("BonusPointsScreen")
		if bonus_screen:
			bonus_screen.open(temp_player, assigned_abilities, bonus_points)
	else:
		print("No bonus points - Opening skill allocation...")
		_open_skill_allocation()

func _on_abilities_cancelled() -> void:
	print("Ability roll cancelled - returning to class selection")
	# Return to class selection dialog
	var class_dialog = get_node("ClassSelectionDialog")
	if class_dialog:
		class_dialog.open()

func _on_bonus_points_confirmed(bonus_distributions: Dictionary) -> void:
	print("Bonus points distributed: %s" % str(bonus_distributions))
	# Merge bonus distributions into pending abilities
	for ability in bonus_distributions:
		if pending_abilities.has(ability):
			pending_abilities[ability] += bonus_distributions[ability]
	print("Final abilities after bonus: %s" % str(pending_abilities))
	_open_skill_allocation()

func _on_bonus_points_cancelled() -> void:
	print("Bonus points cancelled - returning to ability roll")
	# Create temporary player again for ability roll screen
	var temp_player = Player.new()
	temp_player.apply_race(pending_race_id)
	temp_player.apply_class(GameManager.player_class)

	# Return to ability roll screen
	var ability_screen = get_node("AbilityRollScreen")
	if ability_screen:
		ability_screen.open(temp_player)

## Helper to open skill allocation (shared by abilities confirmed and bonus points confirmed)
func _open_skill_allocation() -> void:
	# Create temporary player to calculate skill points and preview
	var temp_player = Player.new()
	temp_player.apply_race(pending_race_id)
	temp_player.apply_class(GameManager.player_class)

	# Apply abilities (including any bonus points) to get correct INT for skill point calculation
	for ability in pending_abilities:
		temp_player.attributes[ability] = pending_abilities[ability]

	# Open skill allocation screen
	var skill_screen = get_node("SkillAllocationScreen")
	if skill_screen:
		skill_screen.open(temp_player)

func _on_skills_confirmed(distributed_points: Dictionary) -> void:
	print("Skills confirmed: %s - Starting game..." % str(distributed_points))
	# Store distributed skill points
	pending_skill_points = distributed_points

	# Start game with character name, race, class, abilities, and skill points
	GameManager.player_abilities = pending_abilities
	GameManager.player_skill_points = pending_skill_points
	GameManager.start_new_game(pending_character_name, pending_race_id, GameManager.player_class)
	print("After start_new_game - World seed: %d, Character: '%s', Race: %s, Class: %s" % [GameManager.world_seed, GameManager.character_name, GameManager.player_race, GameManager.player_class])
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_skills_cancelled() -> void:
	print("Skill allocation cancelled - returning to ability roll")
	# Create temporary player again for ability roll screen
	var temp_player = Player.new()
	temp_player.apply_race(pending_race_id)
	temp_player.apply_class(GameManager.player_class)

	# Return to ability roll screen
	var ability_screen = get_node("AbilityRollScreen")
	if ability_screen:
		ability_screen.open(temp_player)

func _get_most_recent_save_slot() -> int:
	var best_slot: int = -1
	var best_ts: String = ""
	for i in range(1, 4):
		var info = SaveManager.get_save_slot_info(i)
		if not info.exists:
			continue
		var ts = info.timestamp if info.timestamp else ""
		# ISO timestamp sorts lexicographically so we can compare strings
		if ts > best_ts:
			best_ts = ts
			best_slot = i
	return best_slot

func _on_load_button_pressed() -> void:
	print("Opening load game screen...")
	# Create and show the pause menu in load mode
	var PauseMenuScene = load("res://ui/pause_menu.tscn")
	var pause_menu = PauseMenuScene.instantiate()
	add_child(pause_menu)
	pause_menu.open(false)  # false = load mode

func _on_continue_button_pressed() -> void:
	# Load auto-save checkpoint
	if not SaveManager.has_autosave():
		print("No auto-save available to continue")
		return

	print("Loading checkpoint...")
	GameManager.is_loading_save = true
	var success = SaveManager.load_autosave()
	if success:
		get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_quit_button_pressed() -> void:
	print("Quitting game...")
	get_tree().quit()

func _load_version() -> void:
	var version_path := "res://version.json"
	if FileAccess.file_exists(version_path):
		var f := FileAccess.open(version_path, FileAccess.READ)
		if f:
			var json_text := f.get_as_text()
			f.close()
			var json := JSON.new()
			var error := json.parse(json_text)
			if error == OK:
				var data: Dictionary = json.data
				var version_str: String = str(data.get("version", "0.0.0"))
				var build_str: String = str(data.get("build", ""))
				current_version = version_str  # Store for version tracking
				if build_str != "":
					version_label.text = "v%s-%s" % [version_str, build_str]
				else:
					version_label.text = "v%s" % version_str
			else:
				version_label.text = "v?.?.?"
				current_version = "0.0.0"
	else:
		version_label.text = "v?.?.?"
		current_version = "0.0.0"


## Check if current version is newer than last played version
func _check_version_update() -> void:
	if current_version == "" or current_version == "0.0.0":
		return

	var last_version = _load_last_played_version()

	if last_version != "" and _is_version_newer(current_version, last_version):
		# Show version update notice
		version_notice.text = "Version Update (v%s). New Features Available!" % current_version
		version_notice.visible = true
		print("Version update detected: %s -> %s" % [last_version, current_version])

	# Always save current version after checking (so notice only shows once per version)
	_save_last_played_version()


## Load the last played version from storage
func _load_last_played_version() -> String:
	if not FileAccess.file_exists(LAST_VERSION_PATH):
		return ""
	var f = FileAccess.open(LAST_VERSION_PATH, FileAccess.READ)
	if not f:
		return ""
	var version = f.get_as_text().strip_edges()
	f.close()
	return version


## Save the current version as last played
func _save_last_played_version() -> void:
	if current_version == "" or current_version == "0.0.0":
		return
	var f = FileAccess.open(LAST_VERSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(current_version)
		f.close()
		print("Saved last played version: %s" % current_version)


## Compare two version strings (e.g., "1.3" vs "1.2")
## Returns true if version_a is newer than version_b
func _is_version_newer(version_a: String, version_b: String) -> bool:
	var parts_a = version_a.split(".")
	var parts_b = version_b.split(".")

	# Compare each part numerically
	var max_parts = max(parts_a.size(), parts_b.size())
	for i in range(max_parts):
		var a = int(parts_a[i]) if i < parts_a.size() else 0
		var b = int(parts_b[i]) if i < parts_b.size() else 0
		if a > b:
			return true
		elif a < b:
			return false

	return false  # Equal versions


## Handle version notice button click - open release notes
func _on_version_notice_pressed() -> void:
	var release_url = "https://github.com/stevenraines/underkingdom-godot-cc/releases"
	print("Opening release notes: %s" % release_url)
	OS.shell_open(release_url)
	# Hide the notice after clicking (version already saved on menu load)
	version_notice.visible = false
