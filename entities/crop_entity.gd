class_name CropEntity
extends Entity

## CropEntity - A growing crop planted on tilled soil
##
## Tracks growth through stages and can be harvested when mature.

# Crop definition data
var crop_id: String = ""
var crop_data: Dictionary = {}  # Loaded from JSON

# Growth tracking
var current_stage: int = 0
var turns_in_stage: int = 0
var planted_turn: int = 0  # Turn when this crop was planted

# Reference to the tile this crop is on
var tile_position: Vector2i = Vector2i.ZERO

func _init(p_crop_id: String = "", pos: Vector2i = Vector2i.ZERO, p_crop_data: Dictionary = {}) -> void:
	crop_id = p_crop_id
	tile_position = pos
	crop_data = p_crop_data
	planted_turn = TurnManager.current_turn

	var display_char = "."
	var display_color = Color.LIGHT_GREEN

	if crop_data.has("growth_stages") and crop_data.growth_stages.size() > 0:
		var stage = crop_data.growth_stages[0]
		display_char = stage.get("ascii_char", ".")
		display_color = Color.from_string(stage.get("color", "#90EE90"), Color.LIGHT_GREEN)

	super._init(
		"crop_" + p_crop_id + "_" + str(pos.x) + "_" + str(pos.y),
		pos,
		display_char,
		display_color,
		false  # Crops don't block movement
	)
	entity_type = "crop"
	name = crop_data.get("name", "Crop") + " (Seedling)"

## Create a crop entity from crop data
static func create(p_crop_id: String, pos: Vector2i, p_crop_data: Dictionary):
	var script = load("res://entities/crop_entity.gd")
	var crop = script.new(p_crop_id, pos, p_crop_data)
	return crop

## Advance growth by one turn. Returns true if stage changed.
func advance_growth() -> bool:
	if not crop_data.has("growth_stages"):
		return false

	var stages = crop_data.growth_stages
	if current_stage >= stages.size() - 1:
		return false  # Already at final stage

	var current_stage_data = stages[current_stage]
	var duration = current_stage_data.get("duration_turns", -1)

	if duration < 0:
		return false  # Infinite duration (mature stage)

	turns_in_stage += 1

	if turns_in_stage >= duration:
		# Advance to next stage
		current_stage += 1
		turns_in_stage = 0
		_update_visual()
		return true

	return false

## Update visual representation based on current stage
func _update_visual() -> void:
	if not crop_data.has("growth_stages"):
		return

	var stages = crop_data.growth_stages
	if current_stage >= stages.size():
		return

	var stage_data = stages[current_stage]
	ascii_char = stage_data.get("ascii_char", "?")
	color = Color.from_string(stage_data.get("color", "#FFFFFF"), Color.WHITE)
	name = crop_data.get("name", "Crop") + " (" + stage_data.get("name", "Unknown") + ")"

## Check if the crop is harvestable
func is_harvestable() -> bool:
	if not crop_data.has("growth_stages"):
		return false

	var stages = crop_data.growth_stages
	if current_stage >= stages.size():
		return false

	return stages[current_stage].get("harvestable", false)

## Check if the crop is vulnerable to trampling
func is_trample_vulnerable() -> bool:
	if not crop_data.has("growth_stages"):
		return true

	var stages = crop_data.growth_stages
	if current_stage >= stages.size():
		return false

	return stages[current_stage].get("trample_vulnerable", false)

## Get the current growth stage data
func get_current_stage_data() -> Dictionary:
	if not crop_data.has("growth_stages"):
		return {}

	var stages = crop_data.growth_stages
	if current_stage >= stages.size():
		return {}

	return stages[current_stage]

## Get the current stage name
func get_stage_name() -> String:
	var stage_data = get_current_stage_data()
	return stage_data.get("name", "Unknown")

## Get harvest yields - returns array of {item_id, count} dictionaries
func get_harvest_yields() -> Array:
	var yields = []

	if not crop_data.has("yields"):
		return yields

	for yield_entry in crop_data.yields:
		var item_id = yield_entry.get("item_id", "")
		if item_id.is_empty():
			continue

		var chance = yield_entry.get("chance", 1.0)
		if randf() > chance:
			continue  # Failed chance check

		var min_count = yield_entry.get("min_count", 1)
		var max_count = yield_entry.get("max_count", 1)
		var count = randi_range(min_count, max_count)

		if count > 0:
			yields.append({"item_id": item_id, "count": count})

	return yields

## Get stamina cost for harvesting
func get_harvest_stamina_cost() -> int:
	return crop_data.get("harvest_stamina_cost", 5)

## Get harvest message
func get_harvest_message() -> String:
	return crop_data.get("harvest_message", "You harvest the crop")

## Get interaction text for look mode
func get_interaction_text() -> String:
	if is_harvestable():
		return "Harvest: %s" % name
	return "Examine: %s" % name

## Get tooltip
func get_tooltip() -> String:
	var stage_name = get_stage_name()
	var crop_name = crop_data.get("name", "Unknown Crop")

	if is_harvestable():
		return "%s (%s) - Ready to harvest" % [crop_name, stage_name]
	else:
		var stages = crop_data.get("growth_stages", [])
		var remaining_turns = 0

		# Calculate remaining turns to maturity
		for i in range(current_stage, stages.size()):
			var stage = stages[i]
			var duration = stage.get("duration_turns", 0)
			if duration > 0:
				if i == current_stage:
					remaining_turns += duration - turns_in_stage
				else:
					remaining_turns += duration

		return "%s (%s) - %d turns to harvest" % [crop_name, stage_name, remaining_turns]

## Serialize crop for saving
func serialize() -> Dictionary:
	return {
		"crop_id": crop_id,
		"position": {"x": position.x, "y": position.y},
		"current_stage": current_stage,
		"turns_in_stage": turns_in_stage,
		"planted_turn": planted_turn
	}

## Deserialize crop from saved data
static func deserialize(data: Dictionary, p_crop_data: Dictionary):
	var pos = Vector2i(data.get("position", {}).get("x", 0), data.get("position", {}).get("y", 0))
	var script = load("res://entities/crop_entity.gd")
	var crop = script.new(data.get("crop_id", ""), pos, p_crop_data)
	crop.current_stage = data.get("current_stage", 0)
	crop.turns_in_stage = data.get("turns_in_stage", 0)
	crop.planted_turn = data.get("planted_turn", 0)
	crop._update_visual()
	return crop
