# Code Cleanup Work — Sacred Fruit

## Priority Items (from DEVELOPMENT_TODO.md)

### 1. **Remove ungated debug prints** (HIGH PRIORITY)
Status: Incomplete
- Currently: Scattered `print()` calls in photo_mode.gd, io_manager.gd, and GameManager.gd
- Target: All debug output gated by `Util.debug_enabled` or use `push_warning()` for warnings
- Affected files:
  - `scripts/photo/photo_mode.gd` — ~15 print() calls, mostly debug instrumentation
  - `scripts/core/io_manager.gd` — 1 ungated print for I/O trace
  - `scripts/core/GameManager.gd` — 1 ungated print for props.message

### 2. **Clean up magic numbers and hardcoded constants** (MEDIUM PRIORITY)
Status: Incomplete
- Layer masks (e.g., `layer = 10`, `layer = 30`, `layer = 60`, `layer = 200`)
- Z-index values (e.g., `z_index = 200`)
- Physics/movement constants (e.g., `32.0 * AIR_CONTROL`, particle spreads)
- UI dimensions (e.g., `offset_top = 76.0`, corner radii)
- Reveal rates and timings (e.g., `_line_reveal_rate = 90.0`)
- Target: Define as named constants in appropriate manager classes or settings

### 3. **Run linter/formatter** (MEDIUM PRIORITY)
Status: Partially done
- `format_and_lint.sh` exists but requires gdformat + godot-lint tools
- Check: Are gdformat and godot-lint installed?
- Action: Run formatter across all .gd files, fix any style/naming inconsistencies

### 4. **Consistent naming conventions** (LOW PRIORITY)
Status: Not started
- Enforce snake_case for properties/functions
- Standardize exported var comments
- Review for any camelCase outliers

## Recommended Work Order

1. **Fix ungated print() calls** (1-2 hours)
   - Gate photo_mode.gd debug output
   - Make io_manager trace conditional
   - Convert appropriate warnings to push_warning()

2. **Extract magic numbers to constants** (2-3 hours)
   - Create `scripts/core/constants.gd` or extend settings.gd
   - Update all layer/z-index/dimension references
   - Document what each constant controls

3. **Run formatter and linter** (30 mins)
   - Ensure tools are installed
   - Format codebase
   - Fix any linter warnings

4. **Final verification** (30 mins)
   - Run smoke tests to ensure no regressions
   - Verify game still builds and runs

## Total Estimated Time
5-6 hours for full cleanup pass
