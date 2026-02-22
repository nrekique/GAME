# Entity I/O System

The runtime entity I/O dispatcher is implemented by `IOManager` (`res://scripts/io_manager.gd`) and exposed through the `GAME` autoload.

## Core APIs

- `GAME.use_targets(activator, target, overrides = {})`
  - Dispatches to all entities in `targetname` group(s).
  - Supports optional:
    - `input` (defaults to `targetfunc` or `use`)
    - `arg` (defaults to `targetarg`)
    - `delay` (defaults to `targetdelay`)
    - `source_output`
    - `once`
- `GAME.io_fire_output(activator, output_value, source_output = "", default_input = "use")`
  - Parses output rows in this format:
  - `target,input,arg,delay,once`
  - Multiple rows can be separated with `;`
- `GAME.fire_output(activator, output_key, fallback_target = "", default_input = "use")`
  - Reads output text from `activator` property key and dispatches via parser.
- `GAME.io_get_trace()`
  - Returns recent dispatch event list.
- `GAME.io_clear_trace()`
  - Clears event trace and once-only cache.

## Dispatch Rules

- Master lock (`master`) is respected before dispatch.
- Killtarget (`killtarget`) is applied after dispatch (or after delay if delayed dispatch is used).
- Target invocation order:
  1. `io_input(input_name, arg, activator, caller)` if present.
  2. Method named by `input_name`.
  3. Fallback to `use`.
- Method invocation is arity-aware (best-effort argument count matching).

## FGD Base Keys

In addition to existing `target`, `targetfunc`, `killtarget`, `master`:

- `targetarg`: optional argument payload.
- `targetdelay`: optional delay before dispatch (seconds).

Defined in:
- `res://tb/fgd/base/target_base.tres`

## Debugging

- Enable `GAME.io_debug_logging` to print dispatch logs.
- Listen for signal:
  - `GAME.io_event_dispatched(event: Dictionary)`
