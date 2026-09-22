#!/usr/bin/env python3
"""Verify, and only with --apply upload, the pinned seven-bundle 3D release."""
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
    if len(records) != 8 or not all(isinstance(item, dict) for item in records):
        raise ValueError("release metadata must contain one index and seven bundles")
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
    parser.add_argument("--apply", action="store_true", help="Upload after all eight files verify.")
    args = parser.parse_args()
    files = release_files(args.directory.resolve())
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
