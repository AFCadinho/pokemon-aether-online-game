#!/usr/bin/env python3
"""Stage the 82 approved base bundles plus approved Mega Dragonite."""
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
V4_METADATA = ROOT / "release/approved_3d_bundles_v4.json"
MEGA_APPROVAL = ROOT / "tools/sprite_factory/mega_dragonite_approval.json"
REGISTRY = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
REVISION = "approved-pokemon-3d-v5"
MEGA_ID = "pokemon_3d:dragonite:mega"


def digest(path: Path) -> str:
    hashing = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            hashing.update(chunk)
    return hashing.hexdigest()


def build(v4_dir: Path, mega_dir: Path, output: Path, receipt_path: Path) -> dict:
    if output.exists() or output.is_symlink() or receipt_path.exists():
        raise ValueError("release v5 output or receipt already exists")
    release_files(v4_dir, V4_METADATA)
    v4_receipt = json.loads(V4_METADATA.read_text())
    old_index = json.loads((v4_dir / "asset-index.json").read_text())
    mega_index = json.loads((mega_dir / "asset-index.json").read_text())
    approval = json.loads(MEGA_APPROVAL.read_text())
    registry = json.loads(REGISTRY.read_text())
    old_assets = old_index.get("assets", [])
    new_assets = mega_index.get("assets", [])
    if (len(old_assets) != 82 or len({item["asset_id"] for item in old_assets}) != 82
            or len(new_assets) != 1 or new_assets[0].get("asset_id") != MEGA_ID
            or MEGA_ID in {item["asset_id"] for item in old_assets}
            or old_index.get("runtime_contract") != mega_index.get("runtime_contract")
            or registry.get("mega_dragonite_approval_sha256") != digest(MEGA_APPROVAL)
            or approval.get("visual_approved_by_player") is not True
            or approval.get("local_installed_battle_normal_and_shiny_passed") is not True):
        raise ValueError("v4 or Mega Dragonite approval is incomplete")
    mega = new_assets[0]
    if (mega.get("form_id") != "mega" or mega.get("species_id") != "dragonite"
            or mega.get("dependencies") != ["pokemon_3d:dragonite:base"]
            or mega.get("sha256") != approval.get("bundle_v1_sha256")
            or mega.get("size_bytes") != approval.get("bundle_v1_bytes")):
        raise ValueError("Mega bundle differs from the approval receipt")
    expected = {"normal": "dragonite-mega", "shiny": "dragonite-mega@shiny"}
    appearances = mega.get("appearances", [])
    if (len(appearances) != 2 or
            {item.get("variant"): item.get("runtime_identity") for item in appearances} != expected):
        raise ValueError("Mega bundle does not contain its approved pair")
    for item in appearances:
        identity = item["runtime_identity"]
        if registry["models"].get(identity, {}).get("sha256") != item.get("runtime_sha256"):
            raise ValueError(f"Mega appearance is not release-approved: {identity}")
    archive = mega_dir / Path(mega["object_key"]).name
    if archive.is_symlink() or not archive.is_file() or archive.stat().st_size != mega["size_bytes"] or digest(archive) != mega["sha256"]:
        raise ValueError("Mega bundle archive changed after approval")

    assets = sorted([*old_assets, mega], key=lambda item: item["asset_id"])
    output.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=".approved-3d-v5-", dir=output.parent))
    try:
        # Existing v4 archives are immutable and already pinned. Hard links avoid
        # copying two gigabytes just to stage the next content index.
        for asset in old_assets:
            name = Path(asset["object_key"]).name
            os.link(v4_dir / name, staged / name)
        shutil.copyfile(archive, staged / archive.name)
        index = dict(old_index)
        index["catalog_revision"] = REVISION
        index["assets"] = assets
        index_path = staged / "asset-index.json"
        index_path.write_bytes(encoded(index))
        index_hash = digest(index_path)
        metadata = {
            "schema": 1,
            "kind": "pokeaether-approved-3d-release",
            "revision": REVISION,
            "index": {
                "object_key": f"optional-assets/pokemon_3d/index/{REVISION}-{index_hash}.json",
                "sha256": index_hash,
                "size_bytes": index_path.stat().st_size,
            },
            "bundles": [
                {key: asset[key] for key in ("asset_id", "object_key", "sha256", "size_bytes")}
                for asset in assets
            ],
            "total_bundle_bytes": sum(asset["size_bytes"] for asset in assets),
            "new_bundle_count": 1,
            "unchanged_v4_bundle_count": 82,
            "mega_dragonite_approval_sha256": digest(MEGA_APPROVAL),
            "v4_index_sha256": v4_receipt["index"]["sha256"],
        }
        os.rename(staged, output)
        receipt_path.parent.mkdir(parents=True, exist_ok=True)
        receipt_path.write_bytes(encoded(metadata))
        return metadata
    except BaseException:
        shutil.rmtree(staged, ignore_errors=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("v4_dir", type=Path)
    parser.add_argument("mega_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    metadata = build(args.v4_dir.resolve(), args.mega_dir.resolve(),
                     args.output.absolute(), args.receipt.absolute())
    print(f"Staged {len(metadata['bundles'])} approved bundles: {metadata['total_bundle_bytes']} bytes")
    print(f"Index SHA-256: {metadata['index']['sha256']}")


if __name__ == "__main__":
    main()
