# Runtime Logs and Crash Signatures

Canonical error dictionary for TrenchBroom -> Godot runtime map launches.

Use this with:

- [Runtime Map Pipeline](RUNTIME_MAP_PIPELINE.md)
- `tools/tb_run_map.sh`

## Where Logs Are Written

Default log path from `tb_run_map.sh`:

- `.godot/tb_logs/tb_run_*.log`

Overrides:

- `TB_GODOT_LOG_DIR=/custom/dir`
- `TB_GODOT_LOG_FILE=/custom/file.log`
- `TB_GODOT_USER_DATA_DIR=/custom/userdata`

## Signature Index

## 1) `Finished with exit code 134`

Typical meaning:

- Launch process aborted before normal runtime initialization.

Known causes in this project:

- macOS app/binary launch path instability.
- Shell/process pressure from expensive preflight checks.

Targeted fixes:

1. Use the current launcher behavior (app bundle first, binary fallback).
2. Keep import-cache audit opt-in (`TB_ENABLE_IMPORT_CHECK=1` only when diagnosing).
3. Run from terminal first:
   - `tools/tb_run_map.sh "tb/maps/your_map.map"`
4. If needed, force direct binary once to compare:
   - `TB_FORCE_DIRECT_GODOT_BIN=1 tools/tb_run_map.sh "tb/maps/your_map.map"`

## 2) Gray screen, no map content

Typical meaning:

- Runtime map scene loaded, but map build script failed (often parse/load failure).

Common companion errors:

- `Could not preload resource script "..."`
- `Failed to load script ... with error "Parse error".`

Targeted fixes:

1. Open latest `.godot/tb_logs/tb_run_*.log`.
2. Fix first parse/resolve error (later errors are usually cascade failures).
3. Refresh stale script cache (default script already does this):
   - remove `.godot/global_script_class_cache.cfg` and related caches if needed.
4. Re-run with same map path from terminal for cleaner output ordering.

## 3) `Could not find type "X" in the current scope`

Typical meaning:

- Script uses typed class reference that cannot be resolved.

Likely causes:

- Moved/renamed script without updating preload/class reference.
- Stale script-class cache after file reorganization.

Targeted fixes:

1. Verify referenced `class_name` script exists at current path.
2. Verify any `preload("res://...")` path is valid.
3. Let `tb_run_map.sh` clear stale cache, then rerun.
4. If issue persists, restart editor/runtime after cache clear.

## 4) `Could not preload resource script "res://addons/func_godot/..."`

Typical meaning:

- FuncGodot script dependency chain could not compile/resolve.

Likely causes:

- Missing/moved addon files.
- Parse error in one of dependent scripts.

Targeted fixes:

1. Confirm `addons/func_godot` files are present in repo.
2. Fix first parse/type error in the same log.
3. Re-run map after cache refresh.

## 5) `Error loading GDExtension configuration file` / `GDExtension dynamic library not found`

Typical meaning:

- Project is referencing a missing `.gdextension` file/library.

Example from prior failures:

- `res://addons/GodotApplePlugins/godot_apple_plugins.gdextension`

Targeted fixes:

1. If plugin is intentionally removed, remove all project/plugin references to it.
2. If plugin is required, restore addon folder and correct platform binary entries.
3. Re-run to ensure no extension load errors appear before gameplay startup.

## 6) `Failed to open 'user://logs/...'.` followed by crash/backtrace

Typical meaning:

- Runtime failed creating/writing expected log destination, then crashed during startup logging.

Likely causes:

- Low disk space.
- Unwritable user-data/log location.

Targeted fixes:

1. Free disk space.
2. Set explicit writable log file:
   - `TB_GODOT_LOG_FILE=/tmp/sf_tb_run.log`
3. Set explicit writable user data:
   - `TB_GODOT_USER_DATA_DIR=/tmp/sf_userdata`
4. Re-run.

## 7) Lint warnings block behavior indirectly

Common warnings:

- `key "target" references missing targetname "..."`.
- `unknown classname in FGD`.

Meaning:

- Warnings do not directly abort launch, but can make map logic appear broken.

Targeted fixes:

1. Resolve missing targetname wiring.
2. Replace/remove unsupported classes (like helper `func_group`) before runtime tests.
3. Use [Map Validation Cookbook](MAP_VALIDATION_COOKBOOK.md) for warning policy.

## Fast Triage Sequence

1. Run once from terminal.
2. Open latest `.godot/tb_logs/tb_run_*.log`.
3. Fix first hard error:
   - extension load
   - parse/type error
   - path/resource not found
4. Re-run and only then evaluate remaining warnings.

