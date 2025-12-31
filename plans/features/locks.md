# Feature - Locks
**Goal**: Certain things should be lockable, and only accessible with the propery key OR by picking the lock

---

Doors and chests should be lockable. When locked, it cannot be opened. These things should have a lock component.

Keys also exist. Keys are either specific keys for a given door or skeleton keys. 

* Locks have a unique itentifer.
* Locks have a level of difficulty associated with them and 1 or more keys specifically for that lock exist in the world.
* A lock may be unlocked/unlocked by using a key that is specifically for that lock. This requires no check.
* A lock may be unlocked/unlocked by using a skeleton key if that skeleton key's level is greater than or equal to the level of the lock.
* A lock may be opened (picked) if the player has lockpicks. This does not work every time. The player may attempt to pick the lock as long as they have lockpicks in their inventory. On success, the lock opens. On failure, the lockpick is destroyed. The chance to successfully pick the lock depends on the lock level (higher is harder), the player's level, and the player's dexterity score.
* If the player has lockpicks, they can also use them to lock an open lock. The difficulty for this is 1/2 the difficulty of picking the lock.








