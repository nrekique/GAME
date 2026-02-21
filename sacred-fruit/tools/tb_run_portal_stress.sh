#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if command -v godot >/dev/null 2>&1; then
  GODOT_BIN="godot"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
elif [[ -x "$HOME/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  GODOT_BIN="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
else
  echo "Godot executable not found. Install Godot CLI or update this script." >&2
  exit 1
fi

exec "$GODOT_BIN" --path "$ROOT_DIR" --script res://tools/portal_stress_bench.gd -- "$@"
