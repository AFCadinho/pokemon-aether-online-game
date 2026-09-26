#!/usr/bin/env python3
"""Stage the 82-species release from v3 and six approved placement recoveries."""
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
V3_METADATA = ROOT / "release/approved_3d_bundles_v3.json"
RECOVERY_APPROVAL = ROOT / "tools/sprite_factory/screened_100_placement_recovery.json"
RECOVERY_METADATA = ROOT / "release/approved_3d_placement_recovery_v1.json"
REGISTRY = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
REVISION = "approved-pokemon-3d-v4"


def digest(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def build(v3_dir: Path, additions_dir: Path, output: Path, receipt_path: Path) -> dict:
    if output.exists() or output.is_symlink() or receipt_path.exists():
        raise ValueError("release v4 output or receipt already exists")
    approval = json.loads(RECOVERY_APPROVAL.read_text(encoding="utf-8"))
    recovery = json.loads(RECOVERY_METADATA.read_text(encoding="utf-8"))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    if (approval.get("release_approved") is not True or approval.get("published") is not False
            or len(approval.get("approved_species", [])) != 6
            or recovery.get("kind") != "pokeaether-approved-3d-additions"
            or recovery.get("published") is not False
            or recovery.get("placement_recovery_approval_sha256") != digest(RECOVERY_APPROVAL)
            or len(recovery.get("bundles", [])) != 6
            or len(registry.get("models", {})) != 164):
        raise ValueError("placement recovery approval or bundle receipt is incomplete")

    release_files(v3_dir, V3_METADATA)
    old_index_path = v3_dir / "asset-index.json"
    old_index = json.loads(old_index_path.read_text(encoding="utf-8"))
    addition_index_path = additions_dir / "asset-index.json"
    addition_index = json.loads(addition_index_path.read_text(encoding="utf-8"))
    if (digest(addition_index_path) != recovery["index"]["sha256"]
            or addition_index.get("catalog_revision") != "screened-100-placement-recovered-v1"):
        raise ValueError("placement recovery index changed after approval")
    old_assets, new_assets = old_index.get("assets", []), addition_index.get("assets", [])
    old_ids = {asset["species_id"] for asset in old_assets}
    new_ids = {asset["species_id"] for asset in new_assets}
    if (len(old_assets) != 76 or len(old_ids) != 76 or len(new_assets) != 6
            or new_ids != set(approval["approved_species"]) or old_ids & new_ids):
        raise ValueError("release cohorts do not contain exactly 82 approved species")
    pinned_new = {item["asset_id"]: item for item in recovery["bundles"]}
    if len(pinned_new) != 6:
        raise ValueError("placement recovery receipt has duplicate bundle IDs")

    all_assets = sorted([*old_assets, *new_assets], key=lambda item: item["asset_id"])
    output.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=".approved-3d-v4-", dir=output.parent))
    try:
        for asset in all_assets:
            species = asset["species_id"]
            source_dir = v3_dir if species in old_ids else additions_dir
            source = source_dir / Path(asset["object_key"]).name
            if (source.is_symlink() or not source.is_file()
                    or source.stat().st_size != asset["size_bytes"]
                    or digest(source) != asset["sha256"]):
                raise ValueError(f"release archive changed: {species}")
            if species not in old_ids:
                pinned = pinned_new.get(asset["asset_id"])
                if (pinned is None or pinned["object_key"] != asset["object_key"]
                        or pinned["sha256"] != asset["sha256"]
                        or pinned["size_bytes"] != asset["size_bytes"]):
                    raise ValueError(f"placement recovery bundle receipt changed: {species}")
            if len(asset.get("appearances", [])) != 2:
                raise ValueError(f"normal/shiny pair missing: {species}")
            for appearance in asset["appearances"]:
                identity = appearance["runtime_identity"]
                if registry["models"].get(identity, {}).get("sha256") != appearance["runtime_sha256"]:
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
            "new_bundle_count": 6,
            "unchanged_v3_bundle_count": 76,
            "screened_100_placement_recovery_approval_sha256": digest(RECOVERY_APPROVAL),
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
    parser.add_argument("v3_dir", type=Path)
    parser.add_argument("additions_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    metadata = build(args.v3_dir.resolve(), args.additions_dir.resolve(),
                     args.output.absolute(), args.receipt.absolute())
    print(f"Staged {len(metadata['bundles'])} approved bundles: {metadata['total_bundle_bytes']} bytes")
    print(f"Index SHA-256: {metadata['index']['sha256']}")


if __name__ == "__main__":
    main()
