#!/usr/bin/env python3
"""Stage a local 21-species release index from unchanged v1 and approved batch-01 bundles."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile

try:
    from .package_optional_3d_bundle_prototype import encoded
    from .publish_approved_3d_bundles import release_files
except ImportError:
    from package_optional_3d_bundle_prototype import encoded
    from publish_approved_3d_bundles import release_files


ROOT = Path(__file__).resolve().parents[1]
V1_METADATA = ROOT / "release/approved_3d_bundles_v1.json"
APPROVAL = ROOT / "tools/sprite_factory/catalog_production_batch_01_approval.json"
PREFLIGHT = ROOT / "tools/sprite_factory/catalog_production_batch_01_bundle_preflight.json"
REGISTRY = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
REVISION = "approved-pokemon-3d-v2"


def digest(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def build(v1_dir: Path, batch_dir: Path, output: Path, receipt_path: Path) -> dict:
    v1_dir, batch_dir, output, receipt_path = map(Path, (v1_dir, batch_dir, output, receipt_path))
    if output.exists() or output.is_symlink() or receipt_path.exists():
        raise ValueError("release v2 output or receipt already exists")
    approval = json.loads(APPROVAL.read_text())
    preflight = json.loads(PREFLIGHT.read_text())
    approved = json.loads(REGISTRY.read_text())
    if (approval.get("release_approved") is not True or approval.get("published") is not False
            or approved.get("catalog_batch_01_approval_sha256") != digest(APPROVAL)
            or approval.get("bundle_preflight_sha256") != digest(PREFLIGHT)):
        raise ValueError("batch-01 approval is stale")
    release_files(v1_dir, V1_METADATA)
    original = json.loads((v1_dir / "asset-index.json").read_text())
    batch_index_path = batch_dir / "asset-index.json"
    batch = json.loads(batch_index_path.read_text())
    if digest(batch_index_path) != preflight["index_sha256"] or len(batch["assets"]) != 14:
        raise ValueError("batch-01 candidate index changed")
    old_ids = {asset["species_id"] for asset in original["assets"]}
    new_ids = {asset["species_id"] for asset in batch["assets"]}
    if (len(old_ids) != 7 or new_ids != set(approval["approved_species"])
            or old_ids & new_ids or len(approved["models"]) != 42):
        raise ValueError("v2 cohort does not contain exactly 21 approved species")
    assets = sorted([*original["assets"], *batch["assets"]], key=lambda item: item["asset_id"])
    if len(assets) != 21:
        raise ValueError("v2 asset index is incomplete")
    output.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=".approved-3d-v2-", dir=output.parent))
    try:
        for asset in assets:
            species = asset["species_id"]
            source_dir = v1_dir if species in old_ids else batch_dir
            source = source_dir / Path(asset["object_key"]).name
            if (source.is_symlink() or not source.is_file() or source.stat().st_size != asset["size_bytes"]
                    or digest(source) != asset["sha256"]):
                raise ValueError(f"release archive changed: {species}")
            if len(asset["appearances"]) != 2:
                raise ValueError(f"normal/shiny pair missing: {species}")
            for appearance in asset["appearances"]:
                identity = appearance["runtime_identity"]
                if approved["models"].get(identity, {}).get("sha256") != appearance["runtime_sha256"]:
                    raise ValueError(f"appearance is not approved: {identity}")
            destination = staged / source.name
            shutil.copyfile(source, destination)
            if digest(destination) != asset["sha256"]:
                raise ValueError(f"copied archive changed: {species}")
        index = dict(original)
        index["catalog_revision"] = REVISION
        index["assets"] = assets
        (staged / "asset-index.json").write_bytes(encoded(index))
        index_hash = digest(staged / "asset-index.json")
        metadata = {"schema": 1, "kind": "pokeaether-approved-3d-release", "revision": REVISION,
            "index": {"object_key": f"optional-assets/pokemon_3d/index/{REVISION}-{index_hash}.json",
                      "size_bytes": (staged / "asset-index.json").stat().st_size, "sha256": index_hash},
            "bundles": [{key: asset[key] for key in ("asset_id", "object_key", "size_bytes", "sha256")}
                        for asset in assets],
            "total_bundle_bytes": sum(asset["size_bytes"] for asset in assets),
            "new_bundle_count": 14, "unchanged_v1_bundle_count": 7,
            "catalog_batch_01_approval_sha256": digest(APPROVAL)}
        os.rename(staged, output)
        receipt_path.write_bytes(encoded(metadata))
        return metadata
    except BaseException:
        if staged.exists():
            shutil.rmtree(staged)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("v1_dir", type=Path)
    parser.add_argument("batch_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    metadata = build(args.v1_dir.resolve(), args.batch_dir.resolve(), args.output.absolute(), args.receipt.absolute())
    print(f"Staged {len(metadata['bundles'])} approved bundles: {metadata['total_bundle_bytes']} bytes")
    print(f"Index SHA-256: {metadata['index']['sha256']}")


if __name__ == "__main__":
    main()
