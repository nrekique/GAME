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
- [ ] 4. Build profiles
  - Presets for `fast iteration`, `playtest`, `shipping`.
- [ ] 5. Gameplay volumes
  - `damage`, `checkpoint`, `spawn blocker`, `music zone`, `AI alert`, quest trigger volumes.
- [ ] 6. AI authoring layer
  - Nav regions, patrol pathing, cover markers, perception blockers, spawn wave points.
- [ ] 7. Lighting pipeline
  - Baked/dynamic policy, reflection probes, per-zone light culling masks.
- [ ] 8. Save/state hooks
  - Persistence keys like `save_id`, `starts_enabled`, `one_shot`, checkpoint restore rules.
- [ ] 9. Performance budgets in editor
  - Per-entity cost hints and mapper-facing perf heatmaps.
- [ ] 10. Automated smoke tests
  - Headless map load/build checks and perf CSV diff reporting in CI.
