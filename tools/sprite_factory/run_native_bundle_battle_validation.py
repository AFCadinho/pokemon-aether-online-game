#!/usr/bin/env python3
"""Use the existing three-round battle gate on launcher-installed native fixtures.

Only the assigned task checkout's registry is temporarily replaced with generated
future-release model hashes. Restore its exact source bytes in finally. Normal
checkouts, publication files, caches and player userdata are untouched. Run this
command through slot-env with other games/previews closed.
"""
import argparse
import hashlib
import json
import os
import resource
from pathlib import Path
import subprocess


def digest(data):
    return hashlib.sha256(data).hexdigest()


def restore_registry(path, generated, original):
    if path.read_bytes() != generated:
        raise ValueError("Registry changed concurrently; preserve it for review")
    path.write_bytes(original)
    if path.read_bytes() != original:
        raise ValueError("Registry restoration did not preserve its original bytes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture", type=Path)
    parser.add_argument("installation", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--phase", choices=["original", "native-256k", "native-1m"], required=True)
    args = parser.parse_args()
    frontend = Path(__file__).resolve().parents[2]
    if frontend.parent.name not in ["slot-a", "slot-b", "slot-c"] or frontend.name != "frontend":
        raise ValueError("Battle qualification requires an assigned task checkout")
    output = args.output.resolve()
    output.relative_to(frontend / ".tmp")
    output.mkdir(parents=True, exist_ok=False)
    fixture = json.loads(args.fixture.read_text())
    stage = next(s for s in fixture["stages"] if s["label"] == args.phase)
    registry_path = frontend / "scripts/battle/battle_ui/reviewed_model_catalog.json"
    before = registry_path.read_bytes()
    registry = json.loads(before)
    registry["models"].update(stage["models"])
    generated = (json.dumps(registry) + "\n").encode()
    catalog = args.installation.resolve() / (args.phase + "-catalog.json")
    rows = json.loads(catalog.read_text())
    if {e["runtime_sha256"] for e in rows} != {m["sha256"] for m in stage["models"].values()}:
        raise ValueError("Installed catalog does not match selected fixture")
    names = [a["appearances"][0]["runtime_identity"] for a in json.loads(Path(stage["index_path"]).read_text())["assets"]]
    env = os.environ.copy()
    env.update(POKEAETHER_FORM_BUNDLE_WORK=str(Path(stage["index_path"]).parent),
        POKEAETHER_BATCH01_RUNTIME_CATALOG=str(catalog),
        POKEAETHER_BATCH01_STRESS_NAMES=",".join(names),
        POKEAETHER_BATCH01_STRESS_OUTPUT=str(output / "battle-report.json"))
    receipt = {"prototype_only": True, "production_approved": False, "complete": False,
        "phase": args.phase, "pairs": len(names), "fixture_sha256": digest(args.fixture.read_bytes()),
        "source_registry_sha256": digest(before), "future_registry_sha256": digest(generated),
        "script_sha256": digest(Path(__file__).read_bytes())}
    try:
        registry_path.write_bytes(generated)
        with (output / "battle.log").open("w") as log:
            result = subprocess.run([os.environ.get("GODOT_BIN", "godot"), "--path", str(frontend),
                "--script", "res://tests/battle_3d_regional_stress_check.gd"], env=env,
                stdout=log, stderr=subprocess.STDOUT, timeout=360)
        receipt["exit_code"] = result.returncode
        receipt["peak_child_rss_bytes"] = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss * 1024
        log = (output / "battle.log").read_text()
        if result.returncode != 0 or "SCRIPT ERROR:" in log or "\nERROR:" in log:
            raise ValueError("Real battle check failed; inspect retained battle.log")
        report = json.loads((output / "battle-report.json").read_text())
        if not report["complete"] or len(report["rounds"]) != 3 or report["window_size"] != [1280, 720]:
            raise ValueError("Battle check did not complete at the required viewport")
        for row in report["rounds"]:
            if row["pairs"] != len(names) or not 0 < row["frame_p95_ms"] <= 20:
                raise ValueError("Unchanged 20 ms frame gate failed")
        for row in report["steady_frame_p95_ms"].values():
            if row["samples"] < len(names) * 240 or not 0 < row["p95_ms"] <= 20:
                raise ValueError("Unchanged prepared observation gate failed")
        receipt["performance_gate_passed"] = True
        receipt["complete"] = True
        print("NATIVE_REAL_BATTLE_GATE_OK", args.phase, len(names), "pairs", flush=True)
    except Exception as error:
        receipt["failure"] = str(error)
        raise
    finally:
        try:
            restore_registry(registry_path, generated, before)
        except Exception:
            # Do not overwrite an unexpected concurrent edit.
            receipt["registry_restored"] = False
            (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
            raise
        receipt["registry_restored"] = digest(registry_path.read_bytes()) == digest(before)
        (output / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")


if __name__ == "__main__":
    main()
