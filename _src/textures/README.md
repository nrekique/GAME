# Phase 1: Foundation Textures

Replace the top 4 internet-sourced textures with custom designs.

**Impact:** 27,305 brush faces (45% of all geometry)

---

## 📋 The 4 Textures

1. **concreteWhite** (5,936 faces) - Your earth scraper hub signature ⭐⭐⭐
2. **grass_floor1** (9,367 faces) - Most used floor texture ⭐⭐⭐
3. **wizwood1_5** (6,774 faces) - Dominant wood variant ⭐⭐
4. **concreteBrown** (5,228 faces) - Weathered concrete ⭐⭐

---

## 📚 Documentation

- **[PHASE_1_DESIGN_BRIEF.md](PHASE_1_DESIGN_BRIEF.md)** - Detailed design requirements and context
- **[PHASE_1_QUICK_REF.md](PHASE_1_QUICK_REF.md)** - Fast workflow reference
- **[PHASE_1_TECHNICAL_SPECS.md](PHASE_1_TECHNICAL_SPECS.md)** - Export settings and requirements

**📖 Also available in MkDocs:** See Roadmap section after running `mkdocs serve` from `sacred-fruit/`

---

## 📁 Folder Structure

```
_src/textures/
├── README.md                        ← You are here
├── PHASE_1_DESIGN_BRIEF.md         ← Start here for design direction
├── PHASE_1_QUICK_REF.md            ← Quick lookup while working
├── PHASE_1_TECHNICAL_SPECS.md      ← Export specifications
│
├── phase1_references/              ← Original internet textures (backup)
│   ├── concreteWhite.png
│   ├── concreteBrown.png
│   ├── wizwood1_5.png
│   └── grass_floor1.png
│
├── masters/                        ← Your source files (work here)
│   └── [Create your .afdesign, .psd, .blend, etc. here]
│
└── exports/                        ← Final PNG exports (ready for game)
    └── [Export PNG files here, then copy to game]
```

---

## 🚀 Quick Start

1. **Read** [PHASE_1_DESIGN_BRIEF.md](PHASE_1_DESIGN_BRIEF.md)
2. **Design** your textures in `masters/` folder (any tool)
3. **Export** to `exports/` folder (exact specs from TECHNICAL_SPECS.md)
4. **Copy** to `sacred-fruit/tb/textures/world/`
5. **Test** in TrenchBroom (Rascasuelos.map)
6. **Iterate** until happy

---

## ✅ Completion Checklist

- [ ] concreteWhite designed and exported (512x512)
- [ ] concreteBrown designed and exported (512x512)
- [ ] wizwood1_5 designed and exported (64x64)
- [ ] grass_floor1 designed and exported (128x128 or 256x256)
- [ ] All textures tile seamlessly
- [ ] Tested in Rascasuelos.map (looks good!)
- [ ] Satisfied with earth scraper aesthetic
- [ ] Ready for Phase 2

---

## 🎯 Design Goals

**Earth Scraper Hub Aesthetic:**
- Modern underground infrastructure
- Clean but not sterile
- Maintained civilized spaces
- Mix of concrete (structure) and organic (human) elements

**Visual Hierarchy:**
- concreteWhite = clean/maintained (the ideal)
- concreteBrown = weathered/exposed (the reality)
- wizwood = domestic/human warmth
- grass_floor1 = organic ground layer

---

## 📊 Impact

These 4 textures appear **27,305 times** in your maps. They define your game's visual identity.

**Time Investment:** 1-2 weeks  
**Visual Impact:** Establishes entire aesthetic foundation

---

## 🔄 Workflow

```bash
# Quick copy command (once exported):
cd /Users/nre/Documents/GitHub/GAME/_src/textures/exports
cp *.png /Users/nre/Documents/GitHub/GAME/sacred-fruit/tb/textures/world/
```

Godot will auto-reimport on next launch.

---

## 🎨 Tools

Suggested (use what you prefer):
- Affinity Designer/Photo (you have .afdesign files already)
- Blender (procedural textures)
- Substance Designer/Painter
- Photoshop
- GIMP
- Krita

---

## 💡 Tips

- Start with **concreteWhite** - it defines everything else
- Design **wizwood family** together (1_3, 1_5, 1_8) for consistency
- **Test early, test often** - export rough drafts and see them in-engine
- Don't overthink it - you can always iterate
- These set the foundation for 50+ more textures

---

## ⏭️ What's Next?

**Phase 2:** 8 more textures (11,884 faces combined)
- curtainsBlack, wizwood1_8, marble, redPlaster, etc.

**Phase 3+:** Remaining 63 textures organized by priority

But first: nail these 4. They're your visual identity.

---

Ready to design! 🎨
