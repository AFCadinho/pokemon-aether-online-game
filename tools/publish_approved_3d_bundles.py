#!/usr/bin/env python3
"""Verify, and only with --apply upload, a pinned approved 3D release."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    from .upload_launcher_release import _load_config, _upload_file
except ImportError:  # Direct CLI execution from tools/.
    from upload_launcher_release import _load_config, _upload_file


ROOT = Path(__file__).resolve().parents[1]
METADATA = ROOT / "release" / "approved_3d_bundles_v1.json"


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def release_files(directory: Path, metadata_path: Path = METADATA) -> list[tuple[Path, str]]:
    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    if metadata.get("schema") != 1 or metadata.get("kind") != "pokeaether-approved-3d-release":
        raise ValueError("invalid approved 3D release metadata")
    records = [metadata.get("index"), *metadata.get("bundles", [])]
    expected = {
        "approved-pokemon-3d-v1": 7,
        "approved-pokemon-3d-v2": 21,
        "approved-pokemon-3d-v3": 76,
        "approved-pokemon-3d-v4": 82,
        "approved-pokemon-3d-v5": 83,
        "approved-pokemon-3d-v6": 154,
        "approved-pokemon-3d-v7": 160,
    }.get(metadata.get("revision"))
    if expected is None or len(records) != expected + 1 or not all(isinstance(item, dict) for item in records):
        raise ValueError("release metadata has an unsupported or incomplete bundle set")
    if expected == 21:
        approval = ROOT / "tools/sprite_factory/catalog_production_batch_01_approval.json"
        if metadata.get("catalog_batch_01_approval_sha256") != digest(approval):
            raise ValueError("v2 release is not bound to batch-01 approval")
    if expected == 76:
        approval = ROOT / "tools/sprite_factory/screened_100_battle_approval.json"
        if metadata.get("screened_100_battle_approval_sha256") != digest(approval):
            raise ValueError("v3 release is not bound to screened-100 approval")
    if expected == 82:
        approval = ROOT / "tools/sprite_factory/screened_100_placement_recovery.json"
        if metadata.get("screened_100_placement_recovery_approval_sha256") != digest(approval):
            raise ValueError("v4 release is not bound to placement recovery approval")
    if expected == 83:
        approval = ROOT / "tools/sprite_factory/mega_dragonite_approval.json"
        previous = ROOT / "release/approved_3d_bundles_v4.json"
        if (metadata.get("mega_dragonite_approval_sha256") != digest(approval)
                or metadata.get("v4_index_sha256") != json.loads(previous.read_text())["index"]["sha256"]):
            raise ValueError("v5 release is not bound to Mega Dragonite and v4 approval")
    if expected == 154:
        batch = ROOT / "tools/sprite_factory/catalog_production_batch_02_approval.json"
        followup = ROOT / "tools/sprite_factory/catalog_production_batch_02_review_queue_approval.json"
        previous = ROOT / "release/approved_3d_bundles_v5.json"
        if (metadata.get("batch_02_approval_sha256") != digest(batch)
                or metadata.get("batch_02_followup_approval_sha256") != digest(followup)
                or metadata.get("v5_index_sha256") != json.loads(previous.read_text())["index"]["sha256"]):
            raise ValueError("v6 release is not bound to the batch-02 approvals and v5")
    if expected == 160:
        previous = ROOT / "release/approved_3d_bundles_v6.json"
        previous_upload = ROOT / "release/approved_3d_bundles_v6_r2_upload.json"
        approval = ROOT / "tools/sprite_factory/catalog_remaining_six_bundle_qualification.json"
        previous_data = json.loads(previous.read_text())
        upload_data = json.loads(previous_upload.read_text())
        if (metadata.get("six_pair_bundle_qualification_sha256") != digest(approval)
                or metadata.get("v6_index_sha256") != previous_data['index']['sha256']
                or upload_data.get("pinned_receipt_sha256") != digest(previous)
                or upload_data.get("content_index") != previous_data['index']
                or upload_data.get("public_head_size_verified_objects") != 155
                or upload_data.get("public_get_sha256_verified_objects") != 72):
            raise ValueError("v7 release is not bound to the six-pair approval and v6")
    previous_assets = ({item["object_key"]: item for item in
                        json.loads((ROOT / "release/approved_3d_bundles_v6.json").read_text())["bundles"]}
                       if expected == 160 else {})
    result: list[tuple[Path, str]] = []
    for index, item in enumerate(records):
        path = directory / ("asset-index.json" if index == 0 else Path(item["object_key"]).name)
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"missing release file: {path}")
        if path.stat().st_size != item["size_bytes"]:
            raise ValueError(f"release file size does not match pinned metadata: {path}")
        if item.get("object_key") in previous_assets:
            if item != previous_assets[item["object_key"]]:
                raise ValueError(f"inherited bundle changed from approved v6: {path}")
        elif digest(path) != item["sha256"]:
            raise ValueError(f"release file hash does not match pinned metadata: {path}")
        result.append((path, item["object_key"]))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--metadata", type=Path, default=METADATA,
                        help="Pinned release receipt; defaults to the published seven-bundle v1 set.")
    parser.add_argument("--apply", action="store_true", help="Upload after all pinned files verify.")
    args = parser.parse_args()
    files = release_files(args.directory.resolve(), args.metadata.resolve())
    metadata = json.loads(args.metadata.resolve().read_text(encoding="utf-8"))
    if metadata.get("revision") == "approved-pokemon-3d-v3":
        unchanged = {
            item["object_key"]
            for item in json.loads((ROOT / "release/approved_3d_bundles_v2.json").read_text(encoding="utf-8"))["bundles"]
        }
        files = [item for item in files if item[1] not in unchanged]
    if metadata.get("revision") == "approved-pokemon-3d-v4":
        unchanged = {
            item["object_key"]
            for item in json.loads((ROOT / "release/approved_3d_bundles_v3.json").read_text(encoding="utf-8"))["bundles"]
        }
        files = [item for item in files if item[1] not in unchanged]
    if metadata.get("revision") == "approved-pokemon-3d-v5":
        unchanged = {
            item["object_key"]
            for item in json.loads((ROOT / "release/approved_3d_bundles_v4.json").read_text(encoding="utf-8"))["bundles"]
        }
        files = [item for item in files if item[1] not in unchanged]
    if metadata.get("revision") == "approved-pokemon-3d-v6":
        unchanged = {
            item["object_key"]
            for item in json.loads((ROOT / "release/approved_3d_bundles_v5.json").read_text(encoding="utf-8"))["bundles"]
        }
        files = [item for item in files if item[1] not in unchanged]
    if metadata.get("revision") == "approved-pokemon-3d-v7":
        unchanged = {
            item["object_key"]
            for item in json.loads((ROOT / "release/approved_3d_bundles_v6.json").read_text(encoding="utf-8"))["bundles"]
        }
        files = [item for item in files if item[1] not in unchanged]
    total = sum(path.stat().st_size for path, _ in files)
    print(f"Verified {len(files)} release objects ({total} bytes).")
    for path, key in files:
        print(f"{'UPLOAD' if args.apply else 'DRY-RUN'} {path.name} -> {key}")
    if not args.apply:
        print("Dry-run only; pass --apply with R2 credentials to upload.")
        return
    config = _load_config()
    for path, key in files:
        _upload_file(config, path, key)
    print("Approved 3D bundle release uploaded.")


if __name__ == "__main__":
    main()
