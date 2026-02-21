#!/usr/bin/env python3
"""Lightweight lint pass for TrenchBroom .map files using FGD .tres metadata."""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


COMMON_ALLOWED_KEYS = {
    "classname",
    "origin",
    "angle",
    "angles",
    "spawnflags",
    "target",
    "targetname",
    "model",
    "mapversion",
    "wad",
    "_tb_layer",
    "_tb_group",
    "_tb_name",
    "_tb_id",
    "_tb_type",
}

REFERENCE_KEYS_EXACT = {
    "target",
    "killtarget",
    "parentname",
    "next_target",
    "patrol_target",
    "target_a",
    "target_b",
}

PROFILE_MODES = {"cinematic", "balanced", "stress"}


@dataclass
class LintMessage:
    level: str
    entity_idx: int | None
    classname: str | None
    message: str


def parse_map_entities(map_path: Path) -> list[dict[str, str]]:
    entities: list[dict[str, str]] = []
    depth = 0
    props: dict[str, str] = {}

    for raw in map_path.read_text(errors="replace").splitlines():
        line = raw.strip()
        if line == "{":
            depth += 1
            if depth == 1:
                props = {}
            continue
        if line == "}":
            if depth == 1 and props.get("classname"):
                entities.append(dict(props))
            depth = max(0, depth - 1)
            continue
        if depth != 1 or not line.startswith('"'):
            continue
        m = re.match(r'^"([^"]+)"\s+"([^"]*)"$', line)
        if m:
            props[m.group(1)] = m.group(2)
    return entities


def parse_fgd_tres_definitions(fgd_root: Path) -> dict[str, set[str]]:
    project_root = fgd_root.parent.parent
    cache: dict[Path, tuple[str | None, set[str], list[Path]]] = {}

    def to_local_path(res_path: str) -> Path:
        if not res_path.startswith("res://"):
            return project_root / res_path
        return project_root / res_path.removeprefix("res://")

    def parse_tres_file(tres: Path) -> tuple[str | None, set[str], list[Path]]:
        if tres in cache:
            return cache[tres]

        classname: str | None = None
        class_props: set[str] = set()
        ext_map: dict[str, Path] = {}
        base_ids: list[str] = []
        in_props = False

        for raw in tres.read_text(errors="replace").splitlines():
            line = raw.strip()
            ext_m = re.match(
                r'^\[ext_resource\s+type="[^"]+"\s+.*path="([^"]+)"\s+id="([^"]+)"\]$',
                line,
            )
            if ext_m:
                ext_map[ext_m.group(2)] = to_local_path(ext_m.group(1))
                continue

            if line.startswith("classname = "):
                m = re.search(r'"([^"]+)"', line)
                if m:
                    classname = m.group(1)
                continue

            if line.startswith("base_classes = "):
                base_ids.extend(re.findall(r'ExtResource\("([^"]+)"\)', line))
                continue

            if line.startswith("class_properties = {"):
                in_props = True
                continue
            if in_props:
                if line == "}":
                    in_props = False
                    continue
                km = re.match(r'^"([^"]+)":', line)
                if km:
                    class_props.add(km.group(1))

        base_paths = [ext_map[b] for b in base_ids if b in ext_map]
        cache[tres] = (classname, class_props, base_paths)
        return cache[tres]

    def collect_props(tres: Path, seen: set[Path]) -> set[str]:
        if tres in seen or not tres.exists():
            return set()
        seen.add(tres)
        _cn, props, bases = parse_tres_file(tres)
        merged = set(props)
        for b in bases:
            merged |= collect_props(b, seen)
        return merged

    definitions: dict[str, set[str]] = {}
    for tres in fgd_root.rglob("*.tres"):
        classname, _props, _bases = parse_tres_file(tres)
        if not classname:
            continue
        definitions[classname] = collect_props(tres, set())
    return definitions


def collect_target_refs(entity: dict[str, str]) -> list[tuple[str, str]]:
    refs: list[tuple[str, str]] = []
    for key, value in entity.items():
        if not value:
            continue
        kl = key.lower()
        if (
            kl in REFERENCE_KEYS_EXACT
            or kl.endswith("_target")
            or kl.startswith("target_")
        ):
            refs.append((key, value.strip()))
            continue
        # Source-style event format: "target,input,param,delay,once"
        if kl.startswith("on") and "," in value:
            target = value.split(",", 1)[0].strip()
            if target:
                refs.append((key, target))
    return refs


def lint_entities(
    entities: list[dict[str, str]],
    defs: dict[str, set[str]],
) -> list[LintMessage]:
    out: list[LintMessage] = []
    target_buckets: dict[str, list[int]] = defaultdict(list)

    for idx, e in enumerate(entities, start=1):
        targetname = e.get("targetname", "").strip()
        if targetname:
            target_buckets[targetname].append(idx)

    for name, idxs in sorted(target_buckets.items()):
        if len(idxs) > 1:
            out.append(
                LintMessage(
                    "WARN",
                    None,
                    None,
                    f'duplicate targetname "{name}" on entities {idxs}',
                )
            )

    known_targets = set(target_buckets.keys())

    portal_count = 0
    mirror_count = 0
    budget_entities: list[tuple[int, dict[str, str]]] = []

    for idx, e in enumerate(entities, start=1):
        classname = e.get("classname", "").strip()
        if classname == "func_portal":
            portal_count += 1
        if classname == "func_mirror":
            mirror_count += 1
        if classname == "env_portal_budget":
            budget_entities.append((idx, e))

        if classname not in defs:
            out.append(LintMessage("WARN", idx, classname, "unknown classname in FGD"))
        else:
            allowed = defs[classname] | COMMON_ALLOWED_KEYS
            for key in sorted(e.keys()):
                if key not in allowed:
                    out.append(
                        LintMessage(
                            "WARN",
                            idx,
                            classname,
                            f'unknown key "{key}" for classname "{classname}"',
                        )
                    )

        for key, ref_target in collect_target_refs(e):
            if ref_target and ref_target not in known_targets:
                out.append(
                    LintMessage(
                        "WARN",
                        idx,
                        classname,
                        f'key "{key}" references missing targetname "{ref_target}"',
                    )
                )

    if (portal_count > 0 or mirror_count > 0) and not budget_entities:
        out.append(
            LintMessage(
                "WARN",
                None,
                None,
                "func_portal/func_mirror present but no env_portal_budget entity found",
            )
        )

    for idx, budget in budget_entities:
        profile = budget.get("profile_mode", "").strip().lower()
        if profile and profile not in PROFILE_MODES:
            out.append(
                LintMessage(
                    "WARN",
                    idx,
                    "env_portal_budget",
                    f'unknown profile_mode "{profile}" (expected cinematic|balanced|stress)',
                )
            )
        if profile == "cinematic" and (portal_count >= 8 or mirror_count >= 4):
            out.append(
                LintMessage(
                    "WARN",
                    idx,
                    "env_portal_budget",
                    "cinematic profile with high portal/mirror counts may cause frame drops",
                )
            )
        if not profile and budget.get("stress_profile", "").strip() == "":
            out.append(
                LintMessage(
                    "INFO",
                    idx,
                    "env_portal_budget",
                    "profile_mode not set; runtime default is balanced",
                )
            )
    return out


def print_report(messages: list[LintMessage], map_path: Path) -> int:
    errors = sum(1 for m in messages if m.level == "ERROR")
    warns = sum(1 for m in messages if m.level == "WARN")
    infos = sum(1 for m in messages if m.level == "INFO")

    print(f"Map lint report: {map_path}")
    print(f"Summary: {errors} error(s), {warns} warning(s), {infos} info")
    if not messages:
        print("PASS: no issues found")
        return 0

    for m in messages:
        where = ""
        if m.entity_idx is not None:
            where = f"[entity {m.entity_idx}"
            if m.classname:
                where += f" {m.classname}"
            where += "] "
        print(f"{m.level}: {where}{m.message}")
    return 1 if errors > 0 else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint TrenchBroom .map files")
    parser.add_argument("map_file", type=Path, help="Path to .map file")
    parser.add_argument(
        "--fgd-root",
        type=Path,
        default=Path("tb/fgd"),
        help="Path to FGD .tres root (default: tb/fgd)",
    )
    args = parser.parse_args()

    if not args.map_file.exists():
        print(f"ERROR: map file not found: {args.map_file}", file=sys.stderr)
        return 2
    if not args.fgd_root.exists():
        print(f"ERROR: fgd root not found: {args.fgd_root}", file=sys.stderr)
        return 2

    entities = parse_map_entities(args.map_file)
    defs = parse_fgd_tres_definitions(args.fgd_root)
    messages = lint_entities(entities, defs)
    return print_report(messages, args.map_file)


if __name__ == "__main__":
    raise SystemExit(main())
