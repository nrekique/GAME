# Texture Production Checklist

**Design Goal:** Underground tunnel traversal + earth scraper hub aesthetic  
**Source:** Live usage analysis from `tb/maps` (autosaves excluded)  
**Total Textures:** 75 world textures across 60,000+ brush faces

This checklist prioritizes textures by actual face count. Design all from scratch to replace internet sourced materials.

Completed textures move to [Texture Atlas](TEXTURE_ATLAS.md).

---

## 🔴 P0: Critical Foundation (5,000+ faces)
*Design these first - they define your visual identity*

| Status | Texture | Faces | Maps Used | Size | Notes |
|---|---|---:|---|---|---|
| [ ] | `world/grass_floor1` | 9,367 | bigbrother, home, outside, theater, venue | 512x512 | Primary floor material - indoor ground surface |
| [ ] | `world/wizwood1_5` | 6,774 | home | 512x512 | Dominant wood variant - warm brown tone |
| [ ] | `world/concreteWhite` | 5,936 | **Rascasuelos x2**, birthday, grill, outside, theater | 512x512 | **MAIN HUB MATERIAL** - clean concrete for earth scraper |
| [ ] | `world/concreteBrown` | 5,228 | grill, home, outside, venue | 512x512 | Weathered concrete - outdoor/aged surfaces |

---

## 🟠 P1: Underground Core (1,000-4,999 faces)
*Essential for tunnel/underground atmosphere*

| Status | Texture | Faces | Maps Used | Size | Notes |
|---|---|---:|---|---|---|
| [ ] | `world/curtainsBlack` | 3,846 | bigbrother, birthday, theater | 512x512 | Heavy fabric - theater/concealment |
| [ ] | `world/wizwood1_8` | 2,397 | birthday, grill, outside, theater, venue | 512x512 | Secondary wood - darker/richer tone |
| [ ] | `world/marble` | 1,898 | grill, laCebia, outside | 512x512 | Polished stone - upscale areas |
| [ ] | `world/redPlaster` | 1,335 | bigbrother, home | 512x512 | Colored plaster - residential warmth |
| [ ] | `world/groundBrown2` | 1,167 | grill, home, outside | 512x512 | Dirt/earth - exterior ground |
| [ ] | `world/groundRed2` | 1,158 | home, outside | 512x512 | Red earth variant - clay/mineral rich |
| [ ] | `world/indRed2` | 1,092 | grill, outside | 512x512 | Industrial red - machinery/equipment |
| [ ] | `world/cutains` | 1,086 | theater | 512x512 | Theater curtain variant (check if typo vs curtainsBlack) |

---

## 🟡 P2: Infrastructure (500-999 faces)
*Secondary structural materials*

| Status | Texture | Faces | Maps Used | Size | Notes |
|---|---|---:|---|---|---|
| [ ] | `world/concrete1` | 885 | birthday, grill, outside | 512x512 | Concrete variant - rougher texture |
| [ ] | `world/grass` | 883 | grill, outside | 512x512 | Outdoor grass - different from floor variant |
| [ ] | `world/concrete` | 758 | bigbrother, birthday, home, laCebia, outside, reno, venue | 512x512 | Base concrete - neutral gray |
| [ ] | `world/dark1` | 607 | birthday, grill, outside, theater | 512x512 | Dark absorptive surface - shadows/depth |
| [ ] | `world/stAsphaltBrn` | 529 | grill, home, outside | 512x512 | Brown asphalt - roads/paths |
| [ ] | `world/sand` | 525 | grill, outside | 512x512 | Sandy ground - loose terrain |
| [ ] | `world/m5_8` | 522 | grill, outside | 512x512 | Metal variant - industrial |

---

## 🟢 P3: Tunnel Kit (400-499 faces)
*Specific tunnel aesthetics*

| Status | Texture | Faces | Maps Used | Size | Notes |
|---|---|---:|---|---|---|
| [ ] | `world/tunnleTrim` | 443 | birthday | 512x512 | **Tunnel edge/frame** - normalize to `tunnel_trim` |
| [ ] | `world/wizwood1_3` | 435 | bigbrother, home, outside, reno, theater | 512x512 | Third wood variant - lighter tone |
| [ ] | `world/plaster` | 384 | birthday | 512x512 | **Tunnel wall base** - neutral plaster |

---

## 🔵 P4: Atmospheric Details (300-399 faces)

| Status | Texture | Faces | Maps Used | Size | Notes |
|---|---|---:|---|---|---|
| [ ] | `world/sky1` | 372 | home, outside, venue | 1024x1024 | Sky material - consider procedural replacement |
| [ ] | `world/stAsphaltBlk` | 324 | home, outside, theater | 512x512 | Black asphalt - fresh pavement |
| [ ] | `world/skystar1` | 314 | home, outside, theater, venue | 1024x1024 | Starfield sky - night atmosphere |
| [ ] | `world/city1_4` | 312 | grill, outside | 512x512 | Urban building texture |

---

## 🟣 P5: Architectural Accents (100-299 faces)

| Status | Texture | Faces | Maps Used | Size | Notes |
|---|---|---:|---|---|---|
| [ ] | `world/cop1_6` | 228 | grill, outside | 512x512 | Architectural detail variant |
| [ ] | `world/roofTealRough` | 224 | outside | 512x512 | Teal roof - weathered finish |
| [ ] | `world/light1` | 193 | home, outside, theater | 512x512 | **Emissive** - primary light source |
| [ ] | `world/roofTealRound` | 180 | outside | 512x512 | Teal roof - smooth variant |
| [ ] | `world/smpfloor04` | 172 | outside | 512x512 | Sample floor texture |
| [ ] | `world/concreteWhite2` | 164 | birthday, grill, outside | 512x512 | White concrete variation |
| [ ] | `world/red5` | 162 | grill, outside | 512x512 | Bright red accent |
| [ ] | `world/light12` | 147 | grill, outside, theater | 512x512 | **Emissive** - secondary lighting |
| [ ] | `world/city4_7` | 144 | grill, outside | 512x512 | Urban texture variant |
| [ ] | `world/wood1_1` | 139 | grill, outside, theater | 512x512 | Alternative wood family |
| [ ] | `world/wood01` | 124 | home, outside | 512x512 | Wood variant |
| [ ] | `world/roofTeal` | 120 | grill, outside | 512x512 | Base teal roof material |
| [ ] | `world/city4_6` | 114 | grill, outside | 512x512 | Urban texture variant |

---

## ⚪ P6: Specialized/Low Use (<100 faces)

| Status | Texture | Faces | Maps Used | Size | Notes |
|---|---|---:|---|---|---|
| [ ] | `world/foam` | 96 | home | 512x512 | Water edge foam effect |
| [ ] | `world/wood03` | 90 | home, outside | 512x512 | Wood variant |
| [ ] | `world/Assunto` | 74 | theater | 1024x1024 | Custom art/poster |
| [ ] | `world/red1` | 72 | grill, outside | 512x512 | Red variant |
| [ ] | `world/metal5_3` | 72 | grill, outside | 512x512 | Metal variant |
| [ ] | `world/light7` | 72 | grill, outside | 512x512 | **Emissive** - tertiary lighting |
| [ ] | `world/stBlkHighway` | 67 | home, outside | 512x512 | Highway stripe markings |
| [ ] | `world/orange5` | 64 | grill, outside | 512x512 | Orange accent |
| [ ] | `world/green1` | 64 | grill, outside | 512x512 | Green accent |
| [ ] | `world/light6` | 60 | grill, outside | 512x512 | **Emissive** - accent lighting |
| [ ] | `world/car3` | 52 | home, outside, venue | 512x512 | Car texture - consider 3D model replacement |
| [ ] | `world/brass` | 45 | home | 512x512 | Brass metal - decorative |
| [ ] | `world/cutout1` | 40 | theater | 1024x1024 | **Alpha cutout** - 2D sprite card |
| [ ] | `world/indRed` | 36 | outside | 512x512 | Industrial red variant |
| [ ] | `world/bricksRed` | 28 | outside | 512x512 | Red brick |
| [ ] | `world/metalwiz` | 24 | home, outside | 512x512 | Wizard metal texture |
| [ ] | `world/indGrey` | 24 | home | 512x512 | Industrial gray |
| [ ] | `world/bricksRed2` | 24 | grill, home, outside | 512x512 | Red brick variant |
| [ ] | `world/windowsYellow` | 18 | fgd test | 512x512 | Yellow window frames |
| [ ] | `world/groundRed` | 18 | home, outside | 512x512 | Red ground variant |
| [ ] | `world/coop` | 17 | theater | 1024x1024 | **Alpha cutout** - poster/sign |
| [ ] | `world/smpconc01` | 12 | outside | 512x512 | Sample concrete |
| [ ] | `world/kh_art1` | 12 | outside | 1024x1024 | Custom art piece |
| [ ] | `world/streetbrown2` | 8 | home, outside | 512x512 | Brown street variant |
| [ ] | `world/cearth1_6` | 8 | birthday | 512x512 | Earth/dirt variant |
| [ ] | `world/groundBrown3` | 7 | home | 512x512 | Brown ground variant |
| [ ] | `world/plasters` | 6 | home | 512x512 | Plaster variant |
| [ ] | `world/cutout4` | 6 | theater | 1024x1024 | **Alpha cutout** |
| [ ] | `world/cutout11` | 6 | theater | 1024x1024 | **Alpha cutout** |
| [ ] | `world/Tilemos3` | 6 | outside | 1024x1024 | Custom art/texture |
| [ ] | `world/sky` | 5 | theater | 1024x1024 | Sky base |
| [ ] | `world/brick1a` | 3 | bigbrother | 512x512 | Brick variant |
| [ ] | `world/wizmet1_8` | 2 | grill, outside | 512x512 | Wizard metal variant |
| [ ] | `world/cutout5` | 1 | theater | 1024x1024 | **Alpha cutout** |
| [ ] | `world/cutout2` | 1 | theater | 1024x1024 | **Alpha cutout** |
| [ ] | `world/cutout12` | 1 | theater | 1024x1024 | **Alpha cutout** |

---

## 🛠️ Special/Tool Textures

| Status | Texture | Faces | Maps | Size | Notes |
|---|---|---|---|---|
| [ ] | `special/origin` | ~36 | multiple | 256x256 | Editor origin marker - keep simple |

---

## 📊 Production Strategy

### Phase 1: Hub Foundation (Week 1)
Design the 4 P0 textures - these appear 27,305 times. Focus on `concreteWhite` for Rascasuelos hub.

### Phase 2: Underground Atmosphere (Week 2-3)
Complete P1 (8 textures) - establishes tunnel/underground mood.

### Phase 3: Structure Complete (Week 4-5)
P2 Infrastructure + P3 Tunnel Kit (10 textures total) - makes spaces navigable.

### Phase 4: Polish (Week 6+)
P4-P6 as needed for specific scenes. Many low-use textures can share designs with variations.

**Consolidation Opportunities:**
- Wood family: 6 textures → design 2-3 base materials with color variants
- Concrete family: 5 textures → 2 designs with weathering variants
- Ground family: 6 textures → 3 designs with color shifts
- Cutouts: 7 textures → reusable alpha card system

**Total Unique Designs Needed:** ~40-45 after consolidation (vs 75 individual textures)
