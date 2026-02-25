# Running Automated Tests

This project includes a minimal set of smoke tests written in GDScript. They exercise the shared
utility library and the I/O manager.

## Prerequisites

- Godot 4.x (the same version used by the project).  Make sure `godot` is on your PATH.

## Execute

From the project root (where `project.godot` lives) run:

```bash
# run util tests
godot --no-window --headless --script res://tests/util_test.gd

# run I/O manager smoke tests
godot --no-window --headless --script res://tests/io_test.gd

# run build profile verification (inspects project settings)
godot --no-window --headless --script res://tests/profile_test.gd

# run volume subclass smoke tests
godot --no-window --headless --script res://tests/volume_test.gd

# run AI authoring/query smoke tests
godot --no-window --headless --script res://tests/ai_authoring_test.gd

# run perf budget aggregation smoke tests
godot --no-window --headless --script res://tests/perf_budget_test.gd

# run portal plugin smoke test
godot --no-window --headless --script res://tools/portal_pair_smoke_test.gd

# run runtime map build smoke test (headless FuncGodot map build)
godot --no-window --headless --script res://tools/map_build_smoke.gd -- --map="res://tb/maps/fgd test.map" --timeout=45

# run dialogue integration smoke test (quest/faction gating + effects)
godot --no-window --headless --script res://tests/dialogue_integration_test.gd
```

Each script quits the engine when complete; failures will abort with an assertion error printed.

### CI integration

Use the CI wrapper script:

```bash
./tools/run_smoke_suite.sh
```

It runs:

- `tests/util_test.gd`
- `tests/io_test.gd`
- `tests/profile_test.gd`
- `tests/volume_test.gd`
- `tests/ai_authoring_test.gd`
- `tests/perf_budget_test.gd`
- `tests/dialogue_integration_test.gd`
- `tools/portal_pair_smoke_test.gd`
- `tools/map_build_smoke.gd`

Test files can be expanded over time; they're intentionally simple so they work without any running
scene or external dependencies.  The `tests/` folder is included in version control.

### Perf CSV diff reporting

Generate portal stress perf CSV and compare against baseline:

```bash
python ./tools/perf_regression_check.py \
  --output-csv artifacts/perf/portal_stress_current.csv \
  --summary-md artifacts/perf/portal_stress_report.md \
  --raw-log artifacts/perf/portal_stress_raw.log
```

Baseline CSV:

- `tests/perf_baselines/portal_stress_baseline.csv`

### Linting & TODO checks

Before committing, run the formatting/lint helper script to normalise style and
catch static analysis issues:

```bash
./scripts/format_and_lint.sh
```

A separate helper is available to scan for lingering `TODO` comments; it
fails if any are detected, which is handy for CI:

```bash
./scripts/scan_todos.sh
```

Add both commands to your CI pipeline so that formatting, lint and TODOs are
enforced on every push.
