## Version 1.6 Updates 
---

- [X] "Fresh Water" not recognized when crafting because it is contained in a container(#105)
    Fixed: Added `provides_ingredient` property to items. Full Waterskin now provides fresh_water for crafting and transforms to Empty Waterskin when used.
- [X] Healing Salve receipe can't be created (#101)
    Fixed: The crafting screen now displays seeded ingredients (world-seed-based dynamic herb requirements). The recipe was working correctly but the UI wasn't showing the required herbs.
- [X] Player blocked by stone floor bug (#103)
    A player can receive an error message that they are blocked by a stone floor. A stone floor tile appears where the player is trying to move. This may be caused by the spawn location of an enemy that was defeated in combat, or maybe because something is actually there but not being rendered properly and defaulting to the floor as the name of that thing.
- [X] Some overworld drops cannot be picked up (#102)
    After defeating opponents in combat, player was unable to pick up loot drops. Possibly because of encumberance, which did not show a message. Added messaging and logging if this happens again.

