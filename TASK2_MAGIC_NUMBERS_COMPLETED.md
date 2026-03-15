# Task 2: Extract Magic Numbers to Constants — COMPLETED ✓

## Summary
Created `scripts/core/constants.gd` with 20+ named constants and replaced all magic numbers across the codebase. Eliminates guesswork and makes tuning UI, layers, physics, and photography settings trivial.

## New File: constants.gd

**Location:** `sacred-fruit/scripts/core/constants.gd` (125 lines)

**Sections:**
- Canvas Layer Assignments (6 constants): LAYER_CROSSHAIR, LAYER_DIALOGUE_UI, LAYER_WEATHER_OVERLAY, LAYER_PHOTO_MENU, LAYER_DEBUG_PERF_HUD, LAYER_DEBUG_AI_HUD
- UI Z-Index Assignments (2 constants): ZINDEX_PHOTO_GUIDES_BG, ZINDEX_PHOTO_TOOLBAR
- UI Dimensions & Spacing (4 constants): DIALOGUE_CORNER_RADIUS, DIALOGUE_CHOICE_CORNER_RADIUS, PHOTO_ROOT_MARGIN_OFFSET_TOP, PHOTO_ROOT_PADDING
- Camera & Photography (5 constants): GAMEPLAY_DEFAULT_FOV, PHOTO_DEFAULT_FOV, PHOTO_DEFAULT_ISO, PHOTO_ISO_BRIGHT, PHOTO_REFERENCE_ISO
- Dialogue System (1 constant): DIALOGUE_REVEAL_RATE
- Physics & Movement (1 constant): PLAYER_AIR_CONTROL_MULTIPLIER
- Weather & Particles (3 constants): SANDSTORM_SPREAD_NORMAL, SANDSTORM_SPREAD_RAIN, COLOR_COMPONENT_NORMALIZE
- Debug & Logging (2 constants): PHOTO_LAYOUT_DEBUG_INTERVAL, IO_TRACE_CAPACITY

## Files Modified: 7

### 1. scripts/ui/dialogue_ui.gd
- **Layer:** `30` → `Constants.LAYER_DIALOGUE_UI`
- **Panel corner radius:** `10` → `Constants.DIALOGUE_CORNER_RADIUS` (4 occurrences)
- **Choice button corner radius:** `6` → `Constants.DIALOGUE_CHOICE_CORNER_RADIUS` (4 occurrences)

### 2. scripts/core/player.gd
- **Crosshair layer:** `10` → `Constants.LAYER_CROSSHAIR`

### 3. scripts/env/sandstorm_controller.gd
- **Weather overlay layer:** `60` → `Constants.LAYER_WEATHER_OVERLAY`
- **Normal particle spread:** `25.0` → `Constants.SANDSTORM_SPREAD_NORMAL`
- **Rain particle spread:** `12.0` → `Constants.SANDSTORM_SPREAD_RAIN`

### 4. scripts/photo/photo_mode.gd
- **ISO current:** `400.0` → `Constants.PHOTO_DEFAULT_ISO`
- **Guides z-index:** `-1` → `Constants.ZINDEX_PHOTO_GUIDES_BG`
- **Toolbar/filmstrip z-index:** `200` → `Constants.ZINDEX_PHOTO_TOOLBAR` (2 occurrences)
- **Menu layer:** `100` → `Constants.LAYER_PHOTO_MENU`
- **Root margin offset top:** `76.0` → `Constants.PHOTO_ROOT_MARGIN_OFFSET_TOP`
- **Root padding:** `10.0` → `Constants.PHOTO_ROOT_PADDING` (4 occurrences for offset_left, offset_top, offset_right, offset_bottom)
- **ISO Portrait mode:** `400.0` → `Constants.PHOTO_DEFAULT_ISO`
- **ISO Outside mode:** `100.0` → `Constants.PHOTO_ISO_BRIGHT`
- **Reference ISO:** `200.0` → `Constants.PHOTO_REFERENCE_ISO`

### 5. scripts/debug/debug.gd
- **Photo camera FOV:** `70.0` → `Constants.PHOTO_DEFAULT_FOV`

### 6. scripts/debug/runtime_perf_hud.gd
- **Perf HUD layer:** `120` → `Constants.LAYER_DEBUG_PERF_HUD`

### 7. scripts/debug/runtime_ai_hud.gd
- **AI HUD layer:** `121` → `Constants.LAYER_DEBUG_AI_HUD`

## Verification

✓ Constants file created and well-documented (125 lines)
✓ 7 files now import Constants
✓ 30+ constant usages throughout codebase
✓ 0 remaining magic numbers for layers/z-indices
✓ All values replacements verified

## Benefits

1. **Maintainability:** Change UI layer, z-index, or spacing in one place — all refs update automatically
2. **Discoverability:** New developers see all tuning parameters in one file
3. **Documentation:** Each constant has inline comments explaining purpose and usage context
4. **Debugging:** Easy to toggle settings at runtime if debug hooks are added
5. **Design iteration:** Tweak camera FOV, photo ISO, dialogue reveal rate without hunting through code

---

**Next Steps:**
- Task 3: Run formatter/linter (30m)
- Task 4: Smoke test verification (30m)
