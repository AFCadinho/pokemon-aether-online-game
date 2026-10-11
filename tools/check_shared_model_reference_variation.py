#!/usr/bin/env python3
"""Diagnose strict pixel holds using 16 unchanged-source captures per appearance.

Never rerender or replace the held candidate. The original two-control verdict
is retained. Additional matches establish that its exact pixels also occur in
an unchanged, hash-pinned source, without any pixel tolerance.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import time

from PIL import Image
import audit_shared_model_catalog as audit

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "tests/shared_model_reference_repeat.gd"
RENDER = "tools/sprite_factory/shared_model_catalog_render.gd"


def read(path):
    return json.loads(path.read_bytes())


def pixels(control):
    result = {}
    for name in control["paths"]:
        path = Path(name)
        assert path.stem not in result
        with Image.open(path) as image:
            assert image.size == (512, 512) and image.mode in ("RGB", "RGBA")
            digest = hashlib.sha256(image.tobytes()).hexdigest()
        assert digest == control["frames"][path.stem]
        result[path.stem] = digest
    assert result == control["frames"]
    return result


def inspect(control_path, target, model):
    report = read(control_path)
    assert report["complete"] and report["reference_only"] and report["original_verdict_preserved"]
    assert report["script_sha256"] == audit.file_sha(ROOT / SCRIPT)
    assert report["render_script_sha256"] == audit.file_sha(ROOT / RENDER)
    assert report["renderer"] == "mobile" and report["device"]
    row = next(r for r in report["records"] if r["identity"] == model["identity"])
    assert row["source_sha256"] == model["source_sha256"] == target["source_sha256"]
    assert audit.file_sha(Path(model["source_path"])) == model["source_sha256"]
    assert len(row["controls"]) == 16
    originals = [pixels(target["source"]), pixels(target["repeat_source"])]
    candidate = pixels(target["candidate"])
    controls = []
    for control in row["controls"]:
        for key in ("camera_size", "response_schema", "animation_signature", "pose_signatures", "corrections"):
            assert control[key] == target["source"][key]
        controls.append(pixels(control))
    frames = []
    for key, digest in candidate.items():
        if digest in (originals[0][key], originals[1][key]):
            continue
        frames.append({"frame": key, "candidate_pixel_sha256": digest,
                       "matching_unchanged_controls": [i + 1 for i, c in enumerate(controls) if c[key] == digest],
                       "distinct_unchanged_pixel_hashes": len({c[key] for c in controls})})
    assert frames
    return {"identity": model["identity"], "source_sha256": model["source_sha256"],
            "candidate_sha256": target["candidate_sha256"], "original_comparison_passed": False,
            "reference_report": str(control_path), "reference_report_sha256": audit.file_sha(control_path),
            "extra_unchanged_captures": 16, "held_frames": frames,
            "all_held_frames_reproduced_by_unchanged_source": all(f["matching_unchanged_controls"] for f in frames)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--existing", type=Path, action="append", default=[])
    parser.add_argument("--follow", action="store_true", help="Observe completed batches until the full run finishes")
    args = parser.parse_args()
    if os.environ.get("POKEAETHER_SLOT") != ROOT.parent.name:
        parser.error("Use assigned slot-env")
    directory = args.run.resolve()
    output = args.output.resolve()
    for path in (directory, output):
        path.relative_to(ROOT / ".tmp")
    output.mkdir(parents=True, exist_ok=True)
    configuration = {"run_configuration_sha256": audit.file_sha(directory / "configuration.json"),
                     "script_sha256": audit.file_sha(ROOT / SCRIPT), "render_sha256": audit.file_sha(ROOT / RENDER)}
    if (output / "configuration.json").exists():
        assert read(output / "configuration.json") == configuration
    else:
        audit.write_json(output / "configuration.json", configuration)
    existing = {r["identity"]: p for p in args.existing for r in read(p)["records"]}
    results = {}
    child = None
    def interrupt(_signal, _frame):
        if child is not None:
            child.terminate()
        raise KeyboardInterrupt("Reference diagnostic interrupted")
    signal.signal(signal.SIGTERM, interrupt)
    while True:
        holds = {}
        for pointer in sorted(directory.glob("batch-*.receipt.json")):
            receipt = read(pointer)
            batch = Path(receipt["directory"])
            fixture = read(batch / "input.json")
            renders = read(batch / "render/report.json")
            for row in receipt["render"]:
                if row["pixels_exact"]:
                    continue
                assert row["identity"] not in holds
                model = next(m for m in fixture["models"] if m["identity"] == row["identity"])
                target = next(r for r in renders["records"] if r["identity"] == row["identity"])
                holds[row["identity"]] = (model, target)
        for identity, (model, target) in holds.items():
            if identity in results:
                continue
            case = output / identity
            if not case.exists():
                case.mkdir()
            report_path = existing.get(identity, case / "controls/report.json")
            if not report_path.exists():
                data = {k: model[k] for k in ("identity", "source_path", "source_sha256")}
                data.update({k: target["source"][k] for k in ("camera_size", "animation_signature", "pose_signatures", "corrections")})
                audit.write_json(case / "input.json", {"models": [data], "repeats": 16})
                environment = os.environ.copy()
                for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME"):
                    path = case / "runtime" / variable.lower()
                    path.mkdir(parents=True, exist_ok=True)
                    environment[variable] = str(path)
                with (case / "run.log").open("x") as stream:
                    child = subprocess.Popen(["godot", "--path", str(ROOT), "--rendering-method", "mobile",
                        "--resolution", "512x512", "--script", "res://" + SCRIPT, "--log-file", str(case / "engine.log"),
                        "--", str(case / "input.json"), str(case / "controls")], env=environment, stdout=stream, stderr=subprocess.STDOUT)
                    try:
                        assert child.wait(timeout=300) == 0
                    except BaseException:
                        child.terminate()
                        child.wait(timeout=10)
                        raise
                    finally:
                        child = None
                assert "ERROR" not in (case / "run.log").read_text()
            result = inspect(report_path, target, model)
            audit.write_json(case / "receipt.json", result)
            results[identity] = result
            print("REFERENCE_VARIATION", identity, "reproduced=", result["all_held_frames_reproduced_by_unchanged_source"], flush=True)
        complete = (directory / "report.json").exists()
        if complete:
            final = read(directory / "report.json")
            assert {r["identity"] for r in final["records"] if not r["pixels_exact"]} == set(results)
        audit.write_json(output / "report.json", {**configuration, "schema": 1, "complete": complete,
            "original_verdicts_preserved": True, "zero_pixel_tolerance": True,
            "records": sorted(results.values(), key=lambda r: r["identity"])})
        if complete or not args.follow:
            break
        time.sleep(5)


if __name__ == "__main__":
    main()
