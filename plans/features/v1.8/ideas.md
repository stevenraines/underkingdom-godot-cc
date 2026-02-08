## Version 1.8 Updates 
---

- [X] Add more sources of fresh water
    Add additional sources of water to the underworld, like  "Barrel" and "Cistern". In the overworld, add periodic "Spring" spots. All should act like wells. Dungeons should also have a source of water at least every 5 levels.
- [X] Auto Assign Ability Scores at Character Creation, by Class.
    When a new character is created, auto-assign the ability scores based on the class the character chose, applying the highest scores the the abilities commonly associated with that class. Player should still be able to unassign/reassign.
- [X] Force race/class selection. 
    Remove the "Random" option from Character creation Class and Race screens. Instead, make Human the default race (the first one at the top) and Adventurer the default class.
- [X] Items that can be weapons don't appear as weapons
    The Short Bow and Iron Hatchet do not appear in the inventory when the "weapons" filter is applied. Short bow definitely should be and the hatchet acts as a weapon in addition to a tool. Neither of these trigger the "Combat" Player Character Screen to Weapon - it shows as Unarmed.
- [X] Main Menu "Quit" option not valid in web deploy
    When deployed via the HTML export, the "Quit" option on the main menu does nothing. Modify the main menu to hide this option when deployed via the HTML Export.
- [X] Hide Cursed status of Items until used or worn
    Cursed items should never show that they are cursed until used / worn. Cursed items that are worn should not be able to be removed without a Remove Curse spell being cast. Priests should be able to train a player to cast this spell.