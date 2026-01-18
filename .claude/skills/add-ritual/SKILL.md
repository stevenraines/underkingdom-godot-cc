# Add Ritual Skill

Workflow for adding new rituals to the game.

---

## Steps

### 1. Create Ritual JSON

Create `data/rituals/ritual_name.json`:

```json
{
  "id": "enchant_item",
  "name": "Enchant Item",
  "description": "Imbue an item with permanent magical properties.",
  "school": "transmutation",
  "components": [
    {"item_id": "mana_crystal", "quantity": 5},
    {"item_id": "arcane_essence", "quantity": 2},
    {"item_id": "gold", "quantity": 100}
  ],
  "channeling_turns": 10,
  "requirements": {
    "intelligence": 14,
    "near_altar": true
  },
  "effects": {
    "enchant_item": {
      "enchantment_pool": ["sharpness", "protection", "mana_regen", "health_regen"]
    }
  },
  "failure_effects": {
    "destroy_item_chance": 0.3
  },
  "discovery_location": "ancient_library"
}
```

### 2. Ritual vs Spell

| Aspect | Spell | Ritual |
|--------|-------|--------|
| Cast Time | Instant | Multi-turn channeling |
| Cost | Mana | Components (consumed) |
| Level Req | Yes | No |
| INT Req | Yes | Yes (usually higher) |
| Location | Anywhere | Often requires altar/circle |

### 3. Component Requirements

```json
"components": [
  {"item_id": "mana_crystal", "quantity": 5},
  {"item_id": "rare_herb", "quantity": 3},
  {"item_id": "gold", "quantity": 100}
]
```

Components are consumed when ritual begins, not when it completes.

### 4. Location Requirements

```json
"requirements": {
  "intelligence": 14,
  "near_altar": true,
  "near_water": false,
  "underground": false,
  "at_night": true
}
```

### 5. Effect Types

#### Enchant Item
```json
"effects": {
  "enchant_item": {
    "enchantment_pool": ["sharpness", "protection"]
  }
}
```

#### Summon Creature
```json
"effects": {
  "summon": {
    "creature_id": "demon",
    "permanent": true
  }
}
```

#### Scrying
```json
"effects": {
  "reveal_area": {
    "radius": 20,
    "duration": 50
  }
}
```

#### Resurrection
```json
"effects": {
  "resurrection": {
    "health_percent": 0.5
  }
}
```

### 6. Failure Effects

```json
"failure_effects": {
  "destroy_item_chance": 0.3,
  "damage_caster": 20,
  "summon_hostile": "lesser_demon",
  "curse_caster": "weakness"
}
```

### 7. Discovery

Rituals are learned by finding them at specific locations:
```json
"discovery_location": "ancient_library"
```

Discovery locations: `ancient_library`, `dark_altar`, `arcane_tower`, `forgotten_tomb`

---

## Verification

1. Restart game (RitualManager loads on startup)
2. Verify ritual appears when discovered
3. Check component requirements
4. Test channeling (can be interrupted)
5. Verify effects on success/failure

---

## Key Files

- `data/rituals/` - Ritual definitions
- `autoload/ritual_manager.gd` - Ritual loading
- `docs/data/rituals.md` - Full format documentation
