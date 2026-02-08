class_name ASCIITextureMapper
extends RefCounted

## ASCIITextureMapper - Handles ASCII character to tile ID mapping
##
## Extracted from ASCIIRenderer to separate mapping logic from rendering.
## Builds the Unicode character map and provides character-to-tile-index
## and character-to-atlas-coordinate lookups for the renderer.
##
## IMPORTANT: The character order must match generate_tilesets.py exactly.


# =============================================================================
# CONSTANTS
# =============================================================================

## Number of tile columns in the tileset atlas
const TILES_PER_ROW = 32

## Total number of Unicode characters in the tileset (49 rows x 32 cols, 1551 used)
const TOTAL_TILE_COUNT = 1551


# =============================================================================
# STATE
# =============================================================================

## Character to linear tile index mapping (matches generate_tilesets.py order)
var unicode_char_map: Dictionary = {}


# =============================================================================
# INITIALIZATION
# =============================================================================

func _init() -> void:
	_build_unicode_map()


## Build Unicode character index mapping
## IMPORTANT: This must match the exact order from generate_tilesets.py
func _build_unicode_map() -> void:
	var chars: Array = []

	# Basic Latin (ASCII 32-126) - 95 chars
	for i in range(0x0020, 0x007F):
		chars.append(char(i))

	# Latin-1 Supplement (160-255) - 96 chars
	for i in range(0x00A0, 0x0100):
		chars.append(char(i))

	# Greek and Coptic (0x0370-0x03FF) - includes delta, omega, alpha, beta, gamma, etc.
	for i in range(0x0370, 0x0400):
		chars.append(char(i))

	# Mathematical Operators (0x2200-0x22FF) - includes infinity, sum, sqrt, etc.
	for i in range(0x2200, 0x2300):
		chars.append(char(i))

	# Miscellaneous Technical (0x2300-0x23FF) - includes house, corner bracket, etc.
	for i in range(0x2300, 0x2400):
		chars.append(char(i))

	# Box Drawing (0x2500-0x257F) - 128 chars
	for i in range(0x2500, 0x2580):
		chars.append(char(i))

	# Block Elements (0x2580-0x259F) - 32 chars
	for i in range(0x2580, 0x25A0):
		chars.append(char(i))

	# Geometric Shapes (0x25A0-0x25FF) - 96 chars
	for i in range(0x25A0, 0x2600):
		chars.append(char(i))

	# Miscellaneous Symbols (0x2600-0x26FF) - 256 chars
	for i in range(0x2600, 0x2700):
		chars.append(char(i))

	# Dingbats (0x2700-0x27BF) - 192 chars
	for i in range(0x2700, 0x27C0):
		chars.append(char(i))

	# Build lookup dictionary
	for i in range(chars.size()):
		unicode_char_map[chars[i]] = i

	if chars.size() != TOTAL_TILE_COUNT:
		push_error("[ASCIITextureMapper] TOTAL_TILE_COUNT (%d) doesn't match built map size (%d)" % [TOTAL_TILE_COUNT, chars.size()])
	print("[ASCIITextureMapper] Built unicode map with %d characters" % chars.size())


# =============================================================================
# PUBLIC API
# =============================================================================

## Get linear tile index for a character (0-based index into tileset)
func get_tile_index(character: String) -> int:
	if character.is_empty():
		return 0

	# Look up character in unicode map
	if character in unicode_char_map:
		return unicode_char_map[character]

	# Fallback for unmapped characters - use space
	push_warning("[ASCIITextureMapper] Unmapped character '%s' (U+%04X), using space" % [character, character.unicode_at(0) if character.length() > 0 else 0])
	return 0  # Space character at index 0


## Get atlas coordinates (col, row) for a character in the tileset grid
## This combines get_tile_index + index-to-grid conversion into one call
func get_atlas_coords(character: String) -> Vector2i:
	var index = get_tile_index(character)
	return Vector2i(index % TILES_PER_ROW, index / TILES_PER_ROW)
