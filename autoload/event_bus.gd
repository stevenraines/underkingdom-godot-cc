extends Node

## EventBus - Central signal hub for loose coupling between systems
##
## This autoload provides a central location for game-wide signals,
## allowing systems to communicate without direct dependencies.

# Turn and time signals
signal turn_advanced(turn_number: int)
signal time_of_day_changed(period: String)  # "dawn", "day", "dusk", "night"

# Player signals
signal player_moved(old_pos: Vector2i, new_pos: Vector2i)

# Map signals
signal map_changed(map_id: String)

func _ready() -> void:
	print("EventBus initialized")
