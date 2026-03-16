# Codebase Concerns

**Analysis Date:** 2026-03-15

## Tech Debt

**Deprecated Godot 3 API in test:**
- Issue: `tests/io_test.gd` line 16 calls `mgr.io_get_trace().empty()` — this method does not exist in Godot 4; correct is `is_empty()`
- Files: `tests/io_test.gd`
- Impact: Test silently fails or errors at assertion; IO trace clear test is unreliable
- Fix: Replace `.empty()` with `.is_empty()`

**GameManagerLegacy dead code:**
- Issue: `scripts/core/GameManager.gd` (capital G) contains `class_name GameManagerLegacy extends Node` with a single `demangler()` static method. This is a Qodot-era leftover. The actual `GameManager` is `game_manager.gd` at project root.
- Files: `scripts/core/GameManager.gd`
- Impact: Class name collision risk; confusing to navigate; `GameManagerLegacy` class name pollutes global namespace
- Fix: Delete `scripts/core/GameManager.gd` after confirming `demangler()` is not called anywhere

**Unused addons consuming disk/import overhead:**
- Issue: `addons/Mirror/` and `addons/CardGameSkeleton/` are present on disk but not enabled in `project.godot`. `CardImages/` and `Cards/` directories at project root belong to CardGameSkeleton.
- Files: `addons/Mirror/`, `addons/CardGameSkeleton/`, `CardImages/`, `Cards/`
- Impact: Import overhead; confusion about what's active; `CardImages/` are 52+ files at project root
- Fix: Remove all four directories from the project; they are prototype/archived work

**FGD definition missing uid references:**
- Issue: Several `.tres` FGD files reference scripts without `uid=` (e.g., `perf_budget_marker.tres`, `ai_cover_marker.tres`, `ai_nav_region.tres`). Other FGD files include `uid=` on the same type of ext_resource. Inconsistency may cause issues if files are renamed.
- Files: Affected `.tres` in `tb/fgd/point/logic/` and `tb/fgd/point/actors/`
- Impact: Low — Godot resolves by path fallback; but renaming files breaks references that lack uid anchors
- Fix: Open each affected `.tres` in editor; Godot will auto-add uid on save

## Security Considerations

No network access, no user-generated content, no credentials. No security concerns applicable.

## Performance Bottlenecks

**photo_mode.gd is a 5683-line monolith:**
- Problem: Entire photo mode lives in one file. Any modification requires navigating ~5700 lines.
- Files: `scripts/photo/photo_mode.gd`
- Cause: Feature grew organically without extraction into sub-systems
- Improvement path: Extract `_apply_color_adjustments`, `_update_viewfinder`, and camera controller logic into separate scripts in `scripts/photo/`; photo_mode.gd orchestrates them

**Zone lighting polling at fixed 100ms interval:**
- Problem: `game_manager.gd` `_process()` polls `_update_zone_lighting_overrides()` every 100ms unconditionally regardless of whether any zones exist or changed
- Files: `game_manager.gd` (`ZONE_LIGHTING_UPDATE_INTERVAL = 0.10`)
- Cause: Interval-based polling instead of signal-driven updates
- Improvement path: Track dirty flag on zone changes; skip update when nothing changed (`_zone_last_hash` already computed — use it to early-exit more aggressively)

**FuncGodotMap.verify_and_build() called at runtime for sky maps:**
- Problem: `sky_map_controller.gd` builds a full TrenchBroom map at runtime when loading a sky. Building is synchronous-ish and CPU-intensive.
- Files: `entities/logic/sky_map_controller.gd`
- Cause: Sky system designed for editor-time build path but repurposed for runtime switching
- Improvement path: Pre-build sky scenes in editor and reference `PackedScene` instead of raw `.map` files for shipping builds; keep `.map` path for fast-iteration only

## Fragile Areas

**Portal/Mirror rendering (very large, complex scripts):**
- Files: `entities/funcs/func_portal.gd` (1687 lines), `entities/funcs/func_mirror.gd` (1399 lines)
- Why fragile: Oblique clip plane math, viewport lifetime management, and runtime manager integration are tightly coupled. Both scripts maintain near-identical structures.
- Safe modification: Only modify the `# ── Targetfunc-callable methods ──` section at the bottom for gameplay behavior. Touch the geometry/viewport code only when fixing a specific visual bug.
- Test coverage: None — no portal or mirror tests exist

**Runtime state persistence:**
- Files: `game_manager.gd` (`_load_runtime_state`, `_save_runtime_state`)
- Why fragile: Uses `user://runtime_state.cfg` with `.bak` backup, but backup rotation is not atomic. A crash mid-write could leave both files corrupted.
- Safe modification: Always test save/load round-trip after any change to the persistence dictionary keys
- Test coverage: None

**IOManager targetname registry:**
- Files: `scripts/core/io_manager.gd`
- Why fragile: Entities self-register with `GAME.set_targetname()` during `_ready()`. If an entity `_ready()` fires before `IOManager` is added as a child of GAME (in GAME's `_ready()`), registration may fail silently.
- Safe modification: Always call `GAME.set_targetname()` via `call_deferred()` or inside `_start()` which is invoked after `_func_godot_apply_properties()`

## Scaling Limits

**Portal budget:**
- Current capacity: `PortalRuntimeManager.max_active_portals = 8` (runtime default)
- Limit: Viewport-per-portal; each active portal costs a full GPU render pass. Above ~3-4 portals in view, GPU cost accumulates rapidly.
- Scaling path: `env_portal_budget` entity lets designers tune `max_active_portals` per map

**func_godot map build time:**
- Current: For complex maps (HOME.tscn = 9MB, grill.tscn = 8.7MB), map build can take several seconds in editor
- Limit: Build must complete before scene is playable; no incremental build
- Scaling path: Use `save_generated_materials = false` (already set in `map_settings.tres`); keep worldspawn brush count under `WORLDSPAWN_COLLIDER_THRESHOLD = 250` for collision optimization

## Dependencies at Risk

**func_godot v2025.1 (vendored):**
- Risk: Vendored copy — upstream changes require manual merge; no version locking mechanism
- Impact: API changes to `FuncGodotMap`, `_func_godot_apply_properties()` contract, or FGD resource format would require updating all 50+ entity scripts
- Migration plan: Pin to a git tag if moving to a submodule; document the API surface used

## Missing Critical Features

**No headless test runner:**
- Problem: Tests are individual scene files with no runner script. Running the full test suite requires launching each scene manually or scripting Godot CLI calls.
- Blocks: CI/CD, automated regression testing
- Fix: Write a test runner scene that `load()`s each test script, instantiates it, and captures assert failures; or adopt GUT (Godot Unit Testing) framework

**No shipping-build gating:**
- Problem: `build_profile` is a string set by `scripts/build_profile.sh` but no build step enforces that debug-only code is stripped or that `is_shipping()` checks are comprehensive.
- Blocks: Clean shipping builds that omit debug tools
- Fix: Add a shipping validation step that verifies `DEBUG` autoload tools are not accessible when `GAME.is_shipping()` is true

## Test Coverage Gaps

**Player controller:**
- What's not tested: Movement physics, bunny-hop acceleration, water physics, crouch/uncrouch, death/respawn
- Files: `scripts/core/player.gd`
- Risk: Regressions to feel/physics go unnoticed
- Priority: Medium

**Checkpoint/persistence:**
- What's not tested: Save/load round-trip, backup rotation, corrupt file recovery
- Files: `game_manager.gd` (`_load_runtime_state`, `_save_runtime_state`), `user://runtime_state.cfg`
- Risk: Data loss on crash or schema change
- Priority: High

**Sky map controller:**
- What's not tested: Sky switching, parallax factor behavior, material patching, build failure path
- Files: `entities/logic/sky_map_controller.gd`
- Risk: Sky regressions invisible until in-editor playtest
- Priority: Low (purely visual)

**Portal and mirror rendering:**
- What's not tested: Budget management, viewport lifecycle, oblique clip
- Files: `entities/funcs/func_portal.gd`, `entities/funcs/func_mirror.gd`
- Risk: Visual regressions, viewport leaks
- Priority: Medium

---

*Concerns audit: 2026-03-15*
