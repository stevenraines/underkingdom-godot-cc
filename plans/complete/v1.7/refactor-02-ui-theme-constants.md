# Refactor 02: UI Theme Constants

**Risk Level**: Zero
**Estimated Changes**: 1 new file, 22+ files updated

---

## Goal

Create a centralized `UITheme` autoload containing all shared UI color constants, eliminating duplication across 22+ UI files.

---

## Current State

Multiple UI files define identical or similar color constants:

**inventory_screen.gd (lines 72-78):**
```gdscript
const COLOR_SELECTED = Color(0.2, 0.4, 0.3, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_EMPTY = Color(0.4, 0.4, 0.4, 1.0)
const COLOR_EQUIPPED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.6, 1.0)
const COLOR_PANEL_ACTIVE = Color(0.8, 0.8, 0.5, 1.0)
const COLOR_PANEL_INACTIVE = Color(0.5, 0.5, 0.4, 1.0)
```

**shop_screen.gd (lines 59-64):**
```gdscript
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
const COLOR_POSITIVE = Color(0.6, 0.9, 0.6, 1.0)
const COLOR_NEGATIVE = Color(0.9, 0.5, 0.5, 1.0)
const COLOR_GOLD = Color(0.9, 0.7, 0.2, 1.0)
```

Similar patterns found in: container_screen.gd, level_up_screen.gd, crafting_screen.gd, character_sheet.gd, spell_list_screen.gd, and 15+ other UI files.

---

## Implementation

### Step 1: Create autoload/ui_theme.gd

Create new file `autoload/ui_theme.gd`:

```gdscript
class_name UIThemeConfig
extends Node

## UITheme - Centralized UI styling constants
##
## Use UITheme.COLOR_* throughout UI code for consistent theming.
## This allows easy theme changes and ensures visual consistency.

# =============================================================================
# SELECTION & FOCUS COLORS
# =============================================================================

## Color for currently selected/focused items
const COLOR_SELECTED = Color(0.2, 0.4, 0.3, 1.0)

## Alternative selection color (for shop, gold-tinted)
const COLOR_SELECTED_GOLD = Color(0.9, 0.85, 0.5, 1.0)

## Hover/highlight color for emphasized items
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.6, 1.0)

## Normal/unselected item color
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)

## Color for empty slots or placeholders
const COLOR_EMPTY = Color(0.4, 0.4, 0.4, 1.0)

## Color for disabled/unavailable items
const COLOR_DISABLED = Color(0.5, 0.5, 0.5, 1.0)

# =============================================================================
# FEEDBACK COLORS
# =============================================================================

## Positive feedback (healing, buffs, affordable)
const COLOR_POSITIVE = Color(0.6, 0.9, 0.6, 1.0)

## Negative feedback (damage, debuffs, expensive)
const COLOR_NEGATIVE = Color(0.9, 0.5, 0.5, 1.0)

## Warning feedback (low health, encumbered)
const COLOR_WARNING = Color(0.9, 0.7, 0.2, 1.0)

## Gold/currency color
const COLOR_GOLD = Color(0.9, 0.7, 0.2, 1.0)

# =============================================================================
# EQUIPMENT & ITEM COLORS
# =============================================================================

## Color for equipped items in inventory
const COLOR_EQUIPPED = Color(0.9, 0.85, 0.5, 1.0)

## Color for magical/enchanted items
const COLOR_MAGICAL = Color(0.6, 0.7, 1.0, 1.0)

## Color for rare items
const COLOR_RARE = Color(0.8, 0.6, 1.0, 1.0)

## Color for cursed items
const COLOR_CURSED = Color(0.8, 0.3, 0.3, 1.0)

# =============================================================================
# PANEL & SECTION COLORS
# =============================================================================

## Active panel title/border color
const COLOR_PANEL_ACTIVE = Color(0.8, 0.8, 0.5, 1.0)

## Inactive panel title/border color
const COLOR_PANEL_INACTIVE = Color(0.5, 0.5, 0.4, 1.0)

## Section header color
const COLOR_SECTION_HEADER = Color(0.8, 0.8, 0.5, 1.0)

## Label text color
const COLOR_LABEL = Color(0.85, 0.85, 0.7, 1.0)

## Value text color
const COLOR_VALUE = Color(0.7, 0.9, 0.7, 1.0)

# =============================================================================
# BACKGROUND COLORS
# =============================================================================

## Standard panel background
const PANEL_BG_COLOR = Color(0.08, 0.08, 0.12, 0.98)

## Darker panel background for contrast
const PANEL_BG_DARK = Color(0.05, 0.05, 0.08, 0.98)

## Lighter panel background for emphasis
const PANEL_BG_LIGHT = Color(0.12, 0.12, 0.16, 0.98)

# =============================================================================
# STAT CHANGE COLORS
# =============================================================================

## Stat increase color
const COLOR_STAT_UP = Color(0.5, 1.0, 0.5, 1.0)

## Stat decrease color
const COLOR_STAT_DOWN = Color(1.0, 0.5, 0.5, 1.0)

## Stat neutral/unchanged color
const COLOR_STAT_NEUTRAL = Color(0.8, 0.8, 0.8, 1.0)

# =============================================================================
# MESSAGE LOG COLORS
# =============================================================================

## Combat damage message color
const COLOR_MSG_DAMAGE = Color(1.0, 0.6, 0.6, 1.0)

## Healing message color
const COLOR_MSG_HEAL = Color(0.6, 1.0, 0.6, 1.0)

## System/info message color
const COLOR_MSG_INFO = Color(0.7, 0.7, 0.9, 1.0)

## Important/alert message color
const COLOR_MSG_ALERT = Color(1.0, 0.9, 0.4, 1.0)
```

---

### Step 2: Register as Autoload

In `project.godot`, add after existing autoloads (around line 52):

```ini
UITheme="*res://autoload/ui_theme.gd"
```

---

### Step 3: Update UI Files

For each UI file, replace local color constants with `UITheme.COLOR_*` references.

**Example for inventory_screen.gd:**

Remove lines 72-78:
```gdscript
# REMOVE THESE:
const COLOR_SELECTED = Color(0.2, 0.4, 0.3, 1.0)
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)
# ... etc
```

Replace usages throughout the file:
```gdscript
# Before:
label.modulate = COLOR_SELECTED
# After:
label.modulate = UITheme.COLOR_SELECTED
```

---

### Files to Update

| File | Local Constants to Remove |
|------|--------------------------|
| `ui/inventory_screen.gd` | COLOR_SELECTED, COLOR_NORMAL, COLOR_EMPTY, COLOR_EQUIPPED, COLOR_HIGHLIGHT, COLOR_PANEL_ACTIVE, COLOR_PANEL_INACTIVE |
| `ui/shop_screen.gd` | COLOR_SELECTED, COLOR_NORMAL, COLOR_POSITIVE, COLOR_NEGATIVE, COLOR_GOLD |
| `ui/container_screen.gd` | COLOR_SELECTED, COLOR_NORMAL, COLOR_EMPTY |
| `ui/level_up_screen.gd` | COLOR_SELECTED, COLOR_NORMAL, COLOR_POSITIVE, COLOR_NEGATIVE |
| `ui/crafting_screen.gd` | COLOR_SELECTED, COLOR_NORMAL, COLOR_DISABLED |
| `ui/character_sheet.gd` | COLOR_LABEL, COLOR_VALUE, COLOR_SECTION_HEADER |
| `ui/spell_list_screen.gd` | COLOR_SELECTED, COLOR_NORMAL, COLOR_DISABLED |
| `ui/ritual_screen.gd` | COLOR_SELECTED, COLOR_NORMAL, COLOR_DISABLED |
| `ui/special_actions_screen.gd` | COLOR_SELECTED, COLOR_NORMAL |
| `ui/world_map_screen.gd` | COLOR_* constants |
| `ui/help_screen.gd` | COLOR_* constants |
| `ui/targeting_overlay.gd` | COLOR_* constants |
| (and remaining UI files) | Check for local color constants |

---

### Step 4: Search and Replace Pattern

For each file, use these replacements (note some files may use different names):

| Old | New |
|-----|-----|
| `COLOR_SELECTED` | `UITheme.COLOR_SELECTED` |
| `COLOR_NORMAL` | `UITheme.COLOR_NORMAL` |
| `COLOR_EMPTY` | `UITheme.COLOR_EMPTY` |
| `COLOR_EQUIPPED` | `UITheme.COLOR_EQUIPPED` |
| `COLOR_HIGHLIGHT` | `UITheme.COLOR_HIGHLIGHT` |
| `COLOR_POSITIVE` | `UITheme.COLOR_POSITIVE` |
| `COLOR_NEGATIVE` | `UITheme.COLOR_NEGATIVE` |
| `COLOR_GOLD` | `UITheme.COLOR_GOLD` |
| `COLOR_WARNING` | `UITheme.COLOR_WARNING` |
| `COLOR_DISABLED` | `UITheme.COLOR_DISABLED` |
| `COLOR_PANEL_ACTIVE` | `UITheme.COLOR_PANEL_ACTIVE` |
| `COLOR_PANEL_INACTIVE` | `UITheme.COLOR_PANEL_INACTIVE` |
| `COLOR_SECTION_HEADER` | `UITheme.COLOR_SECTION_HEADER` |
| `COLOR_LABEL` | `UITheme.COLOR_LABEL` |
| `COLOR_VALUE` | `UITheme.COLOR_VALUE` |

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Open Inventory screen (I) - colors correct
- [ ] Open Shop screen (talk to merchant) - colors correct
- [ ] Open Character sheet (C) - colors correct
- [ ] Open Crafting screen (R) - colors correct
- [ ] Open Spell list (Z) - colors correct
- [ ] Open Level up screen (gain a level) - colors correct
- [ ] Open Help screen (?) - colors correct
- [ ] Open Container (chest) - colors correct
- [ ] Test selection highlighting in all screens
- [ ] Test hover states work correctly
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- autoload/ui_theme.gd
git checkout HEAD -- project.godot
git checkout HEAD -- ui/
```

Or revert entire commit:
```bash
git revert HEAD
```
