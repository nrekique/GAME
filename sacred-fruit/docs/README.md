# Docs Index

Core references for Sacred Fruit map/entity workflow.

- `DEVELOPMENT_TODO.md`
  - Current roadmap and implementation status.
- `REPO_REORG_PLAN.md`
  - Phased plan to reorganize repository layout with low-risk migration steps.
- `TB_ENTITY_QUICK_REFERENCE.md`
  - Fast mapper cheat-sheet for TrenchBroom entity keys.
- `ENTITY_SCRIPTING_GUIDE.md`
  - Full entity/runtime behavior reference.
- `ENTITY_IO_SYSTEM.md`
  - Runtime target/input/output dispatch model and debug hooks.
- `ENTITY_INTERACTION_CONTRACT.md`
  - Interaction API contract between player, interactables, and key-gated doors.
- `DIALOGUE_MARKDOWN.md`
  - Authoring format for `.md` dialogue files used by NPC conversation runtime.
- `MAP_LINTING.md`
  - Map lint command, checks, and preflight behavior.
- `MAP_VALIDATION_COOKBOOK.md`
  - Warning-by-warning lint interpretation and recommended CI gating policy.
- `DOOR_KEY_AUTHORING.md`
  - Concrete TrenchBroom key/door setups, defaults, and troubleshooting steps.
- `FGD_RUNTIME_KEY_MATRIX.md`
  - Maps FGD keys/defaults to runtime script consumers for core entities.
- `RUNTIME_MAP_PIPELINE.md`
  - TrenchBroom-to-Godot runtime launch flow, preflight checks, and failure triage.
- `RUNTIME_LOGS_AND_CRASH_SIGNATURES.md`
  - Error signature dictionary for launch failures (`exit 134`, parse/type errors, missing extensions, log path failures) with direct fixes.
- `MAP_BUILDING_GUIDELINES.md`
  - Canonical mapper standards for scale, doors, wall heights, roads, sidewalks, lighting, and prefab kit consistency.
- `KIT_SPEC_TEMPLATE.md`
  - Fill-in template for defining modular kit contracts (module sizes, snap rules, adjacency, validation maps, and versioning).
- `PORTAL_TUNING_PLAYBOOK.md`
  - Portal and mirror budget tuning presets and troubleshooting.
- `MIRROR_POLICY.md`
  - Canonical mirror runtime path.
- `ENV_STACK_ORDER.md`
  - Environment source precedence and blending order.
- `PS1_SHADER_PARAMETERS.md`
  - Describes all exported settings controlling the PS1 visual shader.
- `WORLDSPAWN_KEYS_REFERENCE.md`
  - Worldspawn global/fallback key reference.
- `VOLUMES.md`
  - Overview of runtime volume entities (damage, checkpoint, music, etc.).
- `DOCS_BACKLOG.md`
  - Prioritized documentation gaps and next additions.
- `DOCS_CONTRIBUTION_WORKFLOW.md`
  - Workflow and checklist for adding/updating docs with MkDocs nav consistency.

## Run Docs Locally

From `/Users/nre/Documents/GitHub/GAME/sacred-fruit`:

1. Install MkDocs + Material theme:
   - `python3 -m pip install --user mkdocs mkdocs-material`
2. Serve docs in browser:
   - `python3 -m mkdocs serve`
3. Open:
   - `http://127.0.0.1:8000`

Build static site output:

- `python3 -m mkdocs build`
- Output folder: `site/`
