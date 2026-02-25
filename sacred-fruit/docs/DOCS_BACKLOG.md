# Docs Backlog

This is the prioritized documentation backlog for mapper and runtime workflows.

## High Priority

- Runtime map troubleshooting playbook
  - Expand `RUNTIME_MAP_PIPELINE.md` with copy/paste checks for common crash signatures, log paths, and recovery steps.
- Door and key authoring examples
  - Add minimal, medium, and chained-lock examples (`item_key` + `func_door` + I/O).
- Entity class reference parity with FGD
  - Ensure every supported runtime entity in docs has matching key tables and usage notes.

## Medium Priority

- TrenchBroom icon style guide
  - Source file naming, export sizes, SF Symbols mapping, and replacement workflow.
- Map validation cookbook
  - Explain each lint warning type and when to fail CI vs allow warning.
- IO debugging cookbook
  - Real examples using `on_use`, `on_open`, `on_close`, and once-only triggers.

## Future / Nice to Have

- Performance budgets by map type
  - Suggested triangle/light/portal ranges for small, medium, large maps.
- Prefab kit production workflow
  - From module spec to validation map to version bump and migration notes.
- Compatibility notes
  - macOS/Windows differences for TrenchBroom launch + Godot runtime flags.

## Numbered Docs Gap Queue

- [x] 1. Runtime map pipeline doc
  - Added: launch flow, path resolution, preflight checks, and failure triage.
- [x] 2. Entity interaction contract
  - Added: `can_interact`/`interact` expectations and key/door runtime contract.
- [x] 3. Door/key authoring examples
  - Added: reusable/single-use lock patterns, swinging door setup, and debugging checklist.
- [ ] 4. FGD-to-runtime key matrix
  - Per-entity table of every mapper key, default, type, and exact consuming script/property.
- Phase 1 shipped in `FGD_RUNTIME_KEY_MATRIX.md` for high-impact entities (`func_door`, `item_key`, `logic_auto`, `trigger_exit`, `worldspawn`, `env_portal_budget`).
- Next: expand to full coverage for all point/solid classes.
- [x] 5. Runtime logs and crash signatures index
  - Canonical error dictionary (`exit 134`, parse errors, missing resource paths) with targeted fixes.
- [x] 6. Mapping validation cookbook
  - Warning-by-warning lint explanations plus “fix now vs allow temporarily” guidance.
- [x] 7. Documentation contribution workflow
  - Where to add docs, naming conventions, nav update rules, and review checklist before merge.
