#!/usr/bin/env python3
"""Reconcile catalog render/actor evidence; optionally inspect retained PNGs/packs."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def frozen_commit_check(report):
    """Verify historical evidence against its tested commit, not later changes."""
    revision = report["qualified_source_commit"]
    assert re.fullmatch(r"[0-9a-f]{40}", revision)
    subprocess.run(["git", "merge-base", "--is-ancestor", revision, "HEAD"], cwd=ROOT, check=True)
    files = {**report["inputs"], **report.get("evidence_tools", {})}
    with subprocess.Popen(["git", "cat-file", "--batch"], cwd=ROOT,
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE) as process:
        try:
            for name, digest in files.items():
                assert "\n" not in name and not Path(name).is_absolute() and ".." not in Path(name).parts
                process.stdin.write((revision + ":" + name + "\n").encode())
                process.stdin.flush()
                header = process.stdout.readline().split()
                assert len(header) == 3 and header[1] == b"blob", "Missing frozen file: " + name
                data = process.stdout.read(int(header[2]))
                assert process.stdout.read(1) == b"\n"
                assert hashlib.sha256(data).hexdigest() == digest, "Tested commit differs: " + name
        finally:
            process.stdin.close()
        assert process.wait() == 0


def frame_keys(keys):
    required = {view + "-" + pose for view in ("front", "back")
                for pose in ("idle", "physical_attack", "special_attack", "sleep")}
    assert required <= keys
    faint = {"front-faint_loop", "back-faint_loop"}
    if not faint <= keys:
        faint = {"front-faint_start", "back-faint_start"}
    assert faint <= keys
    allowed = required | faint | {view + "-" + action for view in ("front", "back")
                                 for action in ("physical_attack_2", "special_attack_2")}
    assert keys <= allowed and len(keys) in (10, 12, 14)


def reconcile(report, catalog):
    assert report["complete"] and report["full_selected_catalog"]
    assert report["prototype_only"] and not report["production_approved"]
    expected = {a["runtime_identity"]: a for asset in catalog["assets"]
                if asset.get("format") == "model-pair-pck-v1" for a in asset["appearances"]}
    rows = report["records"]
    assert len(rows) == report["appearances"] == len(expected) == 2168
    assert {r["identity"] for r in rows} == set(expected)
    count = 0
    for row in rows:
        binding = expected[row["identity"]]
        assert row["source_sha256"] == binding["source_sha256"]
        assert row["candidate_sha256"] == binding["runtime_sha256"]
        assert row["animation_and_pose_exact"]
        frames = row["frames"]
        keys = {f["frame"] for f in frames}
        assert len(keys) == len(frames)
        frame_keys(keys)
        assert all(type(f[k]) is bool for f in frames for k in ("first_exact", "repeat_exact", "control_exact"))
        assert row["pixels_exact"] == all(f["first_exact"] or f["repeat_exact"] for f in frames)
        count += len(frames)
    assert count == report["candidate_frames"]
    assert report["pixels_exact"] == all(r["pixels_exact"] for r in rows)
    return rows


def retained_check(directory, report, catalog):
    expected = {a["asset_id"]: a for a in catalog["assets"] if a.get("format") == "model-pair-pck-v1"}
    received = {}
    images = pairs = battles = previews = 0
    for pointer in sorted(directory.glob("batch-*.receipt.json")):
        receipt = read(pointer)
        batch = Path(receipt["directory"]).resolve()
        batch.relative_to(directory.resolve())
        assert read(batch / "receipt.json") == receipt
        assert sha(batch / "actors.json") == receipt["actor_receipt_sha256"]
        actors = read(batch / "actors.json")
        fixture = read(batch / "input.json")
        assert actors["complete"] and actors["pairs"] == fixture["pairs"]
        assert actors["renderer"] == "mobile" and actors["device"]
        assert actors["battles"] == 2 * len(fixture["pairs"])
        assert actors["previews"] == 8 * len(fixture["pairs"])
        assert len(actors["records"]) == len(fixture["pairs"])
        assert all(r["actual_actor_states_exact"] and r["battle_pose_samples"] >= 30 for r in actors["records"])
        assert [p["asset"]["asset_id"] for p in fixture["packs"]] == receipt["assets"]
        for pin in fixture["packs"]:
            asset = pin["asset"]
            assert asset == expected.pop(asset["asset_id"])
            path = Path(pin["path"])
            assert path.stat().st_size == asset["size_bytes"] and sha(path) == asset["sha256"]
        for model in fixture["models"]:
            path = Path(model["source_path"])
            assert path.stat().st_size == model["source_bytes"] and sha(path) == model["source_sha256"]
        rendered = read(batch / "render/report.json")
        assert rendered["complete"] and len(rendered["records"]) == len(fixture["models"])
        assert {r["identity"] for r in rendered["records"]} == {m["identity"] for m in fixture["models"]}
        compact = {r["identity"]: r for r in receipt["render"]}
        for row in rendered["records"]:
            assert row["identity"] not in received
            summary = compact[row["identity"]]
            assert row["source_sha256"] == summary["source_sha256"] and row["candidate_sha256"] == summary["candidate_sha256"]
            controls = [row[k] for k in ("source", "repeat_source", "candidate")]
            for field in ("camera_size", "response_schema", "animation_signature", "pose_signatures", "corrections"):
                assert all(c[field] == controls[0][field] for c in controls)
            keys = set(controls[0]["frames"])
            frame_keys(keys)
            assert set(controls[0]["pose_signatures"]) == keys
            pixels = []
            for control in controls:
                files = {Path(p).stem: Path(p).resolve() for p in control["paths"]}
                assert set(files) == keys == set(control["frames"])
                pixel_set = {}
                for key, path in files.items():
                    path.relative_to(batch)
                    with Image.open(path) as image:
                        assert image.size == (512, 512) and image.mode in ("RGB", "RGBA")
                        digest = hashlib.sha256(image.tobytes()).hexdigest()
                    assert digest == control["frames"][key]
                    pixel_set[key] = digest
                    images += 1
                pixels.append(pixel_set)
            for frame in summary["frames"]:
                key = frame["frame"]
                assert frame["first_exact"] == (pixels[2][key] == pixels[0][key])
                assert frame["repeat_exact"] == (pixels[2][key] == pixels[1][key])
                assert frame["control_exact"] == (pixels[0][key] == pixels[1][key])
            received[row["identity"]] = summary
        pairs += len(fixture["pairs"])
        battles += actors["battles"]
        previews += actors["previews"]
    assert not expected and pairs == 1084
    assert list(sorted(received.values(), key=lambda r: r["identity"])) == report["records"]
    assert images == report["candidate_frames"] * 3
    return {"pngs": images, "pairs": pairs, "battles": battles, "previews": previews}


def reference_reconciliation(report):
    extras = {r["identity"]: r for r in report.get("reference_variation", [])}
    assert len(extras) == len(report.get("reference_variation", []))
    held = {r["identity"]: r for r in report["records"] if not r["pixels_exact"]}
    assert set(extras) == set(held)
    accepted = {r["identity"] for r in report["records"] if r["pixels_exact"]}
    for identity, extra in extras.items():
        primary = held[identity]
        assert extra["source_sha256"] == primary["source_sha256"]
        assert extra["candidate_sha256"] == primary["candidate_sha256"]
        assert not extra["original_comparison_passed"] and extra["extra_unchanged_captures"] == 16
        expected = {f["frame"] for f in primary["frames"] if not f["first_exact"] and not f["repeat_exact"]}
        assert {f["frame"] for f in extra["held_frames"]} == expected
        for frame in extra["held_frames"]:
            matches = frame["matching_unchanged_controls"]
            assert len(matches) == len(set(matches)) and all(type(i) is int and 1 <= i <= 16 for i in matches)
        reproduced = all(f["matching_unchanged_controls"] for f in extra["held_frames"])
        assert bool(reproduced) == extra["all_held_frames_reproduced_by_unchanged_source"]
        if reproduced:
            accepted.add(identity)
    assert report["qualified_appearances"] == len(accepted)
    pairs = {identity.removesuffix("@shiny") for identity in accepted}
    assert report["qualified_pairs"] == sum(identity in accepted and identity + "@shiny" in accepted for identity in pairs)
    return accepted


def selection_summary(report, catalog, storage):
    """A shared pack needs both appearances; unresolved pairs retain v11."""
    accepted = reference_reconciliation(report)
    selected = [a["asset_id"] for a in catalog["assets"]
                if a.get("format") == "model-pair-pck-v1"
                and all(m["runtime_identity"] in accepted for m in a["appearances"])]
    assert len(selected) == report["qualified_pairs"]
    additional_original = [a["asset_id"] for a in catalog["assets"]
                           if a.get("format") == "model-pair-pck-v1" and a["asset_id"] not in selected]
    proofs = storage["pairs"]
    assert [a["asset_id"] for a in catalog["assets"]] == [p["asset_id"] for p in proofs]
    totals = {"shared_pairs": len(selected), "original_pairs": len(proofs) - len(selected),
              "shared_asset_ids": selected, "additional_original_pair_ids": additional_original}
    for measure, candidate in (("download", "shared_pck_bytes"), ("installed", "shared_installed_bytes")):
        source = sum(p["source_" + measure + "_bytes"] for p in proofs)
        result = sum(p[candidate] if p["asset_id"] in selected else p["source_" + measure + "_bytes"] for p in proofs)
        totals["source_" + measure + "_bytes"] = source
        totals["selected_" + measure + "_bytes"] = result
        totals["saved_" + measure + "_bytes"] = source - result
    return totals


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, help="Also inspect all retained PNGs, physical packs, sources and actor receipts")
    args = parser.parse_args()
    path = args.run / "report.json" if args.run else ROOT / "tools/shared_model_qualification_results.json"
    report = read(path)
    rows = reconcile(report, read(ROOT / "data/model_pair_catalog.json"))
    if "reference_variation" in report:
        reference_reconciliation(report)
    bound = report
    if args.run and (ROOT / "tools/shared_model_qualification_results.json").exists():
        committed = read(ROOT / "tools/shared_model_qualification_results.json")
        assert committed["run_report_sha256"] == sha(path)
        assert committed["inputs"] == report["inputs"]
        bound = committed
        for name, digest in committed["artifact_sha256"].items():
            artifact = (args.run / name).resolve()
            artifact.relative_to(args.run.resolve())
            assert sha(artifact) == digest, "Retained evidence changed: " + name
    if "qualified_source_commit" in bound:
        frozen_commit_check(bound)
    else:
        for name, digest in report["inputs"].items():
            assert sha(ROOT / name) == digest, "Frozen evidence input changed: " + name
    if "selection" in bound:
        catalog = read(ROOT / "data/model_pair_catalog.json")
        assert bound["selection"] == selection_summary(bound, catalog, read(ROOT / "tools/sprite_factory/shared_model_catalog_results.json"))
        if args.run:
            draft = read(args.run / "qualified-index.json")
            originals = {a["asset_id"]: a for a in read(ROOT / "release/approved_3d_bundles_v11_index.json")["assets"]}
            assert draft["prototype_only"] and not draft["production_approved"]
            assert draft["qualification_run_sha256"] == bound["run_report_sha256"]
            assert draft["assets"] == [a if a["asset_id"] in bound["selection"]["shared_asset_ids"] else originals[a["asset_id"]] for a in catalog["assets"]]
    physical = retained_check(args.run, report, read(ROOT / "data/model_pair_catalog.json")) if args.run else {}
    print("SHARED_MODEL_QUALIFICATION_EVIDENCE_CHECK_OK", "appearances=" + str(len(rows)),
          "frames=" + str(report["candidate_frames"]), "holds=" + str(sum(not r["pixels_exact"] for r in rows)), physical)


if __name__ == "__main__":
    main()
