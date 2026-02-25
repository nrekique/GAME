# Runtime Map Pipeline

This page documents the TrenchBroom to Godot runtime flow used by Sacred Fruit.

## Overview

1. TrenchBroom runs `tools/tb_run_map.sh`.
2. The script lints the map with `tools/tb_lint_map.sh`.
3. Godot is launched with `--tb-run-map "<map>"`.
4. `DEBUG` autoload parses startup args in `scripts/debug/debug.gd`.
5. Runtime map scene loads `scenes/runtime_map_play.tscn`.
6. `scripts/debug/runtime_map_play.gd` creates `FuncGodotMap`, builds the map, and spawns player/spectator.

## File Path Resolution

The runtime arg resolver accepts:

- `res://...`
- `tb/...`
- `/tb/...`
- relative paths such as `fgd test.map`

The canonical map location is:

- `res://tb/maps/...`

## Preflight Checks In `tb_run_map.sh`

- Disk free-space guard (default minimum: 1 GiB)
- Map lint pass (unless `TB_SKIP_LINT=1`)
- Stale Godot script-cache cleanup
- Godot launch with explicit user data directory and log path

## Common Failures

## `exit code 134` from TrenchBroom

Typical causes:

- shell launcher crash under heavy fork/exec pressure
- macOS app-launch edge cases

Current script behavior:

- import-cache audit is opt-in (`TB_ENABLE_IMPORT_CHECK=1`) to avoid heavy subprocess churn
- macOS tries app-bundle launch first, then falls back to direct binary

## Gray screen / map not loading

Check:

1. Parse errors in startup output
2. Missing script paths after file moves
3. Stale `.godot` caches referencing old paths

## Lint warnings during run

Warnings do not block startup by themselves.

Examples:

- `missing targetname` means entity wiring is incomplete
- `unknown classname in FGD` means map entity class is not defined in loaded FGD resources

## Recommended Debug Workflow

1. Run from terminal first:
   - `tools/tb_run_map.sh "fgd test.map"`
2. If map fails in editor but not headless, compare startup mode behavior.
3. Review latest logs in:
   - `.godot/tb_logs/`
4. For crash-level issues on macOS, inspect:
   - `~/Library/Logs/DiagnosticReports/`

## Useful Environment Flags

- `TB_SKIP_LINT=1` skip lint preflight
- `TB_SKIP_CACHE_REFRESH=1` skip stale-cache cleanup
- `TB_ENABLE_IMPORT_CHECK=1` enable expensive import artifact audit
- `TB_GODOT_USER_DATA_DIR=/custom/path` override user data path
- `TB_GODOT_LOG_FILE=/custom/path.log` set explicit log file
- `TB_FORCE_DIRECT_GODOT_BIN=1` bypass macOS app-bundle launch path

