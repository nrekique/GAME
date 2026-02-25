# Map Linting

Use the map linter before compile/playtest to catch common entity wiring issues.

## Command

```bash
tools/tb_lint_map.sh "tb/maps/fgd test.map"
```

Optional:

```bash
tools/tb_lint_map.sh "tb/maps/fgd test.map" --fgd-root tb/fgd
```

## Current checks (phase 1)

- Duplicate `targetname` values.
- Missing target references (`target`, `killtarget`, `*_target`, and basic `On...` output target token parsing).
- Unknown classnames not found in `tb/fgd/**/*.tres`.
- Unknown keys on known classnames based on `class_properties`.
- Portal/mirror budget guardrails:
  - Warn when portals/mirrors exist without `env_portal_budget`.
  - Warn on invalid `profile_mode`.
  - Warn on heavy `cinematic` profile with high portal/mirror counts.
- AI authoring checks:
  - Warn on duplicate `ai_patrol_point.order` values within the same `route_id`.
  - Warn when `npc ai_enabled=1` references an `ai_route_id` without patrol points.
  - Warn when `ai_wave_spawner` has no matching `ai_spawn_wave_point` markers.
  - Warn when `ai_wave_spawner.npc_scene` is not a `res://...*.tscn` path.

## Notes

- This is an entity-level lint pass; it does not yet inspect brush geometry correctness.
- Treat warnings as mapper action items before content freeze.
