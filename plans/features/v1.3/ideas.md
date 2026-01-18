# Feature ideas to flesh out with Claude

## Version 1.3 Updates 
---
- [x] Bug: Can't cook or eat fish
- [x] Bug: Debug mode does not allow spawning templated items
- [x] Feature: Extend day hours to be longer than night
    Daytime should last longer than night. 
- [ ] Feature: Sprint
    The player may invoke a "Sprint" mode, which allows the player to move (and only move) twice before creatures take their turn. Taking any action other than moving turns off sprint mode. Sprint mode on/off should be shown in the bottom of the UI. Moving in sprint mode drains stamina at 4x the normal rate.
- [ ] Feature: Default Harvest Interaction
    If the player runs into a harvestable item and has an appropriate item to harvest it equipped (e.g. Axe for a tree) OR has the required item in inventory (like filling a waterskin) turn on auto harvest and start the harvesting process.
- [x] Content: Increase Overworld Creature Count
    There is a very low frequency of game animals and enemies in the overworld. Increase these.
- [x] Content: Renamed "Potato Seeds" to "Seed Potatoes"
- [x] Content: Mage Starting Equipment
    Mages should start with a spellbook that contains the spells "light", "magic missile", and "create water".
- [x] UI/UX: Spellbook shows damage
    The spellbook should show the range of values for combat spells and healing spells.
- [/] UI/UX: Wells should be more pronounced
    The well icon is hard to see. We need some way for it to be more pronounced and obvious to the user.
- [x] Tech: Improve Lighting Performance:
    Simplify overworld daytime lighting
    No FOV in areas except for interiors of buildings. 
- [x] Tech: Reduce context usage with agents/skills
    Review the CLAUDE.MD file and propose migrating sections to AGENTS files or SKILLS to reduce context usage.
- [ ] UI/UX: Update notice
    Store the current version of the game in storage when a player plays. The next time the game is loaded in the browser, see if the current version is newer than the last saved version. If so, put a message on the menu screen above the Continue button that says "New Updates Available" and provide a link to [https://github.com/stevenraines/underkingdom-godot-cc/releases/tag/v{version number}](https://github.com/stevenraines/underkingdom-godot-cc/releases/)

    