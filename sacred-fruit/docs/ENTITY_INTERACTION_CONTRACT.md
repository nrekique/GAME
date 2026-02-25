# Entity Interaction Contract

This page defines the runtime contract for entities that players can target and use.

## Player Interaction API

Interaction is driven by [`res://scripts/core/player.gd`](../scripts/core/player.gd):

- A target is considered interactable if it exposes `interact(...)` or `use(...)`.
- If present, `can_interact(player)` is checked before interaction.
- On interact input, player calls `interact(player)` first when available.

Crosshair behavior:

- Idle target: `crosshair_idle_color`
- Valid target (`can_interact == true`): `crosshair_target_color` (green by default)
- Blocked target (`can_interact == false`): `crosshair_blocked_color` (red by default)

## Required Methods (by convention)

For custom entities, use this shape:

```gdscript
func can_interact(activator: Node = null) -> bool:
	return true

func interact(activator: Node = null) -> bool:
	use()
	return true
```

Rules:

- `can_interact` should be side-effect free.
- `interact` should return `true` only when action was accepted.
- If the entity can be triggered remotely, also expose `use()`.

## Key + Door Contract

### Key Entity

`item_key` (`res://entities/items/item_key.gd`) uses:

- `key_id` (String): key identifier (normalized to lowercase in runtime manager)
- `auto_free` (bool): removes key entity after pickup
- `targetname` (String): optional I/O registration group

On player overlap, it calls `GAME.give_key(key_id)`.

### Door Entity

`func_door` (`res://entities/funcs/func_door.gd`) uses:

- `required_key` (String): empty means no key needed
- `consume_required_key` (bool): consume key on first successful open
- `wait`, `auto_close`, `lock_open`, inherited movement keys from `func_move`

Door interaction logic:

1. `can_interact` returns `true` if:
   - door is already open, or
   - `required_key` is empty, or
   - `GAME.has_key(required_key)` is true
2. `interact` returns `false` when `can_interact` fails.
3. If closed + `consume_required_key == true`, it requires `GAME.consume_key(required_key)` before opening.

## Inventory Contract (`GAME`)

`res://game_manager.gd` provides:

- `has_key(key_id: String) -> bool`
- `give_key(key_id: String) -> bool`
- `consume_key(key_id: String) -> bool`
- `get_keys() -> PackedStringArray`
- `signal keys_changed(keys: PackedStringArray)`

Normalization rule:

- Key ids are trimmed + lowercased before storage and checks.

## Authoring Checklist

1. `item_key.key_id` exactly matches `func_door.required_key` (case-insensitive).
2. Door is interactable from player reach/line of sight.
3. If `consume_required_key` is on, verify you expect one-time use.
4. If door should be remote-triggered, set `targetname` and wire I/O.

