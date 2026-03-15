# Phase 1: Foundation Texture Design Brief

**Goal:** Replace the top 4 internet-sourced textures with custom-designed materials that establish the visual identity of your underground tunnel and earth scraper setting.

**Total Impact:** 27,305 brush faces (45% of all level geometry)

---

## Design Priority Order

### 1. `world/concreteWhite` ⭐⭐⭐ CRITICAL
**Usage:** 5,936 faces  
**Maps:** Rascasuelos (2,852), Rascasuelos2 (712), birthday, grill, outside, theater  
**Current Specs:** 512x512, 73KB file size  
**Role:** **PRIMARY HUB MATERIAL** - This IS your earth scraper's signature look

**Design Requirements:**
- Clean, architectural concrete
- White/light gray base - represents underground modernity
- Subtle texture for visual interest when covering large areas
- Must tile seamlessly (critical - used on massive surfaces)
- Slightly geometric/industrial feel (earth scraper = inverted skyscraper)
- Should read as "clean underground infrastructure"

**Reference Direction:**
- Modern subway stations (clean concrete)
- Brutalist architecture (but lighter)
- Underground parking structures (new construction)
- NOT weathered/damaged - this is the maintained hub area

**Technical:**
- Export at 512x512
- Tileable on all edges
- Consider subtle directionality (like concrete pour lines) but must tile well
- Test at scale - will be seen close and far

---

### 2. `world/grass_floor1` ⭐⭐⭐
**Usage:** 9,367 faces (HIGHEST usage!)  
**Maps:** bigbrother, home, outside, theater, venue  
**Current Specs:** 128x128 (small!), 12KB  
**Role:** Primary interior ground surface

**Design Requirements:**
- Indoor ground texture - NOT outdoor grass
- Name suggests grass-like but used indoors (check if this is actually carpet/matting?)
- Low resolution acceptable (currently 128x128) - allows pattern variation
- Earthy/organic feel for "lived-in" underground spaces
- Must contrast well with concreteWhite walls

**Design Options:**
A. Worn carpet/mat texture (greenish-brown)
B. Artificial turf/astroturf (underground sports area?)
C. Moss/organic growth (underground nature reclaiming)
D. Painted floor with grass-green tones

**Technical:**
- Can stay low-res (128x128 or bump to 256x256)
- Perfect tiling essential (used everywhere)
- Consider noise/variation to hide tiling at high usage

---

### 3. `world/wizwood1_5` ⭐⭐
**Usage:** 6,774 faces  
**Maps:** home (massive usage)  
**Current Specs:** 64x64 (VERY small), 2.5KB  
**Role:** Dominant wood - warm residential tone

**Design Requirements:**
- Part of "wizwood" family (need consistent style across 1_3, 1_5, 1_8)
- Very low resolution (64x64) = stylized/simple grain
- Warm brown tone (the "5" suggests mid-tone in the series)
- Used heavily in "home" map = domestic/cozy feeling
- Underground housing = reclaimed/precious wood aesthetic?

**Design Direction:**
- Simple, readable wood grain at tiny resolution
- Think PS1/N64 wood textures but cleaner
- Possibly painted/treated wood (underground preservation)
- NOT photorealistic - embrace the low-res constraint

**Technical:**
- 64x64 is TINY - keep details large/simple
- Must tile seamlessly
- Consider this will be upscaled in-engine (intentional pixelation?)
- Design for the full wizwood family (coordinate with 1_3 and 1_8)

---

### 4. `world/concreteBrown` ⭐⭐
**Usage:** 5,228 faces  
**Maps:** grill, home, outside, venue  
**Current Specs:** 512x512, 114KB (largest file)  
**Role:** Weathered exterior/aged concrete

**Design Requirements:**
- Outdoor/exposed concrete variant
- Brown tint = dirt, oxidation, weathering
- Rougher than concreteWhite (this is the "outside" version)
- Still concrete structure but shows age/exposure
- Should feel connected to concreteWhite (same material, different condition)

**Design Direction:**
- Start with concreteWhite design, add weathering
- Brown stains, dirt accumulation
- More texture variation than the clean white version
- Underground exterior = minimal natural weathering, more use-wear
- Think: subway tunnels vs subway stations

**Technical:**
- 512x512 to match concreteWhite
- Seamless tiling
- Can layer weathering over base concrete pattern
- Consider color overlay workflow from concreteWhite master

---

## Design Workflow

### Recommended Tools:
- **Affinity Designer** (you already have .afdesign files in _src/)
- **Affinity Photo** for texture work
- Or any tool you prefer (Blender, Substance, Photoshop, etc.)

### Suggested Approach:

1. **Start with concreteWhite** - this defines everything
   - Sets the "clean" baseline
   - Establishes your concrete style
   - Will inform concreteBrown design

2. **Design wizwood family together**
   - Create all three variants (1_3, 1_5, 1_8) as a set
   - Maintain consistent grain pattern/style
   - Use color/value to differentiate

3. **Nail grass_floor1 personality**
   - This appears everywhere - needs character
   - Test against concreteWhite walls
   - Consider what this surface means (carpet? growth? painted floor?)

4. **Derive concreteBrown from White**
   - Same base structure
   - Add weathering/color layers
   - Keeps visual consistency

### File Organization:

```
_src/textures/
├── PHASE_1_DESIGN_BRIEF.md (this file)
├── phase1_workspace.afdesign (or your format)
├── masters/
│   ├── concreteWhite_master.png (source)
│   ├── concreteBrown_master.png
│   ├── wizwood_family_master.png
│   └── grass_floor1_master.png
└── exports/
    ├── concreteWhite.png (512x512 → copy to tb/textures/world/)
    ├── concreteBrown.png (512x512)
    ├── wizwood1_5.png (64x64)
    └── grass_floor1.png (128x128 or 256x256)
```

---

## Testing Strategy

1. **Export first drafts** at spec resolution
2. **Copy to** `sacred-fruit/tb/textures/world/`
3. **Open Rascasuelos.map** in TrenchBroom
4. **Evaluate at scale:**
   - Does concreteWhite work on huge walls?
   - Do seams show?
   - Does it feel like an earth scraper hub?
5. **Iterate rapidly**

---

## Style Guidelines for Underground/Earth Scraper Aesthetic

**Earth Scraper Context:**
- Inverted skyscraper descending into earth
- Modern architecture (not ancient/fantasy ruins)
- Maintained infrastructure (not abandoned)
- Artificial lighting environment
- Mix of utilitarian and inhabited spaces

**Tunnel Traversal:**
- Connection corridors between spaces
- Should feel like infrastructure (pipes, concrete, industrial)
- Contrast between hub (clean) and tunnels (functional)

**Visual Coherence:**
- concreteWhite = the ideal/new
- concreteBrown = the aged/exposed
- wizwood = the human/domestic element
- grass_floor1 = the organic/lived-in softness

**These 4 textures set your entire visual language.** Get them right and the rest will follow their lead.

---

## Success Criteria

✅ Seamless tiling (no visible seams at any scale)  
✅ Reads clearly at both close and far distances  
✅ Feels cohesive as a set (they'll appear together)  
✅ Establishes "underground earth scraper" mood  
✅ Distinct from generic HL2/Source engine concrete  
✅ Personal/custom - clearly YOUR design aesthetic  

---

## Next Steps

1. Create design workspace (Affinity Designer/Photo recommended)
2. Start with concreteWhite prototype
3. Test in-engine early and often
4. Share drafts for feedback when ready
5. Once approved, move to Phase 2 (8 more textures)

**Time Estimate:** 1-2 weeks for initial designs + iteration

Remember: These will be seen 27,000+ times. Take the time to make them distinctive and cohesive. This is your game's foundation.
