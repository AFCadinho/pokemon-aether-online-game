#!/usr/bin/env python3
"""Upload the immutable files of a packaged browser release to Cloudflare R2."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path

from upload_launcher_release import _load_config, _load_updates_config, _upload_file


ROOT = Path(__file__).resolve().parents[1]
MAX_UPLOAD_WORKERS = 8


def _upload_object(config, source: Path, key: str, size: int) -> None:
    print(f"Uploading immutable web object {key} ({size} bytes)", flush=True)
    _upload_file(config, source, key)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("release_dir", nargs="?", type=Path, default=ROOT / "builds/web-r2")
    parser.add_argument("--publish-manifest", action="store_true", help="Publish manifest-web.json after all immutable files are live.")
    parser.add_argument("--manifest-only", action="store_true", help="Publish only manifest-web.json after external verification.")
    parser.add_argument("--verify-only", action="store_true", help="Verify local files without contacting R2.")
    args = parser.parse_args()
    if args.manifest_only and not args.publish_manifest:
        parser.error("--manifest-only requires --publish-manifest")
    if args.verify_only and (args.manifest_only or args.publish_manifest):
        parser.error("--verify-only cannot publish a manifest")
    release_dir = args.release_dir.resolve()
    manifest = json.loads((release_dir / "web-release.json").read_text(encoding="utf-8"))
    config = None if args.verify_only or args.manifest_only else _load_config()

    if not args.manifest_only:
        verified_objects = []
        for item in manifest["objects"]:
            source = release_dir / item["source"]
            if not source.is_file() or source.stat().st_size != item["bytes"]:
                raise SystemExit(f"Missing or changed release object: {source}")
            with source.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            if digest != item["sha256"]:
                raise SystemExit(f"SHA-256 mismatch for release object: {source}")
            verified_objects.append((source, item["key"], item["bytes"]))

        if not args.verify_only:
            with ThreadPoolExecutor(max_workers=MAX_UPLOAD_WORKERS, thread_name_prefix="r2-web-upload") as executor:
                futures = [
                    executor.submit(_upload_object, config, source, key, size)
                    for source, key, size in verified_objects
                ]
                for future in as_completed(futures):
                    future.result()
            _upload_file(config, release_dir / "web-release.json", f"web/releases/{manifest['buildId']}/web-release.json")
        else:
            print(f"Verified {len(manifest['objects'])} immutable web objects", flush=True)
    if args.publish_manifest:
        updates_config = _load_updates_config()
        _upload_file(updates_config, release_dir / "manifest-web.json", "manifest-web.json")
        print(f"Published manifest-web.json to updates bucket {updates_config.bucket}", flush=True)


if __name__ == "__main__":
    main()
