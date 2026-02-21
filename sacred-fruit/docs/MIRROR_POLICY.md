# Mirror Policy

This project uses `func_mirror` as the canonical mirror implementation.

## Runtime Authority

- Use `res://entities/funcs/func_mirror.gd` for in-map mirrors.
- Author mirrors in TrenchBroom with `func_mirror` (FGD solid entity).

## Addon Mirror

- `res://addons/Mirror/**` is treated as optional/editor reference only.
- Do not rely on `addons/Mirror/Mirror/Mirror.gd` for shipped gameplay scenes.

## Export Rule

- Export presets exclude `addons/Mirror/**` so release builds only ship the `func_mirror` path.
