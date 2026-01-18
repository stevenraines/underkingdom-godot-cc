# Add In-Game Skill

Workflow for adding new player skills to the game.

---

## Overview

In-game skills are abilities players can level up through use. They affect gameplay mechanics like combat, crafting, and survival.

---

## Steps

### 1. Skill Definition

Skills are defined within character classes and referenced by the skill system.

**Class skill bonuses** (in `data/classes/[class].json`):
```json
"skill_bonuses": {
  "swords": 2,
  "axes": 1,
  "light_armor": 1
}
```

### 2. Skill Categories

#### Weapon Skills
- `swords` - One-handed swords
- `axes` - Axes and hatchets
- `maces` - Bludgeoning weapons
- `spears` - Polearms
- `bows` - Ranged bows
- `crossbows` - Crossbows
- `daggers` - Knives and daggers

#### Armor Skills
- `light_armor` - Cloth, leather
- `medium_armor` - Chainmail, scale
- `heavy_armor` - Plate
- `shields` - Shield use

#### Magic Skills
- `evocation` - Damage spells
- `conjuration` - Summoning
- `abjuration` - Protection
- `transmutation` - Transformation

#### Craft Skills
- `smithing` - Metal crafting
- `leatherworking` - Leather crafting
- `alchemy` - Potion making
- `enchanting` - Magic item creation

#### Survival Skills
- `foraging` - Finding food
- `hunting` - Tracking animals
- `fishing` - Catching fish
- `mining` - Ore extraction

### 3. Skill Effects

Skills provide bonuses based on level:
- **Weapon skills**: +accuracy, +damage
- **Armor skills**: Reduced penalties
- **Magic skills**: Spell effectiveness, reduced costs
- **Craft skills**: Success chance, quality
- **Survival skills**: Yield bonuses, success rates

### 4. Skill Leveling

Skills level through use:
```gdscript
# Example: gain sword XP when attacking with sword
SkillManager.add_skill_xp(player, "swords", 10)
```

XP requirements increase per level.

### 5. Adding a New Skill

To add a new skill:

1. Add skill reference in relevant class files
2. Add skill check in relevant game systems
3. Add XP gain triggers in appropriate actions

**Example - Adding "climbing" skill:**

In class file:
```json
"skill_bonuses": {
  "climbing": 1
}
```

In movement system:
```gdscript
func _attempt_climb(player: Player) -> bool:
    var skill_level = SkillManager.get_skill_level(player, "climbing")
    var success_chance = 50 + (skill_level * 5)
    if randf() * 100 < success_chance:
        SkillManager.add_skill_xp(player, "climbing", 5)
        return true
    return false
```

---

## Verification

1. Check skill appears in character sheet
2. Verify class bonuses apply
3. Test skill XP gain on actions
4. Verify skill level affects mechanics

---

## Key Files

- `data/classes/*.json` - Class skill bonuses
- `autoload/skill_manager.gd` - Skill system
- `ui/character_sheet.gd` - Skill display (Skills tab)
- `entities/player.gd` - Player skill data
