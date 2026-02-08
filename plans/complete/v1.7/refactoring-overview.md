# V1.7 Refactoring Overview

**Goal**: Improve code organization, apply DRY/SOLID principles, and make the codebase easier to maintain without breaking any existing functionality.

---

## Plan Index

Execute these plans in order (lowest to highest risk):

### Phase A: Utility Extraction (Zero Risk)
| Plan | File | Description |
|------|------|-------------|
| 01 | [refactor-01-json-helper-extend.md](refactor-01-json-helper-extend.md) | Extend JsonHelper to eliminate duplicate JSON loading code |
| 02 | [refactor-02-ui-theme-constants.md](refactor-02-ui-theme-constants.md) | Create centralized UI color constants |
| 03 | [refactor-03-inventory-filter-constants.md](refactor-03-inventory-filter-constants.md) | Consolidate filter hotkey/label constants |

### Phase B: Minor Extractions (Low Risk)
| Plan | File | Description |
|------|------|-------------|
| 04 | [refactor-04-chunk-cleanup-mixin.md](refactor-04-chunk-cleanup-mixin.md) | Create shared chunk cleanup utility |
| 05 | [refactor-05-input-mode-handlers.md](refactor-05-input-mode-handlers.md) | Extract input mode handlers |
| 06 | [refactor-06-debug-command-executor.md](refactor-06-debug-command-executor.md) | Separate debug command execution from UI |

### Phase C: Component Extraction (Medium Risk)
| Plan | File | Description |
|------|------|-------------|
| 07 | [refactor-07-item-usage-handler.md](refactor-07-item-usage-handler.md) | Extract item usage logic |
| 08 | [refactor-08-save-serializers.md](refactor-08-save-serializers.md) | Extract domain-specific serializers |
| 09 | [refactor-09-ascii-texture-mapper.md](refactor-09-ascii-texture-mapper.md) | Separate texture mapping from rendering |

### Phase D: Major Refactoring (Higher Risk)
| Plan | File | Description |
|------|------|-------------|
| 10 | [refactor-10-player-components.md](refactor-10-player-components.md) | Decompose player.gd into components |
| 11 | [refactor-11-game-ui-coordinator.md](refactor-11-game-ui-coordinator.md) | Extract UI coordination from game.gd |
| 12 | [refactor-12-game-event-handlers.md](refactor-12-game-event-handlers.md) | Extract event handlers from game.gd |
| 13 | [refactor-13-game-rendering-orchestrator.md](refactor-13-game-rendering-orchestrator.md) | Extract rendering orchestration from game.gd |

---

## Key Files Being Refactored

| File | Current Lines | Target Lines | Reduction |
|------|--------------|--------------|-----------|
| scenes/game.gd | 3,337 | ~1,000 | 70% |
| systems/input_handler.gd | 2,569 | ~800 | 69% |
| ui/debug_command_menu.gd | 2,203 | ~800 | 64% |
| entities/player.gd | 1,970 | ~800 | 59% |
| autoload/save_manager.gd | 1,117 | ~400 | 64% |
| items/item.gd | 1,170 | ~600 | 49% |
| rendering/ascii_renderer.gd | 1,182 | ~900 | 24% |

---

## Dependencies Between Plans

```
01 JsonHelper ─────┬──> 04 Chunk Cleanup
                   └──> 08 Save Serializers

02 UI Theme ───────────> All UI file updates in later plans

03 Filter Constants ───> Independent

04-09 ─────────────────> Can be done in parallel after 01-03

10 Player Components ──> Should complete before 11-13
                    └──> Depends on 08 for serialization compatibility

11 UI Coordinator ─────> 12 Event Handlers ─────> 13 Rendering
```

---

## Verification Protocol

Each plan execution should:

1. **Before Starting**
   - Ensure on correct branch
   - Run game to verify baseline functionality
   - Run `gut` tests if available

2. **After Completing**
   - [ ] Game launches without errors
   - [ ] Feature-specific tests pass (listed in each plan)
   - [ ] Save/load cycle works
   - [ ] No new console warnings/errors

3. **Rollback if Needed**
   - Each plan should be one git commit
   - `git revert HEAD` to undo if issues found

---

## Branch Strategy

- Main branch: `refactor/v1.7-code-organization`
- Each plan can optionally have sub-branch: `refactor/v1.7-plan-XX`
- Merge to main branch after each plan is verified
