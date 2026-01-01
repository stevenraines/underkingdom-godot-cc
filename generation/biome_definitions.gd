class_name BiomeDefinition

## BiomeDefinition - Defines properties for a biome type
##
## Used by BiomeGenerator to determine terrain, resource spawning, and visual properties

var biome_id: String
var biome_name: String
var base_tile: String  # "floor", "water", etc.
var tree_density: float  # 0.0-1.0 probability of tree spawning
var rock_density: float  # 0.0-1.0 probability of rock spawning
var grass_char: String  # Visual character for floor tiles
var floor_color: Color  # Color for floor tiles
var movement_cost_modifier: float  # Future: stamina cost multiplier (1.0 = normal)

func _init(
	id: String,
	name: String,
	tile: String = "floor",
	trees: float = 0.0,
	rocks: float = 0.0,
	grass: String = ".",
	color: Color = Color(0.31, 0.31, 0.31),
	move_cost: float = 1.0
) -> void:
	biome_id = id
	biome_name = name
	base_tile = tile
	tree_density = trees
	rock_density = rocks
	grass_char = grass
	floor_color = color
	movement_cost_modifier = move_cost

## Static biome table lookup
## Returns BiomeDefinition based on elevation and moisture values (both 0.0-1.0)
static func get_biome(elevation: float, moisture: float) -> BiomeDefinition:
	# Ocean biomes (elevation < 0.25)
	if elevation < 0.25:
		if moisture < 0.3:
			return BiomeDefinition.new("deep_ocean", "Deep Ocean", "water", 0.0, 0.0, "~", Color(0.1, 0.2, 0.6))
		elif moisture < 0.6:
			return BiomeDefinition.new("ocean", "Ocean", "water", 0.0, 0.0, "~", Color(0.2, 0.4, 0.8))
		else:
			return BiomeDefinition.new("marsh", "Marsh", "floor", 0.05, 0.0, ",", Color(0.3, 0.4, 0.2), 1.5)

	# Low elevation biomes (0.25-0.4) - Coastal/lowland
	elif elevation < 0.4:
		if moisture < 0.3:
			return BiomeDefinition.new("beach", "Beach", "floor", 0.0, 0.02, ".", Color(0.9, 0.9, 0.6))
		elif moisture < 0.6:
			return BiomeDefinition.new("grassland", "Grassland", "floor", 0.05, 0.03, "\"", Color(0.4, 0.7, 0.3))
		else:
			return BiomeDefinition.new("wetland", "Wetland", "floor", 0.15, 0.0, ",", Color(0.3, 0.5, 0.3), 1.3)

	# Medium elevation biomes (0.4-0.65) - Temperate
	elif elevation < 0.65:
		if moisture < 0.3:
			return BiomeDefinition.new("scrubland", "Scrubland", "floor", 0.08, 0.05, ".", Color(0.6, 0.5, 0.3))
		elif moisture < 0.6:
			return BiomeDefinition.new("woodland", "Woodland", "floor", 0.25, 0.04, ".", Color(0.35, 0.5, 0.25))
		else:
			return BiomeDefinition.new("forest", "Forest", "floor", 0.45, 0.02, ".", Color(0.2, 0.4, 0.2))

	# High elevation biomes (0.65-0.85) - Hills/mountains
	elif elevation < 0.85:
		if moisture < 0.3:
			return BiomeDefinition.new("rocky_hills", "Rocky Hills", "floor", 0.02, 0.15, ".", Color(0.5, 0.5, 0.5))
		elif moisture < 0.6:
			return BiomeDefinition.new("taiga", "Taiga", "floor", 0.30, 0.08, ".", Color(0.3, 0.4, 0.3))
		else:
			return BiomeDefinition.new("dense_forest", "Dense Forest", "floor", 0.55, 0.03, ".", Color(0.15, 0.35, 0.15))

	# Mountain biomes (elevation >= 0.85)
	else:
		if moisture < 0.3:
			return BiomeDefinition.new("barren_rock", "Barren Rock", "floor", 0.0, 0.25, "^", Color(0.4, 0.4, 0.4))
		elif moisture < 0.6:
			return BiomeDefinition.new("snow", "Snow", "floor", 0.01, 0.10, ".", Color(0.9, 0.9, 0.95))
		else:
			return BiomeDefinition.new("glacier", "Glacier", "floor", 0.0, 0.08, "≡", Color(0.8, 0.85, 0.95))
