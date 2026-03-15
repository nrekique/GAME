# Sacred Fruit Codebase Issues & Technical Debt

**Date:** March 15, 2026  
**Analysis Type:** Code quality audit after cleanup session

---

## 🔍 Issues Found

### 1. **Large Files (God Objects)**

**Critical (>1000 lines):**
- `photo_mode.gd` — **5,683 lines** 🔴
  - **Issue:** Massive monolithic controller, mixes UI + logic + state
  - **Impact:** Hard to maintain, slow to load in editor, difficult to test
  - **Fix:** Already in progress — UI refactor will reduce to ~800 lines
  - **Priority:** HIGH (already started)

**High (500-1000 lines):**
- `debug_menu.gd` — **988 lines** 🟠
  - **Issue:** Monolithic debug tool, mixed concerns
  - **Impact:** Hard to extend or modify
  - **Fix:** Already complete! Replaced with F3 overlay + F1 menu (475 lines total)
  - **Priority:** DONE ✅ (can deprecate old file)

- `sandstorm_controller.gd` — **968 lines** 🟠
  - **Issue:** Very large for a single weather effect
  - **Impact:** May contain duplicated logic or overly complex state machine
  - **Recommendation:** Review for extraction opportunities
  - **Priority:** MEDIUM

- `player.gd` — **869 lines** 🟡
  - **Issue:** Large player controller
  - **Impact:** Might mix movement, input, animation, inventory, etc.
  - **Recommendation:** Consider extracting systems (movement, inventory, interaction)
  - **Priority:** MEDIUM

- `dialogue_manager.gd` — **640 lines** 🟡
  - **Issue:** Large dialogue system core
  - **Impact:** Complex state management
  - **Recommendation:** Review for state machine extraction
  - **Priority:** LOW (dialogue systems are inherently complex)

---

### 2. **Deprecated Files**

**Can be removed:**
- `debug_menu.gd` (988 lines) — Replaced by debug_overlay.gd + map_builder_menu.gd
- `debug_menu.tscn` — Replaced by debug_overlay.tscn + map_builder_menu.tscn

**Impact:** 988 lines of dead code  
**Priority:** LOW (not causing issues, but clutters repo)

---

### 3. **Incomplete Work**

**TODO/FIXME markers:**
- `map_builder_menu.gd:295` — Entity generation logic needs porting (~600 lines from old debug_menu.gd)
  - **Impact:** TrenchBroom entity generator non-functional
  - **Priority:** MEDIUM (dev tool, not critical path)

---

### 4. **Unstaged Changes**

**Modified but not committed:**
```
 M sacred-fruit/game_manager.gd
 M sacred-fruit/scripts/core/dialogue_manager.gd
 M sacred-fruit/scripts/core/settings.gd
 M sacred-fruit/scripts/core/util.gd
```

**Deleted textures:**
```
 D sacred-fruit/tb/textures/mars/*.png (4 files)
 D sacred-fruit/tb/textures/world/*.png (5 files)
 D sacred-fruit/tb/textures/special/__tb_empty.png
```

**Impact:** Unknown — need to review what changed  
**Priority:** HIGH (should commit or revert)

---

### 5. **Potential Code Smells**

**Commented-out code:**
- Found ~13 instances of commented function/variable declarations
- **Impact:** Dead code cluttering files
- **Recommendation:** Remove or document why kept
- **Priority:** LOW

**Warning/Error handling:**
- Only 30 `push_warning`/`push_error` calls across entire codebase
- **Issue:** May indicate insufficient error handling
- **Recommendation:** Audit critical paths (file I/O, scene loading, networking)
- **Priority:** MEDIUM

---

### 6. **Deleted Texture Files**

**Missing assets:**
- Mars terrain textures (cave, cliff, sand0, sand1)
- World textures (Assunto, dirt_normal, grass_normal, water_normal)
- Special textures (__tb_empty)

**Impact:** 
- TrenchBroom maps may show missing textures
- Runtime errors if maps reference deleted textures
- Build warnings

**Recommendation:** 
- If intentionally deleted: Update maps to remove references
- If accidentally deleted: Restore from git history

**Priority:** MEDIUM (affects level design workflow)

---

## 📊 Code Quality Metrics

**Total scripts:** ~80 files  
**Lines of code:** ~15,000 (estimated)  
**Largest file:** 5,683 lines (photo_mode.gd)  
**Average file size:** ~188 lines  
**Files >500 lines:** 5 files (6% of codebase)

**Distribution:**
- <200 lines: ~70% (good ✓)
- 200-500 lines: ~24% (acceptable)
- 500-1000 lines: ~5% (concerning)
- 1000+ lines: ~1% (critical)

---

## 🎯 Recommended Actions

### Immediate (This Session)
1. ✅ **DONE:** Fix constant expression errors
2. ✅ **DONE:** Fix debug_print parse errors
3. ✅ **DONE:** Create F3 overlay + F1 menu
4. **Review unstaged changes** — Commit or revert modified files
5. **Document texture deletions** — Update maps or restore files

### Short-term (Next Session)
1. **Integrate photo mode tabs** — Reduce photo_mode.gd from 5,683 → ~800 lines
2. **Port entity generation** — Complete map_builder_menu.gd functionality
3. **Deprecate old debug menu** — Remove debug_menu.gd + .tscn
4. **Audit error handling** — Add push_error() to critical paths

### Medium-term (Future)
1. **Refactor player.gd** — Extract movement/inventory/interaction systems
2. **Refactor sandstorm_controller.gd** — Review for complexity reduction
3. **Remove commented code** — Clean up ~13 commented blocks
4. **Add unit tests** — Cover critical systems (dialogue, save/load, etc.)

### Long-term (Maintenance)
1. **Establish file size limits** — Max 500 lines per file (guideline)
2. **Add pre-commit hooks** — Lint, format, size checks
3. **Document architecture** — System diagrams, dependency maps
4. **Performance profiling** — Identify bottlenecks in large controllers

---

## 🔒 Security Audit (from this session)

✅ **Completed:**
- Added path sanitization to trigger_changelevel.gd
- Added path sanitization to trigger_exit.gd
- Added path sanitization to func_prefab_instance.gd
- Added path sanitization to ai_wave_spawner.gd
- Added path sanitization to env_sky_scene.gd

**Allowlists in place:**
- Scene roots: `res://scenes/`, `res://tb/`, `res://entities/`
- Warnings when paths rejected
- Prevents loading arbitrary scenes from untrusted maps

---

## 📈 Progress Tracking

**Before this session:**
- photo_mode.gd: 5,683 lines (monolithic)
- debug_menu.gd: 988 lines (monolithic)
- 20 ungated print() calls
- 30+ magic numbers
- 23 parse errors
- 0 path sanitization

**After this session:**
- photo_mode.gd: 5,683 lines (UI tabs ready, integration pending)
- debug_overlay.gd: 175 lines ✓
- map_builder_menu.gd: 300 lines ✓
- All print() calls gated ✓
- Constants extracted ✓
- 0 parse errors ✓
- 5 systems with path sanitization ✓

**Projected after photo integration:**
- photo_mode.gd: ~800 lines (85% reduction) 🎯
- Total reduction: 6,838 → 1,000 lines

---

## ✅ Next Session Goals

1. **Review unstaged changes** (30 min)
   - Commit util.gd changes (path sanitization functions)
   - Review game_manager.gd, dialogue_manager.gd, settings.gd changes
   - Commit or revert texture deletions

2. **Integrate photo mode tabs** (2-3 hours)
   - Create PhotoModeUI.tscn wrapper
   - Refactor photo_mode.gd to use tab components
   - Wire tab signals
   - Test in-game

3. **Complete map builder** (1-2 hours)
   - Port entity generation logic from old debug_menu.gd
   - Test TrenchBroom entity creation
   - Add entity preview

4. **Cleanup** (30 min)
   - Remove old debug_menu files
   - Remove commented-out code blocks
   - Update documentation

---

## 📚 Related Files

**Analysis:**
- This file: `CODEBASE_ISSUES_ANALYSIS.md`

**Session summaries:**
- `SESSION_COMPLETE.md` — Today's work summary
- `FINAL_SESSION_SUMMARY.md` — Complete commit list
- `DEBUG_MENU_REFACTOR_COMPLETE.md` — F3/F1 menu details
- `COMPONENT_LIBRARY_COMPLETE.md` — UI components
- `PHOTO_MODE_TABS_COMPLETE.md` — Photo tabs

---

**Analysis complete! Use this to prioritize next session's work.** 📊✨
