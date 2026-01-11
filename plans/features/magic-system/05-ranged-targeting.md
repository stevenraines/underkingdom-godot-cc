# Phase 5: Ranged Spell Targeting

## Overview
Integrate spell casting with the existing targeting system for ranged spells.

## Dependencies
- Phase 4: Basic Spell Casting
- Existing: `systems/targeting_system.gd`
- Existing: `systems/ranged_combat_system.gd`

## Implementation Steps

### 5.1 Extend TargetingSystem for Spells
**File:** `systems/targeting_system.gd`

Add spell targeting mode:
```gdscript
var targeting_spell: Spell = null
var is_spell_targeting: bool = false

func start_spell_targeting(p_caster: Entity, p_spell: Spell) -> bool:
    if p_spell.targeting.mode != "ranged":
        return false

    targeting_spell = p_spell
    is_spell_targeting = true
    attacker = p_caster

    # Get valid targets within spell range
    valid_targets = _get_valid_spell_targets(p_caster, p_spell)

    if valid_targets.is_empty():
        cancel()
        return false

    is_targeting = true
    target_index = 0
    current_target = valid_targets[0]
    targeting_started.emit()
    target_changed.emit(current_target)
    return true

func _get_valid_spell_targets(caster: Entity, spell: Spell) -> Array[Entity]:
    var targets: Array[Entity] = []
    var spell_range = spell.targeting.range

    for entity in EntityManager.get_all_entities():
        if entity == caster:
            continue
        if not entity is Enemy:
            continue
        if entity.current_health <= 0:
            continue

        var distance = _get_distance(caster.position, entity.position)
        if distance > spell_range:
            continue

        # Check line of sight if required
        if spell.targeting.get("requires_los", true):
            if not RangedCombatSystem.has_line_of_sight(caster.position, entity.position):
                continue

        # Check if visible to player
        if not _is_visible_to_player(entity):
            continue

        targets.append(entity)

    return targets
```

### 5.2 Add Spell Targeting Confirmation
**File:** `systems/targeting_system.gd`

```gdscript
func confirm_spell_target() -> Dictionary:
    if not is_spell_targeting or current_target == null:
        return {success = false, message = "No valid target"}

    var result = MagicSystem.attempt_spell(attacker, targeting_spell, [current_target])

    # Clean up targeting state
    var spell = targeting_spell
    cancel()

    return result
```

### 5.3 Update Input Handler for Spell Targeting
**File:** `systems/input_handler.gd`

Modify targeting input to handle spells:
```gdscript
func _handle_targeting_input(event: InputEvent) -> bool:
    if not targeting_system.is_targeting:
        return false

    if event.is_action_pressed("confirm") or event.is_action_pressed("fire"):
        if targeting_system.is_spell_targeting:
            var result = targeting_system.confirm_spell_target()
            if result.success:
                TurnManager.advance_turn()
            _display_spell_result(result)
        else:
            # Existing ranged weapon handling
            ...
        return true

    # Tab/arrows for cycling - works for both
    ...
```

### 5.4 Add Spell Selection to Targeting Flow
**File:** `ui/spell_cast_menu.gd`

When a ranged spell is selected:
```gdscript
func _on_spell_selected(spell: Spell):
    if spell.targeting.mode == "self":
        # Cast immediately
        var result = MagicSystem.attempt_spell(player, spell, [])
        _display_result(result)
        if result.success:
            TurnManager.advance_turn()
        hide()
    elif spell.targeting.mode == "ranged":
        # Enter targeting mode
        hide()
        if targeting_system.start_spell_targeting(player, spell):
            EventBus.message_logged.emit("Select target (Tab to cycle, Enter to cast, Esc to cancel)", Color.CYAN)
        else:
            EventBus.message_logged.emit("No valid targets in range.", Color.YELLOW)
```

### 5.5 Add Spell Range Indicator
**File:** `rendering/ascii_renderer.gd`

Optionally highlight tiles within spell range during targeting:
```gdscript
func highlight_spell_range(center: Vector2i, range: int, color: Color):
    # Highlight valid tiles within range
    for x in range(-range, range + 1):
        for y in range(-range, range + 1):
            var pos = center + Vector2i(x, y)
            if _get_distance(center, pos) <= range:
                _highlight_tile(pos, color)
```

### 5.6 Add Targeting Mode Visual Feedback
**File:** `ui/hud.gd`

Show "TARGETING: [Spell Name]" when in spell targeting mode.

## Testing Checklist

- [ ] Select Spark spell from cast menu
- [ ] Game enters targeting mode (Tab to cycle targets)
- [ ] Only enemies within range (6 tiles) are targetable
- [ ] Only enemies with line of sight are targetable
- [ ] Tab cycles through valid targets
- [ ] Enter/F confirms target and casts spell
- [ ] Escape cancels targeting without casting
- [ ] Mana consumed only on cast, not on cancel
- [ ] Turn advances after successful cast
- [ ] HUD shows "TARGETING: Spark" during targeting
- [ ] Spell range visually indicated (optional)
- [ ] No valid targets message if none in range

## Files Modified
- `systems/targeting_system.gd`
- `systems/input_handler.gd`
- `ui/spell_cast_menu.gd`
- `ui/hud.gd`
- `rendering/ascii_renderer.gd` (optional)

## Files Created
- None

## Next Phase
Once ranged targeting works, proceed to **Phase 6: Damage Spells**
