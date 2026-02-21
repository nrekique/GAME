# SF Symbols Icon Pipeline

Use this folder to manage SF Symbols source exports for TrenchBroom entity icons.

## Important
SF Symbols have Apple license restrictions. They are generally safe for Apple-platform app/tool use, but verify licensing for redistribution and non-Apple targets.

## Workflow
1. Open the SF Symbols app on macOS.
2. Export each symbol as SVG.
3. Name files using entity names from `ENTITY_SF_SYMBOL_MAP.md` (example: `item_health.svg`).
4. Export/convert to PNG and place final files in:
   `res://tb/fgd/entities/sprites/<entity>.png`

## Target entities
- env_sandstorm
- env_fog_controller
- env_wind
- env_postfx
- env_weather
- env_portal_budget
- env_audio_ambience
- env_zone
- env_message
- logic_auto
- logic_random
- logic_relay
- logic_timer
- math_counter
- multi_manager
- info_camera
- info_intermission
- item_ammo
- item_collectible
- item_health
- path_corner
