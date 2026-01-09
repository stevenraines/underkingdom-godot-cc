# Feature Implementation Plan: Advanced Inventory Screen

**Goal**: Provide a better inventory experience for players as their inventory grows through filtering, sorting, and improved organization.

---

## Overview

The current inventory screen displays all items in a single scrollable list, which becomes difficult to manage as the player collects more items. This feature adds filtering and sorting capabilities to both the inventory screen and shop screen, allowing players to:

1. Filter items by category (Weapons, Armor, Tools, Consumables, Materials, etc.)
2. View items sorted by value (least to most expensive) within each filter
3. Quickly switch between filters using hotkeys
4. Apply the same filtering system to shop screens

---

## Feature Requirements

**From Feature Brief:**
1. **Grouping/Filtering**: View items by type (weapons, tools, consumables) with UI controls
2. **Ordering**: Items sorted from least to most expensive within groups
3. **All Items View**: Still allow viewing entire unfiltered inventory
4. **Shop Integration**: Apply same features to shop screen (both player and shopkeeper inventory)

---

## Current State Analysis

**Existing Inventory System:**
- **Files**: `ui/inventory_screen.gd` and `ui/inventory_screen.tscn`
- **Layout**: Two-panel (Equipment slots + Backpack items)
- **Navigation**: Tab switches panels, arrow keys navigate items
- **Actions**: Equip, Use, Drop, Inscribe/Uninscribe
- **Displays**: Weight, Warmth, Encumbrance status

**Item Categories** (from `data/items/` structure):
- ammunition, armor, books, consumables, materials, misc, seeds, tools, weapons

**Inventory Data** (`systems/inventory_system.gd`):
- Items: `Array[Item]`
- Each item has: `category`, `item_type`, `subtype`, `flags`, `weight`, `value`

---

## Technical Design

### 1. Filter System

**Filter Categories:**
```gdscript
enum FilterType {
    ALL,           # Show everything (default)
    WEAPONS,       # Swords, axes, bows, etc.
    ARMOR,         # All equippable armor pieces
    TOOLS,         # Knives, hammers, waterskins, etc.
    CONSUMABLES,   # Food, bandages, potions
    MATERIALS,     # Crafting materials, ore, leather
    AMMUNITION,    # Arrows, bolts
    BOOKS,         # Recipe books
    SEEDS,         # Farming seeds
    MISC           # Currency, keys, other items
}
```

**Mapping Strategy:**
- Use `Item.category` property (set from folder structure)
- Fallback to `Item.item_type` for legacy items

### 2. Sorting System

**Sort Order** (per filter group):
1. **Primary**: Value (ascending) - cheapest to most expensive
2. **Secondary**: Name (alphabetical) - for same-value items

### 3. UI Layout Enhancement

**Filter Bar** (new component above inventory panel):
```
╔════════════════════════════════════╗
║         INVENTORY                  ║
║ Weight: 12.5/45.0 kg (28%)        ║
╠════════════════════════════════════╣
║ [All] Weapon Tool Armor Consumable ║ ← New filter bar
║ Material Ammo Book Seed Misc       ║
╠════════════════════════════════════╣
║ EQUIPPED:        ║ BACKPACK:       ║
```

**Filter Controls:**
- **Number keys (1-0)**: Quick filter selection
  - `1` = All, `2` = Weapons, `3` = Armor, `4` = Tools, `5` = Consumables
  - `6` = Materials, `7` = Ammunition, `8` = Books, `9` = Seeds, `0` = Misc
- **Left/Right arrows** (in filter mode): Cycle through filters
- **F key**: Toggle filter bar focus

---

## Implementation Plan

### Phase 1: Core Filter Logic (Backend)

**File**: `systems/inventory_system.gd`

**Tasks:**
1. Add FilterType enum definition
2. Implement `get_items_by_filter(filter: FilterType) -> Array[Item]`
3. Implement filtering logic with category matching
4. Implement sorting by value then name

**New Methods:**
```gdscript
func get_items_by_filter(filter: FilterType) -> Array[Item]:
    var filtered = _filter_items(items, filter)
    return _sort_items(filtered)

func _filter_items(item_list: Array[Item], filter: FilterType) -> Array[Item]
func _item_matches_filter(item: Item, filter: FilterType) -> bool
func _sort_items(item_list: Array[Item]) -> Array[Item]
```

### Phase 2: UI Components (Filter Bar)

**File**: `ui/inventory_screen.tscn`

**Tasks:**
1. Add FilterBarContainer HBoxContainer below header panel
2. Create filter labels for each category
3. Add separators for visual organization

**File**: `ui/inventory_screen.gd`

**Tasks:**
1. Add filter state properties (`current_filter`, `filter_bar_focused`)
2. Implement `_update_filter_bar()` for visual feedback
3. Update `_update_inventory_title()` to show filter info
4. Update `_update_inventory_display()` to use filtered items

### Phase 3: Input Handling

**File**: `ui/inventory_screen.gd`

**Tasks:**
1. Add number key handling (1-0) for quick filter selection
2. Add F key for filter bar focus toggle
3. Add left/right arrow cycling when filter bar focused
4. Invalidate cache and refresh on filter change

### Phase 4: Shop Screen Integration

**File**: `ui/shop_screen.gd`

**Tasks:**
1. Add independent filter state for shop and player panels
2. Copy filter bar implementation
3. Apply filters to both inventory displays
4. Handle filter hotkeys for focused panel

### Phase 5: Documentation & Polish

**Tasks:**
1. Update help screen with filter controls
2. Update system documentation
3. Add feature documentation

---

## Files to Modify

**Core Logic:**
- `systems/inventory_system.gd` - Add filter/sort methods

**UI Files:**
- `ui/inventory_screen.tscn` - Add filter bar UI components
- `ui/inventory_screen.gd` - Filter logic, input handling, display updates
- `ui/shop_screen.gd` - Dual-panel filter logic

**Documentation:**
- `ui/help_screen.gd` - Add filter control documentation
- `docs/systems/inventory-system.md` - Document filter API

---

## Testing Checklist

**Filter Functionality:**
- [ ] Number keys 1-0 switch filters correctly
- [ ] F key toggles filter bar focus mode
- [ ] Left/Right arrows cycle filters when filter bar focused
- [ ] ALL filter shows all items
- [ ] Each category filter shows only matching items
- [ ] Empty categories display appropriate message

**Sorting:**
- [ ] Items sorted by value (ascending) within each filter
- [ ] Items with same value sorted alphabetically
- [ ] Stacked items display quantity correctly

**UI Updates:**
- [ ] Active filter highlighted in filter bar
- [ ] Backpack title shows filter name and item count
- [ ] Scroll position resets to top on filter change

**Shop Integration:**
- [ ] Shop panel has independent filter
- [ ] Player panel filter persists
- [ ] Filters apply to focused panel
- [ ] Tab key switches panels without changing filters

---

## Success Criteria

Feature complete when:
1. ✅ Player can filter inventory by 10 categories
2. ✅ Items sorted by value within each filter
3. ✅ Filter controls accessible via number keys and arrow keys
4. ✅ Filter state shown in backpack title
5. ✅ Shop screen supports independent filters
6. ✅ Documentation updated

---

**Document Version**: 1.0
**Last Updated**: January 8, 2026
**Status**: ⬜ Ready for Implementation
