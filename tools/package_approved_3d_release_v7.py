#!/usr/bin/env python3
"""Stage v6's 154 bundles plus six locally approved pairs for v7."""
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
    from .package_approved_3d_release_v5 import digest
    from .publish_approved_3d_bundles import release_files
except ImportError:
    from package_optional_3d_bundle_prototype import encoded
    from package_approved_3d_release_v5 import digest
    from publish_approved_3d_bundles import release_files

ROOT = Path(__file__).resolve().parents[1]
V6_RECEIPT = ROOT / "release/approved_3d_bundles_v6.json"
APPEARANCE = ROOT / "tools/sprite_factory/catalog_remaining_six_appearance_review.json"
BATTLE = ROOT / "tools/sprite_factory/catalog_remaining_six_battle_qualification.json"
BUNDLES = ROOT / "tools/sprite_factory/catalog_remaining_six_bundle_qualification.json"
REGISTRY = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
REVISION = "approved-pokemon-3d-v7"
NEW_NAMES = ("cursola", "darmanitan-standard", "obstagoon", "silvally", "unown", "wishiwashi")


def build(v6_dir: Path, additions_dir: Path, output: Path, receipt_path: Path) -> dict:
    if output.exists() or output.is_symlink() or receipt_path.exists():
        raise ValueError("release v7 output or receipt already exists")
    old_files = release_files(v6_dir, V6_RECEIPT)
    old = json.loads(V6_RECEIPT.read_text())
    old_index = json.loads((v6_dir / "asset-index.json").read_text())
    candidate_receipt = json.loads(BUNDLES.read_text())
    appearance = json.loads(APPEARANCE.read_text())
    battle = json.loads(BATTLE.read_text())
    addon_index = json.loads((additions_dir / "asset-index.json").read_text())
    addon_registry = json.loads(REGISTRY.read_text())
    if (candidate_receipt.get("appearance_approved") is not True
            or candidate_receipt.get("battle_approved") is not True
            or candidate_receipt.get("runtime_approved") is not True
            or candidate_receipt.get("published") is not False
            or appearance.get("appearance_approved") is not True
            or battle.get("user_review", {}).get("battle_approved") is not True):
        raise ValueError("the six-pair approval chain is incomplete")
    for evidence_path, evidence_hash in candidate_receipt["evidence_sha256"].items():
        if digest(ROOT / evidence_path) != evidence_hash:
            raise ValueError(f"six-pair evidence changed: {evidence_path}")
    if digest(APPEARANCE) != candidate_receipt["evidence_sha256"].get(
            "tools/sprite_factory/catalog_remaining_six_appearance_review.json"):
        raise ValueError("appearance receipt differs from bundle qualification")
    if digest(BATTLE) != candidate_receipt["evidence_sha256"].get(
            "tools/sprite_factory/catalog_remaining_six_battle_qualification.json"):
        raise ValueError("battle receipt differs from bundle qualification")
    if (old.get("revision") != "approved-pokemon-3d-v6" or len(old_index.get("assets", [])) != 154
            or len(addon_index.get("assets", [])) != len(NEW_NAMES)):
        raise ValueError("expected complete v6 plus six-pair bundle indexes")
    seen = {item["asset_id"] for item in old_index["assets"]}
    if len(seen) != 154 or any(f"pokemon_3d:{name}:base" in seen for name in NEW_NAMES):
        raise ValueError("v6 index has duplicate or incomplete assets")
    registry = addon_registry.get("models", {})
    additions = []
    for asset in addon_index["assets"]:
        name = asset["species_id"]
        if name not in NEW_NAMES or asset["asset_id"] in seen:
            raise ValueError(f"unexpected or duplicate approved asset: {asset.get('asset_id')}")
        if asset.get("form_id") != "base" or asset.get("version") != 1 or len(asset.get("appearances", [])) != 2:
            raise ValueError(f"invalid base form bundle: {name}")
        expected = {name, name + "@shiny"}
        if {appearance.get("runtime_identity") for appearance in asset["appearances"]} != expected:
            raise ValueError(f"normal/shiny pair incomplete: {name}")
        for model in asset["appearances"]:
            if registry.get(model["runtime_identity"], {}).get("sha256") != model["runtime_sha256"]:
                raise ValueError(f"bundle model hash is not in reviewed catalog: {model['runtime_identity']}")
        path = additions_dir / Path(asset["object_key"]).name
        if path.is_symlink() or not path.is_file() or path.stat().st_size != asset["size_bytes"] or digest(path) != asset["sha256"]:
            raise ValueError(f"approved archive changed: {name}")
        additions.append((asset, path))
        seen.add(asset["asset_id"])
    if {item["species_id"] for item, _ in additions} != set(NEW_NAMES):
        raise ValueError("the approved six-species bundle set differs")

    assets = sorted([*old_index["assets"], *(item for item, _ in additions)], key=lambda row: row["asset_id"])
    output.parent.mkdir(parents=True, exist_ok=True)
    staged = Path(tempfile.mkdtemp(prefix=".approved-3d-v7-", dir=output.parent))
    try:
        for item in old_index["assets"]:
            source = v6_dir / Path(item["object_key"]).name
            if not source.is_file() or source.is_symlink() or source.stat().st_size != item["size_bytes"] or digest(source) != item["sha256"]:
                raise ValueError(f"pinned v6 bundle is missing or changed: {item['asset_id']}")
            os.link(source, staged / source.name)
        for item, source in additions:
            shutil.copyfile(source, staged / Path(item["object_key"]).name)
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
            "new_bundle_count": len(additions),
            "unchanged_v6_bundle_count": len(old_index["assets"]),
            "v6_index_sha256": old["index"]["sha256"],
            "six_pair_bundle_qualification_sha256": digest(BUNDLES),
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
    parser.add_argument("v6_dir", type=Path)
    parser.add_argument("six_bundle_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("receipt", type=Path)
    args = parser.parse_args()
    receipt = build(args.v6_dir.resolve(), args.six_bundle_dir.resolve(), args.output.resolve(), args.receipt.resolve())
    print(f"Staged v7: bundles={len(receipt['bundles'])} new={receipt['new_bundle_count']} "
          f"index={receipt['index']['sha256']} uploads=7 objects")


if __name__ == "__main__":
    main()
