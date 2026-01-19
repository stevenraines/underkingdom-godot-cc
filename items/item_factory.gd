class_name ItemFactory
extends RefCounted

## ItemFactory - Creates items from templates + variants
##
## Composes items dynamically at runtime by combining base templates
## with variant modifiers. Supports caching for frequently used combinations.
##
## Example usage:
##   var knife = ItemFactory.create_item("knife", {"material": "iron"})
##   var fancy_sword = ItemFactory.create_item("sword", {"material": "steel", "quality": "fine", "origin": "dwarven"})

# Cache for generated item data (id -> composed data)
static var _item_cache: Dictionary = {}

# Maximum cache size before cleanup
const MAX_CACHE_SIZE: int = 500

# Variant application order (for consistent modifier stacking)
const VARIANT_ORDER: Array[String] = ["material", "quality", "origin", "fish_species", "herb_species", "flower_species", "mushroom_species"]

# Display order for name generation (differs from application order)
const NAME_ORDER: Array[String] = ["origin", "quality", "material", "fish_species", "herb_species", "flower_species", "mushroom_species"]


## Create an item from template + variants
## @param template_id: Base template (e.g., "knife", "sword")
## @param variants: Dictionary of {variant_type: variant_name}
## @param count: Stack size
## @returns: Item instance or null if invalid
static func create_item(template_id: String, variants: Dictionary = {}, count: int = 1) -> Item:
	# Get template
	var template = VariantManager.get_template(template_id)
	if template.is_empty():
		push_error("ItemFactory: Unknown template: %s" % template_id)
		return null

	# Apply default variants for any missing required variants
	var final_variants = _apply_defaults(template, variants)

	# Validate combination
	if not is_valid_combination(template_id, final_variants):
		push_error("ItemFactory: Invalid variant combination for %s: %s" % [template_id, final_variants])
		return null

	# Generate item ID
	var item_id = generate_item_id(template_id, final_variants)

	# Check cache first
	if item_id in _item_cache:
		var item = Item.create_from_data(_item_cache[item_id])
		if item.max_stack > 1 and count > 1:
			item.stack_size = mini(count, item.max_stack)
		return item

	# Compose item data
	var composed_data = _compose_item_data(template, final_variants)
	composed_data["id"] = item_id

	# Cache if not full
	if _item_cache.size() < MAX_CACHE_SIZE:
		_item_cache[item_id] = composed_data

	# Create and return item
	var item = Item.create_from_data(composed_data)
	if item.max_stack > 1 and count > 1:
		item.stack_size = mini(count, item.max_stack)

	return item


## Create item with default variants from template
static func create_default_item(template_id: String, count: int = 1) -> Item:
	return create_item(template_id, {}, count)


## Check if a template + variant combination is valid
static func is_valid_combination(template_id: String, variants: Dictionary) -> bool:
	var template = VariantManager.get_template(template_id)
	if template.is_empty():
		return false

	var applicable = template.get("applicable_variants", [])
	var required = template.get("required_variants", [])

	# Check all variants are applicable
	for variant_type in variants:
		if variant_type not in applicable:
			push_warning("ItemFactory: Variant type '%s' not applicable to template '%s'" % [variant_type, template_id])
			return false
		# Check variant exists
		if not VariantManager.has_variant(variant_type, variants[variant_type]):
			push_warning("ItemFactory: Unknown variant '%s' of type '%s'" % [variants[variant_type], variant_type])
			return false

	# Check all required variants are present
	for req in required:
		if req not in variants:
			push_warning("ItemFactory: Missing required variant '%s' for template '%s'" % [req, template_id])
			return false

	return true


## Get composed item data without creating instance (for preview)
static func get_composed_data(template_id: String, variants: Dictionary) -> Dictionary:
	var template = VariantManager.get_template(template_id)
	if template.is_empty():
		return {}

	var final_variants = _apply_defaults(template, variants)
	if not is_valid_combination(template_id, final_variants):
		return {}

	var composed_data = _compose_item_data(template, final_variants)
	composed_data["id"] = generate_item_id(template_id, final_variants)
	return composed_data


## Generate a deterministic item ID from template + variants
## Format: <variant1>_<variant2>_<template_id> (alphabetical by type)
static func generate_item_id(template_id: String, variants: Dictionary) -> String:
	var parts: Array[String] = []

	# Sort variant types alphabetically for consistent ordering
	var variant_types = variants.keys()
	variant_types.sort()

	for variant_type in variant_types:
		var variant_name: String = variants[variant_type]
		# Skip empty/standard variants that don't modify the name
		if variant_name != "" and variant_name != "standard":
			parts.append(variant_name)

	parts.append(template_id)
	return "_".join(parts)


## Clear the item cache
static func clear_cache() -> void:
	_item_cache.clear()


## Apply default variants for missing required/default variants
static func _apply_defaults(template: Dictionary, variants: Dictionary) -> Dictionary:
	var result = variants.duplicate()
	var defaults = template.get("default_variants", {})

	for variant_type in defaults:
		if variant_type not in result:
			result[variant_type] = defaults[variant_type]

	return result


## Compose item data from template + variants
static func _compose_item_data(template: Dictionary, variants: Dictionary) -> Dictionary:
	var data: Dictionary = {}

	# Copy base properties directly
	var base_props = template.get("base_properties", {})
	for key in base_props:
		if base_props[key] is Dictionary:
			data[key] = base_props[key].duplicate()
		elif base_props[key] is Array:
			data[key] = base_props[key].duplicate()
		else:
			data[key] = base_props[key]

	# Copy category/subtype from template
	data["category"] = template.get("category", "")
	data["subtype"] = template.get("subtype", "")
	# Set item_type from category for backwards compatibility
	data["item_type"] = template.get("category", "material")

	# Start with base stats
	var stats = template.get("base_stats", {}).duplicate()

	# Collect applied variant data in order
	var applied_variants: Array[Dictionary] = []
	for variant_type in VARIANT_ORDER:
		if variant_type in variants:
			var variant_name = variants[variant_type]
			var variant_data = VariantManager.get_variant(variant_type, variant_name)
			if not variant_data.is_empty():
				var enriched = variant_data.duplicate()
				enriched["_type"] = variant_type
				enriched["_name"] = variant_name
				applied_variants.append(enriched)

	# Apply modifiers to stats
	stats = _apply_modifiers(stats, applied_variants)

	# Copy stats to data
	for key in stats:
		data[key] = stats[key]

	# Apply overrides from variants (last wins)
	for variant in applied_variants:
		var overrides = variant.get("overrides", {})
		for key in overrides:
			data[key] = overrides[key]

	# Handle effects: start with base_effects, then apply variant effects
	var effects = template.get("base_effects", {}).duplicate()
	for variant in applied_variants:
		var variant_effects = variant.get("effects", {})
		for effect_key in variant_effects:
			# Variant effects add to or override base effects
			if effect_key in effects:
				effects[effect_key] = effects[effect_key] + variant_effects[effect_key]
			else:
				effects[effect_key] = variant_effects[effect_key]
	if not effects.is_empty():
		data["effects"] = effects

	# Generate name and description
	data["name"] = _generate_name(template, applied_variants)
	data["description"] = _generate_description(template, applied_variants)

	# Store variant info for serialization
	data["_template_id"] = template.get("template_id", "")
	data["_variants"] = variants.duplicate()

	return data


## Apply modifiers from variants to base stats
## Multiplicative modifiers are combined first, then additive
static func _apply_modifiers(base_stats: Dictionary, variants: Array[Dictionary]) -> Dictionary:
	var result = base_stats.duplicate()

	# Collect all modifiers by stat
	var multiplicative: Dictionary = {}  # stat -> [values]
	var additive: Dictionary = {}        # stat -> [values]

	for variant in variants:
		var modifiers = variant.get("modifiers", {})
		for stat_name in modifiers:
			var mod = modifiers[stat_name]
			if mod is Dictionary:
				var mod_type = mod.get("type", "add")
				var mod_value = mod.get("value", 0)

				if mod_type == "multiply":
					if stat_name not in multiplicative:
						multiplicative[stat_name] = []
					multiplicative[stat_name].append(mod_value)
				elif mod_type == "add":
					if stat_name not in additive:
						additive[stat_name] = []
					additive[stat_name].append(mod_value)

	# Apply multiplicative first (multiply together)
	for stat_name in multiplicative:
		var combined_mult = 1.0
		for mult in multiplicative[stat_name]:
			combined_mult *= mult
		result[stat_name] = result.get(stat_name, 0) * combined_mult

	# Then apply additive (sum together)
	for stat_name in additive:
		var combined_add = 0.0
		for add_val in additive[stat_name]:
			combined_add += add_val
		result[stat_name] = result.get(stat_name, 0) + combined_add

	# Round integer stats
	var integer_stats = ["durability", "damage_bonus", "damage_min", "damage_max", "armor_value", "value", "attack_range", "accuracy_modifier"]
	for stat_name in integer_stats:
		if stat_name in result:
			result[stat_name] = int(round(result[stat_name]))

	# Ensure minimums
	if "durability" in result:
		result["durability"] = maxi(1, result["durability"])
	if "value" in result:
		result["value"] = maxi(1, result["value"])

	return result


## Generate item name from template + variants
## Display order: origin, quality, material, template name
static func _generate_name(template: Dictionary, applied_variants: Array[Dictionary]) -> String:
	var prefixes: Array[String] = []
	var name_override: String = ""

	# Collect prefixes in display order
	for variant_type in NAME_ORDER:
		for variant in applied_variants:
			if variant.get("_type", "") == variant_type:
				# Check for name_override first (completely replaces base name)
				if variant.has("name_override") and variant.get("name_override", "") != "":
					name_override = variant.get("name_override")
				var prefix = variant.get("name_prefix", "")
				if prefix != "":
					prefixes.append(prefix)

	# Use override if present, otherwise use base name with prefixes
	if name_override != "":
		if prefixes.is_empty():
			return name_override
		else:
			prefixes.append(name_override)
			return " ".join(prefixes)

	# Add base name
	prefixes.append(template.get("display_name", "Item"))

	return " ".join(prefixes)


## Generate item description from template + variants
static func _generate_description(template: Dictionary, applied_variants: Array[Dictionary]) -> String:
	var base_desc = template.get("description_base", "")

	# Collect description modifiers
	var modifiers: Array[String] = []
	for variant in applied_variants:
		var mod = variant.get("description_modifier", "")
		if mod != "":
			modifiers.append(mod)

	if modifiers.is_empty():
		return base_desc

	# Build description with modifiers
	# Example: "A sturdy iron knife suitable for crafting and combat."
	var modifier_text = ", ".join(modifiers)

	# Try to insert modifier naturally
	if base_desc.begins_with("A ") or base_desc.begins_with("An "):
		# Insert after article
		var article_end = 2 if base_desc.begins_with("A ") else 3
		return base_desc.substr(0, article_end) + modifier_text + " " + base_desc.substr(article_end)

	return modifier_text.capitalize() + ". " + base_desc


## Parse a composite item ID into template + variants
## Returns {"template_id": String, "variants": Dictionary}
static func parse_item_id(item_id: String) -> Dictionary:
	var result = {"template_id": "", "variants": {}}

	var parts = item_id.split("_")
	if parts.is_empty():
		return result

	# Try to find which part is the template
	# Work backwards since template is always last
	for i in range(parts.size() - 1, -1, -1):
		var potential_template = "_".join(parts.slice(i))
		if VariantManager.has_template(potential_template):
			result["template_id"] = potential_template

			# Everything before is variants
			var variant_parts = parts.slice(0, i)
			result["variants"] = _identify_variants(variant_parts)
			break

	return result


## Identify which variant type each part belongs to
static func _identify_variants(parts: Array) -> Dictionary:
	var variants = {}

	for part in parts:
		# Check each variant type for a match
		for variant_type in VariantManager.get_all_variant_types():
			if VariantManager.has_variant(variant_type, part):
				variants[variant_type] = part
				break

	return variants
