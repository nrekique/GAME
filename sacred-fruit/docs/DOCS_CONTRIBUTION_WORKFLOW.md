# Docs Contribution Workflow

Use this workflow when adding or updating project documentation.

## Where Docs Live

- Primary docs source: `sacred-fruit/docs/`
- Site config/navigation: `sacred-fruit/mkdocs.yml`

## Naming Rules

- Use uppercase snake case for filenames:
  - `MY_DOC_TITLE.md`
- Keep titles mapper/dev-facing and specific.
- One topic per file. Avoid mixing unrelated systems in one page.

## Authoring Rules

1. Start with purpose and scope.
2. Use concrete keys, paths, and command examples from real project files.
3. Prefer short sections and checklists for mapper workflows.
4. Link related pages at top when a doc depends on other guides.
5. When documenting entity keys, include:
   - key name
   - default value
   - consuming runtime script path
   - behavior notes/caveats

## Navigation Update Rules

Every new docs page must be added to `mkdocs.yml` under the best fit section:

- `Mapping`
- `Entities`
- `Rendering`
- `Contributing`

If the page is high-frequency, also add it to `docs/index.md` quick links.

## Validation Checklist (Before Merge)

1. File is in `docs/` and named correctly.
2. `mkdocs.yml` includes nav entry.
3. `docs/README.md` index includes the page.
4. Any commands are copy/paste runnable from project root.
5. Paths and script names match current repo layout.
6. No stale references to moved scripts/files.

## Recommended Local Preview

From `sacred-fruit/`:

1. `python3 -m pip install --user mkdocs mkdocs-material`
2. `python3 -m mkdocs serve`
3. Open `http://127.0.0.1:8000`

## Commit Scope Guidance

- Keep doc-only PRs focused:
  - docs content
  - nav/index wiring
  - no unrelated code refactors
- If doc depends on new behavior, merge code first, then docs update in same PR or immediate follow-up.

