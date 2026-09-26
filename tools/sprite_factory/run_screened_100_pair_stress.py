#!/usr/bin/env python3
"""Exercise selected screened normal/shiny pairs in the real battle presenter.

The screened registry is amended only for this isolated run and restored byte for
byte. This tool does not approve, package or publish any model.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT.parents[2]
REGISTRY = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
PRODUCTION = ROOT / "tools/sprite_factory/screened_100_shiny_production_results.json"
NORMAL = ROOT / ".tmp/physical-attack-runtime-models-74/report.json"
SHINY_REPORTS = [ROOT / f".tmp/screened-100-shiny-runtime-{index:02d}/report.json" for index in (1, 2, 3)]


def sha256(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def sources(names: list[str]) -> tuple[dict, dict, dict]:
    production = {row["species"]: row for row in json.loads(PRODUCTION.read_text())["entries"]
                  if row["status"] == "technical_candidate"}
    normals = {row["species"]: row for row in json.loads(NORMAL.read_text())}
    shinies = {row["species"].removesuffix("@shiny"): row for report in SHINY_REPORTS
               for row in json.loads(report.read_text())}
    if len(production) != 61 or not set(names) <= set(production):
        raise ValueError("species outside the 61 paired candidates")
    for name in names:
        for variant, row in (("normal", normals[name]), ("shiny", shinies[name])):
            expected = production[name][variant + "_scn_sha256"]
            if row["runtime_sha256"] != expected or sha256(Path(row["runtime_path"])) != expected:
                raise ValueError(f"changed candidate scene: {name} {variant}")
    return production, normals, shinies


def run(profile_path: Path, names: list[str], catalog_path: Path, report_path: Path,
        log_path: Path) -> None:
    if not names or len(names) != len(set(names)) or any(not name for name in names):
        raise ValueError("nonempty unique species required")
    if any(path.exists() for path in (catalog_path, report_path, log_path)):
        raise ValueError("stress outputs must be new")
    profiles = json.loads(profile_path.read_text())
    if profiles.get("motion_holds") and set(names) & set(profiles["motion_holds"]):
        raise ValueError("held motion candidate requested")
    production, normals, shinies = sources(names)
    original = REGISTRY.read_bytes()
    registry = json.loads(original)
    catalog = []
    for name in names:
        motion = dict(profiles["motion"][name])
        if motion["sha256"] != production[name]["normal_glb_sha256"]:
            raise ValueError(f"changed motion source: {name}")
        placement = {"scale": motion["scale"], "yaw_degrees": motion["yaw_degrees"]}
        grounding = {**placement, "lift": motion["lift"]}
        for variant, row in (("normal", normals[name]), ("shiny", shinies[name])):
            identity = name + ("@shiny" if variant == "shiny" else "")
            expected = production[name][variant + "_scn_sha256"]
            if variant == "normal" and registry["models"][name]["sha256"] != expected:
                raise ValueError(f"screened normal hash changed: {name}")
            registry["models"][identity] = {"sha256": expected, "profile": name}
            catalog.append({"species": name, "variant": variant, "runtime_schema": 1,
                            "runtime_path": row["runtime_path"], "runtime_sha256": expected,
                            "action_timing": row["action_timing"]})
        registry["profiles"][name] = {
            "action_timing": normals[name]["action_timing"],
            "attack_family_actions": registry["profiles"][name].get("attack_family_actions", {}),
            "placement": placement,
            "grounding": {**grounding, "sha256": production[name]["normal_scn_sha256"]},
            "motion": {**motion, "sha256": production[name]["normal_scn_sha256"]},
        }
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(json.dumps(catalog, indent=2) + "\n")
    env = os.environ.copy()
    env.update({"POKEAETHER_BATCH01_RUNTIME_CATALOG": str(catalog_path.resolve()),
                "POKEAETHER_BATCH01_STRESS_OUTPUT": str(report_path.resolve()),
                "POKEAETHER_BATCH01_STRESS_NAMES": ",".join(names)})
    command = [str(WORKSPACE / "ops/worktrees/slot-env"), "slot-b", "--", "timeout", "600s",
               "godot", "--path", str(ROOT), "--script",
               "res://tests/catalog_batch_01_candidate_stress_check.gd"]
    REGISTRY.write_text(json.dumps(registry, separators=(",", ":")))
    try:
        with log_path.open("w") as log:
            result = subprocess.run(command, cwd=WORKSPACE, env=env, stdout=log, stderr=subprocess.STDOUT)
        log = log_path.read_text()
        if (result.returncode or "BATCH01_STRESS_OK" not in log
                or "SCRIPT ERROR" in log or "ERROR:" in log):
            raise RuntimeError(f"candidate stress failed: {log_path}")
    finally:
        REGISTRY.write_bytes(original)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profiles", type=Path)
    parser.add_argument("species", help="comma-separated exact species IDs")
    parser.add_argument("catalog", type=Path)
    parser.add_argument("report", type=Path)
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    names = args.species.split(",")
    run(args.profiles.resolve(), names, args.catalog.absolute(), args.report.absolute(), args.log.absolute())
    print(f"Battle stress passed for {len(names)} pairs: {args.report}")


if __name__ == "__main__":
    main()
