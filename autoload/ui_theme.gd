class_name UIThemeConfig
extends Node

## UITheme - Centralized UI styling constants
##
## Use UITheme.COLOR_* throughout UI code for consistent theming.
## This allows easy theme changes and ensures visual consistency.

# =============================================================================
# SELECTION & FOCUS COLORS
# =============================================================================

## Color for currently selected/focused items (inventory/spell style - green tint)
const COLOR_SELECTED = Color(0.2, 0.4, 0.3, 1.0)

## Alternative selection color (for shop, dialogs - gold tinted)
const COLOR_SELECTED_GOLD = Color(0.9, 0.85, 0.5, 1.0)

## Hover/highlight color for emphasized items
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.6, 1.0)

## Hover color for menu items
const COLOR_HOVER = Color(0.8, 0.8, 0.6, 1.0)

## Normal/unselected item color
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)

## Color for unselected items (slightly darker than normal)
const COLOR_UNSELECTED = Color(0.6, 0.6, 0.6, 1.0)

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

## Error feedback
const COLOR_ERROR = Color(1.0, 0.4, 0.4, 1.0)

## Gold/currency color
const COLOR_GOLD = Color(0.9, 0.7, 0.2, 1.0)

## Affordable price color
const COLOR_AFFORDABLE = Color(0.6, 0.9, 0.6, 1.0)

## Expensive/unaffordable price color
const COLOR_EXPENSIVE = Color(0.9, 0.5, 0.5, 1.0)

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
const COLOR_SECTION = Color(0.8, 0.8, 0.5, 1.0)

## Label text color
const COLOR_LABEL = Color(0.85, 0.85, 0.7, 1.0)

## Value text color
const COLOR_VALUE = Color(0.7, 0.9, 0.7, 1.0)

## Pending/temporary value color
const COLOR_PENDING = Color(1.0, 0.85, 0.3, 1.0)

# =============================================================================
# HELP SCREEN COLORS
# =============================================================================

## Key binding color
const COLOR_KEY = Color(0.7, 0.9, 0.7, 1.0)

## Description text color
const COLOR_DESC = Color(0.85, 0.85, 0.7, 1.0)

## Tip text color
const COLOR_TIP = Color(0.8, 0.8, 0.7, 1.0)

# =============================================================================
# SPECIAL ABILITY COLORS
# =============================================================================

## Color for class feats
const COLOR_FEAT = Color(0.9, 0.7, 0.3, 1.0)

## Color for racial traits
const COLOR_TRAIT = Color(0.3, 0.8, 0.9, 1.0)

## Color for usable abilities
const COLOR_USABLE = Color(0.5, 1.0, 0.5, 1.0)

## Color for exhausted abilities
const COLOR_EXHAUSTED = Color(1.0, 0.5, 0.5, 1.0)

## Requirements met color
const COLOR_REQ_MET = Color(0.5, 1.0, 0.5, 1.0)

## Requirements not met color
const COLOR_REQ_NOT_MET = Color(1.0, 0.5, 0.5, 1.0)

# =============================================================================
# MAGIC SYSTEM COLORS
# =============================================================================

## Mana/magic energy color
const COLOR_MANA = Color(0.3, 0.6, 1.0, 1.0)

## Ritual spell color
const COLOR_RITUAL = Color(0.8, 0.4, 1.0, 1.0)

## Purple accent color
const COLOR_PURPLE = Color(0.6, 0.4, 0.8, 1.0)

# =============================================================================
# DEBUG MENU COLORS
# =============================================================================

## Category header in debug menu
const COLOR_CATEGORY = Color(0.9, 0.5, 0.3, 1.0)

## Command text in debug menu
const COLOR_COMMAND = Color(0.8, 0.8, 0.8, 1.0)

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
