# Technology Stack

**Analysis Date:** 2026-03-15

## Languages

**Primary:**
- GDScript 2.0 — all gameplay logic, entities, tooling
- GLSL (gdshader) — custom shaders in `shaders/`

**Secondary:**
- Shell (sh) — build utilities in `scripts/`

## Runtime

**Environment:**
- Godot Engine 4.6 (Forward Plus renderer)

**Package Manager:**
- None — Godot project with vendored addons

## Frameworks / Engine

**Core:**
- Godot 4.6 — game engine, scene system, physics, rendering

**Build/Dev:**
- func_godot 2025.1 — Quake .map file import and entity pipeline (`addons/func_godot/`)
- TrenchBroom — level editor (external, not vendored); configured via `tb/fgd/game_cfg.tres`

## Addons (vendored in `addons/`)

**Active (enabled in project.godot):**
- `func_godot` v2025.1 — map pipeline; point/solid entity spawning from .map files
- `portals` — custom portal rendering addon (local, not func_godot's portal support)
- `dolly-camera-controller` — cinematic camera dolly for cutscenes/photo mode

**Present but NOT enabled:**
- `Mirror` — mirror reflection addon (present on disk, not in `editor_plugins`)
- `CardGameSkeleton` — card game framework (present on disk, not enabled; stale/prototype)

## Configuration

**Environment:**
- No `.env` files; all runtime config via `ProjectSettings`
- Build profiles set via `scripts/build_profile.sh` → writes `build_profile=` in `project.godot`
- Three profiles: `fast-iteration` (default), `playtest`, `shipping`
- Active profile readable at runtime: `ProjectSettings.get_setting("application/build_profile")`

**Build:**
- `project.godot` — engine config; currently set to `build_profile="fast-iteration"`
- `export_presets.cfg` — macOS export target configured

## Platform Requirements

**Development:**
- Godot 4.6+
- TrenchBroom (external) for map authoring

**Production:**
- macOS export preset present; other platforms not configured

---

*Stack analysis: 2026-03-15*
