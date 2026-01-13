class_name Item
extends RefCounted

## Item - Base class for all items in the game
##
## Items can be consumables, materials, tools, weapons, or armor.
## They exist in inventories or as ground items in the world.
## Items use a flags system to indicate multiple properties.

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
var curse_type: String = ""         # "binding", "draining", "unlucky"
var curse_revealed: bool = false    # True once curse is discovered
var fake_passive_effects: Dictionary = {}  # Fake effects shown before curse reveal

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
## Returns true if the item should be consumed (removed from inventory)
func use(user: Entity) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"consumed": false,
		"message": ""
	}

	# Handle wands (charged spell items)
	if is_wand():
		return _use_wand(user)

	# Handle scrolls (can be identified by casts_spell or scroll flag)
	if casts_spell != "" or flags.get("scroll", false):
		return _use_scroll(user)

	# Handle books (can be any item_type with book flag)
	if flags.get("book", false) or flags.get("readable", false):
		return _use_book(user)

	match item_type:
		"consumable":
			result = _use_consumable(user)
		"book":
			# Books without flag still work
			result = _use_book(user)
		"tool":
			# Tools are generally not "used" directly
			# Waterskin is special case
			if id == "waterskin_full":
				result = _use_consumable(user)
			else:
				result.message = "You can't use that directly."
		_:
			result.message = "You can't use that."

	return result

## Apply consumable effects to user
func _use_consumable(user: Entity) -> Dictionary:
	var result = {
		"success": true,
		"consumed": true,
		"message": "You use the %s." % name
	}

	# Check if stat is already at max before consuming
	if user.get("survival"):
		var survival = user.survival
		# Check hunger-restoring items
		if "hunger" in effects and survival.hunger >= 100.0:
			return {
				"success": false,
				"consumed": false,
				"message": "You are not hungry."
			}
		# Check thirst-restoring items
		if "thirst" in effects and survival.thirst >= 100.0:
			return {
				"success": false,
				"consumed": false,
				"message": "You are not thirsty."
			}
		# Check mana-restoring items
		if "restore_mana" in effects and survival.mana >= survival.max_mana:
			return {
				"success": false,
				"consumed": false,
				"message": "Your mana is already full."
			}

	# Apply effects
	if user.has_method("apply_item_effects"):
		user.apply_item_effects(effects)
	else:
		# Fallback for direct effect application
		if "hunger" in effects and user.get("survival"):
			user.survival.eat(effects.hunger)
			result.message = "You eat the %s." % name
		if "thirst" in effects and user.get("survival"):
			user.survival.drink(effects.thirst)
			result.message = "You drink from the %s." % name
		if "health" in effects:
			user.heal(effects.health)
			result.message = "You use the %s and feel better." % name
		# Handle mana restoration
		if "restore_mana" in effects and user.get("survival"):
			var survival = user.survival
			var amount = effects.restore_mana
			# Check for percentage restoration
			if effects.get("restore_mana_percent", false):
				amount = survival.max_mana
			var old_mana = survival.mana
			survival.mana = minf(survival.mana + amount, survival.max_mana)
			var restored = survival.mana - old_mana
			result.message = "You drink the %s. Mana restored: %d" % [name, int(restored)]
			EventBus.mana_changed.emit(old_mana, survival.mana, survival.max_mana)

	# Identify the consumable on use (potions)
	if unidentified and result.success:
		_identify_on_use(result)

	return result

## Read a book item - teaches recipe if applicable
func _use_book(user: Entity) -> Dictionary:
	var result = {
		"success": false,
		"consumed": false,  # Books are NOT consumed after reading by default
		"message": ""
	}

	# Check if this is a spell tome
	if teaches_spell != "":
		return _use_spell_tome(user)

	# Check if this is a ritual tome
	if teaches_ritual != "":
		return _use_ritual_tome(user)

	# Book without recipe to teach
	if teaches_recipe == "":
		result.message = "You read %s but learn nothing new." % name
		result.success = true
		return result

	# Check if player already knows recipe
	if user.has_method("knows_recipe") and user.knows_recipe(teaches_recipe):
		result.message = "You already know the recipe described in this book."
		result.success = true
		return result

	# Teach the recipe
	if user.has_method("learn_recipe"):
		user.learn_recipe(teaches_recipe)
		var recipe = RecipeManager.get_recipe(teaches_recipe)
		var recipe_name = recipe.get_display_name() if recipe else teaches_recipe
		result.message = "You read %s and learn how to craft %s!" % [name, recipe_name]
		result.success = true
		if recipe:
			EventBus.recipe_discovered.emit(recipe)

	return result

## Use a spell tome to learn a spell
func _use_spell_tome(user: Entity) -> Dictionary:
	var result = {
		"success": false,
		"consumed": false,
		"message": ""
	}

	# Check if player has spellbook
	if not user.has_method("has_spellbook") or not user.has_spellbook():
		result.message = "You need a spellbook to learn spells."
		return result

	# Get the spell
	var spell = SpellManager.get_spell(teaches_spell)
	if spell == null:
		result.message = "This tome contains corrupted knowledge."
		return result

	# Check INT requirement
	var user_int = 10
	if user.has_method("get_effective_attribute"):
		user_int = user.get_effective_attribute("INT")
	elif "attributes" in user:
		user_int = user.attributes.get("INT", 10)

	if user_int < spell.requirements.get("intelligence", 8):
		result.message = "The arcane symbols are incomprehensible to you."
		return result

	# Check level requirement
	var user_level = user.level if "level" in user else 1
	if user_level < spell.requirements.get("character_level", 1):
		result.message = "This magic is beyond your current abilities."
		return result

	# Check if already known
	if user.has_method("knows_spell") and user.knows_spell(teaches_spell):
		result.message = "You already know this spell."
		result.success = true  # Still successful read, just no new knowledge
		return result

	# Learn the spell
	if user.has_method("learn_spell"):
		if user.learn_spell(teaches_spell):
			result.message = "You inscribe %s into your spellbook!" % spell.name
			result.success = true
			result.consumed = true  # Spell tomes are consumed after learning
		else:
			result.message = "You cannot learn this spell."

	return result


## Use a ritual tome to learn a ritual
func _use_ritual_tome(user: Entity) -> Dictionary:
	var result = {
		"success": false,
		"consumed": false,
		"message": ""
	}

	# Get the ritual
	var ritual = RitualManager.get_ritual(teaches_ritual)
	if ritual == null:
		result.message = "This tome contains corrupted knowledge."
		return result

	# Check INT requirement (minimum 8 for any magic)
	var user_int = 10
	if user.has_method("get_effective_attribute"):
		user_int = user.get_effective_attribute("INT")
	elif "attributes" in user:
		user_int = user.attributes.get("INT", 10)

	if user_int < 8:
		result.message = "You lack the intelligence to understand ritual magic."
		return result

	if user_int < ritual.get_min_intelligence():
		result.message = "The ritual described within is too complex for you to comprehend."
		return result

	# Check if already known
	if user.has_method("knows_ritual") and user.knows_ritual(teaches_ritual):
		result.message = "You already know this ritual."
		result.success = true  # Still successful read, just no new knowledge
		return result

	# Learn the ritual
	if user.has_method("learn_ritual"):
		if user.learn_ritual(teaches_ritual):
			result.message = "You commit the %s ritual to memory!" % ritual.name
			result.success = true
			result.consumed = true  # Ritual tomes are consumed after learning
			EventBus.ritual_learned.emit(user, teaches_ritual)
		else:
			result.message = "You cannot learn this ritual."

	return result


## Use a spell scroll to cast a spell
func _use_scroll(user: Entity) -> Dictionary:
	var result = {
		"success": false,
		"consumed": false,
		"message": "",
		"requires_targeting": false,
		"scroll_spell": null
	}

	# Check minimum INT requirement (8) for using scrolls
	var user_int = 10
	if user.has_method("get_effective_attribute"):
		user_int = user.get_effective_attribute("INT")
	elif "attributes" in user:
		user_int = user.attributes.get("INT", 10)

	if user_int < 8:
		result.message = "You lack the intelligence to use scrolls."
		return result

	# Check for cursed scroll (has cursed_effect in effects)
	if effects.get("cursed_effect", false):
		const CurseSystemClass = preload("res://systems/curse_system.gd")
		var curse_result = CurseSystemClass.use_cursed_scroll(user, self)
		# Identify the cursed scroll
		if unidentified:
			_identify_on_use(curse_result)
		return curse_result

	# Get the spell from the scroll
	var spell = SpellManager.get_spell(casts_spell)
	if spell == null:
		result.message = "This scroll contains corrupted magic."
		return result

	# Scrolls bypass level/INT requirements for the spell itself
	# They just need minimum 8 INT to use any scroll

	# Check targeting mode
	var targeting_mode = spell.get_targeting_mode()
	if targeting_mode == "self":
		# Self-targeting spells cast immediately from scroll
		result = _cast_scroll_spell(user, spell, user)
		result.consumed = result.success
	elif targeting_mode in ["ranged", "touch"]:
		# Ranged/touch spells need targeting - signal for targeting mode
		result.success = true
		result.requires_targeting = true
		result.scroll_spell = spell
		result.message = "Select a target for %s..." % spell.name
		# Emit signal for input handler to start targeting
		EventBus.scroll_targeting_started.emit(self, spell)
	else:
		result.message = "Unknown scroll targeting type."

	return result


## Cast a spell from a scroll on a target
## Scrolls don't consume mana, don't fail, and cast at base spell level
func _cast_scroll_spell(caster: Entity, spell, target: Entity) -> Dictionary:
	var result = {
		"success": true,
		"damage": 0,
		"healing": 0,
		"message": "",
		"from_scroll": true,
		"effects_applied": []
	}

	# Use SpellCastingSystem but with special scroll flags
	# Scrolls cast at minimum level (spell.level) with no scaling
	const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")
	var cast_result = SpellCastingSystemClass.cast_spell(caster, spell, target)

	# Copy results
	result.success = cast_result.success or not cast_result.failed
	result.damage = cast_result.damage
	result.healing = cast_result.healing
	result.message = cast_result.message
	result.effects_applied = cast_result.effects_applied

	# Identify the scroll on use
	if unidentified and result.success:
		_identify_on_use(result)

	return result


## Check if this item is a scroll
func is_scroll() -> bool:
	# A scroll has casts_spell but is NOT a wand (no charges)
	if is_wand():
		return false
	return casts_spell != "" or flags.get("scroll", false)


## Check if this item is a wand
func is_wand() -> bool:
	return max_charges > 0 and casts_spell != "" and flags.get("charged", false)


## Use a wand to cast its spell (consumes a charge)
func _use_wand(user: Entity) -> Dictionary:
	var result = {
		"success": false,
		"consumed": false,
		"message": "",
		"requires_targeting": false,
		"wand_spell": null
	}

	# Check minimum INT requirement (8) for using wands
	var user_int = 10
	if user.has_method("get_effective_attribute"):
		user_int = user.get_effective_attribute("INT")
	elif "attributes" in user:
		user_int = user.attributes.get("INT", 10)

	if user_int < 8:
		result.message = "You lack the intelligence to use wands."
		return result

	# Check if wand has charges
	if charges <= 0:
		result.message = "The %s is out of charges." % name
		return result

	# Get the spell from the wand
	var spell = SpellManager.get_spell(casts_spell)
	if spell == null:
		result.message = "This wand contains corrupted magic."
		return result

	# Check targeting mode
	var targeting_mode = spell.get_targeting_mode()
	if targeting_mode == "self":
		# Self-targeting spells cast immediately from wand
		result = _cast_wand_spell(user, spell, user)
		if result.success:
			charges -= 1
			EventBus.wand_used.emit(self, spell, charges)
	elif targeting_mode in ["ranged", "touch"]:
		# Ranged/touch spells need targeting - signal for targeting mode
		result.success = true
		result.requires_targeting = true
		result.wand_spell = spell
		result.message = "Select a target for %s..." % spell.name
		# Emit signal for input handler to start targeting
		EventBus.wand_targeting_started.emit(self, spell)
	else:
		result.message = "Unknown wand targeting type."

	return result


## Cast a spell from a wand on a target
## Wands don't consume mana, don't fail, and cast at wand's spell level
func _cast_wand_spell(caster: Entity, spell, target: Entity) -> Dictionary:
	var result = {
		"success": true,
		"damage": 0,
		"healing": 0,
		"message": "",
		"from_wand": true,
		"effects_applied": []
	}

	# Use SpellCastingSystem
	const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")
	var cast_result = SpellCastingSystemClass.cast_spell(caster, spell, target)

	# Copy results
	result.success = cast_result.success or not cast_result.failed
	result.damage = cast_result.damage
	result.healing = cast_result.healing
	result.message = cast_result.message
	result.effects_applied = cast_result.effects_applied

	# Identify the wand on use
	if unidentified and result.success:
		_identify_on_use(result)

	return result


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
		if damage_bonus > 0:
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

## Check if this item can be used for ranged attack (ranged or thrown)
func can_attack_at_range() -> bool:
	return is_ranged_weapon() or is_thrown_weapon()

## Get the effective attack range
## For thrown weapons, this is modified by STR
func get_effective_range(str_stat: int = 0) -> int:
	if is_thrown_weapon():
		# Thrown range = base_range + STR/2
		@warning_ignore("integer_division")
		return attack_range + (str_stat / 2)
	return attack_range


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


## Helper to identify an item on use and update the result message
func _identify_on_use(result: Dictionary) -> void:
	var id_manager = Engine.get_main_loop().root.get_node_or_null("IdentificationManager")
	if id_manager and not id_manager.is_identified(id):
		id_manager.identify_item(id)
		result.message += " (It was a %s!)" % name


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
