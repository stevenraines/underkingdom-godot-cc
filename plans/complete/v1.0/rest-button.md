# Feature - Rest button
**Goal**: Implement a feature to allow the player to rest (wait) for a given number of turns, or until a specific event.

---

Add a new button that allows a player to rest. When the button is pressed, the player is presented with the following options for how long to wait:
1. Until fully rested
2. Until {next time of day}
3. X turns

1. causes the player to rest until stamina is fully restored
2. lists whatever the next time of day would be in the day cycle (for Dawn, day. For the first day, noon, for the second day, dusk, for night, dawn) etc.
3. Gives focus to a text box that allows the user to enter a specific number of turns to wait.


If any events happen (any thing that would be written to the message log) the waiting should stop.
