# Code Style & Formatting

To keep the GDScript code consistent across the project, we use a formatter and a few
conventions:

* **gdformat** – run the shell script at `scripts/format_and_lint.sh` (requires `pip install gdformat`).
  It will reformat every `.gd` file in the workspace.
* **Utilize snake_case** for variables and methods.  Avoid mixing camelCase where possible.
* **Preload shared helpers** at the top of a file (e.g. `const Util := preload("res://scripts/core/util.gd")`).
* **Use `Util.editor_hint()`** instead of `Engine.is_editor_hint()` for editor-only checks.
* **Wrap debug output** with `Util.debug_print` so it respects the global toggle.

Run `scripts/format_and_lint.sh` before committing; this can be added as a Git pre-commit hook.

A future task is to integrate a linter (e.g. `godot-lint`) to automatically check naming, unused
variables, etc.  Refer to `DEVELOPMENT_TODO.md` for the remaining style‑related items.
