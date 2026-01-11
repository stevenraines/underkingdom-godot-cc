# Feature: Leveling

**Goal**: As players gather experience, they should advance in level, giving them new skills, improving abilities, and extra capabilities.

---
Player start at level 0.
There is no maximum level
Players gain experience for performing actions (already implemented)
When the experience reaches a certain level, the player's level increases by 1. 
The formula for the number of experience points needed to advance to the next level is the sum of the priot two levels. The player advances the first time their xp meets or exceeds the value needed. It does not need to be the exact number.

*See the examples below:*
Level: Xp needed to reach it
0: 0xp
1 : 100xp
2 : 200xp
3 : 300xp
4 : 500xp
5 : 800xp
6 : 1300xp
etc.

At each level the player gets a number of skill points (new concept) to spend on skills (see below) The number of skill points will be 1/3 of the current level rounded to the next whole number. 

*See the examples below:*
Level reached : Skill points earned.
Level: 1 (1/3, rounded to 1)
Level: 2 (2/3, rounded to 1)
Level: 3 (3/3, rounded to 1)
Level: 4 (4/3, rounded to 2)
Level: 5 (5/3, rounded to 2)
Level: 6 (6/3, rounded to 2)

Every 4th level, the player get the chance to raise 1 ability score by 1 point.

Build the system, and then update the UI as follows:
The HUD should show current level next to experience.
Experience should be shown as {current experience} / {experience to reach next level}
The Character screen should display level above experience

Add the Availble Skill points value to the player. This is the number they have to spend.

Create a second tab on the Character Screen for skills.
Display the available skill points.
Add a place on the character to store the player's number of skill points assigned.  The player should start with a 0 score in each of these.

List each of the following skills on the screeen (in alphabetical order) - later we will implement the actions they improve (listed after the - here for reference)

Sleight of Hand - pick locks, pick-pockets
Stealth - hide, move silently
Arcana - ability to recognize potions, scrolls, magic item effects (which are hidden by default)
Investigation - find secret doors and traps when investigating
Medicine - improves healing skills (bonuses to healing checks, crafting healing items, and the amount of healing that happens)
Perception - identify hazards when 
Survival - improves harvesting
Persuasion - improves chance of haggling (lower price of items), improves the chance NPCs will like the player 
Crafting - improves the player's chance to craft items and the quality of items produced.



Implement the screen to select skills to assign points to and choose the ability score to increase, at the time that a level is earned.
