# Debug/Test Mode Implementation Plan

## Overview
Add a Debug/Test Mode accessible via **F12** that provides developer tools for spawning items, creatures, hazards, features, and modifying player state during gameplay.

**Key Decisions:**
- Hotkey: F12
- Access: Always available (no restrictions)
- Spawn Location: Adjacent to player with direction prompt

---

## Files to Create

### 1. `ui/debug_command_menu.tscn`
Modal screen following help_screen pattern:
- Dimmer overlay (ColorRect, 0.7 alpha)
- Centered panel (700x640)
- ScrollContainer with command list
- Direction prompt overlay for spawning

### 2. `ui/debug_command_menu.gd`
Core functionality:
- Main menu with categorized commands
- Submenu for item/creature/hazard/feature selection
- Direction selection using existing pattern (_awaiting_*_direction)
- Command execution methods

---

## Files to Modify

### 1. `systems/input_handler.gd`
- Add F12 keybinding in `_unhandled_input()` (~line 700)
- Add `_toggle_debug_menu()` method

### 2. `scenes/game.gd`
- Add `debug_command_menu` variable
- Preload DebugCommandMenuScene
- Add `_setup_debug_command_menu()` in `_ready()`
- Add `toggle_debug_menu()` and signal handlers

### 3. `autoload/game_manager.gd`
- Add `debug_god_mode: bool = false`
- Add `debug_map_revealed: bool = false`

### 4. `entities/entity.gd`
- Check `GameManager.debug_god_mode` in `take_damage()` for Player

### 5. `autoload/spell_manager.gd`
- Add `get_all_spell_ids() -> Array[String]` method

### 6. `ui/help_screen.gd`
- Add F12 to keybindings documentation

---

## Debug Commands

### Items Category
| Command | Action |
|---------|--------|
| Give Item | Select item → add to inventory |
| Spawn Item on Ground | Select item → choose direction → spawn as GroundItem |

### Spawning Category
| Command | Action |
|---------|--------|
| Spawn Creature | Select enemy → choose direction → EntityManager.spawn_enemy() |
| Spawn Hazard | Select hazard → choose direction → add to HazardManager.active_hazards |
| Spawn Feature | Select feature → choose direction → add to FeatureManager.active_features |

### Player Category
| Command | Action |
|---------|--------|
| Give Gold | Select amount (100/500/1000/5000/10000) → player.gold += amount |
| Set Level | Select level (1-50) → update player.level |
| Max Stats | Fill health, hunger, thirst, stamina, mana; reset fatigue |
| Learn All Spells | Add all spells to player.known_spells |
| Learn All Recipes | Add all recipes to player.known_recipes |
| Toggle God Mode | Toggle GameManager.debug_god_mode |

### World Category
| Command | Action |
|---------|--------|
| Teleport | Select location or enter coordinates → move player |
| Reveal Map | Toggle GameManager.debug_map_revealed |

---

## Implementation Phases

### Phase 1: Core Infrastructure
1. Create `ui/debug_command_menu.tscn` scene
2. Create `ui/debug_command_menu.gd` with:
   - Basic open/close functionality
   - Main menu navigation (↑↓ + Enter + ESC)
   - Command list display
3. Add F12 binding to `input_handler.gd`
4. Add menu setup to `game.gd`

### Phase 2: Item Commands
1. Implement Give Item (submenu → inventory add)
2. Implement Spawn Item on Ground (submenu → direction → spawn)
3. Direction selection UI overlay

### Phase 3: Entity Spawning
1. Implement Spawn Creature (submenu → direction → EntityManager.spawn_enemy())
2. Implement Spawn Hazard (submenu → direction → HazardManager.active_hazards)
3. Implement Spawn Feature (submenu → direction → FeatureManager.active_features)

### Phase 4: Player Commands
1. Implement Give Gold (amount selection)
2. Implement Set Level (level selection)
3. Implement Max Stats (instant fill)
4. Implement Learn All Spells/Recipes
5. Implement God Mode toggle

### Phase 5: World Commands
1. Implement Teleport (location list)
2. Implement Reveal Map (FOV toggle)

### Phase 6: Polish
1. Add F12 to help screen
2. Visual feedback for command execution
3. Error handling and edge cases

---

## UI Structure

```
DebugCommandMenu (Control)
├── Dimmer (ColorRect)
└── Panel
    └── MarginContainer
        └── VBoxContainer
            ├── Title: "◆ DEBUG COMMANDS ◆"
            ├── HSeparator
            ├── ScrollContainer
            │   └── CommandList (VBoxContainer)
            │       ├── [ITEMS]
            │       │   ├── Give Item
            │       │   └── Spawn Item on Ground
            │       ├── [SPAWNING]
            │       │   ├── Spawn Creature
            │       │   ├── Spawn Hazard
            │       │   └── Spawn Feature
            │       ├── [PLAYER]
            │       │   ├── Give Gold
            │       │   ├── Set Level
            │       │   ├── Max Stats
            │       │   ├── Learn All Spells
            │       │   ├── Learn All Recipes
            │       │   └── Toggle God Mode
            │       └── [WORLD]
            │           ├── Teleport
            │           └── Reveal Map
            └── Footer: "↑↓ Navigate  [Enter] Execute  [Esc] Close"
```

---

## Key APIs to Use

```gdscript
# Items
ItemManager.get_all_item_ids() -> Array[String]
ItemManager.create_item(item_id, count) -> Item
player.inventory.add_item(item) -> bool
EntityManager.spawn_ground_item(item, position)

# Creatures
EntityManager.get_all_enemy_ids() -> Array[String]
EntityManager.spawn_enemy(enemy_id, position) -> Enemy

# Hazards/Features
HazardManager.hazard_definitions -> Dictionary
HazardManager.active_hazards[position] = hazard_data
FeatureManager.feature_definitions -> Dictionary
FeatureManager.active_features[position] = feature_data

# Player
player.gold += amount
player.level = new_level
player.current_health = player.max_health
player.survival.hunger/thirst/stamina/fatigue/mana
player.known_spells.append(spell_id)
player.known_recipes.append(recipe_id)

# Spells/Recipes
SpellManager.get_all_spell_ids() -> Array[String]
RecipeManager.all_recipes.keys()
```

---

## Verification

1. **F12 opens/closes menu** - Press F12, verify menu appears with dimmer
2. **Navigation works** - Use ↑↓ to move selection, ESC closes
3. **Give Item** - Select item, verify added to inventory
4. **Spawn Creature** - Select enemy, choose direction, verify spawned at adjacent tile
5. **Spawn Hazard/Feature** - Select type, choose direction, verify placed
6. **Give Gold** - Select amount, verify player.gold increased
7. **Max Stats** - Execute, verify all stats filled
8. **God Mode** - Enable, take damage, verify no damage taken
9. **Learn All** - Execute spells/recipes, verify all unlocked
