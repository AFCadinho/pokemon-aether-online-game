#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import urllib.error
import urllib.request
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify uploaded launcher release artifacts before publishing manifests."
    )
    parser.add_argument(
        "release_dir",
        help="Directory containing the generated manifest JSON files.",
    )
    parser.add_argument(
        "--include-launcher",
        action="store_true",
        help="Also verify launcher self-update artifacts from each manifest.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=60.0,
        help="Timeout per public HEAD request.",
    )
    args = parser.parse_args()

    manifest_paths = sorted(Path(args.release_dir).glob("manifest-*.json"))
    if not manifest_paths:
        raise SystemExit(f"No platform manifests found in {args.release_dir}")

    verified_urls: set[str] = set()
    for manifest_path in manifest_paths:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        _verify_entry(manifest_path, "game", manifest.get("game"), args.timeout, verified_urls)
        asset_packs = manifest.get("assetPacks", [])
        if not isinstance(asset_packs, list):
            raise SystemExit(f"{manifest_path} assetPacks must be a list")
        for asset_pack in asset_packs:
            if not isinstance(asset_pack, dict):
                raise SystemExit(f"{manifest_path} contains an invalid asset pack")
            pack_id = str(asset_pack.get("id", "asset-pack"))
            _verify_entry(
                manifest_path,
                f"asset pack {pack_id}",
                asset_pack,
                args.timeout,
                verified_urls,
            )
        if args.include_launcher:
            _verify_entry(
                manifest_path,
                "launcher",
                manifest.get("launcher"),
                args.timeout,
                verified_urls,
            )


def _verify_entry(
    manifest_path: Path,
    label: str,
    value: object,
    timeout: float,
    verified_urls: set[str],
) -> None:
    if not isinstance(value, dict):
        raise SystemExit(f"{manifest_path} has no {label} object")

    url = str(value.get("url", "")).strip()
    expected_size = int(value.get("sizeBytes", 0))
    expected_sha256 = str(value.get("sha256", "")).strip().lower()
    if not url or expected_size <= 0:
        raise SystemExit(f"{manifest_path} has incomplete {label} publication metadata")
    if re.fullmatch(r"[a-f0-9]{64}", expected_sha256) is None:
        raise SystemExit(f"{manifest_path} has no valid SHA-256 for {label}")
    if url in verified_urls:
        return

    request = urllib.request.Request(
        url,
        method="HEAD",
        headers={
            "Cache-Control": "no-cache",
            "User-Agent": "PokeAetherReleaseVerifier/1.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            response_code = response.status
            actual_size_text = response.headers.get("Content-Length", "")
    except (urllib.error.URLError, TimeoutError) as error:
        raise SystemExit(f"Could not verify {label} URL {url}: {error}") from error

    if response_code < 200 or response_code >= 300:
        raise SystemExit(f"{label} URL returned HTTP {response_code}: {url}")
    if not actual_size_text.isdigit():
        raise SystemExit(f"{label} URL has no valid Content-Length: {url}")

    actual_size = int(actual_size_text)
    if actual_size != expected_size:
        raise SystemExit(
            f"{label} size mismatch for {url}: expected {expected_size}, got {actual_size}"
        )

    range_request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "Accept-Encoding": "identity",
            "Cache-Control": "no-cache",
            "Range": "bytes=0-0",
            "User-Agent": "PokeAetherReleaseVerifier/1.0",
        },
    )
    try:
        with urllib.request.urlopen(range_request, timeout=timeout) as response:
            range_status = response.status
            content_range = response.headers.get("Content-Range", "")
            range_body = response.read(2)
    except (urllib.error.URLError, TimeoutError) as error:
        raise SystemExit(f"Could not verify Range support for {label} URL {url}: {error}") from error

    expected_content_range = f"bytes 0-0/{expected_size}"
    if range_status != 206:
        raise SystemExit(f"{label} URL does not support byte ranges: HTTP {range_status}: {url}")
    if content_range.lower() != expected_content_range:
        raise SystemExit(
            f"{label} URL returned invalid Content-Range: "
            f"expected {expected_content_range}, got {content_range!r}"
        )
    if len(range_body) != 1:
        raise SystemExit(f"{label} URL returned {len(range_body)} bytes for bytes=0-0")

    verified_urls.add(url)
    print(f"Verified {label}: {url} ({actual_size} bytes, Range OK)")


if __name__ == "__main__":
    main()
