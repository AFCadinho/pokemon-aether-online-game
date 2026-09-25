#!/usr/bin/env python3
"""Run isolated batch-01 stress with temporary screened admission and restore it."""
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
QUALIFICATION = ROOT / "tools/sprite_factory/catalog_production_batch_01_shiny_qualification.json"
MOTION = ROOT / ".tmp/catalog-production-01-battle-input-2026-09-25/motion-candidates.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(catalog_path: Path, output_path: Path, log_path: Path) -> None:
    qualification = json.loads(QUALIFICATION.read_text())
    qualified = {row["species"]: row for row in qualification["entries"]}
    entries = json.loads(catalog_path.read_text())
    identities = {entry["species"] + ("@shiny" if entry["variant"] == "shiny" else "")
                  for entry in entries}
    expected_identities = set(qualified) | {species + "@shiny" for species in qualified}
    if len(entries) != 28 or len(qualified) != 14 or identities != expected_identities:
        raise ValueError("incomplete batch-01 paired catalog")
    motions = json.loads(MOTION.read_text())["motion"]
    original = REGISTRY.read_bytes()
    registry = json.loads(original)
    for entry in entries:
        species = entry["species"]
        variant = entry["variant"]
        identity = species + ("@shiny" if variant == "shiny" else "")
        expected = qualified[species][variant + "_scn_sha256"]
        path = Path(entry["runtime_path"])
        if entry["runtime_sha256"] != expected or sha256(path) != expected:
            raise ValueError(f"scene changed: {identity}")
        profile = dict(motions[species])
        profile["sha256"] = expected
        placement = {"scale": profile["scale"], "yaw_degrees": profile["yaw_degrees"]}
        grounding = {**placement, "lift": profile["lift"], "sha256": expected}
        registry["models"][identity] = {"sha256": expected, "profile": identity}
        registry["profiles"][identity] = {
            "action_timing": entry["action_timing"], "placement": placement,
            "grounding": grounding, "motion": profile,
        }
    env = os.environ.copy()
    env["POKEAETHER_BATCH01_RUNTIME_CATALOG"] = str(catalog_path)
    env["POKEAETHER_BATCH01_STRESS_OUTPUT"] = str(output_path)
    command = [str(WORKSPACE / "ops/worktrees/slot-env"), "slot-b", "--", "timeout", "360s",
               "godot", "--path", str(ROOT), "--script",
               "res://tests/catalog_batch_01_candidate_stress_check.gd"]
    REGISTRY.write_text(json.dumps(registry, separators=(",", ":")))
    try:
        with log_path.open("w") as log:
            result = subprocess.run(command, cwd=WORKSPACE, env=env, stdout=log, stderr=subprocess.STDOUT)
        log_text = log_path.read_text()
        if (result.returncode or "BATCH01_STRESS_OK" not in log_text
                or "SCRIPT ERROR" in log_text or "ERROR:" in log_text):
            raise RuntimeError(f"batch-01 stress failed, exit {result.returncode}: {log_path}")
    finally:
        REGISTRY.write_bytes(original)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    run(args.catalog.resolve(), args.output.absolute(), args.log.absolute())
    print(f"Batch-01 candidate stress passed; report: {args.output.absolute()}")


if __name__ == "__main__":
    main()
