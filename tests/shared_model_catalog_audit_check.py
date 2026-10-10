#!/usr/bin/env python3
"""Independently reconcile full-catalog evidence and optional retained packs."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import audit_shared_model_catalog as audit


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def reconcile(report, index, bindings):
    assert report["complete"] and report["full_catalog"]
    assert report["prototype_only"] and not report["production_approved"]
    assert report["pairs"] and len(report["pairs"]) == len(index["assets"])
    assert report["source_assets_byte_verified"] == len(index["assets"])
    assert len({row["asset_id"] for row in report["pairs"]}) == len(index["assets"])
    totals = {key: 0 for key in report["totals"]}
    selected = eligible = measured = graphs = 0
    for source, row in zip(index["assets"], report["pairs"], strict=True):
        assert row["asset_id"] == source["asset_id"]
        assert row["source_archive_sha256"] == source["sha256"]
        assert row["source_download_bytes"] == source["size_bytes"]
        assert row["source_installed_bytes"] > sum(bindings[a["runtime_identity"]]["candidate_bytes"] for a in source["appearances"])
        assert len(row["models"]) == 2
        for appearance, model in zip(source["appearances"], row["models"], strict=True):
            binding = bindings[appearance["runtime_identity"]]
            assert model["identity"] == appearance["runtime_identity"]
            assert model["variant"] == appearance["variant"]
            assert model["sha256"] == appearance["runtime_sha256"] == binding["candidate_sha256"]
            assert model["bytes"] == binding["candidate_bytes"]
            assert model["decoded_sha256"] == binding["decoded_sha256"]
            assert model["cache_source_bytes"] == binding["cache_source_bytes"]
            assert model["source_container"] in ("RSRC", "RSCC")
            assert model["codec_control_method"] == ("serialize-rsrc-first" if model["source_container"] == "RSRC" else "reframe-original-rscc")
        checks = row["physical_checks"]
        if "shared_pck_bytes" in row:
            measured += 1
            assert set(checks) == {"codec_control", "serializer_control", "shared"}
            assert row["eligible"] == all(check["ok"] for check in checks.values())
            for model in row["models"]:
                assert len(model["semantic_sha256"]) == len(model["candidate_sha256"]) == 64
            for kind, check in checks.items():
                if check["ok"]:
                    assert check["error"] == "" and check["scenes_exact"] == 2
                    graphs += 2
                    if kind == "shared":
                        assert check["sidecar_bytes"] > 0
                        assert check["installed_bytes"] == row["shared_pck_bytes"] + check["sidecar_bytes"] == row["shared_installed_bytes"]
                else:
                    assert check["error"]
        else:
            assert row["needs_review"] and not checks and not row["eligible"]
        should_select = row["eligible"] and row["shared_pck_bytes"] < row["source_download_bytes"] and row["shared_installed_bytes"] < row["source_installed_bytes"]
        assert row["selected"] == should_select
        eligible += row["eligible"]
        selected += row["selected"]
        for key in totals:
            if key == "selected_download_bytes":
                totals[key] += row["shared_pck_bytes"] if should_select else row["source_download_bytes"]
            elif key == "selected_installed_bytes":
                totals[key] += row["shared_installed_bytes"] if should_select else row["source_installed_bytes"]
            else:
                totals[key] += row.get(key, 0)
    assert report["totals"] == totals
    assert report["physically_qualified_pairs"] == eligible
    assert report["selected_pairs"] == selected
    assert report["measured_candidate_pairs"] == measured
    assert report["native_graph_checks"] == graphs
    return selected


def rejection_checks(report, index, bindings):
    # These faults would overstate savings or admit unqualified native data.
    changed = copy.deepcopy(report)
    changed["totals"]["selected_installed_bytes"] -= 1
    expect_rejection(lambda: reconcile(changed, index, bindings))
    changed = copy.deepcopy(report)
    changed["pairs"][1] = changed["pairs"][0]
    expect_rejection(lambda: reconcile(changed, index, bindings))
    changed = copy.deepcopy(report)
    exact = next(row for row in changed["pairs"] if row["eligible"])
    exact["physical_checks"]["shared"]["scenes_exact"] = 1
    expect_rejection(lambda: reconcile(changed, index, bindings))
    changed = copy.deepcopy(report)
    fallback = next(row for row in changed["pairs"] if not row["selected"])
    fallback["selected"] = True
    expect_rejection(lambda: reconcile(changed, index, bindings))


def expect_rejection(callback):
    try:
        callback()
    except (AssertionError, ValueError):
        return
    raise AssertionError("Invalid evidence/checkpoint was accepted")


def checkpoint_checks():
    # Resume must reject changed sources and retained candidates, even when
    # the earlier JSON receipt claims successful physical qualification.
    (ROOT / ".tmp").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="catalog-check-", dir=ROOT / ".tmp") as name:
        directory = Path(name)
        source = directory / "source.zip"
        source.write_bytes(b"approved-source-fixture")
        asset = {"asset_id": "fixture", "object_key": source.name, "sha256": digest(source), "size_bytes": source.stat().st_size}
        pack = directory / "packs" / "fixture.pck"
        pack.parent.mkdir()
        pack.write_bytes(b"retained-pack-fixture")
        candidate = {"asset_id": "fixture", "object_key": pack.name, "sha256": digest(pack), "size_bytes": pack.stat().st_size}
        metadata = directory / "candidate-assets/0/asset.json"
        metadata.parent.mkdir(parents=True)
        metadata.write_text(json.dumps(candidate))
        row = {"asset_id": "fixture", "source_archive_sha256": asset["sha256"], "source_download_bytes": asset["size_bytes"],
               "shared_pack_sha256": candidate["sha256"], "shared_pck_bytes": candidate["size_bytes"], "eligible": True}
        def checked(rows=None):
            return audit.checkpoints(rows or [row], [asset], directory, {source.name: source})
        assert len(checked()) == 1
        expect_rejection(lambda: checked([row, row]))
        source.write_bytes(b"changed-source-fixture!")
        expect_rejection(checked)
        source.write_bytes(b"approved-source-fixture")
        pack.write_bytes(b"modified-pack-fixture")
        expect_rejection(checked)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--audit", type=Path, help="Retained complete audit directory; also hash every retained pack and draft entry")
    args = parser.parse_args()
    evidence = args.audit / "report.json" if args.audit else ROOT / "tools/sprite_factory/shared_model_catalog_results.json"
    report = json.loads(evidence.read_bytes())
    index = json.loads((ROOT / "release/approved_3d_bundles_v11_index.json").read_bytes())
    bindings = json.loads((ROOT / "release/approved_3d_lossless_binding.json").read_bytes())["models"]
    selected = reconcile(report, index, bindings)
    rejection_checks(report, index, bindings)
    checkpoint_checks()
    for path, expected in report["source_sha256"].items():
        assert digest(ROOT / path) == expected, "Frozen proof source changed: " + path
    if args.audit:
        assert digest(args.audit / "receipts.jsonl") == report["receipts_sha256"]
        draft = json.loads((args.audit / "draft-index.json").read_bytes())
        assert draft["prototype_only"] and not draft["production_approved"]
        assert len(draft["assets"]) == len(index["assets"])
        for position, (original, row) in enumerate(zip(index["assets"], report["pairs"], strict=True)):
            if row["eligible"]:
                candidate = json.loads((args.audit / "candidate-assets" / str(position) / "asset.json").read_bytes())
                pack = args.audit / "packs" / Path(candidate["object_key"]).name
                assert pack.stat().st_size == row["shared_pck_bytes"]
                assert digest(pack) == row["shared_pack_sha256"] == candidate["sha256"]
                assert all(a["cache_source_bytes"] == m["cache_source_bytes"] for a, m in zip(candidate["appearances"], row["models"], strict=True))
            else:
                candidate = None
            assert draft["assets"][position] == (candidate if row["selected"] else original)
    print(f"SHARED_MODEL_CATALOG_AUDIT_CHECK_OK pairs={len(report['pairs'])} selected={selected} graphs={report['native_graph_checks']} rejection_cases=7 retained={args.audit is not None}")


if __name__ == "__main__":
    main()
