# Map Building Guidelines

This document defines baseline mapper standards for Sacred Fruit so new maps feel consistent in scale, traversal, and lighting.

## 1. Canonical Units and Grid

- Use `1 grid unit = 1 map unit (qu)`.
- Runtime conversion is `32 qu = 1 meter` (`inverse_scale_factor = 32.0`).
- Author on an `8 qu` grid for most work.
- Snap structural brushes to `16 qu` multiples.
- Keep hero alignment points (doors, stairs, cover edges, curb lines) on `8 qu` increments.

Quick reference:
- `32 qu = 1.0 m`
- `16 qu = 0.5 m`
- `8 qu = 0.25 m`
- `4 qu = 0.125 m`

## 2. Gameplay Clearances

### 2.1 Doors

Default door standard (matches current key door usage in `tb/maps/fgd test.map`):
- Clear width: `48 qu` (1.5 m)
- Clear height: `84 qu` (2.625 m)
- Door thickness: `4-8 qu`
- Frame thickness: `8-16 qu`

Large door/gate standard:
- Width: `96-160 qu`
- Height: `96-160 qu`

Door movement defaults:
- Swing/slide speed: `120 qu/s` (project default)
- Auto-close wait: `3.0 s` unless gameplay needs faster reset

### 2.2 Interior Walls and Ceilings

- Standard interior wall height: `96 qu` (3.0 m)
- Comfortable interior height: `112-120 qu` (3.5-3.75 m)
- Hero/public spaces: `128-192 qu` (4.0-6.0 m)
- Wall thickness:
  - Interior partition: `8-12 qu`
  - Exterior/structural: `12-24 qu`

### 2.3 Stairs, Steps, and Ramps

- Single step rise: `4-8 qu`
- Preferred stair run per step: `8-12 qu`
- Keep repeated step rhythm consistent within one building kit.
- Ramp slope target: `1:8` to `1:12` for readable traversal.

## 3. Streets and Sidewalks

Use these as map kit baselines:

- Single traffic lane: `96 qu` (3.0 m)
- Two-lane local road (no parking): `192 qu` (6.0 m)
- Collector/main road: `256-320 qu` (8.0-10.0 m)
- Sidewalk clear path (minimum): `32 qu` (1.0 m)
- Sidewalk standard: `48 qu` (1.5 m)
- Sidewalk generous/commercial: `64 qu` (2.0 m)
- Curb reveal height: `4 qu` (0.125 m)
- Buffer strip/tree pit band: `16-32 qu`

Road composition template:
- Building face -> `48 qu` sidewalk -> `4 qu` curb -> `192+ qu` carriageway -> `4 qu` curb -> `48 qu` sidewalk -> building face.

## 4. Lighting Targets

Sacred Fruit currently uses map-authored light energies commonly around `10`, `16`, and `25` in test content. Use that as the practical baseline.

### 4.1 Indoor

- Ambient fill omni: `8-14`
- Primary room key lights: `14-22`
- Accent/task lights: `20-30`
- Avoid fully flat rooms. Use at least 2 light roles:
  - broad fill
  - directional/accent

### 4.2 Outdoor

- Daytime support lights (if needed): `6-12`
- Night street/intersection lights: `16-30`
- Landmark/emphasis lights: `24-40` (sparingly)

### 4.3 Consistency Rules

- Keep color temperature coherent per zone (warm interior vs cooler exterior unless intentionally mixed).
- For one district/biome, keep most lights in a narrow band and reserve high energy for landmarks.
- Use shadows selectively. Enable only where silhouette readability matters.

## 5. Prefab and Kit Rules (Bethesda-style modular discipline)

Define and enforce kit contracts before building large maps.

### 5.1 Module Contracts

Every prefab/kit piece should declare:
- Footprint in qu (`W x D x H`)
- Connection edge type (wall, doorway, corner, stair start/end)
- Door opening standard (`48 x 84` unless explicitly tagged otherwise)
- Floor-to-floor height class (`96`, `120`, `160`, etc.)
- Pivot/origin convention (recommended: floor center or lower-front-left)

### 5.2 Naming

Use deterministic names:
- `kit_<theme>_<type>_<w>x<d>x<h>_<variant>`
- Example: `kit_city_corridor_96x192x120_a`

### 5.3 Variants and Reuse

- Build 1 clean base piece first.
- Add 2-4 visual variants without changing connection dimensions.
- Do not change snap points across variants.

### 5.4 Validation Checklist

Before a prefab is approved:
- Snaps on `8 qu` grid with no off-grid drift.
- Door openings match standard or are clearly tagged as custom.
- Collision and traversal clearances pass.
- Lighting budget is in-range for zone type.
- Works with neighboring kit pieces without manual vertex edits.

## 6. Mapper Checklist

Before submitting a map revision:
- Doorways use standard sizes unless intentional setpiece.
- Interior heights stay within the chosen zone class.
- Roads and sidewalks follow lane/walkway width standards.
- Light energies stay in zone bands (indoor vs outdoor).
- Key gameplay routes preserve readability and clearance.
- New prefabs follow the naming and connection contract.

## 7. Notes on External Baselines

This guide aligns Sacred Fruit with classic Quake/Valve readability principles:
- predictable player clearances
- modular grid discipline
- repeatable architectural metrics

Use this doc as the project source of truth even when references differ by engine unit system.

## 8. Reference Material

- Valve Developer Community: `Dimensions (Half-Life 2 and Counter-Strike: Source)`
  - https://developer.valvesoftware.com/wiki/Dimensions_(Half-Life_2_and_Counter-Strike:_Source)
- QuakeC definitions (historical baseline conventions for classic Quake entity/player setup):
  - https://www.gamers.org/dEngine/quake/QC/defs.qc.html
- Bethesda modular environment talk (kit-based worldbuilding discipline):
  - https://www.youtube.com/watch?v=QBAM27YbKZg
