extends GutTest
## Unit tests for CombatSystem
##
## Tests combat calculations, accuracy, evasion, and damage formulas.

const CombatSystemClass = preload("res://systems/combat_system.gd")


func test_are_adjacent_cardinal():
	# Cardinal directions should be adjacent
	assert_true(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(5, 6)))
	assert_true(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(5, 4)))
	assert_true(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(6, 5)))
	assert_true(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(4, 5)))


func test_are_adjacent_diagonal():
	# Diagonal positions should also be adjacent (8-way adjacency)
	assert_true(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(6, 6)))
	assert_true(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(4, 4)))
	assert_true(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(6, 4)))
	assert_true(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(4, 6)))


func test_are_adjacent_not_adjacent():
	# Positions 2+ tiles away should not be adjacent
	assert_false(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(5, 7)))
	assert_false(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(7, 5)))
	assert_false(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(7, 7)))


func test_are_cardinally_adjacent():
	# Only cardinal directions (not diagonal)
	assert_true(CombatSystemClass.are_cardinally_adjacent(Vector2i(5, 5), Vector2i(5, 6)))
	assert_true(CombatSystemClass.are_cardinally_adjacent(Vector2i(5, 5), Vector2i(6, 5)))
	# Diagonals should NOT be cardinally adjacent
	assert_false(CombatSystemClass.are_cardinally_adjacent(Vector2i(5, 5), Vector2i(6, 6)))


func test_same_position_not_adjacent():
	# Same position should not be adjacent
	assert_false(CombatSystemClass.are_adjacent(Vector2i(5, 5), Vector2i(5, 5)))
	assert_false(CombatSystemClass.are_cardinally_adjacent(Vector2i(5, 5), Vector2i(5, 5)))
