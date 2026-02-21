# Environment Stack Order

This document defines how environment values are resolved at runtime.

Main runtime source:
- `scripts/sandstorm_controller.gd`

## 1. High-Level Order

At startup:
1. Script defaults and scene exports are loaded.
2. Map overrides are applied (if `allow_map_overrides = true`).
3. Base values are cached for runtime blending.

Every frame:
1. Zone blending updates selected values (if zones exist).
2. Final state is applied to particles, fog, and postfx.

## 2. Source Precedence (Startup)

For each system, precedence is:
1. First matching `env_*` entity in map file.
2. Fallback worldspawn keys (same key names where supported).
3. Controller defaults/exports.

Systems:
- Sandstorm:
  - `env_sandstorm` -> fallback worldspawn `sandstorm_*`
- Fog:
  - `env_fog_controller` -> fallback worldspawn fog keys
- Wind:
  - `env_wind` -> fallback worldspawn wind keys
- PostFX:
  - `env_postfx` -> fallback worldspawn postfx keys
- Weather:
  - `env_weather` -> fallback worldspawn weather keys
- Portal budget:
  - `env_portal_budget` -> fallback worldspawn portal budget keys
- Audio ambience:
  - `env_audio_ambience` -> fallback worldspawn ambience keys
- Zones:
  - `env_zone` entities are loaded as a list (no worldspawn fallback equivalent)

## 3. Zone Runtime Behavior

`env_zone` blending happens every frame using camera position.

Important details:
- Zones are radial (point-origin + `radius`).
- The highest-weight zone wins each frame (not additive blending across multiple zones).
- Before evaluating zones, these values are reset to cached base:
  - `intensity`
  - `fog_density_min`
  - `fog_density_max`
  - `wind_speed`
- Zone keys currently affect:
  - `intensity`
  - `fog_density`
  - `wind_speed`
- Zone does not currently override:
  - `fog_color`
  - postfx values
  - weather mode/intensity
  - audio settings

## 4. Portal Budget Override Scope

`env_portal_budget` applies globally to all `func_portal` nodes found in group `func_portal`.

Applied fields:
- `manager_max_active_portals`
- `manager_refresh_seconds`
- `render_scale`
- `dynamic_min_render_scale`

This happens during map override application, before normal runtime portal updates.

## 5. Common Authoring Pitfalls

1. Multiple entities of same type:
- Only the first matching non-zone `env_*` entity in map file is used.

2. Unexpected zone behavior:
- Overlapping zones do not blend together; strongest current zone is used.

3. Worldspawn fallback confusion:
- Worldspawn keys are only used when the corresponding `env_*` entity is absent.

4. FGD changes not visible:
- Reload TrenchBroom game config/FGD and rebuild map import in Godot.
