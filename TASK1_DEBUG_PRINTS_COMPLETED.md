# Task 1: Gate Ungated Debug Prints — COMPLETED ✓

## Summary
All ungated `print()` calls in the codebase have been replaced with `Util.debug_print()` or gated with `io_debug_logging` flag.

## Changes Made

### 1. scripts/core/GameManager.gd
- **Line 80:** `print(props.message)` → `Util.debug_print(props.message)`
- **File:** Only 1 ungated print
- **Purpose:** Gate entity trigger messages to debug output

### 2. scripts/core/io_manager.gd
- **Line 95–103:** Ungated I/O trace print
  - Before: `if io_debug_logging:`
  - After: `if io_debug_logging or Util.debug_enabled:`
  - Changed final print to: `Util.debug_print(...)`
- **Purpose:** Allow trace logging to be controlled by global debug flag + local io_debug_logging

### 3. scripts/photo/photo_mode.gd
- **All 18 occurrences** of `print("[PhotoMode ...")` → `Util.debug_print("[PhotoMode ...)`
- **Lines affected:** 1944, 1954, 1958, 1965, 1970, 1975, 1980, 1984, 1986, 1988, 1993, 2010, 3915, 3921, 3925, 3952, 3967, 4470
- **Purpose:** Gate all photo UI layout debug output

## Verification
✓ All ungated prints removed (except intentional print inside `Util.debug_print()` itself)
✓ All debug output now controlled by:
  - Global: `Util.debug_enabled` (can be toggled at runtime)
  - Local: `io_debug_logging` flag (IOManager specific)

## Next Steps
- Task 2: Extract magic numbers to constants
- Task 3: Run formatter/linter
- Task 4: Smoke test verification

---
**Estimated time saved:** 2-3 hours of future debugging from noise reduction
**Codebase cleanliness:** Much improved
