#!/usr/bin/env python3
"""Verify pinned optional Android assets locally or publicly, without publishing."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen
import zipfile

ROOT = Path(__file__).resolve().parents[1]
RELEASE_PATH = ROOT / "data/approved_3d_release_v14.json"
CATALOG_PATH = ROOT / "data/model_pair_release_v14_catalog.json"


def public_request(key, method="GET"):
    if not isinstance(key, str) or not key or key.startswith("/") or ".." in key or ":" in key:
        raise ValueError("Invalid optional asset object key")
    return Request("https://updates.pokeaether.com/" + key, method=method,
                   headers={"User-Agent": "PokeAetherAndroid3DPreflight/1.0", "Cache-Control": "no-cache"})


def read_public(key, limit):
    with urlopen(public_request(key), timeout=30) as response:
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Optional asset exceeds its pin")
    return data


def model_assets(index, release, catalog):
    if index.get("catalog_revision") != release["revision"] or catalog.get("catalog_revision") != release["revision"]:
        raise ValueError("Android model catalog revision differs from its release")
    rows = {row["asset_id"]: row for row in catalog["assets"]}
    if len(rows) != len(catalog["assets"]):
        raise ValueError("Duplicate Android model catalog asset")
    result = []
    seen = set()
    for reference in index["assets"]:
        identity = reference["asset_id"]
        if identity in seen:
            raise ValueError("Duplicate Android model index asset")
        seen.add(identity)
        if reference.get("format") == "model-pair-ref-v1":
            row = rows.get(identity)
            if row is None or row["sha256"] != reference["sha256"]:
                raise ValueError("Android shared model differs from its approved reference")
        else:
            row = reference
        if int(row["size_bytes"]) <= 0 or row["sha256"] not in row["object_key"]:
            raise ValueError("Android model object is not immutable")
        public_request(row["object_key"])
        result.append(row)
    if seen != set(release["requiredAssetIds"]) or len(seen) != len(release["requiredAssetIds"]):
        raise ValueError("Android model index does not cover its approved release")
    return result


def verify_model_asset(asset):
    # The v14 publication receipt already verifies full GET hashes. Recheck
    # availability here too: a valid historical index can outlive retired packs.
    with urlopen(public_request(asset["object_key"], "HEAD"), timeout=30) as response:
        if int(response.headers.get("Content-Length", -1)) != int(asset["size_bytes"]):
            raise ValueError(f"Android model object size differs: {asset['asset_id']}")


def checked(data, size, sha):
    if len(data) != size or hashlib.sha256(data).hexdigest() != sha:
        raise ValueError("Optional Android asset differs from its immutable pin")


def verify_archive(data, arena):
    import io
    checked(data, arena["archive_bytes"], arena["archive_sha256"])
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        if sorted(archive.namelist()) != ["forest-runtime/forest.json", "forest-runtime/forest.pck"]:
            raise ValueError("Unexpected Android arena ZIP members")
        checked(archive.read("forest-runtime/forest.pck"), arena["pack_bytes"], arena["pack_sha256"])


def verify_public(descriptor, release, catalog):
    if release["revision"] != descriptor["model_release"]:
        raise ValueError("Android experiment and approved model release do not match")
    pin = release["index"]
    data = read_public(pin["object_key"], pin["size_bytes"])
    checked(data, pin["size_bytes"], pin["sha256"])
    assets = model_assets(json.loads(data), release, catalog)
    with ThreadPoolExecutor(max_workers=8) as executor:
        for _ in executor.map(verify_model_asset, assets):
            pass
    arena = descriptor["arena"]
    verify_archive(read_public(arena["object_key"], arena["archive_bytes"]), arena)
    print(f"Android {release['revision']}: {len(assets)} model objects available with pinned sizes")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--public", action="store_true")
    mode.add_argument("--archive", type=Path)
    args = parser.parse_args()
    descriptor = json.loads((ROOT / "data/android_3d_experiment.json").read_text())
    release = json.loads(RELEASE_PATH.read_text())
    if args.public:
        verify_public(descriptor, release, json.loads(CATALOG_PATH.read_text()))
    else:
        verify_archive(args.archive.read_bytes(), descriptor["arena"])
    print("ANDROID_3D_ASSETS_OK: pinned model index, available packs and/or exact Android arena archive; nothing published")


if __name__ == "__main__":
    main()
