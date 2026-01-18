# UI Design Standards

Use this agent when implementing or modifying UI screens, dialogs, menus, or any player-facing interface elements. Follow these standards to maintain consistency across the game.

---

## Color Palette

### Core Colors (Named Constants)
```gdscript
# Panel Colors
const COLOR_BACKGROUND = Color(0.08, 0.08, 0.12, 0.98)  # Dark blue/black
const COLOR_BORDER_BLUE = Color(0.5, 0.7, 0.8, 1)       # Blue border
const COLOR_BORDER_GREEN = Color(0.4, 0.6, 0.4, 1)     # Green border
const COLOR_DIMMER = Color(0, 0, 0, 0.7)               # Semi-transparent overlay

# Text Colors
const COLOR_HEADER = Color(0.8, 0.8, 0.5, 1)           # Olive/yellow - section headers
const COLOR_LABEL = Color(0.7, 0.9, 0.7, 1)            # Light green - key labels
const COLOR_DESCRIPTION = Color(0.85, 0.85, 0.7, 1)   # Light beige - descriptions
const COLOR_HELP = Color(0.8, 0.8, 0.7, 1)             # Neutral beige - help text

# Interactive State Colors
const COLOR_SELECTED = Color(0.9, 0.85, 0.5, 1.0)     # Gold - selected item
const COLOR_NORMAL = Color(0.7, 0.7, 0.7, 1.0)        # Gray - normal state
const COLOR_EMPTY = Color(0.4, 0.4, 0.4, 1.0)         # Dark gray - empty/disabled
const COLOR_HIGHLIGHT = Color(1.0, 1.0, 0.6, 1.0)     # Bright yellow - current focus

# State Colors
const COLOR_SUCCESS = Color(0.5, 1.0, 0.5, 1.0)       # Green - success/healthy
const COLOR_WARNING = Color(1.0, 0.85, 0.3, 1.0)      # Yellow - warning/caution
const COLOR_ERROR = Color(1.0, 0.4, 0.4, 1.0)         # Red - error/danger
const COLOR_AFFORDABLE = Color(0.6, 0.9, 0.6, 1.0)    # Medium green - can afford
const COLOR_EXPENSIVE = Color(0.9, 0.5, 0.5, 1.0)     # Salmon - too expensive

# Specialty Colors
const COLOR_GOLD = Color(0.9, 0.7, 0.2, 1.0)          # Currency/gold
const COLOR_ARMOR = Color(0.5, 0.5, 1.0, 1.0)         # Light blue - defense
const COLOR_COMBAT = Color(1.0, 0.5, 0.5, 1.0)        # Light red - damage
const COLOR_TEMP_WARM = Color(1.0, 0.7, 0.4, 1.0)     # Warm orange
const COLOR_TEMP_COOL = Color(0.5, 0.7, 1.0, 1.0)     # Cool blue
```

---

## Font Sizes

```gdscript
const FONT_SCREEN_HEADER = 20    # Major screen titles
const FONT_SECTION_HEADER = 15   # Subsection titles (use 16 for larger)
const FONT_CONTENT = 14          # Main content, labels, values
const FONT_SECONDARY = 13        # Lighter content, titles
const FONT_DETAILS = 12          # Descriptions, footer, small text
```

---

## Standard Layout Pattern

### Full-Screen UI Structure
```gdscript
func _build_ui() -> void:
    # 1. Full-screen control (root)
    var root = Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    # 2. Dimmer (semi-transparent background)
    var dimmer = ColorRect.new()
    dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
    dimmer.color = COLOR_DIMMER
    root.add_child(dimmer)

    # 3. Centered panel with border
    var panel = Panel.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -340
    panel.offset_right = 340
    panel.offset_top = -320
    panel.offset_bottom = 320
    panel.add_theme_stylebox_override("panel", _create_panel_style())
    root.add_child(panel)

    # 4. Margin container
    var margin = MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)

    # 5. Main content container
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    margin.add_child(vbox)

    # Add header, separator, content, footer...

func _create_panel_style() -> StyleBoxFlat:
    var style = StyleBoxFlat.new()
    style.bg_color = COLOR_BACKGROUND
    style.border_color = COLOR_BORDER_BLUE
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    return style
```

---

## Common UI Components

### Section Header
```gdscript
func _create_section_header(text: String) -> Label:
    var label = Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", COLOR_HEADER)
    label.add_theme_font_size_override("font_size", FONT_SECTION_HEADER)
    return label
```

### Item Row (Inventory/Shop style)
```gdscript
func _create_item_row(icon: String, name: String, value: String) -> HBoxContainer:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)

    # Icon
    var icon_label = Label.new()
    icon_label.text = icon
    icon_label.custom_minimum_size.x = 20
    icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    row.add_child(icon_label)

    # Name (expands)
    var name_label = Label.new()
    name_label.text = name
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.add_theme_font_size_override("font_size", FONT_CONTENT)
    row.add_child(name_label)

    # Value (fixed width, right-aligned)
    var value_label = Label.new()
    value_label.text = value
    value_label.custom_minimum_size.x = 60
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    value_label.add_theme_font_size_override("font_size", FONT_CONTENT)
    row.add_child(value_label)

    return row
```

### Stat Line (Character Sheet style)
```gdscript
func _create_stat_line(label_text: String, value_text: String, color: Color = COLOR_NORMAL) -> HBoxContainer:
    var row = HBoxContainer.new()

    var label = Label.new()
    label.text = label_text
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", FONT_CONTENT)
    row.add_child(label)

    var value = Label.new()
    value.text = value_text
    value.custom_minimum_size.x = 180
    value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    value.add_theme_color_override("font_color", color)
    value.add_theme_font_size_override("font_size", FONT_CONTENT)
    row.add_child(value)

    return row
```

### Selection Highlight
```gdscript
func _update_selection(items: Array[Control], selected_index: int) -> void:
    for i in range(items.size()):
        var item = items[i]
        if i == selected_index:
            item.text = "► " + item.text.trim_prefix("► ")
            item.add_theme_color_override("font_color", COLOR_SELECTED)
        else:
            item.text = item.text.trim_prefix("► ")
            item.add_theme_color_override("font_color", COLOR_NORMAL)
```

---

## Input Handling

### Standard Input Pattern
```gdscript
func _input(event: InputEvent) -> void:
    if not visible:
        return

    if event is InputEventKey and event.pressed:
        if event.echo:  # Prevent key-hold repeats
            return

        match event.keycode:
            KEY_ESCAPE:
                _close()
            KEY_UP, KEY_W:
                _navigate(-1)
            KEY_DOWN, KEY_S:
                _navigate(1)
            KEY_TAB:
                _switch_panel()
            KEY_ENTER, KEY_SPACE:
                _confirm_selection()
            KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
                _apply_filter(event.keycode - KEY_1)

        get_viewport().set_input_as_handled()
```

### Navigation Helper
```gdscript
func _navigate(direction: int) -> void:
    selected_index = clampi(selected_index + direction, 0, max_items - 1)
    _update_display()
    _ensure_visible()

func _ensure_visible() -> void:
    if scroll_container and items.size() > 0:
        call_deferred("_scroll_to_selection")

func _scroll_to_selection() -> void:
    var item = items[selected_index]
    scroll_container.ensure_control_visible(item)
```

---

## Signal Patterns

### Standard Screen Signals
```gdscript
signal closed()
signal confirmed(result)
signal cancelled()
```

### Open/Close Pattern
```gdscript
func open(player: Player) -> void:
    _player = player
    selected_index = 0
    _reset_filters()
    _update_display()
    visible = true
    grab_focus()

func _close() -> void:
    visible = false
    closed.emit()
```

---

## Two-Panel Layout

For screens with two panels (inventory, shop):
```gdscript
var is_left_panel_focused: bool = true

func _switch_panel() -> void:
    is_left_panel_focused = not is_left_panel_focused
    _update_panel_titles()
    _update_display()

func _update_panel_titles() -> void:
    left_title.add_theme_color_override("font_color",
        COLOR_HEADER if is_left_panel_focused else COLOR_EMPTY)
    right_title.add_theme_color_override("font_color",
        COLOR_HEADER if not is_left_panel_focused else COLOR_EMPTY)
```

---

## Key Files

- `ui/inventory_screen.gd` - Reference for two-panel layout
- `ui/crafting_screen.gd` - Reference for list + details layout
- `ui/help_screen.gd` - Reference for tabbed interface
- `ui/character_sheet.gd` - Reference for stat display
- `ui/shop_screen.gd` - Reference for trade interface
- `ui/themes/Underkingdom.tres` - Theme file for defaults
