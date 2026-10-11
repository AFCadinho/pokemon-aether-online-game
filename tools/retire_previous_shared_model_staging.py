#!/usr/bin/env python3
"""Retire only objects superseded by the verified geometry staging collection.

The previous qualified collection was a debug staging collection, never a
player release. Dry-run writes a reviewable exact plan. Apply rechecks current
manifest references and R2 inventory before deleting each allowlisted key.
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
from pathlib import Path
import re
import time
import urllib.request

from prune_r2_release_objects import _list_release_objects
from publish_shared_geometry_collection import ROOT, prepare, read, sha
from publish_shared_model_collection import BASE, MANIFESTS, load_credentials, snapshot_manifests
from upload_launcher_release import _signed_request


def active_references(snapshot):
    protected = set()
    for name in MANIFESTS:
        if snapshot[name] is None:
            continue
        request = urllib.request.Request(BASE + name + '?audit=' + str(time.time_ns()),
                                         headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = response.read()
        assert hashlib.sha256(payload).hexdigest() == snapshot[name]['sha256']
        manifest = json.loads(payload)
        descriptor = manifest.get('assetBundleIndex')
        if not isinstance(descriptor, dict):
            continue
        url = descriptor.get('url')
        assert isinstance(url, str) and url.startswith(BASE + 'optional-assets/pokemon_3d/index/')
        index_key = url.removeprefix(BASE)
        protected.add(index_key)
        request = urllib.request.Request(url + '?audit=' + str(time.time_ns()),
                                         headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = response.read(1024 * 1024 + 1)
        assert len(payload) == descriptor['sizeBytes'] <= 1024 * 1024
        assert hashlib.sha256(payload).hexdigest() == descriptor['sha256']
        for asset in json.loads(payload)['assets']:
            if isinstance(asset, dict) and isinstance(asset.get('object_key'), str):
                protected.add(asset['object_key'])
    return protected


def validate_new_receipt(receipt, rows, index, build_sha):
    assert receipt['schema'] == 1 and receipt['revision'] == 'shared-geometry-test-v1'
    assert receipt['production_approved'] is False and receipt['active_manifest_activated'] is False
    assert receipt['build_report_sha256'] == build_sha
    assert receipt['content_index'] == index
    expected = {record['asset_id']: record for _, record in rows}
    actual = receipt['bundles']
    assert len(actual) == len(expected) == 1200
    assert len({row['asset_id'] for row in actual}) == 1200
    for row in actual:
        assert all(row[name] == value for name, value in expected[row['asset_id']].items())
        assert row['public_get_sha256_verified'] is True and row['public_head_size_verified'] is True
    assert all(receipt['index_verification'][name] == value for name, value in index.items())
    assert receipt['index_verification']['public_get_sha256_verified'] is True
    assert receipt['index_verification']['public_head_size_verified'] is True


def candidates(old, new):
    next_keys = {a['object_key'] for a in new['bundles']}
    removed = []
    for row in old['bundles']:
        if row['object_key'] in next_keys:
            continue
        if row['object_key'].endswith('.zip'):
            # The v11 originals were reused by the old staging collection and
            # may still be needed by current clients.
            assert row['uploaded'] is False
            continue
        assert row['uploaded'] is True and re.fullmatch(
            r'optional-assets/pokemon_3d/[a-z0-9-]+/[a-z0-9-]+/v[0-9]+-[a-f0-9]{64}\.pck',
            row['object_key'])
        removed.append({name: row[name] for name in ('asset_id', 'object_key', 'sha256', 'size_bytes')})
    assert len(removed) == 968
    former_index = old['index_verification']
    assert former_index['uploaded'] is True and former_index['object_key'] != new['content_index']['object_key']
    assert re.fullmatch(r'optional-assets/pokemon_3d/index/pilot-[a-f0-9]{64}\.json',
                        former_index['object_key'])
    removed.append({name: former_index[name] for name in ('object_key', 'sha256', 'size_bytes')})
    return sorted(removed, key=lambda row: row['object_key'])


def make_plan(config, old, new, rows, index, build_sha):
    validate_new_receipt(new, rows, index, build_sha)
    doomed = candidates(old, new)
    before = snapshot_manifests()
    assert before == new['active_manifests_unchanged'], 'Live manifests changed after geometry upload'
    protected = active_references(before)
    assert not protected.intersection(row['object_key'] for row in doomed), 'Active release references old staging'
    objects = {item.key: item for item in _list_release_objects(config, 'desktop')}
    required = [record for _, record in rows] + [index]
    assert all(objects[record['object_key']].size == record['size_bytes'] for record in required)
    for row in doomed:
        if row['object_key'] in objects:
            assert objects[row['object_key']].size == row['size_bytes']
    return {'schema': 1, 'previous_receipt_sha256': sha(ROOT / 'release/shared_model_collection_r2_receipt.json'),
            'geometry_receipt_sha256': sha(ROOT / 'release/shared_model_geometry_r2_receipt.json'),
            'active_manifests': before, 'candidates': doomed,
            'candidate_bytes': sum(row['size_bytes'] for row in doomed),
            'present': sum(row['object_key'] in objects for row in doomed),
            'new_collection_verified_in_inventory': True,
            'active_reference_intersection': 0}


def delete_one(config, row):
    key = row['object_key']
    status, _, _ = _signed_request(config, 'HEAD', key)
    if status == 404:
        return {'object_key': key, 'outcome': 'already_absent'}
    if status != 200:
        raise ValueError('R2 HEAD failed before retirement: ' + key)
    status, _, _ = _signed_request(config, 'DELETE', key)
    if status < 200 or status >= 300:
        raise ValueError('R2 DELETE failed: ' + key)
    status, _, _ = _signed_request(config, 'HEAD', key)
    if status != 404:
        raise ValueError('R2 still reports retired key: ' + key)
    return {'object_key': key, 'outcome': 'deleted'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--collection', type=Path, required=True)
    parser.add_argument('--sources', type=Path, required=True)
    parser.add_argument('--credentials', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--plan', type=Path, default=ROOT / 'release/shared_model_geometry_r2_retirement_plan.json')
    parser.add_argument('--output', type=Path, default=ROOT / 'release/shared_model_geometry_r2_retirement_receipt.json')
    args = parser.parse_args()
    rows, index, old = prepare(args.collection, args.sources)
    new = read(ROOT / 'release/shared_model_geometry_r2_receipt.json')
    config = load_credentials(args.credentials)
    plan = make_plan(config, old, new, rows, index, sha(args.collection / 'report.json'))
    if not args.apply:
        with args.plan.open('x') as stream:
            stream.write(json.dumps(plan, indent=2, sort_keys=True) + '\n')
        print('GEOMETRY_RETIREMENT_PLAN_OK candidates=' + str(len(plan['candidates']))
              + ' bytes=' + str(plan['candidate_bytes']), flush=True)
        return
    saved = read(args.plan)
    assert all(saved[key] == plan[key] for key in
               ('schema', 'previous_receipt_sha256', 'geometry_receipt_sha256',
                'active_manifests', 'candidates', 'candidate_bytes'))
    if args.output.exists():
        raise ValueError('Retirement receipt already exists')
    completed = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(delete_one, config, row) for row in plan['candidates']]
        for future in concurrent.futures.as_completed(futures):
            completed.append(future.result())
            if len(completed) % 25 == 0:
                print('GEOMETRY_RETIRED', len(completed), '/', len(plan['candidates']), flush=True)
    assert snapshot_manifests() == plan['active_manifests']
    assert not active_references(plan['active_manifests']).intersection(
        row['object_key'] for row in plan['candidates'])
    receipt = {'schema': 1, 'plan_sha256': sha(args.plan),
               'deleted': sum(row['outcome'] == 'deleted' for row in completed),
               'already_absent': sum(row['outcome'] == 'already_absent' for row in completed),
               'candidate_bytes': plan['candidate_bytes'],
               'candidates': sorted(completed, key=lambda row: row['object_key']),
               'active_manifests_unchanged': plan['active_manifests'],
               'verified_at_utc': datetime.datetime.now(datetime.UTC).isoformat()}
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
    print('GEOMETRY_RETIREMENT_OK deleted=' + str(receipt['deleted'])
          + ' already_absent=' + str(receipt['already_absent']), flush=True)


if __name__ == '__main__':
    main()
