# Development TODO

## Core Systems Roadmap

- [x] 1. Entity I/O system (phase 1 started and shipped)
  - Standardized `GAME.use_targets(...)` dispatch with input selection, optional arg, optional delay, and trace logging.
  - Added output parsing helpers: `GAME.io_fire_output(...)` and `GAME.fire_output(...)`.
  - Added FGD base keys: `targetarg`, `targetdelay`.
  - Next: author-facing output keys in FGD (`OnTrigger` style) and visual debugger UI for recent I/O events.
- [x] 2. Prefab/instance workflow (phase 1 started and shipped)
  - Added `func_prefab_instance` entity for runtime PackedScene instancing from map keys.
  - Added `env_sky_scene` entity for Source-style distant sky scene loading.
  - Added FGD definitions and TrenchBroom registration.
  - Next: prefab catalog browser, per-instance override UI, and content validation for override paths.
- [x] 3. Validation + lint pass (phase 1 started and shipped)
  - Added `tools/map_lint.py` and `tools/tb_lint_map.sh`.
  - Current checks: duplicate `targetname`, missing target refs, unknown classnames, unknown keys vs FGD, portal/mirror budget heuristics.
  - Next: brush-level checks, nav/fog/audio conflict checks, output graph validation, CI integration.
- [x] 4. Build profiles
  - Presets for `fast iteration`, `playtest`, `shipping`.
  - Added `scripts/build_profile.sh` plus runtime helpers in GameManager.
- [x] 5. Gameplay volumes
  - `damage`, `checkpoint`, `spawn blocker`, `music zone`, `AI alert`, quest trigger volumes.
  - Created `Volume` base plus dedicated subclasses and smoke tests; mappers can
    extend further.
  - Added `body_entered`/`body_exited` signals, spawn blocker group and
    `GAME.is_spawn_blocked` helper, and corresponding FGD entries for each type.
- [ ] 6. AI authoring layer
  - Nav regions, patrol pathing, cover markers, perception blockers, spawn wave points.
  - Phase 1 started: added point entities (`ai_nav_region`, `ai_patrol_point`,
    `ai_cover_marker`, `ai_perception_blocker`, `ai_spawn_wave_point`) and
    `GAME` query helpers (`get_ai_nav_regions`, `get_ai_patrol_points`,
    `get_ai_cover_markers`, `is_ai_perception_blocked`,
    `get_ai_spawn_wave_points`) plus `GAME.alert_ai` signal hook.
  - Added `AIController` (idle/patrol/alert) and mapper-facing NPC AI keys
    (`ai_enabled`, `ai_route_id`, `ai_patrol_speed`, `ai_alert_duration`,
    `ai_reacts_to_alerts`) via `npc_spawn_anchor`.
  - Added `ai_wave_spawner` point entity for marker-driven NPC wave spawning.
  - Phase 1 fixes: `ai_wave_spawner` now accepts `npc_scene` map key path and
    enforces per-point `max_spawn_count`; patrol controllers refresh routes to
    handle late-loaded markers.
- [x] 7. Lighting pipeline
  - Added mapper-facing light `bake_mode` policy (`dynamic` / `static` / `disabled`) in light FGD + runtime light script.
  - Added `env_reflection_probe` point entity with probe cull mask, intensity, and update mode.
  - Added per-zone light/reflection mask overrides on `env_zone` (`light_cull_mask`, `reflection_cull_mask`, `reflection_intensity_scale`) applied at runtime from camera position.
- [x] 8. Save/state hooks
  - Added persistent runtime keys in `GAME`: `save_id`, `starts_enabled`, `one_shot` support for `Volume` subclasses.
  - Added checkpoint registration/activation and restore-first respawn rules in `GAME.respawn_player`.
  - `checkpoint_volume` now registers checkpoints with optional `checkpoint_id` and persistence through runtime state config.
- [ ] 9. Performance budgets in editor
  - Per-entity cost hints and mapper-facing perf heatmaps.
- [ ] 10. Automated smoke tests
  - Headless map load/build checks and perf CSV diff reporting in CI.

## Codebase audit follow‑ups

- [x] Break up **monolithic scripts** (`game_manager.gd`, `func_portal.gd`, `func_mirror.gd`, etc.) into smaller modules or helpers.  
  - PS1 shader subsystem moved to `scripts/ps1_shader_manager.gd`.
  - I/O dispatch and target system extracted to `scripts/io_manager.gd` with GameManager wrappers.
- [x] Centralize shared utilities (e.g. `_to_bool`, bool/prop helpers) in `scripts/util.gd`; updated callers across the repo.
- [x] Gate debug prints using `Util.debug_enabled` and replaced ad‑hoc prints with `Util.debug_print` where appropriate.
- [ ] Remove or gate all `print`‑style debug logs behind a global debug flag; consider using `push_warning()` or a logging subsystem.
- [x] Eliminate editor‑hint clutter by moving editor‑only code into proper `tool` scripts or separate editor plugins.  
  - Early returns consolidated using `Util.editor_hint()`; only plugin code still uses raw `Engine.is_editor_hint()`.
- [ ] Enforce consistent naming and style (snake_case vs camelCase, exported variable comments) and run a linter.  
  - `scripts/format_and_lint.sh` added to format/normalize GDScript; a linter remains to be integrated.
- [x] Add unit tests for utility functions and critical game managers; integrate with CI.  
  - Created simple GDScript smoke tests under `tests/` (run with `godot --script`).
- [x] Document exported shader/portal/mirror parameters and layer constants for mapper authors.  
  - Added `PS1_SHADER_PARAMETERS.md` and updated `PORTAL_TUNING_PLAYBOOK.md`.
- [x] Investigate and handle error cases in I/O dispatch (`_get_node_prop`, missing groups, etc.).  
  - Added debug warnings when properties or target groups are missing and when master disallows a use.
- [ ] Clean up hard‑coded constants and magic numbers (layer masks, port node IDs).
- [x] Remove unused code and update README with current development guidance.  
  - Stray returns and deprecated sections cleaned; README expanded with project overview and docs links.
