#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 /absolute/path/to/godot-source"
  exit 1
fi

SRC_ROOT="$1"
SRC_DIR="$SRC_ROOT/editor/icons"
DST_DIR="$(cd "$(dirname "$0")" && pwd)/editor_icons"

if [ ! -d "$SRC_DIR" ]; then
  echo "ERROR: '$SRC_DIR' not found."
  echo "Pass a local Godot engine source checkout path."
  exit 1
fi

mkdir -p "$DST_DIR"
find "$SRC_DIR" -maxdepth 1 -type f -name '*.svg' -print0 | while IFS= read -r -d '' f; do
  cp -f "$f" "$DST_DIR/$(basename "$f")"
done

echo "Imported $(find "$DST_DIR" -maxdepth 1 -type f -name '*.svg' | wc -l | tr -d ' ') Godot editor SVG icons into: $DST_DIR"
