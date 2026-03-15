# UI Refactor Plan: Move to Scene-Based Components

## Current State Analysis

**Problem:** UI built programmatically in GDScript
- **photo_mode.gd:** 5,683 lines (!!!) — controls built in code
- **dialogue_ui.gd:** 400 lines — similar problem
- **Debug HUDs:** Runtime construction, hard to preview

**Issues:**
- Can't visually preview UI in Godot editor
- Hard to iterate on layouts/spacing
- Difficult to maintain styling consistency
- No theme system integration
- Can't use Godot's UI design tools

---

## Solution: Component-Based Scene Architecture

### Phase 1: Create Component Library (1-2 hours)

Build reusable UI component scenes:

**Core Components:**
```
scenes/ui/components/
├── Button.tscn               # Styled button with hover/pressed states
├── Panel.tscn                # Consistent panel style
├── Slider.tscn               # Slider with label + value display
├── ColorPicker.tscn          # Color picker control
├── Dropdown.tscn             # Styled OptionButton
├── Checkbox.tscn             # Styled CheckBox
├── TabContainer.tscn         # Tab panel wrapper
└── LabeledControl.tscn       # Generic label + control wrapper
```

**Benefits:**
- Single source of truth for styling
- Reusable across all UI systems
- Easy to theme
- Visually editable

### Phase 2: Refactor Dialogue UI (30-45 minutes)

**Current:** `dialogue_ui.gd` builds everything in `_build_ui()`

**New Structure:**
```
scenes/ui/dialogue/
├── DialoguePanel.tscn        # Main container
├── DialogueChoiceButton.tscn # Choice button component
└── dialogue_ui.gd            # Logic only (no UI construction)
```

**DialoguePanel.tscn contains:**
- Speaker label (@onready reference)
- Line label with reveal animation
- Choice container (add/remove ChoiceButton instances)
- Hint label

**Script becomes ~100 lines** instead of 400 (75% reduction)

### Phase 3: Refactor Photo Mode UI (HIGH IMPACT, 2-3 hours)

**Current:** 5,683 lines of UI construction hell

**New Structure:**
```
scenes/ui/photo/
├── PhotoModeUI.tscn          # Main layout
├── components/
│   ├── Toolbar.tscn          # Top toolbar
│   ├── Filmstrip.tscn        # Bottom filmstrip
│   ├── SettingsPanel.tscn    # Tabbed settings
│   ├── tabs/
│   │   ├── CameraTab.tscn    # Camera settings
│   │   ├── LightingTab.tscn  # Lighting controls
│   │   ├── ColorTab.tscn     # Color adjustments
│   │   ├── GuidesTab.tscn    # Composition guides
│   │   └── ExportTab.tscn    # Export options
│   └── widgets/
│       ├── ISOControl.tscn   # ISO slider group
│       ├── ApertureControl.tscn
│       ├── ShutterControl.tscn
│       └── ExposureControl.tscn
└── photo_mode.gd             # Logic only (~500 lines)
```

**Reduction:** 5,683 lines → ~500 lines (91% reduction!)

### Phase 4: Create Theme Resource (30 minutes)

**File:** `themes/sacred_fruit.tres`

Defines:
- Font sizes and families
- Color palette (primary, secondary, accent, backgrounds)
- Corner radii (use Constants.DIALOGUE_CORNER_RADIUS, etc.)
- Border widths
- Padding/margins

**Apply to all UI:** One theme file controls the entire visual style

---

## Implementation Strategy

### Option A: Incremental (Recommended)
1. Start with DialogueUI (smaller, learn the pattern)
2. Create component library as you go
3. Tackle PhotoMode once pattern is proven
4. Refactor debug HUDs last (lowest priority)

### Option B: Top-Down
1. Create full component library first
2. Create theme resource
3. Refactor all UIs in parallel
4. Higher upfront cost, but faster overall

---

## Benefits

**Before:**
- 6,000+ lines of UI code
- No visual preview
- Hard to change styling
- Difficult to maintain

**After:**
- ~1,000 lines of UI logic code
- All UI visually editable in Godot
- Theme-based styling
- Component reuse
- Easy iteration

**Maintainability:** 10x improvement
**Iteration Speed:** 5x faster (visual editing + instant preview)
**Code Reduction:** 83% fewer lines

---

## Recommendation

**Start with Dialogue UI** (Phase 2):
- Smaller scope to learn the pattern
- Immediate visual benefit
- Proves the architecture
- 1-2 hours investment

Then **tackle Photo Mode** (Phase 3):
- Biggest impact (5,000+ line reduction)
- Most painful to maintain currently
- Will benefit most from component reuse

**Estimated Total Time:** 4-6 hours for full refactor
**ROI:** Massive — will save hours on every future UI change

---

## Next Steps

Should I:
1. **Start with Dialogue UI refactor** (prove the pattern)
2. **Create component library first** (build foundation)
3. **Create theme resource** (establish visual system)
4. **Show me what current dialogue_ui.gd looks like** (understand scope)

What's your preference?
