#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORLD_DIR="$ROOT_DIR/tb/textures/world"
AUDIT_DIR="$WORLD_DIR/_audit"
CHECKLIST="$ROOT_DIR/docs/TEXTURE_PRODUCTION_CHECKLIST.md"

mkdir -p "$AUDIT_DIR"

# Canonical assets in world folder.
find "$WORLD_DIR" -maxdepth 1 -type f \
  \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' -o -name '*.tres' \) \
  ! -name '*.import' \
  | sed 's#^.*/##' | sort > "$AUDIT_DIR/all_assets.txt"

# Active refs: source maps/scenes/config only (exclude cache/docs/autosaves/archive).
find "$ROOT_DIR" -type f \
  \( -name '*.map' -o -name '*.tscn' -o -name '*.tres' -o -name '*.gd' -o -name '*.cfg' -o -name '*.json' -o -name '*.txt' \) \
  ! -path "$ROOT_DIR/tb/textures/world/*" \
  ! -path "$ROOT_DIR/.godot/*" \
  ! -path "$ROOT_DIR/docs/*" \
  ! -path "$ROOT_DIR/tb/autosave/*" \
  ! -path "$ROOT_DIR/tb/archive/*" \
  ! -path "$ROOT_DIR/tb/maps/autosave/*" \
  > "$AUDIT_DIR/ref_files_active.txt"

# Legacy refs: autosaves, archive, import cache.
find "$ROOT_DIR" -type f \
  \( -name '*.map' -o -name '*.tres' \) \
  \( -path "$ROOT_DIR/.godot/*" -o -path "$ROOT_DIR/tb/autosave/*" -o -path "$ROOT_DIR/tb/archive/*" -o -path "$ROOT_DIR/tb/maps/autosave/*" \) \
  > "$AUDIT_DIR/ref_files_legacy.txt"

: > "$AUDIT_DIR/used_active.txt"
: > "$AUDIT_DIR/used_legacy_only.txt"
: > "$AUDIT_DIR/unused_candidates.txt"
: > "$AUDIT_DIR/active_hits.tsv"
: > "$AUDIT_DIR/legacy_hits.tsv"

while IFS= read -r asset; do
  stem="${asset%.*}"
  active_hits="$(rg -n -F "world/$stem" $(cat "$AUDIT_DIR/ref_files_active.txt") 2>/dev/null || true)"
  if [ -z "$active_hits" ]; then
    active_hits="$(rg -n -F "$asset" $(cat "$AUDIT_DIR/ref_files_active.txt") 2>/dev/null || true)"
  fi

  if [ -n "$active_hits" ]; then
    echo "$asset" >> "$AUDIT_DIR/used_active.txt"
    printf '%s\t%s\n' "$asset" "$(printf '%s\n' "$active_hits" | sed -n '1p')" >> "$AUDIT_DIR/active_hits.tsv"
    continue
  fi

  legacy_hits="$(rg -n -F "world/$stem" $(cat "$AUDIT_DIR/ref_files_legacy.txt") 2>/dev/null || true)"
  if [ -z "$legacy_hits" ]; then
    legacy_hits="$(rg -n -F "$asset" $(cat "$AUDIT_DIR/ref_files_legacy.txt") 2>/dev/null || true)"
  fi

  if [ -n "$legacy_hits" ]; then
    echo "$asset" >> "$AUDIT_DIR/used_legacy_only.txt"
    printf '%s\t%s\n' "$asset" "$(printf '%s\n' "$legacy_hits" | sed -n '1p')" >> "$AUDIT_DIR/legacy_hits.tsv"
  else
    echo "$asset" >> "$AUDIT_DIR/unused_candidates.txt"
  fi
done < "$AUDIT_DIR/all_assets.txt"

sort -u "$AUDIT_DIR/used_active.txt" -o "$AUDIT_DIR/used_active.txt"
sort -u "$AUDIT_DIR/used_legacy_only.txt" -o "$AUDIT_DIR/used_legacy_only.txt"
sort -u "$AUDIT_DIR/unused_candidates.txt" -o "$AUDIT_DIR/unused_candidates.txt"

if [ -f "$CHECKLIST" ]; then
  rg -n '^\| \[ \] \| `world/' "$CHECKLIST" \
    | sed -E 's#.*`world/([^`]+)`.*#\1#' \
    | sed '/^\s*$/d' \
    | sort -u > "$AUDIT_DIR/needs_update_from_checklist_raw.txt"
  : > "$AUDIT_DIR/needs_update_existing_assets.txt"
  while IFS= read -r stem; do
    found="$(find "$WORLD_DIR" -maxdepth 1 -type f \( -name "$stem.png" -o -name "$stem.jpg" -o -name "$stem.jpeg" -o -name "$stem.webp" -o -name "$stem.tres" \) | sed -n '1p')"
    if [ -n "$found" ]; then
      basename "$found" >> "$AUDIT_DIR/needs_update_existing_assets.txt"
    fi
  done < "$AUDIT_DIR/needs_update_from_checklist_raw.txt"
  sort -u "$AUDIT_DIR/needs_update_existing_assets.txt" -o "$AUDIT_DIR/needs_update_existing_assets.txt"
fi

{
  echo "# Hygiene issues"
  echo
  echo "## Unexpected files"
  find "$WORLD_DIR" -maxdepth 1 -type f \( -name '.DS_Store' -o -name '*.import-*' -o -name '*.map' \) | sed 's#^.*/##' | sort
  echo
  echo "## Assets missing .import pair"
  while IFS= read -r f; do
    case "$f" in
      *.png|*.jpg|*.jpeg|*.webp)
        if [ ! -f "$WORLD_DIR/$f.import" ]; then
          echo "$f"
        fi
        ;;
    esac
  done < "$AUDIT_DIR/all_assets.txt"
} > "$AUDIT_DIR/hygiene_report.md"

all_count="$(wc -l < "$AUDIT_DIR/all_assets.txt" | tr -d ' ')"
active_count="$(wc -l < "$AUDIT_DIR/used_active.txt" | tr -d ' ')"
legacy_count="$(wc -l < "$AUDIT_DIR/used_legacy_only.txt" | tr -d ' ')"
unused_count="$(wc -l < "$AUDIT_DIR/unused_candidates.txt" | tr -d ' ')"
needs_count="$([ -f "$AUDIT_DIR/needs_update_existing_assets.txt" ] && wc -l < "$AUDIT_DIR/needs_update_existing_assets.txt" | tr -d ' ' || echo 0)"

cat > "$AUDIT_DIR/README.md" <<EOF
# World Texture Audit

Generated from project reference scan on $(date '+%Y-%m-%d %H:%M:%S').

- Total assets: $all_count
- Used (active project refs): $active_count
- Used only in legacy/autosave/cache refs: $legacy_count
- Unused candidates: $unused_count
- Needs update (from checklist and exists): $needs_count

## Files
- all_assets.txt
- used_active.txt
- used_legacy_only.txt
- unused_candidates.txt
- active_hits.tsv
- legacy_hits.tsv
- needs_update_existing_assets.txt
- hygiene_report.md

## Notes
- Active refs exclude docs, import cache, autosaves, and archive maps.
- Legacy refs include .godot import cache plus tb autosave/archive map areas.
- "Needs update" comes from unchecked rows in docs/TEXTURE_PRODUCTION_CHECKLIST.md, filtered to assets that exist now.
EOF

# Folder views (symlinks only; source assets stay in place).
USED_VIEW="$AUDIT_DIR/view_used_active"
UNUSED_VIEW="$AUDIT_DIR/view_unused_candidates"
NEEDS_VIEW="$AUDIT_DIR/view_needs_update"
rm -rf "$USED_VIEW" "$UNUSED_VIEW" "$NEEDS_VIEW"
mkdir -p "$USED_VIEW" "$UNUSED_VIEW" "$NEEDS_VIEW"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  ln -s "../../$f" "$USED_VIEW/$f"
done < "$AUDIT_DIR/used_active.txt"

while IFS= read -r f; do
  [ -n "$f" ] || continue
  ln -s "../../$f" "$UNUSED_VIEW/$f"
done < "$AUDIT_DIR/unused_candidates.txt"

if [ -f "$AUDIT_DIR/needs_update_existing_assets.txt" ]; then
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    ln -s "../../$f" "$NEEDS_VIEW/$f"
  done < "$AUDIT_DIR/needs_update_existing_assets.txt"
fi

echo "all=$all_count active=$active_count legacy_only=$legacy_count unused=$unused_count needs_update=$needs_count"
