class_name FireComponent
extends RefCounted

## FireComponent - Provides heat, cooking capability, and light
##
## Attached to structures like campfires to provide warmth and enable cooking.

# Heat properties
var heat_radius: int = 3  # Tiles (Manhattan distance)
var temperature_bonus: float = 15.0  # Degrees Fahrenheit
var is_lit: bool = true  # Can be toggled on/off

# Light properties (future: affects FOV)
var provides_light: bool = true
var light_radius: int = 5  # Tiles

## Check if this fire source affects a target position
func affects_position(fire_pos: Vector2i, target_pos: Vector2i) -> bool:
	if not is_lit:
		return false

	var distance = abs(target_pos.x - fire_pos.x) + abs(target_pos.y - fire_pos.y)
	return distance <= heat_radius

## Get the temperature bonus (only if lit)
func get_temperature_bonus() -> float:
	return temperature_bonus if is_lit else 0.0
