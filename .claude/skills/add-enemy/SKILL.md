# Add Enemy Skill

Workflow for adding new enemies to the game.

---

## Steps

### 1. Create Enemy JSON File

Create a new JSON file in `data/enemies/[location]/enemy_name.json`:

```json
{
  "id": "enemy_id",
  "name": "Enemy Name",
  "description": "Description of the enemy",
  "ascii_char": "e",
  "color": "#FF0000",
  "stats": {
    "max_health": 20,
    "strength": 12,
    "dexterity": 10,
    "constitution": 10,
    "intelligence": 6,
    "wisdom": 8,
    "charisma": 6
  },
  "combat": {
    "base_damage": 4,
    "armor": 0,
    "accuracy": 70,
    "evasion": 10
  },
  "behavior": {
    "type": "aggressive",
    "aggro_range": 8,
    "wander_range": 5
  },
  "loot_table": "enemy_name_loot",
  "experience": 25,
  "spawn_weight": 10,
  "creature_type": "beast"
}
```

### 2. Behavior Types

- `wander` - Moves randomly, attacks if player adjacent
- `guardian` - Stays near spawn point, attacks intruders
- `aggressive` - Actively hunts player within aggro_range
- `pack` - Coordinates with nearby allies

### 3. Create Loot Table (Optional)

If the enemy has unique drops, create `data/loot_tables/enemy_name_loot.json`:

```json
{
  "id": "enemy_name_loot",
  "entries": [
    {"item": "gold", "weight": 50, "min": 1, "max": 10},
    {"item": "raw_meat", "weight": 30, "count": 1},
    {"item": "leather", "weight": 20, "count": 1}
  ]
}
```

### 4. Verification

1. Restart the game (EntityManager loads on startup)
2. Use debug menu to spawn the enemy
3. Test combat and loot drops
4. Verify AI behavior matches expected type

---

## Key Files

- `data/enemies/` - Enemy definitions (organized by location)
- `data/loot_tables/` - Loot table definitions
- `autoload/entity_manager.gd` - Loads and spawns enemies
- `entities/enemy.gd` - Enemy base class

---

## Creature Types

Available creature types (for resistances/vulnerabilities):
- `humanoid`, `beast`, `undead`, `construct`, `elemental`, `demon`, `dragon`

Check `data/creature_types/` for definitions.
