# Feature: Auto-save slot

**Goal**: Create an auto-save slot (hidden) to store the current game

---
Create an auto-save slot for the current game. Persist the current game into that slot every 25 turns. This is the checkpoint.

When the player starts the game and goes to the main menu, the auto-save slot game should be what happens when you click continue. If there is no game in the auto-save slot, continue should not appear.

Loading an existing game copies it into the auto-save slot.

If the player saves a game, the auto-save game should be set to the same as the just saved game.

If the player dies, make the top option in the list of saved games on the death screen "Restore from last checkpoint." If this is selected, restore the auto-save checkpoint file.

If the auto-save slot is cleared and there are no saved games, the continue button should not appear on the main menu. 

