# Feature - Ranged Weapon Combat
**Goal**: Add mechanics for ranged weapon combat

---

The player (and some enemies) should be able to use ranged weapons in combat. These would be things like bows, crossbows, and slings,but also thrown objects like rocks or knives. 

Create a system that supports ranged combat, including target selection (since the target may not be next to the character and there may be more than one), support for ammunition (arrows, bots, sling stones, etc) and also for thrown items (a thrown knife is removed from inventory)

Different weapons will have different ranges. Long bows go farther than short bows. Thrown item distance depends on the strength of the character.

There should be a percentage chance that ammunition can be recovered after use. For a hit, the ammunition should become part of the creature's drop when killed. For misses, recoverable items should appear in the general direction of the target at the distance of its range OR when it contacts a wall or other blocking object, whichever is closer.