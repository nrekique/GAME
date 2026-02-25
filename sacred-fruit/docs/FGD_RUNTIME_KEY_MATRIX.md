# FGD to Runtime Key Matrix

This matrix maps mapper-authored keys to runtime consumers.

Scope for this first pass:

- Core gameplay entities most likely to break maps when misconfigured.
- Exact script and property/method path where keyvalues are consumed.

## How to Read

- `FGD Key`: key shown in TrenchBroom.
- `Default`: default in `.tres` class definition.
- `Runtime Consumer`: script and target property/method.
- `Notes`: conversion, normalization, or behavior caveats.

## func_door (`tb/fgd/solid/funcs/func_door.tres`)

| FGD Key | Default | Runtime Consumer | Notes |
|---|---:|---|---|
| `required_key` | `""` | `res://entities/funcs/func_door.gd` -> `required_key` | Empty means no key required. Compared via lowercase/trim. |
| `consume_required_key` | `false` | `func_door.gd` -> `consume_required_key` | If true, consumes key on first successful open. |
| `auto_close` | `true` | `func_door.gd` -> `auto_close` | Controls delayed close path. |
| `wait` | `3.0` | `func_door.gd` -> `wait` | Seconds before auto-close timer runs. |
| `lock_open` | `false` | `func_door.gd` -> `lock_open` | Prevents manual close/toggle after opening. |
| `move_pos` | `0 0 0` | `res://entities/funcs/func_move.gd` -> `_move_pos_relative` | Converted Quake Units to Godot Units via `GameManager.INVERSE_SCALE`. |
| `move_rot` | `0 0 0` | `func_move.gd` -> `move_rot` | Degrees converted to radians. |
| `speed` | `120.0` | `func_move.gd` -> `speed` then `_move_rate` | Translation: units/sec. Rotation-only: degrees/sec semantics. |
| `target` | `""` | `func_door.gd` -> `GAME.use_targets(self, target)` | Fired on open. |

## item_key (`tb/fgd/point/items/item_key.tres`)

| FGD Key | Default | Runtime Consumer | Notes |
|---|---:|---|---|
| `key_id` | `"blue"` | `res://entities/items/item_key.gd` -> `key_id` | Given to `GAME.give_key(key_id)` on player overlap. |
| `auto_free` | `true` | `item_key.gd` -> `auto_free` | If true, key pickup queues free. |
| `targetname` | (base key) | `item_key.gd` -> `GAME.set_targetname(...)` | Group registration for I/O references. |

## logic_auto (`tb/fgd/point/logic/logic_auto.tres`)

| FGD Key | Default | Runtime Consumer | Notes |
|---|---:|---|---|
| `enabled` | `true` | `res://entities/logic/logic_auto.gd` | Disabled entities do not fire. |
| `fire_once` | `true` | `logic_auto.gd` | One-shot behavior. |
| `delay` | `0.0` | `logic_auto.gd` | Delay before firing outputs. |
| `target` | `""` | `logic_auto.gd` -> `GAME.use_targets(...)` | Target dispatch through I/O manager. |

## trigger_exit (`tb/fgd/solid/triggers/trigger_exit.tres`)

| FGD Key | Default | Runtime Consumer | Notes |
|---|---:|---|---|
| `map` | `""` | `res://entities/triggers/trigger_exit.gd` | Optional scene to load after successful `GAME.try_exit()`. |
| `delay` | `0.0` | `trigger_exit.gd` | Delay before scene transition. |
| `targetname` | (base key) | `Volume`/`GAME.set_targetname(...)` path | Enables external trigger wiring. |

## worldspawn (`tb/fgd/solid/worldspawn.tres`)

| FGD Key | Default | Runtime Consumer | Notes |
|---|---:|---|---|
| `sf_required_collectibles` | `-1` | `res://entities/worldspawn.gd` -> `GAME.apply_worldspawn_globals(...)` | Negative keeps current runtime value. |
| `sf_objective_text` | `""` | `worldspawn.gd` -> GameManager objective text | Non-empty overrides startup objective text. |
| `sf_ps1_shader` | `true` | `worldspawn.gd` -> PS1 manager toggle | Global per-map shader enable/disable. |
| `sf_ps1_dither_strength` | `-1.0` | `worldspawn.gd` -> PS1 manager params | Negative means keep current value. |
| `sf_sun_energy` | `-1.0` | `worldspawn.gd` -> first directional light energy | Negative means no override. |
| `sf_fog_enabled` | `false` | `worldspawn.gd` -> `Environment` fog flags | Applies if environment is available. |
| `sf_fog_density` | `-1.0` | `worldspawn.gd` -> `Environment.fog_density` | Negative means no override. |
| `sf_fog_color` | `Color(0,0,0,1)` | `worldspawn.gd` -> fog color/albedo | Applied with fog settings. |

## env_portal_budget (`tb/fgd/point/logic/env_portal_budget.tres`)

| FGD Key | Default | Runtime Consumer | Notes |
|---|---:|---|---|
| `profile_mode` | `"balanced"` | `res://entities/logic/env_portal_budget.gd` | Lint expects `cinematic|balanced|stress`. |
| `stress_profile` | `false` | `env_portal_budget.gd` | Enables aggressive stress defaults. |
| `portal_max_active` | `4` | `env_portal_budget.gd` | Runtime portal manager cap. |
| `portal_refresh_seconds` | `0.1` | `env_portal_budget.gd` | Portal manager update interval. |
| `portal_min_render_scale` | `0.3` | `env_portal_budget.gd` | Lower quality clamp. |
| `portal_max_render_scale` | `0.6` | `env_portal_budget.gd` | Upper quality clamp. |
| `mirror_max_active` | `2` | `env_portal_budget.gd` | Runtime mirror manager cap. |
| `mirror_refresh_seconds` | `0.08` | `env_portal_budget.gd` | Mirror manager update interval. |
| `mirror_render_scale` | `0.6` | `env_portal_budget.gd` | Mirror quality cap. |

## Next Expansion

Complete matrix coverage for all entity classes in:

- `tb/fgd/point/**/*.tres`
- `tb/fgd/solid/**/*.tres`

Recommended approach:

1. Use `.tres` `class_properties` as source of truth for key/default/type.
2. For each class, list `_func_godot_apply_properties(...)` and runtime behavior methods.
3. Keep one table per classname and link to consuming script.

