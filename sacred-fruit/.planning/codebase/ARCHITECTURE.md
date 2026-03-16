# Architecture

**Analysis Date:** 2026-03-15

## Pattern Overview

**Overall:** Entity-Component system driven by a TrenchBroom map pipeline. Game worlds are authored as `.map` files, imported at runtime via func_godot, which spawns entity scripts as Godot nodes. A central `GAME` autoload (GameManager) acts as global state bus and service locator.

**Key Characteristics:**
- Quake-style BSP entity system: entities are map objects that become GDScript nodes at build time
- Four autoloads provide global services: GAME, DIALOGUE, Exit, SETTINGS, DEBUG
- Signal-based communication between systems; IO manager handles targetname/targetfunc dispatch
- Build profile system (`fast-iteration` / `playtest` / `shipping`) controls runtime feature flags

## Autoloads (Global Singletons)

**GAME** (`game_manager.gd`, class `GameManager`):
- Central coordinator; owns: collectibles, player health, keys, checkpoints, zone lighting
- Facade over `IOManager` (`scripts/core/io_manager.gd`) for entity IO dispatch
- Owns `PS1ShaderManager` for retro shader global state
- Signals: `objective_text_changed`, `player_health_changed`, `player_died`, `exit_unlocked`, `ai_alerted`, `io_event_dispatched`, `keys_changed`

**DIALOGUE** (`scripts/core/dialogue_manager.gd`):
- Manages conversation state and dialogue rendering
- Depends on `scripts/core/dialogue_markdown.gd` for text parsing

**Exit** (`scripts/core/exit.gd`):
- Minimal; handles application quit

**SETTINGS** (`scripts/core/settings.gd`):
- Persists audio/video/input preferences

**DEBUG** (`scripts/debug/debug.gd`):
- Instantiates debug overlay and HUD panels
- Provides `DebugOverlay` to all debug subsystems

## Layers

**Autoload Layer:**
- Purpose: Global state, cross-scene services
- Location: `game_manager.gd`, `scripts/core/`
- Depends on: nothing above it
- Used by: all entities and scenes

**Entity Layer:**
- Purpose: Map-spawned gameplay objects (func_godot entities)
- Location: `entities/` (8 subdirectories)
- Depends on: GAME autoload, Util, IOManager
- Used by: scenes that include a FuncGodotMap

**Scripts Layer:**
- Purpose: Non-entity reusable logic (player controller, env systems, UI logic)
- Location: `scripts/core/`, `scripts/env/`, `scripts/ui/`, `scripts/debug/`, `scripts/photo/`
- Depends on: GAME autoload, Constants

**Scene Layer:**
- Purpose: Assembled game levels and UI screens
- Location: `scenes/`
- Entry point: `scenes/ui/main_menu.tscn`
- Contains: `player.tscn`, `HOME.tscn`, `grill.tscn`, `birthday.tscn`

## Entity System

**func_godot pipeline:**
1. `.map` file built by `FuncGodotMap` node at editor or runtime
2. func_godot reads classname from map entity → looks up matching `.tres` definition in FGD
3. Spawns node of type declared in `.tres` (e.g., `Node3D`, `Area3D`)
4. Calls `_func_godot_apply_properties(props: Dictionary)` on the spawned script
5. Entity registers itself via `GAME.set_targetname()` if it has a `targetname` property

**Entity categories:**
- `entities/actors/` — Actor base class + NPC + marsfrog creature
- `entities/funcs/` — Brush entities: portal, mirror, door, button, move, train, prefab instance, texture tile
- `entities/items/` — Collectibles, health, ammo, keys
- `entities/lights/` — Light wrappers (omni, spot, directional)
- `entities/logic/` — Point entities: AI controllers, env controllers, volume types, sky, timers, relays
- `entities/triggers/` — Area-based triggers: once, multiple, hurt, changelevel, exit, area
- `entities/props/` — Physics objects (physics_ball)
- `entities/generated/` — `generated_model_static.gd` (func_godot procedural static body output)

**Actor inheritance:**
- `entities/actors/actor.gd` (`class Actor extends CharacterBody3D`) — base class; implements `_func_godot_apply_properties`, `ActorFlags`, `ActorStates` enums
- `entities/actors/marsfrog/marsfrog.gd` — extends `Actor`
- `entities/actors/npc/npc_spawn_anchor.gd` — spawns `npc.tscn` instances

**Volume inheritance:**
- `entities/logic/volume.gd` (`class Volume extends Area3D`) — base for all area volumes
- Extended by: `CheckpointVolume`, `SpawnBlockerVolume`, `AIAlertVolume`, `WaterVolume`, `DamageVolume`, `MusicZoneVolume`, `QuestTriggerVolume`

## IO System (Entity Targeting)

All entity triggering flows through `scripts/core/io_manager.gd` (`class IOManager`):
- `use_targets(activator, target)` — fires all entities whose `targetname` matches `target`
- `io_fire_output(activator, output_value)` — reads IO-style output property from activator entity
- `fire_output(activator, output_key)` — reads output key property, fires target
- Trace ring buffer for debugging (capacity = `GAME.io_trace_capacity`, default 256)
- GAME exposes facade methods so entities call `GAME.use_targets(...)` directly

## Portal and Mirror Systems

**Portal:** `entities/funcs/func_portal.gd` (1687 lines)
- Viewport-based portal rendering; oblique clip plane for correct occlusion
- Budget managed by `entities/funcs/portal_runtime_manager.gd` (class `PortalRuntimeManager`)
- Budget entity: `entities/logic/env_portal_budget.gd`
- Portals register with manager; manager activates/deactivates by score

**Mirror:** `entities/funcs/func_mirror.gd` (1399 lines)
- Similar viewport-based approach to portals
- Budget managed by `entities/funcs/mirror_runtime_manager.gd` (class `MirrorRuntimeManager`)
- `addons/Mirror/` present but NOT enabled; func_mirror uses its own implementation

## Sky System

`entities/logic/sky_map_controller.gd` (`class SkyMapController`):
- Loads a TrenchBroom `.map` file as a sky backdrop at runtime via `FuncGodotMap`
- Up to 4 sky slots; switchable via `logic_relay` targetfunc calls
- `parallax_factor` controls camera tracking (0=fixed/parallax, 1=follow/no-parallax)
- Materials auto-patched to unshaded, shadows off, GI disabled after build
- Deferred `_map_settings` load to avoid circular FGD dependency

## Data Flow

**Level load:**
1. Scene loaded (e.g., `HOME.tscn`) → FuncGodotMap built → entities spawned
2. Each entity calls `_func_godot_apply_properties()` → registers with GAME via `set_targetname()`
3. `logic_auto` entities fire on `_ready()` to trigger initial state

**Player interaction:**
1. Player overlaps trigger area / presses use key
2. Entity fires `GAME.use_targets()` or `GAME.fire_output()`
3. IOManager resolves targetname → finds node in group → calls `use()` or targetfunc method
4. Receiving entity executes its effect; may chain further outputs

**Checkpoint / persistence:**
1. Player enters `checkpoint_volume` → GAME records checkpoint in `_runtime_checkpoints`
2. On death/restart, `_load_runtime_state()` restores state from `user://runtime_state.cfg`

## Error Handling

**Strategy:** Defensive — null checks with graceful fallback; `push_error()`/`push_warning()` for non-fatal failures; fatal errors deferred to Godot crash.

**Patterns:**
- `if node == null or not is_instance_valid(node): return` — universal guard
- `_get_node_prop(node, key, default_value)` — safe property access with FGD dict fallback
- Runtime `load()` calls checked: `if loaded == null: push_error(...)` before use
- IO dispatch skips null/invalid nodes silently

## Cross-Cutting Concerns

**Logging:** `Util.debug_print(msg)` — only fires when `Util.debug_enabled` is true; gated by `DEBUG` autoload and project setting `sacred_fruit/debug/runtime_verbose`
**Validation:** Input checked with `Util.to_bool()`, `Util.editor_hint()` guards in all `_ready()` and `_process()` methods
**Authentication:** Not applicable
**Build profile:** `GAME.is_shipping()`, `GAME.is_playtest()`, `GAME.is_fast_iteration()` — used to gate debug tools and performance checks

---

*Architecture analysis: 2026-03-15*
