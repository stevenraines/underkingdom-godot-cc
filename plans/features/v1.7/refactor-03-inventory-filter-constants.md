# Refactor 03: Inventory Filter Constants

**Risk Level**: Zero
**Estimated Changes**: 3 files modified

---

## Goal

Move duplicated `FILTER_LABELS` and `FILTER_HOTKEYS` constants from `inventory_screen.gd` and `shop_screen.gd` into the `Inventory` class in `inventory_system.gd`.

---

## Current State

### inventory_screen.gd (lines 110-134)
```gdscript
const FILTER_LABELS = {
    Inventory.FilterType.ALL: "All",
    Inventory.FilterType.WEAPONS: "Weapons",
    Inventory.FilterType.ARMOR: "Armor",
    Inventory.FilterType.TOOLS: "Tools",
    Inventory.FilterType.CONSUMABLES: "Consumables",
    Inventory.FilterType.MATERIALS: "Materials",
    Inventory.FilterType.AMMUNITION: "Ammo",
    Inventory.FilterType.BOOKS: "Books",
    Inventory.FilterType.SEEDS: "Seeds",
    Inventory.FilterType.MISC: "Misc"
}

const FILTER_HOTKEYS = {
    KEY_1: Inventory.FilterType.ALL,
    KEY_2: Inventory.FilterType.WEAPONS,
    KEY_3: Inventory.FilterType.ARMOR,
    KEY_4: Inventory.FilterType.TOOLS,
    KEY_5: Inventory.FilterType.CONSUMABLES,
    KEY_6: Inventory.FilterType.MATERIALS,
    KEY_7: Inventory.FilterType.AMMUNITION,
    KEY_8: Inventory.FilterType.BOOKS,
    KEY_9: Inventory.FilterType.SEEDS,
    KEY_0: Inventory.FilterType.MISC
}
```

### shop_screen.gd (lines 78-103)
Identical constants (with comment "shared with inventory screen" but actually duplicated):
```gdscript
# Filter hotkeys (shared with inventory screen)
const FILTER_HOTKEYS = { ... }  # IDENTICAL
const FILTER_LABELS = { ... }   # IDENTICAL
```

---

## Implementation

### Step 1: Update systems/inventory_system.gd

Add the constants to the `Inventory` class after the `FilterType` enum (around line 580):

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

## Display labels for filter types (used by UI screens)
const FILTER_LABELS: Dictionary = {
    FilterType.ALL: "All",
    FilterType.WEAPONS: "Weapons",
    FilterType.ARMOR: "Armor",
    FilterType.TOOLS: "Tools",
    FilterType.CONSUMABLES: "Consumables",
    FilterType.MATERIALS: "Materials",
    FilterType.AMMUNITION: "Ammo",
    FilterType.BOOKS: "Books",
    FilterType.SEEDS: "Seeds",
    FilterType.MISC: "Misc"
}

## Keyboard shortcuts for filter selection (used by UI screens)
const FILTER_HOTKEYS: Dictionary = {
    KEY_1: FilterType.ALL,
    KEY_2: FilterType.WEAPONS,
    KEY_3: FilterType.ARMOR,
    KEY_4: FilterType.TOOLS,
    KEY_5: FilterType.CONSUMABLES,
    KEY_6: FilterType.MATERIALS,
    KEY_7: FilterType.AMMUNITION,
    KEY_8: FilterType.BOOKS,
    KEY_9: FilterType.SEEDS,
    KEY_0: FilterType.MISC
}
```

---

### Step 2: Update ui/inventory_screen.gd

**Remove** lines 110-134 (the local FILTER_LABELS and FILTER_HOTKEYS constants).

**Replace** all usages:

| Old | New |
|-----|-----|
| `FILTER_LABELS` | `Inventory.FILTER_LABELS` |
| `FILTER_HOTKEYS` | `Inventory.FILTER_HOTKEYS` |

**Example changes:**

```gdscript
# Before (around line 148):
if FILTER_HOTKEYS.has(event.keycode):
    current_filter = FILTER_HOTKEYS[event.keycode]

# After:
if Inventory.FILTER_HOTKEYS.has(event.keycode):
    current_filter = Inventory.FILTER_HOTKEYS[event.keycode]
```

```gdscript
# Before (in _update_filter_bar):
var label_text = "[%d] %s" % [hotkey, FILTER_LABELS[filter_type]]

# After:
var label_text = "[%d] %s" % [hotkey, Inventory.FILTER_LABELS[filter_type]]
```

---

### Step 3: Update ui/shop_screen.gd

**Remove** lines 78-103 (the local FILTER_LABELS and FILTER_HOTKEYS constants).

**Replace** all usages:

| Old | New |
|-----|-----|
| `FILTER_LABELS` | `Inventory.FILTER_LABELS` |
| `FILTER_HOTKEYS` | `Inventory.FILTER_HOTKEYS` |

**Example changes:**

```gdscript
# Before (around line 120):
if FILTER_HOTKEYS.has(event.keycode):
    if is_shop_focused:
        shop_filter = FILTER_HOTKEYS[event.keycode]

# After:
if Inventory.FILTER_HOTKEYS.has(event.keycode):
    if is_shop_focused:
        shop_filter = Inventory.FILTER_HOTKEYS[event.keycode]
```

---

## Complete Diff Summary

### inventory_system.gd
```diff
 enum FilterType {
     ALL,
     WEAPONS,
     ARMOR,
     TOOLS,
     CONSUMABLES,
     MATERIALS,
     AMMUNITION,
     BOOKS,
     SEEDS,
     MISC
 }

+## Display labels for filter types (used by UI screens)
+const FILTER_LABELS: Dictionary = {
+    FilterType.ALL: "All",
+    FilterType.WEAPONS: "Weapons",
+    FilterType.ARMOR: "Armor",
+    FilterType.TOOLS: "Tools",
+    FilterType.CONSUMABLES: "Consumables",
+    FilterType.MATERIALS: "Materials",
+    FilterType.AMMUNITION: "Ammo",
+    FilterType.BOOKS: "Books",
+    FilterType.SEEDS: "Seeds",
+    FilterType.MISC: "Misc"
+}
+
+## Keyboard shortcuts for filter selection (used by UI screens)
+const FILTER_HOTKEYS: Dictionary = {
+    KEY_1: FilterType.ALL,
+    KEY_2: FilterType.WEAPONS,
+    KEY_3: FilterType.ARMOR,
+    KEY_4: FilterType.TOOLS,
+    KEY_5: FilterType.CONSUMABLES,
+    KEY_6: FilterType.MATERIALS,
+    KEY_7: FilterType.AMMUNITION,
+    KEY_8: FilterType.BOOKS,
+    KEY_9: FilterType.SEEDS,
+    KEY_0: FilterType.MISC
+}
+
 ## Get all items as array (for UI display)
 func get_all_items() -> Array[Item]:
```

### inventory_screen.gd
```diff
-# Filter configuration
-const FILTER_LABELS = {
-    Inventory.FilterType.ALL: "All",
-    ... (24 lines removed)
-}
-
-const FILTER_HOTKEYS = {
-    KEY_1: Inventory.FilterType.ALL,
-    ... (24 lines removed)
-}
```

Then replace all occurrences of `FILTER_LABELS` with `Inventory.FILTER_LABELS` and `FILTER_HOTKEYS` with `Inventory.FILTER_HOTKEYS`.

### shop_screen.gd
Same changes as inventory_screen.gd - remove local constants and update references.

---

## Verification Checklist

After completing all changes:

- [ ] Game launches without errors
- [ ] Open Inventory (I key)
  - [ ] Press 1-0 keys to filter items
  - [ ] Filter labels display correctly in filter bar
  - [ ] Correct items shown for each filter
- [ ] Open Shop (talk to merchant)
  - [ ] Press 1-0 keys to filter shop/player items
  - [ ] Filter labels display correctly
  - [ ] Correct items shown for each filter
- [ ] Filters work identically to before
- [ ] No new console warnings/errors

---

## Rollback

If issues occur:
```bash
git checkout HEAD -- systems/inventory_system.gd
git checkout HEAD -- ui/inventory_screen.gd
git checkout HEAD -- ui/shop_screen.gd
```

Or revert entire commit:
```bash
git revert HEAD
```
