#!/usr/bin/env python3
"""Stage the 76-species release from the published v2 set and approved 55-pair cohort."""
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
V2_METADATA = ROOT / "release/approved_3d_bundles_v2.json"
APPROVAL = ROOT / "tools/sprite_factory/screened_100_battle_approval.json"
PREFLIGHT = ROOT / "tools/sprite_factory/screened_100_bundle_preflight.json"
REGISTRY = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
REVISION = "approved-pokemon-3d-v3"


def digest(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def build(v2_dir: Path, candidate_dir: Path, output: Path, receipt_path: Path) -> dict:
    if output.exists() or output.is_symlink() or receipt_path.exists():
        raise ValueError("release v3 output or receipt already exists")
    approval = json.loads(APPROVAL.read_text(encoding="utf-8"))
    preflight = json.loads(PREFLIGHT.read_text(encoding="utf-8"))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if (approval.get("release_approved") is not True or approval.get("published") is not False
            or approval.get("individual_bundle_count") != 55
            or approval.get("bundle_preflight_sha256") != digest(PREFLIGHT)
            or preflight.get("status") != "local_candidate_bundle_preflight_passed"
            or preflight.get("index_sha256") != approval.get("bundle_index_sha256")):
        raise ValueError("screened-100 approval or bundle preflight is stale")

    release_files(v2_dir, V2_METADATA)
    old_index = json.loads((v2_dir / "asset-index.json").read_text(encoding="utf-8"))
    candidate_index_path = candidate_dir / "asset-index.json"
    candidate_index = json.loads(candidate_index_path.read_text(encoding="utf-8"))
    if digest(candidate_index_path) != preflight["index_sha256"]:
        raise ValueError("candidate index changed after approval")
    old_assets = old_index.get("assets", [])
    new_assets = candidate_index.get("assets", [])
    old_ids = {item["species_id"] for item in old_assets}
    new_ids = {item["species_id"] for item in new_assets}
    if (len(old_assets) != 21 or len(old_ids) != 21 or len(new_assets) != 55
            or new_ids != set(approval["approved_species"]) or old_ids & new_ids
            or len(registry.get("models", {})) < 152):
        raise ValueError("release cohorts do not contain exactly 76 approved species")

    approved_models = registry["models"]
    all_assets = sorted([*old_assets, *new_assets], key=lambda item: item["asset_id"])
    staged = Path(tempfile.mkdtemp(prefix=".approved-3d-v3-", dir=output.parent))
    try:
        for asset in all_assets:
            species = asset["species_id"]
            source_dir = v2_dir if species in old_ids else candidate_dir
            source = source_dir / Path(asset["object_key"]).name
            if (source.is_symlink() or not source.is_file()
                    or source.stat().st_size != asset["size_bytes"]
                    or digest(source) != asset["sha256"]):
                raise ValueError(f"release archive changed: {species}")
            if len(asset.get("appearances", [])) != 2:
                raise ValueError(f"normal/shiny pair missing: {species}")
            for appearance in asset["appearances"]:
                identity = appearance["runtime_identity"]
                if approved_models.get(identity, {}).get("sha256") != appearance["runtime_sha256"]:
                    raise ValueError(f"appearance is not approved: {identity}")
            shutil.copyfile(source, staged / source.name)
        index = dict(old_index)
        index["catalog_revision"] = REVISION
        index["assets"] = all_assets
        (staged / "asset-index.json").write_bytes(encoded(index))
        index_path = staged / "asset-index.json"
        index_hash = digest(index_path)
        metadata = {
            "schema": 1,
            "kind": "pokeaether-approved-3d-release",
            "revision": REVISION,
            "index": {
                "object_key": f"optional-assets/pokemon_3d/index/{REVISION}-{index_hash}.json",
                "size_bytes": index_path.stat().st_size,
                "sha256": index_hash,
            },
            "bundles": [
                {key: asset[key] for key in ("asset_id", "object_key", "size_bytes", "sha256")}
                for asset in all_assets
            ],
            "total_bundle_bytes": sum(asset["size_bytes"] for asset in all_assets),
            "new_bundle_count": 55,
            "unchanged_v2_bundle_count": 21,
            "screened_100_battle_approval_sha256": digest(APPROVAL),
        }
        output.parent.mkdir(parents=True, exist_ok=True)
        os.rename(staged, output)
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        receipt_path.write_bytes(encoded(metadata))
        return metadata
    except BaseException:
        if staged.exists():
            shutil.rmtree(staged)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("v2_dir", type=Path)
    parser.add_argument("candidate_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    metadata = build(args.v2_dir.resolve(), args.candidate_dir.resolve(),
                     args.output.absolute(), args.receipt.absolute())
    print(f"Staged {len(metadata['bundles'])} approved bundles: {metadata['total_bundle_bytes']} bytes")
    print(f"Index SHA-256: {metadata['index']['sha256']}")


if __name__ == "__main__":
    main()
