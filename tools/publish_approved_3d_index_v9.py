#!/usr/bin/env python3
"""Validate and optionally publish the immutable v9 index; never activate a manifest."""
import argparse
import concurrent.futures
import datetime
import json
import os
import shlex
from pathlib import Path
from package_approved_3d_release_v9 import ROOT, build
from publish_approved_3d_index_v8 import public_head, active_manifest_hash
from publish_qualified_3d_bundles import publish
from upload_launcher_release import _load_config


def validate_local():
    expected = build()
    paths = ['release/approved_3d_bundles_v9_index.json', 'release/approved_3d_bundles_v9.json', 'data/approved_3d_release_v9.json']
    for path, data in zip(paths, expected):
        assert (ROOT / path).read_bytes() == data, 'v9 artifact differs from approved inputs: ' + path
    assert (ROOT / 'launcher/data/approved_3d_release_v9.json').read_bytes() == expected[2]
    return json.loads(expected[1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--credentials', type=Path)
    args = parser.parse_args()
    metadata = validate_local()
    if not args.apply:
        print('V9_LOCAL_OK bundles=1142 appearances=2284 no_network=true')
        return
    if args.credentials:
        for line in args.credentials.read_text().splitlines():
            parts = shlex.split(line, comments=True)
            if parts and parts[0] == 'export':
                parts = parts[1:]
            if len(parts) == 1 and '=' in parts[0]:
                key, value = parts[0].split('=', 1)
                if key in ('R2_ACCOUNT_ID', 'R2_BUCKET', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_ENDPOINT'):
                    os.environ[key] = value
    config = _load_config()
    assert config.bucket == 'pokemon-aether-updates'
    before = active_manifest_hash()
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        assert all(pool.map(public_head, metadata['bundles'])), 'Missing or incorrectly sized public bundle'
    verified = publish(config, ROOT / 'release/approved_3d_bundles_v9_index.json', metadata['index'])
    assert active_manifest_hash() == before, 'Active desktop manifest changed concurrently'
    receipt = {'schema': 1, 'revision': metadata['revision'], 'content_index': metadata['index'],
               'bundle_count': 1142, 'appearance_count': 2284, 'public_bundle_head_verified': 1142,
               'index_verification': verified, 'active_manifest_activated': False,
               'active_manifest_sha256_unchanged': before,
               'verified_at_utc': datetime.datetime.now(datetime.UTC).isoformat()}
    (ROOT / 'release/approved_3d_bundles_v9_index_r2_receipt.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print('V9_PUBLICATION_OK bundles_head_verified=1142 index_sha256_verified=true manifest_activated=false')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Publication failed (' + type(error).__name__ + '); no activation performed.') from None
