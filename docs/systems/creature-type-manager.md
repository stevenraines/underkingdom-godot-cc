# Creature Type Manager

**Location**: `autoload/creature_type_manager.gd`
**Autoload Name**: CreatureTypeManager

## Overview

The CreatureTypeManager handles creature type definitions and type-level damage resistances. It provides a data-driven system for configuring creature type properties without hardcoding values in game systems.

## Features

- Loads creature type definitions from JSON files
- Provides type-level and subtype-level resistances
- Supports special rules (immune_to_poison, heals_from_necrotic, etc.)
- Merges resistances with proper precedence

## Resistance Precedence

When calculating elemental resistances, values are merged in this order (highest priority wins):

1. **Per-creature** - `elemental_resistances` in individual enemy JSON
2. **Subtype-level** - Subtype resistances (e.g., fire elemental fire immunity)
3. **Type-level** - Base resistances from creature type definition

## API Reference

### Loading

```gdscript
# Automatically loads all JSON from data/creature_types/ on _ready()
```

### Type Lookup

```gdscript
# Get full type definition
var type_def = CreatureTypeManager.get_creature_type("undead")

# Get all type IDs
var types = CreatureTypeManager.get_all_creature_type_ids()
```

### Display Names

```gdscript
# Get display name for type
var name = CreatureTypeManager.get_type_display_name("undead")  # "Undead"

# Get display name for subtype
var name = CreatureTypeManager.get_subtype_display_name("elemental", "fire")  # "Fire Elemental"

# Get 3-character abbreviation
var abbrev = CreatureTypeManager.get_type_abbreviation("undead")  # "UND"
```

### Resistances

```gdscript
# Get merged resistances for a creature
var resistances = CreatureTypeManager.get_merged_resistances(
    creature_type,      # e.g., "elemental"
    element_subtype,    # e.g., "fire" (optional)
    creature_resistances # per-creature overrides (optional)
)
# Returns: {"fire": -100, "ice": 100, "poison": -100}
```

### Special Rules

```gdscript
# Check if type has a special rule
if CreatureTypeManager.has_special_rule("undead", "heals_from_necrotic"):
    # Heal instead of damage

# Get numeric rule value
var bonus = CreatureTypeManager.get_special_rule_value("undead", "radiant_vulnerability_bonus", 50)
```

### Appearance

```gdscript
# Get type color for UI
var color = CreatureTypeManager.get_type_color("undead")  # "#708090"

# Get description
var desc = CreatureTypeManager.get_type_description("undead")
```

## Creature Types

| Type | Abbreviation | Key Resistances | Special Rules |
|------|--------------|-----------------|---------------|
| humanoid | HUM | None | - |
| undead | UND | poison: -100, necrotic: -100 | heals_from_necrotic, vulnerable_to_radiant, immune_to_poison |
| construct | CON | poison: -100, necrotic: -50 | immune_to_poison, immune_to_mind_control |
| elemental | ELE | poison: -100 | immune_to_poison, immune_to_mind_control |
| demon | DEM | fire: -50, radiant: 50, necrotic: -25 | resistant_to_fire |
| ooze | OOZ | slashing: -50, piercing: -50, acid: -100 | immune_to_mind_control |
| beast | BST | None | susceptible_to_animal_handling |
| aberration | ABR | None | immune_to_mind_control |
| monstrosity | MON | None | - |

## Elemental Subtypes

| Subtype | Resistances |
|---------|-------------|
| fire | fire: -100, ice: 100 |
| ice | ice: -100, fire: 100 |
| earth | piercing: -50, bludgeoning: -25 |
| air | lightning: -25 |

## Integration with ElementalSystem

The `ElementalSystem.calculate_elemental_damage()` function uses CreatureTypeManager to:

1. Get merged resistances for the target
2. Check special rules for type-specific behaviors
3. Apply type-level bonuses (e.g., radiant vs undead)

```gdscript
# In ElementalSystem.calculate_elemental_damage():
var merged = CreatureTypeManager.get_merged_resistances(creature_type, element_subtype, creature_resistances)

if CreatureTypeManager.has_special_rule(creature_type, "heals_from_necrotic"):
    # Heal instead of damage
```

## Related Documentation

- [Enemies Data](../data/enemies.md) - Enemy JSON format with creature_type
- [Elemental System](./elemental-system.md) - Damage calculation
- [Combat System](./combat-system.md) - Damage application
