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
    result: list[tuple[Path, str]] = []
    for index, item in enumerate(records):
        path = directory / ("asset-index.json" if index == 0 else Path(item["object_key"]).name)
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"missing release file: {path}")
        if path.stat().st_size != item["size_bytes"] or digest(path) != item["sha256"]:
            raise ValueError(f"release file does not match pinned metadata: {path}")
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
