#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -lt 1 ]]; then
  echo "Usage: tb_run_map.sh <mapfile> [play|photo|spectator]" >&2
  exit 2
fi

MODE="play"
if [[ $# -ge 2 ]]; then
  LAST_ARG="${@: -1}"
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
    if [[ -f "$ROOT_DIR/tb/maps/$MAP_FILE" ]]; then
      LINT_MAP_FILE="$ROOT_DIR/tb/maps/$MAP_FILE"
    elif [[ -f "$ROOT_DIR/tb/$MAP_FILE" ]]; then
      LINT_MAP_FILE="$ROOT_DIR/tb/$MAP_FILE"
    elif [[ -f "$ROOT_DIR/$MAP_FILE" ]]; then
      LINT_MAP_FILE="$ROOT_DIR/$MAP_FILE"
    else
      # Search subdirectories of tb/maps/ for the filename
      FOUND_MAP="$(find "$ROOT_DIR/tb/maps" -name "$(basename "$MAP_FILE")" -type f 2>/dev/null | head -1)"
      if [[ -n "$FOUND_MAP" ]]; then
        LINT_MAP_FILE="$FOUND_MAP"
      fi
    fi
  fi
  if [[ -f "$LINT_MAP_FILE" ]]; then
    echo "Linting map: $LINT_MAP_FILE"
    "$ROOT_DIR/tools/tb_lint_map.sh" "$LINT_MAP_FILE"
  else
    echo "WARN: map lint skipped (file not found for lint preflight): $MAP_FILE" >&2
  fi
fi

GODOT_APP=""
if [[ "$(uname -s)" == "Darwin" ]]; then
  if [[ -d "/Applications/Godot.app" ]]; then
    GODOT_APP="/Applications/Godot.app"
  elif [[ -d "$HOME/Applications/Godot.app" ]]; then
    GODOT_APP="$HOME/Applications/Godot.app"
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

USER_DATA_DIR="${TB_GODOT_USER_DATA_DIR:-$ROOT_DIR/.godot/userdata}"
if ! mkdir -p "$USER_DATA_DIR" 2>/dev/null; then
  USER_DATA_DIR="$ROOT_DIR/.godot"
fi

maybe_clear_stale_godot_script_cache() {
  local cache_cfg="$ROOT_DIR/.godot/global_script_class_cache.cfg"
  [[ -f "$cache_cfg" ]] || return 0

  local stale=0
  while IFS= read -r script_path; do
    script_path="${script_path#res://}"
    if [[ ! -f "$ROOT_DIR/$script_path" ]]; then
      stale=1
      break
    fi
  done < <(grep -Eo '"path": "res://[^"]+\.gd"' "$cache_cfg" | sed -E 's/^"path": "(res:\/\/[^"]+)"$/\1/')

  if [[ "$stale" -eq 1 ]]; then
    echo "Detected stale Godot script cache (moved/deleted script paths)."
    rm -f \
      "$ROOT_DIR/.godot/global_script_class_cache.cfg" \
      "$ROOT_DIR/.godot/uid_cache.bin" \
      "$ROOT_DIR/.godot/editor/filesystem_cache10" \
      "$ROOT_DIR/.godot/editor/script_editor_cache.cfg"
  fi
}

if [[ "${TB_SKIP_CACHE_REFRESH:-0}" != "1" ]]; then
  maybe_clear_stale_godot_script_cache
fi

# Import-cache audit is expensive and can crash certain macOS bash launchers
# (notably when run from TrenchBroom) due heavy fork/exec pressure.
# Keep this opt-in for manual diagnostics.
if [[ "${TB_ENABLE_IMPORT_CHECK:-0}" == "1" ]]; then
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

GODOT_ARGS=(--user-data-dir "$USER_DATA_DIR" --log-file "$LOG_FILE" --path "$ROOT_DIR" -- --tb-run-map "$MAP_FILE")
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  GODOT_ARGS+=("${EXTRA_ARGS[@]}")
fi

# macOS 26 + Godot 4.6 can abort in NSApp startup when launching the raw Mach-O
# directly from terminal tools. Launching the .app bundle via `open` avoids that path.
if [[ "$(uname -s)" == "Darwin" && "${TB_FORCE_DIRECT_GODOT_BIN:-0}" != "1" ]]; then
  if [[ -n "$GODOT_APP" ]]; then
    if open -n -a "$GODOT_APP" --args "${GODOT_ARGS[@]}"; then
      exit 0
    fi
    echo "WARN: failed to launch via macOS app bundle; falling back to direct binary." >&2
  elif [[ "$GODOT_BIN" == */Godot.app/Contents/MacOS/Godot ]]; then
    GODOT_APP="${GODOT_BIN%/Contents/MacOS/Godot}"
    if open -n -a "$GODOT_APP" --args "${GODOT_ARGS[@]}"; then
      exit 0
    fi
    echo "WARN: failed to launch via macOS app bundle; falling back to direct binary." >&2
  fi
fi

exec "$GODOT_BIN" "${GODOT_ARGS[@]}"
