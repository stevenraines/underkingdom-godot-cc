# Feature: Auto-save slot

**Goal**: Create an auto-save slot (hidden) to store the current game

---

## Feature Description

Create an auto-save slot for the current game. Persist the current game into that slot every 25 turns. This is the checkpoint.

When the player starts the game and goes to the main menu, the auto-save slot game should be what happens when you click continue. If there is no game in the auto-save slot, continue should not appear.

Loading an existing game copies it into the auto-save slot.

If the player saves a game, the auto-save game should be set to the same as the just saved game.

If the player dies, make the top option in the list of saved games on the death screen "Restore from last checkpoint." If this is selected, restore the auto-save checkpoint file.

If the auto-save slot is cleared and there are no saved games, the continue button should not appear on the main menu.

---

## Implementation Plan

### Phase 1: SaveManager Auto-save Infrastructure

**Files to Modify**: [autoload/save_manager.gd](autoload/save_manager.gd)

#### Task 1.1: Add Auto-save Configuration
- Add constant `AUTOSAVE_FILE = "save_autosave.json"`
- Keep auto-save separate from numbered slots (slot 1-3)
- Add constant `AUTOSAVE_INTERVAL = 25` for turn-based auto-save frequency

#### Task 1.2: Implement Auto-save Methods
- Add `save_autosave() -> bool`
  - Similar to `save_game()` but uses `AUTOSAVE_FILE` instead of slot pattern
  - Serialize game state with metadata tag `is_autosave = true`
  - Emit `game_autosaved` signal on success
  - Return success/failure status

- Add `load_autosave() -> bool`
  - Similar to `load_game()` but reads from `AUTOSAVE_FILE`
  - Store in `pending_save_data` for deferred loading
  - Return success/failure status

- Add `has_autosave() -> bool`
  - Check if `SAVE_DIR + AUTOSAVE_FILE` exists
  - Used by main menu to show/hide continue button

- Add `get_autosave_info() -> Dictionary`
  - Return metadata from auto-save file (timestamp, character name, turn, etc.)
  - Return empty dict if no auto-save exists
  - Used by main menu for continue button tooltip/info

- Add `clear_autosave() -> void`
  - Delete auto-save file
  - Called when player explicitly deletes all saves or on new game start

#### Task 1.3: Sync Auto-save with Manual Saves
- Modify `save_game(slot: int)` to copy save to auto-save after successful save
  - After writing slot file, call `_copy_save_to_autosave(slot)`
  - Ensures manual save becomes the new checkpoint

- Modify `load_game(slot: int)` to copy loaded game to auto-save
  - After loading pending data, copy the save file to auto-save slot
  - Ensures loaded game becomes the active checkpoint

- Add helper method `_copy_save_to_autosave(slot: int) -> void`
  - Read save file from slot
  - Write same data to auto-save file
  - Update metadata to mark as auto-save

### Phase 2: TurnManager Auto-save Trigger

**Files to Modify**: [autoload/turn_manager.gd](autoload/turn_manager.gd)

#### Task 2.1: Track Turns Since Last Auto-save
- Add variable `turns_since_autosave: int = 0`
- Reset to 0 after each auto-save
- Increment on each `advance_turn()` call

#### Task 2.2: Auto-save on Turn Interval
- In `advance_turn()` method, after turn processing:
  - Increment `turns_since_autosave`
  - Check if `turns_since_autosave >= SaveManager.AUTOSAVE_INTERVAL`
  - If true, call `SaveManager.save_autosave()`
  - Reset `turns_since_autosave = 0` after successful save
  - Emit message "Game auto-saved (checkpoint)" via EventBus

#### Task 2.3: Reset Counter on Manual Save
- Listen to `EventBus.game_saved` signal
- Reset `turns_since_autosave = 0` when manual save occurs
- Prevents auto-save immediately after manual save

### Phase 3: Main Menu Continue Button

**Files to Modify**: [scenes/main_menu.gd](scenes/main_menu.gd)

#### Task 3.1: Update Continue Button Logic
- In `_ready()`, replace current continue button logic:
  - Old: Check `_get_most_recent_save_slot()` for any saves
  - New: Check `SaveManager.has_autosave()` for auto-save existence
  - Show continue button ONLY if auto-save exists
  - Hide continue button if no auto-save

#### Task 3.2: Implement Continue Action
- Modify `_on_continue_button_pressed()` (or create if doesn't exist):
  - Call `SaveManager.load_autosave()` instead of loading most recent slot
  - Transition to game scene after loading
  - Display "Loading checkpoint..." message

#### Task 3.3: Optional - Display Auto-save Info
- Add tooltip or label showing auto-save metadata
  - Character name, turn number, timestamp
  - Use `SaveManager.get_autosave_info()` to fetch data
  - Display in subtle UI element near continue button

### Phase 4: Death Screen Checkpoint Restore

**Files to Modify**: [ui/death_screen.gd](ui/death_screen.gd)

#### Task 4.1: Add Checkpoint Restore Option
- In `_populate_save_list()` or equivalent method:
  - Check if `SaveManager.has_autosave()` at start
  - If auto-save exists, create special button as FIRST option
  - Button text: "🔄 Restore from Last Checkpoint"
  - Style differently (different color, icon, or marker)

#### Task 4.2: Implement Checkpoint Restore Action
- Add handling for checkpoint restore button selection:
  - When selected and activated (Enter/Space/Click):
  - Call `SaveManager.load_autosave()`
  - Emit `load_save_requested(-1)` with special flag, OR
  - Add new signal `restore_checkpoint_requested()`
  - Hide death screen and transition to game

#### Task 4.3: Update Navigation
- Ensure checkpoint button is included in keyboard navigation
- Should be first in tab order / arrow key navigation
- Number key shortcuts: Checkpoint could be "C" or keep numbered saves 1-3

### Phase 5: Game Integration & Testing

**Files to Modify**: [scenes/game.gd](scenes/game.gd) (if needed for signal handling)

#### Task 5.1: Connect Auto-save Signals
- Ensure `EventBus.game_autosaved` signal is defined in EventBus
- Connect signal in game scene if needed for UI feedback
- Optional: Show transient "Checkpoint saved" message in message log

#### Task 5.2: Handle New Game Start
- When starting new game, call `SaveManager.clear_autosave()`
- Ensures old checkpoint doesn't interfere with new character
- Clear auto-save BEFORE starting new game initialization

#### Task 5.3: Integration Testing
Test the following scenarios:
1. **Auto-save during gameplay**
   - Start new game
   - Play for 25 turns
   - Verify auto-save file created
   - Verify message "Game auto-saved (checkpoint)" appears

2. **Continue from checkpoint**
   - Start new game, play 30 turns
   - Exit to main menu
   - Verify continue button visible
   - Click continue, verify game loads at turn 25 (last checkpoint)

3. **Manual save sync**
   - Play game, auto-save at turn 25
   - Manually save at turn 30
   - Verify auto-save updated to turn 30

4. **Load game sync**
   - Save game at turn 50 in slot 1
   - Exit to menu
   - Load slot 1
   - Verify auto-save updated to turn 50

5. **Death screen restore**
   - Play game until auto-save triggers
   - Die after checkpoint
   - Verify "Restore from Last Checkpoint" appears first
   - Select restore, verify loads checkpoint

6. **No auto-save scenarios**
   - Delete all saves and auto-save
   - Verify continue button hidden
   - Start new game, die before turn 25
   - Verify no checkpoint restore option on death screen

#### Task 5.4: Edge Case Handling
- Handle corrupted auto-save file gracefully
- Handle disk full errors during auto-save
- Ensure auto-save doesn't interrupt gameplay (quick save)
- Test auto-save during combat, inventory screens, etc.

---

## Technical Notes

### File Locations
- Auto-save file: `user://saves/save_autosave.json`
- Regular saves: `user://saves/save_slot_1.json`, `save_slot_2.json`, `save_slot_3.json`

### Signal Architecture
New EventBus signals needed:
- `game_autosaved` - Emitted after successful auto-save
- Optional: `autosave_failed` - Emitted if auto-save fails

### Data Format
Auto-save uses same format as regular saves, with additional metadata:
```json
{
  "metadata": {
    "version": "1.0.0",
    "timestamp": "...",
    "is_autosave": true,
    "slot_number": -1
  },
  "player": { ... },
  "world": { ... }
}
```

### Performance Considerations
- Auto-save should be fast (< 100ms on most systems)
- Same serialization as manual save, already optimized
- Occurs at turn boundary, won't interrupt player input
- No visual interruption needed (just message log entry)

---

## Success Criteria

- [ ] Auto-save triggers every 25 turns automatically
- [ ] Continue button appears when auto-save exists
- [ ] Continue button loads auto-save checkpoint
- [ ] Manual save updates auto-save to match
- [ ] Loading a game updates auto-save to match
- [ ] Death screen shows checkpoint restore option when available
- [ ] Checkpoint restore loads auto-save
- [ ] New game clears old auto-save
- [ ] No auto-save = no continue button
- [ ] All edge cases handled gracefully

---

**Status**: Planning Complete
**Branch**: feature/auto-save-slot
**Estimated Complexity**: Medium (5 files, ~200 lines of code)
**Dependencies**: SaveManager, TurnManager, MainMenu, DeathScreen, EventBus
