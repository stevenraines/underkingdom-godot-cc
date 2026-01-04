# Feature: Room Descriptions for Dungeons

**Goal**: Generate thematic, atmospheric descriptions for dungeon rooms that enhance immersion and provide gameplay hints. Inspired by the [donjon 5-Room Dungeon Generator](https://donjon.bin.sh/fantasy/5_room/) and [Johnn Four's 5-Room Dungeon methodology](https://www.roleplayingtips.com/5-room-dungeons/).

---

## Overview

Currently, dungeon rooms are generated as geometric shapes without identity or atmosphere. This feature adds:

1. **Room Purpose Classification** - Categorize rooms by narrative function (entrance, challenge, setback, climax, reward)
2. **Room Type Classification** - Categorize rooms by physical type (crypt, armory, ritual chamber, etc.)
3. **Dynamic Descriptions** - Generate atmospheric text from extensive template pools
4. **Content-Aware Details** - Hint at features, hazards, enemies through description
5. **Discovery Moments** - Display room description when player first enters

---

## Current State

### What Exists
- Rectangular and BSP room generators create rooms with position/size
- Dungeon definitions have `special_rooms` config (not implemented)
- Feature and hazard placement is random, not room-aware
- No room identity persists after generation

### What's Missing
- Room bounds not stored in map metadata
- No room type or purpose assignment
- No description generation system
- No "player entered room" detection

---

## Configuration Architecture

The description system uses a layered configuration approach for maximum variety and extensibility.

### Layer 1: Core Description Components (`data/room_descriptions/components/`)

Shared building blocks used across all dungeons.

```json
// data/room_descriptions/components/adjectives.json
{
    "atmosphere": {
        "dark": ["shadowy", "dim", "gloomy", "murky", "lightless", "pitch-black"],
        "old": ["ancient", "aged", "weathered", "crumbling", "time-worn", "decrepit"],
        "cold": ["frigid", "chilly", "freezing", "icy", "bone-cold", "frosty"],
        "damp": ["wet", "dripping", "sodden", "moist", "humid", "waterlogged"],
        "quiet": ["silent", "hushed", "still", "soundless", "muted", "deathly quiet"],
        "foul": ["putrid", "rotting", "fetid", "stinking", "rank", "nauseating"],
        "eerie": ["unsettling", "uncanny", "haunting", "disturbing", "ominous", "foreboding"]
    },
    "size": {
        "large": ["vast", "cavernous", "sprawling", "expansive", "immense", "enormous"],
        "small": ["cramped", "narrow", "confined", "tight", "claustrophobic", "compact"],
        "tall": ["towering", "lofty", "high-ceilinged", "vaulted", "soaring"]
    },
    "condition": {
        "ruined": ["collapsed", "shattered", "destroyed", "wrecked", "demolished"],
        "intact": ["preserved", "untouched", "pristine", "maintained", "undamaged"],
        "abandoned": ["deserted", "forsaken", "neglected", "empty", "desolate"]
    }
}
```

```json
// data/room_descriptions/components/architectural_features.json
{
    "walls": [
        "Rough-hewn stone walls bear the marks of ancient tools.",
        "Smooth marble walls reflect your light.",
        "Cracked brick walls ooze moisture.",
        "Carved reliefs depicting forgotten battles line the walls.",
        "Faded murals cover the water-stained walls.",
        "Iron sconces, long empty of torches, line the walls.",
        "Thick cobwebs drape between wall sconces.",
        "Deep scratches mar the stonework at regular intervals."
    ],
    "floors": [
        "The flagstone floor is worn smooth by countless footsteps.",
        "Cracked tiles create an uneven walking surface.",
        "A thick layer of dust covers the floor.",
        "Dark stains mark the floor in irregular patterns.",
        "The floor slopes slightly toward a central drain.",
        "Bones crunch underfoot.",
        "Shattered pottery litters the floor.",
        "Debris from a partial collapse covers one corner."
    ],
    "ceilings": [
        "The vaulted ceiling disappears into shadow.",
        "Stalactites hang from the low ceiling.",
        "A collapsed section reveals rough earth above.",
        "Carved faces stare down from the ceiling.",
        "Chains dangle from hooks embedded in the ceiling.",
        "The ceiling bears scorch marks from ancient fires.",
        "Roots have broken through cracks in the ceiling.",
        "Water drips from somewhere above."
    ],
    "doors": [
        "A heavy iron door blocks further passage.",
        "Splintered remains of a wooden door hang from rusted hinges.",
        "An ornate archway leads deeper.",
        "A portcullis has been jammed halfway open.",
        "Multiple passages branch from this chamber."
    ],
    "lighting": [
        "Phosphorescent fungi provide dim illumination.",
        "A shaft of light falls from a crack above.",
        "Strange runes pulse with faint light.",
        "Your torchlight barely penetrates the darkness.",
        "Braziers of ever-burning flame flank the entrance.",
        "Complete darkness swallows everything beyond your light."
    ]
}
```

```json
// data/room_descriptions/components/sensory_details.json
{
    "sounds": [
        "Distant dripping echoes through the chamber.",
        "An unsettling silence presses against your ears.",
        "Faint scratching sounds come from the walls.",
        "The wind moans through hidden passages.",
        "Something shuffles in the darkness ahead.",
        "Your footsteps echo unnaturally loud.",
        "A rhythmic thumping pulses from below.",
        "Whispered voices seem to come from everywhere and nowhere."
    ],
    "smells": [
        "The air reeks of decay.",
        "A musty, closed-in smell fills your nostrils.",
        "The tang of old blood lingers here.",
        "Sulfurous fumes burn your throat.",
        "An earthy, mineral scent pervades the area.",
        "Sweet incense masks something fouler beneath.",
        "The air smells of dust and forgotten years.",
        "A sharp chemical odor stings your eyes."
    ],
    "temperatures": [
        "Cold seeps into your bones.",
        "Unnatural warmth radiates from the walls.",
        "The air is thick and humid.",
        "A chill draft raises goosebumps on your skin.",
        "The temperature drops noticeably here.",
        "Stifling heat makes breathing difficult."
    ],
    "textures": [
        "The walls are slick with moisture.",
        "Fine dust coats every surface.",
        "The stone feels unnaturally smooth.",
        "Thick moss cushions your footsteps.",
        "Sticky webs brush against your face.",
        "The floor crunches with each step."
    ]
}
```

```json
// data/room_descriptions/components/contents.json
{
    "furnishings": {
        "storage": [
            "Empty shelves line one wall.",
            "Overturned crates spill their contents across the floor.",
            "A row of sealed urns stands against the wall.",
            "Broken barrels leak their contents into a dark pool.",
            "Weapon racks stand empty, dust outlining where arms once hung."
        ],
        "seating": [
            "A stone throne dominates one end of the chamber.",
            "Rotting benches face a raised platform.",
            "Chains and manacles hang from a stone chair.",
            "Cushions of decayed fabric surround a low table."
        ],
        "tables": [
            "A long stone table bears ancient stains.",
            "A workbench covered in rusted tools fills one corner.",
            "An altar-like slab dominates the center.",
            "Shattered remains of furniture are piled in one corner."
        ]
    },
    "remains": {
        "skeletal": [
            "Bones are scattered across the floor.",
            "A skeleton slumps against the wall, still clutching a rusted blade.",
            "Skulls are arranged in a grim pattern.",
            "The remains of the previous explorers serve as a warning."
        ],
        "corpses": [
            "A recently killed creature lies in a pool of blood.",
            "Half-eaten remains suggest something still hunts here.",
            "Bodies hang from chains embedded in the ceiling."
        ]
    },
    "debris": [
        "Rubble from a partial collapse fills one corner.",
        "Shattered pottery crunches underfoot.",
        "Rusted weapons and broken armor litter the ground.",
        "Torn pages from ancient books flutter in an unfelt wind.",
        "Coins are scattered among the debris—payment for the dead."
    ]
}
```

### Layer 2: Room Purpose Templates (`data/room_descriptions/purposes/`)

Based on the 5-Room Dungeon structure with expanded varieties.

```json
// data/room_descriptions/purposes/entrance.json
{
    "purpose": "entrance",
    "description": "The first room - establishes mood and provides initial challenge",
    "templates": {
        "descent": [
            "You descend {depth_descriptor} into {atmosphere}. {architectural}",
            "Stone steps worn by {time_descriptor} lead down into {atmosphere}. {sensory}",
            "The passage opens into {size} {room_type}. {architectural} {sensory}"
        ],
        "threshold": [
            "Crossing the threshold, you enter {atmosphere}. {architectural}",
            "Beyond the entrance lies {size} {room_type}. {contents}",
            "The {door_descriptor} opens onto {atmosphere}. {sensory}"
        ],
        "discovery": [
            "You emerge into {size} {room_type}. {architectural} {contents}",
            "The way forward reveals {atmosphere}. {sensory}",
            "Before you stretches {size} {room_type}. {architectural}"
        ]
    },
    "depth_descriptors": ["deeper", "further", "cautiously", "carefully"],
    "time_descriptors": ["countless feet", "ages of use", "centuries of passage", "generations of visitors"],
    "door_descriptors": ["ancient door", "heavy gate", "rusted portal", "crumbling archway"]
}
```

```json
// data/room_descriptions/purposes/challenge.json
{
    "purpose": "challenge",
    "description": "Puzzle or roleplay encounter - tests different skills than combat",
    "templates": {
        "puzzle": [
            "The chamber presents an obvious obstacle. {puzzle_hint} {architectural}",
            "Something about this room feels deliberate. {puzzle_hint} {sensory}",
            "A {puzzle_type} blocks the way forward. {architectural}"
        ],
        "guardian": [
            "A {guardian_descriptor} awaits within. {sensory} {contents}",
            "The chamber's {guardian_descriptor} regards your approach. {architectural}",
            "Something here demands tribute or proof. {sensory} {contents}"
        ],
        "environmental": [
            "The room itself poses the challenge. {environmental_hazard} {sensory}",
            "Navigating this chamber will require care. {environmental_hazard}",
            "The path forward is treacherous. {environmental_hazard} {architectural}"
        ]
    },
    "puzzle_hints": [
        "Strange symbols cover the floor in a precise pattern.",
        "Pressure plates are visible among the flagstones.",
        "An inscription in an ancient tongue adorns the far wall.",
        "Statues seem positioned with purposeful intent.",
        "Levers protrude from the walls at regular intervals."
    ],
    "puzzle_types": ["mechanical puzzle", "magical ward", "riddle-locked door", "weighted platform"],
    "guardian_descriptors": ["silent sentinel", "ancient watcher", "bound protector", "patient guardian"],
    "environmental_hazards": [
        "Narrow beams span a bottomless chasm.",
        "The floor has given way in several places.",
        "Toxic fumes rise from vents in the floor.",
        "The chamber is partially flooded with dark water."
    ]
}
```

```json
// data/room_descriptions/purposes/setback.json
{
    "purpose": "setback",
    "description": "Trick or complication - things are not as they seem",
    "templates": {
        "deception": [
            "Something feels wrong about this chamber. {deception_hint} {sensory}",
            "The room appears {false_appearance}, but {reality_hint}. {architectural}",
            "Your instincts warn of hidden danger. {deception_hint}"
        ],
        "complication": [
            "The situation here has changed since others came before. {complication} {contents}",
            "You've walked into something unexpected. {complication} {sensory}",
            "This chamber holds an unpleasant surprise. {complication}"
        ],
        "resource_drain": [
            "This place will cost you dearly to cross. {drain_type} {sensory}",
            "The chamber exacts a toll. {drain_type} {architectural}",
            "Passing through here won't be free. {drain_type}"
        ]
    },
    "deception_hints": [
        "The 'treasure' glints too perfectly in the light.",
        "The 'corpse' seems too fresh—or too arranged.",
        "Friendly voices call from the shadows.",
        "An obvious path leads around the obstacle.",
        "The 'ally' seems too eager to help."
    ],
    "false_appearances": ["safe", "empty", "abandoned", "cleared"],
    "reality_hints": [
        "subtle movement betrays hidden watchers",
        "the dust lies undisturbed by recent passage",
        "the quiet is too complete",
        "something has been here recently"
    ],
    "complications": [
        "A cave-in has blocked the way you came.",
        "The 'dead' creature stirs.",
        "Reinforcements pour from hidden passages.",
        "The artifact you sought lies shattered.",
        "Your guide has vanished."
    ],
    "drain_types": [
        "Magical wards sap your strength with each step.",
        "The very air drains vitality.",
        "Crossing requires sacrifice.",
        "Only blood will open the way."
    ]
}
```

```json
// data/room_descriptions/purposes/climax.json
{
    "purpose": "climax",
    "description": "The big battle - dramatic confrontation",
    "templates": {
        "boss_lair": [
            "You've found {boss_descriptor}'s lair. {lair_features} {sensory}",
            "The {boss_type} awaits in {size} {room_type}. {contents}",
            "This is where {boss_descriptor} makes their stand. {architectural} {contents}"
        ],
        "ritual": [
            "A dark ritual nears completion. {ritual_elements} {sensory}",
            "You've interrupted something terrible. {ritual_elements} {contents}",
            "Eldritch energies crackle through the chamber. {ritual_elements}"
        ],
        "siege": [
            "The enemy has prepared defenses here. {defenses} {contents}",
            "You face entrenched opposition. {defenses} {architectural}",
            "They've been expecting you. {defenses} {sensory}"
        ]
    },
    "boss_descriptors": ["the creature", "your quarry", "the master of this place", "the thing you've hunted"],
    "boss_types": ["lord of this dungeon", "ancient evil", "corrupted guardian", "summoned horror"],
    "lair_features": [
        "Trophies of past victims adorn the walls.",
        "A throne of bones dominates the chamber.",
        "The creature's nest fills one corner.",
        "Offerings lie scattered before a dark altar."
    ],
    "ritual_elements": [
        "Chanting figures surround a glowing circle.",
        "Blood channels flow toward a central basin.",
        "Reality itself seems to warp at the center.",
        "Bound captives await sacrifice."
    ],
    "defenses": [
        "Barricades have been erected across the chamber.",
        "Archers line elevated positions.",
        "The floor is trapped in obvious and hidden ways.",
        "Reinforced positions offer cover to defenders."
    ]
}
```

```json
// data/room_descriptions/purposes/reward.json
{
    "purpose": "reward",
    "description": "The payoff - but often with a twist",
    "templates": {
        "treasure": [
            "At last, the prize. {treasure_description} {twist_hint}",
            "The chamber holds what you sought. {treasure_description} {sensory}",
            "Wealth beyond imagining lies before you. {treasure_description} {twist_hint}"
        ],
        "knowledge": [
            "Ancient wisdom awaits the worthy. {knowledge_source} {architectural}",
            "Secrets long hidden are laid bare. {knowledge_source} {sensory}",
            "Understanding comes at a price. {knowledge_source} {twist_hint}"
        ],
        "escape": [
            "A way out presents itself. {escape_route} {twist_hint}",
            "Freedom lies within reach. {escape_route} {sensory}",
            "The path to safety is clear—almost too clear. {escape_route}"
        ]
    },
    "treasure_descriptions": [
        "Gold coins overflow from rotted chests.",
        "A single artifact rests on a pedestal.",
        "Gems wink from alcoves cut into the walls.",
        "The hoard of ages lies unguarded.",
        "What you seek rests exactly where expected."
    ],
    "knowledge_sources": [
        "Ancient texts fill towering shelves.",
        "A prophetic inscription covers every surface.",
        "The ghost of a sage awaits your questions.",
        "A magical mirror reveals hidden truths."
    ],
    "escape_routes": [
        "Sunlight streams through a collapsed wall.",
        "A portal shimmers with promise of safety.",
        "The original entrance now stands open and clear.",
        "A secret passage leads to the surface."
    ],
    "twist_hints": [
        "But something seems off.",
        "Yet the silence is unsettling.",
        "However, you sense you're not alone.",
        "Still, escaping may prove difficult.",
        "Though claiming it may not be simple."
    ]
}
```

### Layer 3: Room Type Templates (`data/room_descriptions/types/`)

Physical room types that combine with purposes.

```json
// data/room_descriptions/types/crypt.json
{
    "type": "crypt",
    "dungeon_types": ["burial_barrow", "temple_ruins", "natural_cave"],
    "room_type_names": ["crypt", "tomb", "ossuary", "burial chamber", "charnel house", "catacomb"],
    "architectural_features": [
        "Stone sarcophagi line the walls in ordered rows.",
        "Burial niches are carved into every surface.",
        "Bones are arranged in elaborate patterns.",
        "Inscriptions name the forgotten dead.",
        "Grave goods litter the floor.",
        "The walls are built of mortared skulls.",
        "Mummified remains slump in alcoves.",
        "Funerary urns fill dusty shelves."
    ],
    "sensory_details": [
        "The smell of ancient death clings to everything.",
        "Grave dust motes drift in your light.",
        "An unnatural chill pervades the chamber.",
        "Whispers seem to emanate from the tombs.",
        "The silence is absolute and oppressive.",
        "Something about the dead feels watchful."
    ],
    "contents": [
        "Some tombs stand open, their contents missing.",
        "Offerings of coins and gems litter the floor.",
        "A disturbed grave yawns open.",
        "The central sarcophagus is larger and more ornate.",
        "Signs of grave robbers precede you."
    ],
    "atmosphere_adjectives": ["silent", "cold", "deathly", "ancient", "haunted", "profane", "sacred", "defiled"]
}
```

```json
// data/room_descriptions/types/armory.json
{
    "type": "armory",
    "dungeon_types": ["ancient_fort", "military_compound", "wizard_tower"],
    "room_type_names": ["armory", "arsenal", "weapons chamber", "quartermaster's store", "war room"],
    "architectural_features": [
        "Weapon racks line every wall.",
        "Armor stands hold rusted remnants of protection.",
        "Repair benches bear ancient tools.",
        "Arrow slits pierce the outer wall.",
        "Chains for suspending heavy equipment hang from above.",
        "Storage lockers have been forced open."
    ],
    "sensory_details": [
        "The smell of old oil and rust fills the air.",
        "Metal clinks somewhere in the darkness.",
        "The air tastes of iron.",
        "Dust covers everything thickly.",
        "The floor is scarred by decades of heavy traffic."
    ],
    "contents": [
        "Most weapons have been claimed or destroyed.",
        "A few intact pieces remain in shadowed corners.",
        "Training dummies are slashed and battered.",
        "Broken arrow shafts litter the floor.",
        "Someone has been here recently."
    ],
    "atmosphere_adjectives": ["abandoned", "ransacked", "orderly", "chaotic", "martial", "disciplined"]
}
```

```json
// data/room_descriptions/types/ritual_chamber.json
{
    "type": "ritual_chamber",
    "dungeon_types": ["temple_ruins", "wizard_tower", "burial_barrow"],
    "room_type_names": ["ritual chamber", "summoning circle", "sanctuary", "unholy sanctum", "ceremonial hall"],
    "architectural_features": [
        "Arcane symbols cover the floor in concentric rings.",
        "An altar stained with old blood dominates the center.",
        "Braziers stand at cardinal points.",
        "The ceiling is painted with celestial charts.",
        "Channels are carved into the floor, stained dark.",
        "Statues of forgotten gods line the walls."
    ],
    "sensory_details": [
        "The air crackles with residual energy.",
        "Incense can't quite mask the smell of sacrifice.",
        "Candles burn without consuming themselves.",
        "Reality feels thin here.",
        "Your skin prickles with unseen forces.",
        "Shadows move independently of the light."
    ],
    "contents": [
        "Ritual components are scattered in preparation.",
        "A grimoire lies open on a lectern.",
        "Cage bars gleam in one corner.",
        "Chains and manacles suggest unwilling participants.",
        "The ceremony appears incomplete."
    ],
    "atmosphere_adjectives": ["profane", "charged", "crackling", "unholy", "eldritch", "corrupted", "sanctified"]
}
```

```json
// data/room_descriptions/types/natural_cave.json
{
    "type": "natural_cave",
    "dungeon_types": ["natural_cave", "abandoned_mine"],
    "room_type_names": ["cavern", "grotto", "cave", "underground chamber", "natural hollow"],
    "architectural_features": [
        "Stalactites hang from the ceiling like stone fangs.",
        "Flowstone formations create natural sculptures.",
        "An underground pool reflects your light.",
        "Bats cluster in shadowy corners.",
        "The cave floor is uneven and treacherous.",
        "Crystal formations glitter in the walls."
    ],
    "sensory_details": [
        "Water drips in a constant rhythm.",
        "The cave smells of damp earth and minerals.",
        "Echoes seem to come from every direction.",
        "The air is cool and surprisingly fresh.",
        "Unseen creatures rustle in the darkness.",
        "Your torch reveals strange shadows."
    ],
    "contents": [
        "Animal bones are scattered near a nest.",
        "Old campfire remains suggest previous inhabitants.",
        "Mushrooms grow in phosphorescent patches.",
        "A stream trickles through a channel in the floor.",
        "Something large has been sleeping here."
    ],
    "atmosphere_adjectives": ["dark", "damp", "echoing", "vast", "cramped", "natural", "primordial"]
}
```

*(Additional types: prison, laboratory, library, throne_room, barracks, chapel, storage, guardroom, dining_hall, kitchen, sleeping_quarters, torture_chamber, sewer_junction, mine_shaft, treasury)*

### Layer 4: Dungeon Theme Modifiers (`data/room_descriptions/themes/`)

Theme-specific modifications that overlay on base templates.

```json
// data/room_descriptions/themes/burial_barrow.json
{
    "dungeon_id": "burial_barrow",
    "theme_name": "Burial Barrow",
    "preferred_atmospheres": ["dark", "old", "cold", "quiet"],
    "preferred_room_types": ["crypt", "ritual_chamber", "natural_cave"],
    "unique_adjectives": ["barrow-cold", "tomb-silent", "grave-dark", "corpse-pale"],
    "theme_overlays": {
        "contents": [
            "Burial goods of a forgotten age lie scattered.",
            "The honored dead rest in stone beds.",
            "Grave markings in an unknown script cover the walls.",
            "Someone has been disturbing the dead."
        ],
        "sensory": [
            "The chill of the grave seeps into your bones.",
            "Ancient dust stirs with your passage.",
            "The dead are aware of your intrusion.",
            "Time has stopped in this place."
        ]
    },
    "enemy_hints": {
        "barrow_wight": ["A presence of ancient malice lingers here.", "The dead do not rest easy."],
        "grave_rat": ["Scratching sounds echo from the walls.", "Small bones crunch underfoot."],
        "skeleton": ["Bones that should lie still seem poised to rise.", "Empty eye sockets track your movement."]
    },
    "feature_hints": {
        "altar": ["A burial altar bears offerings to forgotten gods."],
        "chest": ["A burial chest lies among grave goods."],
        "sarcophagus": ["The central tomb is more ornate than the rest."]
    }
}
```

```json
// data/room_descriptions/themes/sewers.json
{
    "dungeon_id": "sewers",
    "theme_name": "Sewers",
    "preferred_atmospheres": ["damp", "foul", "dark"],
    "preferred_room_types": ["sewer_junction", "natural_cave", "storage"],
    "unique_adjectives": ["reeking", "flooded", "sludge-covered", "vermin-infested"],
    "theme_overlays": {
        "contents": [
            "Refuse and waste clog the channels.",
            "Grates lead to the surface far above.",
            "Makeshift camps suggest criminal habitation.",
            "Bodies have been dumped here to hide."
        ],
        "sensory": [
            "The stench is nearly overwhelming.",
            "Things move in the murky water.",
            "Rats squeak and scatter at your approach.",
            "The sound of flowing water echoes constantly."
        ]
    },
    "enemy_hints": {
        "sewer_ooze": ["The walls glisten with more than moisture.", "Something viscous trails across the floor."],
        "rat_swarm": ["Eyes gleam in countless numbers from the shadows.", "Squeaking fills the tunnel."],
        "criminal": ["Signs of habitation suggest this area isn't abandoned.", "Someone has been living here."]
    }
}
```

*(Additional themes for each dungeon type)*

### Layer 5: Conditional Content (`data/room_descriptions/conditionals/`)

Content-aware additions based on room contents.

```json
// data/room_descriptions/conditionals/enemies.json
{
    "has_enemy": {
        "generic": [
            "You sense you are not alone.",
            "Something stirs in the shadows.",
            "Movement catches your eye.",
            "The hairs on your neck rise."
        ],
        "many_enemies": [
            "Multiple shapes move in the darkness.",
            "You've walked into an ambush.",
            "They were waiting for you."
        ],
        "powerful_enemy": [
            "A palpable aura of danger fills the room.",
            "Something terrible awaits.",
            "Your instincts scream to flee."
        ]
    },
    "enemy_cleared": {
        "generic": [
            "The bodies of your foes lie still.",
            "The chamber is quiet now.",
            "Evidence of recent battle marks the room."
        ]
    }
}
```

```json
// data/room_descriptions/conditionals/features.json
{
    "has_feature": {
        "altar": [
            "A dark altar dominates the center of the room.",
            "An altar of {altar_material} bears {altar_decorations}.",
            "Something has been worshipped here."
        ],
        "chest": [
            "A {chest_condition} chest rests against {chest_location}.",
            "Something valuable might remain.",
            "A container has survived the ages."
        ],
        "inscription": [
            "Ancient writing covers {inscription_surface}.",
            "Someone left a message here.",
            "Knowledge awaits those who can read."
        ],
        "statue": [
            "A statue of {statue_subject} watches from {statue_location}.",
            "Stone eyes seem to follow your movement.",
            "The sculptors' skill was remarkable."
        ]
    },
    "feature_properties": {
        "altar_materials": ["black stone", "bones", "pitted iron", "carved wood"],
        "altar_decorations": ["dried blood", "offerings", "candles", "symbols"],
        "chest_conditions": ["iron-bound", "rotted", "locked", "open"],
        "chest_locations": ["one wall", "a corner", "a pedestal", "a pile of debris"],
        "inscription_surfaces": ["the walls", "a tablet", "the floor", "a monument"],
        "statue_subjects": ["a forgotten king", "a nameless god", "a warrior", "a monster"],
        "statue_locations": ["an alcove", "a pedestal", "the entrance", "each corner"]
    }
}
```

```json
// data/room_descriptions/conditionals/hazards.json
{
    "has_hazard": {
        "pit_trap": [
            "The floor seems uneven in places.",
            "Subtle seams line the floor.",
            "Something about the stonework seems deliberate."
        ],
        "dart_trap": [
            "Small holes dot the walls.",
            "Ancient mechanisms click in the walls.",
            "The builders left defenses."
        ],
        "poison_gas": [
            "A faint haze hangs in the air.",
            "The air has a strange taste.",
            "Vents line the ceiling."
        ],
        "spike_trap": [
            "Dark stains mark the floor in patterns.",
            "The floor stones have seams.",
            "Prior victims serve as warning."
        ]
    },
    "hazard_revealed": {
        "generic": [
            "You spot the trap just in time.",
            "A careful eye reveals the danger.",
            "The trap is now obvious."
        ]
    }
}
```

```json
// data/room_descriptions/conditionals/loot.json
{
    "has_loot": {
        "generic": [
            "Something glints in the debris.",
            "Valuables lie among the remains.",
            "Previous owners left something behind."
        ],
        "abundant": [
            "Treasure fills the chamber.",
            "Wealth beyond imagining lies scattered.",
            "The hoard is impressive."
        ],
        "hidden": [
            "A careful search might reveal more.",
            "Something seems to be concealed.",
            "Not everything is immediately visible."
        ]
    },
    "loot_taken": {
        "generic": [
            "Only empty containers remain.",
            "Someone beat you here.",
            "The valuables have been claimed."
        ]
    }
}
```

---

## Implementation Plan

### Phase 1: Room Tracking Infrastructure

**1.1 Store Room Data in Map Metadata**

```gdscript
# In map.metadata after generation:
"rooms": [
    {
        "id": "room_0",
        "bounds": {"x": 5, "y": 10, "width": 8, "height": 6},
        "purpose": "entrance",  # entrance, challenge, setback, climax, reward, normal
        "type": "crypt",        # crypt, armory, natural_cave, etc.
        "connections": ["room_1", "corridor_0"],
        "features": ["altar_0"],
        "hazards": [],
        "enemies": ["barrow_wight_0"],
        "first_entered": false,
        "enemies_cleared": false,
        "loot_taken": false
    }
]
```

**1.2 Room Query Methods**

```gdscript
func get_room_at(position: Vector2i) -> Dictionary
func get_room_by_id(room_id: String) -> Dictionary
func mark_room_entered(room_id: String) -> void
func update_room_state(room_id: String, property: String, value: Variant) -> void
```

### Phase 2: Description Configuration Loading

**2.1 Create RoomDescriptionManager Autoload**

```gdscript
# Loads and caches all description configuration
var components: Dictionary      # adjectives, features, sensory, contents
var purposes: Dictionary        # entrance, challenge, setback, climax, reward
var types: Dictionary           # crypt, armory, ritual_chamber, etc.
var themes: Dictionary          # burial_barrow, sewers, etc.
var conditionals: Dictionary    # enemies, features, hazards, loot

func _ready():
    _load_components()
    _load_purposes()
    _load_types()
    _load_themes()
    _load_conditionals()
```

### Phase 3: Description Generation

**3.1 Template Processing**

```gdscript
func generate_description(room: Dictionary, dungeon_type: String, map: Map) -> String:
    var theme = themes.get(dungeon_type, themes.common)
    var purpose_data = purposes.get(room.purpose, purposes.normal)
    var type_data = types.get(room.type, types.generic)

    # Select base template from purpose
    var template = _select_template(purpose_data)

    # Build replacement dictionary
    var replacements = _build_replacements(room, theme, type_data, map)

    # Process conditional additions
    var conditionals = _get_conditionals(room, map)

    # Assemble final description
    return _process_template(template, replacements, conditionals)
```

**3.2 Seeded Randomness**

Use world seed + floor + room_id hash for deterministic description selection.

### Phase 4: Display Integration

Same as original plan - message log with distinct styling.

### Phase 5: Save/Load Integration

Track discovered rooms and room state changes.

---

## Data Files Summary

### Components (Shared)
| File | Content Count |
|------|---------------|
| `components/adjectives.json` | 50+ adjective categories |
| `components/architectural_features.json` | 40+ feature descriptions |
| `components/sensory_details.json` | 30+ sensory descriptions |
| `components/contents.json` | 40+ content descriptions |

### Purposes (5-Room Structure)
| File | Templates |
|------|-----------|
| `purposes/entrance.json` | 9+ templates, 20+ sub-elements |
| `purposes/challenge.json` | 9+ templates, 20+ sub-elements |
| `purposes/setback.json` | 9+ templates, 20+ sub-elements |
| `purposes/climax.json` | 9+ templates, 20+ sub-elements |
| `purposes/reward.json` | 9+ templates, 20+ sub-elements |

### Types (Physical Rooms)
15+ room type files, each with:
- 6+ room type names
- 8+ architectural features
- 6+ sensory details
- 5+ contents options
- 8+ atmosphere adjectives

### Themes (Per Dungeon)
8 dungeon theme files, each with:
- Preferred atmospheres and room types
- Unique adjectives
- Theme-specific overlays
- Enemy hints
- Feature hints

### Conditionals
4+ conditional files covering:
- Enemy presence and state
- Feature types
- Hazard types
- Loot presence and state

**Total: 40+ configuration files, 500+ unique description elements**

---

## Example Generated Descriptions

**Burial Barrow - Entrance - Crypt:**
> Stone steps worn by countless feet lead down into tomb-silent darkness. Burial niches are carved into every surface. The chill of the grave seeps into your bones. Whispers seem to emanate from the tombs.

**Sewers - Challenge - Junction:**
> The chamber presents an obvious obstacle. Narrow beams span a flooded channel of filth. Grates lead to the surface far above. The stench is nearly overwhelming.

**Military Compound - Climax - Barracks:**
> The enemy commander awaits in a vast barracks. Barricades have been erected across the chamber. Weapon racks line every wall—most now empty. Signs of recent occupation mark every surface.

**Wizard Tower - Reward - Laboratory:**
> Ancient wisdom awaits the worthy. A grimoire lies open on a lectern. The air crackles with residual energy. But something seems off—the pages flutter in an unfelt wind.

---

## Future Enhancements

1. **WIS-based Revelation**: Higher WIS reveals more conditional hints
2. **Revisit Descriptions**: Shortened versions for discovered rooms
3. **Dynamic Updates**: Descriptions change when room state changes
4. **Named Rooms**: Generate proper names for special chambers
5. **Player Journal**: Log discovered room descriptions
6. **Localization Support**: Template structure supports translation

---

## Implementation Order

1. **Phase 1**: Room tracking infrastructure
2. **Phase 2**: Configuration loading system
3. **Phase 3**: Description generator with template processing
4. **Phase 4**: Create base component files
5. **Phase 5**: Create purpose and type files
6. **Phase 6**: Create theme files for 2-3 dungeons
7. **Phase 7**: Display integration
8. **Phase 8**: Expand to all dungeon types

Estimated scope: Large feature (~5-6 implementation sessions)

Sources:
- [donjon 5-Room Dungeon Generator](https://donjon.bin.sh/fantasy/5_room/)
- [Johnn Four's 5-Room Dungeon Guide](https://www.roleplayingtips.com/5-room-dungeons/)
- [Chaos Gen Five Room Dungeon](https://www.chaosgen.com/fantasy/5rd)
