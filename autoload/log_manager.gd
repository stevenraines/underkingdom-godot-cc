extends Node
class_name LogManagerClass

## Centralized logging service with category filtering
## Usage: LogManager.log_message("Game", "Something happened")
## Or use shortcuts: LogManager.game("Something happened")

# Category enable/disable configuration
# Set to false to suppress logs from that category
var enabled_categories: Dictionary = {
	"Game": true,
	"EntityManager": false,
	"ChunkManager": false,
	"TurnManager": false,
	"FeatureManager": false,
	"MapManager": false,
	"FOW": true,  # Fog of war
	"Render": true,
	"Visibility": false,
	"Combat": false,
	"Items": false,
	"Save": false,
	"WorldChunk": false,
	"TownGenerator": false,
}

# Master switch to disable all logging
var logging_enabled: bool = true

# Log with explicit category
func log_message(category: String, message: String) -> void:
	if not logging_enabled:
		return
	if not enabled_categories.get(category, true):  # Default to enabled for unknown categories
		return
	print("[%s] %s" % [category, message])

# Log without category prefix (for continuation lines)
func log_raw(category: String, message: String) -> void:
	if not logging_enabled:
		return
	if not enabled_categories.get(category, true):
		return
	print(message)

# Shortcut methods for common categories
func game(message: String) -> void:
	log_message("Game", message)

func entity(message: String) -> void:
	log_message("EntityManager", message)

func chunk(message: String) -> void:
	log_message("ChunkManager", message)

func turn(message: String) -> void:
	log_message("TurnManager", message)

func feature(message: String) -> void:
	log_message("FeatureManager", message)

func map(message: String) -> void:
	log_message("MapManager", message)

func fow(message: String) -> void:
	log_message("FOW", message)

func render(message: String) -> void:
	log_message("Render", message)

func visibility(message: String) -> void:
	log_message("Visibility", message)

func combat(message: String) -> void:
	log_message("Combat", message)

func items(message: String) -> void:
	log_message("Items", message)

func save(message: String) -> void:
	log_message("Save", message)

# Enable/disable a category at runtime
func set_category_enabled(category: String, enabled: bool) -> void:
	enabled_categories[category] = enabled

# Enable only specific categories (disables all others)
func enable_only(categories: Array) -> void:
	for cat in enabled_categories.keys():
		enabled_categories[cat] = cat in categories

# Disable all logging
func disable_all() -> void:
	logging_enabled = false

# Enable all logging
func enable_all() -> void:
	logging_enabled = true

# Reset to default configuration
func reset_to_defaults() -> void:
	logging_enabled = true
	enabled_categories = {
		"Game": true,
		"EntityManager": false,
		"ChunkManager": false,
		"TurnManager": false,
		"FeatureManager": false,
		"MapManager": false,
		"FOW": true,
		"Render": true,
		"Visibility": false,
		"Combat": false,
		"Items": false,
		"Save": false,
		"WorldChunk": false,
		"TownGenerator": false,
	}
