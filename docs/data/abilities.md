# Abilities Data Format

Documentation for class feats and racial traits in the data-driven ability system.

**Source Files:**
- Class feats: `data/classes/*.json`
- Racial traits: `data/races/*.json`
- Handler: `ui/special_actions_screen.gd`
- Combat triggers: `systems/combat_system.gd`, `systems/ranged_combat_system.gd`

---

## Overview

The ability system is **fully data-driven** using activation patterns. All ability behavior is defined in JSON files with no hardcoded logic in the UI layer.

### Three Activation Patterns

1. **`proactive_buff`** - Activate now, triggers automatically later on a specific condition
2. **`direct_effect`** - Immediate result when activated (healing, buffs, etc.)
3. **`reactive_automatic`** - Triggers automatically without player control (not shown in Special Actions menu)

---

## JSON Structure

### Base Properties (All Abilities)

```json
{
  "id": "ability_id",
  "name": "Display Name",
  "description": "Tooltip description shown in UI",
  "type": "active",
  "uses_per_day": 1,
  "activation_pattern": "proactive_buff",
  "effect": {
    // Pattern-specific properties
  }
}
```

**Common Properties:**
- `id` (string) - Unique identifier, lowercase_with_underscores
- `name` (string) - Display name shown in UI
- `description` (string) - Help text shown in Special Actions menu
- `type` (string) - Always `"active"` for abilities with uses
- `uses_per_day` (integer) - Number of daily uses (recharges at dawn)
- `activation_pattern` (string) - One of: `"proactive_buff"`, `"direct_effect"`, `"reactive_automatic"`
- `effect` (object) - Pattern-specific effect data

---

## Pattern 1: Proactive Buff

**Use when:** Player activates ability before the event, then it triggers automatically when condition is met.

**Examples:** Lucky (reroll next miss), Berserker Strike (next hit deals double damage), Power Attack (next attack stronger)

### Effect Properties

```json
"effect": {
  "buff_id": "unique_buff_identifier",
  "buff_name": "Buff Display Name",
  "buff_duration": 999,
  "trigger_on": "attack_miss",
  "trigger_effect": "reroll_attack",
  "activation_message": "Message shown when activated",
  "trigger_message": "Message shown when triggered (optional)",

  // Optional properties for specific trigger effects:
  "damage_multiplier": 2.0,
  "self_damage": 5
}
```

#### Required Properties

- **`buff_id`** (string) - Unique identifier for the buff (e.g., `"lucky_active"`)
- **`buff_name`** (string) - Display name shown in active effects (e.g., `"Lucky (Active)"`)
- **`buff_duration`** (integer) - Turns until expires. Use `999` for "until consumed"
- **`trigger_on`** (string) - When the buff triggers:
  - `"attack_miss"` - When the player misses any attack (melee or ranged)
  - `"melee_hit"` - When the player hits with a melee attack
  - `"ranged_hit"` - When the player hits with a ranged attack
- **`trigger_effect`** (string) - What happens when triggered:
  - `"reroll_attack"` - Reroll the attack (for misses)
  - `"double_damage"` - Apply damage multiplier (for hits)
- **`activation_message`** (string) - Message shown when ability is activated

#### Optional Properties

- **`trigger_message`** (string) - Message shown when buff triggers (can use `%d` placeholders for values)
- **`damage_multiplier`** (float) - Damage multiplier for `"double_damage"` effect (default: 2.0)
- **`self_damage`** (integer) - Damage to attacker when triggered (default: 0)

### Complete Example: Lucky (Halfling)

```json
{
  "id": "lucky",
  "name": "Lucky",
  "description": "Once per day, reroll a failed attack",
  "type": "active",
  "uses_per_day": 1,
  "activation_pattern": "proactive_buff",
  "effect": {
    "buff_id": "lucky_active",
    "buff_name": "Lucky (Active)",
    "buff_duration": 999,
    "trigger_on": "attack_miss",
    "trigger_effect": "reroll_attack",
    "activation_message": "Lucky activated! Your next miss will be rerolled.",
    "trigger_message": "Lucky! Rerolling attack... (%d -> %d)"
  }
}
```

### Complete Example: Berserker Strike (Barbarian)

```json
{
  "id": "berserker_strike",
  "name": "Berserker Strike",
  "description": "Deal double damage but take 5 damage yourself once per day",
  "type": "active",
  "uses_per_day": 1,
  "activation_pattern": "proactive_buff",
  "effect": {
    "buff_id": "berserker_strike_active",
    "buff_name": "Berserker Strike (Ready)",
    "buff_duration": 999,
    "trigger_on": "melee_hit",
    "trigger_effect": "double_damage",
    "damage_multiplier": 2.0,
    "self_damage": 5,
    "activation_message": "Berserker Strike ready! Your next melee hit will deal double damage.",
    "trigger_message": "Berserker Strike! You unleash devastating power!"
  }
}
```

---

## Pattern 2: Direct Effect

**Use when:** Ability has immediate result when activated (healing, mana recovery, temporary buffs, etc.)

**Examples:** Second Wind (instant heal), Mana Surge (mana recovery), Vanish (stealth buff), Track Prey (reveal enemies)

### Effect Properties

```json
"effect": {
  // Choose one or more:
  "heal_percent": 0.25,
  "heal_amount": 10,
  "mana_percent": 0.50,
  "reveal_enemies": true,
  "apply_buff": { /* buff object */ },

  "activation_message": "Message shown when activated"
}
```

#### Healing Effects

**Percentage-based healing:**
```json
"effect": {
  "heal_percent": 0.25,  // 0.0 to 1.0 (0.25 = 25% of max HP)
  "activation_message": "Second Wind! You recover health."
}
```

**Fixed amount healing:**
```json
"effect": {
  "heal_amount": 10,  // Fixed HP amount
  "activation_message": "Blessed Rest! Divine energy restores your vitality."
}
```

> **Note:** If the player has `heal_with_class_bonus()` method (Cleric's Divine Favor), healing is automatically boosted.

#### Mana Recovery

```json
"effect": {
  "mana_percent": 0.50,  // 0.0 to 1.0 (0.50 = 50% of max mana)
  "activation_message": "Mana Surge! You recover magical energy."
}
```

#### Temporary Buffs

Apply a buff with limited duration:

```json
"effect": {
  "apply_buff": {
    "buff_id": "vanish_stealth",
    "buff_name": "Vanished",
    "buff_type": "buff",
    "buff_duration": 1  // Turns (1 = expires next turn)
  },
  "activation_message": "You vanish into the shadows!"
}
```

#### Reveal Enemies

```json
"effect": {
  "reveal_enemies": true,
  "activation_message": "You track nearby prey... enemies revealed!"
}
```

> **Note:** Currently reveals enemies within 2× perception range. Count is not shown in message - implement custom logic if needed.

### Complete Example: Second Wind (Warrior)

```json
{
  "id": "second_wind",
  "name": "Second Wind",
  "description": "Recover 25% of max health once per day",
  "type": "active",
  "uses_per_day": 1,
  "activation_pattern": "direct_effect",
  "effect": {
    "heal_percent": 0.25,
    "activation_message": "Second Wind! You recover health."
  }
}
```

### Complete Example: Vanish (Rogue)

```json
{
  "id": "vanish",
  "name": "Vanish",
  "description": "Become undetectable for 1 turn once per day",
  "type": "active",
  "uses_per_day": 1,
  "activation_pattern": "direct_effect",
  "effect": {
    "apply_buff": {
      "buff_id": "vanish_stealth",
      "buff_name": "Vanished",
      "buff_type": "buff",
      "buff_duration": 1
    },
    "activation_message": "You vanish into the shadows!"
  }
}
```

---

## Pattern 3: Reactive Automatic

**Use when:** Ability triggers automatically without player activation (death saves, passive responses)

**Examples:** Relentless Endurance (survive lethal damage)

### Effect Properties

```json
"effect": {
  "trigger_on": "lethal_damage",
  "set_hp": 1,
  "trigger_message": "Message shown when triggered"
}
```

> **Important:** Reactive abilities are NOT implemented in the Special Actions UI handler. You must implement the trigger logic in the appropriate system (e.g., `entities/player.gd` for death saves).

### Complete Example: Relentless Endurance (Half-Orc)

```json
{
  "id": "relentless",
  "name": "Relentless Endurance",
  "description": "Once per day, survive a killing blow with 1 HP",
  "type": "active",
  "uses_per_day": 1,
  "activation_pattern": "reactive_automatic",
  "effect": {
    "trigger_on": "lethal_damage",
    "set_hp": 1,
    "trigger_message": "Relentless Endurance! You refuse to fall."
  }
}
```

> **Note:** This ability appears in the Special Actions menu but cannot be manually activated. Selecting it shows: "Relentless Endurance activates automatically when you would die."

---

## Adding New Abilities

### Step 1: Choose the Activation Pattern

Ask yourself:

1. **Does the player activate it before an event happens, then it triggers automatically?**
   - YES → Use `proactive_buff`
   - Example: "Activate, then your next miss gets rerolled"

2. **Does the ability have an immediate effect when activated?**
   - YES → Use `direct_effect`
   - Example: "Activate to heal 25% HP right now"

3. **Does it trigger automatically without player input?**
   - YES → Use `reactive_automatic`
   - Example: "Automatically survive when you would die"

### Step 2: Add to JSON File

**For class feats:** Edit `data/classes/your_class.json`

**For racial traits:** Edit `data/races/your_race.json`

Add the ability to the `"feats"` or `"traits"` array:

```json
{
  "feats": [
    {
      "id": "existing_ability",
      "name": "Existing Ability",
      // ...
    },
    {
      "id": "your_new_ability",
      "name": "Your New Ability",
      "description": "Clear description of what it does",
      "type": "active",
      "uses_per_day": 2,
      "activation_pattern": "proactive_buff",
      "effect": {
        // Pattern-specific properties
      }
    }
  ]
}
```

### Step 3: Test In-Game

1. Start a new game or load a save
2. Press `A` to open Special Actions menu
3. Select your new ability
4. Verify:
   - Activation message appears
   - Uses decrement correctly
   - Effect triggers at the right time
   - Trigger message appears (for proactive buffs)

---

## Extending the System

### Adding New Trigger Types

To add a new `trigger_on` type (e.g., `"spell_cast"`):

1. **Update combat or relevant system** to check for the trigger:

```gdscript
// In appropriate system (e.g., spell_system.gd)
for effect in player.active_effects:
    if effect.get("trigger_on", "") == "spell_cast":
        match effect.get("trigger_effect", ""):
            "reduce_mana_cost":
                mana_cost = int(mana_cost * effect.get("mana_multiplier", 0.5))
                player.remove_magical_effect(effect.id)
                break
```

2. **Document the new trigger** in this file

3. **Add example abilities** using the new trigger

### Adding New Trigger Effects

To add a new `trigger_effect` type (e.g., `"triple_damage"`):

1. **Add match case** in `combat_system.gd` or `ranged_combat_system.gd`:

```gdscript
match effect.get("trigger_effect", ""):
    "double_damage":
        damage_multiplier = effect.get("damage_multiplier", 2.0)
        // ...
    "triple_damage":
        damage_multiplier = 3.0
        // New effect
```

2. **Document the new effect** in this file

3. **Create example abilities** using the new effect

### Adding New Direct Effect Types

To add a new direct effect (e.g., `"grant_temp_stats"`):

1. **Add handler** in `special_actions_screen.gd` → `_handle_direct_effect()`:

```gdscript
# Grant temporary stat bonuses
if effect.has("grant_temp_stats"):
    var stats = effect.grant_temp_stats
    var buff = {
        "id": action_id + "_stats",
        "type": "buff",
        "modifiers": stats,  // {"STR": 2, "DEX": 1}
        "remaining_duration": effect.get("duration", 10),
        "source_spell": ""
    }
    player.add_magical_effect(buff)
```

2. **Document the new property** in this file

3. **Create example abilities** using the new property

---

## Troubleshooting

### Ability doesn't appear in Special Actions menu

- **Check:** Is `type: "active"` in the JSON?
- **Check:** Is `uses_per_day` > 0?
- **Check:** Did ClassManager/RaceManager load the file? (Check console for errors)

### Ability activates but nothing happens

- **Proactive buffs:** Check that the buff is applied (look at active effects in character sheet)
- **Direct effects:** Check for missing effect properties (e.g., forgot `heal_percent`)
- **Reactive:** These aren't implemented in the UI - check relevant system code

### Trigger doesn't fire

- **Check:** Is the buff ID correct and unique?
- **Check:** Does `trigger_on` match the event? (`"attack_miss"` only triggers on misses)
- **Check:** Is the buff being removed too early? (Check `buff_duration`)

### Uses don't reset at dawn

- **Check:** Player's `reset_daily_abilities()` method is called by TurnManager
- **Check:** Ability ID matches between JSON and player's tracking dictionaries

---

## Summary

| Pattern | When to Use | Example |
|---------|-------------|---------|
| `proactive_buff` | Activate before event, auto-trigger later | Lucky, Berserker Strike, Power Attack |
| `direct_effect` | Immediate result when activated | Second Wind, Mana Surge, Vanish |
| `reactive_automatic` | Triggers without player input | Relentless Endurance, Last Stand |

**Key Benefits:**
- ✅ No code changes needed - just edit JSON
- ✅ Consistent behavior across all abilities
- ✅ Easy to balance - tweak numbers in data
- ✅ Self-documenting - JSON shows exactly how it works
- ✅ Extensible - add new triggers/effects as needed

---

**Related Documentation:**
- [Class Manager](../systems/class-manager.md)
- [Race Manager](../systems/race-manager.md)
- [Combat System](../systems/combat-system.md)
- [Ranged Combat System](../systems/ranged-combat-system.md)

**Last Updated:** January 18, 2026
