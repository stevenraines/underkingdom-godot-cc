#!/usr/bin/env python3
"""Generate CP437 (Code Page 437) tileset sprite sheet for the roguelike game."""

from PIL import Image, ImageDraw, ImageFont
import os

# Configuration
TILE_SIZE = 64  # Increased to 64 for better clarity
TILES_PER_ROW = 16  # 16x16 grid for 256 characters

# CP437 (DOS/IBM Extended ASCII) character mapping
# Maps index 0-255 to the corresponding CP437 Unicode codepoint
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

# Convert CP437 map to actual characters
CHARS = [chr(codepoint) for codepoint in CP437_MAP]

print(f"Total CP437 characters: {len(CHARS)}")

# All characters white - colors will be applied via Godot's modulation
DEFAULT_COLOR = (255, 255, 255)

def create_cp437_tileset():
    """Create a sprite sheet with CP437 (Code Page 437) characters."""
    # Calculate grid dimensions
    num_chars = len(CHARS)
    rows = (num_chars + TILES_PER_ROW - 1) // TILES_PER_ROW  # Ceiling division

    width = TILES_PER_ROW * TILE_SIZE
    height = rows * TILE_SIZE

    print(f"Creating tileset: {width}x{height} ({TILES_PER_ROW} columns x {rows} rows)")

    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Try to use a monospace font with good Unicode/symbol support
    try:
        # Try different fonts with comprehensive Unicode/CP437 support
        # Priority: fonts with best box-drawing and symbol coverage
        font_paths = [
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",  # Linux DejaVu (best)
            "/System/Library/Fonts/Menlo.ttc",  # macOS Menlo (good Unicode)
            "/System/Library/Fonts/Courier.ttc",  # macOS Courier (fallback)
            "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",  # Linux Liberation
            "C:\\Windows\\Fonts\\DejaVuSansMono.ttf",  # Windows DejaVu
            "C:\\Windows\\Fonts\\consola.ttf",  # Windows Consolas
        ]
        font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                # Use larger font size (48) to fill more of the 64px tile
                font = ImageFont.truetype(font_path, 48)
                print(f"Loaded font: {font_path}")
                break

        if font is None:
            print("Warning: No TrueType font found, using PIL default (limited symbols)")
            # PIL's default font has limited symbol support
            font = ImageFont.load_default()
    except Exception as e:
        print(f"Font loading error: {e}, using default")
        font = ImageFont.load_default()

    # Draw each character in grid layout
    for i, char in enumerate(CHARS):
        row = i // TILES_PER_ROW
        col = i % TILES_PER_ROW
        x_offset = col * TILE_SIZE
        y_offset = row * TILE_SIZE

        color = DEFAULT_COLOR  # All white, colors applied in-game

        # Get text bounding box
        bbox = draw.textbbox((0, 0), char, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]

        # Center the character in the tile
        x = x_offset + (TILE_SIZE - text_width) // 2
        y = y_offset + (TILE_SIZE - text_height) // 2 - bbox[1]

        # Draw the character
        draw.text((x, y), char, fill=color + (255,), font=font)

    # Save the image as unicode_tileset.png (default)
    output_path = os.path.join(os.path.dirname(__file__), "tilesets", "unicode_tileset.png")
    image.save(output_path)
    print(f"Saved CP437/Unicode tileset to: {output_path}")
    print(f"Image size: {width}x{height}")
    print(f"Tile size: {TILE_SIZE}x{TILE_SIZE}")
    print(f"Grid layout: {TILES_PER_ROW} columns x {rows} rows")
    print(f"Number of tiles: {len(CHARS)}")

    # Also save character map for reference
    charmap_path = os.path.join(os.path.dirname(__file__), "tilesets", "unicode_charmap.txt")
    with open(charmap_path, 'w', encoding='utf-8') as f:
        f.write("CP437 (Code Page 437) Character Map\n")
        f.write("=====================================\n")
        f.write("Index  Grid   Unicode  Character\n")
        f.write("-----  ----   -------  ---------\n")
        for i, char in enumerate(CHARS):
            row = i // TILES_PER_ROW
            col = i % TILES_PER_ROW
            f.write(f"{i:4d} ({col:2d},{row:2d}) U+{CP437_MAP[i]:04X}   '{char}'\n")
    print(f"Saved character map to: {charmap_path}")

if __name__ == "__main__":
    create_cp437_tileset()
