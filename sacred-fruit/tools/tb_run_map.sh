#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -lt 1 ]]; then
  echo "Usage: tb_run_map.sh <mapfile> [play|photo|spectator]" >&2
  exit 2
fi

MODE="play"
if [[ $# -ge 2 ]]; then
  LAST_ARG="${!#}"
  case "$LAST_ARG" in
    play|photo|spectator)
      MODE="$LAST_ARG"
      set -- "${@:1:$(($#-1))}"
      ;;
  esac
fi

MAP_FILE="$*"
if [[ -z "$MAP_FILE" ]]; then
  echo "Usage: tb_run_map.sh <mapfile> [play|photo|spectator]" >&2
  exit 2
fi

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

EXTRA_ARGS=()
case "$MODE" in
  photo)
    EXTRA_ARGS+=("--tb-photo")
    ;;
  spectator)
    EXTRA_ARGS+=("--tb-spectator")
    ;;
  play)
    ;;
  *)
    echo "Invalid mode: $MODE (expected play|photo|spectator)" >&2
    exit 2
    ;;
esac

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  exec "$GODOT_BIN" --path "$ROOT_DIR" -- --tb-run-map "$MAP_FILE" "${EXTRA_ARGS[@]}"
else
  exec "$GODOT_BIN" --path "$ROOT_DIR" -- --tb-run-map "$MAP_FILE"
fi
