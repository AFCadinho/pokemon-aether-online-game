#!/usr/bin/env python3
"""Exercise exact installed batch-04 main pairs in three real battle rounds."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = ROOT.parents[2]
WORK = ROOT / ".tmp/batch04-main"
REGISTRY = ROOT / "scripts/battle/battle_ui/screened_model_catalog.json"
DECISION = ROOT / "tools/sprite_factory/catalog_production_batch_04_main_candidate_bundles_v2.json"
CATALOG = WORK / "candidate-catalog-v2.json"
OUTPUT = WORK / "battle-stress-full-v2"


def read(path: Path):
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def selections():
    decision = read(DECISION)
    assert len(decision["entries"]) == 200
    names = [entry["species"] for entry in decision["entries"]]
    assert len(set(names)) == 200
    selected = {entry["species"]: entry for entry in decision["entries"]}
    catalog = {(row["species"], row["variant"]): row for row in read(CATALOG)["entries"]}
    assert len(catalog) == 400
    for name in names:
        for variant in ("normal", "shiny"):
            row = catalog[name, variant]
            assert row["runtime_sha256"] == selected[name][variant + "_scn_sha256"]
            assert digest(Path(row["runtime_path"])) == row["runtime_sha256"]
    return names, selected, catalog


def profiles(selected):
    review = read(ROOT / "tools/sprite_factory/catalog_production_batch_04_main_review.json")
    placements = {}
    battle_reviews = {
        "attention-review-10", "paradox-battle-review-11", "recovery-battle-review-13",
        "recovery-battle-review-25", "clean-battle-review-30", "recovery-battle-review-44",
        "recovery-battle-review-52", "remaining-battle-76",
    }
    for evidence in review["evidence"]:
        name = evidence["review"]
        if name not in battle_reviews:
            continue
        receipt = read(WORK / name / "receipt.json")
        for row in receipt["entries"]:
            placements[row["species"]] = row["placement"]
    updated = read(WORK / "final-battle-requalification/candidates.json")["motion"]
    for name, entry in selected.items():
        if not entry["normal_scene_matches_battle_accepted_scene"]:
            placements[name] = updated[name]
    assert set(placements) == set(selected)
    for name, placement in placements.items():
        assert placement["sha256"] == selected[name]["normal_glb_sha256"], name
    return placements


def action_timings(selected):
    found = {}
    for path in WORK.rglob("runtime.json"):
        try:
            rows = read(path)
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(rows, list):
            continue
        for row in rows:
            if not isinstance(row, dict):
                continue
            name = row.get("species", "").removesuffix("@shiny")
            entry = selected.get(name)
            if entry and row.get("glb_sha256") == entry["normal_glb_sha256"] and row.get("action_timing"):
                found[name] = row["action_timing"]
    for path in WORK.rglob("report.json"):
        if "/runtime/" not in str(path) and "-runtime/" not in str(path):
            continue
        try:
            rows = read(path)
        except (OSError, json.JSONDecodeError):
            continue
        if not isinstance(rows, list):
            continue
        for row in rows:
            if not isinstance(row, dict):
                continue
            name = row.get("species", "").removesuffix("@shiny")
            entry = selected.get(name)
            if entry and row.get("glb_sha256") == entry["normal_glb_sha256"] and row.get("action_timing"):
                found[name] = row["action_timing"]
    assert set(found) == set(selected), sorted(set(selected) - set(found))
    return found


def runtime_catalog(selected):
    rows = {(row["species"], row["variant"]): row for row in read(CATALOG)["entries"]}
    assert len(rows) == 400
    for row in rows.values():
        assert digest(Path(row["runtime_path"])) == row["runtime_sha256"]
    return rows


def main():
    names, selected, _ = selections()
    placement = profiles(selected)
    timing = action_timings(selected)
    installed = runtime_catalog(selected)
    original = REGISTRY.read_bytes()
    OUTPUT.mkdir(exist_ok=True)
    try:
        for number, start in enumerate(range(0, len(names), 8), 1):
            group = names[start:start + 8]
            out = OUTPUT / f"group-{number:02d}"
            out.mkdir(exist_ok=True)
            catalog_path, report_path, log_path = (out / "catalog.json", out / "stress.json", out / "godot.log")
            if report_path.exists():
                report = read(report_path)
                assert report["complete"] and report["species"] == group and len(report["rounds"]) == 3
                print("STRESS RESUME", number, group, flush=True)
                continue
            registry = json.loads(original)
            catalog = []
            for name in group:
                profile = placement[name]
                pose = {"scale": profile["scale"], "yaw_degrees": profile["yaw_degrees"]}
                for variant in ("normal", "shiny"):
                    row = installed[name, variant]
                    identity = name + ("@shiny" if variant == "shiny" else "")
                    scene_hash = selected[name][variant + "_scn_sha256"]
                    assert row["runtime_sha256"] == scene_hash
                    registry["models"][identity] = {"sha256": scene_hash, "profile": identity}
                    registry["profiles"][identity] = {
                        "action_timing": timing[name], "placement": pose,
                        "grounding": {**pose, "lift": profile["lift"], "sha256": scene_hash},
                        "motion": {**profile, "sha256": scene_hash},
                    }
                    catalog.append({"species": name, "variant": variant, "runtime_schema": 1,
                                    "runtime_path": row["runtime_path"], "runtime_sha256": scene_hash,
                                    "action_timing": timing[name]})
            catalog_path.write_text(json.dumps(catalog, indent=2) + "\n")
            env = os.environ.copy()
            env.update({"POKEAETHER_BATCH01_RUNTIME_CATALOG": str(catalog_path),
                        "POKEAETHER_BATCH01_STRESS_OUTPUT": str(report_path),
                        "POKEAETHER_BATCH01_STRESS_NAMES": ",".join(group)})
            command = [str(WORKSPACE / "ops/worktrees/slot-env"), "slot-a", "--", "timeout", "900s",
                       "godot", "--path", str(ROOT), "--script",
                       "res://tests/catalog_batch_01_candidate_stress_check.gd"]
            REGISTRY.write_text(json.dumps(registry, separators=(",", ":")))
            print("STRESS START", number, group, flush=True)
            with log_path.open("w") as log:
                status = subprocess.run(command, cwd=WORKSPACE, env=env, stdout=log, stderr=subprocess.STDOUT).returncode
            REGISTRY.write_bytes(original)
            output = log_path.read_text()
            if status or "BATCH01_STRESS_OK" not in output or "SCRIPT ERROR" in output or "ERROR:" in output:
                raise RuntimeError(f"Battle stress failed group {number}: status={status} log={log_path}")
            report = read(report_path)
            assert report["complete"] and report["catalog_sha256"] == digest(catalog_path)
            assert report["species"] == group and len(report["rounds"]) == 3
            assert all(round_["pairs"] == len(group) and round_["faint_replacements"] == len(group)
                       for round_ in report["rounds"])
            print("STRESS OK", number, [(r["arena"], r["pairs"], round(r["frame_p95_ms"], 2))
                                        for r in report["rounds"]], flush=True)
    finally:
        REGISTRY.write_bytes(original)


if __name__ == "__main__":
    main()
