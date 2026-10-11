#!/usr/bin/env python3
"""Collect completed local readiness checks without granting platform/release approval."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
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
    parser.add_argument("--session", type=Path, help="Successful session receipt, if a later retained attempt was needed")
    args = parser.parse_args()
    assert os.environ.get("POKEAETHER_SLOT") == ROOT.parent.name, "Use assigned slot-env"
    run = args.run.resolve()
    run.relative_to(ROOT / ".tmp")
    target = ROOT / "data/shared_model_readiness_checks.json"
    assert not target.exists(), "Retain previously recorded evidence"
    session_path = (args.session or run / "session.json").resolve()
    session_path.relative_to(run)
    assert session_path.parent == run and session_path.suffix == ".json"
    session_name = session_path.stem
    install, consumers, session = (read(path) for path in (run / "installation.json", run / "consumers.json", session_path))
    mounts, crashes = read(args.mounts), read(args.crashes / "receipt.json")
    for proof in (install, consumers, session, mounts, crashes):
        assert proof["ok"] is True
    assert all(proof["os"] == "Linux" for proof in (install, consumers, session))
    assert session["renderer"] == "mobile"
    revision = (run / "implementation-commit.txt").read_text().strip()
    inputs = read(run / "inputs.sha256.json")
    phases = {"installation": {"qualified_source_commit": revision, "inputs": inputs.copy()}}
    for name in ("consumers", "session"):
        artifact_name = session_name if name == "session" else name
        execution = read(run / (artifact_name + ".execution.json"))
        assert execution["ok"] and execution["returncode"] == 0 and execution["inputs_unchanged"]
        frozen = read(run / (artifact_name + ".inputs.json"))
        phases[name] = {"qualified_source_commit": execution["implementation_commit"], "inputs": frozen}
        for path, digest in frozen.items():
            # Different diagnostics may be refined before they are first run.
            # Production code must stay identical across all three phases.
            assert path not in inputs or inputs[path] == digest or path.startswith("tests/")
            inputs[path] = digest
    for phase in phases.values():
        frozen_commit_check(phase)
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
    completed = {row["label"]: row for row in session["samples"] if row["label"].startswith("completed-sweep-")}
    assert set(completed) == {"completed-sweep-1", "completed-sweep-2", "completed-sweep-3"}
    warm, final = completed["completed-sweep-2"], completed["completed-sweep-3"]
    bounds = {"static_growth_bytes": final["static_bytes"] - warm["static_bytes"],
              "static_growth_limit_bytes": 16 * 1048576,
              "texture_growth_bytes": final["texture_bytes"] - warm["texture_bytes"],
              "buffer_growth_bytes": final["buffer_bytes"] - warm["buffer_bytes"],
              "gpu_growth_limit_bytes": 1048576,
              "resource_growth": final["resources"] - warm["resources"], "resource_growth_limit": 8,
              "node_growth": final["nodes"] - warm["nodes"],
              "orphan_growth": final["orphans"] - warm["orphans"],
              "mount_registry_growth_bytes": final["mount_registry_json_bytes"] - warm["mount_registry_json_bytes"]}
    assert bounds["static_growth_bytes"] <= bounds["static_growth_limit_bytes"]
    assert max(bounds["texture_growth_bytes"], bounds["buffer_growth_bytes"]) <= bounds["gpu_growth_limit_bytes"]
    assert bounds["resource_growth"] <= bounds["resource_growth_limit"]
    assert bounds["node_growth"] == bounds["orphan_growth"] == bounds["mount_registry_growth_bytes"] == 0
    assert all(row["mounts"] == row["closures"] == row["namespaces"] == 1082 for row in completed.values())
    assert not session["errors"] and not install["errors"] and not mounts["errors"]
    assert mounts["pairs"] == 1082 and mounts["repeat_mount_requests"] == 5410
    assert mounts["declared_pck_members"] == sum(len(a["pair_manifest"]["files"]) + 1 for a in pairs)
    assert consumers["bulk_available"] == 1200 and consumers["on_demand_appearances"] == 2400 and consumers["network_requests"] == 0
    assert len(crashes["records"]) == 63 and all(r["ok"] for r in crashes["records"])
    assert sum(r["point"] is not None for r in crashes["records"]) == 20
    assert len(install["records"]) == 2
    assert {record["mode"] for record in install["records"]} == {"fresh", "upgrade"}
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
    artifact_names = ["input.json", "installation.json", "installation.log", "consumers.json", "consumers.log", "consumers.execution.json"]
    artifact_names += [session_name + suffix for suffix in (".json", ".log", ".execution.json")]
    for name in ("installation.log", "consumers.log", session_name + ".log"):
        log = (run / name).read_text()
        assert "SCRIPT ERROR:" not in log and "\nERROR:" not in log, "Engine error in completed phase: " + name
    artifacts = {name: sha(run / name) for name in artifact_names}
    artifacts["mounts"] = sha(args.mounts)
    artifacts["crashes"] = sha(args.crashes / "receipt.json")
    previous_sessions = []
    for path in sorted(run.glob("session*.json")):
        if path == session_path:
            continue
        previous = read(path)
        if "qualified_pairs" not in previous or "battles" not in previous:
            continue
        related = [path.with_name(path.stem + suffix) for suffix in
                   (".json", ".log", ".execution.json", ".inputs.json")]
        previous_sessions.append({"receipt": path.name, "ok": previous["ok"],
                                  "battles": previous["battles"], "errors": previous["errors"],
                                  "artifact_sha256": {p.name: sha(p) for p in related if p.exists()}})
    collection_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    collection_tools = {"tools/" + name: sha(ROOT / "tools" / name) for name in
                        ("collect_shared_model_readiness.py", "prepare_shared_model_readiness.py", "run_shared_model_readiness_phase.py")}
    frozen_commit_check({"qualified_source_commit": collection_commit, "inputs": collection_tools})
    result = {"schema": 1, "linux_checks_passed": True, "production_approved": False,
              "native_platforms_pending": ["Windows", "macOS", "Android device"],
              "collection_source_commit": collection_commit, "collection_tools": collection_tools,
              "implementation_commit": revision, "phase_inputs": phases, "artifact_sha256": artifacts,
              "index_bytes": (ROOT / "data/model_pair_qualified.json").stat().st_size,
              "index_sha256": sha(ROOT / "data/model_pair_qualified.json"),
              "installation": install, "consumers": consumers, "independent_physical_checks": physical,
              "mounts": {k: v for k, v in mounts.items() if k != "samples"},
              "mount_samples": [mounts["samples"][0], mounts["samples"][1], *mounts["samples"][-2:]],
              "session": session, "session_bounds": bounds, "crash_invocations": 63, "injected_kills": 20}
    result["prior_session_attempts"] = previous_sessions
    target.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
    print("SHARED_MODEL_READINESS_COLLECTED", target)


if __name__ == "__main__":
    main()
