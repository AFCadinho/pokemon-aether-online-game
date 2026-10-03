#!/usr/bin/env python3
"""Publish only the v8 aggregate index after verifying its existing R2 bundles.

Default mode is local-only. --apply checks every referenced public bundle with
HEAD, uploads only the small immutable aggregate index, then verifies its public
SHA-256 and size. It never changes a game or launcher manifest.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import time
import urllib.error
import urllib.request

try:
    from .upload_launcher_release import _load_config, _signed_request, _upload_file
except ImportError:
    from upload_launcher_release import _load_config, _signed_request, _upload_file

ROOT = Path(__file__).resolve().parents[1]
INDEX_PATH = ROOT / "release/approved_3d_bundles_v8_index.json"
METADATA_PATH = ROOT / "release/approved_3d_bundles_v8.json"
REGISTRY_PATH = ROOT / "scripts/battle/battle_ui/reviewed_model_catalog.json"
BASE = "https://updates.pokeaether.com/"


def hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def public_head(record: dict) -> bool:
    url = BASE + record["object_key"] + "?check=" + str(time.time_ns())
    request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "PokeAether-IndexVerifier/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status == 200 and int(response.headers.get("Content-Length", "0")) == int(record["size_bytes"])
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise


def public_get(record: dict) -> bool:
    url = BASE + record["object_key"] + "?verify=" + record["sha256"] + "&check=" + str(time.time_ns())
    request = urllib.request.Request(url, headers={"User-Agent": "PokeAether-IndexVerifier/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            data = response.read()
            return response.status == 200 and len(data) == int(record["size_bytes"]) and hash_bytes(data) == record["sha256"]
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return False
        raise


def active_manifest_hash() -> str:
    request = urllib.request.Request(BASE + "manifest.json?check=" + str(time.time_ns()),
                                     headers={"User-Agent": "PokeAether-IndexVerifier/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return hash_bytes(response.read())


def validate_local() -> tuple[dict, dict, list[dict]]:
    metadata_bytes = METADATA_PATH.read_bytes()
    metadata = json.loads(metadata_bytes)
    index_bytes = INDEX_PATH.read_bytes()
    index = json.loads(index_bytes)
    if metadata.get("revision") != "approved-pokemon-3d-v8" or index.get("catalog_revision") != metadata.get("revision"):
        raise ValueError("expected the locally prepared v8 candidate")
    pin = metadata.get("index", {})
    if (pin.get("sha256") != hash_bytes(index_bytes) or pin.get("size_bytes") != len(index_bytes)
            or not pin.get("object_key", "").endswith("-" + pin.get("sha256", "") + ".json")):
        raise ValueError("v8 index bytes differ from their immutable metadata pin")
    assets = index.get("assets", [])
    bundles = metadata.get("bundles", [])
    if len(assets) != 1139 or len(bundles) != 1139:
        raise ValueError("v8 bundle count is incomplete")
    by_id = {asset.get("asset_id"): asset for asset in assets}
    records = {asset.get("asset_id"): asset for asset in bundles}
    if len(by_id) != 1139 or set(by_id) != set(records):
        raise ValueError("v8 metadata and index asset IDs differ")
    for asset_id, asset in by_id.items():
        record = records[asset_id]
        for field in ("asset_id", "object_key", "sha256", "size_bytes"):
            if record.get(field) != asset.get(field):
                raise ValueError(f"v8 asset metadata differs: {asset_id}")
    registry = json.loads(REGISTRY_PATH.read_text())["models"]
    identities = {}
    for asset in assets:
        for appearance in asset.get("appearances", []):
            identity = appearance.get("runtime_identity", "")
            if identity in identities or registry.get(identity, {}).get("sha256") != appearance.get("runtime_sha256"):
                raise ValueError(f"v8 model is not uniquely approved: {identity}")
            identities[identity] = True
    if set(identities) != set(registry):
        raise ValueError("v8 index does not cover every reviewed runtime model")
    for filename, expected_hash in metadata.get("source_receipts_sha256", {}).items():
        path = ROOT / "release" / filename
        if not path.is_file() or hash_bytes(path.read_bytes()) != expected_hash:
            raise ValueError(f"v8 source publication receipt changed: {filename}")
    return metadata, index, bundles


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Verify R2 and upload only the aggregate v8 index.")
    args = parser.parse_args()
    metadata, _, bundles = validate_local()
    index_record = {key: metadata["index"][key] for key in ("object_key", "sha256", "size_bytes")}
    if not args.apply:
        print(f"Local v8 index valid: {len(bundles)} references, {index_record['size_bytes']} bytes. "
              "No network access or upload performed. Add --apply to verify bundle HEADs and publish only the index.")
        return

    before = active_manifest_hash()
    config = _load_config()
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        futures = {pool.submit(public_head, record): record["asset_id"] for record in bundles}
        missing = []
        for future in concurrent.futures.as_completed(futures):
            if not future.result():
                missing.append(futures[future])
    if missing:
        raise ValueError(f"{len(missing)} referenced R2 bundles are missing or have wrong sizes; index not uploaded")

    if public_get(index_record):
        if not public_head(index_record):
            raise ValueError("existing public v8 index has the wrong size")
        uploaded = False
    else:
        status, _, _ = _signed_request(config, "HEAD", index_record["object_key"])
        if status == 200:
            raise ValueError("v8 index key exists but public bytes do not match the pin")
        if status != 404:
            raise ValueError(f"R2 HEAD returned {status} for the v8 index")
        _upload_file(config, INDEX_PATH, index_record["object_key"])
        if not public_get(index_record) or not public_head(index_record):
            raise ValueError("new v8 index failed public integrity verification")
        uploaded = True
    after = active_manifest_hash()
    if after != before:
        raise ValueError("active desktop manifest changed during index publication")
    receipt = {
        "schema": 1,
        "revision": metadata["revision"],
        "content_index": index_record,
        "bundle_count": len(bundles),
        "appearance_count": len(bundles) * 2,
        "public_bundle_head_verified": len(bundles),
        "index_public_get_sha256_verified": True,
        "index_uploaded": uploaded,
        "active_manifest_activated": False,
        "active_manifest_sha256_unchanged": before,
    }
    output = ROOT / "release/approved_3d_bundles_v8_index_r2_receipt.json"
    output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    print(f"V8_INDEX_PUBLICATION_OK index_uploaded={str(uploaded).lower()} bundles_head_verified={len(bundles)} "
          "manifest_activated=false")


if __name__ == "__main__":
    main()
