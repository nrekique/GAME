# Sacred Fruit Entity + Scripting Guide

This guide documents how entity scripting works in this repo right now, including the newly added `worldspawn` globals, `logic_auto`, `master`, and `killtarget` behavior.

## 1. Pipeline Overview

Authoring flow:
1. Build entities in TrenchBroom using `sacred-fruit/tb/fgd/sf_fgd.tres`.
2. FuncGodot imports map entities and applies keyvalues through `_func_godot_apply_properties(props)`.
3. Runtime behavior is implemented by scripts in `sacred-fruit/entities/**`.

Key runtime singleton:
- `GAME` (`/root/GAME`) from `sacred-fruit/game_manager.gd`.
- Core dispatch API is `GAME.use_targets(activator, target)`.

## 2. Core I/O Model (Target System)

### 2.1 `targetname`
- `targetname` is mapped to Godot groups via `GAME.set_targetname(node, targetname)`.
- Comma-delimited targetnames are supported.
- Any entity with the same `targetname` becomes part of the same target group.

### 2.2 `target`
- `target` can be comma-delimited.
- Each target token is treated as a group name.
- `GAME.use_targets(...)` calls target entities in each group once per group token.

### 2.3 `targetfunc`
- If activator has `targetfunc`, that method is invoked on target entities.
- If empty, fallback method is `use`.

### 2.4 `master` (new)
`master` is evaluated in `GAME.use_targets(...)` before firing outputs.

Behavior:
- If `master` is empty: outputs proceed.
- If `master` group has no nodes: outputs are blocked.
- If any node in master group is considered unlocked: outputs proceed.
- Otherwise outputs are blocked.

A master node is considered unlocked when one of these is true:
- Method exists and returns true: `is_unlocked`, `is_active`, `is_enabled`, `is_open`, or `is_on`.
- Property exists and is truthy: `unlocked`, `active`, `enabled`, `open`, `on`, or `button_pressed`.
- If no known method/property exists on a master node, that node is treated as unlocked.

### 2.5 `killtarget` (new)
- Applied after outputs fire.
- `killtarget` may be comma-delimited.
- Every node in each killtarget group is `queue_free()`'d.
- Duplicate node removals are deduplicated by instance id.

## 3. Worldspawn Globals (new)

Custom worldspawn definition: `sacred-fruit/tb/fgd/solid/worldspawn.tres`.
Runtime application:
- `sacred-fruit/entities/worldspawn.gd`
- `GAME.apply_worldspawn_globals(props, worldspawn)`

Important detail:
- Globals apply only when the key was explicitly authored in the map (not merely inherited default).
- This is done via source key tracking metadata (`func_godot_source_properties`) in FuncGodot import.

Supported keys:
- `sf_required_collectibles` (int)
  - `>= 0`: overrides `GAME.required_collectibles`.
- `sf_objective_text` (string)
  - non-empty: sets initial objective text.
- `sf_ps1_shader` (bool)
  - toggles `GAME` PS1 shader globally.
- `sf_ps1_dither_strength` (float)
  - `>= 0.0`: overrides PS1 color dither strength.
- `sf_sun_energy` (float)
  - `>= 0.0`: sets first `DirectionalLight3D.light_energy`.
- `sf_fog_enabled` (bool)
  - applies to `Environment.fog_enabled` and `Environment.volumetric_fog_enabled` if present.
- `sf_fog_density` (float)
  - `>= 0.0`: sets `Environment.fog_density` if present.
- `sf_fog_color` (Color/string)
  - sets `fog_light_color` and `volumetric_fog_albedo` when available.

## 4. Base Class Keyvalues

From base FGD resources (`sacred-fruit/tb/fgd/base/*`):

- `Targetname`
  - `targetname`
- `Target`
  - `target`
  - `targetfunc`
  - `master` (new)
  - `killtarget` (new)
- `Globalname`
  - `globalname`
- `Func`
  - `_phong`
- `Trigger`
  - inherits `Target` + `Targetname` + `Globalname`
- `Light`
  - `color`, `energy`, `indirect_energy`, `shadow_bias`, `shadows`
- `Actor`
  - `flags`, `scale`

## 5. Entity Reference

## 5.1 Point Entities

| Classname | Main keyvalues | Runtime behavior |
|---|---|---|
| `info_player_start` | `angles`, `active`, `targetname` | Places/rotates player at this marker on ready if active. |
| `info_intermission` | `angles`, `active`, `targetname` | Camera entity; sets `current = true` if active. |
| `info_camera` | `active`, `camera_target`, `targetname` | Camera that can be activated via `use()`. |
| `light` / `light_omni` | Light base + `range` | Omni light with QU->GU range conversion (`INVERSE_SCALE`). |
| `light_spot` | Light base + `range`, `angle`, `mangle` | Spot light with angle/range and orientation support. |
| `item_collectible` | `value`, `auto_free`, `targetname` | Calls `GAME.collect(value)` on player overlap. |
| `item_health` | `amount`, `allow_overheal`, `overheal_cap`, `auto_free`, `targetname` | Applies health to player (directly and via GAME fallback). |
| `item_ammo` | `ammo_type`, `amount`, `auto_free`, `targetname` | Calls `add_ammo` on player/GAME fallback. |
| `path_corner` | `target`, `wait`, `targetname` | Train path node for `func_train`. |
| `actor_marsfrog` | `flags`, `scale` (+ actor base) | Actor with basic animation/state reactions on `use()`. |
| `logic_auto` (new) | `enabled`, `fire_once`, `delay` + target base | Fires outputs automatically on spawn, optional delay, optional one-shot. |
| `logic_relay` | `enabled`, `trigger_once`, `delay` + target base | Relay with delayed optional one-shot fire. |
| `logic_timer` | `enabled`, `start_on_spawn`, `one_shot`, `wait`, `random_jitter` + target base | Interval-based output source. |
| `logic_random` | `enabled`, `target1..8` (+ `target`) + target base | Picks one target group at random and fires it. |
| `math_counter` | `value`, `min_value`, `max_value`, `step`, `fire_on_limit_only`, `enabled` + target base | Numeric counter with optional threshold-only output behavior. |
| `multi_manager` | `target1..8`, `delay1..8`, `enabled`, `trigger_once` + target base | Multi-output scheduler with per-target delays. |
| `env_message` | `message`, `hold_time`, `restore_default_text`, `enabled` + target base | Sets HUD objective text, optional restore, optional output firing. |

## 5.2 Solid / Brush Entities

| Classname | Main keyvalues | Runtime behavior |
|---|---|---|
| `worldspawn` (new override) | `sf_*` globals | Applies map-global gameplay/visual overrides. |
| `func_geo` | (none custom) | Static colliding geometry; occluder generation enabled. |
| `func_detail` | (none custom) | Static colliding detail; no occluders. |
| `func_illusionary` | (none custom) | Non-colliding decorative geometry; occluders enabled. |
| `func_detail_illusionary` | (none custom) | Non-colliding detail; no occluders. |
| `func_move` | `move_pos`, `move_rot`, `speed`, `targetname` | Interpolated movement/rotation with `use/toggle/mv_forward/mv_reverse`. |
| `func_door` | `target`, `wait`, `auto_close` + func_move/base target keys | Door open/close with optional auto-close and target firing on open. |
| `func_button` | `target`, `targetfunc`, `wait`, `once`, `targetname` | Touch-triggered output source with cooldown or one-shot. |
| `func_train` | `target`, `speed`, `targetname` | Moves along `path_corner` chain. |
| `func_portal` | `target`, `targetname`, `enabled`, `render_scale`, `teleport_cooldown`, `exit_offset`, `reverse_normal` | Linked render+teleport portal between portal pairs. |
| `func_mirror` | `enabled`, `mirror_axis`, `mirror_face_from_texture`, `render_scale`, `reverse_normal` | Solid reflective mirror (no teleport); place on a face textured with a mirror material. |
| `trigger_area` | trigger base keys | Single-use trigger; disables collision after first fire. |
| `trigger_once` | trigger base keys | Fires once on player enter. |
| `trigger_multiple` | `wait` + trigger base keys | Repeatable trigger with cooldown. |
| `trigger_hurt` | `dmg`, `wait`, `start_disabled`, `one_shot`, `targetname` | Applies periodic damage while player remains inside. |
| `trigger_changelevel` | `map`, `delay`, `targetname` | One-shot level transition trigger. |
| `trigger_exit` | `map`, `delay`, `targetname` | Calls `GAME.try_exit()`, optional scene change on success. |

## 6. Practical Recipes

### 6.1 Boot sequence with `logic_auto`
Use one `logic_auto` with:
- `target = setup_relay`
- `delay = 0.1`
- `fire_once = 1`

Then create `logic_relay` with `targetname = setup_relay` for startup chains.

### 6.2 Locked flow with `master`
Pattern:
1. Create a master entity with `targetname = door_master` and `enabled = 0` (e.g., `logic_relay`).
2. On the controlled activator (trigger/button/logic), set `master = door_master`.
3. Create an unlock event that calls `enable` on `door_master`.

Outputs from step 2 will be blocked until step 3 happens.

### 6.3 Cleanup with `killtarget`
On any activator that fires outputs, set:
- `killtarget = temp_fx,old_blocker`

After outputs execute, both groups are removed from scene tree.

### 6.4 Ordered sequence with `multi_manager`
- `target1 = seq_a`, `delay1 = 0.0`
- `target2 = seq_b`, `delay2 = 1.0`
- `target3 = seq_c`, `delay3 = 2.5`

Use `trigger_once = 1` for cutscene-style single-run behavior.

## 7. Test Plan (for your next refinement pass)

### 7.1 Core dispatch regression
1. Create 2 relays in same target group and fire once.
Expected: both relays execute once.

2. Set activator `target = a,b`.
Expected: both groups execute.

3. Set activator `targetfunc = enable` and ensure targets implement `enable()`.
Expected: `enable()` called, not `use()`.

### 7.2 `master` tests
1. `master` points to non-existent group.
Expected: activator is blocked.

2. `master` points to `logic_relay enabled=0`.
Expected: activator blocked.

3. Fire unlock relay that calls `enable` on master.
Expected: activator now fires outputs.

### 7.3 `killtarget` tests
1. Spawn visible entity with `targetname = cleanup_me`.
2. Fire activator with `killtarget = cleanup_me`.
Expected: entity disappears after activation.

### 7.4 `logic_auto` tests
1. `logic_auto fire_once=1 delay=0` triggers relay at map start.
2. `logic_auto fire_once=0`, manually call `use()` from another entity.
Expected: it can fire multiple times.

### 7.5 `worldspawn sf_*` tests
In worldspawn set one key at a time and rebuild map.
- `sf_required_collectibles = 0`: exit should be unlocked immediately.
- `sf_objective_text = "Find the reactor"`: HUD objective should start with this text.
- `sf_ps1_shader = 0`: PS1 shader should disable for scene.
- `sf_sun_energy = 0.3`: sunlight intensity should change.
- `sf_fog_enabled = 1`, `sf_fog_density = ...`, `sf_fog_color = ...`: fog should change.

## 8. Best Practices

- Keep `targetname` names consistent and scoped by system (`door_*`, `seq_*`, `ui_*`).
- Prefer `logic_relay` between raw triggers and gameplay-critical outputs for easier debugging.
- Use comma-delimited `target` only when genuinely parallel fan-out is needed.
- Use `master` for locks/gates, not ad-hoc checks in many entities.
- Use `killtarget` for one-time helpers, temporary blockers, and consumed setup entities.
- For cutscenes/sequences: `logic_auto` -> `multi_manager` -> small relays.
- Keep trigger shapes simple and avoid excessive overlap of multiple large triggers.
- For train paths, keep `path_corner` spacing smooth and set `wait` only where pauses are intended.
- For portal pairs, ensure dimensions and facing are intentional; pair by `target` -> `targetname`.
- When changing FGD definitions, rebuild/reload in TrenchBroom and rebuild the FuncGodot map in Godot before testing behavior.

## 9. Known Caveats

- Some older entity scripts still parse booleans with strict casts; prefer `0/1` in TB where possible.
- `InfoCamera` currently resolves `camera_target` by node naming convention (`entity_<name>`), so keep target ids stable.
- `worldspawn sf_*` values only apply when explicitly authored in map keyvalues.

---
If you want, next step I can add a compact in-game debug panel section that prints: activator, resolved target groups, master state, and killtarget execution in real time during test runs.
