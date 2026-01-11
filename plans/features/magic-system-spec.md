# Magic System Feature Specification

## Overview

A D&D-inspired magic system for Underkingdom featuring two distinct casting methods:
- **Spells**: Instant-cast abilities requiring mana, with level and INT requirements
- **Rituals**: Powerful multi-step processes requiring components and channeling time

Magic provides an alternative progression path that eventually trivializes survival mechanics at high levels, rewarding players who invest in magical development.

---

## Core Requirements

### Minimum Intelligence
- **All magic requires minimum 8 INT** to use
- Characters below 8 INT cannot cast spells, use scrolls, or perform rituals

### Mana Pool
- **Base Mana**: 30 + (INT × 5)
- **Mana Growth**: Max mana increases with character level
- **Regeneration**: Mana regenerates per turn (rate TBD, similar to stamina)
- **Spell Cost**: Scales with spell level

### Spell Levels
- Spells range from **Level 1 to Level 10**
- Higher level spells are more powerful but have stricter requirements and higher mana costs

---

## Schools of Magic

All spells and rituals belong to one of eight schools:

| School | Focus | Primary Use |
|--------|-------|-------------|
| **Evocation** | Raw elemental energy | Direct damage (fire, ice, lightning) |
| **Conjuration** | Creation and summoning | Create food/water, summon creatures, light |
| **Enchantment** | Mind influence | Charm, fear, calm, enrage creatures |
| **Transmutation** | Altering matter | Terrain modification, physical enhancement |
| **Divination** | Knowledge and sight | Detection, identification, scrying |
| **Necromancy** | Death and undeath | Life drain, curses, raise undead |
| **Abjuration** | Protection and wards | Shields, dispel magic, sanctuaries |
| **Illusion** | Deception and trickery | Invisibility, decoys, phantom sounds |

---

## Spell System

### Requirements to Cast
Each spell has two requirements:
1. **Character Level**: Minimum level to cast the spell
2. **Intelligence**: Minimum INT score to cast the spell

If a player possesses a spell book for a spell they cannot cast, the contents appear as **"incomprehensible arcane text"** until requirements are met.

### Player Spellbook

Players must possess a **Spellbook** item to store and cast learned spells.

**Spellbook Properties:**
- Physical item that occupies inventory space
- Must be in inventory (not necessarily equipped) to cast learned spells
- Can be lost, stolen, or destroyed (losing access to learned spells until recovered/replaced)
- Different quality spellbooks may have page limits or bonuses (future feature)
- Starting spellbook available from town mage

**Without a Spellbook:**
- Cannot cast learned spells
- Can still use scrolls for one-time casting
- Cannot inscribe new spells

### Learning Spells
Spells can be learned through three methods:
1. **Inscription from Scrolls**: Transcribe a scroll into your spellbook (see below)
2. **Purchase from Mages**: Pay to have a spell inscribed directly into your book
3. **Mage NPCs**: Learn directly from mage characters (may require payment or quests)

Once inscribed in a spellbook, a spell is permanently known and can be cast whenever mana and requirements allow.

### Spell Inscription (Scroll to Spellbook)

Players can attempt to inscribe a spell from a scroll into their spellbook instead of casting it.

**Requirements:**
- Must possess a spellbook
- Must meet the spell's level and INT requirements (cannot inscribe spells you can't cast)
- Scroll is consumed regardless of success or failure

**Inscription Success Chance:**

Base chance modified by the gap between player level and spell level:

| Player Level vs Spell Level | Base Success |
|-----------------------------|--------------|
| Player level = Spell level | 50% |
| Player level = Spell level + 1 | 65% |
| Player level = Spell level + 2 | 75% |
| Player level = Spell level + 3 | 85% |
| Player level ≥ Spell level + 4 | 95% |

**INT Bonus:** +2% per INT point above minimum requirement

**Example:** Level 5 player with 14 INT inscribing a Level 3 spell (requires 10 INT):
- Base: 75% (player is 2 levels above spell)
- INT bonus: +8% (4 points above minimum × 2%)
- Total: 83% success chance

**Failure Result:**
- Scroll is destroyed
- No spell learned
- Message: "The arcane symbols blur and fade as you fail to comprehend them. The scroll crumbles to dust."

### Scrolls (One-Use Casting)
- Scrolls allow casting a spell **without knowing it**
- Still requires minimum 8 INT
- Scroll is consumed on use
- **Alternative use**: Attempt to inscribe into spellbook (see above)
- Found as loot or purchased

### Spell Targeting Modes

| Mode | Description | Targeting Method |
|------|-------------|------------------|
| **Ranged** | Target an entity at distance | Uses ranged combat targeting system (Tab to cycle, Enter to cast) |
| **Self** | Cast on the player | Instant, no targeting required |
| **Tile/Object** | Target terrain or ground objects | Directional or cursor selection |
| **Inventory** | Target an item in inventory | Select from inventory screen |

### Spell Failure

Spells can fail based on the difference between caster level and spell level. Lower-level spells become more reliable as casters advance.

**Failure Consequences** (random selection):
1. **Fizzle**: Mana is spent, but no effect occurs
2. **Backfire**: Spell damages or negatively affects the caster
3. **Wild Magic**: Random effect from the Wild Magic table occurs

---

## Ritual System

Rituals are powerful magical workings that require preparation and time rather than raw mana.

### Ritual Requirements
1. **Knowledge**: Must find and learn the ritual steps (rituals cannot be purchased or taught)
2. **Components**: Specific items consumed when the ritual is performed
3. **Channeling Time**: Multiple turns of uninterrupted concentration

### Ritual Properties
- **No Level Requirement**: Any character who knows a ritual can attempt it
- **Minimum 8 INT**: Still required for all magic
- **Found Only**: Rituals are discovered in rare, hidden locations (ancient texts, hidden chambers, boss loot)
- **Interruptible**: Taking damage or certain actions cancels channeling

### Ritual Failure
If interrupted or failed, rituals have the same three failure consequences as spells:
- Fizzle (components may or may not be lost)
- Backfire (harmful effect on caster)
- Wild Magic (random effect)

### Channeling Time Scale
- **Short**: 3-5 turns
- **Medium**: 10-15 turns
- **Long**: 25-50 turns

---

## Creature Influence Rules

Mind-affecting spells (Enchantment school) work differently based on creature type:

### Intelligence Threshold
- Creatures with **INT below a certain threshold** (TBD, perhaps 3-4) are immune to mind control
- Mindless creatures (golems, undead constructs) cannot be charmed

### Creature Type Modifiers

| Creature Type | Charm Effectiveness | Notes |
|---------------|---------------------|-------|
| **Humanoids** | Normal | Standard INT-based resistance |
| **Animals** | Modified | Different spells may be needed (Animal Friendship vs Charm Person) |
| **Undead** | Reduced/Immune | Most mind magic ineffective; necromancy required |
| **Constructs** | Immune | No mind to influence |

---

## Environment Magic

Transmutation and Conjuration spells can permanently alter the game world:

### Terrain Modifications
- **Create Pool**: Turn floor tiles into water
- **Wall to Mud**: Make walls passable (permanently)
- **Create Wall**: Turn floor into impassable wall
- **Create Fire**: Ignite a tile (provides light and heat)
- **Extinguish**: Remove fire from a tile

All terrain changes are **permanent** and persist through save/load.

---

## Spell List (Phase 1)

### Evocation (5 spells)
| Spell | Level | Targeting | Effect |
|-------|-------|-----------|--------|
| Spark | 1 | Ranged | Minor lightning damage |
| Flame Bolt | 2 | Ranged | Fire damage, may ignite |
| Ice Shard | 3 | Ranged | Cold damage, may slow |
| Lightning Bolt | 5 | Ranged | High lightning damage, hits in a line |
| Fireball | 7 | Ranged/AoE | Fire damage in radius |

### Conjuration (4 spells)
| Spell | Level | Targeting | Effect |
|-------|-------|-----------|--------|
| Conjure Light | 1 | Self/Tile | Create light source |
| Create Water | 2 | Inventory/Tile | Fill container or create pool |
| Create Food | 3 | Inventory | Create edible rations |
| Summon Creature | 5 | Tile | Summon temporary ally |

### Enchantment (4 spells)
| Spell | Level | Targeting | Effect |
|-------|-------|-----------|--------|
| Calm | 2 | Ranged | Make hostile creature neutral |
| Fear | 3 | Ranged | Cause creature to flee |
| Enrage | 4 | Ranged | Make neutral creature hostile (to all) |
| Charm | 6 | Ranged | Make creature temporary ally |

### Transmutation (3 spells)
| Spell | Level | Targeting | Effect |
|-------|-------|-----------|--------|
| Stone Skin | 3 | Self | Increase armor temporarily |
| Wall to Mud | 5 | Tile | Convert wall to passable terrain |
| Create Wall | 6 | Tile | Convert floor to impassable wall |

### Divination (3 spells)
| Spell | Level | Targeting | Effect |
|-------|-------|-----------|--------|
| Detect Traps | 2 | Self/AoE | Reveal nearby traps |
| Identify | 3 | Inventory | Reveal item properties |
| Clairvoyance | 5 | Self | Reveal map in large radius |

### Necromancy (5 spells)
| Spell | Level | Targeting | Effect |
|-------|-------|-----------|--------|
| Poison | 1 | Ranged | Apply poison (3 damage/turn for 10 turns) |
| Drain Life | 2 | Ranged | Damage enemy, heal self |
| Weakness | 3 | Ranged | Reduce target's STR |
| Curse | 4 | Ranged | Multiple stat penalties |
| Raise Skeleton | 6 | Tile (corpse) | Create temporary undead ally |

### Abjuration (3 spells)
| Spell | Level | Targeting | Effect |
|-------|-------|-----------|--------|
| Shield | 1 | Self | Temporary armor boost |
| Dispel Magic | 4 | Ranged/Self | Remove magical effects |
| Sanctuary | 5 | Self | Enemies cannot target caster briefly |

### Illusion (3 spells)
| Spell | Level | Targeting | Effect |
|-------|-------|-----------|--------|
| Phantom Sound | 1 | Tile | Create distracting noise |
| Mirror Image | 3 | Self | Chance for attacks to miss |
| Invisibility | 5 | Self | Become unseen until acting |

**Total: 29 spells**

---

## Ritual List (Phase 1)

| Ritual | School | Rarity | Components | Channel Time | Effect |
|--------|--------|--------|------------|--------------|--------|
| **Enchant Item** | Transmutation | Common | Gems, magical essence, target item | Medium (10-15 turns) | Add magical properties to equipment |
| **Scrying** | Divination | Uncommon | Crystal, water basin, incense | Short (3-5 turns) | Reveal entire dungeon floor |
| **Sanctify Area** | Abjuration | Uncommon | Holy water, silver dust, candles | Medium (10-15 turns) | Create safe zone that repels enemies |
| **Permanent Summon** | Conjuration | Rare | Creature remains, chalk, binding gems | Long (25-50 turns) | Bind creature as permanent companion |
| **Planar Gate** | Conjuration | Rare | Rare gems, chalk, location anchors | Long (25-50 turns) | Create fast-travel portal to known location |
| **Resurrection** | Necromancy | Very Rare | Rare herbs, life essence, intact corpse | Long (25-50 turns) | Return dead companion to life |

**Total: 6 rituals**

---

## Wild Magic Table

When a spell triggers wild magic, roll on this table:

| Roll | Effect |
|------|--------|
| 1 | Caster teleports to random nearby tile |
| 2 | Random creature summoned (hostile or friendly) |
| 3 | Caster polymorphed into animal for 10 turns |
| 4 | Loud explosion alerts all enemies on floor |
| 5 | All light sources in area extinguished |
| 6 | Caster healed to full health |
| 7 | Random item in inventory destroyed |
| 8 | Caster gains temporary invisibility |
| 9 | Gravity reverses briefly (caster takes fall damage) |
| 10 | All doors on floor open/close |
| 11 | Caster's mana fully restored |
| 12 | Weather changes dramatically (if applicable) |
| 13 | Random buff applied to caster |
| 14 | Random debuff applied to caster |
| 15 | Nearest enemy charmed temporarily |
| 16 | Fire erupts at caster's location |
| 17 | Caster gains 1 level (extremely rare, 1% of wild magic) |
| 18 | All items on ground nearby are destroyed |
| 19 | Caster swaps positions with nearest enemy |
| 20 | Nothing happens (the magic just dissipates) |

---

## Mana Cost Table (Suggested)

| Spell Level | Base Mana Cost |
|-------------|----------------|
| 1 | 5 |
| 2 | 8 |
| 3 | 12 |
| 4 | 18 |
| 5 | 25 |
| 6 | 35 |
| 7 | 45 |
| 8 | 60 |
| 9 | 80 |
| 10 | 100 |

---

## Spell Failure Chance (Suggested)

Base failure chance depends on the gap between spell level and caster level:

| Caster Level vs Spell Level | Failure Chance |
|-----------------------------|----------------|
| Spell level = Caster level | 25% |
| Spell level = Caster level - 1 | 15% |
| Spell level = Caster level - 2 | 10% |
| Spell level = Caster level - 3 | 5% |
| Spell level ≤ Caster level - 4 | 2% |

INT above minimum may reduce failure chance further (TBD).

---

## Spell Scaling

Spells grow more powerful as the caster gains levels, without increasing mana cost. This rewards investment in magical progression.

### Scaling Formula

Each spell defines a **scaling factor** that determines how much it improves per caster level above the spell's base level.

**Damage Scaling:**
```
Final Damage = Base Damage + (Scaling × (Caster Level - Spell Level))
```

**Example - Spark (Level 1 spell, Base 8 damage, Scaling 3):**
| Caster Level | Calculation | Total Damage |
|--------------|-------------|--------------|
| 1 | 8 + (3 × 0) | 8 |
| 2 | 8 + (3 × 1) | 11 |
| 4 | 8 + (3 × 3) | 17 |
| 7 | 8 + (3 × 6) | 26 |
| 10 | 8 + (3 × 9) | 35 |

### Scaling Types

| Scaling Type | What Improves | Example |
|--------------|---------------|---------|
| **damage_scaling** | Spell damage | Spark does more damage |
| **duration_scaling** | Buff/debuff duration | Shield lasts longer |
| **range_scaling** | Maximum cast range | Lightning Bolt reaches further |
| **aoe_scaling** | Area of effect radius | Fireball covers more tiles |
| **healing_scaling** | Health restored | Drain Life heals more |
| **summon_scaling** | Summoned creature strength | Summoned skeleton is tougher |

### Scaling Cap

Spells stop scaling at **Caster Level 10** or when the bonus would exceed **3× base value**, whichever comes first. This prevents infinite scaling.

### JSON Schema Addition
```json
{
  "id": "spark",
  "level": 1,
  "effects": {
    "damage": {
      "base": 8,
      "type": "lightning",
      "scaling": 3,
      "scaling_cap": 35
    }
  }
}
```

---

## Mana Recovery

### Mana Potions

Consumable items that restore mana instantly.

| Potion | Mana Restored | Rarity | Value |
|--------|---------------|--------|-------|
| **Minor Mana Potion** | 15 | Common | 25 gold |
| **Mana Potion** | 35 | Uncommon | 60 gold |
| **Greater Mana Potion** | 60 | Rare | 120 gold |
| **Supreme Mana Potion** | 100 | Very Rare | 250 gold |

**Potion JSON:**
```json
{
  "id": "mana_potion",
  "name": "Mana Potion",
  "category": "consumable",
  "subtype": "potion",
  "effects": {
    "mana": 35
  },
  "ascii_char": "!",
  "ascii_color": "#4444FF"
}
```

### Mana Potion Recipes

Mana potions can be crafted using the existing crafting system.

| Recipe | Ingredients | Tool Required | Skill |
|--------|-------------|---------------|-------|
| **Minor Mana Potion** | Moonpetal ×1, Water ×1 | None | Alchemy 1 |
| **Mana Potion** | Moonpetal ×2, Arcane Dust ×1, Water ×1 | Mortar & Pestle | Alchemy 2 |
| **Greater Mana Potion** | Moonpetal ×3, Magical Essence ×1, Crystal Shard ×1, Water ×1 | Alchemy Set | Alchemy 4 |
| **Supreme Mana Potion** | Moonpetal ×5, Magical Essence ×2, Void Stone ×1, Pure Water ×1 | Alchemy Set | Alchemy 6 |

**New Ingredient: Moonpetal**
A glowing blue flower found in dungeons and magical areas. Primary ingredient for mana potions.

```json
{
  "id": "moonpetal",
  "name": "Moonpetal",
  "description": "A luminescent blue flower that pulses with arcane energy.",
  "category": "material",
  "subtype": "herb",
  "flags": {
    "magical": true
  },
  "weight": 0.1,
  "value": 15,
  "max_stack": 20,
  "ascii_char": "*",
  "ascii_color": "#6666FF"
}
```

**Recipe JSON Example:**
```json
{
  "id": "recipe_mana_potion",
  "name": "Mana Potion",
  "description": "Brew a potion that restores magical energy.",
  "category": "alchemy",
  "result": {
    "item_id": "mana_potion",
    "count": 1
  },
  "ingredients": [
    {"item_id": "moonpetal", "count": 2},
    {"item_id": "arcane_dust", "count": 1},
    {"item_id": "water", "count": 1}
  ],
  "tool_required": "mortar_pestle",
  "skill_required": {
    "skill": "alchemy",
    "level": 2
  },
  "discovery_hint": "Moonpetals seem to hold magical potential...",
  "success_chance": 0.85
}
```

### Rest Recovery

Resting (using the rest/sleep mechanic) restores mana faster than passive regeneration.

| Rest Type | Mana Recovery | Notes |
|-----------|---------------|-------|
| **Wait (R key)** | 1 mana/turn | Standard regeneration |
| **Rest in Shelter** | 3 mana/turn | Must be in shelter structure |
| **Sleep/Camp** | Full restore | Takes many turns, can be interrupted |

### Rest Dialog Mana Option

When resting in a shelter, add a new option to the existing rest dialog:

| Rest Option | Effect |
|-------------|--------|
| Rest until healed | Existing - rest until HP full |
| Rest until stamina restored | Existing - rest until stamina full |
| **Rest until mana restored** | **New** - rest until mana full |
| Rest for X turns | Existing - rest specific duration |
| Cancel | Existing - exit dialog |

The "Rest until mana restored" option:
- Only appears if player has a spellbook (is a spellcaster)
- Calculates turns needed based on current mana deficit and regen rate
- Can be interrupted by enemies like other rest options
- Restores mana at 3/turn rate while in shelter

### Casting at 0 Mana

When mana is depleted:
- **Cannot cast spells** that cost mana
- **Can still use scrolls** (scrolls don't require mana)
- **Can still use wands** (wands have their own charges)
- **Cantrips (Level 0 spells)** can still be cast if implemented

**Optional Desperate Casting (future consideration):**
- Cast without mana by spending HP instead (2 HP per 1 mana)
- High failure chance (+30% to failure roll)
- Can be fatal if not careful

---

## Spell Duration

Buff and debuff spells have durations measured in turns.

### Duration Categories

| Category | Base Duration | Examples |
|----------|---------------|----------|
| **Instant** | 0 (immediate effect) | Fireball, Spark, Identify |
| **Brief** | 5-10 turns | Fear, Phantom Sound |
| **Short** | 15-30 turns | Shield, Stone Skin |
| **Medium** | 50-100 turns | Invisibility, Charm |
| **Long** | 200+ turns | Rarely used, powerful buffs |
| **Permanent** | Until dispelled | Terrain changes, Curse (some) |

### Duration Scaling

Duration increases with caster level:
```
Final Duration = Base Duration + (Duration Scaling × (Caster Level - Spell Level))
```

### Damage Over Time (DoT) Effects

Some spells apply ongoing damage each turn for a duration.

**DoT Properties:**
- Damage applied at start of affected creature's turn
- Duration measured in turns
- Can stack from multiple sources (same spell refreshes duration)
- Scaling increases damage per tick, not duration

**Poison Spell Example:**
```json
{
  "id": "poison",
  "name": "Poison",
  "school": "necromancy",
  "level": 1,
  "mana_cost": 5,
  "targeting": {
    "mode": "ranged",
    "range": 6
  },
  "effects": {
    "dot": {
      "type": "poison",
      "damage_per_turn": 3,
      "duration": 10,
      "damage_scaling": 1,
      "duration_scaling": 2
    }
  },
  "save": {
    "type": "CON",
    "on_success": "half_duration"
  }
}
```

**Poison at Different Caster Levels:**
| Caster Level | Damage/Turn | Duration | Total Damage |
|--------------|-------------|----------|--------------|
| 1 | 3 | 10 | 30 |
| 3 | 5 | 14 | 70 |
| 5 | 7 | 18 | 126 |
| 7 | 9 | 22 | 198 |

**DoT Types:**
| Type | Damage | Visual | Cured By |
|------|--------|--------|----------|
| **Poison** | Nature damage | Green tint | Antidote, Cure Poison spell |
| **Burning** | Fire damage | Orange flicker | Water, Stop Drop Roll |
| **Bleeding** | Physical damage | Red drip | Bandage, healing spell |
| **Necrotic** | Dark damage | Purple pulse | Holy magic, rest |

### Concentration

Some spells require **concentration** to maintain:
- Only **one concentration spell** can be active at a time
- Casting another concentration spell ends the first
- Taking damage forces a **concentration check**: roll vs damage taken
- Failure ends the spell early

**Concentration Spells (marked in JSON):**
- Charm (maintaining control)
- Invisibility (maintaining illusion)
- Summon Creature (maintaining the summoning)
- Sanctuary (maintaining the ward)

```json
{
  "id": "charm",
  "concentration": true,
  "duration": {
    "base": 50,
    "scaling": 10
  }
}
```

---

## Saving Throws

Targets can resist spells based on their attributes.

### Save Types

| Save Type | Resists | Attribute |
|-----------|---------|-----------|
| **INT Save** | Mind control, illusions | Intelligence |
| **WIS Save** | Fear, charm, detection | Wisdom |
| **DEX Save** | Area effects, aimed spells | Dexterity |
| **CON Save** | Poison, drain, death effects | Constitution |
| **STR Save** | Forced movement, grappling spells | Strength |

### Save Mechanic

```
Save DC = 10 + Spell Level + (Caster INT / 2)
Target Roll = d20 + Target's Save Attribute Modifier

Success: Spell has reduced/no effect
Failure: Full spell effect
```

**On Successful Save:**
- Damage spells: Half damage
- Control spells: No effect
- Debuffs: Half duration or no effect

### JSON Schema Addition
```json
{
  "id": "charm",
  "save": {
    "type": "WIS",
    "on_success": "no_effect",
    "on_failure": "full_effect"
  }
}
```

---

## Summoned Creatures

### Summon Limits

- Maximum **3 summoned creatures** active at once
- Attempting to summon a 4th automatically dismisses the oldest
- Permanent summons (from ritual) count toward this limit
- Undead raised via Raise Skeleton count as summons

### Summon Duration

| Summon Type | Duration |
|-------------|----------|
| **Spell Summon** | 50 + (Caster Level × 10) turns |
| **Ritual Permanent Summon** | Unlimited (until killed) |
| **Raised Undead** | 100 + (Caster Level × 20) turns |

### Summon AI Behavior

Summoned creatures have behavior modes the player can set:

| Mode | Behavior | Command Key |
|------|----------|-------------|
| **Follow** | Stay adjacent to caster, attack threats | F |
| **Aggressive** | Attack nearest enemy, pursue | A |
| **Defensive** | Only attack if caster is attacked | D |
| **Stay** | Hold position, attack adjacent enemies | S |
| **Dismiss** | Banish the summon | X |

**Default Behavior:** Follow mode

### Summon Commands UI
- Press **C** to open summon command menu
- Select summon (if multiple)
- Select behavior mode
- Or use quick keys: **Ctrl+F/A/D/S/X**

### Summon Stats

Summoned creatures scale with caster level:
```
Summon HP = Base HP + (Caster Level × 5)
Summon Damage = Base Damage + (Caster Level × 2)
```

### AOE and Friendly Fire

**Friendly Fire Rules:**
- Player AOE spells **DO damage summons** (be careful with Fireball!)
- Player AOE spells **DO NOT damage the caster** (self-protection)
- Enemy AOE spells damage everything (including their allies)

This creates tactical decisions: position summons before casting AOE.

---

## Identification System

Scrolls, wands, and potions can be unidentified until the player learns what they are.

### Unidentified Items

| Item Type | Unidentified Appearance | Example |
|-----------|------------------------|---------|
| **Scrolls** | Random syllable labels | "Scroll labeled ZELGO MOR" |
| **Wands** | Material description | "Oak Wand", "Bone Wand" |
| **Potions** | Color description | "Murky Blue Potion" |
| **Spellbooks** | Appearance description | "Leather-bound Tome" |

### Label Generation

At game start, random labels are assigned to each unidentified spell/effect:
- Scrolls: Two random syllables from a pool (ZELGO, MOR, XYZZY, FOOBAR, etc.)
- Wands: Random material (oak, bone, crystal, iron, silver, obsidian)
- Potions: Random color + descriptor (murky, bubbling, glowing, swirling)

**Same label = same effect for entire playthrough** (consistent within a run)

### Identification Methods

| Method | Effect | Notes |
|--------|--------|-------|
| **Identify Spell** | Identifies one item | Costs mana |
| **Scroll of Identify** | Identifies one item | Consumes scroll |
| **Use Item** | Identifies through use | Risky for cursed items |
| **Mage NPC** | Identifies for a fee | 10-50 gold per item |
| **High INT** | Auto-identify low level items | INT 14+: auto-ID level 1-2 |

### Cursed Scrolls

Some unidentified scrolls have negative effects:

| Cursed Scroll | Effect |
|---------------|--------|
| **Scroll of Amnesia** | Forget a random learned spell |
| **Scroll of Summoning** | Summon hostile creature |
| **Scroll of Fire** | Caster bursts into flames |
| **Scroll of Teleportation** | Random teleport (possibly into danger) |
| **Scroll of Weakness** | -3 STR for 100 turns |

Cursed scrolls appear as normal unidentified scrolls. Use-to-identify is risky!

### JSON Schema Addition
```json
{
  "id": "scroll_zelgo_mor",
  "name": "Scroll labeled ZELGO MOR",
  "unidentified": true,
  "true_id": "scroll_fireball",
  "cursed": false
}
```

---

## Wands and Staves

### Wands (Charged Items)

Wands store spell charges and can be used without mana cost.

| Property | Description |
|----------|-------------|
| **Charges** | Number of uses (typically 5-20) |
| **Recharge** | Some can be recharged at mage NPC |
| **Identification** | Unidentified until used or ID'd |
| **No Requirements** | Anyone can use (still needs 8 INT for magic) |

**Wand JSON:**
```json
{
  "id": "wand_of_fireballs",
  "name": "Wand of Fireballs",
  "category": "weapon",
  "subtype": "wand",
  "flags": {
    "magical": true,
    "charged": true
  },
  "casts_spell": "fireball",
  "spell_level_override": 5,
  "charges": 8,
  "max_charges": 8,
  "recharge_cost": 100,
  "ascii_char": "/",
  "ascii_color": "#FF4400"
}
```

### Staves (Melee + Casting Focus)

Staves serve dual purpose: melee weapon and casting enhancement.

**Staff Properties:**
- **Melee Damage**: Can be used as melee weapon (low damage, two-handed)
- **Casting Bonus**: Provides bonuses when casting spells
- **School Affinity**: Some staves boost specific schools

| Staff | Melee Damage | Casting Bonus | School Affinity |
|-------|--------------|---------------|-----------------|
| **Wooden Staff** | 4 | +5% success | None |
| **Staff of Fire** | 5 | +10% success | Evocation +2 damage |
| **Staff of the Mind** | 4 | +10% success | Enchantment +15% duration |
| **Necromancer's Staff** | 6 | +10% success | Necromancy +3 damage |
| **Archmage Staff** | 8 | +15% success, -10% mana cost | All schools |

**Staff JSON:**
```json
{
  "id": "staff_of_fire",
  "name": "Staff of Fire",
  "category": "weapon",
  "subtype": "staff",
  "flags": {
    "equippable": true,
    "magical": true,
    "two_handed": true,
    "casting_focus": true
  },
  "equip_slots": ["main_hand"],
  "damage_bonus": 5,
  "attack_type": "melee",
  "casting_bonuses": {
    "success_modifier": 10,
    "school_affinity": "evocation",
    "school_damage_bonus": 2
  },
  "ascii_char": "/",
  "ascii_color": "#FF6600"
}
```

---

## Magic Rings

Rings provide permanent magical effects while equipped. Players can wear up to 2 rings (accessory_1 and accessory_2 slots).

### Ring Properties

- **Permanent Effect**: Effect active as long as ring is worn
- **No Charges**: Unlike wands, rings don't deplete
- **No Mana Cost**: Effects are passive, no resource drain
- **Stackable Effects**: Two rings of same type stack (with diminishing returns)
- **Cursed Rings**: Some rings cannot be removed once equipped

### Ring Types

| Ring | Effect | Rarity | Value |
|------|--------|--------|-------|
| **Ring of Protection** | +2 armor | Common | 100 |
| **Ring of Strength** | +1 STR | Uncommon | 150 |
| **Ring of Intelligence** | +1 INT | Uncommon | 150 |
| **Ring of Wisdom** | +1 WIS | Uncommon | 150 |
| **Ring of Fire Resistance** | 50% fire damage reduction | Uncommon | 200 |
| **Ring of Ice Resistance** | 50% ice damage reduction | Uncommon | 200 |
| **Ring of Lightning Resistance** | 50% lightning damage reduction | Uncommon | 200 |
| **Ring of Mana** | +20 max mana | Rare | 300 |
| **Ring of Regeneration** | +1 HP per 10 turns | Rare | 350 |
| **Ring of Mana Regeneration** | +1 mana per 5 turns | Rare | 350 |
| **Ring of Invisibility** | Permanent invisibility (breaks on attack) | Very Rare | 500 |
| **Ring of Free Action** | Immune to slow/paralysis | Rare | 400 |
| **Ring of Sustenance** | Hunger/thirst drain halved | Rare | 400 |
| **Ring of Spell Storing** | Store one spell, cast without mana (1/day) | Very Rare | 600 |
| **Ring of the Archmage** | +2 INT, +30 max mana, -10% spell failure | Legendary | 1000 |

### Cursed Rings

| Cursed Ring | Appears As | Actual Effect |
|-------------|------------|---------------|
| **Ring of Weakness** | Ring of Strength | -2 STR, cannot remove |
| **Ring of Hunger** | Ring of Sustenance | 2× hunger/thirst drain, cannot remove |
| **Ring of Fumbling** | Ring of Protection | +20% spell failure, cannot remove |
| **Ring of Doom** | Ring of Regeneration | -1 HP per 10 turns, cannot remove |

**Removing Cursed Rings:**
- Cast Remove Curse spell
- Visit a temple/shrine (pay fee)
- Find Scroll of Remove Curse
- Die (not recommended)

### Ring JSON Schema
```json
{
  "id": "ring_of_mana",
  "name": "Ring of Mana",
  "description": "A silver ring set with a sapphire that pulses with arcane energy.",
  "category": "accessory",
  "subtype": "ring",
  "flags": {
    "equippable": true,
    "magical": true
  },
  "equip_slots": ["accessory"],
  "weight": 0.1,
  "value": 300,
  "max_stack": 1,
  "ascii_char": "=",
  "ascii_color": "#4444FF",
  "passive_effects": {
    "max_mana_bonus": 20
  }
}
```

### Cursed Ring JSON Schema
```json
{
  "id": "ring_of_weakness",
  "name": "Ring of Strength",
  "true_name": "Ring of Weakness",
  "description": "A gold ring that seems to emanate power.",
  "cursed": true,
  "identified": false,
  "flags": {
    "equippable": true,
    "magical": true,
    "cursed": true
  },
  "equip_slots": ["accessory"],
  "passive_effects": {
    "STR": -2
  },
  "curse_effects": {
    "cannot_unequip": true
  }
}
```

### Stacking Rules

When wearing two rings with the same effect:
- **Stat bonuses**: Stack fully (+1 STR + +1 STR = +2 STR)
- **Resistances**: Diminishing returns (50% + 50% = 75%, not 100%)
- **Regeneration**: Stack fully
- **Max mana/HP**: Stack fully
- **Unique effects**: Do not stack (two Ring of Invisibility = same as one)

---

## Magic Status Effects

### Silence

Prevents all spellcasting.

| Property | Value |
|----------|-------|
| **Duration** | 10-30 turns |
| **Sources** | Enemy spell, trap, cursed item |
| **Effect** | Cannot cast spells or use scrolls |
| **Wands** | CAN still use (not verbal magic) |
| **Counter** | Wait it out, Dispel Magic, certain items |

### Mana Drain

Enemy attack that steals mana.

| Property | Value |
|----------|-------|
| **Sources** | Enemy spell, certain creatures (mana vampires) |
| **Effect** | Lose X mana, enemy may gain it |
| **Prevention** | Abjuration buffs, certain resistances |

### Dispel on Damage (Concentration Break)

Taking damage can end concentration spells.

**Concentration Check:**
```
Roll = d20 + (CON / 2)
DC = 10 + (Damage Taken / 2)

Success: Spell continues
Failure: Spell ends immediately
```

---

## Cantrips (Level 0 Spells)

Minor spells that cost no mana, providing mages a baseline capability.

| Cantrip | School | Effect |
|---------|--------|--------|
| **Mage Hand** | Conjuration | Pick up item from 3 tiles away |
| **Light** | Conjuration | Dim light on self for 100 turns |
| **Prestidigitation** | Transmutation | Minor sensory effects (flavor) |
| **Ray of Frost** | Evocation | 3 damage, no scaling |
| **Message** | Enchantment | "Hear" NPC dialogue from distance |

**Cantrip Properties:**
- Cost: 0 mana
- Always succeed (no failure chance)
- Minimal scaling (if any)
- Available to anyone with 8+ INT and a spellbook
- Don't require learning (known automatically)

---

## Enemy Spellcasters

Enemies can cast spells, making magic feel like part of the world.

### Enemy Mage Types

| Enemy | Spells Known | AI Behavior |
|-------|--------------|-------------|
| **Apprentice Mage** | Spark, Shield | Casts at range, retreats when close |
| **Cultist** | Drain Life, Curse | Aggressive, uses debuffs |
| **Necromancer** | Raise Skeleton, Drain Life, Fear | Summons minions, stays back |
| **Battle Mage** | Fireball, Lightning Bolt, Shield | Balanced offense/defense |
| **Archmage** | Multiple schools, high level spells | Tactical, uses counters |

### Enemy Casting Rules

- Enemies have mana pools (simpler, often unlimited for balance)
- Enemy spells use same mechanics as player spells
- Player can interrupt enemy casting (if we add cast times)
- Enemy AOE can hit their allies (tactical opportunity)

### Enemy JSON Addition
```json
{
  "id": "necromancer",
  "spellcaster": true,
  "mana": 100,
  "mana_regen": 2,
  "known_spells": ["raise_skeleton", "drain_life", "fear"],
  "cast_behavior": "summon_first",
  "preferred_range": 6
}
```

---

## Elemental Interactions

### Resistances and Vulnerabilities

Creatures can be resistant or vulnerable to damage types.

| Resistance Level | Damage Modifier |
|------------------|-----------------|
| **Immune** | 0% damage |
| **Resistant** | 50% damage |
| **Normal** | 100% damage |
| **Vulnerable** | 150% damage |

### Common Creature Resistances

| Creature Type | Fire | Ice | Lightning | Poison | Holy |
|---------------|------|-----|-----------|--------|------|
| **Undead** | Normal | Resistant | Normal | Immune | Vulnerable |
| **Fire Elemental** | Immune | Vulnerable | Normal | Immune | Normal |
| **Ice Creature** | Vulnerable | Immune | Normal | Immune | Normal |
| **Demon** | Resistant | Normal | Normal | Immune | Vulnerable |
| **Plant** | Vulnerable | Normal | Normal | Resistant | Normal |

### Environmental Combos

| Combo | Effect |
|-------|--------|
| **Fire + Oil** | Explosion (double damage, larger radius) |
| **Fire + Water** | Steam (obscures vision for 5 turns) |
| **Ice + Water** | Frozen floor (slippery, DEX check or fall) |
| **Lightning + Water** | Conducts (hits all creatures in water) |
| **Fire + Ice** | Cancel out (both spells negated) |

### JSON Schema Addition
```json
{
  "id": "skeleton",
  "resistances": {
    "fire": "normal",
    "ice": "resistant",
    "lightning": "normal",
    "poison": "immune",
    "holy": "vulnerable"
  }
}
```

---

## Starting Town Mage

A mage NPC should be added to the starting town to introduce players to magic.

### Mage NPC: "Eldric the Wanderer"
- **Location**: Starting town (near shop or in dedicated tower/hut)
- **ASCII**: `@` or `M` in purple/blue
- **Dialogue**: Introduces magic system, offers services

### Mage Services

| Service | Cost | Description |
|---------|------|-------------|
| **Buy Spellbook** | 50 gold | Basic spellbook to store spells |
| **Learn Conjure Light** | Free (first time) | Teaches Level 1 spell to get players started |
| **Learn Spark** | 25 gold | Level 1 Evocation damage spell |
| **Learn Shield** | 30 gold | Level 1 Abjuration protection |
| **Learn Detect Traps** | 40 gold | Level 2 Divination utility |
| **Inscribe Spell** | Varies | Pay to have scroll inscribed (100% success) |
| **Buy Scrolls** | Varies | Purchase common low-level scrolls |
| **Buy Components** | Varies | Basic magical components |

### Mage Dialogue Flow
1. **First meeting**: "Ah, a traveler! I sense potential in you. Have you studied the arcane arts?"
2. **If INT < 8**: "Alas, the mysteries of magic require a keener mind. Perhaps someday..."
3. **If INT >= 8, no spellbook**: "You have the gift, but you'll need a spellbook to harness it. I can sell you one."
4. **If has spellbook, no spells**: "Let me teach you a simple light spell - every mage should know this one. No charge for your first lesson."
5. **Subsequent visits**: Standard shop/service interface

---

## Spell Components

Ritual spells require physical components that are consumed during casting. Components use a mix of existing game items and new magical materials.

### Existing Items as Components

| Item | Used In | Notes |
|------|---------|-------|
| **Wood** | Various rituals | Common, easily harvested |
| **Cloth** | Sanctify Area | For altar cloths |
| **Leather** | Binding rituals | From animals |
| **Iron Ore** | Enchant Item (weapon) | Metal enhancement |
| **Flint** | Fire rituals | Spark source |
| **Herbs** | Resurrection, healing rituals | Various plants |
| **Water (Waterskin)** | Scrying, purification | Clean water required |
| **Coal/Charite** | Drawing circles | For ritual markings |
| **Bones** | Necromancy rituals | From defeated enemies |

### New Magical Components

| Component | Rarity | Found In | Used For |
|-----------|--------|----------|----------|
| **Magical Essence** | Uncommon | Enemy mages, magical creatures | Enchant Item, most rituals |
| **Soul Gem (Empty)** | Uncommon | Dungeon loot, shops | Capturing creature souls |
| **Soul Gem (Filled)** | Rare | Filled by player | Permanent Summon, Resurrection |
| **Arcane Dust** | Common | Disenchanting items, mage shops | General component |
| **Crystal Shard** | Uncommon | Mining, dungeon loot | Scrying, enchantments |
| **Powdered Silver** | Uncommon | Crafted from silver items | Sanctify Area, wards |
| **Dragon Scale** | Rare | Dragon enemies (future) | Powerful enchantments |
| **Phoenix Feather** | Very Rare | Special locations | Resurrection |
| **Void Stone** | Rare | Deep dungeons | Planar Gate |
| **Binding Chalk** | Common | Mage shops, crafted | Drawing ritual circles |

### Component JSON Schema
```json
{
  "id": "magical_essence",
  "name": "Magical Essence",
  "description": "A shimmering vial of condensed magical energy.",
  "category": "material",
  "subtype": "magical_component",
  "flags": {
    "magical": true,
    "craftable": false
  },
  "weight": 0.2,
  "value": 50,
  "max_stack": 10,
  "ascii_char": "!",
  "ascii_color": "#AA44FF"
}
```

### Ritual Component Lists

| Ritual | Components Required |
|--------|---------------------|
| **Enchant Item** | Magical Essence ×1, Crystal Shard ×1, target item |
| **Scrying** | Crystal Shard ×1, Water ×1, Arcane Dust ×3 |
| **Sanctify Area** | Powdered Silver ×2, Binding Chalk ×1, Cloth ×2 |
| **Permanent Summon** | Soul Gem (Filled) ×1, Binding Chalk ×3, Magical Essence ×2 |
| **Planar Gate** | Void Stone ×1, Crystal Shard ×3, Arcane Dust ×5 |
| **Resurrection** | Phoenix Feather ×1, Soul Gem (Filled) ×1, Herbs ×5 |

---

## Integration Notes

### With Survival System
- Light integration only: INT affects max mana
- Survival stats (hunger, thirst, temperature) do NOT affect spellcasting
- High-level conjuration (Create Food/Water) intentionally trivializes survival

### With Combat System
- Ranged spells use existing TargetingSystem
- Spell damage bypasses armor (or has separate magic resistance stat)
- Buffs/debuffs use existing stat_modifier system

### With Item System
- Spell books are items with `teaches_spell` property
- Scrolls are consumable items with `spell_cast` effect
- Staffs/wands may provide casting bonuses or grant spell abilities
- Ritual components are material items

### With Turn System
- Casting a spell costs 1 turn (like attacking)
- Ritual channeling occurs over multiple turns
- Mana regenerates during turn processing

---

## Future Considerations (Post-Phase 1)

- **Spell upgrades**: Enhanced versions of lower-level spells
- **Metamagic**: Modify spells (extend range, increase damage, reduce cost)
- **Magic resistance**: Enemy stat that reduces spell effectiveness
- **Spell combos**: Synergies between certain spells
- **School specialization**: Bonuses for focusing on one school
- **Magical corruption**: Consequences for overusing dark magic
- **Counterspelling**: Interrupt enemy casters
- **Magical items**: Wands, staves, robes that enhance casting

---

## Data-Driven Design

All magic content should be defined in JSON files, following the existing codebase patterns. This allows adding new spells, rituals, and wild magic effects without code changes.

### Directory Structure
```
data/
├── spells/
│   ├── evocation/
│   │   ├── spark.json
│   │   ├── flame_bolt.json
│   │   └── ...
│   ├── conjuration/
│   ├── enchantment/
│   ├── transmutation/
│   ├── divination/
│   ├── necromancy/
│   ├── abjuration/
│   └── illusion/
├── rituals/
│   ├── enchant_item.json
│   ├── scrying.json
│   └── ...
├── wild_magic/
│   └── effects.json
└── spell_components/
    └── ritual_components.json
```

### Spell JSON Schema
```json
{
  "id": "fireball",
  "name": "Fireball",
  "description": "Hurls a ball of fire that explodes on impact.",
  "school": "evocation",
  "level": 7,
  "requirements": {
    "character_level": 7,
    "intelligence": 14
  },
  "mana_cost": 45,
  "targeting": {
    "mode": "ranged",
    "range": 8,
    "aoe_radius": 3
  },
  "effects": {
    "damage": {
      "type": "fire",
      "base": 25,
      "scaling": "INT"
    },
    "status": "burning",
    "status_duration": 3
  },
  "cast_message": "You hurl a ball of flame!",
  "ascii_char": "*",
  "ascii_color": "#FF4400"
}
```

### Spell Targeting Mode Options
```json
{
  "mode": "ranged|self|tile|inventory|aoe",
  "range": 8,
  "aoe_radius": 0,
  "aoe_shape": "circle|cone|line",
  "requires_los": true
}
```

### Ritual JSON Schema
```json
{
  "id": "enchant_item",
  "name": "Enchant Item",
  "description": "Imbue an item with magical properties.",
  "school": "transmutation",
  "rarity": "common",
  "requirements": {
    "intelligence": 8
  },
  "components": [
    {"item_id": "magical_essence", "count": 1},
    {"item_id": "gem_ruby", "count": 2}
  ],
  "channeling_turns": 12,
  "interruptible": true,
  "targeting": {
    "mode": "inventory",
    "valid_categories": ["weapon", "armor", "accessory"]
  },
  "effects": {
    "enchantment_type": "player_choice",
    "enchantment_options": ["fire_damage", "protection", "sharpness"]
  },
  "success_message": "The item glows with magical energy!",
  "failure_message": "The ritual fails and the components crumble to dust."
}
```

### Wild Magic Effects JSON Schema
```json
{
  "effects": [
    {
      "id": "random_teleport",
      "weight": 5,
      "description": "Caster teleports to random nearby tile",
      "effect_type": "teleport",
      "parameters": {
        "range": 10,
        "random": true
      }
    },
    {
      "id": "summon_random",
      "weight": 5,
      "description": "Random creature summoned",
      "effect_type": "summon",
      "parameters": {
        "creature_pool": ["rat", "wolf", "skeleton", "imp"],
        "hostile_chance": 0.5
      }
    }
  ]
}
```

### Spell Book Item Schema
Spell books are items that teach spells:
```json
{
  "id": "spellbook_fireball",
  "name": "Tome of Fireball",
  "description": "A weathered tome containing the secrets of the Fireball spell.",
  "category": "book",
  "subtype": "spellbook",
  "flags": {
    "readable": true,
    "magical": true
  },
  "teaches_spell": "fireball",
  "weight": 1.0,
  "value": 500,
  "ascii_char": "+",
  "ascii_color": "#FF4400"
}
```

### Scroll Item Schema
Scrolls allow one-time spell casting:
```json
{
  "id": "scroll_fireball",
  "name": "Scroll of Fireball",
  "description": "A parchment inscribed with the Fireball incantation.",
  "category": "consumable",
  "subtype": "scroll",
  "flags": {
    "consumable": true,
    "magical": true
  },
  "casts_spell": "fireball",
  "weight": 0.1,
  "value": 150,
  "max_stack": 5,
  "ascii_char": "~",
  "ascii_color": "#FF4400"
}
```

### Manager Loading Pattern
Following existing codebase conventions:
```gdscript
# SpellManager autoload
const SPELL_DATA_PATH = "res://data/spells"
var spells: Dictionary = {}  # spell_id -> spell_data

func _ready() -> void:
    _load_spells_recursive(SPELL_DATA_PATH)

func _load_spells_recursive(path: String) -> void:
    var dir = DirAccess.open(path)
    dir.list_dir_begin()
    var file_name = dir.get_next()
    while file_name != "":
        var full_path = path + "/" + file_name
        if dir.current_is_dir() and not file_name.begins_with("."):
            _load_spells_recursive(full_path)
        elif file_name.ends_with(".json"):
            _load_spell_file(full_path)
        file_name = dir.get_next()
    dir.list_dir_end()
```

### Adding New Content

**To add a new spell:**
1. Create JSON file in `data/spells/{school}/{spell_id}.json`
2. (Optional) Create matching spell book in `data/items/books/`
3. (Optional) Create matching scroll in `data/items/consumables/`
4. SpellManager auto-loads on startup

**To add a new ritual:**
1. Create JSON file in `data/rituals/{ritual_id}.json`
2. Ensure required component items exist in `data/items/`
3. RitualManager auto-loads on startup

**To add wild magic effects:**
1. Add entry to `data/wild_magic/effects.json`
2. Assign appropriate weight for probability

---

## Open Questions

1. **Exact mana regeneration rate** - 1/turn? Based on INT? Based on WIS?
2. **Ritual component specifics** - What items exactly? Create new materials or use existing?
3. **Enchantment options** - What properties can be enchanted onto items?
4. **Summoned creature duration** - How many turns do temporary summons last?
5. **Spell book drop rates** - How rare should each spell level be?
6. **Magic shops** - What spells are available for purchase? Level limits?

---

*Last Updated: January 2025*
*Status: Specification Review*
