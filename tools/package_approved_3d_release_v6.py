#!/usr/bin/env python3
"""Stage v5 plus the 71 separately approved batch-02 normal/shiny pairs."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import tempfile

try:
    from .package_approved_3d_release_v5 import digest
    from .package_optional_3d_bundle_prototype import encoded
    from .publish_approved_3d_bundles import release_files
except ImportError:
    from package_approved_3d_release_v5 import digest
    from package_optional_3d_bundle_prototype import encoded
    from publish_approved_3d_bundles import release_files


ROOT = Path(__file__).resolve().parents[1]
V5_RECEIPT = ROOT / "release/approved_3d_bundles_v5.json"
BATCH_APPROVAL = ROOT / "tools/sprite_factory/catalog_production_batch_02_approval.json"
FOLLOWUP_APPROVAL = ROOT / "tools/sprite_factory/catalog_production_batch_02_review_queue_approval.json"
PREFLIGHT = ROOT / "tools/sprite_factory/catalog_production_batch_02_bundle_preflight.json"
REGISTRY = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
REVISION = "approved-pokemon-3d-v6"


def build(v5_dir: Path, batch_dir: Path, followup_dir: Path,
          output: Path, receipt_path: Path) -> dict:
    if output.exists() or output.is_symlink() or receipt_path.exists():
        raise ValueError("release v6 output or receipt already exists")
    release_files(v5_dir, V5_RECEIPT)
    old_receipt = json.loads(V5_RECEIPT.read_text())
    old_index = json.loads((v5_dir / "asset-index.json").read_text())
    batch_index = json.loads((batch_dir / "asset-index.json").read_text())
    followup_index = json.loads((followup_dir / "asset-index.json").read_text())
    approval = json.loads(BATCH_APPROVAL.read_text())
    followup = json.loads(FOLLOWUP_APPROVAL.read_text())
    preflight = json.loads(PREFLIGHT.read_text())
    registry = json.loads(REGISTRY.read_text())["models"]
    if (approval.get("runtime_approved") is not True or approval.get("release_approved") is not True
            or approval.get("published") is not False or followup.get("runtime_approved") is not True
            or followup.get("release_approved") is not True or followup.get("published") is not False):
        # The preflight is a technical candidate record; release approval is separate.
        raise ValueError("batch-02 approval is incomplete")
    if (digest(PREFLIGHT) != approval.get("bundle_preflight_sha256")
            or digest(batch_dir / "asset-index.json") != preflight.get("index_sha256")
            or digest(followup_dir / "asset-index.json") != followup.get("bundle_index_sha256")):
        raise ValueError("batch-02 bundle evidence changed")
    sources = [(batch_dir, batch_index, set(approval["approved_species"]), 69),
               (followup_dir, followup_index, {row["species"] for row in followup["entries"]}, 2)]
    old_assets = old_index["assets"]
    old_ids = {item["asset_id"] for item in old_assets}
    if len(old_assets) != 83 or len(old_ids) != 83:
        raise ValueError("v5 index is incomplete")
    new_assets: list[dict] = []
    archives: list[tuple[Path, str]] = []
    seen = set(old_ids)
    for directory, index, species, count in sources:
        assets = index.get("assets", [])
        if (len(assets) != count or len(species) != count
                or index.get("runtime_contract") != old_index.get("runtime_contract")):
            raise ValueError("batch-02 index does not match approved cohort")
        if {item.get("species_id") for item in assets} != species:
            raise ValueError("batch-02 species differs from approval")
        for asset in assets:
            asset_id = asset["asset_id"]
            if (asset_id != f"pokemon_3d:{asset['species_id']}:base" or asset_id in seen
                    or asset.get("form_id") != "base" or len(asset.get("appearances", [])) != 2):
                raise ValueError("duplicate or unapproved batch-02 bundle")
            seen.add(asset_id)
            expected = {asset["species_id"], asset["species_id"] + "@shiny"}
            if {item.get("runtime_identity") for item in asset["appearances"]} != expected:
                raise ValueError(f"incomplete normal/shiny pair: {asset_id}")
            for appearance in asset["appearances"]:
                identity = appearance["runtime_identity"]
                if registry.get(identity, {}).get("sha256") != appearance.get("runtime_sha256"):
                    raise ValueError(f"model is not release-approved: {identity}")
            archive = directory / Path(asset["object_key"]).name
            if (archive.is_symlink() or not archive.is_file()
                    or archive.stat().st_size != asset["size_bytes"]
                    or digest(archive) != asset["sha256"]):
                raise ValueError(f"approved bundle changed: {asset_id}")
            archives.append((archive, archive.name))
            new_assets.append(asset)
    assets = sorted([*old_assets, *new_assets], key=lambda item: item["asset_id"])
    output.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=".approved-3d-v6-", dir=output.parent))
    try:
        for asset in old_assets:
            name = Path(asset["object_key"]).name
            os.link(v5_dir / name, staged / name)
        for archive, name in archives:
            if (staged / name).exists():
                raise ValueError(f"archive name collision: {name}")
            os.link(archive, staged / name)
        index = dict(old_index)
        index["catalog_revision"] = REVISION
        index["assets"] = assets
        index_path = staged / "asset-index.json"
        index_path.write_bytes(encoded(index))
        index_hash = digest(index_path)
        receipt = {
            "schema": 1,
            "kind": "pokeaether-approved-3d-release",
            "revision": REVISION,
            "index": {
                "object_key": f"optional-assets/pokemon_3d/index/{REVISION}-{index_hash}.json",
                "sha256": index_hash,
                "size_bytes": index_path.stat().st_size,
            },
            "bundles": [{key: item[key] for key in ("asset_id", "object_key", "sha256", "size_bytes")}
                        for item in assets],
            "total_bundle_bytes": sum(item["size_bytes"] for item in assets),
            "new_bundle_count": 71,
            "unchanged_v5_bundle_count": 83,
            "batch_02_approval_sha256": digest(BATCH_APPROVAL),
            "batch_02_followup_approval_sha256": digest(FOLLOWUP_APPROVAL),
            "v5_index_sha256": old_receipt["index"]["sha256"],
        }
        os.rename(staged, output)
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        receipt_path.write_bytes(encoded(receipt))
        return receipt
    except BaseException:
        shutil.rmtree(staged, ignore_errors=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("v5_dir", "batch_dir", "followup_dir", "output", "receipt"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    receipt = build(*(getattr(args, name).absolute() for name in
                      ("v5_dir", "batch_dir", "followup_dir", "output", "receipt")))
    print(f"Staged {len(receipt['bundles'])} approved bundles; index SHA-256: {receipt['index']['sha256']}")


if __name__ == "__main__":
    main()
