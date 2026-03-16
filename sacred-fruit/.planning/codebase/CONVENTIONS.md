# Coding Conventions

**Analysis Date:** 2026-03-15

## Naming Patterns

**Files:**
- All lowercase with underscores: `sky_map_controller.gd`, `func_portal.gd`
- Filename must match the FGD classname for entities (func_godot requirement)

**Classes (class_name):**
- PascalCase: `SkyMapController`, `TriggerExit`, `AIWaveSpawner`, `EnvPostFX`
- Entities use descriptive prefix: `Trigger*`, `Func*`, `Logic*`, `Env*`, `AI*`, `Math*`

**Functions:**
- snake_case: `_func_godot_apply_properties()`, `get_ai_patrol_points()`, `_on_body_entered()`
- Private methods prefixed with `_`: `_start()`, `_load_by_index()`, `_clear_map()`
- Signal callbacks prefixed with `_on_`: `_on_sky_build_complete()`, `_on_body_entered()`
- Targetfunc-callable methods (called by IOManager) are unprefixed, snake_case: `use()`, `load_sky_0()`, `clear_sky()`

**Variables:**
- snake_case: `_map_settings`, `_current_index`, `parallax_factor`
- Private instance vars prefixed with `_`: `_map`, `_camera`, `_started`
- Constants: ALL_CAPS: `INVERSE_SCALE`, `WORLDSPAWN_COLLIDER_THRESHOLD`, `RUNTIME_STATE_PATH`
- Exported movement params: SCREAMING_SNAKE_CASE: `JUMP_HEIGHT`, `WALKING_SPEED`

**Signals:**
- snake_case, past-tense or noun-changed: `player_died`, `objective_text_changed`, `io_event_dispatched`

**Enums:**
- Enum type: SCREAMING_SNAKE_CASE names, enum container in PascalCase class: `ActorFlags`, `ActorStates`

## Code Style

**Formatting:**
- `.editorconfig` present; tabs for indentation (Godot standard)
- `scripts/format_and_lint.sh` available for linting
- No Prettier/ESLint equivalents; GDScript linting via `gdtoolkit` (inferred from shell script)

**Typing:**
- Static typing used throughout: `var path: String`, `func _load_by_index(idx: int) -> void:`
- `Variant` used explicitly where type is genuinely unknown
- Typed arrays: `Array[Node3D]`, `Array[Dictionary]`, `Array[Resource]`

## Import Organization

**Pattern:**
1. `class_name` declaration (if any)
2. `extends` declaration
3. `const` preloads (dependencies)
4. Blank line
5. Signals
6. Enums
7. Constants
8. `@export` vars
9. Private vars

**Preload pattern (universal):**
```gdscript
const Util := preload("res://scripts/core/util.gd")
const Constants := preload("res://scripts/core/constants.gd")
```

**Path Aliases:** None — all paths use full `res://` prefix.

## Entity Convention: _func_godot_apply_properties

Every entity that receives map properties must implement:
```gdscript
func _func_godot_apply_properties(props: Dictionary) -> void:
    if props.has("targetname"):
        targetname = String(props["targetname"])
    if props.has("enabled"):
        enabled = Util.to_bool(props["enabled"], enabled)
    # ... one block per property
    _started = false
    _start()  # re-initialize with new properties
```

The `_started` flag + `_start()` pattern prevents double-initialization between `_func_godot_apply_properties` (called during map build) and `_ready()` (called when node enters tree).

## Error Handling

**Pattern for runtime `load()` calls:**
```gdscript
var packed_v: Variant = load(safe_path)
if packed_v == null:
    push_error("entity '%s': failed to load '%s'" % [name, safe_path])
    return
```

**Pattern for null node guards:**
```gdscript
if node == null or not is_instance_valid(node):
    return
```

**Safe property access:**
```gdscript
GAME._get_node_prop(node, "key", default_value)
```

## Logging

**Framework:** `Util.debug_print(msg)` — conditional on `Util.debug_enabled`

**Patterns:**
- Log prefix with entity name and system: `"[Portal DEBUG] %s ..."`, `"[GameManager] ..."`
- Use `push_warning()` for recoverable issues (e.g., empty sky path)
- Use `push_error()` for load failures and invalid state
- Never log in `_process()` unconditionally — always accumulate delta and throttle

**Throttled debug logging pattern (used in func_portal, func_mirror, photo_mode):**
```gdscript
const DEBUG_PRINT_INTERVAL := 0.6
var _debug_accum: float = 0.0

func _process(delta: float) -> void:
    _debug_accum += delta
    if _debug_accum < DEBUG_PRINT_INTERVAL:
        return
    _debug_accum = 0.0
    Util.debug_print("[Entity DEBUG] ...")
```

## Comments

**When to Comment:**
- Section headers using `# ---` dividers for logical blocks
- Exported params with inline `##` docstrings in complex entities
- Algorithmic choices that aren't obvious: coordinate system conversions, oblique clip math

**GDDoc (`##`):**
- Used on class-level doc in newer entities: `sky_map_controller.gd` has full `##` doc header
- Used on non-obvious `@export` vars

## Function Design

**Size:** Functions are generally focused; large files (func_portal 1687 lines, func_mirror 1399 lines, photo_mode 5683 lines) are split internally by `# ---` section headers, not extracted to separate files.

**Parameters:** Prefer named parameters; `Variant` for FGD property values before type coercion.

**Return Values:** Always typed; `void` for side-effect functions; early `return` on guard failures rather than deep nesting.

## Module Design

**Exports:** Each file exports one primary class via `class_name`. No barrel files.

**Circular dependency avoidance:** Use deferred `load()` rather than `preload()` where circular dependencies would occur (example: `sky_map_controller.gd` loads `map_settings.tres` at runtime to avoid `fgd_main.tres` → `fgd_point.tres` → this script cycle).

---

*Convention analysis: 2026-03-15*
