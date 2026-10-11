#!/usr/bin/env python3
"""Check exact staged receipt offline, or reverify public bytes without credentials."""
import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path

from publish_qualified_3d_bundles import public
from publish_shared_model_collection import MANIFESTS, snapshot_manifests
from shared_model_publication_helpers import validate_selection

ROOT = Path(__file__).resolve().parents[1]


def check(receipt, root=ROOT):
    wire, assets = validate_selection(root)
    sha = hashlib.sha256(wire).hexdigest()
    index = {'object_key': 'optional-assets/pokemon_3d/index/pilot-' + sha + '.json',
             'sha256': sha, 'size_bytes': len(wire)}
    if receipt.get('schema') != 1 or receipt.get('revision') != json.loads(wire)['catalog_revision']:
        raise ValueError('Unexpected staged revision')
    if receipt.get('active_manifest_activated') is not False or receipt.get('production_approved') is not False:
        raise ValueError('Staging does not certify/activate production')
    if receipt.get('content_index') != index:
        raise ValueError('Index pin differs')
    if receipt.get('readiness_sha256') != hashlib.sha256((root / 'data/shared_model_readiness_checks.json').read_bytes()).hexdigest():
        raise ValueError('Readiness hash differs')
    manifests = receipt.get('active_manifests_unchanged')
    if not isinstance(manifests, dict) or set(manifests) != set(MANIFESTS) or not manifests.get('manifest.json'):
        raise ValueError('Manifest snapshot incomplete')
    actual = receipt.get('bundles')
    if not isinstance(actual, list) or len(actual) != 1200:
        raise ValueError('Physical receipt incomplete')
    expected = {a['asset_id']: {k: a[k] for k in ('asset_id', 'object_key', 'sha256', 'size_bytes')} for a in assets}
    seen = set()
    for row in actual:
        if not isinstance(row, dict) or row.get('asset_id') not in expected or row['asset_id'] in seen:
            raise ValueError('Duplicate/unknown asset')
        verify_row(row, expected[row['asset_id']])
        seen.add(row['asset_id'])
    verify_row(receipt.get('index_verification'), index)
    return actual + [receipt['index_verification']]


def verify_row(row, expected):
    if not isinstance(row, dict) or any(row.get(k) != v for k, v in expected.items()):
        raise ValueError('Physical object pin differs')
    if row.get('public_get_sha256_verified') is not True or row.get('public_head_size_verified') is not True:
        raise ValueError('Public integrity verification incomplete')
    if not isinstance(row.get('uploaded'), bool):
        raise ValueError('Missing upload/reuse outcome')


def remote(record):
    return public(record) and public(record, head=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, default=ROOT / 'release/shared_model_collection_r2_receipt.json')
    parser.add_argument('--remote', action='store_true', help='Full GET SHA-256 and HEAD for all 1,201 objects; no writes')
    args = parser.parse_args()
    receipt = json.loads(args.receipt.read_bytes())
    records = check(receipt)
    if args.remote:
        before = snapshot_manifests()
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            for count, passed in enumerate(pool.map(remote, records), 1):
                if not passed:
                    raise ValueError('Public staged object missing')
                if count % 100 == 0:
                    print('SHARED_REMOTE_REVERIFIED', count, '/', len(records), flush=True)
        if snapshot_manifests() != before:
            raise ValueError('Live manifests changed during reverification')
    print('SHARED_PUBLICATION_RECEIPT_OK bundles=1200 index=1 remote=' + str(args.remote).lower())


if __name__ == '__main__':
    main()
