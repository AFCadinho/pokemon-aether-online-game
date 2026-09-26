#!/usr/bin/env python3
"""Validate local batch-01 bundle and performance evidence; never approve release."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(bundle_dir: Path, stress_path: Path, log_path: Path, output: Path) -> dict:
    receipt_path = bundle_dir / "candidate-receipt.json"
    index_path = bundle_dir / "asset-index.json"
    receipt = json.loads(receipt_path.read_text())
    index = json.loads(index_path.read_text())
    stress = json.loads(stress_path.read_text())
    log = log_path.read_text()
    if (receipt.get("release_approved") is not False or receipt.get("index_sha256") != sha256(index_path)
            or index.get("catalog_revision") != "catalog-batch-01-candidate-v1"
            or len(receipt.get("bundles", [])) != 14 or len(index.get("assets", [])) != 14):
        raise ValueError("candidate bundle receipt/index is incomplete or changed")
    if (not stress.get("complete") or stress.get("screenshots_enabled") is not False
            or len(stress.get("rounds", [])) != 3 or "BATCH01_STRESS_OK" not in log
            or "SCRIPT ERROR" in log or "ERROR:" in log):
        raise ValueError("candidate stress did not finish cleanly")
    if [row["arena"] for row in stress["rounds"]] != ["classic", "stadium", "classic"]:
        raise ValueError("arena coverage is incomplete")
    for asset, pinned in zip(index["assets"], receipt["bundles"], strict=True):
        archive = bundle_dir / Path(asset["object_key"]).name
        if (asset["asset_id"] != pinned["asset_id"] or asset["sha256"] != pinned["sha256"]
                or asset["size_bytes"] != pinned["size_bytes"] or not archive.is_file()
                or archive.stat().st_size != asset["size_bytes"] or sha256(archive) != asset["sha256"]):
            raise ValueError(f"candidate archive changed: {asset['asset_id']}")
    rounds = []
    for row in stress["rounds"]:
        dispatch = max((span["ms"] for span in row["load_spans"]
                        if span["operation"] == "threaded load dispatch/collect"), default=0)
        if (row["pairs"] != 14 or row["faint_replacements"] != 14
                or not 0 < row["frame_p95_ms"] <= 20 or dispatch > 1000 / 60
                or row["retained_source_bytes"] > 64 * 1024 * 1024
                or any(stall["ms"] > 100 and not stall["covered"] for stall in row["stalls_over_50ms"])):
            raise ValueError(f"candidate performance/lifecycle hold in {row['arena']}")
        rounds.append({"arena": row["arena"], "pairs": row["pairs"],
                       "frame_p95_ms": row["frame_p95_ms"], "frame_max_ms": row["frame_max_ms"],
                       "load_callback_max_ms": dispatch,
                       "retained_source_bytes": row["retained_source_bytes"],
                       "uncovered_hitches_over_100ms": 0})
    growth = stress["rounds"][2]["static_bytes"] - stress["rounds"][1]["static_bytes"]
    if growth >= 1024 * 1024:
        raise ValueError("repeated battle static memory growth exceeded 1 MiB")
    result = {
        "schema": 1, "date": "2026-09-25", "status": "local_candidate_bundle_preflight_passed",
        "runtime_approved": False, "release_approved": False,
        "bundle_count": 14, "appearance_count": 28,
        "bundle_bytes": sum(asset["size_bytes"] for asset in index["assets"]),
        "index_bytes": index_path.stat().st_size,
        "index_sha256": sha256(index_path),
        "rounds": rounds, "final_two_round_static_growth_bytes": growth,
        "evidence_sha256": {"candidate_receipt": sha256(receipt_path),
                            "stress_report": sha256(stress_path), "stress_log": sha256(log_path)},
        "open": ["Full moving visual review and final per-species release approval.",
                 "Launcher release admission still pins only the existing seven approved species."],
    }
    output.write_text(json.dumps(result, indent=2) + "\n")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("bundles", "stress", "log", "output"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    result = close(args.bundles, args.stress, args.log, args.output)
    print(f"Local candidate preflight passed: {result['bundle_count']} bundles, {result['bundle_bytes']} bytes")


if __name__ == "__main__":
    main()
