#!/usr/bin/env python3
"""Collect completed local readiness checks without granting platform/release approval."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from shared_model_qualification_evidence_check import frozen_commit_check


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", type=Path, required=True)
    parser.add_argument("--mounts", type=Path, required=True)
    parser.add_argument("--crashes", type=Path, required=True)
    args = parser.parse_args()
    assert os.environ.get("POKEAETHER_SLOT") == ROOT.parent.name, "Use assigned slot-env"
    run = args.run.resolve()
    run.relative_to(ROOT / ".tmp")
    target = ROOT / "data/shared_model_readiness_checks.json"
    assert not target.exists(), "Retain previously recorded evidence"
    install, consumers, session = (read(run / name) for name in ("installation.json", "consumers.json", "session.json"))
    mounts, crashes = read(args.mounts), read(args.crashes / "receipt.json")
    for proof in (install, consumers, session, mounts, crashes):
        assert proof["ok"] is True
    revision = (run / "implementation-commit.txt").read_text().strip()
    inputs = read(run / "inputs.sha256.json")
    for name in ("consumers", "session"):
        execution = read(run / (name + ".execution.json"))
        assert execution["ok"] and execution["returncode"] == 0 and execution["inputs_unchanged"]
        for path, digest in read(run / (name + ".inputs.json")).items():
            assert path not in inputs or inputs[path] == digest
            inputs[path] = digest
    frozen_commit_check({"qualified_source_commit": revision, "inputs": inputs})
    for path, digest in inputs.items():
        assert sha(ROOT / path) == digest, "Source changed after qualification: " + path
    wire = read(ROOT / "data/model_pair_qualified.json")
    catalog = read(ROOT / "data/model_pair_catalog.json")
    source = read(ROOT / "release/approved_3d_bundles_v11_index.json")
    by_id = {a["asset_id"]: a for a in catalog["assets"]}
    originals = {a["asset_id"]: a for a in source["assets"]}
    qualified = {a["asset_id"]: by_id[a["asset_id"]] if a.get("format") == "model-pair-ref-v1" else a for a in wire["assets"]}
    pairs = [a for a in qualified.values() if a.get("format") == "model-pair-pck-v1"]
    identities = {a["appearances"][0]["runtime_identity"] for a in pairs}
    assert len(pairs) == 1082 and len(qualified) == 1200
    assert len(session["qualified_pairs"]) == len(set(session["qualified_pairs"])) == 1082
    assert set(session["qualified_pairs"]) == identities
    assert len(session["repeated_pairs"]) == len(set(session["repeated_pairs"])) == 128
    assert set(session["repeated_pairs"]) <= identities
    assert (session["battles"], session["previews"], session["canceled"]) == (1338, 5352, 3)
    assert not session["errors"] and not install["errors"] and not mounts["errors"]
    assert mounts["pairs"] == 1082 and mounts["repeat_mount_requests"] == 5410
    assert mounts["declared_pck_members"] == sum(len(a["pair_manifest"]["files"]) + 1 for a in pairs)
    assert consumers["bulk_available"] == 1200 and consumers["on_demand_appearances"] == 2400 and consumers["network_requests"] == 0
    assert len(crashes["records"]) == 63 and all(r["ok"] for r in crashes["records"])
    assert sum(r["point"] is not None for r in crashes["records"]) == 20
    assert len(install["records"]) == 2
    physical = []
    for record in install["records"]:
        mode = record["mode"]
        assert mode in ("fresh", "upgrade")
        assert record["assets"] == 1200 and record["appearances"] == 2400
        assert record["downloads"] == (1200 if mode == "fresh" else 1082)
        assert record["cleanup"]["removed_objects"] == (0 if mode == "fresh" else 1082)
        path = Path(record["catalog"])
        path.relative_to(run / mode / "store")
        assert sha(path) == record["catalog_sha256"]
        state_path = path.parent / "installed-state.json"
        assert sha(state_path) == record["generation"] == path.parent.name
        assert state_path.stat().st_size == record["state_bytes"] <= 8 * 1024 * 1024
        assert path.stat().st_size == record["catalog_bytes"] <= 8 * 1024 * 1024
        state = read(state_path)
        assert set(state["assets"]) == set(qualified)
        object_root = run / mode / "store/objects"
        assert {p.name for p in object_root.iterdir()} == {a["sha256"] for a in qualified.values()}
        size, checked = 0, 0
        for key, asset in qualified.items():
            installed = state["assets"][key]
            assert installed["archive_sha256"] == asset["sha256"]
            directory = object_root / asset["sha256"]
            manifest = read(directory / "bundle.json")
            if asset.get("format") == "model-pair-pck-v1":
                assert manifest == asset
                assert installed["pair_ref"] == {"asset_id": key, "sha256": asset["sha256"]}
                assert sha(directory / "model-pair.pck") == asset["sha256"]
                checked += 1
            else:
                assert asset == originals[key] and "pair_ref" not in installed
                for row in manifest["appearances"]:
                    assert sha(directory / row["runtime_path"]) == row["runtime_sha256"]
                    checked += 1
            for member in directory.rglob("*"):
                assert not member.is_symlink()
                if member.is_file():
                    size += member.stat().st_size
        physical.append({"mode": mode, "independently_hashed_payloads": checked, "installed_object_bytes": size})
        if mode == "fresh":
            assert consumers["catalog_sha256"] == session["catalog_sha256"] == record["catalog_sha256"]
    artifacts = {name: sha(run / name) for name in ("input.json", "installation.json", "installation.log", "consumers.json", "consumers.log", "consumers.execution.json", "session.json", "session.log", "session.execution.json")}
    artifacts["mounts"] = sha(args.mounts)
    artifacts["crashes"] = sha(args.crashes / "receipt.json")
    result = {"schema": 1, "linux_checks_passed": True, "production_approved": False,
              "native_platforms_pending": ["Windows", "macOS", "Android device"],
              "implementation_commit": revision, "inputs": inputs, "artifact_sha256": artifacts,
              "index_bytes": (ROOT / "data/model_pair_qualified.json").stat().st_size,
              "index_sha256": sha(ROOT / "data/model_pair_qualified.json"),
              "installation": install, "consumers": consumers, "independent_physical_checks": physical,
              "mounts": {k: v for k, v in mounts.items() if k != "samples"},
              "mount_samples": [mounts["samples"][0], mounts["samples"][1], *mounts["samples"][-2:]],
              "session": session, "crash_invocations": 63, "injected_kills": 20}
    target.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
    print("SHARED_MODEL_READINESS_COLLECTED", target)


if __name__ == "__main__":
    main()
