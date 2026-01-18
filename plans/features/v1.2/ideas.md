# Feature ideas to flesh out with Claude

## Version 1.2 Updates 
---
- [x] Feature: Playable Character Races 
    Allow for different fantasy races (classic D&D) with different abilities
- [x] Feature: Racial Traits (K key)
    Races have passive and active racial traits that give them special abilities.
- [x] Feature: Playable Character Classes 
    Allow the player to choose a starting character class as in traditional roguelikes with with starting skill levels and special abilities. Allow a random choice that auto-chooses for the player and a non-classed "Adventurer" who gets no bonuses at start but has no class restrictions
- [x] Feature: Class Restrictions
    Some classes have restrictions (spell casting not allowed, spells can't be cast in heavy armor, etc.)
- [x] Feature: Feats (K key)
    Character classes come with active and passive classed-based feats that give them special abilities.
- [ ] Feature: Character Customization Sheet
    Character Customization at game start after tace and class selection (point assignment for scores, assigment of skill points, etc)
- [x] Feature: Test mode Expansion
    Implement the following improvements to the Debug Mode:
    * For all the selection lists of hazards, spells, receipes, etc,  in the debug section, if the thing being listed has a level of some kind, sort by that first. Then sort alphabetically.
    * Add options to spawn structures, crops, and resources
    * Add option to convert a tile to another tile (select new tile, select direction, select distance)
    * Add option to learn rituals
- [x] Feature: Make easily collected resources into features
    Made flowers, herbs, and mushrooms collectable by walking over them. These are not collected if auto-pickup is off
- [x] UI/UX: Rename Character sheet Weather tab to Environment as it contains dates 
- [x] Feature: H is for pickup
    When auto-pickup is turned off, standing on an item and pressing H (harvest) will pick up the item.
- [x] Feature: Creature Types
    Classify all creature with types (goblinoid, undead, humanoid,beast,slime, etc.) Add these to the display in Debug mode for each creature in the list (for filtering). We previously implemented damage types & resistances at the creature level. Also add the ability to configure resistences at the creature type level. For example, all creatures of type Elemental - Fire should be immune to fire damage.
- [x] UI: Resistance / Vulnerability cues
    When a creature has immunity or resistance to an attack or action, the log should indicate a cue to the player, like "Your axe seems to do less damage that usual."
