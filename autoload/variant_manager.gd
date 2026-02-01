extends Node

## VariantManager - Autoload singleton for item template and variant management
##
## Loads item templates and variant definitions from JSON files.
## Templates define base item properties, variants define modifiers that
## can be applied to create item variations (e.g., "Iron Knife", "Steel Sword").

# Template data cache (template_id -> data dictionary)
var _templates: Dictionary = {}

# Variant data cache (variant_type -> {variant_name -> data})
var _variants: Dictionary = {}

# Base paths for data
const TEMPLATE_PATH: String = "res://data/item_templates"
const VARIANT_PATH: String = "res://data/variants"

func _ready() -> void:
	_load_templates()
	_load_variants()
	print("VariantManager: Loaded %d templates, %d variant types" % [_templates.size(), _variants.size()])


## Load all templates by recursively scanning folders
func _load_templates() -> void:
	var files = JsonHelper.load_all_from_directory(TEMPLATE_PATH)
	for file_entry in files:
		_process_template_data(file_entry.path, file_entry.data)


## Process loaded template data
func _process_template_data(path: String, data) -> void:
	if data is Dictionary and "template_id" in data:
		var template_id = data.get("template_id", "")
		if template_id != "":
			_templates[template_id] = data
		else:
			push_warning("VariantManager: Template without ID in %s" % path)
	else:
		push_warning("VariantManager: Invalid template file format in %s" % path)


## Load all variant definitions
func _load_variants() -> void:
	var files = JsonHelper.load_all_from_directory(VARIANT_PATH, false)
	for file_entry in files:
		_process_variant_data(file_entry.path, file_entry.data)


## Process loaded variant data
func _process_variant_data(path: String, data) -> void:
	if data is Dictionary and "variant_type" in data and "variants" in data:
		var variant_type = data.get("variant_type", "")
		if variant_type != "":
			_variants[variant_type] = data.get("variants", {})
		else:
			push_warning("VariantManager: Variant file without type in %s" % path)
	else:
		push_warning("VariantManager: Invalid variant file format in %s" % path)


## Get a template by ID
func get_template(template_id: String) -> Dictionary:
	return _templates.get(template_id, {})


## Check if template exists
func has_template(template_id: String) -> bool:
	return template_id in _templates


## Get a specific variant
func get_variant(variant_type: String, variant_name: String) -> Dictionary:
	if variant_type in _variants:
		return _variants[variant_type].get(variant_name, {})
	return {}


## Check if a variant exists
func has_variant(variant_type: String, variant_name: String) -> bool:
	if variant_type in _variants:
		return variant_name in _variants[variant_type]
	return false


## Get all variants of a type
func get_variants_of_type(variant_type: String) -> Dictionary:
	return _variants.get(variant_type, {})


## Get all variant type names
func get_all_variant_types() -> Array[String]:
	var result: Array[String] = []
	for variant_type in _variants:
		result.append(variant_type)
	return result


## Get variants by tier range
func get_variants_by_tier(variant_type: String, min_tier: int, max_tier: int) -> Array[String]:
	var result: Array[String] = []
	if variant_type in _variants:
		for variant_name in _variants[variant_type]:
			var tier = _variants[variant_type][variant_name].get("tier", 1)
			if tier >= min_tier and tier <= max_tier:
				result.append(variant_name)
	return result


## Get all template IDs
func get_all_template_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _templates:
		result.append(id)
	return result


## Get templates by category
func get_templates_by_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for template_id in _templates:
		if _templates[template_id].get("category", "") == category:
			result.append(template_id)
	return result


## Get all possible item IDs that can be created from templates
## For templates with required_variants, generates all variant combinations
## Returns array of dictionaries with {id, display_name, template_id, variants}
func get_all_templated_item_ids() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for template_id in _templates:
		var template = _templates[template_id]
		var required_variants = template.get("required_variants", [])
		var default_variants = template.get("default_variants", {})

		if required_variants.is_empty():
			# No required variants - just use the template as-is with defaults
			var item_id = template_id
			var display_name = template.get("display_name", template_id)
			result.append({
				"id": item_id,
				"display_name": display_name,
				"template_id": template_id,
				"variants": default_variants
			})
		else:
			# Generate all combinations for required variants
			# For now, handle single required variant (most common case)
			if required_variants.size() == 1:
				var variant_type = required_variants[0]
				var variants = get_variants_of_type(variant_type)
				for variant_name in variants:
					var variant_data = variants[variant_name]
					var item_id = variant_name + "_" + template_id
					# Build display name from variant
					var name_prefix = variant_data.get("name_prefix", "")
					var name_override = variant_data.get("name_override", "")
					var display_name: String
					if name_override != "":
						display_name = name_override
					elif name_prefix != "":
						display_name = name_prefix + " " + template.get("display_name", template_id)
					else:
						display_name = variant_name.capitalize() + " " + template.get("display_name", template_id)
					result.append({
						"id": item_id,
						"display_name": display_name,
						"template_id": template_id,
						"variants": {variant_type: variant_name}
					})
			else:
				# Multiple required variants - generate first variant only for now
				# This is a simplification; full cartesian product would be complex
				var variant_type = required_variants[0]
				var variants = get_variants_of_type(variant_type)
				for variant_name in variants:
					var variant_data = variants[variant_name]
					var item_id = variant_name + "_" + template_id
					var name_prefix = variant_data.get("name_prefix", "")
					var name_override = variant_data.get("name_override", "")
					var display_name: String
					if name_override != "":
						display_name = name_override
					elif name_prefix != "":
						display_name = name_prefix + " " + template.get("display_name", template_id)
					else:
						display_name = variant_name.capitalize() + " " + template.get("display_name", template_id)
					result.append({
						"id": item_id,
						"display_name": display_name,
						"template_id": template_id,
						"variants": {variant_type: variant_name}
					})

	return result


## Debug: Print all loaded templates and variants
func debug_print_all() -> void:
	print("=== Loaded Templates ===")
	for template_id in _templates:
		var data = _templates[template_id]
		print("  %s: %s (%s)" % [template_id, data.get("display_name", "?"), data.get("category", "?")])

	print("=== Loaded Variants ===")
	for variant_type in _variants:
		var variants = _variants[variant_type]
		print("  %s: %s" % [variant_type, ", ".join(variants.keys())])
	print("========================")
