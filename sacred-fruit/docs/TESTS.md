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
```

Each script quits the engine when complete; failures will abort with an assertion error printed.

### CI integration

Add the above commands to your CI pipeline (use a headless runner) so the tests run on every push.

Test files can be expanded over time; they're intentionally simple so they work without any running
scene or external dependencies.  The `tests/` folder is included in version control.

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
