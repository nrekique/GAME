# Sacred Fruit Entity + Scripting Guide

This guide documents how entity scripting works in this repo right now, including `worldspawn` globals, `logic_auto`, `master`, `killtarget`, and runtime environment controllers (`env_*`).

## See Also

- `docs/PORTAL_TUNING_PLAYBOOK.md`
- `docs/MIRROR_POLICY.md`
- `docs/ENV_STACK_ORDER.md`
- `docs/TB_ENTITY_QUICK_REFERENCE.md`
- `docs/WORLDSPAWN_KEYS_REFERENCE.md`

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
| `physics_ball` | `tumbleweed_enabled`, `radius`, `mass_kg`, `wind_response`, `rolling_torque`, `max_speed` | `RigidBody3D` physics prop. In tumbleweed mode it samples map wind/sandstorm settings and rolls with gusting wind force. |
| `npc` | `flags`, `scale`, `targetname` (+ actor base) | Generic NPC actor entity using the default NPC scene. |
| `path_corner` | `target`, `wait`, `targetname` | Train path node for `func_train`. |
| `logic_auto` (new) | `enabled`, `fire_once`, `delay` + target base | Fires outputs automatically on spawn, optional delay, optional one-shot. |
| `logic_relay` | `enabled`, `trigger_once`, `delay` + target base | Relay with delayed optional one-shot fire. |
| `logic_timer` | `enabled`, `start_on_spawn`, `one_shot`, `wait`, `random_jitter` + target base | Interval-based output source. |
| `logic_random` | `enabled`, `target1..8` (+ `target`) + target base | Picks one target group at random and fires it. |
| `math_counter` | `value`, `min_value`, `max_value`, `step`, `fire_on_limit_only`, `enabled` + target base | Numeric counter with optional threshold-only output behavior. |
| `multi_manager` | `target1..8`, `delay1..8`, `enabled`, `trigger_once` + target base | Multi-output scheduler with per-target delays. |
| `env_message` | `message`, `hold_time`, `restore_default_text`, `enabled` + target base | Sets HUD objective text, optional restore, optional output firing. |
| `env_sandstorm` | `enabled`, `intensity`, `wind_speed`, `wind_direction`, `fog_color` | Global sandstorm controller source. Drives overlay, dust particles, and fog tint/density in runtime map play. |
| `env_fog_controller` | `fog_enabled`, `volumetric_fog_enabled`, `fog_density`, `volumetric_fog_density`, `fog_color` | Forces environment fog settings for the map. |
| `env_wind` | `wind_speed`, `wind_direction` | Sets global wind vector/speed used by weather and sand effects. |
| `env_postfx` | `postfx_strength`, `postfx_exposure`, `postfx_contrast`, `postfx_saturation` | Applies environment post-adjustments through `WorldEnvironment` adjustment/tonemap properties. |
| `env_weather` | `weather_mode`, `weather_intensity` | Enables rain/snow-style ambient particles around camera. |
| `env_portal_budget` | `portal_max_active`, `portal_refresh_seconds`, `portal_max_render_scale`, `portal_min_render_scale` | Applies runtime portal budgeting overrides to all `func_portal` entities. |
| `env_audio_ambience` | `ambience_stream`, `ambience_volume_db`, `ambience_bus` | Plays looped ambience stream at map runtime via `AudioStreamPlayer`. |
| `env_zone` | `radius`, `intensity`, `fog_density`, `wind_speed` | Radial local override zone blended by camera distance. |

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
| `func_portal` | `target`, `targetname`, `enabled`, `render_scale`, `dynamic_min_render_scale`, `dynamic_near_distance`, `dynamic_far_distance`, `manager_enable_budgeting`, `manager_max_active_portals`, `manager_refresh_seconds`, `teleport_cooldown`, `exit_offset`, `reverse_normal` | Linked render+teleport portal with runtime dynamic quality scaling and global budget manager support. |
| `func_mirror` | `enabled`, `mirror_axis`, `mirror_face_from_texture`, `mirror_flip_u`, `mirror_tint`, `mirror_distortion`, `render_scale`, `render_cull_exclude_layers`, `reverse_normal` | Solid reflective mirror (no teleport); place on a face textured with a mirror material. Supports tint, optional distortion, and mirror-camera layer filtering. Plugin mirror backend is the default path. |
| `trigger_area` | trigger base keys | Single-use trigger; disables collision after first fire. |
| `trigger_once` | trigger base keys | Fires once on player enter. |
| `trigger_multiple` | `wait` + trigger base keys | Repeatable trigger with cooldown. |
| `trigger_hurt` | `dmg`, `wait`, `start_disabled`, `one_shot`, `targetname` | Applies periodic damage while player remains inside. |
| `trigger_changelevel` | `map`, `delay`, `targetname` | One-shot level transition trigger. |
| `trigger_exit` | `map`, `delay`, `targetname` | Calls `GAME.try_exit()`, optional scene change on success. |
| `damage_volume` | `amount`, `enabled` | Applies instant damage (calls `apply_damage()`) when bodies enter. |
| `checkpoint_volume` | `enabled` | Respawns player at volume when entered (uses `GAME.handle_player_death`). |
| `music_zone_volume` | `tag`, `enabled` | Switches music zone on entry. |
| `ai_alert_volume` | `enabled` | Notifies AI system of entrant position. |
| `quest_trigger_volume` | `tag`, `enabled` | Placeholder for quest scripting; no default action. |
| `spawn_blocker_volume` | `enabled` | Marks area where spawning should be avoided. |

### 5.2.1 Portal Runtime Notes

`func_portal` behavior is implemented in `entities/funcs/func_portal.gd` and supports:
- Dynamic per-portal render scaling based on distance/size:
  - `dynamic_quality_enabled`
  - `dynamic_min_render_scale`
  - `dynamic_near_distance`
  - `dynamic_far_distance`
  - `dynamic_size_influence`
  - `dynamic_scale_step`
- Runtime portal manager budgeting:
  - `manager_enable_budgeting`
  - `manager_max_active_portals`
  - `manager_refresh_seconds`
- Base plugin settings:
  - `plugin_keep_viewports_hot`
  - `plugin_teleport_collision_mask`
  - `render_scale`

Pairing:
- Portal A links to Portal B by setting `target` on A to B's `targetname`.
- Portal B should reciprocate for bidirectional portals.

Interaction with `env_portal_budget`:
- `env_portal_budget` applies map-wide overrides to all `func_portal` nodes at runtime:
  - `manager_max_active_portals`
  - `manager_refresh_seconds`
  - `render_scale` (max quality cap)
  - `dynamic_min_render_scale` (min quality floor)

## 5.3 Environment Entity Rules

Runtime environment parsing is centralized in `scripts/sandstorm_controller.gd`.

Priority and fallback:
1. Specific `env_*` point entity for that system (first matching entity in map file).
2. `worldspawn` fallback keys (same key names where supported).

Systems and keys:
- Sandstorm: `env_sandstorm` or worldspawn `sandstorm_*`
  - `sandstorm_enabled`, `sandstorm_intensity`, `sandstorm_wind_speed`, `sandstorm_wind_direction`, `sandstorm_fog_color`
- Fog: `env_fog_controller` or worldspawn fog keys
  - `fog_enabled`, `volumetric_fog_enabled`, `fog_density`, `volumetric_fog_density`, `fog_color`
- Wind: `env_wind` or worldspawn wind keys
  - `wind_speed`, `wind_direction`
- PostFX: `env_postfx` or worldspawn postfx keys
  - `postfx_strength`, `postfx_exposure`, `postfx_contrast`, `postfx_saturation`
- Weather: `env_weather` or worldspawn weather keys
  - `weather_mode` (`none`/`rain`/`snow`), `weather_intensity`
- Portal budget: `env_portal_budget` or worldspawn portal keys
  - `portal_max_active`, `portal_refresh_seconds`, `portal_max_render_scale`, `portal_min_render_scale`
- Audio ambience: `env_audio_ambience` or worldspawn ambience keys
  - `ambience_stream`, `ambience_volume_db`, `ambience_bus`
- Zones: `env_zone` only (multiple supported)
  - `radius`, `intensity`, `fog_density`, `wind_speed`

Notes:
- `env_zone` is currently point/radial (not brush volume).
- `env_zone.origin` is parsed from map origin and converted into Godot coordinates with map scale.
- If multiple entities of the same non-zone type are authored, first one in the `.map` is used.

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

### 7.6 Environment `env_*` tests
1. Place one `env_sandstorm` with `intensity=0.9`.
Expected: visible storm overlay + dust + fog tint at runtime.

2. Place one `env_fog_controller` with high `fog_density`.
Expected: fog values in active `WorldEnvironment` update on load.

3. Place one `env_wind` with changed direction/speed.
Expected: storm/weather particle motion direction updates.

4. Place one `env_postfx` with `postfx_strength=1`, boosted contrast/saturation.
Expected: noticeable global color adjustment.

5. Place one `env_weather` with `weather_mode=rain`, non-zero intensity.
Expected: rain-like particle behavior around camera.

6. Place one `env_portal_budget` with low max active portals.
Expected: fewer active portal renders and lower portal render scale caps.

7. Place one `env_audio_ambience` with valid stream path.
Expected: ambience plays on configured bus and volume.

8. Place two `env_zone` points with different radii/intensities.
Expected: camera movement between zones blends local overrides.

### 7.7 Portal tests
1. Create two linked `func_portal` entities with reciprocal `target`/`targetname`.
Expected: both render and teleport when traversed.

2. Set per-portal dynamic quality spread:
- `render_scale = 1.0`
- `dynamic_min_render_scale = 0.35`
- `dynamic_near_distance = 6`
- `dynamic_far_distance = 32`
Expected: near/large portals stay sharp, far/small portals reduce scale.

3. Place `env_portal_budget` with:
- `portal_max_active = 2`
- `portal_refresh_seconds = 0.1`
- `portal_max_render_scale = 0.8`
- `portal_min_render_scale = 0.3`
Expected: global cap limits concurrent active portal rendering and applies scale bounds to all portals.

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
