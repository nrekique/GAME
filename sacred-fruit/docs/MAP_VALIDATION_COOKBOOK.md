# Map Validation Cookbook

How to interpret and fix `tools/map_lint.py` output.

Run:

- `tools/tb_lint_map.sh tb/maps/your_map.map`

The linter reports `ERROR`, `WARN`, and `INFO`.

## Severity Policy

- `ERROR`: must fix before testing/shipping.
- `WARN`: fix before merge unless intentionally accepted.
- `INFO`: optional improvement.

## Warning Types and Fixes

## 1) duplicate targetname

Example:

- `WARN: duplicate targetname "door_a" on entities [12, 45]`

Meaning:

- Multiple entities share a `targetname`. This can be intentional for fan-out triggers, but often is accidental.

Fix:

1. If fan-out is intentional, keep as-is and document it in map notes.
2. Otherwise rename one side (`door_a`, `door_a_2`, etc.).

Gate recommendation:

- `CI warn` by default.
- `CI fail` when duplication is not explicitly documented.

## 2) unknown classname in FGD

Example:

- `WARN: [entity 21 func_group] unknown classname in FGD`

Meaning:

- Map contains an entity class not defined under active `tb/fgd` resources.

Fix:

1. If brush helper entity (like `func_group`) should be ignored, convert to supported class or remove before runtime map export.
2. If it is a real gameplay class, add corresponding `.tres` definition and register in `fgd_point.tres` or `fgd_solid.tres`.

Gate recommendation:

- `CI fail` for shipping maps.
- `CI warn` for sandbox/WIP maps.

## 3) unknown key for classname

Example:

- `WARN: [entity 33 func_door] unknown key "speed_fast" for classname "func_door"`

Meaning:

- Key is not listed in that class’s merged FGD key set (`class_properties` + base classes + common keys).

Fix:

1. Correct typo in map key.
2. If key is valid new behavior, add it to entity `.tres` + runtime script.

Gate recommendation:

- `CI fail` for shipping/playtest.

## 4) key references missing targetname

Example:

- `WARN: [entity 8 logic_auto] key "target" references missing targetname "setup_relay"`

Meaning:

- A reference key (`target`, `killtarget`, `next_target`, etc.) points to a missing group.

Fix:

1. Add entity with matching `targetname`.
2. Fix typo/case in reference string.
3. Remove stale reference if no longer used.

Gate recommendation:

- `CI fail` for shipping/playtest.

## 5) func_portal/func_mirror present but no env_portal_budget

Meaning:

- Portal/mirror content exists without explicit budget controller.

Fix:

1. Add one `env_portal_budget` entity.
2. Set `profile_mode` and scale caps intentionally.

Gate recommendation:

- `CI warn` in iteration.
- `CI fail` for performance-sensitive profiles.

## 6) env_portal_budget unknown profile_mode

Meaning:

- `profile_mode` is not one of `cinematic`, `balanced`, `stress`.

Fix:

1. Replace with a supported value.

Gate recommendation:

- `CI fail`.

## 7) cinematic profile with high portal/mirror counts

Meaning:

- Heuristic warning for likely frame drops (`portal >= 8` or `mirror >= 4`).

Fix:

1. Use `balanced` or `stress`.
2. Reduce active portals/mirrors.
3. Tighten render scale caps.

Gate recommendation:

- `CI warn` with manual perf check required.

## 8) profile_mode not set (INFO)

Meaning:

- Budget entity exists but profile was omitted; runtime defaults to `balanced`.

Fix:

1. Set explicit `profile_mode` to remove ambiguity.

Gate recommendation:

- Keep as info.

## Suggested CI Rule Set

- Fast iteration branch:
  - fail on `ERROR`
  - allow `WARN` with review
- Playtest/shipping branch:
  - fail on `ERROR`
  - fail on `unknown classname`, `unknown key`, `missing targetname`, `invalid profile_mode`
  - warn on duplication and cinematic/perf heuristics

