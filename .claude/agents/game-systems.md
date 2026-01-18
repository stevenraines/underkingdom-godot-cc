# Game Systems Domain Knowledge

Use this agent when implementing or modifying core game systems: combat, survival, inventory, equipment, or the turn-based game loop.

---

## Turn-Based Game Loop

1. Player takes action (movement, attack, interact, wait)
2. `TurnManager.advance_turn()` increments turn counter
3. `EntityManager.process_entity_turns()` runs all enemy AI
4. Survival systems drain (hunger, thirst, fatigue)
5. Repeat

**Day/Night Cycle**: Configured in `data/calendar.json`, turns_per_day calculated from time period durations
- Default: 100 turns/day with periods: dawn (15), day (27), mid_day (1), day (27), dusk (15), night (7), midnight (1), night (7)
- Time periods define duration and temperature modifiers; start/end turns computed automatically
- Affects: visibility range, enemy spawn rates, survival drain rates, temperature

---

## Entity-Component System

**Base Classes**:
- `Entity` (base) - Position, ASCII char, color, blocking, health, stats (STR/DEX/CON/INT/WIS/CHA)
- `Player` (extends Entity) - Inventory, equipment, survival stats, movement, interaction
- `Enemy` (extends Entity) - AI behavior (wander/guardian/aggressive/pack), loot table, aggro range
- `GroundItem` (extends Entity) - Item on ground, despawn timer

**Stats & Derived Values**:
- Health: Base 10 + (CON × 5)
- Stamina: Base 50 + (CON × 10)
- Carry Capacity: Base 20 + (STR × 5) kg
- Perception Range: Base 5 + (WIS / 2) tiles

---

## Combat System

### Melee Combat
- Bump-to-attack for melee (cardinal adjacency)
- Attack resolution: `Hit Chance = Attacker Accuracy - Defender Evasion`
- Damage: `Weapon Base + STR Modifier - Armor`

### Ranged Combat
- Press `R` to enter targeting mode with ranged weapon
- `Tab`/Arrow keys cycle through valid targets
- `Enter`/`F` to fire, `Escape` to cancel
- Ranged weapons (bows, crossbows, slings) require ammunition
- Thrown weapons (throwing_knife, throwing_axe) are consumed on throw
- Ammunition can be recovered (based on `recovery_chance` property)
- Range penalty: -5% accuracy per tile beyond half range
- Line-of-sight required (uses Bresenham's algorithm)

### Weapon Types
- `attack_type: "melee"` - Standard bump-to-attack weapons
- `attack_type: "ranged"` - Bows, crossbows, slings (require `ammunition_type`)
- `attack_type: "thrown"` - Throwing knives, axes (consumed on use)

### Enemy AI (based on INT)
- INT 1-3: Direct approach, no tactics
- INT 4-6: Flanking, retreats when low health
- INT 7-9: Group coordination, uses environment
- INT 10+: Predicts movement, calls reinforcements

---

## Survival Systems

All interconnected for emergent gameplay:

### Hunger (0-100)
- Drain: 1 point per 20 turns
- Effects: Stamina regen penalty, STR loss, health drain at 0

### Thirst (0-100)
- Drain: 1 point per 15 turns (faster than hunger)
- Effects: Stamina max reduction, WIS loss, perception loss, confusion, severe health drain

### Temperature (Hypothermia ↔ Comfortable ↔ Hyperthermia)
- Sources: Weather, biome, time of day, equipment, fires
- Comfortable: 15-25°C
- Cold/Hot: Stat penalties, accelerated drain rates

### Stamina/Fatigue
- Stamina: 0-Max (CON-based), costs for movement/attacks
- Fatigue: 0-100, accumulates when stamina hits 0, reduces max stamina
- Regen: 1/turn when not acting

---

## Inventory & Equipment

### Structure
- Equipment slots: head, torso, hands, legs, feet, main_hand, off_hand, accessory×2
- General inventory: Unlimited slots, weight-limited

### Encumbrance
- 0-75%: No penalty
- 75-100%: Stamina costs +50%
- 100-125%: Movement costs 2 turns, stamina +100%
- 125%+: Cannot move

### Items
- All items defined in JSON (`data/items/*.json`) or generated from templates
- Properties: id, name, weight, value, stack size, ASCII char/color, durability
- Types: consumable, material, tool, weapon, armor, currency
- Equipped items provide stat bonuses (weapon damage, armor)

### GroundItems
- Items on the ground rendered on EntityLayer
- Floor tile (period) hidden when item/entity stands on it
- Pickup/drop mechanics integrated with movement

---

## Harvest System

**Generic resource harvesting** with configurable behaviors:
- All resources defined in separate JSON files (`data/resources/*.json`)
- Loaded recursively from subdirectories like items and enemies
- Three harvest behaviors: permanent destruction, renewable, non-consumable
- Tool requirements, stamina costs, yield tables with probability

### Harvest Behaviors
- **Destroy Permanent**: Resource destroyed forever (trees → wood, rocks → stone)
- **Destroy Renewable**: Resource respawns after N turns (wheat → grain)
- **Non-Consumable**: Never depletes (water → fresh water)

### Player Interaction
- Press 'H' key to harvest
- Select direction with arrow keys or WASD
- System validates tool, consumes stamina, generates yields
- Renewable resources tracked for automatic respawn

---

## Key Files

- `systems/combat_system.gd` - Melee combat
- `systems/ranged_combat_system.gd` - Ranged combat
- `systems/survival_system.gd` - Hunger, thirst, temperature
- `systems/inventory_system.gd` - Inventory management
- `systems/harvest_system.gd` - Resource harvesting
- `autoload/turn_manager.gd` - Turn loop
- `autoload/entity_manager.gd` - Entity spawning and AI
- `entities/player.gd` - Player entity
- `entities/enemy.gd` - Enemy entity
