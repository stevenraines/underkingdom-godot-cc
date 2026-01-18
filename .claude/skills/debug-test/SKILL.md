# Debug and Test Skill

Workflow for debugging and testing game features.

---

## Debug Mode

Enable debug mode via the in-game menu or by setting `GameManager.debug_mode = true`.

### Debug Menu Commands
- Spawn items
- Spawn enemies
- Teleport player
- Modify stats
- Toggle god mode

---

## Common Debug Checks

### Check Turn System
```gdscript
print("Turn: %d | %s" % [TurnManager.current_turn, TurnManager.time_of_day])
```

### Verify Map Generation (Deterministic)
```gdscript
var map1 = WorldGenerator.generate_overworld(12345)
var map2 = WorldGenerator.generate_overworld(12345)
# Should be identical - same seed = same result
```

### Inspect Entity State
```gdscript
print("Player HP: %d/%d" % [player.current_health, player.max_health])
print("Inventory Weight: %.1f/%.1f kg" % [
    player.inventory.get_total_weight(),
    player.inventory.max_weight
])
```

### Watch Signals
```gdscript
EventBus.turn_advanced.connect(func(turn): print("Turn advanced: ", turn))
EventBus.entity_died.connect(func(entity): print("Entity died: ", entity.name))
```

### Check Item Loading
```gdscript
ItemManager.debug_print_all()
VariantManager.debug_print_all()
```

---

## Testing Checklist

### New Item
- [ ] Item appears in debug spawn menu
- [ ] Item has correct properties (weight, value, effects)
- [ ] Item stacks correctly
- [ ] Item can be picked up/dropped
- [ ] Item can be equipped (if applicable)
- [ ] Item can be consumed (if applicable)

### New Enemy
- [ ] Enemy appears in debug spawn menu
- [ ] Enemy has correct stats
- [ ] Enemy AI behaves correctly
- [ ] Enemy drops loot on death
- [ ] Enemy grants experience

### New Recipe
- [ ] Recipe appears in crafting menu
- [ ] Ingredients are consumed on craft
- [ ] Result item is correct
- [ ] Tool requirement works
- [ ] Fire requirement works (if applicable)

### Map Generation
- [ ] Same seed produces identical map
- [ ] Stairs connect floors correctly
- [ ] Entities spawn in valid locations
- [ ] No inaccessible areas (wall culling works)

---

## Performance Notes

- Map Size: 100×100 overworld (10k tiles), 50×50 dungeons (2.5k tiles)
- Entity Count: Typical dungeon ~20-50 enemies, overworld ~100 entities
- Turn-based = no real-time performance concerns

---

## Key Files

- `ui/debug_command_menu.gd` - Debug menu
- `autoload/game_manager.gd` - Debug mode flag
- `autoload/event_bus.gd` - Signal reference
