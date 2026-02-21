# Portal Tuning Playbook

This guide covers practical tuning for `func_portal` and map-level overrides via `env_portal_budget`.

## 1. What Controls What

Per-portal (`func_portal`):
- `render_scale`: max render quality cap per portal.
- `dynamic_quality_enabled`: enables distance/size-based scaling.
- `dynamic_min_render_scale`: minimum dynamic scale floor.
- `dynamic_near_distance`: starts near-quality band.
- `dynamic_far_distance`: reaches far-quality band.
- `dynamic_size_influence`: favors on-screen portal size vs distance.
- `dynamic_scale_step`: quantization step for scale changes.
- `manager_enable_budgeting`: enables manager-based active portal limit.
- `manager_max_active_portals`: max active portal renders.
- `manager_refresh_seconds`: manager update period.

Map-wide (`env_portal_budget`):
- `portal_max_active` -> overrides all portal `manager_max_active_portals`.
- `portal_refresh_seconds` -> overrides all portal `manager_refresh_seconds`.
- `portal_max_render_scale` -> overrides all portal `render_scale`.
- `portal_min_render_scale` -> overrides all portal `dynamic_min_render_scale`.

## 2. Recommended Presets

### 2.1 Performance First
- `portal_max_active = 2`
- `portal_refresh_seconds = 0.10`
- `portal_max_render_scale = 0.65`
- `portal_min_render_scale = 0.30`

Use when:
- Many simultaneous visible portals.
- Lower-end hardware targets.

### 2.2 Balanced Default
- `portal_max_active = 4`
- `portal_refresh_seconds = 0.08`
- `portal_max_render_scale = 0.75`
- `portal_min_render_scale = 0.35`

Use when:
- General gameplay maps.
- Mixed indoor/outdoor visibility.

### 2.3 Quality First
- `portal_max_active = 6`
- `portal_refresh_seconds = 0.05`
- `portal_max_render_scale = 0.90`
- `portal_min_render_scale = 0.45`

Use when:
- Fewer portals visible at once.
- Screenshot/cinematic-heavy maps.

## 3. Dynamic Quality Setup

Start with these `func_portal` values:
- `dynamic_quality_enabled = 1`
- `dynamic_near_distance = 6`
- `dynamic_far_distance = 32`
- `dynamic_size_influence = 0.65`
- `dynamic_scale_step = 0.05`

Rules of thumb:
- If distant portals still look too expensive: lower `portal_max_render_scale` or raise `dynamic_far_distance`.
- If nearby portals look soft: raise `dynamic_min_render_scale` and/or lower `dynamic_size_influence`.
- If quality flickers often: increase `dynamic_scale_step` slightly (e.g. `0.05` -> `0.1`).

## 4. Authoring Checklist

1. Portal pairing:
- A portal `target` must point to the other portal's `targetname`.
- For bidirectional traversal/rendering, set this both directions.

2. Keep portal dimensions intentional:
- Thin/sliver portals can degrade render stability and projection quality.

3. Set a map-level budget:
- Place one `env_portal_budget` in each performance-critical map.

## 5. Troubleshooting

Symptom: Too many portals tank FPS.
- Lower `portal_max_active`.
- Lower `portal_max_render_scale`.
- Increase `portal_refresh_seconds`.

Symptom: Nearby portals blurry.
- Increase `portal_max_render_scale`.
- Increase `portal_min_render_scale`.
- Decrease `dynamic_far_distance`.

Symptom: Portal quality pops aggressively.
- Increase `dynamic_scale_step`.
- Increase `manager_refresh_seconds` slightly.

Symptom: Budget settings seem ignored.
- Confirm `manager_enable_budgeting = 1` on `func_portal`.
- Confirm `env_portal_budget` exists in map and FGD reloaded.

## 6. Quick Copy/Paste (TrenchBroom)

`env_portal_budget`:
- `portal_max_active` `4`
- `portal_refresh_seconds` `0.08`
- `portal_max_render_scale` `0.75`
- `portal_min_render_scale` `0.35`
