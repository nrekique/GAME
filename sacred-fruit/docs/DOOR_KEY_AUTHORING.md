# Door + Key Authoring

Practical patterns for making doors and keys in TrenchBroom that work at runtime.

## Quick Rules

1. Set `item_key.key_id` to the same value as `func_door.required_key`.
2. Matching is case-insensitive at runtime, but use lowercase for consistency.
3. If `required_key` is empty, the door is always interactable.
4. If player does not satisfy `can_interact`, crosshair dot is blocked color (red by default).
5. If player satisfies `can_interact`, crosshair dot is target color (green by default).

## Current Door Defaults

From FGD/runtime (`func_door`):

- `speed`: `120.0`
- `wait`: `3.0`
- `auto_close`: `true`
- `lock_open`: `false`
- `required_key`: `""`
- `consume_required_key`: `false`

Speed behavior:

- Translating doors: Quake units per second.
- Rotation-only doors: degrees per second.

## Pattern 1: Unlocked Sliding Door

`func_door` keyvalues:

- `move_pos`: `0 64 0`
- `speed`: `120`
- `required_key`: ``
- `auto_close`: `true`
- `wait`: `3`

Result:

- Crosshair is green when aimed at door.
- Press interact to open; it auto-closes after 3s.

## Pattern 2: Locked Door + Reusable Key

`item_key` keyvalues:

- `key_id`: `blue`
- `auto_free`: `true`

`func_door` keyvalues:

- `required_key`: `blue`
- `consume_required_key`: `false`
- `move_pos`: `0 0 96`
- `speed`: `120`

Result:

- Before pickup: crosshair turns red on this door.
- After pickup: crosshair turns green and door opens.
- Key remains in inventory for other `blue` doors.

## Pattern 3: Single-Use Security Door

`item_key`:

- `key_id`: `vault`

`func_door`:

- `required_key`: `vault`
- `consume_required_key`: `true`
- `lock_open`: `true`

Result:

- First open consumes key.
- Door remains open and cannot be closed by use/toggle.

## Pattern 4: Swinging Door

Use rotation instead of translation.

`func_door`:

- `move_pos`: `0 0 0`
- `move_rot`: `0 90 0` (or `0 -90 0`)
- `speed`: `180`
- `auto_close`: `true`
- `wait`: `2`

Tips:

- Ensure brush pivot/origin is at hinge side.
- Positive/negative Y rotation controls swing direction.

## Debug Checklist

If door stays locked after key pickup:

1. Confirm `item_key.key_id` exactly matches `func_door.required_key`.
2. Confirm player actually overlaps key and key disappears (or logs inventory change).
3. Confirm door is the entity you are targeting (not neighboring brush/entity).
4. If using `consume_required_key`, make sure it was not consumed by another door.
5. Check map lint and runtime logs for unrelated script load/parse errors.

