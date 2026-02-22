# Build Profiles

This section outlines the intended build profiles for the project.  Profiles are
not code‑enforced but you can implement them using project settings or export
scripts in Godot.

## Profiles

| Name | Purpose | Typical settings |
|------|---------|------------------|
| **fast-iteration** | Short startup time during active development. |
| | - Minimal preprocessing | - Disable heavy shaders
| | | - Low texture quality
| **playtest** | Realistic runtime for testers. |
| | - Moderate quality | - PS1 shader enabled
| | | - Standard physics settings
| **shipping** | Production build. |
| | - Full quality | - All optimizations enabled
| | | - Stripped debug logs, no editor tools

## Implementation ideas

- Use export presets to toggle settings by name.
- Add a pre‑build script (`scripts/build_profile.sh`) that patches `project.godot`.
- Conditionals in code can check `Engine.has_singleton("GAME") && GAME.profile == "shipping"`.

The repository includes a helper script that will modify `project.godot` for you:

```sh
# set fast iteration (default)
./scripts/build_profile.sh fast-iteration

# switch to playtest build
./scripts/build_profile.sh playtest

# prepare a shipping build
./scripts/build_profile.sh shipping
```

This changes or adds a `build_profile="..."` entry under the
`[application]` section; Godot will reimport the project automatically.  At
runtime the current profile is available through `ProjectSettings`, and the
`GameManager` singleton caches the value in `build_profile` with helpers such
as `is_shipping()`.

Profiles can also be toggled manually via export presets or a more complex
pre‑build patch script, but the above tool is handy during local development.
