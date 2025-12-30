#!/usr/bin/env python3
"""Generate Extended ASCII tileset sprite sheet for the roguelike game."""

from PIL import Image, ImageDraw, ImageFont
import os
import string

# Configuration
TILE_SIZE = 64  # Increased to 64 for better clarity
TILES_PER_ROW = 16  # 16x16 grid for 256 characters

# Extended ASCII characters (0-255)
# Includes all ASCII (0-127) and Extended ASCII (128-255)
CHARS = [chr(i) for i in range(256)]

print(f"Total characters: {len(CHARS)}")

# All characters white - colors will be applied via Godot's modulation
DEFAULT_COLOR = (255, 255, 255)

def create_extended_ascii_tileset():
    """Create a sprite sheet with Extended ASCII characters (0-255)."""
    # Calculate grid dimensions
    num_chars = len(CHARS)
    rows = (num_chars + TILES_PER_ROW - 1) // TILES_PER_ROW  # Ceiling division

    width = TILES_PER_ROW * TILE_SIZE
    height = rows * TILE_SIZE

    print(f"Creating tileset: {width}x{height} ({TILES_PER_ROW} columns x {rows} rows)")

    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Try to use a monospace font
    try:
        # Try different common monospace fonts with much larger size
        font_paths = [
            "/System/Library/Fonts/Courier.ttc",  # macOS (TrueType Collection)
            "/System/Library/Fonts/Monaco.ttf",  # macOS alternative
            "/System/Library/Fonts/Menlo.ttc",  # macOS Menlo
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",  # Linux
            "C:\\Windows\\Fonts\\consola.ttf",  # Windows (Consolas)
            "C:\\Windows\\Fonts\\cour.ttf",  # Windows (Courier)
        ]
        font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                # Use larger font size (48) to fill more of the 64px tile
                font = ImageFont.truetype(font_path, 48)
                print(f"Loaded font: {font_path}")
                break

        if font is None:
            print("Warning: No TrueType font found, using PIL default (very small)")
            # PIL's default font is tiny - we'll use it but warn
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

    # Save the image
    output_path = os.path.join(os.path.dirname(__file__), "tilesets", "ascii_tileset.png")
    image.save(output_path)
    print(f"Saved Extended ASCII tileset to: {output_path}")
    print(f"Image size: {width}x{height}")
    print(f"Tile size: {TILE_SIZE}x{TILE_SIZE}")
    print(f"Grid layout: {TILES_PER_ROW} columns x {rows} rows")
    print(f"Number of tiles: {len(CHARS)}")

    # Also save character map for reference
    charmap_path = os.path.join(os.path.dirname(__file__), "tilesets", "ascii_charmap.txt")
    with open(charmap_path, 'w', encoding='utf-8') as f:
        for i, char in enumerate(CHARS):
            row = i // TILES_PER_ROW
            col = i % TILES_PER_ROW
            f.write(f"{i:4d} ({col:2d},{row:2d}) ASCII {i:3d} '{char}'\n")
    print(f"Saved character map to: {charmap_path}")

if __name__ == "__main__":
    create_extended_ascii_tileset()
