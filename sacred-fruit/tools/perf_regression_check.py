#!/usr/bin/env python3
"""Run portal stress bench, emit CSV, and report baseline diff for CI."""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


RESULT_RE = re.compile(r"Portal stress:\s*result=(\{.*\})")


def _find_godot() -> str:
    candidates = [
        "godot",
        "/Applications/Godot.app/Contents/MacOS/Godot",
        str(Path.home() / "Applications/Godot.app/Contents/MacOS/Godot"),
    ]
    for candidate in candidates:
        if candidate == "godot":
            if subprocess.run(["which", "godot"], capture_output=True).returncode == 0:
                return "godot"
            continue
        if Path(candidate).exists():
            return candidate
    raise FileNotFoundError("Godot executable not found")


def _run_bench(root: Path, godot_bin: str, args: argparse.Namespace) -> tuple[dict[str, Any], str]:
    cmd = [
        godot_bin,
        "--no-window",
        "--headless",
        "--path",
        str(root),
        "--script",
        "res://tools/portal_stress_bench.gd",
        "--",
        f"--pairs={args.pairs}",
        f"--seconds={args.seconds}",
        f"--warmup={args.warmup}",
        f"--scale={args.scale}",
        f"--keep-hot={'true' if args.keep_hot else 'false'}",
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    output = (proc.stdout or "") + ("\n" + proc.stderr if proc.stderr else "")
    if proc.returncode != 0:
        raise RuntimeError(f"portal bench failed with exit={proc.returncode}\n{output}")

    matches = RESULT_RE.findall(output)
    if not matches:
        raise RuntimeError(f"could not parse portal bench result JSON\n{output}")
    result = json.loads(matches[-1])
    if not isinstance(result, dict):
        raise RuntimeError("parsed portal bench result is not an object")
    return result, output


def _write_csv(path: Path, row: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "timestamp_unix",
        "pairs",
        "portals",
        "render_scale",
        "keep_hot",
        "samples",
        "avg_fps",
        "p95_ms",
        "p99_ms",
        "max_ms",
    ]
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerow({k: row.get(k, "") for k in fieldnames})


def _read_first_row(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    with path.open(newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            return dict(row)
    return None


def _to_float(row: dict[str, Any], key: str) -> float:
    return float(row.get(key, 0.0))


def _format_pct(delta: float) -> str:
    sign = "+" if delta >= 0 else ""
    return f"{sign}{delta:.2f}%"


def _build_summary(
    baseline: dict[str, Any] | None,
    current: dict[str, Any],
    enforce: bool,
    fps_drop_pct: float,
    p95_rise_pct: float,
    p99_rise_pct: float,
) -> tuple[str, bool]:
    lines: list[str] = []
    lines.append("# Portal Perf Report")
    lines.append("")
    lines.append("## Current")
    lines.append(
        "- pairs={pairs}, scale={render_scale}, keep_hot={keep_hot}, avg_fps={avg_fps:.3f}, p95_ms={p95_ms:.3f}, p99_ms={p99_ms:.3f}, max_ms={max_ms:.3f}".format(
            **current
        )
    )
    lines.append("")

    if baseline is None:
        lines.append("## Baseline")
        lines.append("- No baseline CSV found; diff skipped.")
        return "\n".join(lines) + "\n", True

    b_avg_fps = _to_float(baseline, "avg_fps")
    b_p95 = _to_float(baseline, "p95_ms")
    b_p99 = _to_float(baseline, "p99_ms")
    c_avg_fps = float(current["avg_fps"])
    c_p95 = float(current["p95_ms"])
    c_p99 = float(current["p99_ms"])

    fps_delta_pct = 0.0 if b_avg_fps <= 0 else ((c_avg_fps - b_avg_fps) / b_avg_fps) * 100.0
    p95_delta_pct = 0.0 if b_p95 <= 0 else ((c_p95 - b_p95) / b_p95) * 100.0
    p99_delta_pct = 0.0 if b_p99 <= 0 else ((c_p99 - b_p99) / b_p99) * 100.0

    lines.append("## Baseline Diff")
    lines.append(f"- baseline avg_fps={b_avg_fps:.3f}, p95_ms={b_p95:.3f}, p99_ms={b_p99:.3f}")
    lines.append(f"- avg_fps delta: {_format_pct(fps_delta_pct)}")
    lines.append(f"- p95_ms delta: {_format_pct(p95_delta_pct)}")
    lines.append(f"- p99_ms delta: {_format_pct(p99_delta_pct)}")
    lines.append("")

    pass_check = True
    reasons: list[str] = []
    if fps_delta_pct < -abs(fps_drop_pct):
        pass_check = False
        reasons.append(f"avg_fps dropped more than {abs(fps_drop_pct):.2f}%")
    if p95_delta_pct > abs(p95_rise_pct):
        pass_check = False
        reasons.append(f"p95_ms increased more than {abs(p95_rise_pct):.2f}%")
    if p99_delta_pct > abs(p99_rise_pct):
        pass_check = False
        reasons.append(f"p99_ms increased more than {abs(p99_rise_pct):.2f}%")

    lines.append("## Threshold Check")
    lines.append(
        f"- enforce={'true' if enforce else 'false'}, allowed_fps_drop={abs(fps_drop_pct):.2f}%, allowed_p95_rise={abs(p95_rise_pct):.2f}%, allowed_p99_rise={abs(p99_rise_pct):.2f}%"
    )
    if pass_check:
        lines.append("- status=PASS")
    else:
        lines.append("- status=FAIL")
        for reason in reasons:
            lines.append(f"- reason={reason}")

    return "\n".join(lines) + "\n", (pass_check or not enforce)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pairs", type=int, default=16)
    parser.add_argument("--seconds", type=float, default=8.0)
    parser.add_argument("--warmup", type=float, default=2.0)
    parser.add_argument("--scale", type=float, default=0.5)
    parser.add_argument("--keep-hot", action="store_true", default=True)
    parser.add_argument("--godot-bin", default="")
    parser.add_argument("--output-csv", default="artifacts/perf/portal_stress_current.csv")
    parser.add_argument("--summary-md", default="artifacts/perf/portal_stress_report.md")
    parser.add_argument("--raw-log", default="artifacts/perf/portal_stress_raw.log")
    parser.add_argument("--baseline-csv", default="tests/perf_baselines/portal_stress_baseline.csv")
    parser.add_argument("--enforce", action="store_true", default=False)
    parser.add_argument("--fps-drop-pct", type=float, default=20.0)
    parser.add_argument("--p95-rise-pct", type=float, default=25.0)
    parser.add_argument("--p99-rise-pct", type=float, default=25.0)
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    os.chdir(root)

    try:
        godot_bin = args.godot_bin or _find_godot()
        result, raw_output = _run_bench(root, godot_bin, args)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    current_row: dict[str, Any] = {
        "timestamp_unix": int(time.time()),
        "pairs": int(result.get("pairs", args.pairs)),
        "portals": int(result.get("portals", args.pairs * 2)),
        "render_scale": float(result.get("render_scale", args.scale)),
        "keep_hot": bool(result.get("keep_hot", args.keep_hot)),
        "samples": int(result.get("samples", 0)),
        "avg_fps": float(result.get("avg_fps", 0.0)),
        "p95_ms": float(result.get("p95_ms", 0.0)),
        "p99_ms": float(result.get("p99_ms", 0.0)),
        "max_ms": float(result.get("max_ms", 0.0)),
    }

    output_csv = Path(args.output_csv)
    summary_md = Path(args.summary_md)
    raw_log = Path(args.raw_log)
    baseline_csv = Path(args.baseline_csv)

    _write_csv(output_csv, current_row)
    raw_log.parent.mkdir(parents=True, exist_ok=True)
    raw_log.write_text(raw_output)

    baseline = _read_first_row(baseline_csv)
    summary_text, ok = _build_summary(
        baseline=baseline,
        current=current_row,
        enforce=args.enforce,
        fps_drop_pct=args.fps_drop_pct,
        p95_rise_pct=args.p95_rise_pct,
        p99_rise_pct=args.p99_rise_pct,
    )
    summary_md.parent.mkdir(parents=True, exist_ok=True)
    summary_md.write_text(summary_text)
    print(summary_text.strip())

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
