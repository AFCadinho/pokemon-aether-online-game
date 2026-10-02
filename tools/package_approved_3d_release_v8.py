#!/usr/bin/env python3
"""Build the full, locally approved 3D bundle index for release v8.

This combines the receipt-backed immutable bundle cohorts already published to
R2. It only writes local index and metadata files; it does not upload or
activate them.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RELEASE = ROOT / "release"
REGISTRY = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
REVISION = "approved-pokemon-3d-v8"
SOURCE_INDEXES = (
    "approved_3d_bundles_884_index.json",
    "approved_3d_dlc_15_index.json",
    "approved_3d_recovery_39_index.json",
    "approved_3d_recovery_pair_index.json",
    "approved_3d_remaining_142_eight_index.json",
    "approved_3d_remaining_142_paras_index.json",
    "approved_3d_remaining_142_six_index.json",
    "approved_3d_remaining_56_index.json",
    "approved_3d_remaining_76_index.json",
    "approved_3d_remaining_final_112_index.json",
    "approved_3d_skarmory_flight_v2_index.json",
    "approved_3d_battle_forms_first_five_index.json",
    "approved_3d_battle_forms_next_seven_index.json",
    "approved_3d_kyurem_forms_index.json",
    "approved_3d_legendary_riders_crowned_index.json",
    "approved_3d_mega_24_index.json",
    "approved_3d_mega_71_index.json",
    "approved_3d_ogerpon_cloak_v2_index.json",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def encoded(value: object) -> bytes:
    # Keep the full index below the 1 MiB client-side integrity limit.
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def read_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return value


def build(index_output: Path, metadata_output: Path) -> dict:
    indexes: dict[str, dict] = {}
    receipt_hashes: dict[str, str] = {}
    versions: dict[str, list[dict]] = {}
    for filename in SOURCE_INDEXES:
        index_path = RELEASE / filename
        receipt_path = RELEASE / filename.replace("_index.json", "_r2_upload.json")
        index_data = index_path.read_bytes()
        index = json.loads(index_data)
        receipt = read_json(receipt_path)
        pin = receipt.get("content_index", {})
        if (not receipt.get("desktop_manifest_activated") is False
                or pin.get("sha256") != sha256_bytes(index_data)
                or pin.get("size_bytes") != len(index_data)
                or not pin.get("object_key")):
            raise ValueError(f"R2 publication receipt does not pin {filename}")
        if not isinstance(index.get("assets"), list) or not index["assets"]:
            raise ValueError(f"source index has no assets: {filename}")
        for asset in index["assets"]:
            asset_id = asset.get("asset_id")
            if not isinstance(asset_id, str):
                raise ValueError(f"source index has an invalid asset: {filename}")
            versions.setdefault(asset_id, []).append({"asset": asset, "source": filename})
        receipt_hashes[receipt_path.name] = hashlib.sha256(receipt_path.read_bytes()).hexdigest()
        indexes[filename] = index

    selected: list[dict] = []
    for asset_id, rows in versions.items():
        rows.sort(key=lambda row: int(row["asset"].get("version", 0)))
        highest_version = int(rows[-1]["asset"].get("version", 0))
        latest = [row for row in rows if int(row["asset"].get("version", 0)) == highest_version]
        hashes = {row["asset"].get("sha256") for row in latest}
        if len(hashes) != 1:
            raise ValueError(f"conflicting same-version bundles: {asset_id}")
        selected.append(latest[-1]["asset"])
    selected.sort(key=lambda asset: asset["asset_id"])

    registry = read_json(REGISTRY)
    approved_models = registry.get("models", {})
    covered: set[str] = set()
    for asset in selected:
        asset_id = asset["asset_id"]
        if asset_id != f"pokemon_3d:{asset['species_id']}:{asset['form_id']}":
            raise ValueError(f"asset ID does not match form identity: {asset_id}")
        appearances = asset.get("appearances", [])
        if len(appearances) != 2 or {item.get("variant") for item in appearances} != {"normal", "shiny"}:
            raise ValueError(f"normal/shiny pair is incomplete: {asset_id}")
        for appearance in appearances:
            identity = appearance.get("runtime_identity", "")
            if identity in covered:
                raise ValueError(f"runtime identity is assigned twice: {identity}")
            model = approved_models.get(identity, {})
            if not model or model.get("sha256") != appearance.get("runtime_sha256"):
                raise ValueError(f"runtime hash is not in the reviewed catalog: {identity}")
            covered.add(identity)
    if covered != set(approved_models):
        missing = sorted(set(approved_models) - covered)
        extra = sorted(covered - set(approved_models))
        raise ValueError(f"approved catalog coverage differs; missing={missing[:8]} extra={extra[:8]}")
    if len(selected) != 1139 or len(covered) != 2278:
        raise ValueError(f"unexpected catalog size: {len(selected)} bundles, {len(covered)} appearances")

    index = dict(next(iter(indexes.values())))
    index.update({
        "catalog_revision": REVISION,
        "assets": selected,
    })
    index_bytes = encoded(index)
    index_hash = sha256_bytes(index_bytes)
    if len(index_bytes) > 1024 * 1024:
        raise ValueError("combined index exceeds the current 1 MiB client limit")
    index_output.parent.mkdir(parents=True, exist_ok=True)
    metadata_output.parent.mkdir(parents=True, exist_ok=True)
    index_output.write_bytes(index_bytes)

    bundles = [{key: asset[key] for key in ("asset_id", "object_key", "sha256", "size_bytes")}
               for asset in selected]
    metadata = {
        "schema": 1,
        "kind": "pokeaether-approved-3d-release",
        "revision": REVISION,
        "index": {
            "object_key": f"optional-assets/pokemon_3d/index/{REVISION}-{index_hash}.json",
            "sha256": index_hash,
            "size_bytes": len(index_bytes),
        },
        "bundles": bundles,
        "new_bundle_count": len(bundles),
        "total_bundle_bytes": sum(asset["size_bytes"] for asset in selected),
        "source_index_count": len(indexes),
        "source_receipts_sha256": receipt_hashes,
    }
    metadata_output.write_bytes(encoded(metadata))
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", type=Path, default=RELEASE / "approved_3d_bundles_v8_index.json")
    parser.add_argument("--metadata", type=Path, default=RELEASE / "approved_3d_bundles_v8.json")
    args = parser.parse_args()
    result = build(args.index.resolve(), args.metadata.resolve())
    print(f"Prepared local v8: bundles={len(result['bundles'])} appearances={len(result['bundles']) * 2} "
          f"index={result['index']['sha256']} bytes={result['index']['size_bytes']} "
          "R2 upload=not performed; manifest activation=not performed")


if __name__ == "__main__":
    main()
