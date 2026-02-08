extends Node

## IdentificationManager - Autoload singleton for item identification
##
## Implements classic roguelike identification system where scrolls, wands,
## and potions appear with randomized descriptions until identified.

# Maps true_id -> appearance for this playthrough
var scroll_appearances: Dictionary = {}  # "scroll_spark" -> "ZELGO MOR"
var wand_appearances: Dictionary = {}    # "wand_of_sparks" -> "oak"
var potion_appearances: Dictionary = {}  # "mana_potion" -> "murky blue"
var ring_appearances: Dictionary = {}    # "ring_of_power" -> "silver"
var amulet_appearances: Dictionary = {}  # "amulet_of_fortune" -> "bone"
var weapon_appearances: Dictionary = {}  # "sword_of_flame" -> "fine"
var armor_appearances: Dictionary = {}   # "boots_of_speed" -> "ornate"

# Set of identified item IDs for this playthrough
var identified_items: Array[String] = []

# Syllable pools for random scroll labels
const SCROLL_SYLLABLES = [
	"ZELGO", "MOR", "XYZZY", "FOOBAR", "KLAATU", "BARADA", "NIKTO",
	"LOREM", "IPSUM", "DOLOR", "AMET", "VERITAS", "ARCANA", "MYSTIS",
	"UMBRA", "NOCTIS", "IGNIS", "AQUA", "TERRA", "VENTUS"
]

# Material pools for random wand descriptions
const WAND_MATERIALS = [
	"oak", "bone", "crystal", "iron", "silver", "obsidian",
	"willow", "ash", "copper", "jade", "ivory", "ebony"
]

# Color pools for random potion descriptions
const POTION_COLORS = [
	"murky blue", "bubbling red", "glowing green", "swirling purple",
	"shimmering gold", "dark black", "clear", "fizzing orange",
	"luminous white", "oily brown", "sparkling pink", "cloudy gray"
]

# Material pools for random ring descriptions
const RING_APPEARANCES = [
	"silver", "gold", "ornate", "bronze", "jade", "ruby",
	"platinum", "iron", "copper", "bone", "crystal"
]

# Material pools for random amulet descriptions
const AMULET_APPEARANCES = [
	"silver", "bone", "crystal", "leather", "copper",
	"jade", "obsidian", "wooden", "ivory", "golden"
]

# Prefix pools for random weapon descriptions
const WEAPON_PREFIXES = [
	"fine", "ornate", "gleaming", "engraved", "masterwork",
	"polished", "decorated", "well-crafted"
]

# Prefix pools for random armor descriptions
const ARMOR_PREFIXES = [
	"fine", "ornate", "gleaming", "masterwork", "polished",
	"decorated", "well-made", "reinforced"
]

func _ready() -> void:
	# Generate appearances on new game
	EventBus.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	_generate_random_appearances()

## Generate random appearances for all unidentified items
func _generate_random_appearances() -> void:
	# Clear existing appearances for new game
	scroll_appearances.clear()
	wand_appearances.clear()
	potion_appearances.clear()
	ring_appearances.clear()
	amulet_appearances.clear()
	weapon_appearances.clear()
	armor_appearances.clear()
	identified_items.clear()

	# Shuffle pools
	var syllables = SCROLL_SYLLABLES.duplicate()
	syllables.shuffle()

	var materials = WAND_MATERIALS.duplicate()
	materials.shuffle()

	var colors = POTION_COLORS.duplicate()
	colors.shuffle()

	var ring_materials = RING_APPEARANCES.duplicate()
	ring_materials.shuffle()

	var amulet_materials = AMULET_APPEARANCES.duplicate()
	amulet_materials.shuffle()

	var weapon_prefixes = WEAPON_PREFIXES.duplicate()
	weapon_prefixes.shuffle()

	var armor_prefixes = ARMOR_PREFIXES.duplicate()
	armor_prefixes.shuffle()

	# Track assignment indices
	var scroll_idx = 0
	var wand_idx = 0
	var potion_idx = 0
	var ring_idx = 0
	var amulet_idx = 0
	var weapon_idx = 0
	var armor_idx = 0

	# Assign appearances to each unidentified item type
	for item_id in ItemManager.get_all_item_ids():
		var item_data = ItemManager.get_item_data(item_id)
		if item_data and item_data.get("unidentified", false):
			var subtype = item_data.get("subtype", "")
			var category = item_data.get("category", "")
			match subtype:
				"scroll":
					var syl1 = syllables[scroll_idx % syllables.size()]
					var syl2 = syllables[(scroll_idx + 1) % syllables.size()]
					scroll_appearances[item_id] = syl1 + " " + syl2
					scroll_idx += 2
				"wand":
					wand_appearances[item_id] = materials[wand_idx % materials.size()]
					wand_idx += 1
				"potion":
					potion_appearances[item_id] = colors[potion_idx % colors.size()]
					potion_idx += 1
				"ring":
					ring_appearances[item_id] = ring_materials[ring_idx % ring_materials.size()]
					ring_idx += 1
				"amulet":
					amulet_appearances[item_id] = amulet_materials[amulet_idx % amulet_materials.size()]
					amulet_idx += 1
				_:
					# Check category for weapons and armor
					if category == "weapon":
						weapon_appearances[item_id] = weapon_prefixes[weapon_idx % weapon_prefixes.size()]
						weapon_idx += 1
					elif category == "armor":
						armor_appearances[item_id] = armor_prefixes[armor_idx % armor_prefixes.size()]
						armor_idx += 1

	print("IdentificationManager: Generated random appearances for %d scrolls, %d wands, %d potions, %d rings, %d amulets, %d weapons, %d armor" % [
		scroll_appearances.size(), wand_appearances.size(), potion_appearances.size(),
		ring_appearances.size(), amulet_appearances.size(), weapon_appearances.size(), armor_appearances.size()
	])

## Check if an item has been identified
func is_identified(item_id: String) -> bool:
	return item_id in identified_items

## Mark an item as identified
func identify_item(item_id: String) -> void:
	if not is_identified(item_id):
		identified_items.append(item_id)
		EventBus.item_identified.emit(item_id)

## Get the display name for an item (real name or appearance)
func get_display_name(item) -> String:
	var item_id = item.id if "id" in item else ""
	var is_unidentified = item.unidentified if "unidentified" in item else false

	# If identified or not an unidentified item type, return real name
	if is_identified(item_id) or not is_unidentified:
		return item.name

	# Return appearance-based name
	var subtype = item.subtype if "subtype" in item else ""
	var category = item.category if "category" in item else ""

	match subtype:
		"scroll":
			var appearance = scroll_appearances.get(item_id, "???")
			return "Scroll labeled %s" % appearance
		"wand":
			var appearance = wand_appearances.get(item_id, "strange")
			return "%s wand" % appearance.capitalize()
		"potion":
			var appearance = potion_appearances.get(item_id, "unknown")
			return "%s potion" % appearance.capitalize()
		"ring":
			var appearance = ring_appearances.get(item_id, "plain")
			return "%s ring" % appearance
		"amulet":
			var appearance = amulet_appearances.get(item_id, "plain")
			return "%s amulet" % appearance
		_:
			# Check category for weapons and armor
			if category == "weapon":
				var prefix = weapon_appearances.get(item_id, "fine")
				# Get base weapon type from name (e.g., "Sword of Flame" -> "sword")
				var base_type = _get_base_item_type(item.name)
				return "%s %s" % [prefix, base_type]
			elif category == "armor":
				var prefix = armor_appearances.get(item_id, "fine")
				# Get base armor type from name (e.g., "Boots of Speed" -> "boots")
				var base_type = _get_base_item_type(item.name)
				return "%s %s" % [prefix, base_type]

	return item.name


## Extract base item type from full name (e.g., "Sword of Flame" -> "sword")
func _get_base_item_type(full_name: String) -> String:
	var lower_name = full_name.to_lower()

	# Common weapon types
	if "sword" in lower_name:
		return "sword"
	elif "axe" in lower_name:
		return "axe"
	elif "dagger" in lower_name:
		return "dagger"
	elif "mace" in lower_name:
		return "mace"
	elif "spear" in lower_name:
		return "spear"
	elif "bow" in lower_name:
		return "bow"
	elif "staff" in lower_name:
		return "staff"

	# Common armor types
	elif "boots" in lower_name:
		return "boots"
	elif "gloves" in lower_name:
		return "gloves"
	elif "helmet" in lower_name:
		return "helmet"
	elif "armor" in lower_name:
		return "armor"
	elif "shield" in lower_name:
		return "shield"
	elif "cloak" in lower_name:
		return "cloak"

	# Fallback: take first word
	var words = full_name.split(" ")
	if words.size() > 0:
		return words[0].to_lower()

	return "item"

## Check if high INT allows auto-identification
func check_auto_identify(item, user) -> bool:
	var item_id = item.id if "id" in item else ""

	if is_identified(item_id):
		return true

	# INT 14+ auto-identifies level 1-2 spells
	var user_int = 10
	if user.has_method("get_effective_attribute"):
		user_int = user.get_effective_attribute("INT")
	elif "attributes" in user:
		user_int = user.attributes.get("INT", 10)

	# Check if item casts a spell we can auto-identify
	var casts_spell = item.casts_spell if "casts_spell" in item else ""
	if casts_spell != "":
		var spell = SpellManager.get_spell(casts_spell)
		if spell and user_int >= 14 and spell.level <= 2:
			identify_item(item_id)
			EventBus.message_logged.emit(
				"Your keen intellect reveals this to be a %s." % item.name,
				Color.CYAN
			)
			return true

	return false

## Serialize identification state for saving
func serialize() -> Dictionary:
	return {
		"scroll_appearances": scroll_appearances.duplicate(),
		"wand_appearances": wand_appearances.duplicate(),
		"potion_appearances": potion_appearances.duplicate(),
		"ring_appearances": ring_appearances.duplicate(),
		"amulet_appearances": amulet_appearances.duplicate(),
		"weapon_appearances": weapon_appearances.duplicate(),
		"armor_appearances": armor_appearances.duplicate(),
		"identified_items": identified_items.duplicate()
	}

## Deserialize identification state from save data
func deserialize(data: Dictionary) -> void:
	scroll_appearances = data.get("scroll_appearances", {}).duplicate()
	wand_appearances = data.get("wand_appearances", {}).duplicate()
	potion_appearances = data.get("potion_appearances", {}).duplicate()
	ring_appearances = data.get("ring_appearances", {}).duplicate()
	amulet_appearances = data.get("amulet_appearances", {}).duplicate()
	weapon_appearances = data.get("weapon_appearances", {}).duplicate()
	armor_appearances = data.get("armor_appearances", {}).duplicate()

	# Handle Array type conversion
	var items = data.get("identified_items", [])
	identified_items.clear()
	for item_id in items:
		identified_items.append(item_id)

## Reset identification state for new game
func reset() -> void:
	scroll_appearances.clear()
	wand_appearances.clear()
	potion_appearances.clear()
	ring_appearances.clear()
	amulet_appearances.clear()
	weapon_appearances.clear()
	armor_appearances.clear()
	identified_items.clear()
	_generate_random_appearances()
