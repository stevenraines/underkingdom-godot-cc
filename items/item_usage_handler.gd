class_name ItemUsageHandler
extends RefCounted

## ItemUsageHandler - Handles item usage, effects, and learning
##
## Extracted from Item class to separate data from behavior.
## All methods are static, taking the item as the first parameter.

const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")


# =============================================================================
# MAIN USAGE
# =============================================================================

## Use an item, returning result dictionary
## Result: {"success": bool, "message": String, "consumed": bool}
static func use(item: Item, user: Entity) -> Dictionary:
	if item == null or user == null:
		return {"success": false, "consumed": false, "message": ""}

	# Reveal curse on use if item is cursed and not yet revealed
	if item.is_cursed and not item.curse_revealed:
		item.reveal_curse()
		var item_name = item.get_display_name()
		EventBus.message_logged.emit("The %s reveals its true nature - it is cursed!" % item_name, Color.RED)

	# Handle wands (charged spell items)
	if item.is_wand():
		return _use_wand(item, user)

	# Handle scrolls (can be identified by casts_spell or scroll flag)
	if item.casts_spell != "" or item.flags.get("scroll", false):
		return _use_scroll(item, user)

	# Handle books (can be any item_type with book flag)
	if item.flags.get("book", false) or item.flags.get("readable", false):
		return _use_book(item, user)

	var result: Dictionary = {
		"success": false,
		"consumed": false,
		"message": ""
	}

	match item.item_type:
		"consumable":
			result = _use_consumable(item, user)
		"book":
			# Books without flag still work
			result = _use_book(item, user)
		"tool":
			# Tools are generally not "used" directly
			# Waterskin is special case
			if item.id == "waterskin_full":
				result = _use_consumable(item, user)
			else:
				result.message = "You can't use that directly."
		_:
			result.message = "You can't use that."

	return result


# =============================================================================
# CONSUMABLES
# =============================================================================

## Use a consumable item (food, potion, bandage)
static func _use_consumable(item: Item, user: Entity) -> Dictionary:
	var result = {
		"success": true,
		"consumed": true,
		"message": "You use the %s." % item.name
	}

	# Check if stat is already at max before consuming
	if user.get("survival"):
		var survival = user.survival
		# Check hunger-restoring items
		if "hunger" in item.effects and survival.hunger >= 100.0:
			return {
				"success": false,
				"consumed": false,
				"message": "You are not hungry."
			}
		# Check thirst-restoring items
		if "thirst" in item.effects and survival.thirst >= 100.0:
			return {
				"success": false,
				"consumed": false,
				"message": "You are not thirsty."
			}
		# Check mana-restoring items
		if "restore_mana" in item.effects and survival.mana >= survival.max_mana:
			return {
				"success": false,
				"consumed": false,
				"message": "Your mana is already full."
			}

	# Apply effects
	if user.has_method("apply_item_effects"):
		user.apply_item_effects(item.effects)
	else:
		# Fallback for direct effect application
		if "hunger" in item.effects and user.get("survival"):
			user.survival.eat(item.effects.hunger)
			result.message = "You eat the %s." % item.name
		if "thirst" in item.effects and user.get("survival"):
			user.survival.drink(item.effects.thirst)
			result.message = "You drink from the %s." % item.name
		if "health" in item.effects:
			user.heal(item.effects.health)
			result.message = "You use the %s and feel better." % item.name
		# Handle mana restoration
		if "restore_mana" in item.effects and user.get("survival"):
			var survival = user.survival
			var amount = item.effects.restore_mana
			# Check for percentage restoration
			if item.effects.get("restore_mana_percent", false):
				amount = survival.max_mana
			var old_mana = survival.mana
			survival.mana = minf(survival.mana + amount, survival.max_mana)
			var restored = survival.mana - old_mana
			result.message = "You drink the %s. Mana restored: %d" % [item.name, int(restored)]
			EventBus.mana_changed.emit(old_mana, survival.mana, survival.max_mana)

	# Identify the consumable on use (potions)
	if item.unidentified and result.success:
		_identify_on_use(item, result)

	return result


# =============================================================================
# BOOKS
# =============================================================================

## Read a book item - teaches recipe, spell, or ritual
static func _use_book(item: Item, user: Entity) -> Dictionary:
	var result = {
		"success": false,
		"consumed": false,  # Books are NOT consumed after reading by default
		"message": ""
	}

	# Check if this is a spell tome
	if item.teaches_spell != "":
		return _use_spell_tome(item, user)

	# Check if this is a ritual tome
	if item.teaches_ritual != "":
		return _use_ritual_tome(item, user)

	# Book without recipe to teach
	if item.teaches_recipe == "":
		result.message = "You read %s but learn nothing new." % item.name
		result.success = true
		return result

	# Check if player already knows recipe
	if user.has_method("knows_recipe") and user.knows_recipe(item.teaches_recipe):
		result.message = "You already know the recipe described in this book."
		result.success = true
		return result

	# Teach the recipe
	if user.has_method("learn_recipe"):
		user.learn_recipe(item.teaches_recipe)
		var recipe = RecipeManager.get_recipe(item.teaches_recipe)
		var recipe_name = recipe.get_display_name() if recipe else item.teaches_recipe
		result.message = "You read %s and learn how to craft %s!" % [item.name, recipe_name]
		result.success = true
		if recipe:
			EventBus.recipe_discovered.emit(recipe)

	return result


## Use a spell tome to learn a spell
static func _use_spell_tome(item: Item, user: Entity) -> Dictionary:
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
	var spell = SpellManager.get_spell(item.teaches_spell)
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
	if user.has_method("knows_spell") and user.knows_spell(item.teaches_spell):
		result.message = "You already know this spell."
		result.success = true  # Still successful read, just no new knowledge
		return result

	# Learn the spell
	if user.has_method("learn_spell"):
		if user.learn_spell(item.teaches_spell):
			result.message = "You inscribe %s into your spellbook!" % spell.name
			result.success = true
			result.consumed = true  # Spell tomes are consumed after learning
		else:
			result.message = "You cannot learn this spell."

	return result


## Use a ritual tome to learn a ritual
static func _use_ritual_tome(item: Item, user: Entity) -> Dictionary:
	var result = {
		"success": false,
		"consumed": false,
		"message": ""
	}

	# Get the ritual
	var ritual = RitualManager.get_ritual(item.teaches_ritual)
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
	if user.has_method("knows_ritual") and user.knows_ritual(item.teaches_ritual):
		result.message = "You already know this ritual."
		result.success = true  # Still successful read, just no new knowledge
		return result

	# Learn the ritual
	if user.has_method("learn_ritual"):
		if user.learn_ritual(item.teaches_ritual):
			result.message = "You commit the %s ritual to memory!" % ritual.name
			result.success = true
			result.consumed = true  # Ritual tomes are consumed after learning
			EventBus.ritual_learned.emit(user, item.teaches_ritual)
		else:
			result.message = "You cannot learn this ritual."

	return result


# =============================================================================
# SCROLLS
# =============================================================================

## Use a spell scroll to cast a spell
static func _use_scroll(item: Item, user: Entity) -> Dictionary:
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
	if item.effects.get("cursed_effect", false):
		const CurseSystemClass = preload("res://systems/curse_system.gd")
		var curse_result = CurseSystemClass.use_cursed_scroll(user, item)
		# Identify the cursed scroll
		if item.unidentified:
			_identify_on_use(item, curse_result)
		return curse_result

	# Get the spell from the scroll
	var spell = SpellManager.get_spell(item.casts_spell)
	if spell == null:
		result.message = "This scroll contains corrupted magic."
		return result

	# Scrolls bypass level/INT requirements for the spell itself
	# They just need minimum 8 INT to use any scroll

	# Check targeting mode
	var targeting_mode = spell.get_targeting_mode()
	if targeting_mode == "self":
		# Self-targeting spells cast immediately from scroll
		result = _cast_scroll_spell(item, user, spell, user)
		result.consumed = result.success
	elif targeting_mode in ["ranged", "touch"]:
		# Ranged/touch spells need targeting - signal for targeting mode
		result.success = true
		result.requires_targeting = true
		result.scroll_spell = spell
		result.message = "Select a target for %s..." % spell.name
		# Emit signal for input handler to start targeting
		EventBus.scroll_targeting_started.emit(item, spell)
	else:
		result.message = "Unknown scroll targeting type."

	return result


## Cast a spell from a scroll on a target
## Scrolls don't consume mana, don't fail, and cast at base spell level
static func _cast_scroll_spell(item: Item, caster: Entity, spell, target: Entity) -> Dictionary:
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
	# from_item=true bypasses class magic type restrictions
	var cast_result = SpellCastingSystemClass.cast_spell(caster, spell, target, true)

	# Copy results
	result.success = cast_result.success or not cast_result.failed
	result.damage = cast_result.damage
	result.healing = cast_result.healing
	result.message = cast_result.message
	result.effects_applied = cast_result.effects_applied

	# Identify the scroll on use
	if item.unidentified and result.success:
		_identify_on_use(item, result)

	return result


# =============================================================================
# WANDS
# =============================================================================

## Use a wand to cast its spell (consumes a charge)
static func _use_wand(item: Item, user: Entity) -> Dictionary:
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
	if item.charges <= 0:
		result.message = "The %s is out of charges." % item.name
		return result

	# Get the spell from the wand
	var spell = SpellManager.get_spell(item.casts_spell)
	if spell == null:
		result.message = "This wand contains corrupted magic."
		return result

	# Check targeting mode
	var targeting_mode = spell.get_targeting_mode()
	if targeting_mode == "self":
		# Self-targeting spells cast immediately from wand
		result = _cast_wand_spell(item, user, spell, user)
		if result.success:
			item.charges -= 1
			EventBus.wand_used.emit(item, spell, item.charges)
	elif targeting_mode in ["ranged", "touch"]:
		# Ranged/touch spells need targeting - signal for targeting mode
		result.success = true
		result.requires_targeting = true
		result.wand_spell = spell
		result.message = "Select a target for %s..." % spell.name
		# Emit signal for input handler to start targeting
		EventBus.wand_targeting_started.emit(item, spell)
	else:
		result.message = "Unknown wand targeting type."

	return result


## Cast a spell from a wand on a target
## Wands don't consume mana, don't fail, and cast at wand's spell level
static func _cast_wand_spell(item: Item, caster: Entity, spell, target: Entity) -> Dictionary:
	var result = {
		"success": true,
		"damage": 0,
		"healing": 0,
		"message": "",
		"from_wand": true,
		"effects_applied": []
	}

	# Use SpellCastingSystem (from_item=true bypasses class restrictions)
	var cast_result = SpellCastingSystemClass.cast_spell(caster, spell, target, true)

	# Copy results
	result.success = cast_result.success or not cast_result.failed
	result.damage = cast_result.damage
	result.healing = cast_result.healing
	result.message = cast_result.message
	result.effects_applied = cast_result.effects_applied

	# Identify the wand on use
	if item.unidentified and result.success:
		_identify_on_use(item, result)

	return result


# =============================================================================
# HELPERS
# =============================================================================

## Helper to identify an item on use and update the result message
static func _identify_on_use(item: Item, result: Dictionary) -> void:
	var id_manager = Engine.get_main_loop().root.get_node_or_null("IdentificationManager")
	if id_manager and not id_manager.is_identified(item.id):
		id_manager.identify_item(item.id)
		result.message += " (It was a %s!)" % item.name
