#!/usr/bin/env python3
"""Reconcile batch-04 bundle pairs with the exact visually accepted battle scenes."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / ".tmp/batch04-main"
HERE = Path(__file__).resolve().parent
PREVIOUS = HERE / "catalog_production_batch_04_main_candidate_bundles.json"
REVIEW = HERE / "catalog_production_batch_04_main_review.json"
CATALOG = WORK / "candidate-catalog-v2.json"
AUDIT = WORK / "candidate-reconciliation-v2.json"


def read(path: Path):
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def main() -> None:
    previous = read(PREVIOUS)
    reviewed = {row["species"]: row for row in read(REVIEW)["entries"]}
    original = {(row["species"], row["variant"]): row for row in read(WORK / "candidate-catalog.json")["entries"]}
    assert len(previous["entries"]) == len(reviewed) == 200 and len(original) == 400
    entries = []
    audit = []
    for candidate in previous["entries"]:
        name = candidate["species"]
        battle = reviewed[name]
        old_normal = candidate["normal_scn_sha256"]
        if name == "floragato":
            normal_path = WORK / "floragato-scale-fix-test/normal-alias-compressed.scn"
            shiny_path = WORK / "floragato-scale-fix-test/shiny-alias-compressed.scn"
            reason = "post-review scale and physical attack fix, independently battle requalified"
        elif old_normal != battle["normal_runtime_sha256"]:
            normal_path = ROOT / battle["normal_runtime_artifact"]
            sibling = normal_path.parent.parent / "shiny-runtime" / f"{name}@shiny.scn"
            shiny_path = sibling if sibling.is_file() else Path(original[name, "shiny"]["runtime_path"])
            reason = "exact accepted normal battle scene restored"
        else:
            normal_path = Path(original[name, "normal"]["runtime_path"])
            shiny_path = Path(original[name, "shiny"]["runtime_path"])
            reason = "previous exact battle scene retained"
        normal_hash = digest(normal_path)
        shiny_hash = digest(shiny_path)
        if name == "floragato":
            assert normal_hash == candidate["normal_scn_sha256"]
            assert shiny_hash == candidate["shiny_scn_sha256"]
        else:
            assert normal_hash == battle["normal_runtime_sha256"], name
        for variant, path, scene_hash in (("normal", normal_path, normal_hash), ("shiny", shiny_path, shiny_hash)):
            entries.append({"species": name, "variant": variant, "runtime_path": str(path.resolve()),
                            "runtime_sha256": scene_hash})
        audit.append({"species": name, "reason": reason,
                      "normal_scn_sha256": normal_hash, "shiny_scn_sha256": shiny_hash,
                      "normal_source": str(normal_path.relative_to(ROOT)),
                      "shiny_source": str(shiny_path.relative_to(ROOT)),
                      "normal_changed": normal_hash != candidate["normal_scn_sha256"],
                      "shiny_changed": shiny_hash != candidate["shiny_scn_sha256"]})
    assert len(entries) == 400
    assert sum(row["normal_changed"] for row in audit) == 21
    assert sum(row["shiny_changed"] for row in audit) == 7
    CATALOG.write_text(json.dumps({"entries": entries}, indent=2) + "\n")
    AUDIT.write_text(json.dumps({"schema": 1, "status": "reconciled_review_candidates",
                                 "previous_candidate_sha256": digest(PREVIOUS),
                                 "review_sha256": digest(REVIEW), "entries": audit}, indent=2) + "\n")
    print("RECONCILED pairs=200 normal_restored=21 shiny_repaired=7")


if __name__ == "__main__":
    main()
