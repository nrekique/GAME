# TrenchBroom Entity Quick Reference

Quick authoring sheet for common gameplay/environment entities.

## Core Logic

`logic_auto`
- `enabled` (`0/1`)
- `fire_once` (`0/1`)
- `delay` (seconds)
- `target`, `targetfunc`

`logic_relay`
- `enabled` (`0/1`)
- `trigger_once` (`0/1`)
- `delay` (seconds)
- `target`, `targetfunc`

`logic_timer`
- `enabled` (`0/1`)
- `start_on_spawn` (`0/1`)
- `one_shot` (`0/1`)
- `wait`, `random_jitter`
- `target`

## Portals

`func_portal` (pairing required)
- `target` -> other portal `targetname`
- `targetname` -> name this portal
- `enabled` (`0/1`)
- `render_scale` (`0.25..1.0`)
- `dynamic_min_render_scale` (`0.25..1.0`)
- `dynamic_near_distance`
- `dynamic_far_distance`
- `manager_enable_budgeting` (`0/1`)
- `manager_max_active_portals`
- `manager_refresh_seconds`

`env_portal_budget` (global)
- `portal_max_active`
- `portal_refresh_seconds`
- `portal_max_render_scale`
- `portal_min_render_scale`

`perf_budget_marker`
- `enabled` (`0/1`)
- `cost` (base local perf cost)
- `radius` (influence radius)
- `falloff_exponent` (center weighting; higher is steeper)
- `budget_limit` (optional local cap; `<=0` uses global HUD thresholds)
- `tag` (optional grouping key)

`perf_heatmap_volume`
- `enabled` (`0/1`)
- `cost` (added while inside volume)
- `extents` (`x y z` half-size)
- `budget_limit` (optional local cap)
- `tag` (optional grouping key)

## Environment

`env_sandstorm`
- `enabled` (`0/1`)
- `intensity` (`0..1`)
- `wind_speed`
- `wind_direction` (`x z`, example: `1 0.25`)
- `fog_color` (`r g b`, supports `0..1` or `0..255`)

`env_fog_controller`
- `fog_enabled` (`0/1`)
- `volumetric_fog_enabled` (`0/1`)
- `fog_density` (`0..0.2`)
- `volumetric_fog_density` (`0..0.2`)
- `fog_color`

`env_wind`
- `wind_speed`
- `wind_direction`

`env_postfx`
- `postfx_strength` (`0..1`)
- `postfx_exposure` (`0.25..4`)
- `postfx_contrast` (`0.1..4`)
- `postfx_saturation` (`0..2`)

`env_weather`
- `weather_mode` (`none`/`rain`/`snow`)
- `weather_intensity` (`0..1`)

`env_audio_ambience`
- `ambience_stream` (`res://...` audio resource path)
- `ambience_volume_db` (`-60..12`)
- `ambience_bus` (default: `SFX`)

`env_zone` (radial point zone)
- `enabled` (`0/1`)
- `radius`
- `intensity`
- `fog_density`
- `wind_speed`
- `light_cull_mask` (`-1` to ignore)
- `reflection_cull_mask` (`-1` to ignore)
- `reflection_intensity_scale` (`-1` to ignore)

`env_reflection_probe`
- `enabled` (`0/1`)
- `box_size` (`x y z`)
- `update_mode` (`once`/`always`)
- `probe_intensity`
- `probe_cull_mask`

`func_prefab_instance`
- `prefab_scene` (`res://...tscn`)
- `spawn_on_ready` (`0/1`)
- `one_shot` (`0/1`)
- `clear_children_before_spawn` (`0/1`)
- `override_json` (JSON Dictionary keyed by `node_path:property`)

`env_sky_scene`
- `sky_scene` (`res://...tscn`)
- `load_on_ready` (`0/1`)
- `follow_camera` (`0/1`)
- `copy_camera_rotation` (`0/1`)
- `position_offset` (`x y z`)
- `rotation_speed_deg` (`x y z` degrees/sec)

## Physics Props

`physics_ball` (tumbleweed-ready)
- `tumbleweed_enabled` (`0/1`)
- `interact_pickup_enabled` (`0/1`)
- `radius`
- `mass_kg`
- `wind_response`
- `rolling_torque`
- `max_speed`
- `water_buoyancy` (`0..3`, `1` neutral, `<1` sinks, `>1` floats)

## Triggers

`trigger_once`
- `target`, `targetfunc`

`trigger_multiple`
- `wait`
- `target`, `targetfunc`

`trigger_hurt`
- `dmg`
- `wait`
- `start_disabled` (`0/1`)
- `one_shot` (`0/1`)

## Doors

`func_door` (swinging or translating)
- `move_rot` (`x y z` degrees; use `0 90 0` for a 90deg Y swing)
- `move_pos` (`x y z` in Quake units; leave `0 0 0` for pure swing)
- `speed` (default `120`; translation uses Q1 units/sec, rotation-only uses deg/sec)
- `auto_close` (`0/1`)
- `wait` (seconds before close if `auto_close=1`)
- `lock_open` (`0/1`)
- `required_key` (optional key id, e.g. `blue`, `two`)
- `consume_required_key` (`0/1`, consumes key on first open)

## Volumes

_These areas emit `body_entered(body)` and `body_exited(body)` signals._

`damage_volume`
- `amount` (damage applied on entry)
- `enabled` (`0/1`)

`checkpoint_volume`
- `enabled` (`0/1`)
- `checkpoint_id` (optional unique checkpoint key)
- `save_id` (optional persistence key)
- `starts_enabled` (`0/1`)
- `one_shot` (`0/1`)

`music_zone_volume`
- `tag` (zone name)
- `enabled` (`0/1`)

`ai_alert_volume`
- `enabled` (`0/1`)

`quest_trigger_volume`
- `tag` (optional identifier)
- `enabled` (`0/1`)

`spawn_blocker_volume`
- `enabled` (`0/1`)

`water_volume`
- `enabled` (`0/1`)
- `starts_enabled` (`0/1`)
- `default_buoyancy` (`0..3`, `1` neutral, `<1` sinks, `>1` floats)
- `linear_drag`
- `angular_drag`
- `affect_sleeping_bodies` (`0/1`)
- Use a normal water-textured brush (`special/water`) for visuals and swim volume in one.

## AI Authoring (Phase 1)

`ai_nav_region`
- `enabled` (`0/1`)
- `region_id` (optional unique id)
- `nav_tag` (optional category: `indoor`, `rooftop`, etc.)
- `radius`

`ai_patrol_point`
- `enabled` (`0/1`)
- `route_id` (route/group id)
- `order` (integer ordering within route)
- `target` (optional next point `targetname`; shows TrenchBroom link arrow)
- `wait` (seconds)

`ai_cover_marker`
- `enabled` (`0/1`)
- `team` (optional team filter)
- `exposure` (`0..1`)
- `crouch_only` (`0/1`)

`ai_perception_blocker`
- `enabled` (`0/1`)
- `radius`

`ai_spawn_wave_point`
- `enabled` (`0/1`)
- `wave_id`
- `squad_id` (optional)
- `max_spawn_count`
- `cooldown`

`ai_wave_spawner`
- `enabled` (`0/1`)
- `wave_id`
- `squad_id` (optional)
- `npc_scene` (`res://...tscn`)
- `spawn_on_ready` (`0/1`)
- `spawn_interval`
- `max_alive`
- `total_spawn_limit`

`npc` (AI keys)
- `ai_enabled` (`0/1`)
- `ai_route_id`
- `ai_patrol_speed`
- `ai_alert_duration`
- `ai_reacts_to_alerts` (`0/1`)

Runtime debug:
- `F7` toggles AI HUD (controller counts/states, route/point summary).

`npc_enemy_patrol` (preset)
- `ai_enabled` default `1`
- `dialogue_enabled` default `0`
- `ai_route_id` default `enemy_patrol`
- Uses same scene as `npc`, but tuned for drop-in patrol enemies.

Basic path setup:
1. Place one `npc_enemy_patrol`.
2. Set `ai_route_id` (example: `enemy_patrol_a`).
3. Place at least 2 `ai_patrol_point` entities with matching `route_id`.
4. Set patrol `order` values (0, 1, 2...) to define loop path.
5. Optional visual links: give each patrol point a `targetname`, then set each point's `target` to the next point `targetname` to display route arrows in TrenchBroom.

## Interactions

- Player `use` input is mapped to `E`.
- `func_button` now supports both interaction styles:
  - `touch_activates` (`0/1`)
  - `interact_activates` (`0/1`)
- `physics_ball` supports pickup/drop via `use` ray interaction.

## Target I/O Reminders

- `targetname` defines group membership.
- `target` fires group(s), comma-separated supported.
- `targetfunc` chooses called method (default `use`).
- `targetarg` optional argument payload passed to target input.
- `targetdelay` optional delay (seconds) before dispatch.
- `master` gates outputs through another entity/group.
- `killtarget` removes entities by group after fire.
