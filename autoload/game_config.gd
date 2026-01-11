extends Node

## GameConfig - Loads and manages game configuration settings
##
## Provides access to configurable game constants for progression, balance, etc.

# Progression settings
var xp_multiplier: float = 1.0  # Multiplier for XP requirements (1.0 = normal, 0.5 = half, 2.0 = double)
var skill_points_divisor: float = 3.0  # Divisor for skill points per level (level / divisor)
var ability_point_interval: int = 4  # Levels between ability point grants

const CONFIG_PATH = "res://data/configuration/configuration.json"

func _ready() -> void:
	_load_configuration()

## Load configuration from JSON file
func _load_configuration() -> void:
	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		push_warning("GameConfig: Could not load configuration file at %s, using defaults" % CONFIG_PATH)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("GameConfig: Error parsing configuration JSON: %s" % json.get_error_message())
		return

	var data = json.data
	if not data is Dictionary:
		push_error("GameConfig: Configuration root is not a dictionary")
		return

	# Load progression settings
	if data.has("progression"):
		var prog = data.progression
		if prog.has("xp_multiplier"):
			xp_multiplier = float(prog.xp_multiplier)
		if prog.has("skill_points_divisor"):
			skill_points_divisor = float(prog.skill_points_divisor)
		if prog.has("ability_point_interval"):
			ability_point_interval = int(prog.ability_point_interval)

	print("GameConfig loaded: XP multiplier=%.2f, Skill divisor=%.1f, Ability interval=%d" %
		[xp_multiplier, skill_points_divisor, ability_point_interval])
