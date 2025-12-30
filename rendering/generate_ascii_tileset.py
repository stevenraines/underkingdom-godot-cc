#!/usr/bin/env python3
"""Generate ASCII tileset sprite sheet for the roguelike game."""

from PIL import Image, ImageDraw, ImageFont
import os
import string

# Configuration
TILE_SIZE = 48  # Increased to 48 for better clarity
TILES_PER_ROW = 16  # Standard 16x6 grid for printable ASCII

# Printable ASCII characters (32-126)
# Space, !"#$%&'()*+,-./0-9:;<=>?@A-Z[\]^_`a-z{|}~
CHARS = [chr(i) for i in range(32, 127)]

# Default white for most characters - we'll override specific ones
DEFAULT_COLOR = (200, 200, 200)

# Special color overrides for game elements
COLOR_OVERRIDES = {
    "@": (255, 255, 0),      # Yellow - Player
    ".": (80, 80, 80),       # Dark Gray - Floor
    "#": (200, 200, 200),    # Light Gray - Wall
    "+": (153, 102, 51),     # Brown - Door
    ">": (0, 255, 255),      # Cyan - Stairs down
    "<": (0, 255, 255),      # Cyan - Stairs up
    "T": (0, 180, 0),        # Green - Tree
    "~": (51, 102, 255),     # Blue - Water
    "r": (140, 69, 18),      # Brown - Grave Rat
    "W": (69, 255, 69),      # Green - Barrow Wight
    "w": (161, 161, 161),    # Gray - Woodland Wolf
    "%": (180, 100, 100),    # Corpse (for future use)
    "$": (255, 215, 0),      # Gold
    "&": (139, 90, 43),      # Chest/container
    "!": (255, 100, 100),    # Potion (for future use)
    "?": (100, 149, 237),    # Scroll (for future use)
}

def create_ascii_tileset():
    """Create a sprite sheet with ASCII characters."""
    # Calculate grid dimensions
    num_chars = len(CHARS)
    rows = (num_chars + TILES_PER_ROW - 1) // TILES_PER_ROW  # Ceiling division

    width = TILES_PER_ROW * TILE_SIZE
    height = rows * TILE_SIZE
    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    # Try to use a monospace font
    try:
        # Try different common monospace fonts
        font_paths = [
            "/System/Library/Fonts/Courier.dfont",  # macOS
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",  # Linux
            "C:\\Windows\\Fonts\\cour.ttf",  # Windows
        ]
        font = None
        for font_path in font_paths:
            if os.path.exists(font_path):
                font = ImageFont.truetype(font_path, 36)  # Increased to 36 for 48px tiles
                break

        if font is None:
            print("Using default font")
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

        color = COLOR_OVERRIDES.get(char, DEFAULT_COLOR)

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
    print(f"Saved ASCII tileset to: {output_path}")
    print(f"Image size: {width}x{height}")
    print(f"Tile size: {TILE_SIZE}x{TILE_SIZE}")
    print(f"Grid layout: {TILES_PER_ROW} columns x {rows} rows")
    print(f"Number of tiles: {len(CHARS)}")

if __name__ == "__main__":
    create_ascii_tileset()
