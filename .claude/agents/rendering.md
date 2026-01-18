# Rendering Domain Knowledge

Use this agent when implementing or modifying rendering, ASCII display, tileset handling, or visual systems.

---

## Rendering Abstraction

Game logic never touches visuals directly:
```
Game Logic (positions, states)
    ↓ events/state
RenderInterface (abstract)
    ↓ concrete implementation
ASCIIRenderer (TileMapLayer-based)
```

**Current Implementation**: ASCIIRenderer using Unicode tileset (895 characters, 32-column grid)
- Rectangular tiles (38×64 pixels) optimized for monospace fonts
- Two TileMapLayer nodes: TerrainLayer (floors/walls) + EntityLayer (entities/items)
- Runtime color modulation via white tiles + modulated_cells dictionaries
- Floor hiding system: periods don't render when entities stand on them

**Future**: Graphics renderer can swap in without touching game logic

---

## Unicode Tileset

- **File**: `rendering/tilesets/unicode_tileset.png`
- **Dimensions**: 1216×1792 pixels (32 cols × 28 rows)
- **Tile Size**: 38×64 pixels (rectangular, not square)
- **Characters**: 895 total (Basic Latin, Latin-1, Box Drawing, Block Elements, Geometric Shapes, Symbols, Dingbats)
- **Font**: DejaVu Sans Mono (58pt), generated via Python PIL

---

## Character Mapping

Built-in `unicode_char_map` dictionary in `ascii_renderer.gd`:
- Maps character → tileset index
- Index → grid coords: `col = index % 32, row = index / 32`

---

## Color Modulation

- All tiles rendered white in tileset
- Runtime coloring via `modulated_cells` dictionaries
- Separate tracking for terrain + entity layers
- Custom tile data override for modulation

---

## Floor Hiding System

When entities/items render:
1. Check if standing on floor tile (period ".")
2. Store floor data in `hidden_floor_positions` dictionary
3. Erase floor tile from TerrainLayer
4. When entity moves, restore floor tile from stored data

---

## Key Files

- `rendering/render_interface.gd` - Abstract interface
- `rendering/ascii_renderer.gd` - TileMapLayer implementation
- `rendering/generate_tilesets.py` - Python script (PIL) for tileset generation
- `rendering/tilesets/unicode_tileset.png` - Main tileset
- `rendering/tilesets/ascii_tileset.png` - CP437 tileset
- `rendering/tilesets/*.txt` - Character maps
