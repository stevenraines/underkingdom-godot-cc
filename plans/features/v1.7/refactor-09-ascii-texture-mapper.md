# Refactor 09: ASCII Texture Mapper

**Risk Level**: Medium
**Estimated Changes**: 1 new file, 1 file modified

---

## Goal

Separate texture/character mapping logic from rendering in `ascii_renderer.gd` (1,182 lines).

Extract character-to-tile-ID mapping, Unicode character handling, and tileset configuration into an `ASCIITextureMapper` class.

---

## Current State

### rendering/ascii_renderer.gd
The file mixes:
- Character-to-tile ID mapping (~100 lines)
- Unicode character map building (~50 lines)
- Tileset creation and configuration
- Actual rendering to TileMapLayers
- Dirty flag management
- FOV/visibility calculations
- Chunk rendering

### Code to Extract
- `CHAR_TO_TILE` dictionary
- `_build_unicode_map()`
- `_get_tile_id_for_char()`
- `_get_source_id()`
- Character/symbol constants

---

## Implementation

### Step 1: Create rendering/ascii_texture_mapper.gd

```gdscript
class_name ASCIITextureMapper
extends RefCounted

## ASCIITextureMapper - Handles ASCII character to tile ID mapping
##
## Extracted from ASCIIRenderer to separate mapping logic from rendering.
## Provides character-to-tile-ID lookups for the renderer.


# =============================================================================
# CHARACTER TO TILE ID MAPPING
# =============================================================================

## Base ASCII characters (32-126) map directly to tile IDs 0-94
## Extended characters use IDs 95+

## Direct character to tile ID mapping for special/extended characters
const EXTENDED_CHAR_MAP: Dictionary = {
	# Box drawing
	"─": 95,
	"│": 96,
	"┌": 97,
	"┐": 98,
	"└": 99,
	"┘": 100,
	"├": 101,
	"┤": 102,
	"┬": 103,
	"┴": 104,
	"┼": 105,
	"═": 106,
	"║": 107,
	"╔": 108,
	"╗": 109,
	"╚": 110,
	"╝": 111,

	# Symbols
	"●": 112,
	"○": 113,
	"◎": 114,
	"◇": 115,
	"◆": 116,
	"□": 117,
	"■": 118,
	"▪": 119,
	"▫": 120,
	"▲": 121,
	"▼": 122,
	"►": 123,
	"◄": 124,
	"★": 125,
	"☆": 126,

	# Game-specific symbols
	"♠": 127,
	"♣": 128,
	"♥": 129,
	"♦": 130,
	"†": 131,
	"‡": 132,
	"§": 133,
	"¶": 134,
	"©": 135,
	"®": 136,
	"™": 137,

	# Terrain/feature symbols
	"≈": 138,  # Water
	"≡": 139,  # Deep water
	"∿": 140,  # Waves
	"⌂": 141,  # House
	"⌐": 142,  # Floor corner
	"¬": 143,  # Not symbol / wall
	"░": 144,  # Light shade
	"▒": 145,  # Medium shade
	"▓": 146,  # Dark shade
	"█": 147,  # Full block

	# Entity symbols
	"☺": 148,  # Player/friendly
	"☻": 149,  # Enemy
	"☼": 150,  # Sun/light
	"♪": 151,  # Music/bard
	"♫": 152,  # Notes
	"☢": 153,  # Hazard
	"☣": 154,  # Biohazard
	"⚔": 155,  # Combat
	"⚡": 156,  # Lightning
	"⚠": 157,  # Warning

	# Currency/items
	"$": 36,   # Gold (standard ASCII)
	"¢": 158,  # Cent
	"£": 159,  # Pound
	"¥": 160,  # Yen
	"€": 161,  # Euro

	# Arrows
	"←": 162,
	"→": 163,
	"↑": 164,
	"↓": 165,
	"↔": 166,
	"↕": 167,

	# Misc
	"∞": 168,
	"≠": 169,
	"≤": 170,
	"≥": 171,
	"±": 172,
	"÷": 173,
	"×": 174,
	"√": 175,
}

## Reverse lookup: tile ID to character
var _tile_to_char: Dictionary = {}

## Unicode map for font texture generation
var _unicode_map: Dictionary = {}


func _init() -> void:
	_build_reverse_map()
	_build_unicode_map()


## Build reverse lookup from tile ID to character
func _build_reverse_map() -> void:
	# Standard ASCII (32-126 -> tile IDs 0-94)
	for code in range(32, 127):
		var char_str = char(code)
		var tile_id = code - 32
		_tile_to_char[tile_id] = char_str

	# Extended characters
	for char_str in EXTENDED_CHAR_MAP:
		var tile_id = EXTENDED_CHAR_MAP[char_str]
		_tile_to_char[tile_id] = char_str


## Build unicode map for all supported characters
func _build_unicode_map() -> void:
	# Standard ASCII
	for code in range(32, 127):
		_unicode_map[char(code)] = code - 32

	# Extended characters
	for char_str in EXTENDED_CHAR_MAP:
		_unicode_map[char_str] = EXTENDED_CHAR_MAP[char_str]


# =============================================================================
# PUBLIC API
# =============================================================================

## Get tile ID for a character (0-based index into tileset)
func get_tile_id(character: String) -> int:
	if character.is_empty():
		return 0  # Space

	var first_char = character[0]

	# Check extended map first
	if first_char in EXTENDED_CHAR_MAP:
		return EXTENDED_CHAR_MAP[first_char]

	# Standard ASCII (32-126 -> 0-94)
	var code = first_char.unicode_at(0)
	if code >= 32 and code <= 126:
		return code - 32

	# Unknown character - return question mark
	return 31  # '?' is ASCII 63, tile ID 31


## Get character for a tile ID
func get_character(tile_id: int) -> String:
	if tile_id in _tile_to_char:
		return _tile_to_char[tile_id]
	return "?"


## Check if a character is supported
func is_supported(character: String) -> bool:
	if character.is_empty():
		return true  # Space is supported

	var first_char = character[0]

	if first_char in EXTENDED_CHAR_MAP:
		return true

	var code = first_char.unicode_at(0)
	return code >= 32 and code <= 126


## Get all characters that need to be in the tileset
func get_all_characters() -> Array[String]:
	var chars: Array[String] = []

	# Standard ASCII
	for code in range(32, 127):
		chars.append(char(code))

	# Extended
	for char_str in EXTENDED_CHAR_MAP:
		chars.append(char_str)

	return chars


## Get total number of tiles needed in tileset
func get_tile_count() -> int:
	# 95 standard ASCII + extended characters
	var max_extended = 0
	for char_str in EXTENDED_CHAR_MAP:
		max_extended = maxi(max_extended, EXTENDED_CHAR_MAP[char_str])
	return max_extended + 1


## Get the unicode map for font texture generation
func get_unicode_map() -> Dictionary:
	return _unicode_map


# =============================================================================
# ENTITY/TILE SYMBOL HELPERS
# =============================================================================

## Standard symbols for common game elements
const SYMBOL_PLAYER = "@"
const SYMBOL_ENEMY = "E"
const SYMBOL_NPC = "N"
const SYMBOL_MERCHANT = "$"
const SYMBOL_DOOR_CLOSED = "+"
const SYMBOL_DOOR_OPEN = "'"
const SYMBOL_STAIRS_DOWN = ">"
const SYMBOL_STAIRS_UP = "<"
const SYMBOL_CHEST_CLOSED = "="
const SYMBOL_CHEST_OPEN = "_"
const SYMBOL_WALL = "#"
const SYMBOL_FLOOR = "."
const SYMBOL_WATER = "≈"
const SYMBOL_DEEP_WATER = "≡"
const SYMBOL_GRASS = ","
const SYMBOL_TREE = "♠"
const SYMBOL_BUSH = "*"
const SYMBOL_ROCK = "○"
const SYMBOL_CAMPFIRE = "☼"
const SYMBOL_TRAP = "^"
const SYMBOL_ITEM = "!"
const SYMBOL_GOLD = "$"
const SYMBOL_CORPSE = "%"
const SYMBOL_ALTAR = "_"
const SYMBOL_STATUE = "&"


## Get symbol for entity type
static func get_entity_symbol(entity_type: String) -> String:
	match entity_type:
		"player":
			return SYMBOL_PLAYER
		"enemy":
			return SYMBOL_ENEMY
		"npc":
			return SYMBOL_NPC
		"merchant":
			return SYMBOL_MERCHANT
		_:
			return "?"


## Get symbol for tile type
static func get_tile_symbol(tile_type: String) -> String:
	match tile_type:
		"wall":
			return SYMBOL_WALL
		"floor":
			return SYMBOL_FLOOR
		"water", "shallow_water":
			return SYMBOL_WATER
		"deep_water":
			return SYMBOL_DEEP_WATER
		"grass":
			return SYMBOL_GRASS
		"tree":
			return SYMBOL_TREE
		"door_closed":
			return SYMBOL_DOOR_CLOSED
		"door_open":
			return SYMBOL_DOOR_OPEN
		"stairs_down":
			return SYMBOL_STAIRS_DOWN
		"stairs_up":
			return SYMBOL_STAIRS_UP
		_:
			return SYMBOL_FLOOR
```

---

### Step 2: Update rendering/ascii_renderer.gd

1. **Add preload and instance**:
```gdscript
const ASCIITextureMapperClass = preload("res://rendering/ascii_texture_mapper.gd")

var _texture_mapper: ASCIITextureMapper = null
```

2. **Initialize in `_init()` or `_ready()`**:
```gdscript
func _init() -> void:
	_texture_mapper = ASCIITextureMapperClass.new()
```

3. **Replace direct character mapping**:
```gdscript
# Before:
func _get_tile_id_for_char(character: String) -> int:
	if character in CHAR_TO_TILE:
		return CHAR_TO_TILE[character]
	var code = character.unicode_at(0)
	if code >= 32 and code <= 126:
		return code - 32
	return 31

# After:
func _get_tile_id_for_char(character: String) -> int:
	return _texture_mapper.get_tile_id(character)
```

4. **Remove** the following from ascii_renderer.gd:
- `CHAR_TO_TILE` dictionary constant
- `_build_unicode_map()` method
- `_unicode_map` variable
- Any inline character mapping code

5. **Update font texture generation** to use mapper:
```gdscript
func _generate_tileset_texture() -> ImageTexture:
	var chars = _texture_mapper.get_all_characters()
	var tile_count = _texture_mapper.get_tile_count()
	# ... rest of texture generation using chars and tile_count
```

---

## Files Summary

### New Files
- `rendering/ascii_texture_mapper.gd` (~250 lines)

### Modified Files
- `rendering/ascii_renderer.gd` - Reduced by ~150 lines

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Start new game
- [ ] All terrain renders correctly
  - [ ] Walls (#)
  - [ ] Floors (.)
  - [ ] Water (≈)
  - [ ] Trees (♠)
  - [ ] Grass (,)
- [ ] All entities render correctly
  - [ ] Player (@)
  - [ ] Enemies (various letters)
  - [ ] NPCs (N)
  - [ ] Merchants ($)
- [ ] All features render correctly
  - [ ] Doors (+ and ')
  - [ ] Stairs (> and <)
  - [ ] Chests (= and _)
- [ ] All items render correctly
  - [ ] Ground items (!)
  - [ ] Gold piles ($)
- [ ] Special characters display correctly
  - [ ] Box drawing characters
  - [ ] Symbols (●, ○, ♠, etc.)
- [ ] FOV and explored areas render correctly
- [ ] Chunk transitions render correctly
- [ ] No visual glitches or missing characters
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- rendering/ascii_renderer.gd
rm rendering/ascii_texture_mapper.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
