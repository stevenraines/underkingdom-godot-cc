# Feature - Preferred Harvesting Tool
**Goal**: Some tools are more efficent at harvesting resources than others and produce more bountiful returns in less time.

---

Resources have a required tools attribute, like this:

"required_tools" : ["axe", "flint_knife", "iron_knife"],

However some tools are better at harvesting a given type of resource. For instance, an ace is better at harvesting a tree than a knife is.

Change the system so that each type of required tool can be assigned two properties: the reduction in the number of times the harvest action needs to be taken to get the drop (see multi-turn-harvesting.md for this feature) and the change in the quantity dropped.

For instance, assume a tree yields 2-4 wood normally and it takes 5 harvest actions to get the drop. 

The resource could be configured so the required tool "axe" have an action reduction of 2, meaning only 3 harvest actions are required to get the drop. Similarly, it could have a drop bonus of 2, automatically adding 2 to the randomly generated number of dropped items (2-4) becomes (2-4)+2.
