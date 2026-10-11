#!/usr/bin/env python3
"""Prove exact comparison rejects a new pixel, forged hash and missing frame."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import subprocess
import tempfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from qualify_shared_model_catalog import compare
from shared_model_qualification_evidence_check import frame_keys, frozen_commit_check, sha, selection_summary


def rejected(callback):
    try:
        callback()
    except AssertionError:
        return
    raise AssertionError("Invalid comparison evidence accepted")


def main():
    historical = {"qualified_source_commit": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "inputs": {"project.godot": sha(ROOT / "project.godot")}}
    frozen_commit_check(historical)
    invalid_history = copy.deepcopy(historical)
    invalid_history["inputs"]["project.godot"] = "0" * 64
    rejected(lambda: frozen_commit_check(invalid_history))
    # One held shiny appearance must retain BOTH original models in that pack.
    selection_report = {"qualified_appearances": 3, "qualified_pairs": 1, "records": [
        {"identity": identity, "pixels_exact": identity != "held@shiny", "source_sha256": "source",
         "candidate_sha256": "candidate", "frames": [{"frame": "front-idle", "first_exact": identity != "held@shiny", "repeat_exact": False}]}
        for identity in ("held", "held@shiny", "exact", "exact@shiny")],
        "reference_variation": [{"identity": "held@shiny", "source_sha256": "source", "candidate_sha256": "candidate",
            "original_comparison_passed": False, "extra_unchanged_captures": 16,
            "held_frames": [{"frame": "front-idle", "matching_unchanged_controls": []}],
            "all_held_frames_reproduced_by_unchanged_source": False}]}
    selection_catalog = {"assets": [{"asset_id": identity, "format": "model-pair-pck-v1",
        "appearances": [{"runtime_identity": identity}, {"runtime_identity": identity + "@shiny"}]}
        for identity in ("held", "exact")] + [{"asset_id": "legacy"}]}
    selection_storage = {"pairs": [{"asset_id": identity, "source_download_bytes": 100,
        "source_installed_bytes": 200, "shared_pck_bytes": 50, "shared_installed_bytes": 150}
        for identity in ("held", "exact", "legacy")]}
    selected = selection_summary(selection_report, selection_catalog, selection_storage)
    assert selected["shared_asset_ids"] == ["exact"] and selected["additional_original_pair_ids"] == ["held"]
    assert selected["original_pairs"] == 2 and selected["selected_download_bytes"] == 250 and selected["selected_installed_bytes"] == 550
    # Exact source evidence can qualify the pack, without changing any pixels.
    selection_report["reference_variation"][0]["held_frames"][0]["matching_unchanged_controls"] = [1]
    selection_report["reference_variation"][0]["all_held_frames_reproduced_by_unchanged_source"] = True
    selection_report.update(qualified_appearances=4, qualified_pairs=2)
    selected = selection_summary(selection_report, selection_catalog, selection_storage)
    assert selected["shared_asset_ids"] == ["held", "exact"] and selected["original_pairs"] == 1
    assert selected["selected_download_bytes"] == 200 and selected["selected_installed_bytes"] == 500
    with tempfile.TemporaryDirectory(prefix="pixel-proof-", dir=ROOT / ".tmp") as name:
        directory = Path(name)
        keys = [v + "-" + a for v in ("front", "back") for a in
                ("idle", "physical_attack", "special_attack", "sleep", "faint_loop")]
        frame_keys(set(keys))
        rejected(lambda: frame_keys(set(keys[1:] + ["front-invented"])) )
        row = {"identity": "fixture", "source_sha256": "a" * 64, "candidate_sha256": "b" * 64}
        for role in ("source", "repeat_source", "candidate"):
            control = {"frames": {}, "paths": [], "camera_size": 5.5, "response_schema": 1,
                       "animation_signature": "c" * 64, "pose_signatures": {k: "d" * 64 for k in keys},
                       "corrections": {"flight": False}}
            target = directory / role
            target.mkdir()
            for key in keys:
                image = Image.new("RGBA", (512, 512), (50, 100, 150, 255))
                path = target / (key + ".png")
                image.save(path)
                control["paths"].append(str(path))
                control["frames"][key] = hashlib.sha256(image.tobytes()).hexdigest()
            row[role] = control
        report = {"complete": True, "renderer": "mobile", "device": "fixture", "records": [row]}
        def evaluate(value=report):
            (directory / "report.json").write_text(json.dumps(value))
            return compare(directory)
        assert evaluate()[0]["pixels_exact"]
        def pixel(role, red, update_hash=True):
            path = directory / role / (keys[0] + ".png")
            image = Image.open(path).copy()
            image.putpixel((256, 256), (red, 100, 150, 255))
            image.save(path)
            if update_hash:
                row[role]["frames"][keys[0]] = hashlib.sha256(image.tobytes()).hexdigest()
        pixel("candidate", 51)
        assert not evaluate()[0]["pixels_exact"], "One changed channel in one pixel cannot pass by tolerance"
        pixel("repeat_source", 51)
        result = evaluate()[0]
        assert result["pixels_exact"] and any(not f["first_exact"] and f["repeat_exact"] for f in result["frames"])
        pixel("candidate", 52, update_hash=False)
        rejected(evaluate)
        pixel("candidate", 51)
        invalid = copy.deepcopy(report)
        for role in ("source", "repeat_source", "candidate"):
            invalid["records"][0][role]["frames"].pop(keys[0])
        rejected(lambda: evaluate(invalid))
        invalid = copy.deepcopy(report)
        invalid["records"][0]["candidate"]["pose_signatures"][keys[0]] = "changed"
        rejected(lambda: evaluate(invalid))
    print("SHARED_MODEL_QUALIFICATION_COMPARATOR_CHECK_OK exact_repeat=true zero_tolerance=true hash_frame_pose_faults_rejected=true whole_pair_fallback=true")


if __name__ == "__main__":
    main()
