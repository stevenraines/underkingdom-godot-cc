# Magic System

The magic system provides spellcasting and ritual mechanics for the player.

## Overview

The magic system consists of two main components:
- **Spells** - Instant-cast abilities that consume mana
- **Rituals** - Multi-turn channeled abilities that consume components

## Implementation Status

- **Phase 01** (Mana System) - Implemented
- **Phase 02** (Spell Data & Manager) - Implemented
- **Phase 03** (Spellbook & Spell Learning) - Implemented
- **Phase 04** (Spell Casting) - Implemented
- **Phase 05** (Ranged Spell Targeting) - Implemented
- **Phase 06** (Damage Spells) - Implemented
- **Phase 07** (Active Effects/Buffs/Debuffs) - Implemented
- **Phase 08** (Saving Throws) - Implemented
- **Phase 09** (Scrolls) - Implemented
- **Phase 10** (Scroll Transcription) - Implemented
- **Phase 11** (Wands & Staves) - Implemented
- **Phase 12** (Rings & Amulets) - Implemented
- **Phase 13** (Identification System) - Implemented
- **Phase 14** (DoT & Concentration) - Implemented
- **Phase 15** (Summoning System) - Implemented
- **Phase 16** (AOE & Terrain Spells) - Implemented
- **Phase 17** (Mind Spells) - Implemented
- **Phase 18** (Town Mage NPC) - Implemented

Remaining phases (Rituals) are planned.

## Mana System (Implemented)

The mana system is fully integrated with the SurvivalSystem.

### Mana Pool Formula
```
Max Mana = Base (30) + (INT - 10) × 5 + (Level - 1) × 5
```

### Mana Regeneration
- **Base Rate**: 1 mana per turn
- **Shelter Bonus**: 3× regeneration when in shelter
- Regeneration occurs automatically each turn via TurnManager

### Key Constants
```gdscript
MANA_REGEN_PER_TURN = 1.0
MANA_REGEN_SHELTER_MULTIPLIER = 3.0
MANA_PER_LEVEL = 5.0
MANA_PER_INT = 5.0
BASE_MAX_MANA = 30.0
```

### Integration Points
- **HUD**: Displays current/max mana alongside stamina
- **Rest Menu**: "Until mana restored" option (key 5)
- **Save/Load**: Mana persists between sessions
- **Signals**: `mana_changed`, `mana_depleted` via EventBus

### Related Methods (SurvivalSystem)
- `get_max_mana()` - Calculate max mana from INT and level
- `consume_mana(amount)` - Deduct mana for spell casting
- `regenerate_mana(multiplier)` - Called each turn
- `restore_mana(amount)` - Instant mana restoration

For detailed mana documentation, see [Survival System - Mana](./survival-system.md#mana-system).

## Spell Data & Manager (Implemented)

SpellManager autoload loads spell definitions from JSON files.

### Data Location
```
data/spells/
├── evocation/      # Damage and energy spells
├── conjuration/    # Creation, summoning, healing
├── enchantment/    # Mind control
├── transmutation/  # Transformation
├── divination/     # Detection, knowledge
├── necromancy/     # Death, undead
├── abjuration/     # Protection, warding
└── illusion/       # Deception
```

### SpellManager Methods

```gdscript
# Get spell by ID
SpellManager.get_spell("spark") -> Spell

# Query spells
SpellManager.get_spells_by_school("evocation") -> Array[Spell]
SpellManager.get_spells_by_level(1) -> Array[Spell]
SpellManager.get_cantrips() -> Array[Spell]
SpellManager.get_all_spell_ids() -> Array[String]

# Check casting requirements
SpellManager.can_cast(caster, spell) -> {can_cast: bool, reason: String}

# Calculate scaled values
SpellManager.calculate_spell_damage(spell, caster) -> int
SpellManager.calculate_spell_duration(spell, caster) -> int
```

### Spell Properties

| Property | Type | Description |
|----------|------|-------------|
| id | String | Unique identifier |
| name | String | Display name |
| school | String | Magic school |
| level | int | 0-10 (0 = cantrip) |
| mana_cost | int | Mana required |
| requirements | Dict | {character_level, intelligence} |
| targeting | Dict | {mode, range, requires_los} |
| effects | Dict | Spell effects (damage, buff, heal, debuff) |
| save | Dict | Saving throw info {type, on_success} |

### Current Spells

| Spell | School | Level | Cost | Effect |
|-------|--------|-------|------|--------|
| light | evocation | 0 | 0 | +2 vision for 100 turns |
| spark | evocation | 1 | 5 | 8 lightning damage |
| flame_bolt | evocation | 2 | 8 | 12 fire damage |
| ice_shard | evocation | 3 | 12 | 15 cold damage |
| lightning_bolt | evocation | 5 | 25 | 30 lightning damage |
| heal | conjuration | 1 | 8 | Restore 10 HP |
| drain_life | necromancy | 2 | 10 | 10 damage, heal 50% |
| shield | abjuration | 1 | 5 | +3 armor for 20 turns |
| stone_skin | transmutation | 3 | 12 | +5 armor for 30 turns |
| weakness | necromancy | 3 | 12 | -3 STR for 20 turns |
| curse | necromancy | 4 | 18 | Multiple stat penalties |

For spell JSON format, see [Spell Data Format](../data/spells.md).

## Spellbook & Spell Learning (Implemented)

Players must possess a spellbook item to learn and access spells.

### Spellbook Item

A spellbook is a book item with the `spellbook` flag:
```json
{
  "id": "spellbook",
  "category": "book",
  "flags": {"readable": true, "magical": true, "spellbook": true}
}
```

### Player Known Spells

- `known_spells: Array[String]` - List of learned spell IDs
- Persisted in save/load
- Accessed via `player.get_known_spells()` which returns full Spell objects

### Learning Spells

Spells are learned from **Spell Tomes** - book items with `teaches_spell` property:

```json
{
  "id": "tome_of_spark",
  "name": "Tome of Spark",
  "category": "book",
  "subtype": "spell_tome",
  "teaches_spell": "spark"
}
```

**Learning Requirements:**
- Player must have a spellbook in inventory
- Player must meet spell's INT requirement
- Player must meet spell's level requirement
- Player must not already know the spell
- Spell tome is consumed on successful learning

### Player Methods

```gdscript
player.has_spellbook() -> bool       # Check for spellbook item
player.knows_spell(spell_id) -> bool # Check if spell is known
player.learn_spell(spell_id) -> bool # Learn a new spell
player.get_known_spells() -> Array   # Get all known Spell objects
```

### EventBus Signals

```gdscript
signal spell_learned(spell_id: String)
signal spell_cast(caster, spell, targets: Array, result: Dictionary)
```

### Spell List UI

Open with **Shift+M** to view known spells:
- Shows all learned spells with name, school, level, mana cost
- Detail panel shows requirements and whether player can cast
- School colors: Evocation (orange), Conjuration (purple), etc.

## Spell Casting (Implemented)

The SpellCastingSystem handles all spell casting mechanics.

### Casting a Spell

1. Open spellbook with **Shift+M** or **K**
2. Select a spell from the list
3. Press **Enter** or **C** to cast
4. For ranged spells, use targeting system to select target
5. Mana is consumed and effects are applied

### Targeting Modes

| Mode | Behavior |
|------|----------|
| self | Casts immediately on caster |
| ranged | Opens targeting system, select enemy |
| touch | Like ranged but 1-tile range |

### Spell Failure

Spells can fail based on level difference:

| Condition | Base Failure Chance |
|-----------|---------------------|
| Spell level > caster level | 25% + 15% per level above |
| Spell level = caster level | 5% |
| Spell level = caster level - 1 | 3% |
| Spell level = caster level - 2 | 2% |
| Spell level < caster level - 2 | 1% |

**INT bonus** reduces failure chance: -1% per INT point above spell requirement.

**Staff bonus** reduces failure chance: success_modifier % (e.g., 10% for Staff of Fire).

**Cantrips** (level 0) never fail.

### Failure Types

| Type | Chance | Effect |
|------|--------|--------|
| Fizzle | 70% | Spell dissipates harmlessly |
| Backfire | 25% | Spell damages caster |
| Wild Magic | 5% | Random magical effect |

### SpellCastingSystem Methods

```gdscript
# Cast a spell (static function)
SpellCastingSystem.cast_spell(caster, spell, target) -> Dictionary

# Result dictionary contains:
{
    "success": bool,
    "damage": int,
    "healing": int,
    "mana_cost": int,
    "message": String,
    "effects_applied": Array,
    "target_died": bool,
    "failed": bool,
    "failure_type": String,  # "fizzle", "backfire", "wild_magic"
    "save_attempted": bool,
    "save_succeeded": bool,
    "save_dc": int
}

# Get valid targets for a spell
SpellCastingSystem.get_valid_spell_targets(caster, spell) -> Array[Entity]

# Check if caster can cast any spell
SpellCastingSystem.can_cast_any_spell(caster) -> bool

# Calculate saving throw DC
SpellCastingSystem.calculate_save_dc(caster, spell) -> int

# Attempt a saving throw
SpellCastingSystem.attempt_saving_throw(target, save_type, dc) -> Dictionary
```

## Saving Throws (Implemented)

Targets can resist spells with saving throws.

### Save Types

| Save Type | Resists | Attribute |
|-----------|---------|-----------|
| INT | Mind control, illusions | Intelligence |
| WIS | Fear, charm, detection | Wisdom |
| DEX | Area effects, aimed spells | Dexterity |
| CON | Poison, drain, death effects | Constitution |
| STR | Forced movement, grappling | Strength |

### Save DC Formula
```
DC = 10 + Spell Level + (Caster INT - 10) / 2
```

### Save Roll
```
Roll = d20 + (Target Attribute - 10) / 2
Success if Roll >= DC
```

### On Successful Save

| Effect Type | on_success | Result |
|-------------|------------|--------|
| Damage | "half_damage" | 50% damage |
| Debuff | "half_duration" | 50% duration |
| Control | "no_effect" | Complete immunity |

## Active Effects (Buffs/Debuffs) (Implemented)

Spells can apply temporary effects to entities.

### Effect Properties

```gdscript
{
    "id": "shield_buff",
    "type": "buff",  # or "debuff"
    "source_spell": "shield",
    "remaining_duration": 20,
    "modifiers": {"STR": 0, "DEX": 0, ...},
    "armor_bonus": 3
}
```

### Entity Methods

```gdscript
entity.add_magical_effect(effect: Dictionary)
entity.remove_magical_effect(effect_id: String)
entity.process_effect_durations()  # Called each turn
entity.get_effective_attribute(attr_name) -> int  # Includes modifiers
entity.get_effective_armor() -> int  # Includes armor_modifier
```

### EventBus Signals

```gdscript
signal effect_applied(entity, effect: Dictionary)
signal effect_removed(entity, effect: Dictionary)
signal effect_expired(entity, effect_name: String)
```

## Scrolls (Implemented)

Scrolls allow casting spells without knowing them.

### Scroll Properties

```json
{
  "id": "scroll_spark",
  "name": "Scroll of Spark",
  "category": "consumable",
  "subtype": "scroll",
  "flags": {"consumable": true, "magical": true, "scroll": true},
  "casts_spell": "spark"
}
```

### Using Scrolls

- Requires minimum 8 INT
- No mana cost
- No spell level/INT requirements (scroll handles it)
- Scroll is consumed on use
- Uses same targeting system as regular casting

### Scroll Transcription (Implemented)

Players can attempt to transcribe a scroll into their spellbook instead of casting.

```gdscript
player.attempt_transcription(scroll) -> Dictionary
player.calculate_transcription_chance(spell) -> float
```

### Transcription Success Chance

| Player Level vs Spell Level | Base Success |
|-----------------------------|--------------|
| Player level = Spell level | 50% |
| Player level = Spell level + 1 | 65% |
| Player level = Spell level + 2 | 75% |
| Player level = Spell level + 3 | 85% |
| Player level >= Spell level + 4 | 95% |

**INT Bonus**: +2% per INT point above spell's minimum requirement.

**On Failure**: Scroll is destroyed, no spell learned.

### Current Scrolls

| Scroll | Casts | Value |
|--------|-------|-------|
| Scroll of Spark | spark | 25 |
| Scroll of Shield | shield | 30 |
| Scroll of Flame Bolt | flame_bolt | 50 |
| Scroll of Heal | heal | 40 |
| Scroll of Lightning Bolt | lightning_bolt | 150 |

## Wands (Implemented)

Wands are charged items that cast spells without mana cost.

### Wand Properties

```json
{
  "id": "wand_of_spark",
  "name": "Wand of Spark",
  "category": "weapon",
  "subtype": "wand",
  "flags": {"equippable": true, "magical": true, "charged": true},
  "casts_spell": "spark",
  "charges": 15,
  "max_charges": 15,
  "recharge_cost": 30
}
```

### Using Wands

- Requires minimum 8 INT
- No mana cost (uses charges instead)
- Charge is consumed on successful cast
- Can be recharged at mage NPC (future feature)
- Equips to main_hand slot

### Item Methods

```gdscript
item.is_wand() -> bool
item._use_wand(user) -> Dictionary
item._cast_wand_spell(caster, spell, target) -> Dictionary
```

### Current Wands

| Wand | Casts | Charges | Value |
|------|-------|---------|-------|
| Wand of Spark | spark | 15 | 75 |
| Wand of Flame Bolt | flame_bolt | 12 | 125 |
| Wand of Ice Shard | ice_shard | 10 | 150 |
| Wand of Healing | heal | 8 | 200 |
| Wand of Lightning | lightning_bolt | 6 | 350 |

## Staves (Casting Focus) (Implemented)

Staves provide casting bonuses while equipped.

### Staff Properties

```json
{
  "id": "staff_of_fire",
  "name": "Staff of Fire",
  "category": "weapon",
  "subtype": "staff",
  "flags": {"equippable": true, "magical": true, "two_handed": true, "casting_focus": true},
  "damage_bonus": 5,
  "casting_bonuses": {
    "success_modifier": 10,
    "school_affinity": "evocation",
    "school_damage_bonus": 2,
    "mana_cost_modifier": -10
  }
}
```

### Casting Bonuses

| Bonus | Effect |
|-------|--------|
| success_modifier | Reduces spell failure chance (%) |
| school_affinity | School that gets damage bonus |
| school_damage_bonus | Extra damage for affinity school |
| mana_cost_modifier | % change to mana cost (negative = reduction) |

### Player Methods

```gdscript
player.get_casting_bonuses() -> Dictionary
# Returns: {success_modifier, mana_cost_modifier, school_bonuses: {school: bonus}}
```

### Current Staves

| Staff | Success Mod | School Bonus | Value |
|-------|-------------|--------------|-------|
| Staff of Power | +5% | - | 150 |
| Staff of Fire | +10% | Evocation +2 | 350 |
| Staff of Frost | +10% | Evocation +2 | 350 |
| Necromancer's Staff | +10% | Necromancy +3 | 400 |
| Archmage Staff | +15%, -10% mana | - | 1500 |

## Magic Rings & Amulets (Implemented)

Rings and amulets provide passive effects while equipped.

### Equipment Slots

| Slot | Items |
|------|-------|
| accessory_1 | Rings |
| accessory_2 | Rings |
| neck | Amulets |

### Passive Effects

```json
{
  "id": "ring_of_protection",
  "category": "accessory",
  "subtype": "ring",
  "equip_slots": ["accessory"],
  "passive_effects": {
    "armor_bonus": 2,
    "STR": 1,
    "max_mana_bonus": 20,
    "resistances": {"fire": 50}
  }
}
```

### Effect Types

| Effect | Description |
|--------|-------------|
| armor_bonus | Adds to armor value |
| STR/DEX/CON/INT/WIS/CHA | Adds to attribute |
| max_mana_bonus | Adds to max mana |
| max_health_bonus | Adds to max health |
| mana_regen_bonus | Bonus mana per turn |
| health_regen_bonus | Bonus HP per turn |
| resistances | {damage_type: % reduction} |

### Resistance Stacking

Resistances use diminishing returns:
```
Combined = A + (100 - A) × B / 100
# Example: 50% + 50% = 75%, not 100%
```

### Player Methods

```gdscript
player.get_equipment_passive_effects() -> Dictionary
player._recalculate_effect_modifiers()  # Called on equip/unequip
```

### Current Rings

| Ring | Effect | Value |
|------|--------|-------|
| Ring of Protection | +2 armor | 100 |
| Ring of Strength | +1 STR | 150 |
| Ring of Intelligence | +1 INT | 150 |
| Ring of Mana | +20 max mana | 300 |
| Ring of Fire Resistance | 50% fire resist | 200 |

### Current Amulets

| Amulet | Effect | Value |
|--------|--------|-------|
| Amulet of Health | +1 CON, +10 max HP | 250 |
| Amulet of the Mage | +2 INT, +15 max mana | 400 |
| Amulet of Warding | +3 armor, 25% all resist | 300 |

## Keybindings

### Implemented
| Key | Action |
|-----|--------|
| Shift+M | Open spellbook (view known spells) |
| K | Open spell casting (alias for Shift+M) |
| Enter/C | Cast selected spell (in spell list) |
| Tab | Cycle spell targets (in targeting mode) |
| Escape | Cancel spell targeting |

### Planned
| Key | Action |
|-----|--------|
| Shift+T | Open ritual menu (T alone is Talk) |
| Shift+S | Summon commands (if summons active) |

## EventBus Signals

```gdscript
# Spell signals
signal spell_learned(spell_id: String)
signal spell_cast(caster, spell, targets: Array, result: Dictionary)

# Effect signals
signal effect_applied(entity: Entity, effect: Dictionary)
signal effect_removed(entity: Entity, effect: Dictionary)
signal effect_expired(entity: Entity, effect_name: String)

# Scroll signals
signal scroll_targeting_started(scroll, spell)
signal transcription_attempted(scroll, spell, success: bool)

# Wand signals
signal wand_targeting_started(wand, spell)
signal wand_used(wand, spell, charges_remaining: int)
```

## Related Documentation

- [Spell Data Format](../data/spells.md)
- [Ritual Data Format](../data/rituals.md)
- [Items Documentation](../data/items.md)
- [Inventory System](./inventory-system.md)

## Identification System (Implemented)

The identification system tracks which magical items the player has identified.

### IdentificationManager

```gdscript
# Check if item type is identified
IdentificationManager.is_identified(item_id: String) -> bool

# Identify an item type
IdentificationManager.identify_item(item_id: String)

# Get identified items
IdentificationManager.get_identified_items() -> Array[String]

# Item-specific checks
IdentificationManager.needs_identification(item) -> bool
```

### Items That Need Identification

- Potions (until consumed or identified)
- Scrolls (cursed scroll detection)
- Wands (type unknown until used)
- Rings and amulets (effects hidden)

### Identify Spell

The `identify` spell (Divination, Level 1) reveals an item's true nature:
```json
{
  "id": "identify",
  "school": "divination",
  "effects": {"identify": true}
}
```

### EventBus Signals

```gdscript
signal item_identified(item_id: String)
```

## DoT & Concentration System (Implemented)

### Damage over Time (DoT)

DoT effects deal damage each turn for a duration.

#### DoT Effect Structure

```gdscript
{
    "id": "poison_dot",
    "type": "dot",
    "dot_type": "poison",  # or "burning", "bleeding"
    "damage_per_turn": 3,
    "remaining_duration": 10,
    "source": caster
}
```

#### DoT Spells

| Spell | School | DoT Type | Damage | Duration |
|-------|--------|----------|--------|----------|
| poison | necromancy | poison | 3+scaling | 10+scaling |
| ignite | evocation | burning | 4+scaling | 5+scaling |

#### DoT Processing

DoT effects are processed at the start of each turn:
```gdscript
TurnManager._process_dot_effects()
entity.process_dot_effects() -> int  # Returns total damage
```

#### Curing DoT

```gdscript
entity.cure_dot_type("poison") -> int  # Returns count cured
```

The `antidote` consumable cures poison DoT effects.

### Concentration System

Some spells require concentration to maintain.

#### Concentration Mechanics

- Only one concentration spell active at a time
- Starting a new concentration spell ends the previous one
- Taking damage triggers a concentration check

#### Concentration Check

```
Roll = d20 + (CON - 10) / 2
DC = max(10, 10 + damage_taken / 2)
Success if Roll >= DC
```

#### Player Methods

```gdscript
player.start_concentration(spell_id: String)
player.end_concentration()
player.check_concentration(damage_taken: int) -> bool  # true = maintained
player.concentration_spell  # Currently concentrated spell ID
```

#### EventBus Signals

```gdscript
signal concentration_started(caster, spell_id: String)
signal concentration_ended(caster, spell_id: String)
signal dot_damage_tick(entity, dot_type: String, damage: int)
```

## Summoning System (Implemented)

The summoning system allows players to call creatures to fight alongside them.

### SummonedCreature Class

Summoned creatures extend Enemy with special behavior:

```gdscript
class_name SummonedCreature
extends Enemy

var summoner: Entity = null
var remaining_duration: int = -1  # -1 = permanent
var is_summon: bool = true
var faction: String = "player"
var behavior_mode: String = "follow"  # follow, aggressive, defensive, stay
```

### Behavior Modes

| Mode | Behavior |
|------|----------|
| follow | Stay near summoner, attack nearby enemies |
| aggressive | Seek out and attack nearest enemy |
| defensive | Guard summoner, only attack threats |
| stay | Hold position, attack if approached |

### Summon Limits

- Maximum 3 summons active at once (configurable)
- Summoning a 4th creature dismisses the oldest
- Summons last for a duration based on spell + caster level

### Summon Spells

| Spell | School | Creature | Base Duration |
|-------|--------|----------|---------------|
| summon_wolf | conjuration | Summoned Wolf | 50 + 10/level |
| raise_skeleton | necromancy | Skeletal Warrior | 50 + 10/level |

### Summoned Creature Data

Summoned creatures are defined in `data/enemies/summons/`:
```json
{
  "id": "summoned_wolf",
  "name": "Summoned Wolf",
  "creature_type": "animal",
  "base_stats": {"STR": 12, "DEX": 14, "CON": 11},
  "base_health": 20,
  "base_damage": 6
}
```

### Player Methods

```gdscript
player.add_summon(summon) -> bool
player.remove_summon(summon)
player.dismiss_summon(summon)
player.dismiss_all_summons()
player.active_summons  # Array of active summons
player.MAX_SUMMONS = 3
```

### EventBus Signals

```gdscript
signal summon_created(summon, summoner)
signal summon_dismissed(summon)
```

## AOE & Terrain Spells (Implemented)

### Area of Effect (AOE)

AOE spells affect multiple targets in a radius.

#### AOE Properties

```json
{
  "targeting": {
    "mode": "aoe",
    "range": 6,
    "aoe_radius": 2,
    "aoe_shape": "circle"
  }
}
```

#### AOE Shapes

| Shape | Behavior |
|-------|----------|
| circle | Chebyshev distance (square with rounded edges) |
| square | Manhattan distance |

#### Friendly Fire

AOE spells can damage the caster's summons. The caster is protected.

#### AOE Methods

```gdscript
SpellCastingSystem.get_entities_in_aoe(center, radius, shape) -> Array
SpellCastingSystem.apply_aoe_damage(caster, spell, center, result) -> Dictionary
```

#### AOE Spells

| Spell | School | Radius | Damage |
|-------|--------|--------|--------|
| fireball | evocation | 2 | 15+scaling |

### Terrain Modification

Terrain spells change the map permanently.

#### Terrain Change Effects

```json
{
  "effects": {
    "terrain_change": {
      "from_type": "floor",  # "floor", "wall", "any"
      "to_type": "water",    # "water", "wall", "mud", "floor"
      "permanent": true
    }
  }
}
```

#### Terrain Rules

- Cannot create walls on occupied tiles
- Some terrain changes are restricted by source type
- Mana is refunded if terrain change fails

#### Terrain Spells

| Spell | School | From | To | Level |
|-------|--------|------|-----|-------|
| create_water | conjuration | floor | water | 2 |
| create_wall | transmutation | floor | wall | 5 |
| wall_to_mud | transmutation | wall | mud | 4 |

#### EventBus Signals

```gdscript
signal terrain_changed(position: Vector2i, new_type: String)
signal aoe_cursor_moved(position: Vector2i)
```

## Mind Spells (Implemented)

Mind spells affect enemy behavior through enchantment.

### Mind Control Immunity

Some creatures are immune to mind control:

```gdscript
entity.can_be_mind_controlled() -> bool
# Returns false if:
# - creature_type == "construct"
# - INT < 3
```

### Mind Save Modifiers

| Creature Type | Save Modifier |
|---------------|---------------|
| humanoid | +0 |
| undead | +5 (resistant) |
| animal | -2 (vulnerable) |
| construct | Immune |

### Mind Effect Types

| Effect | Faction Change | AI State | Description |
|--------|---------------|----------|-------------|
| charm | player | normal | Target fights for caster |
| fear | unchanged | fleeing | Target flees from caster |
| calm | neutral | idle | Target becomes non-hostile |
| enrage | hostile_to_all | berserk | Target attacks everything |

### Mind Effect Expiration

When mind effects expire, the original faction and AI state are restored:

```gdscript
entity._handle_mind_effect_expiration(effect: Dictionary)
```

### Mind Spells

| Spell | School | Effect | Level | Concentration |
|-------|--------|--------|-------|---------------|
| charm | enchantment | charm | 2 | Yes |
| fear | enchantment | fear | 1 | No |
| calm | enchantment | calm | 2 | No |
| enrage | enchantment | enrage | 3 | No |

### Entity Properties

```gdscript
entity.creature_type  # "humanoid", "animal", "undead", "construct"
entity.faction        # "player", "enemy", "neutral", "hostile_to_all"
entity.ai_state       # "normal", "fleeing", "berserk", "idle"
```

## Town Mage NPC (Implemented)

The town mage sells magical items and supplies.

### Location

The mage is located in the Mage Tower in Thornhaven (starter town).

### NPC Data

```json
{
  "id": "mage",
  "name": "Aldric the Sage",
  "npc_type": "shop",
  "gold": 800,
  "restock_interval": 750
}
```

### Trade Inventory

| Item | Stock | Base Price |
|------|-------|------------|
| Spellbook | 1 | 150 |
| Mana Potion | 5 | 35 |
| Scroll of Spark | 3 | 15 |
| Scroll of Heal | 2 | 45 |
| Scroll of Shield | 2 | 40 |
| Scroll of Flame Bolt | 2 | 55 |
| Scroll of Identify | 3 | 30 |
| Scroll of Lightning Bolt | 1 | 120 |
| Herb | 15 | 3 |
| Glowing Mushroom | 5 | 8 |
| Bone | 10 | 2 |
| Antidote | 3 | 25 |

### Mage Tower Building

Located at offset (-6, 4) in Thornhaven:
```
 ###
 #.#
##.##
#...#
#.@.#
#...#
##+##
```

## Implementation Phases

The magic system is implemented across 18 phases. Phases 01-18 are complete.
See `plans/features/magic-system-spec.md` for the full specification.
