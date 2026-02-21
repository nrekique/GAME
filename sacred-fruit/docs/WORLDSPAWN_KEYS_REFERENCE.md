# Worldspawn Keys Reference

Reference for map-global keys authored on `worldspawn`.

## 1. Legacy `sf_*` Keys

Handled by:
- `entities/worldspawn.gd`
- `GAME.apply_worldspawn_globals(...)`

Keys:
- `sf_required_collectibles` (int, `>=0`)
- `sf_objective_text` (string)
- `sf_ps1_shader` (bool)
- `sf_ps1_dither_strength` (float, `>=0`)
- `sf_sun_energy` (float, `>=0`)
- `sf_fog_enabled` (bool)
- `sf_fog_density` (float, `>=0`)
- `sf_fog_color` (color string or color value)

## 2. Environment Fallback Keys

Handled by:
- `scripts/sandstorm_controller.gd`
- Used only when matching `env_*` entity is not present

### 2.1 Sandstorm fallback
- `sandstorm_enabled` (bool)
- `sandstorm_intensity` (`0..1`)
- `sandstorm_wind_speed` (float)
- `sandstorm_wind_direction` (`x z`)
- `sandstorm_fog_color` (`r g b`, `0..1` or `0..255`)

### 2.2 Fog fallback
- `fog_enabled` (bool)
- `volumetric_fog_enabled` (bool)
- `fog_density` (`0..0.2`)
- `volumetric_fog_density` (`0..0.2`)
- `fog_color`

### 2.3 Wind fallback
- `wind_speed` (float)
- `wind_direction` (`x z`)

### 2.4 PostFX fallback
- `postfx_strength` (`0..1`)
- `postfx_exposure` (`0.25..4`)
- `postfx_contrast` (`0.1..4`)
- `postfx_saturation` (`0..2`)

### 2.5 Weather fallback
- `weather_mode` (`none`/`rain`/`snow`)
- `weather_intensity` (`0..1`)

### 2.6 Portal budget fallback
- `portal_max_active` (int)
- `portal_refresh_seconds` (`0.02..0.5`)
- `portal_max_render_scale` (`0.25..1.0`)
- `portal_min_render_scale` (`0.25..1.0`)

### 2.7 Audio ambience fallback
- `ambience_stream` (`res://` path)
- `ambience_volume_db` (`-60..12`)
- `ambience_bus` (bus name)

## 3. Precedence

For environment systems:
1. First matching `env_*` point entity in map file.
2. Worldspawn fallback keys (above).
3. Script defaults/scene exports.

Notes:
- `env_zone` has no worldspawn equivalent.
- If multiple non-zone `env_*` entities exist, first one in the map file is used.

## 4. Example Worldspawn Snippet

```text
"classname" "worldspawn"
"sandstorm_intensity" "0.8"
"wind_direction" "1 0.25"
"fog_density" "0.045"
"weather_mode" "rain"
"weather_intensity" "0.35"
"portal_max_active" "4"
"portal_max_render_scale" "0.75"
```
