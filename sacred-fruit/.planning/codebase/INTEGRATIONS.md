# External Integrations

**Analysis Date:** 2026-03-15

## Level Pipeline — TrenchBroom + func_godot

**Authoring tool:** TrenchBroom (external, not vendored)
**Import plugin:** `addons/func_godot/` v2025.1
**Pipeline flow:**
1. Maps authored in TrenchBroom using `tb/fgd/sacredFruit.fgd` (generated from `sf_fgd.tres`)
2. `.map` files saved to `tb/maps/`
3. `FuncGodotMap` nodes in Godot scenes reference `.map` files and call `verify_and_build()` at runtime or editor build time
4. Entity scripts are spawned by func_godot matching classnames in the FGD

**Key resources:**
- `tb/fgd/sf_fgd.tres` — top-level FGD export resource; points to `fgd_main.tres`
- `tb/fgd/fgd_main.tres` — aggregates base, solid, point FGD sub-files
- `tb/fgd/map_settings.tres` — FuncGodotMapSettings: inverse scale 32, textures at `res://tb/textures/`, material extension `.tres`
- `tb/fgd/game_cfg.tres` — TrenchBroomGameConfig: entity scale 0.25, search path `tb/`
- `tb/fgd/map_settings_grill.tres` — separate settings for the grill level

**Scale convention:** 1 Quake unit = `INVERSE_SCALE` (0.03125) Godot units; map settings use inverse_scale_factor of 32.

## Quake Unit / Godot Unit Conversion

Used throughout `game_manager.gd`:
- `GameManager.id_vec_to_godot_vec()` — converts Quake axis orientation (Y-up, Y-forward) to Godot (Y-up, Z-back)
- `INVERSE_SCALE = 0.03125` constant used for coordinate translation

## APIs & External Services

None — fully offline, no external API calls.

## Data Storage

**Persistence:**
- `user://runtime_state.cfg` — checkpoint and entity-enabled state (read/write via `ConfigFile`)
- `user://runtime_state.cfg.bak` — automatic backup before save
- Managed by `game_manager.gd` (`_load_runtime_state`, `_save_runtime_state`)

**File Storage:**
- Local filesystem only; textures, maps, and models under `tb/`

**Caching:**
- None

## Authentication & Identity

Not applicable — single-player local game.

## Monitoring & Observability

**Debug autoload:** `DEBUG` → `scripts/debug/debug.gd`
- Provides `DebugOverlay` scene (`scenes/ui/debug_overlay.tscn`)
- Runtime perf HUD: `scripts/debug/runtime_perf_hud.gd`
- Runtime AI HUD: `scripts/debug/runtime_ai_hud.gd`
- Toggle via ProjectSetting `sacred_fruit/debug/runtime_verbose`

**Error Tracking:**
- None — uses `push_error()` / `push_warning()` to Godot output
- IO event trace ring buffer (capacity configurable via `GAME.io_trace_capacity`)

**Logs:**
- `Util.debug_print()` — conditional logging gated on `Util.debug_enabled`

## CI/CD & Deployment

**Hosting:** Local macOS builds only
**CI Pipeline:** None configured
**Export:** `export_presets.cfg` has macOS preset; build via Godot CLI or editor

## Webhooks & Callbacks

Not applicable.

---

*Integration audit: 2026-03-15*
