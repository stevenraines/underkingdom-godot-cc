#!/usr/bin/env python3
"""Generate both CP437 and Unicode tileset sprite sheets for the roguelike game."""

from PIL import Image, ImageDraw, ImageFont
import os

# Configuration
TILE_WIDTH = 38   # Width optimized for monospace fonts
TILE_HEIGHT = 64  # Height for good vertical spacing
DEFAULT_COLOR = (255, 255, 255)  # All white - colors applied via Godot modulation

# ============================================================================
# CP437 (Code Page 437) - 256 characters in 16x16 grid
# ============================================================================

CP437_TILES_PER_ROW = 16

# CP437 (DOS/IBM Extended ASCII) character mapping
CP437_MAP = [
    0x0000, 0x263A, 0x263B, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022,
    0x25D8, 0x25CB, 0x25D9, 0x2642, 0x2640, 0x266A, 0x266B, 0x263C,
    0x25BA, 0x25C4, 0x2195, 0x203C, 0x00B6, 0x00A7, 0x25AC, 0x21A8,
    0x2191, 0x2193, 0x2192, 0x2190, 0x221F, 0x2194, 0x25B2, 0x25BC,
] + list(range(0x0020, 0x0080)) + [
    0x00C7, 0x00FC, 0x00E9, 0x00E2, 0x00E4, 0x00E0, 0x00E5, 0x00E7,
    0x00EA, 0x00EB, 0x00E8, 0x00EF, 0x00EE, 0x00EC, 0x00C4, 0x00C5,
    0x00C9, 0x00E6, 0x00C6, 0x00F4, 0x00F6, 0x00F2, 0x00FB, 0x00F9,
    0x00FF, 0x00D6, 0x00DC, 0x00A2, 0x00A3, 0x00A5, 0x20A7, 0x0192,
    0x00E1, 0x00ED, 0x00F3, 0x00FA, 0x00F1, 0x00D1, 0x00AA, 0x00BA,
    0x00BF, 0x2310, 0x00AC, 0x00BD, 0x00BC, 0x00A1, 0x00AB, 0x00BB,
    0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556,
    0x2555, 0x2563, 0x2551, 0x2557, 0x255D, 0x255C, 0x255B, 0x2510,
    0x2514, 0x2534, 0x252C, 0x251C, 0x2500, 0x253C, 0x255E, 0x255F,
    0x255A, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256C, 0x2567,
    0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256B,
    0x256A, 0x2518, 0x250C, 0x2588, 0x2584, 0x258C, 0x2590, 0x2580,
    0x03B1, 0x00DF, 0x0393, 0x03C0, 0x03A3, 0x03C3, 0x00B5, 0x03C4,
    0x03A6, 0x0398, 0x03A9, 0x03B4, 0x221E, 0x03C6, 0x03B5, 0x2229,
    0x2261, 0x00B1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00F7, 0x2248,
    0x00B0, 0x2219, 0x00B7, 0x221A, 0x207F, 0x00B2, 0x25A0, 0x00A0,
]

CP437_CHARS = [chr(codepoint) for codepoint in CP437_MAP]

# ============================================================================
# Unicode Printable Characters - Comprehensive set in 32-column grid
# ============================================================================

UNICODE_TILES_PER_ROW = 32

# Collect printable Unicode characters from various blocks
UNICODE_CHARS = []

# Basic Latin (ASCII 32-126) - 95 chars
UNICODE_CHARS.extend([chr(i) for i in range(0x0020, 0x007F)])

# Latin-1 Supplement (160-255) - 96 chars
UNICODE_CHARS.extend([chr(i) for i in range(0x00A0, 0x0100)])

# Box Drawing (0x2500-0x257F) - 128 chars
UNICODE_CHARS.extend([chr(i) for i in range(0x2500, 0x2580)])

# Block Elements (0x2580-0x259F) - 32 chars
UNICODE_CHARS.extend([chr(i) for i in range(0x2580, 0x25A0)])

# Geometric Shapes (0x25A0-0x25FF) - 96 chars
UNICODE_CHARS.extend([chr(i) for i in range(0x25A0, 0x2600)])

# Miscellaneous Symbols (0x2600-0x26FF) - 256 chars
UNICODE_CHARS.extend([chr(i) for i in range(0x2600, 0x2700)])

# Dingbats (0x2700-0x27BF) - 192 chars
UNICODE_CHARS.extend([chr(i) for i in range(0x2700, 0x27C0)])

print(f"Total CP437 characters: {len(CP437_CHARS)}")
print(f"Total Unicode characters: {len(UNICODE_CHARS)}")


def load_font():
    """Load a monospace font with good Unicode support."""
    font_paths = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",  # Linux DejaVu (best)
        "/System/Library/Fonts/Menlo.ttc",  # macOS Menlo
        "/System/Library/Fonts/Courier.ttc",  # macOS Courier
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",  # Linux Liberation
        "C:\\Windows\\Fonts\\DejaVuSansMono.ttf",  # Windows DejaVu
        "C:\\Windows\\Fonts\\consola.ttf",  # Windows Consolas
    ]

    for font_path in font_paths:
        if os.path.exists(font_path):
            font = ImageFont.truetype(font_path, 58)  # Larger font to fill 64px tiles
            print(f"Loaded font: {font_path}")
            return font

    print("Warning: No TrueType font found, using PIL default")
    return ImageFont.load_default()


def create_cp437_tileset():
    """Create CP437 tileset (ascii_tileset.png) - 256 characters, 16x16 grid."""
    num_chars = len(CP437_CHARS)
    rows = (num_chars + CP437_TILES_PER_ROW - 1) // CP437_TILES_PER_ROW
    width = CP437_TILES_PER_ROW * TILE_WIDTH
    height = rows * TILE_HEIGHT

    print(f"\nCreating CP437 tileset: {width}x{height} ({CP437_TILES_PER_ROW} columns x {rows} rows)")

    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    font = load_font()

    # Draw each character
    for i, char in enumerate(CP437_CHARS):
        row = i // CP437_TILES_PER_ROW
        col = i % CP437_TILES_PER_ROW
        x_offset = col * TILE_WIDTH
        y_offset = row * TILE_HEIGHT

        # Get text bounding box and center
        bbox = draw.textbbox((0, 0), char, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        x = x_offset + (TILE_WIDTH - text_width) // 2
        y = y_offset + (TILE_HEIGHT - text_height) // 2 - bbox[1]

        draw.text((x, y), char, fill=DEFAULT_COLOR + (255,), font=font)

    # Save CP437 tileset
    output_path = os.path.join(os.path.dirname(__file__), "tilesets", "ascii_tileset.png")
    image.save(output_path)
    print(f"Saved CP437 tileset to: {output_path}")
    print(f"Image size: {width}x{height}")
    print(f"Grid: {CP437_TILES_PER_ROW} columns x {rows} rows")

    # Save character map
    charmap_path = os.path.join(os.path.dirname(__file__), "tilesets", "ascii_charmap.txt")
    with open(charmap_path, 'w', encoding='utf-8') as f:
        f.write("CP437 (Code Page 437) Character Map\n")
        f.write("=" * 60 + "\n")
        f.write("Index  Grid    Unicode  Character\n")
        f.write("-" * 60 + "\n")
        for i, char in enumerate(CP437_CHARS):
            row = i // CP437_TILES_PER_ROW
            col = i % CP437_TILES_PER_ROW
            f.write(f"{i:4d}  ({col:2d},{row:2d})  U+{CP437_MAP[i]:04X}     '{char}'\n")
    print(f"Saved CP437 character map to: {charmap_path}")


def create_unicode_tileset():
    """Create Unicode tileset (unicode_tileset.png) - comprehensive character set, 32-column grid."""
    num_chars = len(UNICODE_CHARS)
    rows = (num_chars + UNICODE_TILES_PER_ROW - 1) // UNICODE_TILES_PER_ROW
    width = UNICODE_TILES_PER_ROW * TILE_WIDTH
    height = rows * TILE_HEIGHT

    print(f"\nCreating Unicode tileset: {width}x{height} ({UNICODE_TILES_PER_ROW} columns x {rows} rows)")

    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    font = load_font()

    # Draw each character
    for i, char in enumerate(UNICODE_CHARS):
        row = i // UNICODE_TILES_PER_ROW
        col = i % UNICODE_TILES_PER_ROW
        x_offset = col * TILE_WIDTH
        y_offset = row * TILE_HEIGHT

        # Get text bounding box and center
        bbox = draw.textbbox((0, 0), char, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        x = x_offset + (TILE_WIDTH - text_width) // 2
        y = y_offset + (TILE_HEIGHT - text_height) // 2 - bbox[1]

        draw.text((x, y), char, fill=DEFAULT_COLOR + (255,), font=font)

    # Save Unicode tileset
    output_path = os.path.join(os.path.dirname(__file__), "tilesets", "unicode_tileset.png")
    image.save(output_path)
    print(f"Saved Unicode tileset to: {output_path}")
    print(f"Image size: {width}x{height}")
    print(f"Grid: {UNICODE_TILES_PER_ROW} columns x {rows} rows")

    # Save character map
    charmap_path = os.path.join(os.path.dirname(__file__), "tilesets", "unicode_charmap.txt")
    with open(charmap_path, 'w', encoding='utf-8') as f:
        f.write("Unicode Printable Characters Map\n")
        f.write("=" * 60 + "\n")
        f.write("Index  Grid    Unicode  Character\n")
        f.write("-" * 60 + "\n")
        for i, char in enumerate(UNICODE_CHARS):
            row = i // UNICODE_TILES_PER_ROW
            col = i % UNICODE_TILES_PER_ROW
            f.write(f"{i:4d}  ({col:2d},{row:2d})  U+{ord(char):04X}     '{char}'\n")
    print(f"Saved Unicode character map to: {charmap_path}")


if __name__ == "__main__":
    create_cp437_tileset()
    create_unicode_tileset()
    print("\nBoth tilesets generated successfully!")
