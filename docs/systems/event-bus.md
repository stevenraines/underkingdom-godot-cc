# Event Bus

**Source File**: `autoload/event_bus.gd`
**Type**: Autoload Singleton

## Overview

The Event Bus is a central signal hub that enables loose coupling between game systems. Instead of direct dependencies, systems emit signals through the Event Bus and other systems listen for relevant events. This architecture makes the codebase more modular and easier to maintain.

## Key Concepts

- **Central Hub**: Single location for all game-wide signals
- **Loose Coupling**: Systems communicate without direct references
- **Signal-Based**: Uses Godot's built-in signal system

## Signal Categories

### Turn and Time

| Signal | Parameters | Description |
|--------|------------|-------------|
| `turn_advanced` | turn_number: int | Emitted each turn |
| `time_of_day_changed` | period: String | Dawn/day/dusk/night transitions |

### Player

| Signal | Parameters | Description |
|--------|------------|-------------|
| `player_moved` | old_pos, new_pos: Vector2i | Player position changed |

### Map

| Signal | Parameters | Description |
|--------|------------|-------------|
| `map_changed` | map_id: String | Transitioned to new map |
| `chunk_loaded` | chunk_coords: Vector2i | Chunk generated/loaded |
| `chunk_unloaded` | chunk_coords: Vector2i | Chunk unloaded from memory |

### Entity

| Signal | Parameters | Description |
|--------|------------|-------------|
| `entity_died` | entity: Entity | Entity killed |
| `entity_moved` | entity, old_pos, new_pos | Entity position changed |

### Combat

| Signal | Parameters | Description |
|--------|------------|-------------|
| `attack_performed` | attacker, defender, result | Attack resolved |
| `combat_message` | message: String, color: Color | Combat log message |
| `player_died` | (none) | Player health reached 0 |

### Survival

| Signal | Parameters | Description |
|--------|------------|-------------|
| `survival_stat_changed` | stat_name, old_value, new_value | Survival stat updated |
| `survival_warning` | message: String, severity: String | Low survival warning |
| `stamina_depleted` | (none) | Stamina reached 0 |

### Inventory

| Signal | Parameters | Description |
|--------|------------|-------------|
| `item_picked_up` | item: Item | Item added to inventory |
| `item_dropped` | item, position: Vector2i | Item dropped on ground |
| `item_used` | item, result: Dictionary | Item consumed/used |
| `item_equipped` | item, slot: String | Item equipped |
| `item_unequipped` | item, slot: String | Item unequipped |
| `inventory_changed` | (none) | Inventory contents changed |
| `encumbrance_changed` | ratio: float | Weight ratio changed |

### Crafting

| Signal | Parameters | Description |
|--------|------------|-------------|
| `craft_attempted` | recipe, success: bool | Crafting attempt made |
| `craft_succeeded` | recipe, result: Item | Crafting succeeded |
| `craft_failed` | recipe | Crafting failed |
| `recipe_discovered` | recipe | New recipe learned |

### Structure

| Signal | Parameters | Description |
|--------|------------|-------------|
| `structure_placed` | structure | Structure built |
| `structure_removed` | structure | Structure destroyed |
| `structure_interacted` | structure, player | Player used structure |
| `container_opened` | structure | Container accessed |
| `container_closed` | structure | Container closed |
| `fire_toggled` | structure, is_lit: bool | Fire lit/extinguished |

### NPC & Shop

| Signal | Parameters | Description |
|--------|------------|-------------|
| `npc_interacted` | npc, player | NPC interaction started |
| `shop_opened` | npc, player | Shop interface opened |
| `item_purchased` | item, price: int | Item bought from shop |
| `item_sold` | item, price: int | Item sold to shop |
| `shop_restocked` | npc | Shop inventory refreshed |

### Save/Load

| Signal | Parameters | Description |
|--------|------------|-------------|
| `game_saved` | slot: int | Game saved to slot |
| `game_loaded` | slot: int | Game loaded from slot |
| `save_failed` | error: String | Save operation failed |
| `load_failed` | error: String | Load operation failed |

### Feature & Hazard

| Signal | Parameters | Description |
|--------|------------|-------------|
| `feature_interacted` | feature_id, position, result | Feature used |
| `feature_spawned_enemy` | enemy_id, position | Feature spawned enemy |
| `hazard_triggered` | hazard_id, position, target, damage | Hazard activated |
| `hazard_detected` | hazard_id, position | Hidden hazard revealed |
| `hazard_disarmed` | hazard_id, position | Hazard neutralized |

### UI

| Signal | Parameters | Description |
|--------|------------|-------------|
| `message_logged` | message: String | Message for game log |

### Rest/Wait

| Signal | Parameters | Description |
|--------|------------|-------------|
| `rest_started` | turns: int | Rest session began |
| `rest_interrupted` | reason: String | Rest stopped by event |
| `rest_completed` | turns_rested: int | Rest finished normally |

## Usage Patterns

### Emitting Signals

```gdscript
# From any system
EventBus.turn_advanced.emit(current_turn)
EventBus.message_logged.emit("You picked up the sword.")
EventBus.combat_message.emit("Critical hit!", Color.RED)
```

### Connecting to Signals

```gdscript
func _ready():
    EventBus.turn_advanced.connect(_on_turn_advanced)
    EventBus.player_moved.connect(_on_player_moved)

func _on_turn_advanced(turn_number: int):
    # Handle turn advancement
    pass
```

### One-Shot Connections

```gdscript
# Connect for single event only
EventBus.map_changed.connect(_on_first_map_change, CONNECT_ONE_SHOT)
```

## Best Practices

### Do
- Use EventBus for cross-system communication
- Keep signal parameters minimal
- Use appropriate signal for each event type
- Clean up connections in `_exit_tree()`

### Don't
- Create circular signal chains
- Pass large objects through signals
- Use EventBus for internal class communication
- Emit signals before systems are initialized

## Signal Flow Examples

### Combat Flow

```
Player attacks enemy
    ↓
CombatSystem resolves attack
    ↓
EventBus.attack_performed.emit(player, enemy, result)
    ↓
HUD updates damage display
Renderer shows attack animation
Audio plays combat sound
```

### Turn Flow

```
TurnManager.advance_turn()
    ↓
EventBus.turn_advanced.emit(turn_number)
    ↓
SurvivalSystem processes drains
EntityManager processes AI turns
HUD updates turn display
```

## Related Documentation

- [Turn Manager](./turn-manager.md) - Turn signals
- [Combat System](./combat-system.md) - Combat signals
- [Inventory System](./inventory-system.md) - Item signals
- [Feature Manager](./feature-manager.md) - Feature signals
