# Repository Reorganization Plan

This plan improves discoverability and maintenance while minimizing breakage of Godot `res://` paths.

## 1. Current Pain Points

- Content is split across overlapping roots (`tb/`, `maps/`, `scenes/`, `entities/`, `scripts/`), making ownership unclear.
- `tb/` is very large and mixes source maps, generated imports, textures, models, autosaves, and crash artifacts.
- TrenchBroom autosaves are currently tracked in git even though `.gitignore` excludes `tb/autosave/`.
- Duplicate/legacy-looking paths exist:
  - `tb/models` and `tb/tb/models`
  - `GAME/sacred-fruit/.github/workflows` nested under project root
- Root has mixed runtime and non-runtime files (large images, backups, plugin demo leftovers).
- Naming inconsistency for core script entrypoints (`game_manager.gd` at root and `scripts/GameManager.gd`).

## Status Update (Implemented)

- Phase 1: completed
  - `tb/autosave/*` removed from git tracking (kept local)
  - tracked `.DS_Store` files removed
  - crash artifacts moved into `tb/archive/`
- Phase 2: completed
  - canonical map sources moved to `tb/maps/`
  - runtime/tooling path resolution updated with backward-compatible fallbacks
- Phase 3: partially completed
  - duplicate `tb/tb/models` tree consolidated into `tb/models`
  - nested empty `GAME/sacred-fruit` residue removed

## 2. Reorganization Goals

- Make it obvious where runtime code, authored content, generated artifacts, and external/vendor assets live.
- Keep the number of moved runtime paths small per phase.
- Eliminate tracked temporary/editor outputs.
- Preserve build/run behavior at each phase.

## 3. Target Structure (Godot-Friendly)

Keep current major runtime roots, but add clear boundaries:

- `addons/` third-party and plugin code (vendor only)
- `entities/` map-spawned entity scripts
- `scenes/` runtime scenes
- `scripts/` gameplay systems and UI runtime code
- `tb/` TrenchBroom authoring workspace only
  - `tb/maps/` canonical `.map` source files
  - `tb/fgd/` FGD + icon configuration
  - `tb/textures/` TB-facing texture source
  - `tb/models/` TB-facing model source
  - `tb/archive/` crash logs / one-off historical files
- `docs/` documentation and plans
- `tools/` build/lint/smoke tooling
- `tests/` automated checks
- `data/` runtime content data (dialogue, tables, config)
- `assets/` non-TB runtime media if needed (future phase)

## 4. Execution Phases

## Phase 0: Safety Baseline

- Capture pre-move baseline:
  - map compile smoke
  - runtime map launch smoke
  - test smoke scripts
- Add a lightweight path inventory file for all `.tscn`, `.tres`, `.gd`, and `.map` refs.

## Phase 1: No-Risk Cleanup

- Stop tracking temp/editor noise:
  - `tb/autosave/*` (remove from index, keep local files)
  - stray `.DS_Store` files
- Move obvious crash artifacts to `tb/archive/`:
  - `tb/*-crash.*`
- Remove/relocate backup file:
  - `project.godot.bak` -> `tb/archive/project.godot.bak` or delete if obsolete

## Phase 2: Normalize TrenchBroom Map Sources

- Create `tb/maps/` and move canonical `.map` files from `tb/*.map` into it.
- Update all references:
  - scripts that scan/launch maps
  - any hardcoded `tb/<name>.map` paths
  - docs and helper scripts
- Keep `tb/autosave/` excluded and local-only.

## Phase 3: Resolve Duplicate/Legacy Paths

- Consolidate duplicate models:
  - choose one canonical path (`tb/models/`)
  - remove duplicate `tb/tb/models/` after confirming no references
- Investigate/remove nested `GAME/sacred-fruit` residue if unused.
- Audit root-level large binaries:
  - keep only runtime-required files at root
  - move non-runtime art/screens to dedicated folders.

## Phase 4: Runtime Code Organization Pass

- Keep `entities/` for map-authored classes.
- Keep `scripts/` for systems; optionally split into:
  - `scripts/core/`
  - `scripts/ui/`
  - `scripts/photo/`
  - `scripts/debug/`
- Resolve `game_manager.gd` vs `scripts/GameManager.gd` naming ambiguity.

## Phase 5: Documentation and Guardrails

- Add `docs/REPO_LAYOUT.md` as source of truth.
- Add CI checks for:
  - forbidden tracked paths (`tb/autosave/`, `.DS_Store`)
  - duplicate directory mirrors (`tb/tb/*`)
  - accidental root clutter.

## 5. Migration Rules

- Move in small batches, one phase per PR.
- After each phase:
  - run map compile smoke
  - run test smoke
  - run docs link/path check
- Prefer scripted moves with deterministic path rewrite commands.
- Do not modify vendor `addons/` unless explicitly planned.

## 6. First Implementation Slice (Recommended)

- Phase 1 only:
  - untrack `tb/autosave/*`
  - purge tracked `.DS_Store`
  - archive crash files

This gives immediate signal/noise improvement with near-zero gameplay risk.
