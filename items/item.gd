class_name Item
extends RefCounted

## Item - Base class for all items in the game
##
## Items can be consumables, materials, tools, weapons, or armor.
## They exist in inventories or as ground items in the world.
## Items use a flags system to indicate multiple properties.

const ItemUsageHandlerClass = preload("res://items/item_usage_handler.gd")

# Core identification
var id: String = ""                 # Unique identifier (e.g., "iron_knife")
var name: String = ""               # Display name
var description: String = ""        # Item description

# Classification
var item_type: String = ""          # Legacy: "consumable", "material", "tool", "weapon", "armor", "currency"
var category: String = ""           # Folder category (weapon, armor, tool, consumable, material, misc)
var subtype: String = ""            # Further classification (e.g., "knife", "chest_armor")

# Flags - flexible boolean properties
var flags: Dictionary = {}          # {"equippable": true, "consumable": false, "tool": true, etc.}

# Physical properties
var weight: float = 0.0             # Weight in kg
var value: int = 0                  # Base gold value

# Stacking
var stack_size: int = 1             # Current stack count
var max_stack: int = 1              # Maximum stack size

# Display
var ascii_char: String = "?"        # ASCII display character
var ascii_color: String = "#FFFFFF" # Hex color for rendering

# Durability (for tools/weapons/armor)
var durability: int = -1            # -1 = no durability
var max_durability: int = -1        # -1 = no durability

# Equipment properties
var equip_slot: String = ""         # Legacy: single slot (for backwards compatibility)
var equip_slots: Array[String] = [] # Which slots this can equip to (e.g., ["main_hand", "off_hand"])
var armor_value: int = 0            # Damage reduction when equipped
var damage_bonus: int = 0           # Added to base damage when equipped
var damage_min: int = 0             # Minimum weapon damage (0 = use damage_bonus as flat value)
var damage_max: int = 0             # Maximum weapon damage (0 = use damage_bonus as flat value)

# Damage type properties (for weapons and attacks)
var damage_type: String = "bludgeoning"      # Primary damage type (slashing, piercing, bludgeoning, etc.)
var secondary_damage_type: String = ""       # Optional secondary damage type (e.g., fire for enchanted weapons)
var secondary_damage_bonus: int = 0          # Bonus damage for secondary type

# Ranged weapon properties
var attack_type: String = "melee"   # "melee", "ranged", or "thrown"
var attack_range: int = 1           # Maximum attack distance in tiles
var ammunition_type: String = ""    # Required ammo type (e.g., "arrow", "bolt")
var accuracy_modifier: int = 0      # Bonus/penalty to hit chance
var recovery_chance: float = 0.5    # Chance ammo/thrown weapon can be recovered (0.0-1.0)

# Tool properties
var tool_type: String = ""          # "knife", "hammer", etc. for crafting requirements

# Light source properties
var provides_light: bool = false    # True if this item provides light
var light_radius: int = 0           # Light radius in tiles (0 = no light)
var burns_per_turn: float = 0.0     # Durability consumed per turn when lit
var is_lit: bool = false            # True if the light source is currently lit (for torches/lanterns)

# Key properties
var key_id: String = ""             # For specific keys - matches a lock's lock_id
var skeleton_key_level: int = 0     # For skeleton keys - can open locks at or below this level

# Temperature properties (for armor/clothing)
var warmth: float = 0.0             # Temperature modifier when equipped (positive = warmer, negative = cooler)

# Inscription (player-added label)
var inscription: String = ""        # Player-written inscription displayed in {curly braces}

# Consumable effects
var effects: Dictionary = {}        # {"hunger": 30, "thirst": 20, "health": 10}

# Spell learning (for spell tomes)
var teaches_spell: String = ""      # Spell ID to learn when this item is read

# Ritual learning (for ritual tomes)
var teaches_ritual: String = ""     # Ritual ID to learn when this item is read

# Scroll properties (for spell scrolls)
var casts_spell: String = ""        # Spell ID to cast when scroll is used

# Wand properties (for charged spell items)
var charges: int = -1               # Current charges (-1 = not a wand)
var max_charges: int = -1           # Maximum charges (-1 = not a wand)
var recharge_cost: int = 0          # Gold cost to recharge at mage NPC
var spell_level_override: int = -1  # Override spell level when cast from wand (-1 = use spell's level)

# Staff/casting focus properties
var casting_bonuses: Dictionary = {} # {success_modifier, school_affinity, school_damage_bonus, mana_cost_modifier}

# Passive effects (for rings, amulets - applied while equipped)
var passive_effects: Dictionary = {} # {stat_bonuses: {STR: +1}, resistances: {fire: 50}, etc.}

# Transform on use (e.g., full waterskin -> empty waterskin)
var transforms_into: String = ""    # Item ID to transform into after use

# Crafting ingredient provision (e.g., waterskin_full provides fresh_water)
var provides_ingredient: String = "" # Item ID this item can provide as a crafting ingredient

# Template/variant tracking (for factory-generated items)
var template_id: String = ""        # Original template ID (e.g., "knife")
var applied_variants: Dictionary = {} # {variant_type: variant_name}
var is_templated: bool = false      # True if created from template + variants

# Book properties
var teaches_recipe: String = ""     # Recipe ID this book teaches when read

# Identification properties
var unidentified: bool = false      # True if item needs identification before revealing true name
var true_name: String = ""          # Real name (for cursed items that show false name)
var true_description: String = ""   # Real description (for cursed items)

# Curse properties
var is_cursed: bool = false         # True if item is cursed
var curse_type: String = ""         # "binding", "stat_penalty", "draining", "unlucky"
var curse_revealed: bool = false    # True once curse is discovered
var fake_passive_effects: Dictionary = {}  # Fake effects shown before curse reveal

# Draining curse properties
var curse_drain_type: String = ""  # "health", "mana", "stamina"
var curse_drain_amount: int = 0    # Amount drained per turn

# Unlucky curse properties
var curse_accuracy_penalty: int = 0      # Penalty to hit chance
var curse_dodge_penalty: int = 0         # Penalty to dodge chance
var curse_encounter_modifier: float = 1.0  # Multiplier for encounter rate (e.g., 1.25 = 25% more encounters)

## Create an item from a data dictionary (loaded from JSON)
static func create_from_data(data: Dictionary) -> Item:
	var item = Item.new()
	
	# Core properties
	item.id = data.get("id", "unknown")
	item.name = data.get("name", "Unknown Item")
	item.description = data.get("description", "")
	
	# Classification
	item.item_type = data.get("item_type", "material")
	item.category = data.get("category", "")
	item.subtype = data.get("subtype", "")
	
	# Flags
	item.flags = data.get("flags", {})
	
	# Physical
	item.weight = data.get("weight", 0.0)
	item.value = data.get("value", 0)
	
	# Stacking
	item.max_stack = data.get("max_stack", 1)
	item.stack_size = 1
	
	# Display
	item.ascii_char = data.get("ascii_char", "?")
	item.ascii_color = data.get("ascii_color", "#FFFFFF")
	
	# Durability
	item.max_durability = data.get("durability", -1)
	item.durability = item.max_durability
	
	# Equipment - support both new equip_slots array and legacy equip_slot
	var slots_data = data.get("equip_slots", [])
	if slots_data is Array:
		for slot in slots_data:
			item.equip_slots.append(str(slot))
	
	# Legacy support: if equip_slot exists but equip_slots is empty, use it
	var legacy_slot = data.get("equip_slot", "")
	if legacy_slot != "" and item.equip_slots.is_empty():
		item.equip_slots.append(legacy_slot)
	
	# Set equip_slot to first slot for backwards compatibility
	if not item.equip_slots.is_empty():
		item.equip_slot = item.equip_slots[0]
	
	item.armor_value = data.get("armor_value", 0)
	item.damage_bonus = data.get("damage_bonus", 0)
	item.damage_min = data.get("damage_min", 0)
	item.damage_max = data.get("damage_max", 0)

	# Damage type properties
	item.damage_type = data.get("damage_type", "bludgeoning")
	item.secondary_damage_type = data.get("secondary_damage_type", "")
	item.secondary_damage_bonus = data.get("secondary_damage_bonus", 0)

	# Ranged weapon properties
	item.attack_type = data.get("attack_type", "melee")
	item.attack_range = data.get("attack_range", 1)
	item.ammunition_type = data.get("ammunition_type", "")
	item.accuracy_modifier = data.get("accuracy_modifier", 0)
	item.recovery_chance = data.get("recovery_chance", 0.5)

	# Tool
	item.tool_type = data.get("tool_type", "")

	# Light source properties
	item.provides_light = data.get("provides_light", false)
	item.light_radius = data.get("light_radius", 0)
	item.burns_per_turn = data.get("burns_per_turn", 0.0)
	item.is_lit = data.get("is_lit", false)

	# Key properties
	item.key_id = data.get("key_id", "")
	item.skeleton_key_level = data.get("skeleton_key_level", 0)

	# Temperature properties
	item.warmth = data.get("warmth", 0.0)

	# Consumable effects
	item.effects = data.get("effects", {})

	# Spell learning
	item.teaches_spell = data.get("teaches_spell", "")

	# Ritual learning
	item.teaches_ritual = data.get("teaches_ritual", "")

	# Scroll properties
	item.casts_spell = data.get("casts_spell", "")

	# Wand properties
	item.max_charges = data.get("max_charges", -1)
	item.charges = data.get("charges", item.max_charges)  # Default to max if not specified
	item.recharge_cost = data.get("recharge_cost", 0)
	item.spell_level_override = data.get("spell_level_override", -1)

	# Staff/casting focus properties
	item.casting_bonuses = data.get("casting_bonuses", {})

	# Passive effects (for rings, amulets)
	item.passive_effects = data.get("passive_effects", {})

	# Transform on use
	item.transforms_into = data.get("transforms_into", "")

	# Crafting ingredient provision
	item.provides_ingredient = data.get("provides_ingredient", "")

	# Template/variant tracking (for factory-generated items)
	if "_template_id" in data:
		item.template_id = data.get("_template_id", "")
		item.applied_variants = data.get("_variants", {}).duplicate()
		item.is_templated = true

	# Book properties
	item.teaches_recipe = data.get("teaches_recipe", "")

	# Identification properties
	item.unidentified = data.get("unidentified", false)
	item.true_name = data.get("true_name", "")
	item.true_description = data.get("true_description", "")

	# Curse properties
	item.is_cursed = data.get("is_cursed", false) or data.get("flags", {}).get("cursed", false)
	item.curse_type = data.get("curse_type", "")
	item.curse_revealed = data.get("curse_revealed", false)
	item.fake_passive_effects = data.get("fake_passive_effects", {})

	# Draining curse properties
	item.curse_drain_type = data.get("curse_drain_type", "")
	item.curse_drain_amount = data.get("curse_drain_amount", 0)

	# Unlucky curse properties
	item.curse_accuracy_penalty = data.get("curse_accuracy_penalty", 0)
	item.curse_dodge_penalty = data.get("curse_dodge_penalty", 0)
	item.curse_encounter_modifier = data.get("curse_encounter_modifier", 1.0)

	return item

## Create a copy of this item
func duplicate_item() -> Item:
	var copy = Item.new()
	copy.id = id
	copy.name = name
	copy.description = description
	copy.item_type = item_type
	copy.category = category
	copy.subtype = subtype
	copy.flags = flags.duplicate()
	copy.weight = weight
	copy.value = value
	copy.stack_size = stack_size
	copy.max_stack = max_stack
	copy.ascii_char = ascii_char
	copy.ascii_color = ascii_color
	copy.durability = durability
	copy.max_durability = max_durability
	copy.equip_slot = equip_slot
	copy.equip_slots = equip_slots.duplicate()
	copy.armor_value = armor_value
	copy.damage_bonus = damage_bonus
	copy.damage_min = damage_min
	copy.damage_max = damage_max
	copy.damage_type = damage_type
	copy.secondary_damage_type = secondary_damage_type
	copy.secondary_damage_bonus = secondary_damage_bonus
	copy.attack_type = attack_type
	copy.attack_range = attack_range
	copy.ammunition_type = ammunition_type
	copy.accuracy_modifier = accuracy_modifier
	copy.recovery_chance = recovery_chance
	copy.tool_type = tool_type
	copy.provides_light = provides_light
	copy.light_radius = light_radius
	copy.burns_per_turn = burns_per_turn
	copy.is_lit = is_lit
	copy.key_id = key_id
	copy.skeleton_key_level = skeleton_key_level
	copy.warmth = warmth
	copy.inscription = inscription
	copy.effects = effects.duplicate()
	copy.transforms_into = transforms_into
	copy.provides_ingredient = provides_ingredient
	copy.template_id = template_id
	copy.applied_variants = applied_variants.duplicate()
	copy.is_templated = is_templated
	copy.teaches_recipe = teaches_recipe
	copy.teaches_spell = teaches_spell
	copy.teaches_ritual = teaches_ritual
	copy.casts_spell = casts_spell
	copy.charges = charges
	copy.max_charges = max_charges
	copy.recharge_cost = recharge_cost
	copy.spell_level_override = spell_level_override
	copy.casting_bonuses = casting_bonuses.duplicate()
	copy.passive_effects = passive_effects.duplicate(true)
	copy.unidentified = unidentified
	copy.true_name = true_name
	copy.true_description = true_description
	copy.is_cursed = is_cursed
	copy.curse_type = curse_type
	copy.curse_revealed = curse_revealed
	copy.fake_passive_effects = fake_passive_effects.duplicate(true)
	copy.curse_drain_type = curse_drain_type
	copy.curse_drain_amount = curse_drain_amount
	copy.curse_accuracy_penalty = curse_accuracy_penalty
	copy.curse_dodge_penalty = curse_dodge_penalty
	copy.curse_encounter_modifier = curse_encounter_modifier
	return copy

## Get the display name (handles unidentified items and inscriptions)
func get_display_name() -> String:
	var display_name = name

	# Use IdentificationManager if available (it's an autoload)
	if Engine.has_singleton("IdentificationManager"):
		var id_manager = Engine.get_singleton("IdentificationManager")
		display_name = id_manager.get_display_name(self)
	else:
		# Fallback: check if we can access it as a node
		var id_manager = Engine.get_main_loop().root.get_node_or_null("IdentificationManager")
		if id_manager:
			display_name = id_manager.get_display_name(self)

	# Add inscription if present
	if inscription != "":
		return "%s {%s}" % [display_name, inscription]

	return display_name

## Check if this item is currently identified
func is_identified() -> bool:
	if not unidentified:
		return true  # Non-unidentified items are always "identified"

	var id_manager = Engine.get_main_loop().root.get_node_or_null("IdentificationManager")
	if id_manager:
		return id_manager.is_identified(id)

	return true  # Fallback to identified

## Use this item on an entity
## Returns result dictionary with success, consumed, message
func use(user: Entity) -> Dictionary:
	return ItemUsageHandlerClass.use(self, user)


## Check if this item is a scroll
func is_scroll() -> bool:
	# A scroll has casts_spell but is NOT a wand (no charges)
	if is_wand():
		return false
	return casts_spell != "" or flags.get("scroll", false)


## Check if this item is a wand
func is_wand() -> bool:
	return max_charges > 0 and casts_spell != "" and flags.get("charged", false)


## Check if this item can stack with another item
func can_stack_with(other: Item) -> bool:
	if not other:
		return false
	if id != other.id:
		return false
	if max_stack <= 1:
		return false
	if stack_size >= max_stack:
		return false
	return true

## Add to this item's stack
## Returns the leftover amount that couldn't be added
func add_to_stack(amount: int) -> int:
	var space = max_stack - stack_size
	var to_add = min(amount, space)
	stack_size += to_add
	return amount - to_add

## Remove from this item's stack
## Returns the amount actually removed
func remove_from_stack(amount: int) -> int:
	var to_remove = min(amount, stack_size)
	stack_size -= to_remove
	return to_remove

## Get the total weight of this item stack
func get_total_weight() -> float:
	return weight * stack_size

## Check if this item can be equipped (uses flags or equip_slots)
func is_equippable() -> bool:
	# Check flag first, then fall back to equip_slots
	if flags.get("equippable", false):
		return true
	return not equip_slots.is_empty()

## Check if this item can be equipped to a specific slot
func can_equip_to_slot(slot: String) -> bool:
	if not is_equippable():
		return false
	# Handle accessory slots specially - both accessory_1 and accessory_2 match "accessory"
	if slot in ["accessory_1", "accessory_2"]:
		return "accessory" in equip_slots
	return slot in equip_slots

## Get all slots this item can be equipped to
func get_equip_slots() -> Array[String]:
	return equip_slots

## Check if this item requires two hands
func is_two_handed() -> bool:
	return flags.get("two_handed", false)

## Check if this item is consumable
func is_consumable() -> bool:
	if flags.get("consumable", false):
		return true
	return item_type == "consumable"

## Check if this item is usable (consumable, book, or has readable flag)
func is_usable() -> bool:
	if is_consumable():
		return true
	if flags.get("book", false) or flags.get("readable", false):
		return true
	return item_type == "book"

## Check if this item is a tool
func is_tool() -> bool:
	if flags.get("tool", false):
		return true
	return item_type == "tool" or tool_type != ""

## Check if this item is a crafting material
func is_crafting_material() -> bool:
	return flags.get("crafting_material", false) or item_type == "material"

## Check if this item has a specific flag
func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)

## Get all flags for this item
func get_flags() -> Dictionary:
	return flags

## Check if this item is a tool of the specified type
func is_tool_type(required_type: String) -> bool:
	return tool_type == required_type

## Reduce durability by 1
## Returns true if item broke
func use_durability() -> bool:
	if durability <= 0 and max_durability > 0:
		return true  # Already broken
	
	if durability > 0:
		durability -= 1
		if durability <= 0:
			return true  # Just broke
	
	return false

## Get durability as a percentage (0-100)
func get_durability_percent() -> int:
	if max_durability <= 0:
		return 100  # No durability = always full
	return int((float(durability) / float(max_durability)) * 100.0)

## Get tooltip text for this item
func get_tooltip() -> String:
	var lines: Array[String] = []
	
	lines.append(name)
	
	if description != "":
		lines.append(description)
	
	lines.append("")
	lines.append("Type: %s" % item_type.capitalize())
	lines.append("Weight: %.2f kg" % weight)
	
	if value > 0:
		lines.append("Value: %d gold" % value)
	
	if stack_size > 1:
		lines.append("Stack: %d/%d" % [stack_size, max_stack])
	
	if equip_slot != "":
		lines.append("Equips to: %s" % equip_slot.replace("_", " ").capitalize())
		# Show damage for weapons
		if damage_min > 0 and damage_max > 0:
			# Has damage range - show range plus bonus
			if damage_bonus > 0:
				lines.append("Damage: %d-%d +%d" % [damage_min, damage_max, damage_bonus])
			else:
				lines.append("Damage: %d-%d" % [damage_min, damage_max])
		elif damage_bonus > 0:
			# Legacy: flat damage bonus only
			lines.append("Damage: +%d" % damage_bonus)
		if armor_value > 0:
			lines.append("Armor: %d" % armor_value)
		if warmth != 0.0:
			var warmth_text = "%+.0f°F" % warmth
			lines.append("Warmth: %s" % warmth_text)
	
	if tool_type != "":
		lines.append("Tool type: %s" % tool_type.capitalize())
	
	if durability > 0:
		lines.append("Durability: %d/%d" % [durability, max_durability])

	# Wand charges
	if max_charges > 0:
		lines.append("Charges: %d/%d" % [charges, max_charges])
		if casts_spell != "":
			var spell = SpellManager.get_spell(casts_spell)
			if spell:
				lines.append("Casts: %s" % spell.name)

	if effects.size() > 0:
		lines.append("")
		lines.append("Effects:")
		for effect_name in effects:
			var effect_value = effects[effect_name]
			var sign_str = "+" if effect_value > 0 else ""
			lines.append("  %s: %s%d" % [effect_name.capitalize(), sign_str, effect_value])
	
	return "\n".join(lines)

## Get display color as Color object
func get_color() -> Color:
	return Color.from_string(ascii_color, Color.WHITE)


## Inscribe text on this item
func inscribe(text: String) -> void:
	inscription = text


## Remove inscription from this item
func uninscribe() -> void:
	inscription = ""


## Check if this item has an inscription
func has_inscription() -> bool:
	return inscription != ""


## Serialize item for saving
## Returns minimal data needed to recreate this item
func serialize() -> Dictionary:
	var data: Dictionary = {
		"id": id,
		"stack_size": stack_size
	}

	# Only save durability if not at max
	if durability >= 0 and durability != max_durability:
		data["durability"] = durability

	# Include template info for templated items
	if is_templated:
		data["template_id"] = template_id
		data["variants"] = applied_variants.duplicate()

	# Save lit state for light sources
	if is_lit:
		data["is_lit"] = true

	# Save inscription if present
	if inscription != "":
		data["inscription"] = inscription

	# Save wand charges if not at max
	if max_charges > 0 and charges != max_charges:
		data["charges"] = charges

	return data

## Check if item stack is empty
func is_empty() -> bool:
	return stack_size <= 0

## Check if this item is a ranged weapon (bow, crossbow, sling)
func is_ranged_weapon() -> bool:
	return attack_type == "ranged"

## Check if this item is a thrown weapon
func is_thrown_weapon() -> bool:
	return attack_type == "thrown" or flags.get("throwable", false)

## Check if this is a charged spell item (wand, rod) that can be used for ranged attacks
func is_charged_ranged_item() -> bool:
	return is_wand() and charges > 0

## Check if this item is ammunition
func is_ammunition() -> bool:
	return flags.get("ammunition", false) or category == "ammunition"

## Check if this item is a key (specific or skeleton)
func is_key() -> bool:
	return flags.get("key", false)

## Check if this item is a skeleton key
func is_skeleton_key() -> bool:
	return flags.get("skeleton_key", false)

## Check if this item is a lockpick
func is_lockpick() -> bool:
	return tool_type == "lockpick"

## Check if this item can be used for ranged attack (ranged, thrown, or charged spell item)
func can_attack_at_range() -> bool:
	return is_ranged_weapon() or is_thrown_weapon() or is_charged_ranged_item()

## Get the effective attack range
## For thrown weapons, this is modified by STR
## For charged spell items (wands), uses the spell's range
func get_effective_range(str_stat: int = 0) -> int:
	if is_thrown_weapon():
		# Thrown range = base_range + STR/2
		@warning_ignore("integer_division")
		return attack_range + (str_stat / 2)
	if is_charged_ranged_item() and casts_spell != "":
		# Use spell's range for wands
		var spell = SpellManager.get_spell(casts_spell)
		if spell:
			return spell.get_range()
	return attack_range


## Roll weapon damage (between min and max, plus bonus)
## If no damage range defined, returns damage_bonus as flat value
func roll_damage() -> int:
	if damage_min > 0 and damage_max > 0:
		return randi_range(damage_min, damage_max) + damage_bonus
	return damage_bonus


## Get minimum possible damage from this weapon
func get_min_damage() -> int:
	if damage_min > 0:
		return damage_min + damage_bonus
	return damage_bonus


## Get maximum possible damage from this weapon
func get_max_damage() -> int:
	if damage_max > 0:
		return damage_max + damage_bonus
	return damage_bonus


## Check if this item is a casting focus (staff)
func is_casting_focus() -> bool:
	return flags.get("casting_focus", false)


## Check if this item is a staff
func is_staff() -> bool:
	return subtype == "staff" or flags.get("casting_focus", false)


## Get casting bonuses provided by this item
## Returns dictionary with: success_modifier, school_affinity, school_damage_bonus, mana_cost_modifier
func get_casting_bonuses() -> Dictionary:
	return casting_bonuses


## Check if this item has passive effects
func has_passive_effects() -> bool:
	return not passive_effects.is_empty()


## Get passive effects provided by this item
## Returns dictionary that may contain: stat_bonuses, max_mana_bonus, max_health_bonus,
## resistances, mana_regen_bonus, health_regen_bonus, etc.
func get_passive_effects() -> Dictionary:
	return passive_effects


## Check if this item is a ring
func is_ring() -> bool:
	return subtype == "ring"


## Check if this item is an amulet
func is_amulet() -> bool:
	return subtype == "amulet"


## Check if this item has a curse
func has_curse() -> bool:
	return is_cursed and curse_type != ""


## Reveal the curse on this item
func reveal_curse() -> void:
	if is_cursed and not curse_revealed:
		curse_revealed = true
		EventBus.curse_revealed.emit(self)


## Remove the curse from this item
func remove_curse() -> void:
	if is_cursed:
		is_cursed = false
		curse_type = ""
		curse_revealed = false
		# Restore true name if it was hidden
		if true_name != "":
			name = true_name
		if true_description != "":
			description = true_description
		EventBus.curse_removed.emit(self)


## Check if this item has binding curse (cannot be unequipped)
func has_binding_curse() -> bool:
	return is_cursed and curse_type == "binding"


## Get the effective passive effects (real or fake based on curse reveal)
func get_effective_passive_effects() -> Dictionary:
	# If cursed but not revealed, show fake effects
	if is_cursed and not curse_revealed and not fake_passive_effects.is_empty():
		return fake_passive_effects
	return passive_effects
