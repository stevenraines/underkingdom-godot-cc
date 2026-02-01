# Refactor 07: Item Usage Handler

**Risk Level**: Medium
**Estimated Changes**: 1 new file, 2 files modified

---

## Goal

Separate item usage logic from the `Item` class data structure.

Extract `use()`, `apply_effects()`, and related methods into an `ItemUsageHandler` class, keeping `Item` as a pure data container.

---

## Current State

### items/item.gd (1,170 lines)
The Item class mixes:
- Data properties (id, name, type, stats, etc.) - ~120 lines
- Factory method `create_from_data()` - ~200 lines
- Usage logic `use()` - ~150 lines with extensive branching
- Effect application `apply_effects()`, `apply_passive_effects()` - ~100 lines
- Spell/ritual learning - ~50 lines
- Equipment mechanics - ~100 lines
- Stack management - ~50 lines
- Serialization - ~100 lines

### Methods to Extract
- `use(user: Entity) -> Dictionary` - Main usage logic
- `apply_effects(user: Entity)` - Apply consumable effects
- `apply_passive_effects(user: Entity)` - Apply equipped item effects
- `remove_passive_effects(user: Entity)` - Remove equipped item effects
- `try_learn_spell(user: Entity)` - Learn spell from book/scroll
- `try_learn_ritual(user: Entity)` - Learn ritual from item
- `try_learn_recipe(user: Entity)` - Learn recipe from book

---

## Implementation

### Step 1: Create items/item_usage_handler.gd

```gdscript
class_name ItemUsageHandler
extends RefCounted

## ItemUsageHandler - Handles item usage, effects, and learning
##
## Extracted from Item class to separate data from behavior.
## All methods are static for easy access.

const SpellCastingSystemClass = preload("res://systems/spell_casting_system.gd")
const RitualSystemClass = preload("res://systems/ritual_system.gd")


# =============================================================================
# MAIN USAGE
# =============================================================================

## Use an item, returning result dictionary
## Result: {"success": bool, "message": String, "consumed": bool}
static func use(item: Item, user: Entity) -> Dictionary:
	if item == null or user == null:
		return {"success": false, "message": "Invalid item or user", "consumed": false}

	match item.item_type:
		"consumable", "food", "potion", "bandage":
			return _use_consumable(item, user)
		"scroll":
			return _use_scroll(item, user)
		"wand":
			return _use_wand(item, user)
		"book":
			return _use_book(item, user)
		"ritual_item":
			return _use_ritual_item(item, user)
		"tool":
			return _use_tool(item, user)
		"key":
			return _use_key(item, user)
		_:
			if item.is_equippable():
				return {"success": false, "message": "Use equipment screen to equip this item", "consumed": false}
			return {"success": false, "message": "Cannot use this item", "consumed": false}


# =============================================================================
# CONSUMABLES
# =============================================================================

## Use a consumable item (food, potion, bandage)
static func _use_consumable(item: Item, user: Entity) -> Dictionary:
	# Check if user can benefit from the item
	if item.item_type == "food":
		if user.has_method("get_hunger") and user.get_hunger() <= 0:
			return {"success": false, "message": "You're not hungry", "consumed": false}

	# Apply effects
	var effects_applied = apply_effects(item, user)

	if effects_applied:
		# Consume the item
		return {"success": true, "message": "Used %s" % item.display_name, "consumed": true}

	return {"success": false, "message": "Item had no effect", "consumed": false}


## Apply item effects to user
static func apply_effects(item: Item, user: Entity) -> bool:
	if item == null or user == null:
		return false

	var had_effect = false

	# Healing
	if item.healing > 0 and user.hp < user.max_hp:
		var heal_amount = mini(item.healing, user.max_hp - user.hp)
		user.hp += heal_amount
		EventBus.player_health_changed.emit(user.hp, user.max_hp)
		EventBus.message_logged.emit("Healed %d HP" % heal_amount)
		had_effect = true

	# Mana restoration
	if item.mana_restore > 0 and user.mp < user.max_mp:
		var restore_amount = mini(item.mana_restore, user.max_mp - user.mp)
		user.mp += restore_amount
		EventBus.player_mana_changed.emit(user.mp, user.max_mp)
		EventBus.message_logged.emit("Restored %d MP" % restore_amount)
		had_effect = true

	# Stamina restoration
	if item.stamina_restore > 0 and user.stamina < user.max_stamina:
		var restore_amount = mini(item.stamina_restore, user.max_stamina - user.stamina)
		user.stamina += restore_amount
		EventBus.player_stamina_changed.emit(user.stamina, user.max_stamina)
		EventBus.message_logged.emit("Restored %d Stamina" % restore_amount)
		had_effect = true

	# Food (hunger reduction)
	if item.nutrition > 0 and user.has_method("reduce_hunger"):
		user.reduce_hunger(item.nutrition)
		had_effect = true

	# Hydration
	if item.hydration > 0 and user.has_method("reduce_thirst"):
		user.reduce_thirst(item.hydration)
		had_effect = true

	# Status effect removal
	if item.cures_poison and user.has_method("cure_poison"):
		user.cure_poison()
		had_effect = true

	if item.cures_disease and user.has_method("cure_disease"):
		user.cure_disease()
		had_effect = true

	# Buff effects
	if item.buffs and not item.buffs.is_empty():
		_apply_buffs(item.buffs, user)
		had_effect = true

	return had_effect


## Apply buff effects from item
static func _apply_buffs(buffs: Dictionary, user: Entity) -> void:
	for buff_id in buffs:
		var buff_data = buffs[buff_id]
		if user.has_method("add_buff"):
			user.add_buff(buff_id, buff_data)


# =============================================================================
# SCROLLS
# =============================================================================

## Use a scroll to cast a spell
static func _use_scroll(item: Item, user: Entity) -> Dictionary:
	if not item.spell_id or item.spell_id.is_empty():
		return {"success": false, "message": "Scroll has no spell", "consumed": false}

	var spell = SpellManager.get_spell(item.spell_id)
	if spell == null:
		return {"success": false, "message": "Unknown spell on scroll", "consumed": false}

	# Check if spell needs targeting
	if spell.needs_target:
		# Trigger targeting mode - scroll consumed after successful cast
		EventBus.scroll_targeting_started.emit(item, spell)
		return {"success": true, "message": "Select target for %s" % spell.name, "consumed": false}

	# Instant cast spell
	var result = SpellCastingSystemClass.cast_spell(user, spell, user.position)
	if result.success:
		return {"success": true, "message": result.message, "consumed": true}

	return {"success": false, "message": result.message, "consumed": false}


# =============================================================================
# WANDS
# =============================================================================

## Use a wand to cast a spell
static func _use_wand(item: Item, user: Entity) -> Dictionary:
	if not item.spell_id or item.spell_id.is_empty():
		return {"success": false, "message": "Wand has no spell", "consumed": false}

	if item.charges <= 0:
		return {"success": false, "message": "Wand is out of charges", "consumed": false}

	var spell = SpellManager.get_spell(item.spell_id)
	if spell == null:
		return {"success": false, "message": "Unknown spell on wand", "consumed": false}

	# Check if spell needs targeting
	if spell.needs_target:
		EventBus.wand_targeting_started.emit(item, spell)
		return {"success": true, "message": "Select target for %s" % spell.name, "consumed": false}

	# Instant cast
	var result = SpellCastingSystemClass.cast_spell(user, spell, user.position)
	if result.success:
		item.charges -= 1
		if item.charges <= 0:
			EventBus.message_logged.emit("The wand crumbles to dust!")
			return {"success": true, "message": result.message, "consumed": true}
		return {"success": true, "message": result.message, "consumed": false}

	return {"success": false, "message": result.message, "consumed": false}


# =============================================================================
# BOOKS
# =============================================================================

## Use a book to learn spells/recipes
static func _use_book(item: Item, user: Entity) -> Dictionary:
	# Recipe book
	if item.teaches_recipe and not item.teaches_recipe.is_empty():
		return _try_learn_recipe(item, user)

	# Spell book
	if item.teaches_spell and not item.teaches_spell.is_empty():
		return _try_learn_spell(item, user)

	return {"success": false, "message": "This book contains nothing useful", "consumed": false}


## Try to learn a spell from item
static func _try_learn_spell(item: Item, user: Entity) -> Dictionary:
	if not user.has_method("learn_spell"):
		return {"success": false, "message": "Cannot learn spells", "consumed": false}

	var spell_id = item.teaches_spell
	if user.knows_spell(spell_id):
		return {"success": false, "message": "You already know this spell", "consumed": false}

	var spell = SpellManager.get_spell(spell_id)
	if spell == null:
		return {"success": false, "message": "Unknown spell", "consumed": false}

	# Check requirements (level, stats, etc.)
	if not _meets_spell_requirements(spell, user):
		return {"success": false, "message": "You don't meet the requirements to learn this spell", "consumed": false}

	user.learn_spell(spell_id)
	return {"success": true, "message": "Learned %s!" % spell.name, "consumed": true}


## Try to learn a recipe from item
static func _try_learn_recipe(item: Item, user: Entity) -> Dictionary:
	if not user.has_method("learn_recipe"):
		return {"success": false, "message": "Cannot learn recipes", "consumed": false}

	var recipe_id = item.teaches_recipe
	if user.knows_recipe(recipe_id):
		return {"success": false, "message": "You already know this recipe", "consumed": false}

	var recipe = RecipeManager.get_recipe(recipe_id)
	if recipe == null:
		return {"success": false, "message": "Unknown recipe", "consumed": false}

	user.learn_recipe(recipe_id)
	return {"success": true, "message": "Learned recipe: %s!" % recipe.name, "consumed": true}


## Check if user meets spell requirements
static func _meets_spell_requirements(spell: Dictionary, user: Entity) -> bool:
	# Level requirement
	if spell.has("min_level") and user.level < spell.min_level:
		return false

	# Stat requirements
	if spell.has("required_int") and user.attributes.get("INT", 0) < spell.required_int:
		return false

	if spell.has("required_wis") and user.attributes.get("WIS", 0) < spell.required_wis:
		return false

	return true


# =============================================================================
# RITUAL ITEMS
# =============================================================================

## Use a ritual item
static func _use_ritual_item(item: Item, user: Entity) -> Dictionary:
	if not item.teaches_ritual or item.teaches_ritual.is_empty():
		return {"success": false, "message": "This item teaches no ritual", "consumed": false}

	if not user.has_method("learn_ritual"):
		return {"success": false, "message": "Cannot learn rituals", "consumed": false}

	var ritual_id = item.teaches_ritual
	if user.knows_ritual(ritual_id):
		return {"success": false, "message": "You already know this ritual", "consumed": false}

	user.learn_ritual(ritual_id)
	var ritual = RitualManager.get_ritual(ritual_id)
	var ritual_name = ritual.name if ritual else ritual_id
	return {"success": true, "message": "Learned ritual: %s!" % ritual_name, "consumed": true}


# =============================================================================
# TOOLS
# =============================================================================

## Use a tool item
static func _use_tool(item: Item, user: Entity) -> Dictionary:
	# Tools are typically used implicitly (fishing rod when fishing, etc.)
	return {"success": false, "message": "Use this tool with the appropriate action", "consumed": false}


# =============================================================================
# KEYS
# =============================================================================

## Use a key item
static func _use_key(item: Item, user: Entity) -> Dictionary:
	# Keys are used automatically when interacting with locked things
	return {"success": false, "message": "Use this key by interacting with a locked object", "consumed": false}


# =============================================================================
# EQUIPMENT EFFECTS
# =============================================================================

## Apply passive effects when item is equipped
static func apply_equipment_effects(item: Item, user: Entity) -> void:
	if item == null or user == null:
		return

	# Stat bonuses
	if item.stat_bonuses:
		for stat in item.stat_bonuses:
			if stat in user.attributes:
				user.attribute_bonuses[stat] = user.attribute_bonuses.get(stat, 0) + item.stat_bonuses[stat]

	# Armor
	if item.armor > 0:
		user.armor_bonus += item.armor

	# Damage bonus
	if item.damage_bonus > 0:
		user.damage_bonus += item.damage_bonus

	# Recalculate derived stats
	if user.has_method("recalculate_stats"):
		user.recalculate_stats()


## Remove passive effects when item is unequipped
static func remove_equipment_effects(item: Item, user: Entity) -> void:
	if item == null or user == null:
		return

	# Stat bonuses
	if item.stat_bonuses:
		for stat in item.stat_bonuses:
			if stat in user.attribute_bonuses:
				user.attribute_bonuses[stat] = user.attribute_bonuses.get(stat, 0) - item.stat_bonuses[stat]

	# Armor
	if item.armor > 0:
		user.armor_bonus -= item.armor

	# Damage bonus
	if item.damage_bonus > 0:
		user.damage_bonus -= item.damage_bonus

	# Recalculate derived stats
	if user.has_method("recalculate_stats"):
		user.recalculate_stats()
```

---

### Step 2: Update items/item.gd

1. **Add preload** at top:
```gdscript
const ItemUsageHandlerClass = preload("res://items/item_usage_handler.gd")
```

2. **Simplify `use()` method**:
```gdscript
## Use this item
func use(user: Entity) -> Dictionary:
	return ItemUsageHandlerClass.use(self, user)
```

3. **Remove** the following methods (now in handler):
- Large `use()` implementation with match statement
- `_use_consumable()`, `_use_scroll()`, `_use_wand()`, etc.
- `apply_effects()`
- `_apply_buffs()`
- `_try_learn_spell()`, `_try_learn_recipe()`, `_try_learn_ritual()`
- `_meets_spell_requirements()`

4. **Update equipment effect methods** to delegate:
```gdscript
func apply_passive_effects(user: Entity) -> void:
	ItemUsageHandlerClass.apply_equipment_effects(self, user)

func remove_passive_effects(user: Entity) -> void:
	ItemUsageHandlerClass.remove_equipment_effects(self, user)
```

---

### Step 3: Update systems/inventory_system.gd

Ensure item usage goes through the handler:

```gdscript
## Use an item from inventory
func use_item(item: Item, user: Entity) -> Dictionary:
	var result = ItemUsageHandlerClass.use(item, user)

	if result.consumed:
		# Remove or reduce stack
		if item.stackable and item.stack_count > 1:
			item.stack_count -= 1
		else:
			remove_item(item)
		EventBus.inventory_changed.emit()

	return result
```

---

## Files Summary

### New Files
- `items/item_usage_handler.gd` (~350 lines)

### Modified Files
- `items/item.gd` - Reduced from 1,170 to ~600 lines
- `systems/inventory_system.gd` - Minor updates

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Use consumable items
  - [ ] Food reduces hunger
  - [ ] Potions heal
  - [ ] Bandages work
- [ ] Use scrolls
  - [ ] Instant spells cast
  - [ ] Targeted spells enter targeting mode
  - [ ] Scroll consumed after successful cast
- [ ] Use wands
  - [ ] Charges decrease
  - [ ] Wand destroyed at 0 charges
- [ ] Use books
  - [ ] Learn recipes
  - [ ] Learn spells
- [ ] Equipment effects
  - [ ] Equipping adds stat bonuses
  - [ ] Unequipping removes stat bonuses
- [ ] Stack management
  - [ ] Using stacked items decreases count
  - [ ] Item removed when stack depleted
- [ ] Save and load
  - [ ] Item usage state preserved
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- items/item.gd
git checkout HEAD -- systems/inventory_system.gd
rm items/item_usage_handler.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
