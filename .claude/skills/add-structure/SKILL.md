# Add Structure Skill

Workflow for adding new placeable structures to the game.

---

## Steps

### 1. Create Structure JSON

Create `data/structures/structure_name.json`:

```json
{
  "id": "structure_id",
  "name": "Structure Name",
  "description": "What this structure does and provides.",
  "ascii_char": "^",
  "ascii_color": "#FF6600",
  "blocks_movement": false,
  "structure_type": "campfire",
  "durability": 100,
  "components": {
    "fire": {
      "heat_radius": 3,
      "temperature_bonus": 15.0,
      "light_radius": 5
    }
  },
  "build_requirements": [
    {"item": "wood", "count": 3}
  ],
  "build_tool": "flint",
  "build_time_turns": 1
}
```

### 2. Structure Types

| Type | Description |
|------|-------------|
| `campfire` | Fire source, provides heat and light |
| `shelter` | Weather protection |
| `container` | Storage for items |
| `workstation` | Crafting station (anvil, forge) |
| `light` | Light source only |
| `decoration` | Visual only, no gameplay effect |

### 3. Component Types

#### Fire Component
```json
"fire": {
  "heat_radius": 3,
  "temperature_bonus": 15.0,
  "light_radius": 5
}
```

#### Shelter Component
```json
"shelter": {
  "weather_protection": 0.8,
  "size": [3, 3]
}
```

#### Container Component
```json
"container": {
  "capacity": 100,
  "weight_limit": 50.0
}
```

#### Workstation Component
```json
"workstation": {
  "station_type": "forge",
  "crafting_bonus": 10
}
```

### 4. Build Requirements

```json
"build_requirements": [
  {"item": "wood", "count": 3},
  {"item": "stone", "count": 2}
],
"build_tool": "hammer",
"build_time_turns": 5
```

---

## Verification

1. Restart game (StructureManager loads on startup)
2. Check structure appears in build menu
3. Test building with required materials
4. Verify component effects work (heat, light, etc.)

---

## Key Files

- `data/structures/` - Structure definitions
- `autoload/structure_manager.gd` - Structure loading
- `systems/structure_placement.gd` - Build validation
- `systems/components/fire_component.gd` - Fire behavior
- `systems/components/shelter_component.gd` - Shelter behavior
- `systems/components/container_component.gd` - Storage behavior
