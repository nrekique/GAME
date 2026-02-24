# Gameplay Volumes

The `entities/logic/volume.gd` class provides a generic `Area3D` that tracks
when bodies enter or exit and delegates logic to subclasses.  Mappers can drop
one of the ready‑made volume types into their map or write custom variants.

## Provided subclasses

* `DamageVolume` – calls `apply_damage(amount)` on any body that enters.
* `CheckpointVolume` – registers a respawn checkpoint on entry. `GAME.respawn_player`
  now restores to the active checkpoint before falling back to `info_player_start`.
* `SpawnBlockerVolume` – placeholder that can be queried by the spawning system
  to prevent actors from appearing inside the area.
* `MusicZoneVolume` – tells `GAME` to switch music to the tagged zone on entry.
* `AIAlertVolume` – notifies the AI system of an alert at the entrant's position.
* `QuestTriggerVolume` – hook for quest scripting, emits no behaviour by default.

## Authoring tips

* All volumes export `enabled`, `amount`, and `tag` variables. They also support
  `save_id`, `starts_enabled`, and `one_shot` for persistence-friendly behavior.
  Further
  subclasses may add additional exports as needed.
* Use `Volume` directly for custom logic by overriding `_process_body(body, entered)`.
* In editor mode (`@tool`) volumes continue to exist but won’t run their
  runtime logic (thanks to `Util.editor_hint()` early return).

Volumes are lightweight—just drop one in a scene, configure the exported
properties and connect to signals (`body_entered` / `body_exited`) if you need
to react to overlaps directly.  The base class emits these events automatically.

Spawn blocker volumes automatically join the `spawn_blocker` group; `GAME`
provides a helper `is_spawn_blocked(point)` that returns true when the point
falls inside any active blocker.
