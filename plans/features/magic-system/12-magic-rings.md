# Phase 12: Magic Rings & Amulets

## Overview
Implement magic rings and amulets that provide permanent passive effects while equipped.
- Rings: 2 slots (accessory_1, accessory_2)
- Amulets: 1 slot (neck)

## Dependencies
- Phase 7: Buff/Debuff Spells (for effect system)
- Existing: Equipment slot system

## Pre-Implementation: Add Neck Slot

**File:** `systems/inventory_system.gd`

Add "neck" to equipment slots:
```gdscript
var equipment: Dictionary = {
    "head": null,
    "neck": null,  # NEW - for amulets
    "torso": null,
    "hands": null,
    "legs": null,
    "feet": null,
    "main_hand": null,
    "off_hand": null,
    "accessory_1": null,
    "accessory_2": null
}
```

## Implementation Steps

### 12.1 Add Ring Passive Effects to Item
**File:** `items/item.gd`

```gdscript
var passive_effects: Dictionary = {}
# Example: {max_mana_bonus: 20, STR: 1, fire_resistance: 0.5}
```

### 12.2 Apply Ring Effects on Equip
**File:** `systems/inventory_system.gd`

```gdscript
func equip_item(item: Item, target_slot: String = "") -> Array[Item]:
    # ... existing equip logic ...

    # Apply passive effects
    if item.passive_effects.size() > 0:
        _apply_passive_effects(item)

    return unequipped

func unequip_item(slot: String) -> Item:
    var item = equipment.get(slot)
    if item and item.passive_effects.size() > 0:
        _remove_passive_effects(item)

    # ... existing unequip logic ...

func _apply_passive_effects(item: Item) -> void:
    for effect_key in item.passive_effects:
        var value = item.passive_effects[effect_key]
        match effect_key:
            "max_mana_bonus":
                _owner.survival.max_mana_bonus += value
            "max_health_bonus":
                _owner.max_health_bonus += value
            "STR", "DEX", "CON", "INT", "WIS", "CHA":
                _owner.equipment_stat_modifiers[effect_key] += value
            # Resistances handled in Phase 22

func _remove_passive_effects(item: Item) -> void:
    # Reverse of _apply_passive_effects
```

### 12.3 Add Equipment Stat Modifiers to Entity
**File:** `entities/entity.gd`

```gdscript
var equipment_stat_modifiers: Dictionary = {
    "STR": 0, "DEX": 0, "CON": 0, "INT": 0, "WIS": 0, "CHA": 0
}

func get_effective_attribute(attr_name: String) -> int:
    var base_value = attributes.get(attr_name, 10)
    var modifier = stat_modifiers.get(attr_name, 0)
    var equip_modifier = equipment_stat_modifiers.get(attr_name, 0)
    return max(1, base_value + modifier + equip_modifier)
```

### 12.4 Add Max Mana Bonus to SurvivalSystem
**File:** `systems/survival_system.gd`

```gdscript
var max_mana_bonus: int = 0

func get_max_mana() -> float:
    var int_bonus = (owner.get_effective_attribute("INT") - 10) * 5
    return base_max_mana + int_bonus + level_bonus + max_mana_bonus
```

### 12.5 Implement Ring Stacking Rules
**File:** `systems/inventory_system.gd`

```gdscript
func get_total_passive_effect(effect_key: String) -> float:
    var total: float = 0.0

    for slot in ["accessory_1", "accessory_2"]:
        var item = equipment.get(slot)
        if item and effect_key in item.passive_effects:
            var value = item.passive_effects[effect_key]

            # Resistances use diminishing returns
            if effect_key.ends_with("_resistance"):
                # 50% + 50% = 75%, not 100%
                total = total + (1.0 - total) * value
            else:
                # Other effects stack fully
                total += value

    return total
```

### 12.6 Create Ring JSON Files
**Directory:** `data/items/accessories/rings/`

**ring_of_protection.json:**
```json
{
  "id": "ring_of_protection",
  "name": "Ring of Protection",
  "description": "A silver ring etched with protective runes.",
  "category": "accessory",
  "subtype": "ring",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["accessory"],
  "weight": 0.1,
  "value": 100,
  "ascii_char": "=",
  "ascii_color": "#C0C0C0",
  "passive_effects": {
    "armor_bonus": 2
  }
}
```

**ring_of_strength.json:**
```json
{
  "id": "ring_of_strength",
  "name": "Ring of Strength",
  "description": "A gold ring that pulses with physical power.",
  "category": "accessory",
  "subtype": "ring",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["accessory"],
  "weight": 0.1,
  "value": 150,
  "ascii_char": "=",
  "ascii_color": "#FFD700",
  "passive_effects": {
    "STR": 1
  }
}
```

**ring_of_mana.json:**
```json
{
  "id": "ring_of_mana",
  "name": "Ring of Mana",
  "description": "A sapphire ring that enhances magical reserves.",
  "category": "accessory",
  "subtype": "ring",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["accessory"],
  "weight": 0.1,
  "value": 300,
  "ascii_char": "=",
  "ascii_color": "#4444FF",
  "passive_effects": {
    "max_mana_bonus": 20
  }
}
```

**ring_of_fire_resistance.json:**
```json
{
  "id": "ring_of_fire_resistance",
  "name": "Ring of Fire Resistance",
  "description": "A ruby ring cool to the touch despite its fiery appearance.",
  "category": "accessory",
  "subtype": "ring",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["accessory"],
  "weight": 0.1,
  "value": 200,
  "ascii_char": "=",
  "ascii_color": "#FF4400",
  "passive_effects": {
    "fire_resistance": 0.5
  }
}
```

**ring_of_regeneration.json:**
```json
{
  "id": "ring_of_regeneration",
  "name": "Ring of Regeneration",
  "description": "A jade ring that slowly mends wounds.",
  "category": "accessory",
  "subtype": "ring",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["accessory"],
  "weight": 0.1,
  "value": 350,
  "ascii_char": "=",
  "ascii_color": "#00FF00",
  "passive_effects": {
    "hp_regen_per_10_turns": 1
  }
}
```

**ring_of_the_archmage.json:**
```json
{
  "id": "ring_of_the_archmage",
  "name": "Ring of the Archmage",
  "description": "A legendary ring of immense magical power.",
  "category": "accessory",
  "subtype": "ring",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["accessory"],
  "weight": 0.1,
  "value": 1000,
  "ascii_char": "=",
  "ascii_color": "#AA44FF",
  "passive_effects": {
    "INT": 2,
    "max_mana_bonus": 30,
    "spell_failure_modifier": -10
  }
}
```

### 12.7 Create Amulet JSON Files
**Directory:** `data/items/accessories/amulets/`

**amulet_of_health.json:**
```json
{
  "id": "amulet_of_health",
  "name": "Amulet of Health",
  "description": "A ruby pendant that strengthens the body.",
  "category": "accessory",
  "subtype": "amulet",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["neck"],
  "weight": 0.2,
  "value": 250,
  "ascii_char": "\"",
  "ascii_color": "#FF4444",
  "passive_effects": {
    "CON": 2,
    "max_health_bonus": 10
  }
}
```

**amulet_of_mana.json:**
```json
{
  "id": "amulet_of_mana",
  "name": "Amulet of Mana",
  "description": "A sapphire pendant that enhances magical capacity.",
  "category": "accessory",
  "subtype": "amulet",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["neck"],
  "weight": 0.2,
  "value": 300,
  "ascii_char": "\"",
  "ascii_color": "#4444FF",
  "passive_effects": {
    "INT": 1,
    "max_mana_bonus": 25
  }
}
```

**amulet_of_protection.json:**
```json
{
  "id": "amulet_of_protection",
  "name": "Amulet of Protection",
  "description": "A silver pendant inscribed with protective wards.",
  "category": "accessory",
  "subtype": "amulet",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["neck"],
  "weight": 0.2,
  "value": 200,
  "ascii_char": "\"",
  "ascii_color": "#C0C0C0",
  "passive_effects": {
    "armor_bonus": 3,
    "spell_failure_modifier": -5
  }
}
```

**amulet_of_sustenance.json:**
```json
{
  "id": "amulet_of_sustenance",
  "name": "Amulet of Sustenance",
  "description": "An emerald pendant that reduces bodily needs.",
  "category": "accessory",
  "subtype": "amulet",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["neck"],
  "weight": 0.2,
  "value": 400,
  "ascii_char": "\"",
  "ascii_color": "#00FF00",
  "passive_effects": {
    "hunger_drain_modifier": 0.5,
    "thirst_drain_modifier": 0.5
  }
}
```

**amulet_of_the_archmage.json:**
```json
{
  "id": "amulet_of_the_archmage",
  "name": "Amulet of the Archmage",
  "description": "A legendary amulet of supreme magical power.",
  "category": "accessory",
  "subtype": "amulet",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["neck"],
  "weight": 0.2,
  "value": 1500,
  "ascii_char": "\"",
  "ascii_color": "#AA44FF",
  "passive_effects": {
    "INT": 3,
    "max_mana_bonus": 40,
    "mana_regen_per_5_turns": 2,
    "spell_failure_modifier": -15
  }
}
```

### 12.8 Create Magic Armor & Clothing JSON Files
**Directory:** `data/items/armor/`

The same `passive_effects` system works for armor and clothing.

**robes_of_the_mage.json:**
```json
{
  "id": "robes_of_the_mage",
  "name": "Robes of the Mage",
  "description": "Enchanted robes woven with arcane threads.",
  "category": "armor",
  "subtype": "robe",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["torso"],
  "armor_value": 1,
  "weight": 1.5,
  "value": 200,
  "ascii_char": "[",
  "ascii_color": "#4444AA",
  "passive_effects": {
    "max_mana_bonus": 15,
    "spell_failure_modifier": -5
  }
}
```

**archmage_robes.json:**
```json
{
  "id": "archmage_robes",
  "name": "Archmage Robes",
  "description": "Legendary robes of immense magical power.",
  "category": "armor",
  "subtype": "robe",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["torso"],
  "armor_value": 2,
  "weight": 2.0,
  "value": 800,
  "ascii_char": "[",
  "ascii_color": "#AA44FF",
  "passive_effects": {
    "INT": 2,
    "max_mana_bonus": 30,
    "spell_failure_modifier": -10,
    "mana_regen_per_5_turns": 1
  }
}
```

**flaming_plate_armor.json:**
```json
{
  "id": "flaming_plate_armor",
  "name": "Flaming Plate Armor",
  "description": "Plate armor wreathed in magical flames.",
  "category": "armor",
  "subtype": "plate",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["torso"],
  "armor_value": 8,
  "weight": 25.0,
  "value": 600,
  "ascii_char": "[",
  "ascii_color": "#FF6600",
  "passive_effects": {
    "fire_resistance": 0.5,
    "warmth": 15.0
  }
}
```

**boots_of_speed.json:**
```json
{
  "id": "boots_of_speed",
  "name": "Boots of Speed",
  "description": "Enchanted boots that quicken your step.",
  "category": "armor",
  "subtype": "boots",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["feet"],
  "armor_value": 1,
  "weight": 1.0,
  "value": 300,
  "ascii_char": "[",
  "ascii_color": "#FFFF00",
  "passive_effects": {
    "DEX": 1,
    "movement_cost_modifier": -0.25
  }
}
```

**gloves_of_dexterity.json:**
```json
{
  "id": "gloves_of_dexterity",
  "name": "Gloves of Dexterity",
  "description": "Supple gloves that enhance manual precision.",
  "category": "armor",
  "subtype": "gloves",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["hands"],
  "armor_value": 1,
  "weight": 0.3,
  "value": 200,
  "ascii_char": "[",
  "ascii_color": "#AAAAAA",
  "passive_effects": {
    "DEX": 2
  }
}
```

**helm_of_wisdom.json:**
```json
{
  "id": "helm_of_wisdom",
  "name": "Helm of Wisdom",
  "description": "A circlet that sharpens the mind.",
  "category": "armor",
  "subtype": "helm",
  "flags": {"equippable": true, "magical": true},
  "equip_slots": ["head"],
  "armor_value": 2,
  "weight": 1.0,
  "value": 250,
  "ascii_char": "[",
  "ascii_color": "#4488FF",
  "passive_effects": {
    "WIS": 2,
    "perception_bonus": 2
  }
}
```

### 12.9 Implement Regeneration Effect Processing
**File:** `autoload/turn_manager.gd`

```gdscript
func _process_regeneration_effects() -> void:
    var player = EntityManager.player
    if not player:
        return

    var hp_regen = player.inventory.get_total_passive_effect("hp_regen_per_10_turns")
    if hp_regen > 0 and current_turn % 10 == 0:
        player.heal(int(hp_regen))

    var mana_regen = player.inventory.get_total_passive_effect("mana_regen_per_5_turns")
    if mana_regen > 0 and current_turn % 5 == 0:
        player.survival.mana = min(player.survival.get_max_mana(),
            player.survival.mana + mana_regen)
```

### 12.8 Show Ring Effects in Equipment Screen
**IMPORTANT:** Use the `ui-implementation` agent for UI updates.

**File:** `ui/equipment_screen.gd`

Display ring passive effects when hovering/selecting.

## Testing Checklist

- [ ] Ring of Strength adds +1 STR when equipped
- [ ] Ring of Mana adds +20 max mana when equipped
- [ ] Ring of Protection adds +2 armor when equipped
- [ ] Effects removed when ring unequipped
- [ ] Can equip two rings (accessory_1 and accessory_2)
- [ ] Two Ring of Strength = +2 STR (full stacking)
- [ ] Two fire resistance rings = 75% (diminishing returns)
- [ ] Ring of Regeneration heals 1 HP every 10 turns
- [ ] Ring effects persist through save/load
- [ ] Ring effects shown in character sheet
- [ ] Cannot equip more than 2 rings

## Files Modified
- `items/item.gd`
- `entities/entity.gd`
- `systems/inventory_system.gd`
- `systems/survival_system.gd`
- `autoload/turn_manager.gd`

## Files Created
- `data/items/accessories/rings/ring_of_protection.json`
- `data/items/accessories/rings/ring_of_strength.json`
- `data/items/accessories/rings/ring_of_intelligence.json`
- `data/items/accessories/rings/ring_of_wisdom.json`
- `data/items/accessories/rings/ring_of_mana.json`
- `data/items/accessories/rings/ring_of_fire_resistance.json`
- `data/items/accessories/rings/ring_of_ice_resistance.json`
- `data/items/accessories/rings/ring_of_regeneration.json`
- `data/items/accessories/rings/ring_of_mana_regeneration.json`
- `data/items/accessories/rings/ring_of_the_archmage.json`

## Next Phase
Once rings work, proceed to **Phase 13: Identification System**
