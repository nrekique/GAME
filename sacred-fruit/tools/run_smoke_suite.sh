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
declare -a MAP_LIST=()
declare -a MAP_ARGS=()
if [[ -n "${SMOKE_MAPS:-}" ]]; then
  IFS=',' read -r -a MAPS <<< "${SMOKE_MAPS}"
  for map in "${MAPS[@]}"; do
    trimmed="$(echo "$map" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    [[ -n "$trimmed" ]] && MAP_LIST+=("$trimmed")
  done
else
  MAP_LIST+=("res://tb/maps/fgd test.map")
fi

resolve_map_for_lint() {
  local raw="$1"
  local map="${raw%\"}"
  map="${map#\"}"
  if [[ "$map" == res://* ]]; then
    echo "$ROOT_DIR/${map#res://}"
    return 0
  fi
  if [[ "$map" == tb/* ]]; then
    echo "$ROOT_DIR/$map"
    return 0
  fi
  if [[ "$map" == /tb/* ]]; then
    echo "$ROOT_DIR$map"
    return 0
  fi
  if [[ "$map" == ./* ]]; then
    map="${map#./}"
  fi
  if [[ "$map" == /* ]]; then
    echo "$map"
    return 0
  fi
  if [[ -f "$ROOT_DIR/$map" ]]; then
    echo "$ROOT_DIR/$map"
    return 0
  fi
  if [[ -f "$ROOT_DIR/tb/maps/$map" ]]; then
    echo "$ROOT_DIR/tb/maps/$map"
    return 0
  fi
  if [[ -f "$ROOT_DIR/tb/$map" ]]; then
    echo "$ROOT_DIR/tb/$map"
    return 0
  fi
  echo ""
}

for map in "${MAP_LIST[@]}"; do
  lint_map="$(resolve_map_for_lint "$map")"
  if [[ -z "$lint_map" || ! -f "$lint_map" ]]; then
    echo "[smoke] ERROR: map not found for lint: ${map}" >&2
    exit 1
  fi
  echo "[smoke] linting map ${lint_map}"
  "$ROOT_DIR/tools/tb_lint_map.sh" "$lint_map"
  MAP_ARGS+=("--map=${map}")
done

echo "[smoke] running map build smoke (${#MAP_ARGS[@]} map args, timeout=${MAP_TIMEOUT}s)"
"$GODOT_BIN" --no-window --headless --path "$ROOT_DIR" --script res://tools/map_build_smoke.gd -- "${MAP_ARGS[@]}" "--timeout=${MAP_TIMEOUT}"

echo "[smoke] PASS"
