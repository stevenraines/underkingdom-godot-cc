# Feature ideas to flesh out with Claude

## Version 1.1 Updates 
---
- [X] Add explicit version number to UI.
- [X] Add a release number to the game, shown on the main menu screen. This version should be auto incremented on every merge to main.
- [X] Bug Fix: Player can no longer spawn inside of buildings
- [X] UI: Added Q to Save Screen to exit to main menu with one key press.
---
## In Progress

- [/] Weapon damage types & resistances - reference https://scrollforinitiative.com/2023/08/19/a-complete-guide-to-the-13-damage-types-in-dd-part-one/ for the types to implement. Creatures should be able to have vulnerabilty, resistance, or immunity to these just like the implementation for various types of magic. Magic items always deal magic damage as their type. for examples, skeletons should have resistance to piercing weapons but vulnerability to bludgeoning weapons. Fire based creatures should be immune to fire attacks, etc.

---
## Planned

- [X] Test mode (CMD) where the player can perform actions to help debug the system (give players items, increase level, gold, spawn items, hazards, features, creatures, etc)


---
## Unplanned

- [ ] Modify mine generation 
    so that in addition to the fixed mine design, sometimes mines intersect cave systems, so overlay a portion of the mine with the cave generator for more variety. Mines should be particularly susceptible to cave in hazards
- [ ] Overworld building dungeon representation
    Modify dungeon generators so they have a layout in the overworld similar to buildings but appropriate to the shape the structure would have above ground  For instance, a fort or tower should have structure above ground. The barrow should have a crypt and be surrounded by tombstones, etc. Structures that can be above ground should have up stairs inside the structure as well as down (e.g. towers)
- [ ] Scaled Loot Drops
    Loot drops shoulds be based on the scale of the creature. Review https://dungeonmastertools.github.io/treasure.html and the related pages to improve how loot tables work to make them more realistic. Consider having separate loot tables by type/CR instead of creature, and have each creature have a list of loot_tables instead of one.
- [ ] Limit Fast Travel
    only allow fast travel to destinations that the player has been near previously, or as an option in debug-mode.
- [ ] Secret Doors
    Add secret doors to dungeons using traditional roguelike mechanics. Players should be able to detect secret doors like the detect traps.
- [ ] Fire!
    Add a fire mechanic, where wood structures can burn.  Players should also be able to throw oil and light the oil on fire. Base this feature on fire mechanics in other roguelikes.
- [ ] City: Add a new city (large town) to island.
    Include a general store, blacksmith, temple, magic shop, and multiple wells.
- [ ] Limit Trade by Trader
    NPCs only buy certain types of items
- [ ] NPC: Tanner & mechanics
    Add a tanner NPC to the city who teaches the player to turn animal hide into leather. Modify creatures that yield leather to yield hide instead.
- [ ] Rivers
    Add rivers to the game, including one near the starting town. where rivers and roads intersect, bridges should exist.
- [ ] NPC: Miller and mechanics
    Add a mill and a miller to the starting town, who can grind grains into flour. the mill must be directly adjacent to a river.
- [ ] NPC: Butcher
    Add a butcher to the city who sells different cuts of meat and buys raw meat
- [ ] NPC: Baker 
    Add a baker to the city who sells bread and baked goods and buys flour (wheat, rye, spelt) sugar, herbs, and spices
- [ ] NPC: Weaver and mechanics
    Add a weaver to the city  - can teach the player how to make cloth. Add resources the player can gather to make cloth.
- [ ] NPC: Tailor
    Add a tailor to the city  who can teach the player how to create cloth clothes
- [ ] NPC: Dyer
    Add a dyer to the city, who teaches making dyes, sells dye pot an premade dyes - player should be able to dye clothes. Use existing resources (flowers) and creatures (bugs) as sources of dyes, and add new ones. 
- [ ] NPC: Cobbler
    Add a cobbler to the city who teaches making shows and sells components and tools for shoe-making
- [ ] NPC: Brewer
    Add a brewer to the city who sells beer and teaches brewing skill
- [ ] NPC: Vintner
    Add a vintner outside of the city town who sells wine and teaches wine making & distillation
- [ ] NPCs: Wandering Traders:
    Add wandering traders who appear along roads and offer goods for sale.
- [ ] NPCs: Non-trade NPCs
    Additional non-trade NPCs (with houses, camps, etc) in the world to add color. Families, factions, etc. 
- [ ] Town layouts vary by seed
    Towns should not have fixed layouts. Layouts should be randomly generated based on the seeds
- [ ] Stealth mechanic
    Add a Stealth mechanic, based on traditional roguelikes.
- [ ] Pickpockets
    Add a Pick pockets mechanic, based on traditional roguelikes.
- [ ] NPC: Urchin
    Add an urchin to the city who will attempt to sneak up to the player / npcs and steal from them before running away and hiding. This NPC
- [ ] NPC Schedules:
    NPC's go about daily activities related to their profession. For instsance - farmers should not always be in their building. They should move about the farm. Shop keepers should close up in the middle of some days and visit other shops or perform other actions.
- [ ] Animal companions 
    Allow players to train creatures with low intelligence. Chance of failure, improved with the animal handling skill. Creatures should be loyal if maintained (fed, watered, healed.) They should fight enemies if the player is attacked. If very loyal to the player, they will fight to the death, otherwise will run away. If loyalty gets too low, the animal companion will abandon the player and will need to be retrained.
- [ ] Familiars 
    Add familiars to the game. A ritual is requird to summon them. Treat them as animal companions with bonus abilities for the player
- [ ] Extend currency
    Add a multi-tiered currency system (pp, gp, ep, sp, cp)
- [ ] Alcohol Effects
    Add alcohol effects using traditional roguelikes.
- [ ] Quests
- [ ] Hirelings
- [ ] Playable character races 
    Allow for different fantasy races (classic D&D) with different abilities
- [ ] Playable Character Classes 
    Allow the player to choose a starting character class as in traditional roguelikes with with starting skill levels and special abilities
- [ ] Character Customization Sheet
    Character Customization at game start (point assignment for scores, assigment of skill points, classes, races)
- [ ] Turn Undead
    Turn undead ability for cleric classes
- [ ] Sailing Mechanic
    Add sailing mechanic - player can board a boat at a dock
- [ ] Multiplayer implementation

- [ ] Improve Lighting Performance:
    Simplify overworld daytime lighting
    No FOV in areas except for interiors of buildings. Players should see all external building walls.
