# Feature ideas to flesh out with Claude

## Version 1.3 Updates 
---

---
## Unplanned
- [ ] Feature: Tree Variety
    Support different kinds of trees (e.g. oak, yew, maple, alder, pine, fir, apple, cherry, pear, willow, magnolia, mangrove, olive, almond, spruce) The types of trees should vary by biome / elevation. Use the variant mechanic to define tree types. Trees should grow in clusters - but the occasional other tree may grow in a group. Some trees bear fruit. The fruit should be harvestable as a renewable resource seasonally. Some trees are also flowering (magnolia) and flowers should be harvestable like fruit. The player should still have the option to cut down the tree and receive wood of the tree type.
- [ ] Feature: Sprint
    The player may invoke a "Sprint" mode, which allows the player to move (and only move) twice before creatures take their turn. Taking any action other than moving turns off sprint mode. Sprint mode on/off should be shown in the bottom of the UI. Moving in sprint mode drains stamina at 4x the normal rate.
- [ ] Tech: Reduce context usage with agents/skills
    Review the CLAUDE.MD file and propose migrating sections to AGENTS files or SKILLS to reduce context usage.
- [ ] Weapon and Armor Proficiency
    Players should be able to use any weapon, but if they are not trained in int they should have a -2 penalty to hit. All characters should be trained to use basic bludgeoning weapons (clubs, staves), slings, knives, and axes. But Swords, two-handed axes, bows, crossbows, require proficency (by the type or classification.) Similarly, wearing clothing or leather armor can be done by anyone but once more advanced armor (including a shield) is involved, the player mus tbe proficent (medium armor, heavy armor, shield) there should be a -2 penalty. Implement both of these by extending restrictions system designed for character classes.
- [ ] Enemy traits
    Some creatures should have special abilities like the racial traits / feats players have - trolls have regenreation, dragons breath fire, etc. Implement a system to support special abilities that can be defined through data configuration
- [ ] Allow enemies to use ranged weapons and spells.
    Humanoid creatures should be able to use ranged weapons like bows and slings to attach players. Spell casting creatures (mages, demons, etc) should also be able to cast spells on players to hurt or hinder them. For instance, in addition to the combat spells, a wizard of sufficent level should be able to cast a Slow spell on the player that causes the player to only be able to act once every 2 turns until the spell ends or the player makes a successful save.
- [ ] Creature interaction
    Creatures in the world should interact with other creatures. For example, a deserter in the woods meets a wolf - they should interact in the same way with each other that either would with the player. 
- [ ] Allies
    Creatures should be able to allied with other creatures, For instance a pack of 3 goblins and 1 hobgoblin could be allies, working together against one or more "enemies". Spell casting creatures who are allies should be able to heal and buff their allies in addition to hurting enemies.
- [ ] Magic Item: Scroll of Recall
    Add a consumable item used to instantly teleport a character to a safe location (nearest town), allowing for emergency escapes. This should work even if the player is in a dungeon
- [ ] Caves in Mines
    Change mine generation so that in addition to the fixed mine design, sometimes mines intersect cave systems, so overlay a portion of the mine with the cave generator for more variety. Mines should be particularly susceptible to cave in hazards
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
- [ ] Craft: Fisherman, tailor, or weaver can teach receipe for cord.
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
- [ ] Some spells require components
    Come spells may have required components. Without these components in inventory the spell cannot be cast. If the player has the components and casts the spell, the components are consumed and removed from the player's inventory. This occurs regardless of whether the spell succeeds or fails.
- [ ] Quests
- [ ] Hirelings
- [ ] Turn Undead
    Turn undead ability for cleric classes, using traditional roguelike patterns
- [ ] Sailing Mechanic
    Add sailing mechanic - player can board a boat at a dock
- [ ] Luck Mechanic
    Add a mechanic that gives the player a luck score that builds up overtime and is spent when the player is in imminent peril
- [ ] Action Point Mechanic
    Add an action point system, where the players earn action points that can be spent to roll back the last action (and its consequences) or re-roll a die
 - [ ] Advantage Mechanic
    Add an advantage system, where the players can have advantage over an enemy (if the creature is between the player and an ally, disabled via a condition, etc) and 2 d20 rolls are made on attack or casting a spell targeted at the creature. The higher of the two is used. There should be some indication in the targeted enemy text at the bottom that the player has advantage. Similalry, monsters should be able to have advantage of the player / npcs / familiars. The player should get a message in the log when a creature gains advantage over them.
- [ ] Add Racial Variants
    Allow players to select racial variants for races that have them (Dark Elf, Wood Elf, High Elf, etc.)
- [ ] Improve Lighting Performance:
    Simplify overworld daytime lighting
    No FOV in areas except for interiors of buildings. Players should see all external building walls.

- [ ] Multiplayer implementation