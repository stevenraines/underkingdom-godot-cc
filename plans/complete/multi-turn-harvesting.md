# Feature - Multi-turn Harvesting
**Goal**: Some resources may take more than one action to harvest.

---

Currently, a resource is harvested by taking the "Harvest" action on the resource. However, this does not make sense for some resources. For instance, it should take more than one swing of an axe to fell a tree.

Modify resources to have a property that indicates the number of "harvest" actions are required to get the harvest drop. If the property is not defined, use 1.

For any resource with a value > 1, make sure the player performs the harvest action that number of times before the drop occurs.


