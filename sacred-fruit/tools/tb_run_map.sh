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

AVAILABLE_KB="$(df -Pk "$ROOT_DIR" | awk 'NR==2 {print $4}')"
MIN_FREE_KB="${TB_MIN_FREE_KB:-1048576}" # 1 GiB default safety floor
if [[ -n "$AVAILABLE_KB" && "$AVAILABLE_KB" -lt "$MIN_FREE_KB" ]]; then
  echo "ERROR: low disk space on project volume." >&2
  echo "Available: ${AVAILABLE_KB} KiB, required minimum: ${MIN_FREE_KB} KiB." >&2
  echo "Godot can crash in startup logging/import when free space is this low." >&2
  echo "Free space and rerun, or override with TB_MIN_FREE_KB=0." >&2
  exit 1
fi

if [[ "${TB_SKIP_LINT:-0}" != "1" ]]; then
  LINT_MAP_FILE="$MAP_FILE"
  if [[ ! -f "$LINT_MAP_FILE" ]]; then
    if [[ -f "$ROOT_DIR/tb/$MAP_FILE" ]]; then
      LINT_MAP_FILE="$ROOT_DIR/tb/$MAP_FILE"
    elif [[ -f "$ROOT_DIR/$MAP_FILE" ]]; then
      LINT_MAP_FILE="$ROOT_DIR/$MAP_FILE"
    fi
  fi
  if [[ -f "$LINT_MAP_FILE" ]]; then
    echo "Linting map: $LINT_MAP_FILE"
    "$ROOT_DIR/tools/tb_lint_map.sh" "$LINT_MAP_FILE"
  else
    echo "WARN: map lint skipped (file not found for lint preflight): $MAP_FILE" >&2
  fi
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

LOG_DIR="${TB_GODOT_LOG_DIR:-$ROOT_DIR/.godot/tb_logs}"
if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
  LOG_DIR="/tmp"
  mkdir -p "$LOG_DIR"
fi
if [[ -n "${TB_GODOT_LOG_FILE:-}" ]]; then
  LOG_FILE="$TB_GODOT_LOG_FILE"
else
  LOG_FILE="$LOG_DIR/tb_run_$(date +%Y%m%d_%H%M%S_%N).log"
fi
if ! : > "$LOG_FILE" 2>/dev/null; then
  echo "ERROR: could not create Godot log file at: $LOG_FILE" >&2
  echo "Set TB_GODOT_LOG_FILE to a writable path and retry." >&2
  exit 1
fi

if [[ "${TB_SKIP_IMPORT_CHECK:-0}" != "1" ]]; then
  find_missing_import_artifact() {
    while IFS= read -r import_file; do
      source_rel="$(awk -F'\"' '/^source_file=/{print $2; exit}' "$import_file")"
      source_rel="${source_rel#res://}"
      if [[ -n "$source_rel" && ! -f "$ROOT_DIR/$source_rel" ]]; then
        continue
      fi
      while IFS= read -r rel_path; do
        rel_path="${rel_path#res://}"
        if [[ ! -f "$ROOT_DIR/$rel_path" ]]; then
          echo "$rel_path"
          return 0
        fi
      done < <(grep -Eo 'res://\.godot/imported/[^"\]]+' "$import_file" | sort -u)
    done < <(find "$ROOT_DIR" -type f -name '*.import' | sort)
    return 1
  }

  MISSING_IMPORT_ARTIFACT="$(find_missing_import_artifact || true)"
  if [[ -n "$MISSING_IMPORT_ARTIFACT" ]]; then
    echo "Godot import cache missing artifact: $MISSING_IMPORT_ARTIFACT"
    echo "Running import pass..."
    "$GODOT_BIN" --headless --log-file "${LOG_FILE}.import" --path "$ROOT_DIR" --import
    MISSING_IMPORT_AFTER="$(find_missing_import_artifact || true)"
    if [[ -n "$MISSING_IMPORT_AFTER" ]]; then
      echo "ERROR: import cache still incomplete after import: $MISSING_IMPORT_AFTER" >&2
      exit 1
    fi
  fi
fi

if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  exec "$GODOT_BIN" --log-file "$LOG_FILE" --path "$ROOT_DIR" -- --tb-run-map "$MAP_FILE" "${EXTRA_ARGS[@]}"
else
  exec "$GODOT_BIN" --log-file "$LOG_FILE" --path "$ROOT_DIR" -- --tb-run-map "$MAP_FILE"
fi
