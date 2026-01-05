class_name ShelterComponent
extends RefCounted

## ShelterComponent - Provides protection from weather and temperature
##
## Attached to structures like lean-tos to provide shelter benefits.
## When player rests inside shelter, HP is restored every hp_restore_turns turns.

# Shelter properties
var shelter_radius: int = 2  # Tiles (Manhattan distance)
var temperature_bonus: float = 5.0  # Degrees Fahrenheit
var blocks_rain: bool = true  # Future: weather system integration

# HP restoration properties
var hp_restore_turns: int = 10  # Restore 1 HP every X turns while resting in shelter
var hp_restore_amount: int = 1  # Amount of HP restored per interval

## Check if a position is sheltered by this structure
func is_sheltered(shelter_pos: Vector2i, target_pos: Vector2i) -> bool:
	var distance = abs(target_pos.x - shelter_pos.x) + abs(target_pos.y - shelter_pos.y)
	return distance <= shelter_radius
