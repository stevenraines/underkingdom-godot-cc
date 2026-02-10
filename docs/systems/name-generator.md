# Name Generator System

## Overview

The Name Generator system provides deterministic, culturally-appropriate fantasy names for NPCs, settlements, enemies, and items. All generation is seeded for consistency within a game world.

## Usage

### Basic Name Generation

```gdscript
# Get a SeededRandom instance (from GameManager or create one)
var rng = SeededRandom.new(GameManager.world_seed + some_offset)

# Generate a personal name (first + last)
var name = NameGenerator.generate_personal_name("human", "male", rng)
# Result: "Aldwin Blacksmith", "Garwald Stonehill", etc.

# Generate just a first name
var first = NameGenerator.generate_name("dwarf_male", rng)
# Result: "Balin", "Thorin", "Gimli", etc.

# Generate a settlement name
var town_name = NameGenerator.generate_settlement_name("town", "grassland", rng)
# Result: "Ashford", "Riverbridge", "Thornbury", etc.

# Generate a book title
var book = NameGenerator.generate_book_title("magic", rng)
# Result: "The Ancient Grimoire", "On the Nature of Magic", etc.

# Generate a ship name
var ship = NameGenerator.generate_ship_name(rng)
# Result: "The Swift Dragon", "Storm's Glory", etc.
```

### Available Personal Name Patterns

Personal names use the format: `race_gender` for first names, `race_surname` for last names.

**Races:**
- `human` - Western European/Anglo-Saxon
- `dwarf` - Nordic/Germanic
- `elf` - Melodic, flowing
- `halfling` - Cheerful, simple
- `gnome` - Quirky, inventive
- `half_orc` - Harsh, guttural
- `goblin` - Sneaky, sharp sounds

**Genders:**
- `male`
- `female`

**Example:**
```gdscript
var elf_name = NameGenerator.generate_personal_name("elf", "female", rng)
# Result: "Galadriel Starwhisper", "Arwen Moonleaf", etc.
```

### Available Settlement Patterns

- `settlement_town` - Generic town/village names
- `settlement_village` - Small village names (simpler, rustic)
- `settlement_fort` - Military forts and towers

**Example:**
```gdscript
var fort = NameGenerator.generate_settlement_name("fort", "", rng)
# Result: "Fort Iron", "The Shadow Citadel", "Ravengard", etc.
```

### Available Item Patterns

- `book_title` - Generic book titles
- `ship_name` - Ship and vessel names

### Integration Examples

#### Generating NPC Names

```gdscript
# When spawning a random NPC
func spawn_random_npc(position: Vector2i, race: String, gender: String):
    var rng = SeededRandom.new(GameManager.world_seed + position.x * 1000 + position.y)
    var npc_name = NameGenerator.generate_personal_name(race, gender, rng)

    var npc = NPCClass.new("npc_generic", position, "@", Color.WHITE, true)
    npc.name = npc_name
    return npc
```

#### Generating Settlement Names

```gdscript
# When placing a procedural town
func place_town(position: Vector2i, biome: String):
    var rng = SeededRandom.new(GameManager.world_seed + position.x + position.y * 10000)
    var town_name = NameGenerator.generate_settlement_name("town", biome, rng)

    var town_data = {
        "name": town_name,
        "position": position,
        "type": "town"
    }
    TownManager.add_placed_town(town_data)
```

#### Generating Enemy Names

```gdscript
# For unique/boss enemies
func spawn_boss_enemy(enemy_id: String, position: Vector2i):
    var enemy = EntityManager.spawn_enemy(enemy_id, position)

    # Determine race from creature type
    var race = "goblin"  # Or detect from enemy_id/type
    var rng = SeededRandom.new(GameManager.world_seed + position.x * 100 + position.y)

    enemy.name = NameGenerator.generate_name(race + "_male", rng)
    return enemy
```

#### Generating Book Titles

```gdscript
# When creating a random book item
func create_random_book():
    var rng = SeededRandom.new(GameManager.world_seed + ItemManager.generated_book_count)
    var title = NameGenerator.generate_book_title("", rng)

    # Create a book item with generated title
    var book = ItemManager.create_item("book")
    book.name = title
    return book
```

## Pattern Structure

### Syllable-Based Patterns

Syllable patterns use predefined lists of prefixes, middles, and suffixes to create names.

**Structure Types:**
- `prefix-suffix` - Two-part names (most common)
- `prefix-middle-suffix` - Three-part names
- `prefix-optional-middle-suffix` - Two or three parts (50% chance for middle)

**Example JSON:**
```json
{
  "id": "human_male",
  "type": "syllable",
  "structure": "prefix-suffix",
  "capitalization": "first",
  "prefixes": ["Ald", "Ber", "Gar", ...],
  "suffixes": ["win", "ric", "mund", ...]
}
```

### Template-Based Patterns

Template patterns use word lists to fill in placeholders.

**Example JSON:**
```json
{
  "id": "book_title",
  "type": "template",
  "templates": [
    "The [adjective] [noun]",
    "[noun] of [quality]"
  ],
  "word_lists": {
    "adjective": ["Ancient", "Lost", "Hidden", ...],
    "noun": ["Tome", "Codex", "Grimoire", ...]
  }
}
```

## Adding New Patterns

1. Create a JSON file in `data/name_patterns/` (or subdirectory)
2. Define the pattern structure (syllable or template)
3. The NameGenerator will automatically load it on startup

**Directory Structure:**
```
data/name_patterns/
├── personal/          # Character names by race/gender
├── settlements/       # Settlement names by type
└── items/            # Item names (books, ships, etc.)
```

## Seeding Best Practices

For deterministic generation, always use consistent seeds:

```gdscript
# Good: Position-based seed for consistent names at each location
var rng = SeededRandom.new(GameManager.world_seed + pos.x * 1000 + pos.y)

# Good: Counter-based seed for sequential generation
var rng = SeededRandom.new(GameManager.world_seed + npc_count)

# Bad: Random seed (names will change every reload)
var rng = SeededRandom.new(randi())
```

## Future Enhancements

Possible future additions:
- Compound names (combining multiple patterns)
- Cultural variants (regional dialects within races)
- Title generation (e.g., "Lord", "Captain", "Master")
- Procedural language generation for inscriptions
- Markov chain patterns for more variety

## See Also

- `autoload/name_generator.gd` - Implementation
- `data/name_patterns/` - Pattern definitions
- `generation/seeded_random.gd` - Deterministic RNG
