# Kit Spec Template

Use this template for each modular environment kit. Duplicate this file per kit and fill it out before producing art variants.

## 1. Kit Identity

- Kit name: `kit_<theme>_<scale_class>`
- Owner:
- Date:
- Status: `draft | blockout-validated | production`
- Target map types:
- Notes:

## 2. Scale Contract

- Grid snap: `8 qu`
- Structural increment: `16 qu`
- Unit conversion: `32 qu = 1 m`
- Floor-to-floor height:
- Standard wall height:
- Standard wall thickness:
- Door opening default: `48w x 84h qu` (change only if this kit is intentionally custom)
- Ceiling/floor slab thickness:

## 3. Pivot and Orientation Rules

- Pivot convention (all modules): `floor center | lower-front-left | ...`
- Forward axis convention:
- Up axis convention:
- Rotation policy: `90 degree increments only` (recommended)
- Mirroring policy:

## 4. Module Catalog

For each module, fill one row.

| Module ID | Category | Footprint (W x D x H qu) | Connection Edges | Pivot Type | Collision Type | Variants Planned | Notes |
|---|---|---|---|---|---|---|---|
| `kit_xxx_wall_straight_...` | wall |  |  |  |  |  |  |
| `kit_xxx_corner_inner_...` | corner |  |  |  |  |  |  |
| `kit_xxx_corner_outer_...` | corner |  |  |  |  |  |  |
| `kit_xxx_door_opening_...` | opening |  |  |  |  |  |  |
| `kit_xxx_window_opening_...` | opening |  |  |  |  |  |  |
| `kit_xxx_floor_tile_...` | floor |  |  |  |  |  |  |
| `kit_xxx_ceiling_tile_...` | ceiling |  |  |  |  |  |  |
| `kit_xxx_stair_start_...` | stair |  |  |  |  |  |  |
| `kit_xxx_stair_mid_...` | stair |  |  |  |  |  |  |
| `kit_xxx_stair_end_...` | stair |  |  |  |  |  |  |

## 5. Adjacency Rules

- Allowed adjacency matrix location:
- Hard constraints:
  - Example: `outer_corner` cannot connect directly to `inner_corner`.
  - Example: `window_opening` requires `wall_straight` neighbor on both sides.
- Soft constraints:
  - Example: avoid more than 3 identical wall variants in a row.

## 6. Material and Detail Policy

- Material palette for this kit:
- Trim sheet(s):
- Decal set(s):
- Dirt/age pass rules:
- Repetition break strategy:

## 7. Lighting Baseline for Kit Spaces

- Indoor target energy band:
- Outdoor target energy band:
- Accent light max:
- Shadow policy:
- Color temperature policy:

## 8. Gameplay and Traversal Constraints

- Minimum walkable clear width:
- Minimum head clearance:
- Cover heights used in this kit:
- Stair rise/run rules:
- Ramp slope rules:
- Collision simplification rules:

## 9. Validation Scenes

Create and keep these test scenes/maps for every kit:

- `kit_test_corridor_loop`
- `kit_test_room_2x2`
- `kit_test_stair_transition`
- `kit_test_facade_strip`

For each validation scene:
- Assembles without off-grid nudging
- No visible seams at standard camera distances
- Player collision/traversal passes
- Lighting baseline is readable

## 10. Naming and Versioning

- Naming pattern:
  - `kit_<theme>_<type>_<w>x<d>x<h>_<variant>_vNN`
- Versioning rule:
  - Never change dimensions on an existing ID.
  - If dimensions or snap points change, create a new versioned module ID.
- Deprecation policy:
  - Keep old IDs available until all maps are migrated.

## 11. Production Checklist

- [ ] Scale contract finalized
- [ ] All atomic modules modeled and snapped
- [ ] Validation scenes pass
- [ ] Variant pass complete
- [ ] Collision pass complete
- [ ] Naming/versioning audit complete
- [ ] Mapper handoff notes complete

## 12. Mapper Handoff Notes

- Recommended usage patterns:
- Anti-patterns to avoid:
- Known limitations:
- Suggested companion entities:
  - `func_door`
  - `trigger_area`
  - `light` / `light_omni` / `light_spot`
  - `env_zone`
