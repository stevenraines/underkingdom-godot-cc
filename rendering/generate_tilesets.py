#!/usr/bin/env python3
"""Generate both CP437 and Unicode tileset sprite sheets for the roguelike game."""

from PIL import Image, ImageDraw, ImageFont
import os

# Configuration
TILE_WIDTH = 38   # Width optimized for monospace fonts
TILE_HEIGHT = 64  # Height for good vertical spacing
DEFAULT_COLOR = (255, 255, 255)  # All white - colors applied via Godot modulation
FONT_SIZE = 52  # Slightly smaller for regular weight fonts

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

# Greek and Coptic (0x0370-0x03FF) - 144 chars
# Includes Δ (Delta), Ω (Omega), α, β, γ, etc.
UNICODE_CHARS.extend([chr(i) for i in range(0x0370, 0x0400)])

# Mathematical Operators (0x2200-0x22FF) - 256 chars
# Includes ∴ (therefore), ∞ (infinity), ∑ (summation), √ (square root), etc.
UNICODE_CHARS.extend([chr(i) for i in range(0x2200, 0x2300)])

# Miscellaneous Technical (0x2300-0x23FF) - 256 chars
# Includes ⌂ (House), ⌐ (Reversed Not), ⌠ (Top Half Integral), etc.
UNICODE_CHARS.extend([chr(i) for i in range(0x2300, 0x2400)])

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


def get_project_fonts_dir():
    """Get the fonts directory in the project."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(os.path.dirname(script_dir), "fonts")


def load_font():
    """Load a monospace font with good Unicode support (regular weight, not bold)."""
    fonts_dir = get_project_fonts_dir()

    font_paths = [
        # Project Noto fonts - prefer variable font for regular weight
        os.path.join(fonts_dir, "NotoSansMono-VariableFont_wdth,wght.ttf"),
        # System fallbacks
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",  # Linux DejaVu
        "/System/Library/Fonts/Menlo.ttc",  # macOS Menlo
        "/System/Library/Fonts/Courier.ttc",  # macOS Courier
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",  # Linux Liberation
        "C:\\Windows\\Fonts\\DejaVuSansMono.ttf",  # Windows DejaVu
        "C:\\Windows\\Fonts\\consola.ttf",  # Windows Consolas
    ]

    for font_path in font_paths:
        if os.path.exists(font_path):
            font = ImageFont.truetype(font_path, FONT_SIZE)
            print(f"Loaded font: {font_path}")
            return font

    print("Warning: No TrueType font found, using PIL default")
    return ImageFont.load_default()


def load_symbol_fonts():
    """Load symbol fonts for characters not in the main font."""
    fonts_dir = get_project_fonts_dir()
    symbol_fonts = []

    # Order matters: Noto Symbols 1 first, then Noto Symbols 2 as fallback
    symbol_font_paths = [
        os.path.join(fonts_dir, "NotoSansSymbols-Regular.ttf"),
        os.path.join(fonts_dir, "NotoSansSymbols2-Regular.ttf"),
    ]

    for font_path in symbol_font_paths:
        if os.path.exists(font_path):
            font = ImageFont.truetype(font_path, FONT_SIZE)
            print(f"Loaded symbol font: {font_path}")
            symbol_fonts.append(font)

    return symbol_fonts


# Cache for tofu pixel counts per font
_tofu_cache = {}


def get_tofu_pixels(font):
    """Get the pixel count of the 'tofu' (missing glyph) box for a font."""
    font_id = id(font)
    if font_id not in _tofu_cache:
        # Render a character that definitely doesn't exist
        img = Image.new('L', (100, 100), 0)
        draw = ImageDraw.Draw(img)
        draw.text((10, 10), chr(0xFFFF), fill=255, font=font)
        pixels = sum(1 for p in img.getdata() if p > 0)
        _tofu_cache[font_id] = pixels
    return _tofu_cache[font_id]


def font_has_glyph(font, char):
    """Check if a font has a real glyph for a character (not the tofu box).

    Uses pixel-based comparison: if rendering produces the same number of
    pixels as the missing glyph box, it's probably tofu.
    """
    # Spaces are special - they have no pixels but are valid
    if char in (' ', '\u00A0'):
        return True

    try:
        # Render the character
        img = Image.new('L', (100, 100), 0)
        draw = ImageDraw.Draw(img)
        draw.text((10, 10), char, fill=255, font=font)
        pixels = sum(1 for p in img.getdata() if p > 0)

        # Compare to tofu - if same pixel count, likely missing
        tofu_pixels = get_tofu_pixels(font)

        # Allow some variance (within 5%) to account for similar-looking glyphs
        # but if it's exactly the tofu count, reject it
        if pixels == tofu_pixels:
            return False

        # Also reject if no pixels at all (except spaces handled above)
        if pixels == 0:
            return False

        return True
    except:
        return False


def should_use_symbol_font(char):
    """Check if a character should prefer symbol fonts over the main font.

    Symbol fonts have better glyphs for these Unicode ranges:
    - Miscellaneous Technical (0x2300-0x23FF)
    - Miscellaneous Symbols (0x2600-0x26FF) - includes ☦ (U+2626)
    - Dingbats (0x2700-0x27BF)
    - Geometric Shapes (0x25A0-0x25FF)
    """
    codepoint = ord(char)

    # Ranges where symbol fonts are preferred
    symbol_ranges = [
        (0x2300, 0x23FF),  # Miscellaneous Technical
        (0x25A0, 0x25FF),  # Geometric Shapes
        (0x2600, 0x26FF),  # Miscellaneous Symbols (☦ is here at U+2626)
        (0x2700, 0x27BF),  # Dingbats
    ]

    for start, end in symbol_ranges:
        if start <= codepoint <= end:
            return True
    return False


def render_char_to_tile(char, font, tile_width, tile_height):
    """Render a character to a tile image, scaling if necessary to fit."""
    # First, render at full size to measure
    temp_img = Image.new('RGBA', (tile_width * 3, tile_height * 2), (0, 0, 0, 0))
    temp_draw = ImageDraw.Draw(temp_img)

    # Draw at origin to measure
    bbox = temp_draw.textbbox((0, 0), char, font=font)
    if bbox is None:
        bbox = (0, 0, 0, 0)

    char_width = bbox[2] - bbox[0]
    char_height = bbox[3] - bbox[1]

    # Check if we need to scale
    max_width = tile_width - 2  # Leave 1px padding on each side
    max_height = tile_height - 4  # Leave 2px padding top/bottom

    needs_scale = char_width > max_width or char_height > max_height

    if needs_scale and char_width > 0 and char_height > 0:
        # Calculate scale factor to fit
        scale_x = max_width / char_width
        scale_y = max_height / char_height
        scale = min(scale_x, scale_y)

        # Render at larger size for quality
        large_size = (int(char_width * 2), int(char_height * 2))
        large_img = Image.new('RGBA', large_size, (0, 0, 0, 0))
        large_draw = ImageDraw.Draw(large_img)
        large_draw.text((-bbox[0], -bbox[1]), char, fill=DEFAULT_COLOR + (255,), font=font)

        # Scale down
        new_width = max(1, int(char_width * scale))
        new_height = max(1, int(char_height * scale))
        scaled_img = large_img.resize((new_width, new_height), Image.LANCZOS)

        # Create final tile and paste centered
        tile_img = Image.new('RGBA', (tile_width, tile_height), (0, 0, 0, 0))
        x = (tile_width - new_width) // 2
        y = (tile_height - new_height) // 2
        tile_img.paste(scaled_img, (x, y))

        return tile_img
    else:
        # No scaling needed, render directly centered
        tile_img = Image.new('RGBA', (tile_width, tile_height), (0, 0, 0, 0))
        tile_draw = ImageDraw.Draw(tile_img)

        x = (tile_width - char_width) // 2 - bbox[0]
        y = (tile_height - char_height) // 2 - bbox[1]

        tile_draw.text((x, y), char, fill=DEFAULT_COLOR + (255,), font=font)

        return tile_img


def create_cp437_tileset():
    """Create CP437 tileset (ascii_tileset.png) - 256 characters, 16x16 grid."""
    num_chars = len(CP437_CHARS)
    rows = (num_chars + CP437_TILES_PER_ROW - 1) // CP437_TILES_PER_ROW
    width = CP437_TILES_PER_ROW * TILE_WIDTH
    height = rows * TILE_HEIGHT

    print(f"\nCreating CP437 tileset: {width}x{height} ({CP437_TILES_PER_ROW} columns x {rows} rows)")

    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    font = load_font()

    # Draw each character
    for i, char in enumerate(CP437_CHARS):
        row = i // CP437_TILES_PER_ROW
        col = i % CP437_TILES_PER_ROW
        x_offset = col * TILE_WIDTH
        y_offset = row * TILE_HEIGHT

        tile = render_char_to_tile(char, font, TILE_WIDTH, TILE_HEIGHT)
        image.paste(tile, (x_offset, y_offset))

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
    main_font = load_font()
    symbol_fonts = load_symbol_fonts()

    missing_chars = []
    symbol_font_used = 0
    scaled_chars = 0

    # Draw each character
    for i, char in enumerate(UNICODE_CHARS):
        row = i // UNICODE_TILES_PER_ROW
        col = i % UNICODE_TILES_PER_ROW
        x_offset = col * TILE_WIDTH
        y_offset = row * TILE_HEIGHT

        # Find a font that has this character
        # For symbol ranges, prefer symbol fonts over the main mono font
        selected_font = None

        if should_use_symbol_font(char):
            # Try symbol fonts first for characters in symbol ranges
            for font in symbol_fonts:
                if font_has_glyph(font, char):
                    selected_font = font
                    symbol_font_used += 1
                    break
            # Fall back to main font if symbol fonts don't have it
            if selected_font is None and font_has_glyph(main_font, char):
                selected_font = main_font
        else:
            # For non-symbol characters, try main font first
            if font_has_glyph(main_font, char):
                selected_font = main_font
            else:
                # Fall back to symbol fonts
                for font in symbol_fonts:
                    if font_has_glyph(font, char):
                        selected_font = font
                        symbol_font_used += 1
                        break

        if selected_font is None:
            # No font has this glyph - leave tile empty
            missing_chars.append((char, hex(ord(char))))
            continue

        # Render the character to a tile (with scaling if needed)
        tile = render_char_to_tile(char, selected_font, TILE_WIDTH, TILE_HEIGHT)
        image.paste(tile, (x_offset, y_offset))

    print(f"\nSymbol fonts used for {symbol_font_used} characters")

    if missing_chars:
        print(f"Warning: {len(missing_chars)} characters missing from all fonts (left empty):")
        for char, code in missing_chars[:20]:  # Show first 20
            print(f"  {code}: '{char}'")
        if len(missing_chars) > 20:
            print(f"  ... and {len(missing_chars) - 20} more")

    # Save Unicode tileset
    output_path = os.path.join(os.path.dirname(__file__), "tilesets", "unicode_tileset.png")
    image.save(output_path)
    print(f"\nSaved Unicode tileset to: {output_path}")
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
