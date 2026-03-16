# Testing Patterns

**Analysis Date:** 2026-03-15

## Test Framework

**Runner:**
- No external test framework; tests are Godot scenes that run in-engine
- Each test script is a `Node` scene that asserts in `_ready()` and calls `get_tree().quit()`
- No vitest/GUT/WAT — raw `assert()` + `print()` pattern

**Run Commands:**
```bash
# Run a test scene headlessly via Godot CLI
godot --headless --path /path/to/sacred-fruit res://tests/io_test.tscn

# Run all test scenes (no runner script exists — manual per-file)
# Convention: each test scene is independent, exits 0 on pass, non-zero on assert failure
```

## Test File Organization

**Location:** `tests/` directory at project root (not co-located with source)

**Test files:**
- `tests/io_test.gd` — IOManager smoke test
- `tests/ai_authoring_test.gd` — AI entity authoring (patrol points, cover markers, wave points)
- `tests/dialogue_integration_test.gd` — dialogue manager integration
- `tests/perf_budget_test.gd` — performance budget scoring
- `tests/profile_test.gd` — build profile detection
- `tests/util_test.gd` — Util helper functions
- `tests/volume_test.gd` — Volume entity behavior
- `tests/perf_baselines/` — performance baseline data files

## Test Structure

**Suite Organization:**
```gdscript
extends Node

const IO := preload("res://scripts/core/io_manager.gd")

func _ready():
    var mgr := IO.new()
    # ... setup
    assert(condition)
    print("[TEST] description passed")
    # ...
    get_tree().quit()
```

**Patterns:**
- Setup: inline in `_ready()`, no BeforeEach/AfterEach
- Teardown: `get_tree().quit()` to exit after tests run
- Assertion: built-in `assert(condition)` — crashes with "Assertion failed" on failure
- Output: `print("[TEST] <name> passed")` for success confirmation

## Mocking

**Framework:** None

**Patterns:**
- Unit tests instantiate classes directly: `var mgr := IO.new()`
- No mock framework; tests that require scene nodes are noted as skipped:
  ```gdscript
  # master lock and killtarget behavior tests require scene nodes; skip for smoke
  ```
- AI tests construct stub nodes manually and add them to the scene tree

## Coverage

**Requirements:** None enforced

**What is tested:**
- IO trace buffer operations
- AI entity spatial queries (patrol points, cover markers, wave spawns)
- Dialogue manager parse + display
- Performance budget score calculation
- Build profile detection (`GAME.is_fast_iteration()` etc.)
- Util helpers
- Volume entity body tracking

**What is NOT tested (gaps):**
- Player controller (`scripts/core/player.gd`) — no tests
- Portal rendering (`entities/funcs/func_portal.gd`) — no tests
- Mirror rendering (`entities/funcs/func_mirror.gd`) — no tests
- Checkpoint/persistence (`user://runtime_state.cfg`) — no tests
- Sky map controller (`entities/logic/sky_map_controller.gd`) — no tests
- Photo mode (`scripts/photo/photo_mode.gd`) — no tests
- All scene-level integration — no tests

## Known Test Bug

`tests/io_test.gd` line 16 calls `mgr.io_get_trace().empty()` which uses the **Godot 3 API**. In Godot 4, `Array.empty()` does not exist; the correct method is `is_empty()`. This test will produce an error or false positive at runtime.

**Fix:** Change `.empty()` to `.is_empty()` in `tests/io_test.gd`.

## Test Types

**Smoke Tests:**
- `io_test.gd`, `profile_test.gd`, `util_test.gd` — instantiate class, call methods, assert basic behavior

**Integration Tests:**
- `ai_authoring_test.gd` — builds a mini scene tree with stub entities and tests GameManager spatial query methods
- `dialogue_integration_test.gd` — exercises DIALOGUE autoload with real input

**Performance Tests:**
- `perf_budget_test.gd` — validates budget scoring logic against known values
- `tests/perf_baselines/` — baseline data for comparison

**E2E Tests:** Not present

---

*Testing analysis: 2026-03-15*
