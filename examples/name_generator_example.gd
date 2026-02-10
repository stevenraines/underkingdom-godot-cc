extends Node
## Example script demonstrating the NameGenerator system
##
## This script can be run to test name generation.
## Attach it to a node and run the scene to see output in console.

const SeededRandomClass = preload("res://generation/seeded_random.gd")

func _ready():
	print("=== Name Generator Examples ===\n")

	# Create a seeded RNG for deterministic generation
	var rng = SeededRandomClass.new(12345)

	# Generate human names
	print("--- Human Names ---")
	for i in range(5):
		var name = NameGenerator.generate_personal_name("human", "male", rng)
		print("  %s" % name)
	print()

	for i in range(5):
		var name = NameGenerator.generate_personal_name("human", "female", rng)
		print("  %s" % name)
	print()

	# Generate dwarf names
	print("--- Dwarf Names ---")
	for i in range(5):
		var name = NameGenerator.generate_personal_name("dwarf", "male", rng)
		print("  %s" % name)
	print()

	# Generate elf names
	print("--- Elf Names ---")
	for i in range(5):
		var name = NameGenerator.generate_personal_name("elf", "female", rng)
		print("  %s" % name)
	print()

	# Generate halfling names
	print("--- Halfling Names ---")
	for i in range(5):
		var name = NameGenerator.generate_personal_name("halfling", "male", rng)
		print("  %s" % name)
	print()

	# Generate settlement names
	print("--- Settlement Names ---")
	for i in range(5):
		var town = NameGenerator.generate_settlement_name("town", "", rng)
		print("  Town: %s" % town)
	print()

	for i in range(3):
		var fort = NameGenerator.generate_settlement_name("fort", "", rng)
		print("  Fort: %s" % fort)
	print()

	# Generate ship names
	print("--- Ship Names ---")
	for i in range(5):
		var ship = NameGenerator.generate_ship_name(rng)
		print("  %s" % ship)
	print()

	# Generate book titles
	print("--- Book Titles ---")
	for i in range(5):
		var book = NameGenerator.generate_book_title("", rng)
		print("  %s" % book)
	print()

	print("=== End Examples ===")
