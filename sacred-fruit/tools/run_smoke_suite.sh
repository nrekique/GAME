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

run_test_script() {
  local script_path="$1"
  echo "[smoke] running ${script_path}"
  "$GODOT_BIN" --no-window --headless --path "$ROOT_DIR" --script "$script_path"
}

run_test_script "res://tests/util_test.gd"
run_test_script "res://tests/io_test.gd"
run_test_script "res://tests/profile_test.gd"
run_test_script "res://tests/volume_test.gd"
run_test_script "res://tests/ai_authoring_test.gd"
run_test_script "res://tests/perf_budget_test.gd"
run_test_script "res://tests/dialogue_integration_test.gd"
run_test_script "res://tools/portal_pair_smoke_test.gd"

MAP_TIMEOUT="${SMOKE_MAP_TIMEOUT_SECONDS:-45}"
declare -a MAP_ARGS=()
if [[ -n "${SMOKE_MAPS:-}" ]]; then
  IFS=',' read -r -a MAPS <<< "${SMOKE_MAPS}"
  for map in "${MAPS[@]}"; do
    trimmed="$(echo "$map" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -n "$trimmed" ]] && MAP_ARGS+=("--map=${trimmed}")
  done
else
  MAP_ARGS+=("--map=res://tb/maps/fgd test.map")
fi

echo "[smoke] running map build smoke (${#MAP_ARGS[@]} map args, timeout=${MAP_TIMEOUT}s)"
"$GODOT_BIN" --no-window --headless --path "$ROOT_DIR" --script res://tools/map_build_smoke.gd -- "${MAP_ARGS[@]}" "--timeout=${MAP_TIMEOUT}"

echo "[smoke] PASS"
