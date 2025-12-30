class_name SeededRandom

## SeededRandom - Deterministic random number generation
##
## Wraps Godot's RandomNumberGenerator with a seeded instance
## to ensure deterministic procedural generation.

var rng: RandomNumberGenerator

func _init(seed_value: int) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value

## Get random integer
func randi() -> int:
	return rng.randi()

## Get random float [0.0, 1.0)
func randf() -> float:
	return rng.randf()

## Get random integer in range [from, to]
func randi_range(from: int, to: int) -> int:
	return rng.randi_range(from, to)

## Get random float in range [from, to]
func randf_range(from: float, to: float) -> float:
	return rng.randf_range(from, to)

## Pick random element from array
func choice(array: Array):
	if array.is_empty():
		return null
	return array[randi_range(0, array.size() - 1)]
