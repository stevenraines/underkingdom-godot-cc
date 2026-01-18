# Add NPC Skill

Workflow for adding new NPCs to the game.

---

## Steps

### 1. Create NPC JSON

Create `data/npcs/npc_name.json`:

```json
{
  "id": "blacksmith",
  "name": "Brom Ironhand",
  "npc_type": "shop",
  "ascii_char": "@",
  "ascii_color": "#CD853F",
  "faction": "neutral",
  "gold": 400,
  "restock_interval": 500,
  "dialogue": {
    "greeting": "The forge runs hot today! Looking for quality metalwork?",
    "training": "I can teach you the ways of the smith.",
    "farewell": "May your blade stay sharp.",
    "no_gold": "No coin, no steel. That's how it works."
  },
  "trade_inventory": [
    {"item_id": "iron_sword", "count": 2, "base_price": 50},
    {"item_id": "iron_dagger", "count": 3, "base_price": 30}
  ],
  "recipes_for_sale": [
    {"recipe_id": "iron_sword", "base_price": 50}
  ]
}
```

### 2. NPC Types

| Type | Description |
|------|-------------|
| `shop` | Buys and sells items |
| `trainer` | Teaches skills/recipes |
| `quest` | Quest giver |
| `service` | Provides services (healing, etc.) |
| `ambient` | Decorative, provides dialogue only |

### 3. Dialogue Configuration

```json
"dialogue": {
  "greeting": "Hello, traveler!",
  "farewell": "Safe travels.",
  "no_gold": "You don't have enough gold.",
  "no_item": "I don't have that in stock.",
  "training": "I can teach you...",
  "quest_offer": "I have a task for you...",
  "quest_complete": "Well done!",
  "busy": "I'm busy right now."
}
```

### 4. Trade Inventory

```json
"trade_inventory": [
  {"item_id": "iron_sword", "count": 2, "base_price": 50},
  {"item_id": "healing_potion", "count": 5, "base_price": 25}
],
"restock_interval": 500
```

Inventory restocks after `restock_interval` turns.

### 5. Recipes for Sale

```json
"recipes_for_sale": [
  {"recipe_id": "iron_sword", "base_price": 50},
  {"recipe_id": "steel_dagger", "base_price": 75}
]
```

Player can purchase recipe knowledge.

### 6. Faction System

```json
"faction": "neutral"
```

Factions: `neutral`, `friendly`, `hostile`, `guard`

Faction affects initial disposition and dialogue.

### 7. Services

For service NPCs:
```json
"services": {
  "healing": {
    "cost_per_hp": 2,
    "max_heal": 50
  },
  "identify": {
    "cost": 50
  },
  "repair": {
    "cost_percent": 0.1
  }
}
```

### 8. Assigning to Towns

In `data/towns/[town].json`:
```json
"buildings": [
  {
    "building_id": "blacksmith",
    "position_offset": [5, -5],
    "npc_id": "blacksmith",
    "door_facing": "south"
  }
]
```

---

## Verification

1. Restart game (NPCManager loads on startup)
2. Visit town where NPC is assigned
3. Interact with NPC (Enter key)
4. Test trade functionality
5. Verify dialogue displays correctly
6. Check restock behavior over time

---

## Key Files

- `data/npcs/` - NPC definitions
- `autoload/npc_manager.gd` - NPC loading
- `entities/npc.gd` - NPC base class
- `systems/shop_system.gd` - Trade logic
- `ui/shop_screen.gd` - Trade UI
- `data/towns/` - Town NPC assignments
