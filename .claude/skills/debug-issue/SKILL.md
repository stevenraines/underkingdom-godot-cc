# Debug Issue Skill

Root-cause analysis workflow for debugging user-reported issues. Prioritizes understanding the problem deeply over applying quick patches.

---

## CRITICAL RULES

1. **NO PREMATURE FIXES** - Do not modify any code until the root cause is identified, confirmed, and presented to the user. Resist the urge to patch symptoms.
2. **UNDERSTAND BEFORE CHANGING** - Read all relevant code paths end-to-end before proposing a fix. A surface-level read is not enough.
3. **FIND THE ROOT CAUSE** - Every bug has a root cause. Find it. Do not stop at the first thing that "looks wrong." Some bugs have multiple contributing causes - identify all of them.
4. **PRESENT BEFORE FIXING** - After completing Phase 3, you MUST stop and present your analysis to the user. Do NOT proceed to Phase 4 until the user confirms the root cause and approves the fix approach. This is a hard gate.
5. **VERIFY THE FIX MATCHES THE CAUSE** - The fix must directly address the identified root cause, not work around it.

---

## Workflow

Use TodoWrite to track investigation progress throughout. Create tasks for each phase and mark them as you go, so the user has visibility into what has been checked and what remains.

### Phase 1: Reproduce and Characterize

Before touching any code, establish the facts.

**1. Gather the Bug Report**

Extract these details from the user (ask if missing):

- **What happened?** - The observed (incorrect) behavior
- **What was expected?** - The correct behavior
- **Steps to reproduce** - Exact sequence of actions
- **Frequency** - Always, sometimes, or one-time?
- **Context** - When did it start? After a specific change? On a specific map/item/entity?
- **Error output** - Any error messages, stack traces, or Godot console output?

**2. Parse Error Output First**

If the user provides an error message or stack trace, extract the information before doing anything else:

- **File and line number** - Godot errors like "Invalid get index on base Nil" include the exact location
- **Error type** - Null reference, type mismatch, missing method, parse error, etc.
- **Call stack** - Which functions were in the call chain when it failed?

This is often the fastest path to the bug. Start your trace from here.

**3. Classify the Bug**

Determine which category the issue falls into:

| Category | Symptoms | Likely Systems |
|----------|----------|----------------|
| **Data** | Wrong values, missing items/enemies, JSON parse errors | `data/` JSON files, ItemManager, EntityManager, VariantManager |
| **Logic** | Wrong behavior, incorrect calculations, state corruption | Systems in `systems/`, entity scripts in `entities/` |
| **Signal** | Events not firing, duplicate events, wrong order | EventBus, signal connections in managers |
| **Rendering** | Wrong display, missing tiles, UI glitches | ASCIIRenderer, `rendering/`, `ui/` scripts |
| **State** | Save/load issues, stale references, turn desync | SaveManager, TurnManager, GameManager |
| **Input** | Keys not working, wrong mode, action not triggered | InputModeManager, input handler scripts in `systems/input/` |
| **Generation** | Bad maps, unreachable areas, wrong spawns | `generation/` scripts, MapManager, DungeonManager |

**4. Identify the Blast Radius**

Before investigating, map out which systems are involved:

- What is the **entry point**? (user action, signal, turn event)
- What is the **expected call chain**? (which functions should execute, in what order)
- What is the **output point**? (what the player sees or what state changes)

---

### Phase 2: Trace the Execution Path

Read code methodically. Do not skip steps.

**5. Check Recent Changes**

If the bug is a regression ("it used to work"), check what changed:

```bash
git log --oneline -20          # Recent commits
git diff HEAD~5                # What changed in the last 5 commits
git log --oneline -- <file>    # History of a specific suspect file
git blame <file>               # Who changed each line and when
```

This narrows the search space dramatically. If a specific commit introduced the bug, the fix is often in the same diff.

**6. Trace Forward from the Entry Point**

Starting from the user action or trigger event, read each function in the call chain:

```
User Action → Input Handler → System Method → Manager → State Change → Render Update
```

For each function in the chain:
- Read the full function body (do not skim)
- Note all conditional branches - which path does the bug scenario take?
- Note all signal emissions - what downstream effects are triggered?
- Note all early returns - could the function be exiting before the expected logic runs?

**7. Trace Backward from the Symptom**

Starting from where the wrong behavior is visible, work backward:

- What function directly produces the wrong output?
- What data does that function receive? Is it correct?
- Where does that data come from? Trace one level up.
- Repeat until you find where correct data becomes incorrect.

**8. Check the Data Path**

For data-driven issues, verify the full chain:

```
JSON File → Manager._ready() load → Dictionary lookup → Runtime usage
```

- Is the JSON valid and well-formed?
- Does the manager load the file? (check the directory scan in `_ready()`)
- Is the dictionary key correct? (check for typos, case sensitivity)
- Is the runtime code using the right key to look up the data?

---

### Phase 3: Identify the Root Cause

**9. Formulate a Hypothesis**

Based on tracing, state the root cause clearly:

> "The bug occurs because [specific function] in [specific file] does [specific wrong thing] when [specific condition], which causes [observed symptom]."

This must be a single, specific statement - not "something is wrong with X system."

**10. Validate the Hypothesis**

Before presenting to the user, confirm the hypothesis by checking:

- [ ] Does the hypothesis explain ALL reported symptoms?
- [ ] Does the hypothesis explain the frequency? (always vs sometimes)
- [ ] Does the hypothesis explain the timing? (when did it start?)
- [ ] Is there any contradicting evidence?
- [ ] Could this be a symptom of a deeper issue?

If the hypothesis fails any check, return to Phase 2 and continue tracing.

**11. STOP - Present Findings to the User**

**This is a mandatory gate. Do not proceed to Phase 4 without user confirmation.**

Present your analysis using the Reporting Template (see below). Include:
- The root cause hypothesis
- The evidence that supports it
- What was investigated and ruled out
- Your proposed fix approach

Wait for the user to confirm before writing any code. The user may have additional context that changes the analysis, or may prefer a different fix approach.

**If the investigation is inconclusive**, say so honestly. Present:
- What was investigated and what was found
- What was ruled out and why
- What remains uncertain
- What additional context from the user would help narrow it down

Do NOT guess or propose a speculative fix when the root cause is unclear. Ask for more information instead.

---

### Phase 4: Fix and Verify

Only proceed after the user has confirmed the root cause and approved the fix approach.

**12. Design the Fix**

The fix must:
- Address the root cause directly, not work around the symptom
- Be minimal - change only what is necessary
- Follow existing code patterns (see CLAUDE.md)
- Not introduce new problems in adjacent systems

**13. Implement the Fix**

Apply the fix. For each file changed:
- State what is being changed and why
- Reference the root cause identified in step 9
- Use `preload()` for any new cross-script references (CLAUDE.md mandate)
- Use `UITheme` for any color constants (CLAUDE.md mandate)

**14. Verify the Fix**

Use the debug-test skill's testing checklists and debug commands for verification. Confirm:

- [ ] The original bug is resolved
- [ ] The fix addresses the root cause, not just the symptom
- [ ] No new issues are introduced in related systems
- [ ] Edge cases are handled
- [ ] Signal connections are correct if modified

See `debug-test` skill for debug mode commands, signal watchers, and category-specific testing checklists.

---

## Common Root Cause Patterns

### Pattern: Stale Reference After Map Transition
**Symptom**: Crash or wrong behavior after entering/leaving a dungeon or changing maps.
**Root cause**: A system holds a reference to an entity or map object that was freed during transition.
**Where to look**: MapManager, EntityManager, any system caching entity references.

### Pattern: Signal Connected Multiple Times
**Symptom**: An action happens twice, or effects are doubled.
**Root cause**: A signal connection is made in a function that runs more than once without disconnecting first.
**Where to look**: `_ready()` functions, `connect()` calls without `is_connected()` guards.

### Pattern: Dictionary Key Mismatch
**Symptom**: Item/enemy/spell not found, or wrong one returned.
**Root cause**: The key used to store a definition differs from the key used to look it up (typo, case mismatch, underscore vs hyphen).
**Where to look**: JSON `id` fields, manager dictionary keys, lookup function arguments.

### Pattern: Turn Order Dependency
**Symptom**: Intermittent wrong behavior that depends on entity processing order.
**Root cause**: Logic assumes a specific execution order within a turn, but entity processing order is not guaranteed.
**Where to look**: TurnManager, EntityManager.process_turns(), systems that read shared state.

### Pattern: Null Value From Missing Initialization
**Symptom**: Crash with "Invalid get index on base Nil" or similar.
**Root cause**: A value that should be initialized is not - an unequipped slot, an unset reference, a missing dictionary entry. The null itself is the bug; something upstream failed to set the value.
**Where to look**: The exact line in the error, then trace where the null value originates. The fix is to ensure proper initialization, NOT to add a null check that suppresses the crash (see Anti-Patterns).
**Important distinction**: This is different from a legitimate boundary guard. If a value CAN be absent by design (e.g., an optional equipment slot, a tile with no entity), then a null check is the correct handling - not an anti-pattern. The question to ask: "Is this null a bug or an expected state?"

### Pattern: JSON Data Not Loading
**Symptom**: Feature works in code but data is missing at runtime.
**Root cause**: New JSON file is in wrong directory, has syntax error, or manager doesn't scan the subdirectory.
**Where to look**: `data/` directory structure, manager `_ready()` load functions, Godot output console for parse errors.

### Pattern: Input Mode Conflict
**Symptom**: Key press does nothing or triggers wrong action.
**Root cause**: InputModeManager is in a different mode than expected, or mode handler doesn't cover the key.
**Where to look**: `systems/input/input_mode_manager.gd`, mode-specific handlers in `systems/input/`.

### Pattern: Preload vs class_name
**Symptom**: "Identifier not found" or method not recognized at runtime.
**Root cause**: Script references another class by `class_name` instead of using `preload()` (violates CLAUDE.md mandate).
**Where to look**: Top of the script file - verify `const XClass = preload(...)` exists for all cross-script references.

---

## Anti-Patterns to Avoid

These are NOT acceptable fixes **for internal logic bugs**. If you find yourself writing one to fix a bug, you have likely not found the root cause.

**Exception**: Defensive checks ARE appropriate at system boundaries - validating user input, handling optional/nullable fields that are absent by design, or guarding against legitimately asynchronous entity lifecycle (e.g., an entity dying mid-turn while other systems still process). The question is always: "Am I fixing the cause, or hiding it?"

| Anti-Pattern | Why It's Wrong | What to Do Instead |
|---|---|---|
| Adding a null check to suppress a crash | Hides the real problem - why is it null? | Find why the value is null and fix the source |
| Adding a `try`/`catch` or silent fallback | Swallows errors, makes future bugs harder to find | Fix the condition that causes the error |
| Duplicating logic to "make sure it runs" | Creates maintenance burden, masks ordering bug | Fix the execution order or signal chain |
| Adding a timer/delay to "wait for it to load" | Race condition still exists, just less likely | Fix the initialization order or use signals |
| Scattering `is_instance_valid()` broadly | Band-aid for dangling references | Fix the lifecycle - ensure cleanup happens correctly |

---

## Reporting Template

When presenting findings to the user (at the mandatory Phase 3 gate), use this structure:

```
## Bug Analysis

**Reported Issue**: <one-line summary of what the user reported>

**Root Cause**: <specific explanation of why the bug occurs>

**Affected File(s)**: <file:line references>

**Call Chain**: <entry point → ... → point of failure>

**Evidence**:
- <what was observed that confirms this root cause>
- <specific code references that demonstrate the issue>

**Investigated and Ruled Out**:
- <alternative hypothesis 1> - ruled out because <reason>
- <alternative hypothesis 2> - ruled out because <reason>

**Proposed Fix**: <what will be changed and why this addresses the root cause>

**Risk Assessment**: <what else could be affected by this fix>
```

---

## Key Files

- `autoload/event_bus.gd` - Signal definitions (check connections here first)
- `autoload/game_manager.gd` - Game state, debug mode flag
- `autoload/turn_manager.gd` - Turn loop, day/night cycle
- `autoload/map_manager.gd` - Map transitions, caching
- `autoload/entity_manager.gd` - Entity lifecycle, turn processing
- `autoload/item_manager.gd` - Item loading, lookup
- `systems/input/input_mode_manager.gd` - Input mode state machine
- `rendering/ascii_renderer.gd` - Visual rendering
- `ui/debug_command_menu.gd` - Debug commands for testing

## Related Skills

- **debug-test** - Use for debug mode commands, signal watchers, and testing checklists during Phase 4 verification
