# Phase 1 Quick Reference

## Current vs Target Specs

| Texture | Current | Target | Priority | Notes |
|---------|---------|--------|----------|-------|
| **concreteWhite** | 512x512, internet source | 512x512, custom design | ⭐⭐⭐ HIGHEST | Your hub signature - design FIRST |
| **grass_floor1** | 128x128, internet source | 128-256x256, custom | ⭐⭐⭐ HIGH | Most used (9,367 faces!) |
| **wizwood1_5** | 64x64, internet source | 64x64, custom | ⭐⭐ MEDIUM | Part of wood family (also design 1_3, 1_8) |
| **concreteBrown** | 512x512, internet source | 512x512, custom | ⭐⭐ MEDIUM | Derived from concreteWhite |

## Folder Structure

```
_src/textures/
├── PHASE_1_DESIGN_BRIEF.md          ← Full design brief
├── PHASE_1_QUICK_REF.md             ← This file
├── phase1_references/               ← Original internet textures (copied)
│   ├── concreteWhite.png
│   ├── concreteBrown.png
│   ├── wizwood1_5.png
│   └── grass_floor1.png
├── masters/                         ← Your source files (high-res, layered)
│   └── [Your .afdesign or .psd files here]
└── exports/                         ← Final PNG exports ready for game
    └── [Export here, then copy to sacred-fruit/tb/textures/world/]
```

## Fast Workflow

1. **Design** in `masters/` (any tool, any resolution)
2. **Export** to `exports/` (exact specs: 512x512, 128x128, 64x64)
3. **Copy** from `exports/` → `sacred-fruit/tb/textures/world/`
4. **Test** in TrenchBroom (open Rascasuelos.map)
5. **Iterate**

## Testing Maps

- **concreteWhite** → `Rascasuelos.map` (2,852 faces - THE HUB)
- **grass_floor1** → `home.map` (lots of floor area)
- **wizwood1_5** → `home.map` (6,774 faces concentrated here)
- **concreteBrown** → `outside.map` (outdoor spaces)

## Design Order Recommendation

1. **concreteWhite** first (defines everything)
2. **concreteBrown** second (while concrete is fresh in mind)
3. **wizwood1_5** with siblings (1_3, 1_8 as a family)
4. **grass_floor1** last (most creative freedom)

## Color Palette Suggestion

Based on underground earth scraper theme:

**concreteWhite:** #E8E8E8 to #F5F5F5 (bright but not pure white)  
**concreteBrown:** #8B7355 to #A89080 (warm earth tones)  
**wizwood1_5:** #6B4423 to #8B6F47 (mid-tone warm brown)  
**grass_floor1:** #5A6B3F to #3D4A28 (muted green-brown)

*Adjust to taste - these are starting points*

## Tiling Test Command

Once exported, check tiling with:

```bash
# macOS Preview can tile images:
# File > Open > [your texture] > View > Actual Size > Screenshot tiled area

# Or use this to create a 2x2 tile test:
cd /Users/nre/Documents/GitHub/GAME/_src/textures/exports
magick concreteWhite.png -write mpr:tile +delete \
  -size 1024x1024 tile:mpr:tile concreteWhite_tile_test.png
```

## Affinity Designer Template Dimensions

If creating an .afdesign file, use these artboard sizes:

- **concreteWhite** artboard: 512x512px (or 1024x1024, export at 50%)
- **concreteBrown** artboard: 512x512px
- **wizwood1_5** artboard: 64x64px (or 256x256, export at 25%)
- **grass_floor1** artboard: 128x128px (or 512x512, export at 25%)

Working at 2-4x resolution gives you more control, then downscale on export.

## Key Design Constraints

✅ **MUST tile seamlessly** (wrap edges perfectly)  
✅ Must export at exact specified resolution  
✅ Save as PNG (8-bit or 24-bit RGB, no alpha channel)  
✅ sRGB color space  
✅ No extreme contrast (will be viewed under various game lighting)

## Success Check

Before calling Phase 1 "done":

- [ ] All 4 textures designed and exported
- [ ] Copied to `sacred-fruit/tb/textures/world/`
- [ ] Opened Rascasuelos.map in TrenchBroom
- [ ] No visible seams at normal viewing distance
- [ ] Feels cohesive as a set
- [ ] Distinctly "yours" (not generic internet texture vibes)
- [ ] Happy with the visual identity established

---

**Total Design Impact:** 27,305 brush faces  
**Your Time Investment:** ~1-2 weeks  
**Visual Impact:** Defines your entire game's aesthetic

Ready when you are! 🎨
