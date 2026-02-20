# Entity Icon Sync

This folder is synced from:

- `/_src/entity/Brush/*.svg`
- `/_src/entity/Point/*.svg`

## Brush Icons

Located in `tb/icons/entities/brush/`:

- `__tb_empty.svg`
- `clip.svg`
- `glass.svg`
- `mirror.svg`
- `portal.svg`
- `skip.svg`
- `sky.svg`
- `trigger.svg`
- `water.svg`

Current runtime brush helper textures already exist as PNG/TRES in:

- `tb/textures/special/`

## Point Icons

Located in `tb/icons/entities/point/`:

- `omni.svg`
- `spot.svg`
- `sprites.svg`

## Notes

- FuncGodot FGD currently uses `meta_properties` (`color`, `size`, optional `model`) for TrenchBroom entity visuals.
- These SVGs are now part of the active project and can be wired to specific entity definitions in a follow-up pass.
