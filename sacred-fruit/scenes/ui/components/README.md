# UI Component Library Documentation

## Overview

The Sacred Fruit UI Component Library provides reusable, styled UI components that maintain visual consistency across the game. All components use the shared `sacred_fruit.tres` theme.

**Location:** `scenes/ui/components/`

---

## Available Components

### 1. Button (`Button.tscn`)

**Usage:**
```
scenes/ui/components/Button.tscn
```

**Properties:**
- `text` — Button label
- Styled with hover and pressed states
- Automatically uses theme colors

**Example:**
```gdscript
var button = preload("res://scenes/ui/components/Button.tscn").instantiate()
button.text = "Click Me"
button.pressed.connect(_on_button_pressed)
add_child(button)
```

---

### 2. Panel (`Panel.tscn`)

**Usage:**
```
scenes/ui/components/Panel.tscn
```

**Features:**
- Dark background with warm border
- Built-in margin container (18px sides, 16px top, 14px bottom)
- Corner radius: 10px

**Example:**
```gdscript
var panel = preload("res://scenes/ui/components/Panel.tscn").instantiate()
var content = VBoxContainer.new()
panel.get_node("MarginContainer").add_child(content)
add_child(panel)
```

---

### 3. LabeledSlider (`Slider.tscn` + `labeled_slider.gd`)

**Class:** `LabeledSlider`

**Exported Properties:**
- `label_text: String` — Label text
- `min_value: float` — Minimum slider value
- `max_value: float` — Maximum slider value
- `current_value: float` — Current slider value
- `step_size: float` — Increment step
- `value_format: String` — Printf-style format (default: "%.0f")
- `value_suffix: String` — Suffix appended to value (e.g., "%", "ms")

**Signals:**
- `value_changed(new_value: float)` — Emitted when slider changes

**Example in Scene:**
```
Just instance Slider.tscn and set properties in Inspector:
- label_text: "Volume"
- min_value: 0
- max_value: 100
- current_value: 75
- value_suffix: "%"
```

**Example in Code:**
```gdscript
@onready var volume_slider: LabeledSlider = $VolumeSlider

func _ready():
    volume_slider.value_changed.connect(_on_volume_changed)

func _on_volume_changed(value: float):
    AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
```

---

### 4. Checkbox (`Checkbox.tscn`)

**Usage:**
```
scenes/ui/components/Checkbox.tscn
```

**Properties:**
- `text` — Checkbox label
- `button_pressed` — Checked state

**Example:**
```gdscript
var checkbox = preload("res://scenes/ui/components/Checkbox.tscn").instantiate()
checkbox.text = "Enable Feature"
checkbox.toggled.connect(_on_checkbox_toggled)
add_child(checkbox)
```

---

### 5. LabeledDropdown (`Dropdown.tscn`)

**Usage:**
```
scenes/ui/components/Dropdown.tscn
```

**Features:**
- Label above dropdown
- Access dropdown via `$Dropdown` node

**Example:**
```gdscript
var dropdown = preload("res://scenes/ui/components/Dropdown.tscn").instantiate()
dropdown.get_node("Label").text = "Quality"
var option_btn = dropdown.get_node("Dropdown")
option_btn.add_item("Low")
option_btn.add_item("Medium")
option_btn.add_item("High")
option_btn.item_selected.connect(_on_quality_changed)
add_child(dropdown)
```

---

### 6. LabeledColorPicker (`ColorPicker.tscn`)

**Usage:**
```
scenes/ui/components/ColorPicker.tscn
```

**Features:**
- Label above color picker button
- Access picker via `$ColorButton` node

**Example:**
```gdscript
var picker = preload("res://scenes/ui/components/ColorPicker.tscn").instantiate()
picker.get_node("Label").text = "Background Color"
var color_btn = picker.get_node("ColorButton")
color_btn.color = Color.RED
color_btn.color_changed.connect(_on_color_changed)
add_child(picker)
```

---

### 7. LabeledControl (`LabeledControl.tscn`)

**Usage:**
```
scenes/ui/components/LabeledControl.tscn
```

**Purpose:** Generic wrapper for any control with a label above it

**Example:**
```gdscript
var wrapper = preload("res://scenes/ui/components/LabeledControl.tscn").instantiate()
wrapper.get_node("Label").text = "Custom Control"
var my_control = MyCustomControl.new()
wrapper.get_node("ControlContainer").add_child(my_control)
add_child(wrapper)
```

---

## Theme System

**Theme File:** `themes/sacred_fruit.tres`

**Color Palette:**
- **Background:** `Color(0.07, 0.08, 0.10, 0.93)`
- **Border/Accent:** `Color(0.72, 0.68, 0.50, 0.95)`
- **Button Normal:** `Color(0.16, 0.18, 0.22, 0.95)`
- **Button Hover:** `Color(0.24, 0.27, 0.31, 0.98)`
- **Hover Border:** `Color(0.84, 0.78, 0.56, 0.98)`

**Typography:**
- **Default Font Size:** 16px
- **Speaker/Title Color:** `Color(0.95, 0.84, 0.50, 1.0)` (warm gold)
- **Body Text:** `Color(0.94, 0.95, 0.97, 1.0)` (off-white)
- **Hint Text:** `Color(0.78, 0.80, 0.85, 0.90)` (muted gray)

**Radii:**
- **Panel Corners:** 10px
- **Button Corners:** 6px

---

## Example Scene

**File:** `scenes/ui/components/ComponentShowcase.tscn`

Open this scene in Godot to see all components in action. Use it as a reference when building new UIs.

---

## Usage Pattern: Building a New UI

### Step 1: Create Scene File

Create a new scene in `scenes/ui/your_feature/YourUI.tscn`:

```gdscript
[gd_scene load_steps=4 format=3]

[ext_resource type="PackedScene" path="res://scenes/ui/components/Panel.tscn" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/components/Slider.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/components/Button.tscn" id="3"]

[node name="MyUI" type="Control"]
layout_mode = 3
anchors_preset = 15

[node name="Panel" parent="." instance=ExtResource("1")]
# ... layout ...

[node name="VolumeSlider" parent="Panel/MarginContainer/Content" instance=ExtResource("2")]
label_text = "Volume"
current_value = 75.0
value_suffix = "%"

[node name="ApplyButton" parent="Panel/MarginContainer/Content" instance=ExtResource("3")]
text = "Apply"
```

### Step 2: Create Minimal Script

Only handle logic, no UI construction:

```gdscript
extends Control

@onready var volume_slider: LabeledSlider = $Panel/MarginContainer/Content/VolumeSlider
@onready var apply_button: Button = $Panel/MarginContainer/Content/ApplyButton

signal settings_applied(volume: float)


func _ready() -> void:
    apply_button.pressed.connect(_on_apply_pressed)


func _on_apply_pressed() -> void:
    settings_applied.emit(volume_slider.current_value)
```

**Result:** ~15 lines of logic instead of 400+ lines of UI construction!

---

## Migration Guide

### Before (Programmatic UI):
```gdscript
func _build_ui():
    var panel = PanelContainer.new()
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.07, 0.08, 0.10, 0.93)
    style.corner_radius_top_left = 10
    # ... 50 more lines ...
    panel.add_theme_stylebox_override("panel", style)
    
    var slider = HSlider.new()
    slider.min_value = 0
    slider.max_value = 100
    # ... more setup ...
```

### After (Component-Based):
```gdscript
# In the .tscn file, just instance components
# Script only has logic:
@onready var my_slider: LabeledSlider = $MySlider

func _ready():
    my_slider.value_changed.connect(_on_value_changed)
```

**Code Reduction:** 90%+ reduction in UI code

---

## Next Steps

1. **Open ComponentShowcase.tscn** in Godot editor to see components
2. **Experiment** with changing properties in Inspector
3. **Start refactoring** existing UIs using these components
4. **Add new components** as needed (tabs, separators, etc.)

**Happy building!** 🎨
