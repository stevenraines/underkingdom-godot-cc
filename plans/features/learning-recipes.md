# Feature: Learning Receipes

**Goal**: Implement ways for the player to learn recipes

---

Players can craft recipes, but they have no way to learn new ones. Implement  new mechanics for this:

1. NPC Training
2. Books
3. Experimenation

1. Some NPCs should have recipes which they will sell to the character to train them. Create a new interaction screen for training. This should present the name of the recipe and what it creates but not how to make it. Once they player buys it, it becomes part of their craftable recipes. Then, make the healing potion something that the Priest in the starting town can train.

2. Create the concept of "books" in the world. Books are a way for players to gain knowledge. The first kind of knowledge will be recipes. Create the mechanic where reading a book adds a receipe to the player's crafting receipes. Then, have a book with the receipe for healing potion in the starting inventory for the shopkeeper in the main town.

3. Players can try to mix things together and see if they make something good. There already appears to be code to do this in crafting_system.gd  (attempt_experiment) but there does not appear to be any UI to support it, so lets add one.
