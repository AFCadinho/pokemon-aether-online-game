#!/usr/bin/env python3
"""Rebuild only batch-04 bundles whose reviewed scenes changed."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

try:
    from tools.package_optional_3d_bundle_prototype import build, encoded
except ImportError:
    import sys
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from package_optional_3d_bundle_prototype import build, encoded


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / ".tmp/batch04-main"
HERE = Path(__file__).resolve().parent
OLD = HERE / "catalog_production_batch_04_main_candidate_bundles.json"
AUDIT = WORK / "candidate-reconciliation-v2.json"
CATALOG = WORK / "candidate-catalog-v2.json"
OLD_BUNDLES = WORK / "candidate-bundles-v1"
CHANGED = WORK / "candidate-bundles-changed-v2"
OUTPUT = WORK / "candidate-bundles-v2"
RECEIPT = HERE / "catalog_production_batch_04_main_candidate_bundles_v2.json"


def read(path: Path):
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def runtime_glb_hash(path: Path, name: str, scene_hash: str) -> str:
    report = path.parent / "report.json"
    for row in read(report):
        if row.get("species") == name and row.get("runtime_sha256") == scene_hash:
            return row["glb_sha256"]
    raise ValueError("scene absent from its runtime report: " + str(path))


def main() -> None:
    previous = read(OLD)
    audit = {entry["species"]: entry for entry in read(AUDIT)["entries"]}
    catalog = {(entry["species"], entry["variant"]): entry for entry in read(CATALOG)["entries"]}
    changed_names = [entry["species"] for entry in previous["entries"] if
                     audit[entry["species"]]["normal_changed"] or audit[entry["species"]]["shiny_changed"]]
    if len(changed_names) != 21 or CHANGED.exists() or OUTPUT.exists():
        raise ValueError("unexpected changed bundle set or output already exists")
    hashes = {name + ("@shiny" if variant == "shiny" else ""): catalog[name, variant]["runtime_sha256"]
              for name in changed_names for variant in ("normal", "shiny")}
    dex = {entry["species"]: entry["national_dex"] for entry in previous["entries"]}
    rebuilt = build(CATALOG, CHANGED, version=2, revision="catalog-batch-04-main-changed-v2",
                    species_set=tuple(changed_names), dex=dex, candidate_hashes=hashes)
    old_index = read(OLD_BUNDLES / "asset-index.json")
    old_assets = {asset["species_id"]: asset for asset in old_index["assets"]}
    new_assets = {asset["species_id"]: asset for asset in rebuilt["assets"]}
    OUTPUT.mkdir()
    assets = []
    rows = []
    for prior in previous["entries"]:
        name = prior["species"]
        asset = new_assets.get(name, old_assets[name])
        source = CHANGED if name in new_assets else OLD_BUNDLES
        archive = source / Path(asset["object_key"]).name
        destination = OUTPUT / archive.name
        os.link(archive, destination)
        assert digest(destination) == asset["sha256"]
        assets.append(asset)
        row = dict(prior)
        row.update({"normal_scn_sha256": audit[name]["normal_scn_sha256"],
                    "shiny_scn_sha256": audit[name]["shiny_scn_sha256"],
                    "bundle_sha256": asset["sha256"], "bundle_size_bytes": asset["size_bytes"],
                    "object_key": asset["object_key"],
                    "normal_scene_matches_battle_accepted_scene": name != "floragato"})
        for variant in ("normal", "shiny"):
            if not audit[name][variant + "_changed"]:
                continue
            scene = catalog[name, variant]
            row[variant + "_glb_sha256"] = runtime_glb_hash(
                Path(scene["runtime_path"]), name + ("@shiny" if variant == "shiny" else ""),
                scene["runtime_sha256"])
        row["pair_source_receipt"] = str(AUDIT) if name in new_assets else row["pair_source_receipt"]
        rows.append(row)
    index = dict(old_index)
    index["catalog_revision"] = "catalog-batch-04-main-corrected-v2"
    index["assets"] = assets
    (OUTPUT / "asset-index.json").write_bytes(encoded(index))
    receipt = {
        "schema": 1, "date": "2026-09-28", "scope": "Reconciled batch-04 main 200 normal/shiny bundles",
        "status": "corrected_local_candidate_bundles_pending_review_and_qualification",
        "runtime_approved": False, "release_approved": False, "published": False,
        "candidate_count": 200, "appearance_count": 400, "bundle_count": 200,
        "replaced_bundle_count": 21, "bundle_bytes": sum(asset["size_bytes"] for asset in assets),
        "bundle_index_sha256": digest(OUTPUT / "asset-index.json"),
        "candidate_bundle_directory": str(OUTPUT.relative_to(ROOT)),
        "previous_manifest_sha256": digest(OLD), "reconciliation_sha256": digest(AUDIT),
        "candidate_catalog_sha256": digest(CATALOG), "entries": rows,
    }
    RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n")
    print("REPACKAGED bundles=200 updated=21 index=" + receipt["bundle_index_sha256"])


if __name__ == "__main__":
    main()
