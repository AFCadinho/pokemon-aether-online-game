#!/usr/bin/env python3
"""Build the immutable, required forest runtime archive used by releases."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
from zipfile import ZIP_STORED, ZipFile, ZipInfo


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "builds" / "asset-packs"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def archive_bytes(source_pck: Path, output_dir: Path = OUTPUT) -> tuple[str, Path, int, str]:
    if not source_pck.is_file() or source_pck.stat().st_size == 0:
        raise SystemExit(f"Missing forest runtime PCK: {source_pck}")
    pack_hash = sha256(source_pck)
    version = f"battle-environment-forest-{pack_hash[:12]}"
    output_dir.mkdir(parents=True, exist_ok=True)
    target = output_dir / f"{version}.zip"
    descriptor = (json.dumps({"schema": 1, "pack": "forest.pck"}, indent=2) + "\n").encode()
    with ZipFile(target, "w", ZIP_STORED) as archive:
        for name, data in (
            ("forest-runtime/forest.json", descriptor),
            ("forest-runtime/forest.pck", source_pck.read_bytes()),
        ):
            info = ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = ZIP_STORED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)
    return version, target, target.stat().st_size, sha256(target)


def upload_archive(target: Path, config_loader=None, uploader=None) -> None:
    """Publish only after the caller explicitly opts in with --upload."""
    if config_loader is None or uploader is None:
        sys.path.insert(0, str(ROOT / "tools"))
        from upload_launcher_release import _load_config, _upload_file

        config_loader = _load_config
        uploader = _upload_file

    uploader(config_loader(), target, f"assets/{target.name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_pck", type=Path)
    parser.add_argument("--json", action="store_true", help="Print machine-readable metadata.")
    parser.add_argument(
        "--upload",
        action="store_true",
        help="Upload the immutable archive to configured R2 after packaging.",
    )
    args = parser.parse_args()
    version, target, size, digest = archive_bytes(args.source_pck.resolve())
    result = {"id": "battle-environment-forest", "version": version,
              "file": target.name, "path": str(target), "sizeBytes": size,
              "sha256": digest, "optional": False}
    if args.upload:
        upload_archive(target)
        result["uploadedKey"] = f"assets/{target.name}"
    print(json.dumps(result, sort_keys=True) if args.json else
          f"{version} {size} bytes {digest} {target}")


if __name__ == "__main__":
    main()
