# Phase 1 Technical Specifications

**Export Settings for Godot/TrenchBroom Textures**

---

## Export Specifications

### concreteWhite.png
```
Resolution:    512 x 512 pixels
Format:        PNG
Color Mode:    RGB (24-bit) or Indexed (8-bit)
Alpha:         None
Color Space:   sRGB
Compression:   Default PNG compression
Target Size:   ~50-150KB
Tiling:        MUST be seamless on all 4 edges
```

### concreteBrown.png
```
Resolution:    512 x 512 pixels
Format:        PNG
Color Mode:    RGB (24-bit) or Indexed (8-bit)
Alpha:         None
Color Space:   sRGB
Compression:   Default PNG compression
Target Size:   ~50-150KB
Tiling:        MUST be seamless on all 4 edges
```

### grass_floor1.png
```
Resolution:    128 x 128 pixels (current) OR 256 x 256 (upgrade)
Format:        PNG
Color Mode:    RGB (24-bit) or Indexed (8-bit)
Alpha:         None
Color Space:   sRGB
Compression:   Default PNG compression
Target Size:   ~10-30KB
Tiling:        MUST be seamless on all 4 edges
Notes:         Can upgrade to 256x256 for better quality
```

### wizwood1_5.png
```
Resolution:    64 x 64 pixels
Format:        PNG
Color Mode:    RGB (24-bit) or Indexed (8-bit)
Alpha:         None
Color Space:   sRGB
Compression:   Default PNG compression
Target Size:   ~2-5KB
Tiling:        MUST be seamless on all 4 edges
Notes:         Intentionally low-res, embrace pixel aesthetic
               Design with 1_3 and 1_8 variants for consistency
```

---

## Seamless Tiling Requirements

**Critical:** These textures tile continuously across large surfaces. Seams will be immediately visible.

### Testing Tiling

**Method 1: Offset Test (Photoshop/Affinity Photo)**
1. Offset your texture by 50% horizontally and vertically
2. The seam should appear in the center
3. Fix the seam with clone stamp/healing
4. Offset back to original position

**Method 2: Tile Preview**
- Create a 2x2 or 4x4 grid of your texture
- Seams should be invisible where tiles meet

**Method 3: Filter → Tiling (if available)**
- Some tools have "Make Seamless" filters
- Test results carefully (can create unnatural patterns)

### Common Tiling Mistakes

❌ Edge values don't match opposite edge  
❌ Obvious repeated elements creating visual patterns  
❌ Directional grain that doesn't wrap naturally  
❌ Color/brightness shift at edges

✅ Edges perfectly match wraparound  
✅ Pattern variation breaks up repetition  
✅ Natural randomness or aligned directionality  
✅ Consistent brightness across entire texture

---

## Resolution Guidance

### Why These Specific Sizes?

**512x512** (concreteWhite, concreteBrown)
- Standard "mid-res" game texture
- Good detail at close range
- Reasonable memory usage
- Can scale down if needed

**128x128** (grass_floor1)
- Low-res but acceptable for floors
- Very fast to render
- Consider 256x256 upgrade for quality
- Helps hide tiling with more detail

**64x64** (wizwood1_5)
- Extremely low-res
- Intentional stylistic choice
- Forces simple, readable design
- Retro/PS1 aesthetic appeal

### Working Resolution Recommendation

Design at **2x or 4x target resolution**, then downscale:

- **concreteWhite**: Work at 1024x1024 or 2048x2048 → export 512x512
- **wizwood1_5**: Work at 256x256 → export 64x64
- **grass_floor1**: Work at 512x512 → export 128x128 (or 256x256)

**Benefits:**
- More control over fine details
- Cleaner edges when downscaling
- Can keep high-res master for future use
- Downscaling naturally anti-aliases

---

## Color Considerations

### Underground Lighting Context

Your textures will be viewed under:
- Artificial lights (emissive materials)
- No natural sunlight
- Possibly colored lighting (tunnel ambience)
- Dark/moody atmosphere

**Design Implications:**
- Don't rely on extreme brightness (will blow out)
- Don't go too dark (will disappear in shadows)
- Mid-tones are your friend
- Slightly boost saturation (lighting will desaturate)

### Recommended Value Ranges

**concreteWhite:**
- Lightest values: ~90-95% brightness
- Darkest values: ~70-80% brightness
- Keep it high-key but not pure white

**concreteBrown:**
- Lightest values: ~60-70% brightness
- Darkest values: ~30-40% brightness
- Earth tone saturation: 15-25%

**wizwood:**
- Lightest values: ~50-60% brightness
- Darkest values: ~20-30% brightness
- Warm hue (orange-brown): 25-35 degrees
- Moderate saturation: 30-40%

**grass_floor1:**
- Lightest values: ~45-55% brightness
- Darkest values: ~25-35% brightness
- Green-brown hue: 70-90 degrees
- Low saturation: 15-25%

---

## File Naming

**Follow exact names** - TrenchBroom loads by filename:

✅ `concreteWhite.png` (exact case matters)  
✅ `concreteBrown.png`  
✅ `wizwood1_5.png`  
✅ `grass_floor1.png`

❌ Don't use: `concretewhite.png`, `concrete_white.png`, `concreteWhite_v2.png`

**Master files** can use any name:
- `concreteWhite_master_v1.afdesign`
- `phase1_concrete_family.psd`
- Whatever works for your workflow

---

## Export Checklist

Before copying to `sacred-fruit/tb/textures/world/`:

- [ ] Correct resolution (check with `file` command or image properties)
- [ ] PNG format
- [ ] No alpha channel (fully opaque)
- [ ] Tiles seamlessly (test with 2x2 preview)
- [ ] Reasonable file size (<200KB for 512x512)
- [ ] Exact filename match
- [ ] Saved in `_src/textures/exports/`

---

## Installation

Once exported and tested:

```bash
cd /Users/nre/Documents/GitHub/GAME/_src/textures/exports

# Copy to game textures folder (overwrites internet versions)
cp concreteWhite.png /Users/nre/Documents/GitHub/GAME/sacred-fruit/tb/textures/world/
cp concreteBrown.png /Users/nre/Documents/GitHub/GAME/sacred-fruit/tb/textures/world/
cp wizwood1_5.png /Users/nre/Documents/GitHub/GAME/sacred-fruit/tb/textures/world/
cp grass_floor1.png /Users/nre/Documents/GitHub/GAME/sacred-fruit/tb/textures/world/

# Godot will auto-reimport on next launch
```

**Backup Tip:** Original internet textures are saved in `_src/textures/phase1_references/`

---

## Verification

After installation, verify in TrenchBroom:

1. Open `sacred-fruit/tb/maps/Rascasuelos.map`
2. Your new concreteWhite should load automatically
3. Check for:
   - Visible seams (rotate camera and look carefully)
   - Color/brightness issues
   - Tiling pattern repetition
   - Overall aesthetic fit

If something looks wrong:
- Iterate in your master file
- Re-export
- Re-copy
- Re-check

---

## Godot Import Settings

Godot creates `.import` files automatically. Default settings are usually fine, but if you need to adjust:

**Location:** `sacred-fruit/tb/textures/world/[texture].png.import`

```ini
[remap]
importer="texture"
type="CompressedTexture2D"

[params]
compress/mode=0          # 0 = Lossless, 2 = VRAM Compressed
mipmaps/generate=true    # Recommended for world textures
repeat=1                 # Required for tiling
filter=true              # Can set false for hard pixel look
```

**Usually leave defaults** - Godot handles texture import well for Quake-style textures.

---

## Performance Notes

**Memory Usage (uncompressed in VRAM):**
- 512x512 RGB = 768 KB each
- 128x128 RGB = 48 KB each
- 64x64 RGB = 12 KB each

**Phase 1 Total:** ~1.6 MB for all 4 textures (insignificant)

**Mipmap chains** (automatically generated):
- Adds ~33% memory overhead
- Essential for proper rendering at distance
- Godot handles automatically

---

## Going Beyond Phase 1

Once these 4 are done and you're happy:

**Next: Phase 2 (8 textures, P1 priority)**
- curtainsBlack (3,846 faces)
- wizwood1_8 (2,397 faces)
- marble (1,898 faces)
- redPlaster (1,335 faces)
- groundBrown2 (1,167 faces)
- groundRed2 (1,158 faces)
- indRed2 (1,092 faces)
- cutains (1,086 faces)

But first: nail these 4 foundation textures. They're 45% of your visual identity.

---

**Questions while designing?** Check the design brief or test early and often in TrenchBroom!
