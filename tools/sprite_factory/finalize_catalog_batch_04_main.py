#!/usr/bin/env python3
"""Record local approval only after all 200 exact pairs pass every gate."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / ".tmp/batch04-main"
HERE = Path(__file__).resolve().parent
OUTPUT = HERE / "catalog_production_batch_04_main_approval.json"


def read(path: Path):
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> None:
    if OUTPUT.exists():
        raise ValueError("approval receipt already exists")
    candidate_path = HERE / "catalog_production_batch_04_main_candidate_bundles_v2.json"
    candidate = read(candidate_path)
    names = [row["species"] for row in candidate["entries"]]
    if len(names) != len(set(names)) or len(names) != 200:
        raise ValueError("candidate set is incomplete")
    visual = WORK / "final-appearance-review-v2/user-feedback.json"
    review_receipt = WORK / "final-appearance-review-v2/receipt.json"
    feedback = read(visual)
    if feedback.get("visual_review") != "accepted" or feedback.get("receipt_sha256") != digest(review_receipt):
        raise ValueError("normal/shiny review is incomplete")
    evidence = [
        candidate_path,
        HERE / "catalog_production_batch_04_main_review.json",
        WORK / "candidate-reconciliation-v2.json",
        WORK / "candidate-catalog-v2.json",
        WORK / "candidate-bundles-v2/asset-index.json",
        review_receipt,
        visual,
    ]
    for number in range(1, 26):
        folder = WORK / f"battle-stress-full-v2/group-{number:02d}"
        report_path = folder / "stress.json"
        log_path = folder / "godot.log"
        report = read(report_path)
        log = log_path.read_text()
        if (report.get("complete") is not True or len(report.get("rounds", [])) != 3
                or report.get("species") != names[(number - 1) * 8:number * 8]
                or "BATCH01_STRESS_OK" not in log or "SCRIPT ERROR" in log or "ERROR:" in log
                or any(round_["pairs"] != 8 or round_["faint_replacements"] != 8
                       or round_["frame_p95_ms"] > 25.0
                       or any(stall["ms"] > 400.0 and not stall["covered"]
                              for stall in round_["stalls_over_50ms"])
                       for round_ in report["rounds"])):
            raise ValueError("real battle gate failed: " + str(folder))
        evidence.extend([report_path, log_path])
    index_path = WORK / "candidate-bundles-v2/asset-index.json"
    index = read(index_path)
    if (len(index["assets"]) != 200 or candidate["bundle_index_sha256"] != digest(index_path)
            or {asset["species_id"] for asset in index["assets"]} != set(names)):
        raise ValueError("bundle index is incomplete")
    installation_log = WORK / "candidate-install-individual-v2.log"
    install_text = installation_log.read_text()
    if ("CATALOG_BATCH_04_MAIN_INDIVIDUAL_BUNDLES_OK bundles=200 scenes=400" not in install_text
            or install_text.count("BUNDLE_OK ") != 200 or "SCRIPT ERROR" in install_text
            or "ERROR:" in install_text):
        raise ValueError("launcher install/load/no-op/restart gate is incomplete")
    evidence.append(installation_log)
    installed_path = WORK / "candidate-install-individual-v2/installed-catalog.json"
    if len(read(installed_path)) != 400:
        raise ValueError("launcher installed catalog is incomplete")
    evidence.append(installed_path)
    receipt = {
        "schema": 1, "date": "2026-09-28",
        "scope": "200 batch-04 main normal/shiny pairs, exact visual review, real battle rounds and individual launcher bundles",
        "status": "local_release_content_approved", "runtime_approved": True,
        "release_approved": True, "published": False,
        "approved_species": names, "appearance_count": 400, "bundle_count": 200,
        "bundle_bytes": candidate["bundle_bytes"], "bundle_index_sha256": digest(index_path),
        "installed_catalog_sha256": digest(installed_path), "battle_rounds": 75,
        "evidence_sha256": {str(path.relative_to(ROOT)): digest(path) for path in evidence},
        "remaining": ["Release certification and publication are separate."],
    }
    OUTPUT.write_text(json.dumps(receipt, indent=2) + "\n")
    print("BATCH04_MAIN_LOCAL_APPROVAL pairs=200 scenes=400 rounds=75")


if __name__ == "__main__":
    main()
