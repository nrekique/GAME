# Codebase Structure

**Analysis Date:** 2026-03-15

## Directory Layout

```
sacred-fruit/
├── addons/                  # Vendored Godot plugins
│   ├── func_godot/          # Quake .map import pipeline (active)
│   ├── portals/             # Portal rendering addon (active)
│   ├── dolly-camera-controller/ # Cinematic camera dolly (active)
│   ├── Mirror/              # Mirror addon (present, NOT enabled)
│   └── CardGameSkeleton/    # Card game framework (present, NOT enabled)
├── entities/                # func_godot entity scripts + FGD definitions
│   ├── actors/              # CharacterBody3D actors (Actor base, NPC, marsfrog)
│   ├── funcs/               # Brush entities (portal, mirror, door, button, move, train)
│   ├── items/               # Pickups (collectible, health, ammo, key)
│   ├── lights/              # Light entity wrappers
│   ├── logic/               # Point entities (AI, env, volumes, sky, timers)
│   ├── props/               # Physics props (physics_ball)
│   ├── triggers/            # Area triggers (once, multiple, hurt, changelevel, exit)
│   └── generated/           # Procedural static body output from func_godot
├── scenes/                  # Assembled scenes
│   ├── ui/                  # UI scenes (main_menu, hud, options, debug overlays)
│   ├── env/                 # Environment resources
│   ├── vfx/                 # VFX one-shot scenes (collect_burst, exit_burst)
│   ├── dev/                 # Dev/test scenes (ui_health_check)
│   └── photo/               # Photo mode UI components
├── scripts/                 # Non-entity GDScript logic
│   ├── core/                # Player controller, IO manager, dialogue, settings, util
│   ├── env/                 # PS1 shader manager, sandstorm, sky loader, VFX
│   ├── debug/               # Debug menu, map builder, perf HUD, AI HUD, runtime map play
│   ├── ui/                  # Dialogue UI, HUD, menus
│   └── photo/               # Photo mode (~5700 lines)
├── shaders/                 # GLSL shaders (ps1_geometry, sandstorm, photo mode postfx, texture tile)
├── tb/                      # TrenchBroom-facing assets
│   ├── fgd/                 # FuncGodot FGD resources (entity definitions)
│   │   ├── base/            # Shared FGD base classes (actor_base, target_base, etc.)
│   │   ├── point/           # Point entity FGD definitions by category
│   │   │   ├── actors/      # npc, npc_enemy_patrol
│   │   │   ├── items/       # collectible, health, ammo, key
│   │   │   ├── lights/      # light_omni, light_spot, light_directional
│   │   │   ├── logic/       # 27 logic/env/AI entities
│   │   │   └── props/       # physics_ball
│   │   ├── solid/           # Solid (brush) entity FGD definitions
│   │   │   ├── funcs/       # func_portal, func_mirror, func_door, func_move, etc.
│   │   │   ├── triggers/    # trigger_*, volume_* entities
│   │   │   └── volumes/     # (same directory as triggers)
│   │   └── tags/            # TrenchBroom face/brush tags
│   ├── maps/                # .map source files (level geometry)
│   ├── textures/            # Texture files used by maps
│   ├── models/              # Models referenced in maps
│   └── icons/               # TrenchBroom entity icons
├── tests/                   # In-engine test scripts (run as scenes)
├── data/                    # Game data files
├── themes/                  # Godot theme resources
├── tools/                   # Build/utility tools
├── docs/                    # mkdocs documentation source
├── CardImages/              # Card game asset images (stale, unused)
├── Cards/                   # Card data (stale, unused)
├── game_manager.gd          # GAME autoload (root of project)
└── project.godot            # Engine configuration
```

## Key File Locations

**Entry Points:**
- `scenes/ui/main_menu.tscn` — main scene (set in project.godot)
- `game_manager.gd` — GAME autoload; loaded before any scene

**Autoloads:**
- `game_manager.gd` — GAME
- `scripts/core/dialogue_manager.gd` — DIALOGUE
- `scripts/core/exit.gd` — Exit
- `scripts/core/settings.gd` — SETTINGS
- `scripts/debug/debug.gd` — DEBUG

**Core Logic:**
- `scripts/core/player.gd` — player controller (CharacterBody3D; not an autoload, lives in `scenes/player.tscn`)
- `scripts/core/io_manager.gd` — entity IO dispatch (instantiated by GAME, not autoload)
- `scripts/core/util.gd` — shared utilities; imported as `const Util` by nearly every script
- `scripts/core/constants.gd` — canvas layers, z-indices, UI constants

**Entity Base Classes:**
- `entities/actors/actor.gd` — Actor base (CharacterBody3D)
- `entities/logic/volume.gd` — Volume base (Area3D)
- `entities/funcs/func_move.gd` — FuncMove base (AnimatableBody3D); extended by func_door

**FGD Pipeline:**
- `tb/fgd/sf_fgd.tres` — top-level FGD export target
- `tb/fgd/map_settings.tres` — used by FuncGodotMap nodes in scenes
- `tb/fgd/game_cfg.tres` — TrenchBroom game config

**Testing:**
- `tests/` — standalone scene-based tests; run by opening scene in Godot

## Naming Conventions

**Files:**
- Entity scripts: `snake_case.gd` matching classname in FGD (e.g., `sky_map_controller.gd` → classname `sky_map_controller`)
- FGD .tres resources: mirror the script name exactly
- Scenes: `snake_case.tscn`
- Class names in GDScript: `PascalCase` (e.g., `class_name SkyMapController`)

**Directories:**
- Entity subdirs match func_godot entity category: `actors/`, `funcs/`, `items/`, `lights/`, `logic/`, `props/`, `triggers/`
- FGD subdirs mirror entity subdirs under `tb/fgd/point/` and `tb/fgd/solid/`

## Where to Add New Code

**New point entity (map-spawnable):**
1. Script: `entities/logic/<entity_name>.gd` (or appropriate subdir)
2. FGD resource: `tb/fgd/point/logic/<entity_name>.tres` (FuncGodotFGDPointClass)
3. Register in `tb/fgd/fgd_point.tres` (array of resources)
4. Add `class_name` and `_func_godot_apply_properties()` method
5. Register `targetname` with `GAME.set_targetname(self, targetname)` if targetable

**New solid/brush entity:**
1. Script: `entities/funcs/<entity_name>.gd`
2. FGD resource: `tb/fgd/solid/funcs/<entity_name>.tres` (FuncGodotFGDSolidClass)
3. Register in `tb/fgd/fgd_solid.tres`

**New scene:**
1. Place in `scenes/<category>/`
2. Wire autoloads via `GAME`, `DIALOGUE`, etc. — do not create new autoloads

**New utility:**
1. Add to `scripts/core/util.gd` for broadly shared helpers
2. Add to `scripts/core/constants.gd` for named constants (layers, z-indices, physics values)

**New shader:**
1. `shaders/<name>.gdshader`
2. Create a `.tres` material that references it

## Special Directories

**`addons/`:**
- Purpose: Vendored plugins
- Generated: No (manually added)
- Committed: Yes; all addons are in source control

**`tb/`:**
- Purpose: TrenchBroom authoring assets (maps, textures, FGD)
- Generated: Partially — `.map` files are authored; FGD resources are manually maintained
- Committed: Yes

**`.godot/`:**
- Purpose: Godot editor cache (import data, uid cache)
- Generated: Yes — by Godot editor
- Committed: No (in .gitignore)

**`entities/generated/`:**
- Purpose: Generated static body script from func_godot
- Generated: Partially (output of map build)
- Committed: Yes (single script `generated_model_static.gd`)

---

*Structure analysis: 2026-03-15*
