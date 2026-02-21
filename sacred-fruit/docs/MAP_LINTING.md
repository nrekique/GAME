# Map Linting

Use the map linter before compile/playtest to catch common entity wiring issues.

## Command

```bash
tools/tb_lint_map.sh "tb/fgd test.map"
```

Optional:

```bash
tools/tb_lint_map.sh "tb/fgd test.map" --fgd-root tb/fgd
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

## Notes

- This is an entity-level lint pass; it does not yet inspect brush geometry correctness.
- Treat warnings as mapper action items before content freeze.
